import os
import subprocess
import hashlib
import shutil
import urllib.request
import tempfile
from datetime import datetime
from typing import Tuple, Dict, Optional, Union
from app.profiles.metadata_profiles import METADATA_PROFILES
from app.services.metadata_enhancer import enrich_metadata

from app.core.config import (
    FFMPEG_PATH,
    TEMP_DIR,
    THUMBNAIL_TIMESTAMP,
    THUMBNAIL_SIZE,
    THUMBNAIL_QUALITY,
    generate_standard_metadata
)
from app.core.logger import setup_logger

logger = setup_logger("finalizer")

def download_video(src: Union[str, bytes]) -> Tuple[str, bool]:
    """
    Prepare or download the video.
    
    Supports:
    - URL (http/https)
    - Local file path
    - Bytes buffer (in-memory video)
    
    Returns (path, is_temp_file).
    """
    if isinstance(src, bytes):
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4", dir=TEMP_DIR)
        logger.info(f"Saving video bytes to temporary file {tmp.name}")
        with open(tmp.name, "wb") as f:
            f.write(src)
        return tmp.name, True

    if isinstance(src, str):
        if src.startswith(("http://", "https://")):
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4", dir=TEMP_DIR)
            logger.info(f"Downloading remote video: {src}")
            with urllib.request.urlopen(src) as resp, open(tmp.name, "wb") as out:
                shutil.copyfileobj(resp, out)
            return tmp.name, True
        elif os.path.exists(src):
            logger.info(f"Using local video: {src}")
            return src, False
        else:
            logger.error(f"Cannot access video source: {src}")
            raise ValueError(f"Cannot access source: {src}")

    raise TypeError(f"Unsupported source type: {type(src)}")

def generate_thumbnail(
    video_path: str, 
    output_path: str, 
    timestamp: str = THUMBNAIL_TIMESTAMP,
    size: str = THUMBNAIL_SIZE,
    quality: int = THUMBNAIL_QUALITY
):
    """Generate a thumbnail from the video."""
    logger.info(f"Generating thumbnail for {video_path} at {timestamp} with size {size}")
    subprocess.run([
        FFMPEG_PATH, "-y", "-i", video_path,
        "-ss", timestamp, "-frames:v", "1",
        "-s", size, "-q:v", str(quality),
        output_path
    ], check=True)
    logger.info(f"Thumbnail saved to {output_path}")

def calculate_sha256(path: str) -> str:
    """Calculate SHA256 hash of the file."""
    logger.info(f"Calculating SHA256 for {path}")
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def create_metadata(
    video_path: str,
    thumb_path: Optional[str] = None,
    profile: str = "default",
    additional_tags: Optional[list] = None
) -> Dict:
    """Create metadata dictionary for a video with optional enrichment."""
    logger.info(f"Creating metadata for {video_path} with profile '{profile}'")

    if profile not in METADATA_PROFILES:
        raise ValueError(f"Metadata profile '{profile}' not found")

    # Get the base profile metadata first
    base_metadata = METADATA_PROFILES[profile](video_path, thumb_path)

    # Enrich the metadata (optional deeper analysis, auto keywords, etc)
    base_metadata = enrich_metadata(base_metadata, video_path)

    # Add additional tags if provided
    if additional_tags:
        base_metadata.setdefault("tags", []).extend(additional_tags)

    return base_metadata

def finalize_video(
    source: Union[str, bytes],
    profile: str = "default",
    generate_thumb: bool = True,
    generate_meta: bool = True,
    custom_timestamp: Optional[str] = None,
    custom_size: Optional[str] = None,
    custom_quality: Optional[int] = None,
    extra_tags: Optional[list] = None
) -> Dict[str, Optional[Union[str, Dict]]]:
    """
    Finalize a video:
    
    - Download or access video
    - Generate thumbnail (optional)
    - Create metadata (optional)

    Returns a dict:
    {
      "thumbnail_path": str or None,
      "metadata": dict or None,
    }
    """
    logger.info(f"Finalizing video: {source}")
    video_path, is_temp = download_video(source)
    thumb_path = None
    metadata = None

    try:
        if generate_thumb:
            thumb_path = os.path.splitext(video_path)[0] + "_thumb.jpg"
            generate_thumbnail(
                video_path,
                thumb_path,
                timestamp=custom_timestamp or THUMBNAIL_TIMESTAMP,
                size=custom_size or THUMBNAIL_SIZE,
                quality=custom_quality or THUMBNAIL_QUALITY
            )
        
        if generate_meta:
            metadata = create_metadata(
                video_path,
                thumb_path=thumb_path if generate_thumb else None,
                profile=profile,
                additional_tags=extra_tags
            )

        return {
            "thumbnail_path": thumb_path,
            "metadata": metadata,
        }

    finally:
        if is_temp:
            logger.info(f"Cleaning up temporary video file: {video_path}")
            try:
                os.unlink(video_path)
            except Exception as e:
                logger.warning(f"Failed to delete temp file {video_path}: {e}")