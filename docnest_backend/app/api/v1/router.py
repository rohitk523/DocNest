# app/api/v1/router.py
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any

from app.db.session import get_db
from app.core.auth import get_current_user
from app.models.user import User
from app.schemas.document import DocumentCreate, DocumentResponse
from app.services.document import DocumentService

api_router = APIRouter()

async def get_document_service(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> DocumentService:
    return DocumentService(db=db, user=current_user, request=request)

@api_router.post("/documents/", response_model=DocumentResponse)
async def create_document(
    name: str = Form(...),
    description: Optional[str] = Form(None),
    category: str = Form(...),
    file: UploadFile = File(...),
    document_service: DocumentService = Depends(get_document_service)
):
    """Create a new document with file upload."""
    try:
        document_in = DocumentCreate(
            name=name,
            description=description,
            category=category.lower().strip()
        )
        
        return await document_service.create_document(
            owner_id=document_service.user.id,
            document_in=document_in,
            file=file
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@api_router.get("/documents/", response_model=List[DocumentResponse])
async def list_documents(
    category: Optional[str] = None,
    document_service: DocumentService = Depends(get_document_service)
):
    """List all documents owned by the current user."""
    return await document_service.get_user_documents(
        owner_id=document_service.user.id,
        category=category
    )

@api_router.get("/documents/{document_id}", response_model=DocumentResponse)
async def get_document(
    document_id: str,
    document_service: DocumentService = Depends(get_document_service)
):
    """Get a specific document by ID."""
    return await document_service.get_document(
        document_id=document_id,
        owner_id=document_service.user.id
    )

@api_router.put("/documents/{document_id}", response_model=DocumentResponse)
async def update_document(
    document_id: str,
    name: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    document_service: DocumentService = Depends(get_document_service)
):
    """Update a document. All fields are optional."""
    try:
        document_updates = {
            "name": name,
            "description": description,
            "category": category.lower().strip() if category else None
        }
        # Remove None values
        document_updates = {k: v for k, v in document_updates.items() if v is not None}
        
        return await document_service.update_document(
            document_id=document_id,
            owner_id=document_service.user.id,
            document_in=document_updates,
            file=file
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@api_router.delete("/documents/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: str,
    document_service: DocumentService = Depends(get_document_service)
):
    """Delete a document."""
    await document_service.delete_document(
        document_id=document_id,
        owner_id=document_service.user.id
    )

@api_router.get("/documents/{document_id}/download")
async def download_document(
    document_id: str,
    document_service: DocumentService = Depends(get_document_service)
) -> StreamingResponse:
    """Download a document from S3."""
    try:
        document = await document_service.get_document(
            document_id=document_id,
            owner_id=document_service.user.id
        )
        
        if not document.file_path:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No file associated with this document"
            )

        stream, content_type, content_length = await document_service.get_file_stream(
            document.file_path
        )

        filename = document_service.get_safe_filename(document.name, document.file_path)

        return StreamingResponse(
            stream,
            media_type=content_type,
            headers={
                'Content-Disposition': f'attachment; filename="{filename}"',
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
    document_service: DocumentService = Depends(get_document_service)
) -> Dict[str, Any]:
    """Get document sharing information."""
    return await document_service.get_share_info(
        document_id=document_id,
        owner_id=document_service.user.id
    )

@api_router.get("/categories")
async def get_categories(
    document_service: DocumentService = Depends(get_document_service)
):
    """Get all categories for the current user."""
    return await document_service.get_user_categories()

@api_router.post("/categories/{category_name}", status_code=status.HTTP_201_CREATED)
async def add_category(
    category_name: str,
    document_service: DocumentService = Depends(get_document_service)
) -> dict:
    """Add a new custom category."""
    return await document_service.add_category(category_name)

@api_router.put("/categories/{old_category_name}")
async def rename_category(
    old_category_name: str,
    new_category_name: str,
    document_service: DocumentService = Depends(get_document_service)
) -> dict:
    """Rename a custom category."""
    return await document_service.rename_category(
        old_category_name=old_category_name,
        new_category_name=new_category_name
    )