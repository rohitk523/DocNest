# app/services/analytics_service.py
from typing import Optional, Dict, Any
from fastapi import Request
from sqlalchemy.orm import Session
from ..models.analytics_event import AnalyticsEvent
from ..models.user import User
import json

class AnalyticsService:
    def __init__(self, db: Session):
        self.db = db

    def track_event(
        self,
        event_type: str,
        user: Optional[User] = None,
        event_category: Optional[str] = None,
        properties: Optional[Dict[str, Any]] = None,
        session_id: Optional[str] = None,
        request: Optional[Request] = None,
        duration: Optional[int] = None
    ) -> AnalyticsEvent:
        """
        Track an analytics event
        
        Args:
            event_type: Type of event being tracked
            user: User associated with the event
            event_category: Category of the event
            properties: Event-specific properties
            session_id: Session identifier
            request: FastAPI request object for device info
            duration: Duration of the event in milliseconds
        """
        device_info = {}
        
        if request:
            device_info = {
                "ip": request.client.host,
                "user_agent": request.headers.get("user-agent"),
                "referer": request.headers.get("referer"),
                "language": request.headers.get("accept-language")
            }

        event = AnalyticsEvent(
            user_id=user.id if user else None,
            event_type=event_type,
            event_category=event_category,
            properties=properties or {},
            session_id=session_id,
            device_info=device_info,
            duration=duration
        )
        
        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        
        return event