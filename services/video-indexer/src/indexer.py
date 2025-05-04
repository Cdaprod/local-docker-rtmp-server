import json
import hashlib
import logging
import ffmpeg
from pathlib import Path
from typing import List, Optional
from datetime import datetime

from .models import VideoMetadata
from .config import settings


logger = logging.getLogger(__name__)


class VideoIndexer:
    def __init__(self):
        self.index_path = settings.index_dir / settings.index_file
        self.processed_log_path = settings.index_dir / settings.processed_log
        self._ensure_index_exists()
    
    def _ensure_index_exists(self):
        """Ensure index directory and files exist"""
        settings.index_dir.mkdir(parents=True, exist_ok=True)
        
        if not self.index_path.exists():
            self._save_index([])
        
        if not self.processed_log_path.exists():
            self.processed_log_path.touch()
    
    def _load_index(self) -> List[VideoMetadata]:
        """Load the current index"""
        try:
            with open(self.index_path, 'r') as f:
                data = json.load(f)
                return [VideoMetadata(**item) for item in data]
        except Exception as e:
            logger.error(f"Error loading index: {e}")
            return []
    
    def _save_index(self, index: List[VideoMetadata]):
        """Save the index to disk"""
        try:
            with open(self.index_path, 'w') as f:
                json.dump([item.dict() for item in index], f, indent=2, default=str)
        except Exception as e:
            logger.error(f"Error saving index: {e}")
    
    def _get_video_metadata(self, file_path: Path) -> Optional[VideoMetadata]:
        """Extract video metadata using ffmpeg"""
        try:
            probe = ffmpeg.probe(str(file_path))
            video_stream = next((stream for stream in probe['streams'] if stream['codec_type'] == 'video'), None)
            
            metadata = VideoMetadata.from_file(file_path)
            
            if video_stream:
                metadata.duration = float(probe.get('format', {}).get('duration', 0))
                metadata.resolution = f"{video_stream['width']}x{video_stream['height']}"
                metadata.codec = video_stream.get('codec_name')
            
            if settings.thumbnail_enabled:
                metadata.thumbnail_path = self._generate_thumbnail(file_path)
            
            return metadata
        except Exception as e:
            logger.error(f"Error extracting metadata for {file_path}: {e}")
            return None
    
    def _generate_thumbnail(self, file_path: Path) -> Optional[str]:
        """Generate a thumbnail for the video"""
        try:
            settings.thumbnail_dir.mkdir(parents=True, exist_ok=True)
            
            # Create thumbnail filename based on video file hash
            file_hash = hashlib.md5(str(file_path).encode()).hexdigest()
            thumbnail_path = settings.thumbnail_dir / f"{file_hash}.jpg"
            
            if not thumbnail_path.exists():
                (
                    ffmpeg
                    .input(str(file_path), ss=1)
                    .filter('scale', settings.thumbnail_size[0], -1)
                    .output(str(thumbnail_path), vframes=1)
                    .overwrite_output()
                    .run(capture_stdout=True, capture_stderr=True)
                )
            
            return str(thumbnail_path)
        except Exception as e:
            logger.error(f"Error generating thumbnail for {file_path}: {e}")
            return None
    
    def is_duplicate(self, file_path: Path) -> bool:
        """Check if a file is already indexed"""
        index = self._load_index()
        stat = file_path.stat()
        
        for item in index:
            # Check by path
            if item.path == str(file_path):
                return True
            
            # Check by size and mtime (possible duplicate)
            if item.size == stat.st_size and item.mtime == int(stat.st_mtime):
                return True
        
        return False
    
    def index_video(self, file_path: Path) -> bool:
        """Index a new video file"""
        try:
            if self.is_duplicate(file_path):
                logger.info(f"Skipping duplicate: {file_path}")
                return False
            
            metadata = self._get_video_metadata(file_path)
            if not metadata:
                return False
            
            index = self._load_index()
            index.append(metadata)
            self._save_index(index)
            
            # Log processed file
            with open(self.processed_log_path, 'a') as f:
                f.write(f"{datetime.now().isoformat()},{file_path}\n")
            
            logger.info(f"Indexed: {file_path}")
            return True
            
        except Exception as e:
            logger.error(f"Error indexing {file_path}: {e}")
            return False