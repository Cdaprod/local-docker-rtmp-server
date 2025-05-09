import os
from pathlib import Path
from pydantic import BaseSettings

class Settings(BaseSettings):
    watch_dir: Path = Path(os.getenv("WATCH_DIR", "/mnt/videos"))
    index_dir: Path = Path(os.getenv("INDEX_DIR", "/data/index"))
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
    recursive_watch: bool = True
    
    # Video file extensions to monitor
    video_extensions: set = {".mp4", ".mov", ".webm", ".mkv", ".avi", ".m4v"}
    
    # Index file settings
    index_file: str = "index.json"
    processed_log: str = "processed.log"
    
    # Thumbnail settings
    thumbnail_enabled: bool = os.getenv("THUMBNAIL_ENABLED", "false").lower() == "true"
    thumbnail_dir: Path = Path(os.getenv("THUMBNAIL_DIR", "/data/thumbnails"))
    thumbnail_size: tuple = (320, 180)
    
    openai_enabled: bool = os.getenv("OPENAI_ENABLED", "false").lower() == "true"
    openai_frame_rate: int = int(os.getenv("OPENAI_FRAME_RATE", 1))
    
    # ─── BlackBox Metadata Service ──────────────────────────────
    blackbox_enabled: bool = os.getenv("BLACKBOX_ENABLED", "false").lower() == "true"
    # where to write per-batch spreadsheets
    blackbox_output_dir: Path = Path(os.getenv("BLACKBOX_OUTPUT_DIR", "/repo-data/metadata-batches"))
    # model to use for metadata generation
    metadata_model: str = os.getenv("METADATA_MODEL", "gpt-4o")
    # ─────────────────────────────────────────────────────────────
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()