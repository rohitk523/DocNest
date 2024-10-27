from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import timedelta
from typing import List
from . import models, schemas, auth
from .database import get_db, engine
from google.oauth2 import id_token
from google.auth.transport import requests

app = FastAPI(title="DocNest API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with actual frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create database tables
models.Base.metadata.create_all(bind=engine)

@app.post("/token", response_model=schemas.Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    user = auth.authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.email},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/auth/google", response_model=schemas.Token)
async def google_auth(token: str, db: Session = Depends(get_db)):
    try:
        idinfo = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            "your-google-client-id"  # Replace with your Google Client ID
        )
        
        user = auth.get_user_by_email(db, idinfo['email'])
        if not user:
            user = auth.create_google_user(
                db,
                schemas.UserGoogle(
                    email=idinfo['email'],
                    full_name=idinfo.get('name', ''),
                    google_id=idinfo['sub']
                )
            )
        
        access_token = auth.create_access_token(data={"sub": user.email})
        return {"access_token": access_token, "token_type": "bearer"}
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google token"
        )

@app.get("/users/me", response_model=schemas.UserResponse)
async def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user

@app.post("/users/", response_model=schemas.User)
async def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = auth.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )
    return auth.create_user(db=db, user=user)