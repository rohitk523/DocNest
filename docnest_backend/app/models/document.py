# app/models/document.py
from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Integer, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from uuid import uuid4
from ..db.base import Base

class Document(Base):
    __tablename__ = "documents"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    file_path = Column(String, nullable=True)
    file_size = Column(Integer, nullable=True)
    file_type = Column(String, nullable=True)
    category = Column(String, nullable=False)  # Changed from Enum to String
    version = Column(Integer, default=1)
    is_shared = Column(Boolean, default=False)
    owner_id = Column(String, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)
    modified_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    owner = relationship("User", back_populates="documents")