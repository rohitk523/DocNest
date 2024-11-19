from sqlalchemy import Boolean, Column, String, DateTime, ARRAY
from sqlalchemy.orm import relationship
from datetime import datetime
from uuid import uuid4
from ..db.base import Base

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True)  # Nullable for Google users
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    is_google_user = Column(Boolean, default=False)
    google_user_id = Column(String, unique=True, nullable=True)
    profile_picture = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)
    custom_categories = Column(ARRAY(String), default=list, nullable=True)
    
    # Import relationships at the end to avoid circular imports
    documents = relationship("Document", back_populates="owner", cascade="all, delete-orphan")
    
    # These will be initialized after all models are loaded
    activity_logs = relationship(
        "ActivityLog",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="dynamic"
    )
    analytics_events = relationship(
        "AnalyticsEvent",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="dynamic"
    )