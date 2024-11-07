# app/schemas/document.py
from pydantic import BaseModel, constr
from typing import Optional
from datetime import datetime
from ..models.document import DocumentType

class DocumentBase(BaseModel):
    name: constr(min_length=1, max_length=255)
    description: Optional[str] = None
    category: DocumentType

class DocumentCreate(DocumentBase):
    pass

class DocumentUpdate(BaseModel):
    name: Optional[constr(min_length=1, max_length=255)] = None
    description: Optional[str] = None
    category: Optional[DocumentType] = None

class DocumentInDB(DocumentBase):
    id: str
    file_path: Optional[str]
    file_size: Optional[int]
    file_type: Optional[str]
    version: int
    is_shared: bool
    owner_id: str
    created_at: datetime
    modified_at: datetime

    class Config:
        from_attributes = True

class DocumentResponse(DocumentInDB):
    pass