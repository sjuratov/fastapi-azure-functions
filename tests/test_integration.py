"""Integration tests that run against local Azure Functions runtime.

These tests require the Azure Functions host to be running:
    func start

Then run with:
    pytest tests/test_integration.py
    or
    pytest -m integration

To test against Azure-deployed function:
    FUNCTION_URL=https://your-app.azurewebsites.net pytest -m integration
"""

import os
import pytest
import httpx

BASE_URL = os.getenv("FUNCTION_URL", "http://localhost:7071")
TIMEOUT = 10.0


@pytest.fixture(scope="module")
def http_client():
    """Create an HTTP client for integration tests."""
    with httpx.Client(base_url=BASE_URL, timeout=TIMEOUT) as client:
        yield client


@pytest.mark.integration
def test_functions_runtime_is_running(http_client):
    """Verify Azure Functions runtime is accessible."""
    try:
        response = http_client.get("/api/omy")
        assert response.status_code in [200, 404, 500], "Functions runtime not responding"
    except httpx.ConnectError as e:
        pytest.skip(
            f"Azure Functions runtime not accessible at {BASE_URL}. "
            "For local: Start with 'func start'. "
            "For Azure: Set FUNCTION_URL environment variable."
        )


@pytest.mark.integration
def test_omy_default_via_functions(http_client):
    """Test /api/omy endpoint through Azure Functions with default name."""
    response = http_client.get("/api/omy")
    assert response.status_code == 200
    assert response.json() == {"message": "O my, hello, World!"}


@pytest.mark.integration
def test_omy_custom_name_via_functions(http_client):
    """Test /api/omy endpoint through Azure Functions with custom name."""
    response = http_client.get("/api/omy", params={"name": "Alice"})
    assert response.status_code == 200
    assert response.json() == {"message": "O my, hello, Alice!"}


@pytest.mark.integration
def test_hello_user_via_functions(http_client):
    """Test /api/helloUser POST endpoint through Azure Functions."""
    response = http_client.post(
        "/api/helloUser",
        json={"name": "Bob"}
    )
    assert response.status_code == 200
    assert response.json() == {"message": "Hello, Bob!"}


@pytest.mark.integration
def test_hello_user_missing_name_via_functions(http_client):
    """Test /api/helloUser validation through Azure Functions."""
    response = http_client.post("/api/helloUser", json={})
    assert response.status_code == 422  # Validation error


@pytest.mark.integration
def test_swagger_ui_via_functions(http_client):
    """Test custom Swagger UI endpoint through Azure Functions."""
    response = http_client.get("/api/docs")
    assert response.status_code == 200
    assert "swagger-ui" in response.text.lower()
    # Verify the embedded OpenAPI schema is present
    assert "openapi" in response.text.lower()
