# app/services/document.py
import os
import shutil
from fastapi import UploadFile, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
import magic
from ..models.document import Document, DocumentType
from ..schemas.document import DocumentCreate, DocumentUpdate
from ..core.config import settings

class DocumentService:
    ALLOWED_EXTENSIONS = {'.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png'}
    
    def __init__(self):
        self.upload_dir = settings.UPLOAD_DIR
        os.makedirs(self.upload_dir, exist_ok=True)

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
                detail=f"Error validating file: {str(e)}"
            )

    async def create_document(
        self,
        db: Session,
        owner_id: str,
        document_in: DocumentCreate,
        file: UploadFile
    ) -> Document:
        """Create a new document with file upload"""
        try:
            # Validate file
            self._validate_file(file)
            
            # Create unique filename
            ext = os.path.splitext(file.filename)[1].lower()
            filename = f"{owner_id}_{datetime.utcnow().timestamp()}{ext}"
            file_path = os.path.join(self.upload_dir, filename)
            
            # Save file
            with open(file_path, "wb+") as file_object:
                shutil.copyfileobj(file.file, file_object)
            
            # Get file info
            file_size = os.path.getsize(file_path)
            file_type = magic.from_file(file_path, mime=True)
            
            # Create document in database
            db_document = Document(
                name=document_in.name,
                description=document_in.description,
                category=document_in.category,
                file_path=file_path,
                file_size=file_size,
                file_type=file_type,
                owner_id=owner_id
            )
            
            db.add(db_document)
            db.commit()
            db.refresh(db_document)
            
            return db_document
            
        except Exception as e:
            # Clean up file if database operation fails
            if 'file_path' in locals() and os.path.exists(file_path):
                os.remove(file_path)
            raise e

    def get_document(self, db: Session, document_id: str, owner_id: str) -> Document:
        document = db.query(Document).filter(
            Document.id == document_id,
            Document.owner_id == owner_id
        ).first()
        
        if not document:
            raise HTTPException(status_code=404, detail="Document not found")
        return document

    def get_user_documents(
        self,
        db: Session,
        owner_id: str,
        category: Optional[DocumentType] = None
    ) -> List[Document]:
        query = db.query(Document).filter(Document.owner_id == owner_id)
        
        if category:
            query = query.filter(Document.category == category)
            
        return query.order_by(Document.created_at.desc()).all()


    async def update_document(
        self,
        db: Session,
        document_id: str,
        owner_id: str,
        document_in: dict,  # Changed from DocumentUpdate to dict
        file: Optional[UploadFile] = None
    ) -> Document:
        document = self.get_document(db, document_id, owner_id)

        # Update file if provided
        if file:
            self._validate_file(file)
            
            # Delete old file if exists
            if document.file_path and os.path.exists(document.file_path):
                os.remove(document.file_path)

            # Save new file
            ext = os.path.splitext(file.filename)[1].lower()
            filename = f"{owner_id}_{datetime.utcnow().timestamp()}{ext}"
            file_path = os.path.join(self.upload_dir, filename)
            
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            
            document.file_path = file_path
            document.file_size = os.path.getsize(file_path)
            document.file_type = magic.from_file(file_path, mime=True)
            document.version += 1

        # Update other fields
        # Changed this part to handle dict directly
        for field, value in document_in.items():
            if value is not None:  # Only update non-None values
                setattr(document, field, value)

        db.commit()
        db.refresh(document)
        return document

    async def delete_document(
        self,
        db: Session,
        document_id: str,
        owner_id: str
    ) -> None:
        document = self.get_document(db, document_id, owner_id)
        
        # Delete file if exists
        if document.file_path and os.path.exists(document.file_path):
            os.remove(document.file_path)
            
        db.delete(document)
        db.commit()