from pydantic import BaseModel
from datetime import datetime
from pathlib import Path
from typing import Optional


class VideoMetadata(BaseModel):
    name: str
    path: str
    size: int
    mtime: int
    duration: Optional[float] = None
    resolution: Optional[str] = None
    codec: Optional[str] = None
    thumbnail_path: Optional[str] = None
    indexed_at: datetime = datetime.now()
    
    @classmethod
    def from_file(cls, file_path: Path) -> "VideoMetadata":
        stat = file_path.stat()
        return cls(
            name=file_path.name,
            path=str(file_path),
            size=stat.st_size,
            mtime=int(stat.st_mtime)
        )