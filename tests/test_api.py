"""API endpoint tests."""

import pytest


def test_omy_default(client):
    """Test /api/omy endpoint with default name."""
    response = client.get("/api/omy")
    assert response.status_code == 200
    assert response.json() == {"message": "O my, hello, World!"}


def test_omy_custom_name(client):
    """Test /api/omy endpoint with custom name."""
    response = client.get("/api/omy?name=Alice")
    assert response.status_code == 200
    assert response.json() == {"message": "O my, hello, Alice!"}


def test_hello_user(client):
    """Test /api/helloUser POST endpoint."""
    response = client.post(
        "/api/helloUser",
        json={"name": "Bob"}
    )
    assert response.status_code == 200
    assert response.json() == {"message": "Hello, Bob!"}


def test_hello_user_missing_name(client):
    """Test /api/helloUser with missing name field."""
    response = client.post("/api/helloUser", json={})
    assert response.status_code == 422  # Validation error


def test_swagger_ui(client):
    """Test custom Swagger UI endpoint."""
    response = client.get("/api/docs")
    assert response.status_code == 200
    assert "swagger-ui" in response.text.lower()
