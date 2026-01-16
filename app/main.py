"""FastAPI application initialization."""

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.openapi.docs import get_swagger_ui_html

from app.config import settings
from app.api.routes import router

# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    description=settings.DESCRIPTION,
)

# Include routers
app.include_router(router)


@app.get("/api/docs", include_in_schema=False)
async def custom_swagger_ui_html() -> HTMLResponse:
    """Custom Swagger UI endpoint that works with Azure Functions."""
    return get_swagger_ui_html(
        openapi_url="",
        title=app.title + " - Swagger UI",
        swagger_ui_parameters={"spec": app.openapi()},
    )
