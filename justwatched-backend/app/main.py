from fastapi import FastAPI
from app.api.v1.api import api_router
from app.api.v1.endpoints import websocket
from app.core.config import settings
from app.middleware.token_middleware import TokenMiddleware
import os

# Application Insights setup for production
if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    from opencensus.ext.azure.log_exporter import AzureLogHandler
    from opencensus.ext.fastapi.fastapi_middleware import FastAPIMiddleware
    from opencensus.trace.tracer import Tracer
    from opencensus.trace.samplers import ProbabilitySampler
    import logging
    
    # Configure logging
    logger = logging.getLogger(__name__)
    logger.addHandler(AzureLogHandler(
        connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
    ))

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Add Application Insights middleware if connection string is available
if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    app.add_middleware(FastAPIMiddleware)

# Add token middleware for automatic token refresh
app.add_middleware(TokenMiddleware)

app.include_router(api_router, prefix=settings.API_V1_STR)

# Mount WebSocket routes directly on the main app
app.include_router(websocket.router, prefix="/api/v1/websocket", tags=["websocket"])

@app.get("/healthcheck")
async def healthcheck():
    """Health check endpoint for monitoring."""
    try:
        # Test database connection
        from app.core.firestore import get_firestore_client
        db = get_firestore_client()
        # Simple test - try to access a collection
        db.collection("health_check").limit(1).stream()
        
        return {
            "status": "healthy",
            "database": "connected",
            "environment": os.getenv("ENVIRONMENT", "development")
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e),
            "environment": os.getenv("ENVIRONMENT", "development")
        }

@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "message": "JustWatched Backend API",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "docs": "/docs"
    }


@app.get("/test")
async def test():
    return {"message": "update"}