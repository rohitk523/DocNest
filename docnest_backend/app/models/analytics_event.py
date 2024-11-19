# app/models/analytics_event.py
from sqlalchemy import Column, String, DateTime, JSON, ForeignKey, Integer
from sqlalchemy.orm import relationship
from datetime import datetime
from uuid import uuid4
from ..db.base import Base

class AnalyticsEvent(Base):
    __tablename__ = "analytics_events"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id"))
    event_type = Column(String, nullable=False)  # e.g., "document_view", "search"
    event_category = Column(String)  # e.g., "engagement", "error"
    properties = Column(JSON)  # Event-specific data
    session_id = Column(String)
    device_info = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Optional metrics
    duration = Column(Integer)  # Duration in milliseconds if applicable
    
    # Relationships
    user = relationship("User", back_populates="analytics_events")