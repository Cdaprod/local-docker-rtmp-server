# app/api/finalizer.py

import os
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Query, Depends, Body
from typing import Dict, List, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field
from app.services.finalizer import finalize_video
from app.services.finalizer_service import finalizer_service
from app.core.minio_client import MinIOClient
from app.core.config import (
    MINIO_METADATA_BUCKET, THUMBNAIL_OBJECT_PREFIX, 
    METADATA_OBJECT_PREFIX, MINIO_ASSETS_BUCKET
)
from app.core.logging import log_streamer

router = APIRouter(tags=["Finalizer"])
minio = MinIOClient()

class FinalizationResponse(BaseModel):
    status: str
    job_id: Optional[str] = None
    results: Optional[Dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class FinalizationRequest(BaseModel):
    source: str
    metadata: Dict[str, Any] = Field(default_factory=dict)

class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    source: str
    created_at: str
    updated_at: Optional[str] = None
    completed_at: Optional[str] = None
    results: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

@router.post("/", response_model=FinalizationResponse)
async def finalize(
    source: str = Form(..., description="Path, URL, or '-' for upload"),
    upload: UploadFile = File(None)
) -> Dict:
    """
    If source == '-', expects a file upload.
    Otherwise, source may be a URL or local path.
    """
    try:
        if source == "-" and upload:
            tmp_path = f"/tmp/{upload.filename}"
            with open(tmp_path, "wb") as f:
                f.write(await upload.read())
            source = tmp_path

        # Log the finalization attempt
        log_streamer.info(f"Starting synchronous finalization for {source}")
        
        thumb_path, metadata = finalize_video(source)

        # Upload thumbnail to the correct path
        thumb_key = f"{THUMBNAIL_OBJECT_PREFIX}{os.path.basename(thumb_path)}"
        meta_key = f"{METADATA_OBJECT_PREFIX}{os.path.splitext(os.path.basename(thumb_path))[0]}.json"

        with open(thumb_path, "rb") as f:
            minio.upload_file(
                bucket_name=MINIO_METADATA_BUCKET,
                object_name=thumb_key,
                file_data=f,
                content_type="image/jpeg"
            )
            
        minio.upload_json(
            bucket_name=MINIO_METADATA_BUCKET,
            object_name=meta_key,
            data=metadata
        )

        # Clean up the temporary thumbnail file
        if os.path.exists(thumb_path):
            os.unlink(thumb_path)

        log_streamer.info(f"Completed synchronous finalization for {source}")
        return {
            "status": "success",
            "results": {
                "thumbnail": f"s3://{MINIO_METADATA_BUCKET}/{thumb_key}",
                "metadata": f"s3://{MINIO_METADATA_BUCKET}/{meta_key}"
            },
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        log_streamer.error(f"Error in synchronous finalization: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/async", response_model=FinalizationResponse)
async def finalize_async(
    request: FinalizationRequest = Body(...)
) -> Dict:
    """Queue a video for asynchronous finalization"""
    try:
        log_streamer.info(f"Queueing asynchronous finalization for {request.source}")
        job_id = await finalizer_service.queue_finalization(
            source=request.source,
            metadata=request.metadata
        )
        return {
            "status": "queued",
            "job_id": job_id,
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        log_streamer.error(f"Error queueing finalization job: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/job/{job_id}", response_model=JobStatusResponse)
async def get_job_status(job_id: str) -> Dict:
    """Get the status of a finalization job"""
    job = await finalizer_service.get_job_status(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    return job

@router.get("/jobs", response_model=List[JobStatusResponse])
async def list_jobs(status: Optional[str] = Query(None)) -> List:
    """List all finalization jobs with optional status filter"""
    return await finalizer_service.list_jobs(status)

@router.post("/complete")
async def finalize_event(
    stream_name: str = Form(..., description="Stream name to finalize")
):
    """Finalize recorded stream: Move to S3, clean up temp files."""
    try:
        log_streamer.info(f"Received finalize event for stream: {stream_name}")
        # This endpoint will be implemented to handle the end of stream recording
        # For now, just return acknowledgment
        return {
            "status": "acknowledged", 
            "message": f"Finalization event received for stream {stream_name}",
            "stream": stream_name,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        log_streamer.error(f"Error processing finalize event: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))