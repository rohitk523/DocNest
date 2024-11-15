# app/api/v1/router.py

import re
from app.models.user import User
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
from app.db.session import get_db
from app.core.auth import get_current_user
from app.schemas.document import DocumentCreate, DocumentResponse, DocumentUpdate
from app.models.document import DocumentType
from app.services.s3_service import S3Service
from app.models.document import Document
from pydantic import parse_obj_as
import os
from sqlalchemy import func
from app.core.exceptions import CategoryValidationError, CategoryLimitExceeded, CategoryNotFound, CategoryInUse

api_router = APIRouter()

@api_router.post("/documents/", response_model=DocumentResponse)
async def create_document(
    name: str = Form(...),
    description: Optional[str] = Form(None),
    category: DocumentType = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Create a new document with file upload.
    """
    try:
        # Create document data
        document_data = {
            "name": name,
            "description": description,
            "category": category
        }
        document_in = parse_obj_as(DocumentCreate, document_data)
        
        # Initialize S3 service
        s3_service = S3Service()
        
        try:
            # Upload file to S3
            file_path, file_size, file_type = await s3_service.upload_file(
                file, 
                folder=f"documents/{current_user.id}"
            )
            
            # Create document in database
            document = Document(
                name=document_in.name,
                description=document_in.description,
                category=document_in.category,
                file_path=file_path,
                file_size=file_size,
                file_type=file_type,
                owner_id=current_user.id
            )
            
            db.add(document)
            db.commit()
            db.refresh(document)
            
            return document
            
        except Exception as e:
            # If database operation fails, clean up the uploaded file
            if 'file_path' in locals():
                await s3_service.delete_file(file_path)
            raise e
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@api_router.get("/documents/", response_model=List[DocumentResponse])
async def list_documents(
    category: Optional[DocumentType] = None,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    List all documents owned by the current user.
    Optionally filter by category.
    """
    query = db.query(Document).filter(Document.owner_id == current_user.id)
    if category:
        query = query.filter(Document.category == category)
    return query.order_by(Document.created_at.desc()).all()

@api_router.get("/documents/{document_id}", response_model=DocumentResponse)
async def get_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Get a specific document by ID.
    """
    document = db.query(Document).filter(
        Document.id == document_id,
        Document.owner_id == current_user.id
    ).first()
    
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    return document

@api_router.put("/documents/{document_id}", response_model=DocumentResponse)
async def update_document(
    document_id: str,
    name: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    category: Optional[DocumentType] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Update a document. All fields are optional.
    """
    try:
        # Get existing document
        document = db.query(Document).filter(
            Document.id == document_id,
            Document.owner_id == current_user.id
        ).first()
        
        if not document:
            raise HTTPException(status_code=404, detail="Document not found")

        # Initialize S3 service
        s3_service = S3Service()
        old_file_path = None

        # Update file if provided
        if file:
            try:
                # Store old file path for cleanup
                old_file_path = document.file_path
                
                # Upload new file
                file_path, file_size, file_type = await s3_service.upload_file(
                    file,
                    folder=f"documents/{current_user.id}"
                )
                
                # Update document with new file info
                document.file_path = file_path
                document.file_size = file_size
                document.file_type = file_type
                document.version += 1
                
            except Exception as e:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Error uploading file: {str(e)}"
                )

        # Update other fields if provided
        if name is not None:
            document.name = name
        if description is not None:
            document.description = description
        if category is not None:
            document.category = category

        db.commit()
        db.refresh(document)

        # Delete old file if it was replaced
        if old_file_path:
            await s3_service.delete_file(old_file_path)

        return document
        
    except Exception as e:
        # Clean up new file if database operation failed
        if file and 'file_path' in locals():
            await s3_service.delete_file(file_path)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@api_router.delete("/documents/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Delete a document.
    """
    document = db.query(Document).filter(
        Document.id == document_id,
        Document.owner_id == current_user.id
    ).first()
    
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")

    try:
        # Store file path before deleting from database
        file_path = document.file_path
        
        # Delete from database
        db.delete(document)
        db.commit()
        
        # Delete file from S3 if it exists
        if file_path:
            s3_service = S3Service()
            await s3_service.delete_file(file_path)
            
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error deleting document: {str(e)}"
        )

@api_router.get("/documents/{document_id}/download")
async def download_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
) -> StreamingResponse:
    """
    Download a document from S3 using document name as filename
    """
    document = db.query(Document).filter(
        Document.id == document_id,
        Document.owner_id == current_user.id
    ).first()
    
    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document not found"
        )
        
    if not document.file_path:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No file associated with this document"
        )

    try:
        s3_service = S3Service()
        file_content, content_type, content_length = await s3_service.download_file(
            document.file_path
        )

        # Get extension from the S3 file path
        ext = os.path.splitext(document.file_path)[-1]
        
        # Create filename from document name and original extension
        filename = f"{document.name}{ext}"
        
        # Clean filename to be safe for downloads (remove any potentially unsafe characters)
        safe_filename = "".join(c for c in filename if c.isalnum() or c in "._- ")

        return StreamingResponse(
            file_content,
            media_type=content_type,
            headers={
                'Content-Disposition': f'attachment; filename="{safe_filename}"',
                'Content-Length': str(content_length)
            }
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

@api_router.get("/documents/{document_id}/share")
async def get_document_share_info(
    document_id: str,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get document sharing information including metadata and download URL
    """
    document = db.query(Document).filter(
        Document.id == document_id,
        Document.owner_id == current_user.id
    ).first()
    
    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document not found"
        )

    try:
        # Generate temporary download URL if file exists
        download_url = None
        if document.file_path:
            s3_service = S3Service()
            download_url = await s3_service.generate_presigned_url(
                document.file_path,
                expires_in=3600  # URL expires in 1 hour
            )

        # Get extension from the file path
        ext = os.path.splitext(document.file_path)[-1] if document.file_path else ''
        
        share_info = {
            "name": f"{document.name}{ext}",  # Include extension in the name
            "description": document.description,
            "category": document.category,
            "file_type": document.file_type,
            "file_size": document.file_size,
            "created_at": document.created_at.isoformat(),
            "modified_at": document.modified_at.isoformat(),
            "download_url": download_url,
            "metadata": {
                "version": document.version,
                "owner": current_user.full_name or current_user.email
            }
        }

        return share_info

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
    

