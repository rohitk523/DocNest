from google.oauth2 import id_token
from google.auth.transport import requests
from fastapi import HTTPException, status
from typing import Optional
from ..core.config import settings
from ..models.user import User
from sqlalchemy.orm import Session
from datetime import datetime

class GoogleAuth:
    def __init__(self):
        self.GOOGLE_CLIENT_ID = settings.GOOGLE_CLIENT_ID
        self.GOOGLE_CLIENT_SECRET = settings.GOOGLE_CLIENT_SECRET

    async def verify_google_token(self, token: str) -> dict:
        try:
            idinfo = id_token.verify_oauth2_token(
                token, requests.Request(), self.GOOGLE_CLIENT_ID
            )
            
            if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
                raise ValueError('Wrong issuer.')
                
            return idinfo
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google token"
            )

    async def get_or_create_user(self, db: Session, user_data: dict) -> User:
        google_user_id = user_data['sub']
        email = user_data['email']
        
        # Check if user exists
        user = db.query(User).filter(
            (User.google_user_id == google_user_id) | (User.email == email)
        ).first()
        
        if user:
            # Update last login
            user.last_login = datetime.utcnow()
            db.commit()
            return user
            
        # Create new user
        user = User(
            email=email,
            full_name=user_data.get('name'),
            google_user_id=google_user_id,
            is_google_user=True,
            profile_picture=user_data.get('picture'),
            is_active=True,
            last_login=datetime.utcnow()
        )
        
        db.add(user)
        db.commit()
        db.refresh(user)
        return user