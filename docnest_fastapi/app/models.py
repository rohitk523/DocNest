from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from .database import Base

class DocumentType(str, enum.Enum):
    GOVERNMENT = "government"
    MEDICAL = "medical"
    EDUCATIONAL = "educational"
    FINANCIAL = "financial"
    PERSONAL = "personal"
    OTHER = "other"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True)  # Nullable for Google OAuth users
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    google_id = Column(String, unique=True, nullable=True)
    profile_picture = Column(String, nullable=True)
    
    # Relationships
    documents = relationship("Document", back_populates="owner")
    folders = relationship("Folder", back_populates="owner")

class Folder(Base):
    __tablename__ = "folders"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    document_type = Column(Enum(DocumentType), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    user_id = Column(Integer, ForeignKey("users.id"))

    # Relationships
    owner = relationship("User", back_populates="folders")
    documents = relationship("Document", back_populates="folder")

class Document(Base):
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    file_path = Column(String, nullable=False)
    file_type = Column(String, nullable=False)  # e.g., pdf, jpg, png
    file_size = Column(Integer, nullable=False)  # in bytes
    document_type = Column(Enum(DocumentType), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    user_id = Column(Integer, ForeignKey("users.id"))
    folder_id = Column(Integer, ForeignKey("folders.id"), nullable=True)

    # Relationships
    owner = relationship("User", back_populates="documents")
    folder = relationship("Folder", back_populates="documents")