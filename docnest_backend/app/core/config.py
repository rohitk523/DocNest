# app/core/config.py
from typing import Optional, List
from pydantic_settings import BaseSettings
import os

class Settings(BaseSettings):
    # Project settings
    PROJECT_NAME: str = "DocNest"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    
    # Database settings
    POSTGRES_SERVER: str = os.getenv("POSTGRES_SERVER", "localhost")
    POSTGRES_USER: str = os.getenv("POSTGRES_USER", "postgres")
    POSTGRES_PASSWORD: str = os.getenv("POSTGRES_PASSWORD")
    POSTGRES_DB: str = os.getenv("POSTGRES_DB", "docnest-db")
    DATABASE_URL: Optional[str] = os.getenv("DATABASE_URL")  # For Render
    SQLALCHEMY_DATABASE_URI: Optional[str] = None

    # JWT settings
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY")
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

    # Google OAuth Settings
    GOOGLE_CLIENT_ID: str = os.getenv("GOOGLE_CLIENT_ID")
    GOOGLE_CLIENT_SECRET: str = os.getenv("GOOGLE_CLIENT_SECRET")
    GOOGLE_REDIRECT_URI: str = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/api/v1/auth/google/callback")

    # File upload settings
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "uploads")
    MAX_FILE_SIZE: int = int(os.getenv("MAX_FILE_SIZE", str(10 * 1024 * 1024)))  # 10MB default
    ALLOWED_EXTENSIONS: List[str] = [".pdf", ".doc", ".docx", ".jpg", ".jpeg", ".png"]
    
    # CORS settings
    ALLOWED_ORIGINS: List[str] = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8000").split(",")

    model_config = {
        "case_sensitive": True,
        "env_file": ".env",
        "extra": "allow"
    }

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # Handle Render's DATABASE_URL if present
        if self.DATABASE_URL:
            self.SQLALCHEMY_DATABASE_URI = self.DATABASE_URL
        else:
            self.SQLALCHEMY_DATABASE_URI = (
                f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
                f"@{self.POSTGRES_SERVER}/{self.POSTGRES_DB}"
            )
        
        # Validate required settings
        self.validate_settings()

    def validate_settings(self):
        """Validate that all required settings are provided."""
        required_settings = {
            "POSTGRES_PASSWORD": self.POSTGRES_PASSWORD,
            "JWT_SECRET_KEY": self.JWT_SECRET_KEY,
            "GOOGLE_CLIENT_ID": self.GOOGLE_CLIENT_ID,
            "GOOGLE_CLIENT_SECRET": self.GOOGLE_CLIENT_SECRET
        }

        missing_settings = [k for k, v in required_settings.items() if not v]
        if missing_settings and self.ENVIRONMENT != "development":
            raise ValueError(f"Missing required settings: {', '.join(missing_settings)}")

settings = Settings()