# app/services/activity_logger.py
from typing import Optional, Dict, Any
from fastapi import Request
from sqlalchemy.orm import Session
from ..models.activity_log import ActivityLog
from ..models.user import User

class ActivityLogger:
    def __init__(self, db: Session):
        self.db = db

    async def log_activity(
        self,
        user: User,
        action: str,
        resource_type: str,
        resource_id: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
        request: Optional[Request] = None
    ) -> ActivityLog:
        """
        Log a user activity
        
        Args:
            user: The user performing the action
            action: The action being performed
            resource_type: Type of resource being acted upon
            resource_id: ID of the affected resource
            details: Additional context about the action
            request: FastAPI request object for IP and user agent
        """
        ip_address = None
        user_agent = None
        
        if request:
            ip_address = request.client.host
            user_agent = request.headers.get("user-agent")

        log_entry = ActivityLog(
            user_id=user.id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            details=details or {},
            ip_address=ip_address,
            user_agent=user_agent
        )
        
        self.db.add(log_entry)
        self.db.commit()
        self.db.refresh(log_entry)
        
        return log_entry
