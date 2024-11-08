# app/api/v1/auth_router.py
from app.core.auth import get_password_hash
from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import datetime
from app.models.user import User
from app.db.session import get_db
from app.core.auth import (
    authenticate_user,
    create_access_token,
    create_refresh_token,
    get_current_user
)
from app.schemas.user import UserCreate, UserResponse
from app.services.google_auth_service import GoogleAuthService

auth_router = APIRouter()

@auth_router.post("/login")
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """Login with username and password"""
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Update last login
    user.last_login = datetime.utcnow()
    db.commit()

    return {
        "access_token": create_access_token(data={"sub": user.id}),
        "token_type": "bearer"
    }

@auth_router.post("/register", response_model=UserResponse)
async def register(
    *,
    db: Session = Depends(get_db),
    user_in: UserCreate
):
    """Register a new user"""
    # Check if user exists
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    user = User(
        email=user_in.email,
        hashed_password=get_password_hash(user_in.password),
        full_name=user_in.full_name,
        is_active=True,
        is_google_user=False
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

@auth_router.get("/me", response_model=UserResponse)
async def read_users_me(current_user = Depends(get_current_user)):
    """Get current user"""
    return current_user

@auth_router.post("/google/signin", response_model=dict)
async def google_signin(
    token: str = Body(..., embed=True),
    db: Session = Depends(get_db)
):
    """
    Handle Google Sign-in
    
    Args:
        token: The ID token obtained from Google Sign-in on the client side
        
    Returns:
        dict: Contains access token and user info
    """
    try:
        google_service = GoogleAuthService()
        # Verify the Google token
        user_data = await google_service.verify_google_token(token)
        
        # Get or create user
        user = await google_service.get_or_create_user(db, user_data)
        
        # Create access token
        access_token = create_access_token(data={"sub": user.id})
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": UserResponse.model_validate(user)
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate Google credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

@auth_router.post("/refresh")
async def refresh_token(
    current_user: User = Depends(get_current_user),
):
    """
    Refresh access token
    """
    access_token = create_access_token(data={"sub": current_user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

@auth_router.post("/logout")
async def logout(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Logout user
    """
    # Update last login time
    current_user.last_login = datetime.utcnow()
    db.commit()
    
    return {"message": "Successfully logged out"}