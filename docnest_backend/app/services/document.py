# app/services/document_service.py
import os
import time
import magic
import boto3
import uuid
from botocore.exceptions import ClientError
from fastapi import UploadFile, HTTPException, status, Request, Form
from sqlalchemy.orm import Session
from typing import List, Optional, Tuple
from datetime import datetime

from ..models.document import Document
from ..models.user import User
from ..schemas.document import DocumentCreate, DocumentUpdate
from ..core.config import settings
from ..services.activity_logger import ActivityLogger
from ..services.analytics_service import AnalyticsService

class DocumentService:
    ALLOWED_EXTENSIONS = {'.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png'}
    
    def __init__(self, db: Session, user: Optional[User] = None, request: Optional[Request] = None):
        # Initialize core services
        self.db = db
        self.user = user
        self.request = request
        
        # Initialize S3 client
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION
        )
        self.bucket_name = settings.AWS_BUCKET_NAME
        
        # Initialize logging and analytics
        self.activity_logger = ActivityLogger(db)
        self.analytics_service = AnalyticsService(db)

    def _validate_file(self, file: UploadFile) -> None:
        """Validate file size and type"""
        if not file.filename:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No file provided"
            )

        # Check file extension
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in self.ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File type not allowed. Allowed types: {', '.join(self.ALLOWED_EXTENSIONS)}"
            )

        # Check file size
        try:
            file.file.seek(0, 2)
            size = file.file.tell()
            file.file.seek(0)
            
            if size > settings.MAX_FILE_SIZE:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"File too large. Maximum size is {settings.MAX_FILE_SIZE/1024/1024}MB"
                )



        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(e)
            )

    async def _upload_to_s3(
        self,
        file: UploadFile,
        folder: str = "documents"
    ) -> Tuple[str, int, str]:
        """Upload file to S3 with comprehensive error handling and monitoring"""
        upload_start = time.time()
        try:
            # Generate unique filename
            ext = os.path.splitext(file.filename)[1].lower()
            s3_key = f"{folder.strip('/')}/{uuid.uuid4()}{ext}"
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Generated S3 key for upload: {s3_key}")

            content = await file.read()
            file_size = len(content)
            file_type = magic.from_buffer(content, mime=True)

            if settings.DEBUG_S3_OPERATIONS:
                print(f"Uploading file: size={file_size}, type={file_type}")

            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=s3_key,
                Body=content,
                ContentType=file_type,
                Metadata={
                    'original_filename': file.filename,
                    'upload_timestamp': datetime.utcnow().isoformat()
                }
            )



            await file.seek(0)
            return s3_key, file_size, file_type

        except Exception as e:
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Error during S3 upload: {str(e)}")
            raise

    async def _delete_from_s3(self, file_path: str) -> None:
        """Delete file from S3 with improved error handling and key parsing"""
        if not file_path:
            if settings.DEBUG_S3_OPERATIONS:
                print("No file path provided for deletion")
            return

        try:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Original file path: {file_path}")

            # Clean up the key - remove any leading/trailing slashes and spaces
            s3_key = file_path.strip('/')
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Attempting to delete object with key: {s3_key}")
                # List objects to verify key exists
                response = self.s3_client.list_objects_v2(
                    Bucket=self.bucket_name,
                    Prefix=s3_key
                )
                if 'Contents' in response:
                    print(f"Object found in bucket with key: {s3_key}")
                else:
                    print(f"No object found in bucket with key: {s3_key}")

            # Delete the object
            response = self.s3_client.delete_object(
                Bucket=self.bucket_name,
                Key=s3_key
            )
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Delete response: {response}")
                print(f"Successfully deleted from S3: {s3_key}")

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"S3 delete error: Code={error_code}, Message={error_message}")
            
            if error_code == 'NoSuchKey':
                # Log but don't raise if object doesn't exist
                if settings.DEBUG_S3_OPERATIONS:
                    print(f"Object already deleted or doesn't exist: {s3_key}")
                return
            
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"S3 delete error: {error_message}"
            )
        except Exception as e:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Unexpected error during S3 deletion: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error deleting file: {str(e)}"
            )

    async def create_document(
        self,
        owner_id: str,
        document_in: DocumentCreate,
        file: UploadFile,
    ) -> Document:
        """Create a new document with comprehensive tracking and error handling"""
        operation_start = time.time()
        
        try:
            # Validate and upload file
            self._validate_file(file)
            file_url, file_size, file_type = await self._upload_to_s3(
                file,
                folder=f"documents/{owner_id}"
            )
            
            # Create document
            db_document = Document(
                name=document_in.name,
                description=document_in.description,
                category=document_in.category,
                file_path=file_url,
                file_size=file_size,
                file_type=file_type,
                owner_id=owner_id
            )
            
            self.db.add(db_document)
            self.db.commit()
            self.db.refresh(db_document)

            # Log activity with the correct user
            if self.user:  # Make sure we have a user
                await self.activity_logger.log_activity(
                    user=self.user,  # Pass the actual User object
                    action="document.create",
                    resource_type="document",
                    resource_id=db_document.id,
                    details={
                        "name": db_document.name,
                        "category": db_document.category,
                        "size": file_size,
                        "file_type": file_type
                    },
                    request=self.request
                )

                # Track analytics with the correct user
                self.analytics_service.track_event(
                    event_type="document_created",
                    user=self.user,  # Pass the actual User object
                    event_category="document",
                    properties={
                        "document_id": db_document.id,
                        "category": db_document.category
                    },
                    request=self.request
                )

            return db_document

        except Exception as e:
            # Clean up uploaded file if exists
            if 'file_url' in locals():
                await self._delete_from_s3(file_url)

            # Track failure
            if self.user:
                self.analytics_service.track_event(
                    event_type="document_creation_failed",
                    user=self.user,
                    event_category="error",
                    properties={
                        "error": str(e),
                        "file_name": file.filename,
                        "attempted_category": document_in.category
                    },
                    request=self.request
                )

            raise


    def get_document(self, db: Session, document_id: str, owner_id: str) -> Document:
        """Get a specific document"""
        document = db.query(Document).filter(
            Document.id == document_id,
            Document.owner_id == owner_id
        ).first()
        
        if not document:
            raise HTTPException(status_code=404, detail="Document not found")
        
        # Single analytics entry for document view
        if self.user and self.request:
            self.analytics_service.track_event(
                event_type="document_viewed",
                user=self.user,
                event_category="document",
                properties={"document_id": document_id},
                request=self.request
            )
        return document

    def get_user_documents(
        self,
        db: Session,
        owner_id: str,
        category: Optional[str] = Form(None)
    ) -> List[Document]:
        """Get all documents for a user, optionally filtered by category"""
        query = db.query(Document).filter(Document.owner_id == owner_id)
        
        if category:
            query = query.filter(Document.category == category)
            
        return query.order_by(Document.created_at.desc()).all()

    async def update_document(
        self,
        document_id: str,
        owner_id: str,
        document_in: dict,
        file: Optional[UploadFile] = None
    ) -> Document:
        """Update document with improved error handling and tracking"""
        operation_start = time.time()
        document = self.get_document(document_id, owner_id)
        old_file_url = None
        update_details = {}

        try:
            if file:
                self._validate_file(file)
                old_file_url = document.file_path
                file_url, file_size, file_type = await self._upload_to_s3(
                    file,
                    folder=f"documents/{owner_id}"
                )
                
                document.file_path = file_url
                document.file_size = file_size
                document.file_type = file_type
                document.version += 1
                update_details["file_updated"] = True

            # Update other fields
            for field, value in document_in.items():
                if value is not None and hasattr(document, field):
                    old_value = getattr(document, field)
                    setattr(document, field, value)
                    update_details[f"old_{field}"] = old_value
                    update_details[f"new_{field}"] = value

            self.db.commit()
            self.db.refresh(document)


            # Delete old file if it was replaced
            if old_file_url:
                await self._delete_from_s3(old_file_url)

            # Single analytics entry for update
            if self.user and self.request:
                self.analytics_service.track_event(
                    event_type="document_updated",
                    user=self.user,
                    event_category="document",
                    properties={"document_id": document_id},
                    request=self.request
                )

            if old_file_url:
                await self._delete_from_s3(old_file_url)

            return document

        except Exception as e:
            if file and 'file_url' in locals():
                await self._delete_from_s3(file_url)
            
            if self.user:
                self.analytics_service.track_event(
                    event_type="document_update_failed",
                    user=self.user,
                    event_category="error",
                    properties={
                        "document_id": document_id,
                        "error": str(e),
                        "attempted_changes": document_in
                    },
                    request=self.request
                )
            raise

    async def delete_document(
        self,
        db: Session,
        document_id: str,
        owner_id: str
    ) -> None:
        """Delete a document with improved error handling"""
        try:
            document = self.get_document(db, document_id, owner_id)
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Starting delete for document ID: {document_id}")
                print(f"Document file path: {document.file_path}")

            # Store file path before deleting from database
            file_path = document.file_path

            if settings.DEBUG_S3_OPERATIONS:
                print("Deleting document from database...")

            # Delete from database first
            db.delete(document)
            db.commit()

            # Single analytics entry for deletion
            if self.user and self.request:
                self.analytics_service.track_event(
                    event_type="document_deleted",
                    user=self.user,
                    event_category="document",
                    properties={"document_id": document_id},
                    request=self.request
                )

            if settings.DEBUG_S3_OPERATIONS:
                print("Successfully deleted from database")

            # Then try to delete from S3
            if file_path:
                if settings.DEBUG_S3_OPERATIONS:
                    print(f"Now deleting from S3: {file_path}")
                await self._delete_from_s3(file_path)

        except Exception as e:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Error during document deletion: {str(e)}")
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error deleting document: {str(e)}"
            )

    async def generate_download_url(
        self,
        file_url: str,
        document_id: str,
        expires_in: int = 3600
    ) -> str:
        """Generate download URL with tracking"""
        try:
            if not file_url:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No file URL provided"
                )

            # Extract key from URL
            key = file_url.split(f"{self.bucket_name}.s3.{settings.AWS_REGION}.amazonaws.com/")[1]
            
            # Generate presigned URL
            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={
                    'Bucket': self.bucket_name,
                    'Key': key
                },
                ExpiresIn=expires_in
            )

            if self.user:
                self.analytics_service.track_event(
                    event_type="download_url_generated",
                    user=self.user,
                    event_category="document",
                    properties={
                        "document_id": document_id,
                        "expiry_seconds": expires_in
                    },
                    request=self.request
                )

            return url
            
        except Exception as e:
            if self.user:
                self.analytics_service.track_event(
                    event_type="download_url_generation_failed",
                    user=self.user,
                    event_category="error",
                    properties={
                        "document_id": document_id,
                        "error": str(e)
                    },
                    request=self.request
                )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error generating download URL: {str(e)}"
            )