from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import events, health, control, storage
from app.core.config import settings
from app.core.logger import setup_logger
from app.services.minio_init import initialize_minio

# Setup application logger
logger = setup_logger("metadata_service")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(events.router, prefix="/events", tags=["Events"])
app.include_router(control.router, prefix="/control", tags=["Control Plane"])
app.include_router(storage.router, prefix="/storage", tags=["Storage"])

@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION}")
    
    # Initialize MinIO buckets
    try:
        await initialize_minio()
        logger.info("MinIO initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize MinIO: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info(f"Shutting down {settings.PROJECT_NAME}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
