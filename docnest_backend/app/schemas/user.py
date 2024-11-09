# app/schemas/user.py
from pydantic import BaseModel, EmailStr, HttpUrl
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserCreateGoogle(UserBase):
    google_user_id: str
    profile_picture: Optional[HttpUrl] = None

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    profile_picture: Optional[HttpUrl] = None

class UserInDB(UserBase):
    id: str
    is_active: bool
    is_google_user: bool
    created_at: datetime
    last_login: Optional[datetime]

    class Config:
        from_attributes = True

class UserResponse(UserInDB):
    pass

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: Optional[UserResponse] = None

    class Config:
        json_schema_extra = {
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer",
                "user": {
                    "id": "123",
                    "email": "user@example.com",
                    "full_name": "John Doe",
                    "is_active": True,
                    "is_google_user": False,
                    "created_at": "2024-01-01T00:00:00",
                    "last_login": "2024-01-01T00:00:00"
                }
            }
        }