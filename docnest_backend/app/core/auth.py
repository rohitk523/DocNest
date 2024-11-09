from datetime import datetime, timedelta
from typing import Optional, Union
from fastapi import Depends, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from passlib.context import CryptContext

from app.core.config import settings
from app.db.session import get_db
from app.models.user import User
from app.core.exceptions import (
    TokenValidationError,
    InvalidCredentialsException,
    InactiveUserException,
    GoogleAuthenticationError
)

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 setup
oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/auth/login"
)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against its hash."""
    try:
        return pwd_context.verify(plain_password, hashed_password)
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    """Generate password hash."""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create JWT access token.
    
    Args:
        data: Payload to encode in the token
        expires_delta: Optional custom expiration time
        
    Returns:
        str: Encoded JWT token
    """
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )
    return encoded_jwt

def create_refresh_token(data: dict) -> str:
    """
    Create JWT refresh token.
    
    Args:
        data: Payload to encode in the token
        
    Returns:
        str: Encoded JWT refresh token
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )
    return encoded_jwt

async def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    """
    Get current user from JWT token.
    
    Args:
        db: Database session
        token: JWT token from request
        
    Returns:
        User: Current authenticated user
        
    Raises:
        TokenValidationError: If token is invalid
        InactiveUserException: If user account is inactive
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise TokenValidationError("Invalid token payload")
    except JWTError:
        raise TokenValidationError()

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise TokenValidationError()
    if not user.is_active:
        raise InactiveUserException()
    return user

async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Get current active user.
    
    Args:
        current_user: User from token validation
        
    Returns:
        User: Current active user
        
    Raises:
        InactiveUserException: If user account is inactive
    """
    if not current_user.is_active:
        raise InactiveUserException()
    return current_user

def authenticate_user(
    db: Session,
    email: str,
    password: str
) -> User:
    """
    Authenticate user with email and password.
    
    Args:
        db: Database session
        email: User's email
        password: User's password
        
    Returns:
        User: Authenticated user
        
    Raises:
        InvalidCredentialsException: If credentials are invalid
        InactiveUserException: If user account is inactive
    """
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        raise InvalidCredentialsException()
    if not user.is_active:
        raise InactiveUserException()
    return user

async def verify_google_token(token: str) -> dict:
    """
    Verify Google OAuth token.
    
    Args:
        token: Google OAuth token
        
    Returns:
        dict: User information from Google
        
    Raises:
        GoogleAuthenticationError: If token verification fails
    """
    try:
        # This would use google-auth library in production
        # For now, return mock data
        return {
            "sub": "google_user_id",
            "email": "user@example.com",
            "name": "Test User",
            "picture": "https://example.com/picture.jpg"
        }
    except Exception as e:
        raise GoogleAuthenticationError(str(e))

def create_test_user(db: Session) -> User:
    """
    Create a test user for unit testing.
    
    Args:
        db: Database session
        
    Returns:
        User: Created test user
    """
    user = User(
        email="test@example.com",
        hashed_password=get_password_hash("testpassword"),
        full_name="Test User",
        is_active=True,
        created_at=datetime.utcnow()
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

def get_test_token(user_id: str) -> str:
    """
    Create a test JWT token for unit testing.
    
    Args:
        user_id: User ID to encode in token
        
    Returns:
        str: Test JWT token
    """
    return create_access_token(data={"sub": user_id})