from typing import List, Optional, Dict, Any
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import ValidationError

from app.core.auth import (
    authenticate_user,
    create_access_token,
    create_refresh_token,
    get_current_user,
    get_password_hash


)
from app.core.exceptions import CategoryLimitExceeded, CategoryValidationError
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, TokenResponse
from app.db.session import get_db
from app.services.google_auth_service import GoogleAuthService
from app.core.exceptions import (
    InvalidCredentialsException,
    UserAlreadyExistsException,
    GoogleAuthenticationError,
    CategoryLimitExceeded
)

auth_router = APIRouter()

@auth_router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
) -> Dict[str, str]:
    try:
        user = authenticate_user(db, form_data.username, form_data.password)
        if not user:
            raise InvalidCredentialsException()

        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Inactive user account"
            )

        # Update last login
        user.last_login = datetime.utcnow()
        db.commit()

        return {
            "access_token": create_access_token(data={"sub": user.id}),
            "token_type": "bearer",
            "user": user  # User model now includes custom_categories
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )


@auth_router.post("/google/signin", response_model=TokenResponse)
async def google_signin(
    token: str = Body(..., embed=True),
    db: Session = Depends(get_db)
) -> Dict[str, Any]:
    try:
        google_service = GoogleAuthService()
        user_data = await google_service.verify_google_token(token)
        user = await google_service.get_or_create_user(db, user_data)
        
        user.last_login = datetime.utcnow()
        db.commit()
        
        access_token = create_access_token(data={"sub": user.id})
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": user  # User model now includes custom_categories
        }
    except Exception as e:
        raise GoogleAuthenticationError(str(e))


# @auth_router.post("/register", response_model=UserResponse)
# async def register(
#     *,
#     db: Session = Depends(get_db),
#     user_in: UserCreate
# ) -> User:
#     """
#     Register a new user
    
#     Args:
#         db: Database session
#         user_in: User creation data
        
#     Returns:
#         Created user object
        
#     Raises:
#         UserAlreadyExistsException: If email is already registered
#     """
#     try:
#         # Check if user exists
#         existing_user = db.query(User).filter(User.email == user_in.email).first()
#         if existing_user:
#             raise UserAlreadyExistsException()

#         user = User(
#             email=user_in.email,
#             hashed_password=get_password_hash(user_in.password),
#             full_name=user_in.full_name,
#             is_active=True,
#             is_google_user=False,
#             created_at=datetime.utcnow()
#         )
#         db.add(user)
#         db.commit()
#         db.refresh(user)
#         return user
#     except ValidationError as e:
#         raise HTTPException(
#             status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
#             detail=str(e)
#         )
#     except Exception as e:
#         db.rollback()
#         raise HTTPException(
#             status_code=status.HTTP_400_BAD_REQUEST,
#             detail=str(e)
#         )


@auth_router.get("/me", response_model=UserResponse)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> User:
    """
    Get current user's profile information
    
    Returns:
        User: Current user's profile data including custom categories
    """
    try:
        # Refresh user data from database
        db.refresh(current_user)
        
        # Ensure custom_categories is initialized
        if current_user.custom_categories is None:
            current_user.custom_categories = []
            db.commit()
            
        return current_user
    except Exception as e:
        print(f"Error fetching user profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching user profile: {str(e)}"
        )

@auth_router.put("/me", response_model=UserResponse)
async def update_user_profile(
    *,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    custom_categories: List[str] = Body(None),
) -> User:
    """
    Update current user's profile including custom categories
    
    Args:
        custom_categories: List of custom category names
        
    Returns:
        User: Updated user profile
        
    Raises:
        CategoryLimitExceeded: If custom categories exceed limit
        CategoryValidationError: If category names are invalid
    """
    MAX_CUSTOM_CATEGORIES = 20
    
    try:
        if custom_categories is not None:
            # Validate categories length
            if len(custom_categories) > MAX_CUSTOM_CATEGORIES:
                raise CategoryLimitExceeded()
            
            # Validate individual categories
            for category in custom_categories:
                if len(category.strip()) < 2:
                    raise CategoryValidationError(
                        "Category names must be at least 2 characters long"
                    )
                if not category.strip().replace(" ", "").isalnum():
                    raise CategoryValidationError(
                        "Category names can only contain letters, numbers, and spaces"
                    )
            
            # Normalize categories
            normalized_categories = [cat.lower().strip() for cat in custom_categories]
            
            # Update user's custom categories
            current_user.custom_categories = normalized_categories
            current_user.modified_at = datetime.utcnow()
            
        db.commit()
        db.refresh(current_user)
        return current_user
        
    except (CategoryLimitExceeded, CategoryValidationError) as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        print(f"Error updating user profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error updating profile: {str(e)}"
        )


@auth_router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    current_user: User = Depends(get_current_user),
) -> Dict[str, str]:
    """
    Refresh access token for current user
    
    Args:
        current_user: Current authenticated user from token
        
    Returns:
        Dict containing new access token and token type
    """
    try:
        access_token = create_access_token(data={"sub": current_user.id})
        return {
            "access_token": access_token,
            "token_type": "bearer"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@auth_router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, str]:
    """
    Logout current user and update last login time
    
    Args:
        current_user: Current authenticated user from token
        db: Database session
        
    Returns:
        Success message
    """
    try:
        # Update last login time
        current_user.last_login = datetime.utcnow()
        db.commit()
        return {"message": "Successfully logged out"}
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )