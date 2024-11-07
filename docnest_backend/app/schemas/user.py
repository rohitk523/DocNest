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
