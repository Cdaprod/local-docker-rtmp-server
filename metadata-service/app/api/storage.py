from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form, Query
from fastapi.responses import Response
from typing import Dict, Any, List, Optional
from datetime import datetime
from pydantic import BaseModel
from app.core.minio_client import MinIOClient
from app.core.config import settings
from app.core.logger import setup_logger
import json

logger = setup_logger("storage_api")
router = APIRouter()

class StorageResponse(BaseModel):
    status: str
    message: str
    data: Optional[Dict[str, Any]] = None
    timestamp: datetime = datetime.utcnow()

def get_minio_client():
    """Dependency to get MinIO client"""
    return MinIOClient()

@router.get("/health", response_model=StorageResponse)
async def storage_health(minio: MinIOClient = Depends(get_minio_client)):
    """Check MinIO storage health"""
    is_healthy = minio.check_connection()
    if is_healthy:
        return {
            "status": "healthy",
            "message": "MinIO storage is connected and working",
            "data": None,
            "timestamp": datetime.utcnow()
        }
    else:
        return {
            "status": "unhealthy",
            "message": "MinIO storage is not reachable",
            "data": None,
            "timestamp": datetime.utcnow()
        }

@router.post("/upload", response_model=StorageResponse)
async def upload_file(
    bucket: str = Form(...),
    path: str = Form(...),
    file: UploadFile = File(...),
    minio: MinIOClient = Depends(get_minio_client)
):
    """Upload a file to MinIO storage"""
    try:
        # Read file content
        file_content = await file.read()
        
        # Determine object name (path + filename)
        object_name = f"{path.rstrip('/')}/{file.filename}"
        
        # Upload to MinIO
        success = minio.upload_file(
            bucket_name=bucket,
            object_name=object_name,
            file_data=file_content,
            content_type=file.content_type
        )
        
        if success:
            return {
                "status": "success",
                "message": f"File uploaded successfully to {bucket}/{object_name}",
                "data": {
                    "bucket": bucket,
                    "object_name": object_name,
                    "file_name": file.filename,
                    "content_type": file.content_type,
                    "size": len(file_content)
                },
                "timestamp": datetime.utcnow()
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to upload file to storage")
    except Exception as e:
        logger.error(f"File upload error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"File upload error: {str(e)}")

@router.post("/metadata/save", response_model=StorageResponse)
async def save_metadata(
    key: str = Form(...),
    data: str = Form(...),
    minio: MinIOClient = Depends(get_minio_client)
):
    """Save metadata as JSON to MinIO storage"""
    try:
        # Parse the JSON data
        json_data = json.loads(data)
        
        # Add timestamp if not present
        if "timestamp" not in json_data:
            json_data["timestamp"] = datetime.utcnow().isoformat()
        
        # Ensure key has .json extension
        if not key.endswith(".json"):
            key = f"{key}.json"
        
        # Upload to MinIO
        success = minio.upload_json(
            bucket_name=settings.MINIO_METADATA_BUCKET,
            object_name=key,
            data=json_data
        )
        
        if success:
            return {
                "status": "success",
                "message": f"Metadata saved successfully to {key}",
                "data": {"key": key},
                "timestamp": datetime.utcnow()
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to save metadata")
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON data")
    except Exception as e:
        logger.error(f"Metadata save error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Metadata save error: {str(e)}")

@router.get("/metadata/get/{key}", response_model=StorageResponse)
async def get_metadata(
    key: str,
    minio: MinIOClient = Depends(get_minio_client)
):
    """Get metadata from MinIO storage"""
    try:
        # Ensure key has .json extension
        if not key.endswith(".json"):
            key = f"{key}.json"
        
        # Download from MinIO
        data = minio.download_json(
            bucket_name=settings.MINIO_METADATA_BUCKET,
            object_name=key
        )
        
        if data is not None:
            return {
                "status": "success",
                "message": f"Metadata retrieved successfully from {key}",
                "data": data,
                "timestamp": datetime.utcnow()
            }
        else:
            raise HTTPException(status_code=404, detail=f"Metadata not found for key: {key}")
    except Exception as e:
        logger.error(f"Metadata retrieval error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Metadata retrieval error: {str(e)}")

@router.get("/list", response_model=StorageResponse)
async def list_files(
    bucket: str = Query(...),
    prefix: str = Query(""),
    minio: MinIOClient = Depends(get_minio_client)
):
    """List files in a bucket with optional prefix"""
    try:
        # List objects from MinIO
        objects = minio.list_objects(
            bucket_name=bucket,
            prefix=prefix
        )
        
        return {
            "status": "success",
            "message": f"Listed {len(objects)} objects from {bucket}/{prefix}",
            "data": {"objects": objects},
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        logger.error(f"List files error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"List files error: {str(e)}")

@router.get("/download/{bucket}/{object_path:path}", response_class=Response)
async def download_file(
    bucket: str,
    object_path: str,
    minio: MinIOClient = Depends(get_minio_client)
):
    """Download a file from MinIO storage"""
    try:
        # Download from MinIO
        data = minio.download_file(
            bucket_name=bucket,
            object_name=object_path
        )
        
        if data is not None:
            # Determine content type
            if object_path.endswith(".json"):
                media_type = "application/json"
            elif object_path.endswith(".txt"):
                media_type = "text/plain"
            elif object_path.endswith(".html"):
                media_type = "text/html"
            elif object_path.endswith(".css"):
                media_type = "text/css"
            elif object_path.endswith(".js"):
                media_type = "application/javascript"
            elif object_path.endswith(".png"):
                media_type = "image/png"
            elif object_path.endswith(".jpg") or object_path.endswith(".jpeg"):
                media_type = "image/jpeg"
            elif object_path.endswith(".mp4"):
                media_type = "video/mp4"
            else:
                media_type = "application/octet-stream"
            
            return Response(content=data, media_type=media_type)
        else:
            raise HTTPException(status_code=404, detail=f"File not found: {bucket}/{object_path}")
    except Exception as e:
        logger.error(f"File download error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"File download error: {str(e)}")

@router.delete("/{bucket}/{object_path:path}", response_model=StorageResponse)
async def delete_file(
    bucket: str,
    object_path: str,
    minio: MinIOClient = Depends(get_minio_client)
):
    """Delete a file from MinIO storage"""
    try:
        # Delete from MinIO
        success = minio.remove_file(
            bucket_name=bucket,
            object_name=object_path
        )
        
        if success:
            return {
                "status": "success",
                "message": f"File deleted successfully: {bucket}/{object_path}",
                "data": None,
                "timestamp": datetime.utcnow()
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to delete file")
    except Exception as e:
        logger.error(f"File deletion error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"File deletion error: {str(e)}")
