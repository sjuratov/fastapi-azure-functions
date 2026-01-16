"""Request models."""

from pydantic import BaseModel


class HelloRequest(BaseModel):
    """Request model for hello endpoint."""
    name: str
