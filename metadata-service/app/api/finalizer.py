# metadata-service/app/api/finalizer.py

import os
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from app.services.finalizer import finalize_video
from app.core.minio_client import MinIOClient
from typing import Dict

router = APIRouter(prefix="/finalize", tags=["Finalizer"])
minio = MinIOClient()

@router.post("/")
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
        assets_bucket = "assets"
        metadata_bucket = "metadata"
        thumb_key = os.path.basename(thumb_path)
        meta_key = f"{os.path.splitext(thumb_key)[0]}_metadata.json"

        minio.upload_file(
            bucket_name=assets_bucket,
            object_name=thumb_key,
            file_data=open(thumb_path, "rb"),
            content_type="image/jpeg"
        )
        minio.upload_json(
            bucket_name=metadata_bucket,
            object_name=meta_key,
            data=metadata
        )

        return {
            "status": "success",
            "thumbnail": f"s3://{assets_bucket}/{thumb_key}",
            "metadata": f"s3://{metadata_bucket}/{meta_key}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/complete")
async def finalize_event():
    """Finalize recorded stream: Move to S3, clean up temp files."""
    return {"status": "finalizer pending implementation"}