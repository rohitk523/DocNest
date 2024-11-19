# app/api/v1/analytics_router.py
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
from app.db.session import get_db
from app.core.auth import get_current_user
from app.models.user import User
from app.models.activity_log import ActivityLog
from app.models.analytics_event import AnalyticsEvent
from app.schemas.analytics import (
    ActivityLogResponse,
    AnalyticsEventResponse,
    AnalyticsSummary
)
from sqlalchemy import func, and_, distinct

analytics_router = APIRouter()

@analytics_router.get("/logs", response_model=List[ActivityLogResponse])
async def get_activity_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    action: Optional[str] = None,
    resource_type: Optional[str] = None,
    limit: int = Query(50, le=100),
    offset: int = 0
):
    """Get activity logs with optional filtering"""
    query = db.query(ActivityLog)
    
    if start_date:
        query = query.filter(ActivityLog.created_at >= start_date)
    if end_date:
        query = query.filter(ActivityLog.created_at <= end_date)
    if action:
        query = query.filter(ActivityLog.action == action)
    if resource_type:
        query = query.filter(ActivityLog.resource_type == resource_type)
        
    return query.order_by(ActivityLog.created_at.desc())\
                .offset(offset)\
                .limit(limit)\
                .all()

@analytics_router.get("/events", response_model=List[AnalyticsEventResponse])
async def get_analytics_events(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    event_type: Optional[str] = None,
    event_category: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    limit: int = Query(50, le=100),
    offset: int = 0
):
    """Get analytics events with optional filtering"""
    query = db.query(AnalyticsEvent)
    
    if event_type:
        query = query.filter(AnalyticsEvent.event_type == event_type)
    if event_category:
        query = query.filter(AnalyticsEvent.event_category == event_category)
    if start_date:
        query = query.filter(AnalyticsEvent.created_at >= start_date)
    if end_date:
        query = query.filter(AnalyticsEvent.created_at <= end_date)
        
    return query.order_by(AnalyticsEvent.created_at.desc())\
                .offset(offset)\
                .limit(limit)\
                .all()

@analytics_router.get("/summary", response_model=AnalyticsSummary)
async def get_analytics_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    days: int = Query(30, ge=1, le=365)
):
    """Get analytics summary for the specified time period"""
    start_date = datetime.utcnow() - timedelta(days=days)
    
    # Get event counts by type
    event_counts = db.query(
        AnalyticsEvent.event_type,
        func.count(AnalyticsEvent.id).label('count')
    ).filter(
        AnalyticsEvent.created_at >= start_date
    ).group_by(
        AnalyticsEvent.event_type
    ).all()
    
    # Get average request duration
    avg_duration = db.query(
        func.avg(AnalyticsEvent.duration)
    ).filter(
        and_(
            AnalyticsEvent.event_type == 'api_request',
            AnalyticsEvent.created_at >= start_date
        )
    ).scalar()
    
    # Get daily active users
    daily_users = db.query(
        func.date_trunc('day', ActivityLog.created_at).label('date'),
        func.count(distinct(ActivityLog.user_id)).label('count')
    ).filter(
        ActivityLog.created_at >= start_date
    ).group_by(
        func.date_trunc('day', ActivityLog.created_at)
    ).all()
    
    return {
        'event_counts': dict(event_counts),
        'avg_request_duration_ms': round(avg_duration) if avg_duration else None,
        'daily_active_users': [
            {'date': day.date, 'count': day.count}
            for day in daily_users
        ]
    }