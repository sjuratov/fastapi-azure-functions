"""API route handlers."""

from fastapi import APIRouter
from app.models.requests import HelloRequest

router = APIRouter()


@router.get("/api/omy")
def omy(name: str = "World"):
    """O my greeting endpoint."""
    return {"message": f"O my, hello, {name}!"}


@router.post("/api/helloUser") 
def hello(request: HelloRequest): 
    """Hello user endpoint."""
    return {"message": f"Hello, {request.name}!"}
