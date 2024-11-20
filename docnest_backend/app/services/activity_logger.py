# app/services/activity_logger.py
from typing import Optional, Dict, Any
from fastapi import Request
from sqlalchemy.orm import Session
from ..models.activity_log import ActivityLog
from ..models.user import User

# services/activity_logger.py
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
        try:
            ip_address = None
            user_agent = None
            
            if request:
                ip_address = request.client.host
                user_agent = request.headers.get("user-agent")

            log_entry = ActivityLog(
                user_id=user.id,  # Make sure this gets set
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
            
        except Exception as e:
            self.db.rollback()
            print(f"Error logging activity: {e}")
            # You might want to handle this error differently
            raise
