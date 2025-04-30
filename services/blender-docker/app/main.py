# /app/main.py
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
from jobs.render import process_blender_render
from minio.video_storage_bucket_client import VideoStorageClient
import os

app = FastAPI()

# Initialize MinIO client from env vars
MINIO = VideoStorageClient(
    endpoint=os.getenv("MINIO_ENDPOINT"),
    access_key=os.getenv("MINIO_ACCESS_KEY"),
    secret_key=os.getenv("MINIO_SECRET_KEY"),
    secure=(os.getenv("MINIO_SECURE", "true").lower() == "true"),
    bucket_name=os.getenv("MINIO_BUCKET", "video-storage")
)

@app.post("/process")
async def process_videos(
    background: UploadFile = File(...),
    overlay: UploadFile = File(...),
    chroma_key: str = Form("#00FF00")
):
    result = await process_blender_render(background, overlay, chroma_key)
    return JSONResponse(result)

@app.post("/put")
async def put_video_to_minio(
    file: UploadFile = File(...)
):
    # Save temp
    temp_path = f"/mnt/b/app/exports/{uuid.uuid4()}_{file.filename}"
    with open(temp_path, "wb") as f:
        f.write(await file.read())
    upload = MINIO.upload_file(temp_path, file.filename)
    return JSONResponse(upload)

@app.get("/get")
async def get_video_from_minio(object_name: str):
    dest = f"/mnt/b/app/exports/{object_name}"
    MINIO.download_file(object_name, dest)
    return JSONResponse({"downloaded_to": dest})