import azure.functions as func
import logging
from app.main import app as fastapi_app
from azure.functions._http_asgi import AsgiMiddleware

app = func.FunctionApp()

# Create ASGI middleware to connect Azure Function -> FastAPI
asgi_middleware = AsgiMiddleware(fastapi_app)

@app.route(route="{*routes}", auth_level=func.AuthLevel.ANONYMOUS)
async def fastapi_handler(req: func.HttpRequest) -> func.HttpResponse:
    """Proxy all HTTP traffic to FastAPI."""
    response = await asgi_middleware.handle_async(req)
    logging.info(f"{req.method} {req.url} -> {response.status_code}")
    return response
