from app.core.minio_client import MinIOClient
from app.core.config import settings
from app.core.logger import setup_logger
import asyncio

logger = setup_logger("minio_init")

async def initialize_minio():
    """Initialize MinIO buckets and default objects"""
    logger.info("Initializing MinIO storage...")
    
    # Create client
    minio_client = MinIOClient()
    
    # Create default buckets
    buckets = [
        settings.MINIO_METADATA_BUCKET,
        settings.MINIO_ASSETS_BUCKET,
        settings.MINIO_RECORDINGS_BUCKET
    ]
    
    for bucket in buckets:
        success = minio_client.ensure_bucket_exists(bucket)
        if success:
            logger.info(f"Bucket '{bucket}' ready")
        else:
            logger.error(f"Failed to create bucket '{bucket}'")
    
    # Create sample metadata object
    sample_metadata = {
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "description": "Sample metadata object"
    }
    
    success = minio_client.upload_json(
        bucket_name=settings.MINIO_METADATA_BUCKET,
        object_name="sample.json",
        data=sample_metadata
    )
    
    if success:
        logger.info("Sample metadata created")
    else:
        logger.error("Failed to create sample metadata")
    
    return True

if __name__ == "__main__":
    # Run the initialization
    asyncio.run(initialize_minio())