# Add new category management endpoints
@api_router.get("/categories", response_model=List[str])
async def get_categories(
    current_user: User = Depends(get_current_user),
):
    """
    Get all categories (both default and custom) for the current user
    """
    default_categories = ["government", "medical", "educational", "other"]
    return default_categories + (current_user.custom_categories or [])

@api_router.post("/categories/{category_name}")
async def add_category(
    category_name: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> dict:
    """
    Add a new custom category
    """
    # Validate category name
    category_name = category_name.lower().strip()
    if not re.match(r'^[a-z0-9][a-z0-9\s-_]{0,28}[a-z0-9]$', category_name):
        raise CategoryValidationError(
            "Category name must be 2-30 characters, containing only letters, numbers, spaces, hyphens, and underscores"
        )

    # Check if category already exists
    default_categories = ["government", "medical", "educational", "other"]
    if category_name in default_categories:
        raise CategoryValidationError("Cannot add default category")

    custom_categories = current_user.custom_categories or []
    if category_name in custom_categories:
        raise CategoryValidationError("Category already exists")

    # Check category limit
    if len(custom_categories) >= 20:
        raise CategoryLimitExceeded()

    # Add new category
    custom_categories.append(category_name)
    current_user.custom_categories = custom_categories
    db.commit()

    return {"message": f"Category '{category_name}' added successfully"}

@api_router.delete("/categories/{category_name}")
async def delete_category(
    category_name: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> dict:
    """
    Delete a custom category
    """
    category_name = category_name.lower().strip()
    
    # Verify category exists and is custom
    default_categories = ["government", "medical", "educational", "other"]
    if category_name in default_categories:
        raise CategoryValidationError("Cannot delete default category")

    custom_categories = current_user.custom_categories or []
    if category_name not in custom_categories:
        raise CategoryNotFound()

    # Check if category is in use
    documents_count = db.query(func.count(Document.id))\
        .filter(
            Document.owner_id == current_user.id,
            Document.category == category_name
        ).scalar()

    if documents_count > 0:
        raise CategoryInUse()

    # Remove category
    custom_categories.remove(category_name)
    current_user.custom_categories = custom_categories
    db.commit()

    return {"message": f"Category '{category_name}' deleted successfully"}

@api_router.put("/categories/{old_category_name}")
async def rename_category(
    old_category_name: str,
    new_category_name: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> dict:
    """
    Rename a custom category
    """
    old_category_name = old_category_name.lower().strip()
    new_category_name = new_category_name.lower().strip()

    # Validate new category name
    if not re.match(r'^[a-z0-9][a-z0-9\s-_]{0,28}[a-z0-9]$', new_category_name):
        raise CategoryValidationError(
            "Category name must be 2-30 characters, containing only letters, numbers, spaces, hyphens, and underscores"
        )

    # Verify old category exists and is custom
    default_categories = ["government", "medical", "educational", "other"]
    if old_category_name in default_categories:
        raise CategoryValidationError("Cannot rename default category")

    custom_categories = current_user.custom_categories or []
    if old_category_name not in custom_categories:
        raise CategoryNotFound()

    # Check if new name already exists
    if new_category_name in default_categories or new_category_name in custom_categories:
        raise CategoryValidationError("Category name already exists")

    # Update category name in user's custom categories
    custom_categories[custom_categories.index(old_category_name)] = new_category_name
    current_user.custom_categories = custom_categories

    # Update category name in all relevant documents
    documents = db.query(Document)\
        .filter(
            Document.owner_id == current_user.id,
            Document.category == old_category_name
        ).all()

    for doc in documents:
        doc.category = new_category_name

    db.commit()

    return {
        "message": f"Category renamed from '{old_category_name}' to '{new_category_name}' successfully",
        "documents_updated": len(documents)
    }