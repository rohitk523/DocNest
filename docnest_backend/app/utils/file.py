# app/utils/file.py
import os
from datetime import datetime
from fastapi import UploadFile, HTTPException, status
from typing import Optional
import magic
from app.core.config import settings

def save_upload_file(file: UploadFile, user_id: str) -> tuple[str, int, str]:
    """
    Save an uploaded file and return its path, size, and type.
    
    Returns:
        tuple: (file_path, file_size, file_type)
    """
    # Check file size
    file.file.seek(0, 2)
    size = file.file.tell()
    file.file.seek(0)
    
    if size > settings.MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size is {settings.MAX_FILE_SIZE/1024/1024}MB"
        )

    # Get file extension and check if it's allowed
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File type not allowed"
        )

    # Create unique filename and save
    filename = f"{user_id}_{datetime.utcnow().timestamp()}{ext}"
    file_path = os.path.join(settings.UPLOAD_DIR, filename)
    
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    
    with open(file_path, "wb") as buffer:
        file.file.seek(0)
        while chunk := file.file.read(8192):
            buffer.write(chunk)

    # Get file type using python-magic
    file_type = magic.from_file(file_path, mime=True)
    
    return file_path, size, file_type