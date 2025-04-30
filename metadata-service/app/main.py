# app/main.py

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import events, health, control, storage, finalizer
from app.core.logger import setup_logger
from app.services.minio_init import initialize_minio
from app.core.logging import log_streamer
import logging
from typing import Dict, Any
from app.core.config import (
    PROJECT_NAME, PROJECT_DESCRIPTION, VERSION, 
    CORS_ORIGINS, HOST, PORT, DEBUG,
    CONTAINER_LOG_SERVICES
)

# Setup application logger
logger = setup_logger("metadata_service")

app = FastAPI(
    title=PROJECT_NAME,
    description=PROJECT_DESCRIPTION,
    version=VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(events.router, prefix="/events", tags=["Events"])
app.include_router(control.router, prefix="/control", tags=["Control Plane"])
app.include_router(storage.router, prefix="/storage", tags=["Storage"])
app.include_router(finalizer.router, prefix="/finalize", tags=["Finalizer"])

@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {PROJECT_NAME} v{VERSION}")
    
    # Configure LogStreamer to monitor all services
    def callback(log: Dict[str, Any]):
        print(f"[{log['service']}] {log['message']}")

    log_streamer.set_services(CONTAINER_LOG_SERVICES)
    log_streamer.set_callback(callback)
    log_streamer.set_level_filter(logging.INFO)
    log_streamer.start()
    
    # Initialize MinIO buckets
    try:
        await initialize_minio()
        logger.info("MinIO initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize MinIO: {e}")
    
    # Start finalizer service
    try:
        from app.services.finalizer_service import finalizer_service
        await finalizer_service.start()
        logger.info("Finalizer service started successfully")
        # Log additional service startup information
        log_streamer.info("Metadata finalizer service is ready to process video files")
    except Exception as e:
        logger.error(f"Failed to start finalizer service: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info(f"Shutting down {PROJECT_NAME}...")
    
    # Stop the finalizer service
    try:
        from app.services.finalizer_service import finalizer_service
        await finalizer_service.stop()
        logger.info("Finalizer service stopped successfully")
    except Exception as e:
        logger.error(f"Error stopping finalizer service: {e}")
    
    # Stop the LogStreamer
    log_streamer.stop()
    logger.info(f"Shutdown complete for {PROJECT_NAME}")

@app.get("/")
async def root():
    """Root endpoint showing service information"""
    return {
        "service": PROJECT_NAME,
        "version": VERSION,
        "description": PROJECT_DESCRIPTION,
        "endpoints": {
            "docs": "/docs",
            "redoc": "/redoc",
            "health": "/health",
            "events": "/events",
            "control": "/control",
            "storage": "/storage",
            "finalizer": "/finalize"
        },
        "status": "operational"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=HOST, port=PORT, reload=DEBUG)