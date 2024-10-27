from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from .models import DocumentType

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserGoogle(UserBase):
    google_id: str

class User(UserBase):
    id: int
    is_active: bool
    is_verified: bool
    created_at: datetime
    profile_picture: Optional[str] = None

    class Config:
        orm_mode = True

class FolderBase(BaseModel):
    name: str
    description: Optional[str] = None
    document_type: DocumentType

class FolderCreate(FolderBase):
    pass

class Folder(FolderBase):
    id: int
    created_at: datetime
    updated_at: datetime
    user_id: int

    class Config:
        orm_mode = True

class DocumentBase(BaseModel):
    title: str
    description: Optional[str] = None
    document_type: DocumentType
    folder_id: Optional[int] = None

class DocumentCreate(DocumentBase):
    file_path: str
    file_type: str
    file_size: int

class Document(DocumentBase):
    id: int
    file_path: str
    file_type: str
    file_size: int
    created_at: datetime
    updated_at: datetime
    user_id: int

    class Config:
        orm_mode = True

class UserResponse(User):
    folders: List[Folder] = []
    documents: List[Document] = []

# Create tables
def init_db():
    Base.metadata.create_all(bind=engine)

# Drop tables
def drop_db():
    Base.metadata.drop_all(bind=engine)