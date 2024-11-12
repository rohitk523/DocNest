# app/api/v1/router.py
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from app.db.session import get_db
from app.core.auth import get_current_user
from app.schemas.document import DocumentCreate, DocumentResponse, DocumentUpdate
from app.models.document import DocumentType
from app.services.document import DocumentService
from pydantic import parse_obj_as

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
    
    Parameters:
    - **name**: Name of the document (required)
    - **description**: Optional description of the document
    - **category**: Document category (GOVERNMENT, MEDICAL, EDUCATIONAL, OTHER)
    - **file**: The file to upload (PDF, DOC, DOCX, JPG, JPEG, PNG)
    
    Returns:
    - Document object with metadata and file information
    """
    try:
        # Create document data from form fields
        document_data = {
            "name": name,
            "description": description,
            "category": category
        }
        
        # Parse the data into a DocumentCreate object
        document_in = parse_obj_as(DocumentCreate, document_data)
        
        # Initialize document service
        document_service = DocumentService()
        
        # Create document
        document = await document_service.create_document(
            db=db,
            owner_id=current_user.id,
            document_in=document_in,
            file=file
        )
        
        return document
    
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )
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
    document_service = DocumentService()
    documents = document_service.get_user_documents(
        db=db,
        owner_id=current_user.id,
        category=category
    )
    return documents

@api_router.get("/documents/{document_id}", response_model=DocumentResponse)
async def get_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Get a specific document by ID.
    """
    document_service = DocumentService()
    document = document_service.get_document(
        db=db,
        document_id=document_id,
        owner_id=current_user.id
    )
    return document

# app/api/v1/router.py
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
        document_service = DocumentService()
        
        # Create update data dictionary
        update_data = {
            "name": name,
            "description": description,
            "category": category
        }
        
        # Remove None values
        update_data = {k: v for k, v in update_data.items() if v is not None}
        
        document = await document_service.update_document(
            db=db,
            document_id=document_id,
            owner_id=current_user.id,
            document_in=update_data,
            file=file
        )
        
        return document
        
    except Exception as e:
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
    document_service = DocumentService()
    await document_service.delete_document(
        db=db,
        document_id=document_id,
        owner_id=current_user.id
    )