# app/core/logger.py
import logging
from app.core.logging import log_streamer

def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    """Create or get a logger with the given name and level.
    Also integrates with the LogStreamer singleton.
    
    This provides a unified interface for both standard logging
    and the specialized container log streaming.
    """
    
    # Get a standard logger
    logger = logging.getLogger(name)
    
    # Only set up the logger if it hasn't been configured yet
    if not logger.handlers:
        logger.setLevel(level)
        
        # Create a console handler
        handler = logging.StreamHandler()
        handler.setLevel(level)
        
        # Create a formatter
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        handler.setFormatter(formatter)
        
        # Add the handler to the logger
        logger.addHandler(handler)
    
    # Create a wrapper class that logs to both the standard logger and LogStreamer
    class LoggerWrapper:
        def __init__(self, std_logger, streamer):
            self.logger = std_logger
            self.streamer = streamer
            
        def info(self, msg, *args, **kwargs):
            self.logger.info(msg, *args, **kwargs)
            self.streamer.info(f"[{name}] {msg}")
            
        def warning(self, msg, *args, **kwargs):
            self.logger.warning(msg, *args, **kwargs)
            self.streamer.warning(f"[{name}] {msg}")
            
        def error(self, msg, *args, **kwargs):
            self.logger.error(msg, *args, **kwargs)
            self.streamer.error(f"[{name}] {msg}")
            
        def debug(self, msg, *args, **kwargs):
            self.logger.debug(msg, *args, **kwargs)
            # Don't send debug messages to LogStreamer to avoid noise
            
        def critical(self, msg, *args, **kwargs):
            self.logger.critical(msg, *args, **kwargs)
            self.streamer.critical(f"[{name}] {msg}")
            
        def exception(self, msg, *args, exc_info=True, **kwargs):
            self.logger.exception(msg, *args, exc_info=exc_info, **kwargs)
            self.streamer.error(f"[{name}] Exception: {msg}")
    
    # Return the wrapper that logs to both standard logger and LogStreamer
    return LoggerWrapper(logger, log_streamer)