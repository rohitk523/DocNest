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
from app.core.exceptions import CategoryInUse, CategoryLimitExceeded, CategoryNotFound, CategoryValidationError
from ..models.document import Document
from ..models.user import User
from ..schemas.document import DocumentCreate, DocumentUpdate
from ..core.config import settings
from ..services.activity_logger import ActivityLogger
from ..services.analytics_service import AnalyticsService
from fastapi.responses import StreamingResponse
import re
from typing import List, Dict, Any, Tuple

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

    # ... [Previous S3 and helper methods remain unchanged] ...
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
        
    async def get_file_stream(
        self,
        file_path: str
    ) -> Tuple[StreamingResponse, str, int]:
        """Get file stream for downloading."""
        try:
            # Track file download
            if self.user and self.request:
                self.analytics_service.track_event(
                    event_type="document_download",
                    user=self.user,
                    event_category="document",
                    properties={"file_path": file_path},
                    request=self.request
                )

            # Get file content, type, and size from S3
            content, content_type, content_length = await self._download_from_s3(file_path)
            return content, content_type, content_length

        except Exception as e:
            if self.user:
                self.analytics_service.track_event(
                    event_type="document_download_failed",
                    user=self.user,
                    event_category="error",
                    properties={"error": str(e), "file_path": file_path},
                    request=self.request
                )
            raise

    async def _download_from_s3(
        self,
        file_path: str
    ) -> Tuple[StreamingResponse, str, int]:
        """Download file from S3."""
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket_name,
                Key=file_path.strip('/')
            )
            
            return (
                StreamingResponse(response['Body']),
                response.get('ContentType', 'application/octet-stream'),
                response.get('ContentLength', 0)
            )
        except ClientError as e:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found"
            )

    def get_safe_filename(self, name: str, file_path: str) -> str:
        """Generate safe filename for download."""
        # Get extension from file path
        ext = os.path.splitext(file_path)[-1]
        
        # Create filename from document name and extension
        filename = f"{name}{ext}"
        
        # Remove any potentially unsafe characters
        safe_filename = "".join(c for c in filename if c.isalnum() or c in "._- ")
        
        return safe_filename

    async def get_share_info(
        self,
        document_id: str,
        owner_id: str
    ) -> Dict[str, Any]:
        """Get document sharing information."""
        document = await self.get_document(document_id, owner_id)
        
        # Generate download URL if file exists
        download_url = None
        if document.file_path:
            download_url = await self.generate_download_url(
                document.file_path,
                document_id
            )

        # Get file extension
        ext = os.path.splitext(document.file_path)[-1] if document.file_path else ''
        
        share_info = {
            "name": f"{document.name}{ext}",
            "description": document.description,
            "category": document.category,
            "file_type": document.file_type,
            "file_size": document.file_size,
            "created_at": document.created_at.isoformat(),
            "modified_at": document.modified_at.isoformat(),
            "download_url": download_url,
            "metadata": {
                "version": document.version,
                "owner": self.user.full_name or self.user.email if self.user else None
            }
        }

        # Track share info view
        if self.user and self.request:
            self.analytics_service.track_event(
                event_type="document_share_info_viewed",
                user=self.user,
                event_category="document",
                properties={"document_id": document_id},
                request=self.request
            )

        return share_info

    async def get_user_categories(self) -> List[str]:
        """Get all categories for the current user."""
        if not self.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )

        default_categories = ["government", "medical", "educational", "other"]
        custom_categories = self.user.custom_categories or []
        
        return default_categories + custom_categories

    async def add_category(self, category_name: str) -> dict:
        """Add a new custom category."""
        if not self.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )

        # Normalize category name
        category_name = category_name.lower().strip()

        # Validate category name
        if not re.match(r'^[a-z0-9][a-z0-9 _-]{0,28}[a-z0-9]$', category_name):
            raise CategoryValidationError(
                "Category name must be 2-30 characters and can only contain letters, "
                "numbers, spaces, hyphens, and underscores. Must start and end with letter or number."
            )

        # Check if default category
        default_categories = {"government", "medical", "educational", "other"}
        if category_name in default_categories:
            raise CategoryValidationError("Cannot add default category")

        # Initialize custom_categories if None
        if self.user.custom_categories is None:
            self.user.custom_categories = []

        # Check if category exists
        if category_name in self.user.custom_categories:
            raise CategoryValidationError("Category already exists")

        # Add category
        self.user.custom_categories.append(category_name)
        self.db.commit()

        # Track category addition
        if self.request:
            self.analytics_service.track_event(
                event_type="category_added",
                user=self.user,
                event_category="category",
                properties={"category_name": category_name},
                request=self.request
            )

        return {"message": f"Category '{category_name}' added successfully"}

    async def rename_category(
        self,
        old_category_name: str,
        new_category_name: str
    ) -> dict:
        """Rename a custom category."""
        if not self.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )

        # Normalize category names
        old_category_name = old_category_name.lower().strip()
        new_category_name = new_category_name.lower().strip()

        # Validate new category name
        if not re.match(r'^[a-z0-9][a-z0-9\s-_]{0,28}[a-z0-9]$', new_category_name):
            raise CategoryValidationError(
                "Category name must be 2-30 characters, containing only letters, "
                "numbers, spaces, hyphens, and underscores"
            )

        # Check if trying to rename default category
        default_categories = ["government", "medical", "educational", "other"]
        if old_category_name in default_categories:
            raise CategoryValidationError("Cannot rename default category")

        # Get user's custom categories
        custom_categories = self.user.custom_categories or []
        if old_category_name not in custom_categories:
            raise CategoryNotFound()

        # Check if new name already exists
        if new_category_name in default_categories or new_category_name in custom_categories:
            raise CategoryValidationError("Category name already exists")

        # Update category name
        custom_categories[custom_categories.index(old_category_name)] = new_category_name
        self.user.custom_categories = custom_categories

        # Update documents with this category
        documents = self.db.query(Document).filter(
            Document.owner_id == self.user.id,
            Document.category == old_category_name
        ).all()

        for doc in documents:
            doc.category = new_category_name

        self.db.commit()

        # Track category rename
        if self.request:
            self.analytics_service.track_event(
                event_type="category_renamed",
                user=self.user,
                event_category="category",
                properties={
                    "old_name": old_category_name,
                    "new_name": new_category_name,
                    "documents_updated": len(documents)
                },
                request=self.request
            )

        return {
            "message": f"Category renamed from '{old_category_name}' to '{new_category_name}' successfully",
            "documents_updated": len(documents)
        }