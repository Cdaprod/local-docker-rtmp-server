import logging
import sys
from fastapi import FastAPI
from pythonjsonlogger import jsonlogger

from .config import settings
from .watcher import VideoWatcher
from .api import router as api_router

# Conditional Blackbox Import
if settings.blackbox_enabled:
    from .blackbox_metadata import BlackBoxMetadataGenerator
    bb = BlackBoxMetadataGenerator()

def setup_logging():
    """Configure logging with JSON formatter"""
    handler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter(
        fmt="%(asctime)s %(name)s %(levelname)s %(message)s"
    )
    handler.setFormatter(formatter)

    logging.basicConfig(
        level=settings.log_level,
        handlers=[handler]
    )

def start_services():
    logger = logging.getLogger(__name__)
    logger.info("Starting Video Indexer", extra={
        "watch_dir": str(settings.watch_dir),
        "index_dir": str(settings.index_dir),
        "thumbnail_enabled": settings.thumbnail_enabled,
        "openai_enabled": settings.openai_enabled,
        "blackbox_enabled": settings.blackbox_enabled
    })

    # Optionally run blackbox batch scan
    if settings.blackbox_enabled:
        bb.scan_and_process(settings.watch_dir)

    watcher = VideoWatcher()
    watcher.start()

# ----------- FastAPI Setup -----------
app = FastAPI(title="CDA Video Indexer API")
app.include_router(api_router)

@app.get("/health")
def health_check():
    return {"status": "ok"}

# ----------- CLI Entry -----------
if __name__ == "__main__":
    setup_logging()
    start_services()