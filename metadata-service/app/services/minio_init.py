from app.core.minio_client import MinIOClient
from app.core.config import (
    MINIO_METADATA_BUCKET, MINIO_ASSETS_BUCKET, MINIO_RTMP_BUCKET, 
    MINIO_OBS_BUCKET, THUMBNAIL_OBJECT_PREFIX, METADATA_OBJECT_PREFIX,
    JOBS_OBJECT_PREFIX, LOG_OBJECT_PREFIX, PROJECT_NAME, VERSION
)
from app.core.logger import setup_logger
from app.core.logging import log_streamer
import asyncio

logger = setup_logger("minio_init")

async def initialize_minio():
    """Initialize MinIO buckets and default objects"""
    logger.info("Initializing MinIO storage...")
    log_streamer.info("Starting MinIO initialization")
    
    # Create client
    minio_client = MinIOClient()
    
    # Create default buckets
    service_buckets = [
        MINIO_METADATA_BUCKET,
        MINIO_ASSETS_BUCKET,
        MINIO_RTMP_BUCKET,
        MINIO_OBS_BUCKET
    ]
    
    for bucket in service_buckets:
        success = minio_client.ensure_bucket_exists(bucket)
        if success:
            logger.info(f"Bucket '{bucket}' ready")
            log_streamer.info(f"Initialized bucket: {bucket}")
        else:
            logger.error(f"Failed to create bucket '{bucket}'")
            log_streamer.error(f"Failed to create bucket: {bucket}")
    
    # Create required folder structure within the metadata bucket
    # by creating placeholder objects
    folder_paths = [
        f"{THUMBNAIL_OBJECT_PREFIX}.placeholder",
        f"{METADATA_OBJECT_PREFIX}.placeholder",
        f"{JOBS_OBJECT_PREFIX}.placeholder",
        f"{LOG_OBJECT_PREFIX}.placeholder"
    ]
    
    for path in folder_paths:
        minio_client.upload_file(
            bucket_name=MINIO_METADATA_BUCKET,
            object_name=path,
            file_data=b"",  # Empty content
            content_type="application/x-empty"
        )
        logger.info(f"Created path structure: {path}")
    
    # Create sample metadata object
    sample_metadata = {
        "service": PROJECT_NAME,
        "version": VERSION,
        "description": "Sample metadata object",
        "created_at": asyncio.get_running_loop().time(),
        "bucket_structure": {
            "metadata_bucket": MINIO_METADATA_BUCKET,
            "paths": {
                "thumbnails": THUMBNAIL_OBJECT_PREFIX,
                "metadata": METADATA_OBJECT_PREFIX,
                "jobs": JOBS_OBJECT_PREFIX,
                "logs": LOG_OBJECT_PREFIX
            }
        }
    }
    
    success = minio_client.upload_json(
        bucket_name=MINIO_METADATA_BUCKET,
        object_name=f"{METADATA_OBJECT_PREFIX}system_info.json",
        data=sample_metadata
    )
    
    if success:
        logger.info("Sample metadata created")
        log_streamer.info("MinIO initialization complete")
    else:
        logger.error("Failed to create sample metadata")
        log_streamer.error("MinIO initialization incomplete")
    
    return True

if __name__ == "__main__":
    # Run the initialization
    asyncio.run(initialize_minio())