"""Application configuration."""

from typing import Optional


class Settings:
    """Application settings."""
    
    APP_NAME: str = "FastAPI on Azure Functions"
    VERSION: str = "0.1.0"
    DESCRIPTION: str = "FastAPI application running on Azure Functions"
    
    # Add environment-specific settings here
    DEBUG: bool = False
    

settings = Settings()
