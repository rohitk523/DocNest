from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
from ....db.session import get_db
from ....core.auth import get_current_user
from ....schemas.document import DocumentCreate, DocumentResponse, DocumentUpdate
from ....services.document import DocumentService
from ....models.document import DocumentType

api_router = APIRouter()

# Document routes
@api_router.post("/documents/", response_model=DocumentResponse)
async def create_document(
    *,
    db: Session = Depends(get_db),
    document_in: DocumentCreate,
    file: Optional[UploadFile] = File(None),
    current_user = Depends(get_current_user)
):
    """Create a new document."""
    document_service = DocumentService()
    return await document_service.create_document(
        db=db,
        owner_id=current_user.id,
        document_in=document_in,
        file=file
    )

@api_router.get("/documents/", response_model=List[DocumentResponse])
def get_user_documents(
    *,
    db: Session = Depends(get_db),
    category: Optional[DocumentType] = None,
    current_user = Depends(get_current_user)
):
    """Get all documents for current user."""
    document_service = DocumentService()
    return document_service.get_user_documents(
        db=db,
        owner_id=current_user.id,
        category=category
    )

@api_router.get("/documents/{document_id}", response_model=DocumentResponse)
def get_document(
    *,
    db: Session = Depends(get_db),
    document_id: str,
    current_user = Depends(get_current_user)
):
    """Get a specific document."""
    document_service = DocumentService()
    return document_service.get_document(
        db=db,
        document_id=document_id,
        owner_id=current_user.id
    )

@api_router.put("/documents/{document_id}", response_model=DocumentResponse)
async def update_document(
    *,
    db: Session = Depends(get_db),
    document_id: str,
    document_in: DocumentUpdate,
    file: Optional[UploadFile] = File(None),
    current_user = Depends(get_current_user)
):
    """Update a document."""
    document_service = DocumentService()
    return await document_service.update_document(
        db=db,
        document_id=document_id,
        owner_id=current_user.id,
        document_in=document_in,
        file=file
    )

@api_router.delete("/documents/{document_id}")
async def delete_document(
    *,
    db: Session = Depends(get_db),
    document_id: str,
    current_user = Depends(get_current_user)
):
    """Delete a document."""
    document_service = DocumentService()
    await document_service.delete_document(
        db=db,
        document_id=document_id,
        owner_id=current_user.id
    )
    return {"status": "success"}