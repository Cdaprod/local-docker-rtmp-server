import logging
import sys
from pythonjsonlogger import jsonlogger

from .config import settings
from .watcher import VideoWatcher


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


def main():
    setup_logging()
    logger = logging.getLogger(__name__)
    
    logger.info("Starting Video Indexer", extra={
        "watch_dir": str(settings.watch_dir),
        "index_dir": str(settings.index_dir),
        "thumbnail_enabled": settings.thumbnail_enabled
        "openai_enabled": settings.openai_enabled
    })
    
    watcher = VideoWatcher()
    watcher.start()


if __name__ == "__main__":
    main()