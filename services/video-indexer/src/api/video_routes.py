from fastapi import APIRouter, Query, HTTPException
from pathlib import Path
from ..indexer import VideoIndexer

router = APIRouter(prefix="/videos", tags=["videos"])
indexer = VideoIndexer()

@router.get("/status")
def get_video_status(path: str = Query(...)):
    file_path = Path(path)
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    index = indexer._load_index()
    for video in index:
        if video.path == str(file_path):
            return video.dict()

    return {"status": "not indexed", "path": str(file_path)}