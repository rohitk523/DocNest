from google.oauth2 import id_token
from google.auth.transport import requests
from fastapi import HTTPException, status
from datetime import datetime
from typing import Dict, Optional
from sqlalchemy.orm import Session
from app.core.config import settings
from app.models.user import User

class GoogleAuthService:
    @staticmethod
    async def verify_google_token(token: str) -> Dict:
        try:
            idinfo = id_token.verify_oauth2_token(
                token,
                requests.Request(),
                settings.GOOGLE_CLIENT_ID
            )
            
            if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
                raise ValueError('Wrong issuer.')
                
            return idinfo
            
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid Google token: {str(e)}"
            )

    @staticmethod
    async def get_or_create_user(db: Session, user_data: Dict) -> User:
        google_user_id = user_data['sub']
        email = user_data['email']
        
        # Check if user exists
        user = db.query(User).filter(
            (User.google_user_id == google_user_id) | 
            (User.email == email)
        ).first()
        
        if user:
            # Update existing user's last login
            user.last_login = datetime.utcnow()
            if not user.google_user_id:
                user.google_user_id = google_user_id
                user.is_google_user = True
            db.commit()
            return user
            
        # Create new user
        new_user = User(
            email=email,
            full_name=user_data.get('name'),
            google_user_id=google_user_id,
            is_google_user=True,
            profile_picture=user_data.get('picture'),
            is_active=True,
            last_login=datetime.utcnow(),
            hashed_password=""  # Google users don't need a password
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user