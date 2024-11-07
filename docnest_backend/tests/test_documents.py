import pytest
from fastapi import UploadFile
from pathlib import Path
import io

def test_create_document(client, test_user):
    headers = {"Authorization": f"Bearer {test_user['token']}"}
    
    # Test document creation without file
    response = client.post(
        "/api/v1/documents/",
        headers=headers,
        json={
            "name": "Test Document",
            "description": "Test Description",
            "category": "GOVERNMENT"
        }
    )
    assert response.status_code == 200
    assert response.json()["name"] == "Test Document"

    # Test document creation with file
    file_content = b"test file content"
    files = {
        "file": ("test.pdf", io.BytesIO(file_content), "application/pdf")
    }
    data = {
        "name": "Test Document with File",
        "description": "Test Description",
        "category": "GOVERNMENT"
    }
    
    response = client.post(
        "/api/v1/documents/",
        headers=headers,
        data=data,
        files=files
    )
    assert response.status_code == 200
    assert response.json()["file_type"] == "application/pdf"

def test_get_documents(client, test_user):
    headers = {"Authorization": f"Bearer {test_user['token']}"}
    
    # Create test document
    client.post(
        "/api/v1/documents/",
        headers=headers,
        json={
            "name": "Test Document",
            "description": "Test Description",
            "category": "GOVERNMENT"
        }
    )
    
    # Test get all documents
    response = client.get("/api/v1/documents/", headers=headers)
    assert response.status_code == 200
    assert len(response.json()) > 0

    # Test get documents by category
    response = client.get(
        "/api/v1/documents/?category=GOVERNMENT",
        headers=headers
    )
    assert response.status_code == 200
    assert all(doc["category"] == "GOVERNMENT" for doc in response.json())

def test_update_document(client, test_user):
    headers = {"Authorization": f"Bearer {test_user['token']}"}
    
    # Create test document
    create_response = client.post(
        "/api/v1/documents/",
        headers=headers,
        json={
            "name": "Original Name",
            "description": "Original Description",
            "category": "GOVERNMENT"
        }
    )
    document_id = create_response.json()["id"]
    
    # Test update
    response = client.put(
        f"/api/v1/documents/{document_id}",
        headers=headers,
        json={
            "name": "Updated Name",
            "description": "Updated Description"
        }
    )
    assert response.status_code == 200
    assert response.json()["name"] == "Updated Name"
    assert response.json()["description"] == "Updated Description"

def test_delete_document(client, test_user):
    headers = {"Authorization": f"Bearer {test_user['token']}"}
    
    # Create test document
    create_response = client.post(
        "/api/v1/documents/",
        headers=headers,
        json={
            "name": "To Delete",
            "description": "Will be deleted",
            "category": "GOVERNMENT"
        }
    )
    document_id = create_response.json()["id"]
    
    # Test delete
    response = client.delete(
        f"/api/v1/documents/{document_id}",
        headers=headers
    )
    assert response.status_code == 200
    
    # Verify deletion
    response = client.get(
        f"/api/v1/documents/{document_id}",
        headers=headers
    )
    assert response.status_code == 404