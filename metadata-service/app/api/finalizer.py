# app/api/finalizer.py

import os
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Query, Depends, Body
from typing import Dict, List, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field
from app.services.finalizer import finalize_video
from app.services.finalizer_service import finalizer_service
from app.core.minio_client import MinIOClient
from app.core.config import MINIO_ASSETS_BUCKET, MINIO_METADATA_BUCKET

router = APIRouter(prefix="/finalize", tags=["Finalizer"])
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

        thumb_path, metadata = finalize_video(source)

        # upload thumbnail
        assets_bucket = MINIO_ASSETS_BUCKET
        metadata_bucket = MINIO_METADATA_BUCKET
        thumb_key = os.path.basename(thumb_path)
        meta_key = f"{os.path.splitext(thumb_key)[0]}_metadata.json"

        with open(thumb_path, "rb") as f:
            minio.upload_file(
                bucket_name=assets_bucket,
                object_name=thumb_key,
                file_data=f,
                content_type="image/jpeg"
            )
            
        minio.upload_json(
            bucket_name=metadata_bucket,
            object_name=meta_key,
            data=metadata
        )

        return {
            "status": "success",
            "results": {
                "thumbnail": f"s3://{assets_bucket}/{thumb_key}",
                "metadata": f"s3://{metadata_bucket}/{meta_key}"
            },
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/async", response_model=FinalizationResponse)
async def finalize_async(
    request: FinalizationRequest = Body(...)
) -> Dict:
    """Queue a video for asynchronous finalization"""
    try:
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
async def finalize_event():
    """Finalize recorded stream: Move to S3, clean up temp files."""
    return {"status": "finalizer pending implementation"}