import azure.functions as func
import logging
from fastapi.responses import HTMLResponse
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi_app import app as fastapi_app
from azure.functions._http_asgi import AsgiMiddleware

app = func.FunctionApp()

#Create ASGI middleware to connect Azure Function -> FastAPI
asgi_middleware = AsgiMiddleware(fastapi_app)

@fastapi_app.get("/api/docs", include_in_schema=False)
async def custom_swagger_ui_html() -> HTMLResponse:
    """Custom Swagger UI endpoint that works with Azure Functions."""
    return get_swagger_ui_html(
        openapi_url="",
        title=fastapi_app.title + " - Swagger UI",
        swagger_ui_parameters={"spec": fastapi_app.openapi()},
    )

@app.route(route="{*routes}", auth_level=func.AuthLevel.ANONYMOUS)
async def fastapi_handler(req: func.HttpRequest) -> func.HttpResponse:
    """Proxy all HTTP traffic to FastAPI."""
    response = await asgi_middleware.handle_async(req)
    logging.info(f"{req.method} {req.url} -> {response.status_code}")
    return response
