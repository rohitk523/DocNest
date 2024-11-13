# app/services/s3_service.py
import boto3
from botocore.exceptions import ClientError
from fastapi import HTTPException, status
from ..core.config import settings
import uuid

class S3Service:
    def __init__(self):
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION
        )
        self.bucket_name = settings.AWS_BUCKET_NAME

    async def upload_file(self, file, folder: str = "documents") -> str:
        """
        Upload a file to S3 bucket
        
        Args:
            file: UploadFile object
            folder: Folder name in S3 bucket
            
        Returns:
            str: S3 URL of the uploaded file
        """
        try:
            # Generate unique filename
            file_extension = file.filename.split('.')[-1]
            unique_filename = f"{folder}/{uuid.uuid4()}.{file_extension}"
            
            # Upload file
            await file.seek(0)
            file_content = await file.read()
            
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=unique_filename,
                Body=file_content,
                ContentType=file.content_type
            )
            
            # Generate S3 URL
            url = f"https://{self.bucket_name}.s3.{settings.AWS_REGION}.amazonaws.com/{unique_filename}"
            return url
            
        except ClientError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error uploading file to S3: {str(e)}"
            )

    async def delete_file(self, file_url: str):
        """
        Delete a file from S3 bucket
        
        Args:
            file_url: S3 URL of the file to delete
        """
        try:
            # Extract key from URL
            key = file_url.split(f"{self.bucket_name}.s3.{settings.AWS_REGION}.amazonaws.com/")[1]
            
            self.s3_client.delete_object(
                Bucket=self.bucket_name,
                Key=key
            )
        except ClientError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error deleting file from S3: {str(e)}"
            )

    async def generate_presigned_url(self, file_url: str, expires_in: int = 3600) -> str:
        """
        Generate a presigned URL for accessing a private S3 object
        
        Args:
            file_url: S3 URL of the file
            expires_in: URL expiration time in seconds
            
        Returns:
            str: Presigned URL
        """
        try:
            key = file_url.split(f"{self.bucket_name}.s3.{settings.AWS_REGION}.amazonaws.com/")[1]
            
            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={
                    'Bucket': self.bucket_name,
                    'Key': key
                },
                ExpiresIn=expires_in
            )
            return url
            
        except ClientError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error generating presigned URL: {str(e)}"
            )