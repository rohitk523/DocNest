# app/services/s3_service.py
from typing import Tuple, Optional
from fastapi import UploadFile, HTTPException, status
import boto3
from botocore.exceptions import ClientError
import uuid
import os
import io
import mimetypes
import magic
from ..core.config import settings

class S3Service:
    def __init__(self):
        """Initialize S3 service with AWS credentials and configuration"""
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION
        )
        self.bucket_name = settings.AWS_BUCKET_NAME

    async def upload_file(
        self, 
        file: UploadFile, 
        folder: str = "documents"
    ) -> Tuple[str, int, str]:
        """
        Upload a file to S3 bucket
        
        Args:
            file: UploadFile object
            folder: Folder name in S3 bucket
            
        Returns:
            Tuple[str, int, str]: (file_path, file_size, file_type)
        """
        try:
            # Generate unique key
            ext = os.path.splitext(file.filename)[1].lower()
            s3_key = f"{folder.strip('/')}/{uuid.uuid4()}{ext}"
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Uploading file to S3: {s3_key}")

            # Read file content
            content = await file.read()
            file_size = len(content)
            file_type = magic.from_buffer(content, mime=True)

            # Upload to S3
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=s3_key,
                Body=content,
                ContentType=file_type
            )

            if settings.DEBUG_S3_OPERATIONS:
                print(f"File uploaded successfully: size={file_size}, type={file_type}")

            # Reset file pointer
            await file.seek(0)
            
            return s3_key, file_size, file_type

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            if settings.DEBUG_S3_OPERATIONS:
                print(f"S3 upload error: Code={error_code}, Message={error_message}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error uploading file to S3: {error_message}"
            )
        except Exception as e:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Unexpected error during upload: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error uploading file: {str(e)}"
            )

    async def delete_file(self, file_path: Optional[str]) -> None:
        """
        Delete a file from S3 bucket
        
        Args:
            file_path: S3 key of the file to delete
        """
        if not file_path:
            if settings.DEBUG_S3_OPERATIONS:
                print("No file path provided for deletion")
            return

        try:
            s3_key = file_path.strip('/')
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Attempting to delete S3 object: {s3_key}")

            # Delete object
            self.s3_client.delete_object(
                Bucket=self.bucket_name,
                Key=s3_key
            )

            if settings.DEBUG_S3_OPERATIONS:
                print(f"Successfully deleted file: {s3_key}")

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"S3 delete error: Code={error_code}, Message={error_message}")
            
            if error_code == 'NoSuchKey':
                if settings.DEBUG_S3_OPERATIONS:
                    print(f"Object already deleted or doesn't exist: {s3_key}")
                return
                
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error deleting file from S3: {error_message}"
            )

    async def download_file(self, file_path: str) -> Tuple[io.BytesIO, str, int]:
        """
        Download a file from S3 bucket
        
        Args:
            file_path: S3 key of the file
            
        Returns:
            Tuple[io.BytesIO, str, int]: (file_content, content_type, content_length)
        """
        try:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Downloading file from S3: {file_path}")

            # Get object from S3
            response = self.s3_client.get_object(
                Bucket=self.bucket_name,
                Key=file_path.strip('/')
            )

            # Read content
            file_content = response['Body'].read()
            content_type = response.get('ContentType', 
                mimetypes.guess_type(file_path)[0] or 'application/octet-stream'
            )
            content_length = response.get('ContentLength', len(file_content))

            if settings.DEBUG_S3_OPERATIONS:
                print(f"File downloaded successfully: type={content_type}, size={content_length}")

            return io.BytesIO(file_content), content_type, content_length

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            
            if settings.DEBUG_S3_OPERATIONS:
                print(f"S3 download error: Code={error_code}, Message={error_message}")

            if error_code == 'NoSuchKey':
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="File not found in storage"
                )
                
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error downloading file: {error_message}"
            )

    async def generate_presigned_url(
        self, 
        file_path: str, 
        expires_in: int = 3600
    ) -> str:
        """
        Generate a presigned URL for accessing a private S3 object
        
        Args:
            file_path: S3 key of the file
            expires_in: URL expiration time in seconds
            
        Returns:
            str: Presigned URL
        """
        try:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Generating presigned URL for: {file_path}")

            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={
                    'Bucket': self.bucket_name,
                    'Key': file_path.strip('/')
                },
                ExpiresIn=expires_in
            )

            if settings.DEBUG_S3_OPERATIONS:
                print(f"Generated presigned URL successfully")

            return url

        except ClientError as e:
            error_message = e.response.get('Error', {}).get('Message', str(e))
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Error generating presigned URL: {error_message}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error generating download URL: {error_message}"
            )

    async def verify_bucket_access(self) -> bool:
        """Verify S3 bucket access permissions"""
        try:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Verifying access to bucket: {self.bucket_name}")

            # Test listing objects
            self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                MaxKeys=1
            )

            return True

        except ClientError as e:
            if settings.DEBUG_S3_OPERATIONS:
                print(f"Error verifying bucket access: {str(e)}")
            return False