# app/schemas/analytics.py
from pydantic import BaseModel
from typing import Dict, List, Optional, Any
from datetime import datetime

class ActivityLogResponse(BaseModel):
    id: str
    user_id: str
    action: str
    resource_type: str
    resource_id: Optional[str]
    details: Dict[str, Any]
    ip_address: Optional[str]
    user_agent: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

class AnalyticsEventResponse(BaseModel):
    id: str
    user_id: Optional[str]
    event_type: str
    event_category: Optional[str]
    properties: Dict[str, Any]
    session_id: Optional[str]
    device_info: Dict[str, Any]
    duration: Optional[int]
    created_at: datetime

    class Config:
        from_attributes = True

class DailyUserCount(BaseModel):
    date: datetime
    count: int

class AnalyticsSummary(BaseModel):
    event_counts: Dict[str, int]
    avg_request_duration_ms: Optional[int]
    daily_active_users: List[DailyUserCount]