#!/bin/bash

# Install MinIO client dependency
pip install minio

# Add MinIO client module
sudo tee metadata-service/app/core/minio_client.py << 'EOF'
from minio import Minio
from minio.error import S3Error
from typing import BinaryIO, Dict, Any, List, Optional, Union
from io import BytesIO
import json
import os
from app.core.config import settings
from app.core.logger import setup_logger

logger = setup_logger("minio_client")

class MinIOClient:
    def __init__(
        self,
        endpoint: str = settings.MINIO_ENDPOINT,
        access_key: str = settings.MINIO_ACCESS_KEY,
        secret_key: str = settings.MINIO_SECRET_KEY,
        secure: bool = settings.MINIO_SECURE
    ):
        self.endpoint = endpoint
        self.access_key = access_key
        self.secret_key = secret_key
        self.secure = secure
        self._client = None
    
    @property
    def client(self) -> Minio:
        """Lazy initialization of MinIO client"""
        if self._client is None:
            self._client = Minio(
                endpoint=self.endpoint,
                access_key=self.access_key,
                secret_key=self.secret_key,
                secure=self.secure
            )
        return self._client
    
    def check_connection(self) -> bool:
        """Check if MinIO connection is working"""
        try:
            # List buckets as a connection test
            self.client.list_buckets()
            return True
        except Exception as e:
            logger.error(f"MinIO connection check failed: {e}")
            return False
    
    def ensure_bucket_exists(self, bucket_name: str) -> bool:
        """Ensure a bucket exists, create it if it doesn't"""
        try:
            if not self.client.bucket_exists(bucket_name):
                self.client.make_bucket(bucket_name)
                logger.info(f"Created bucket: {bucket_name}")
            return True
        except S3Error as e:
            logger.error(f"Failed to create bucket {bucket_name}: {e}")
            return False
    
    def upload_file(
        self, 
        bucket_name: str, 
        object_name: str, 
        file_data: Union[BinaryIO, bytes, str],
        content_type: str = 'application/octet-stream'
    ) -> bool:
        """Upload a file to MinIO bucket"""
        try:
            # Ensure bucket exists
            if not self.ensure_bucket_exists(bucket_name):
                return False
            
            # Handle different input types
            if isinstance(file_data, str):
                # Convert string to bytes
                file_data = BytesIO(file_data.encode('utf-8'))
                if content_type == 'application/octet-stream':
                    content_type = 'text/plain'
            elif isinstance(file_data, bytes):
                file_data = BytesIO(file_data)
            
            # Get file size for BytesIO objects
            if isinstance(file_data, BytesIO):
                file_data.seek(0, os.SEEK_END)
                file_length = file_data.tell()
                file_data.seek(0)
            else:
                # For file-like objects, use automatic length detection
                file_length = -1
                
            # Upload file
            self.client.put_object(
                bucket_name=bucket_name,
                object_name=object_name,
                data=file_data,
                length=file_length,
                content_type=content_type
            )
            logger.info(f"Uploaded {object_name} to {bucket_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to upload file to MinIO: {e}")
            return False
    
    def upload_json(self, bucket_name: str, object_name: str, data: Dict[str, Any]) -> bool:
        """Upload JSON data to MinIO bucket"""
        try:
            json_data = json.dumps(data, default=str)
            return self.upload_file(
                bucket_name=bucket_name,
                object_name=object_name,
                file_data=json_data,
                content_type='application/json'
            )
        except Exception as e:
            logger.error(f"Failed to upload JSON to MinIO: {e}")
            return False
    
    def download_file(self, bucket_name: str, object_name: str) -> Optional[bytes]:
        """Download a file from MinIO bucket"""
        try:
            response = self.client.get_object(bucket_name, object_name)
            data = response.read()
            response.close()
            response.release_conn()
            return data
        except Exception as e:
            logger.error(f"Failed to download file from MinIO: {e}")
            return None
    
    def download_json(self, bucket_name: str, object_name: str) -> Optional[Dict[str, Any]]:
        """Download and parse JSON data from MinIO bucket"""
        try:
            data = self.download_file(bucket_name, object_name)
            if data:
                return json.loads(data.decode('utf-8'))
            return None
        except Exception as e:
            logger.error(f"Failed to download or parse JSON from MinIO: {e}")
            return None
    
    def list_objects(self, bucket_name: str, prefix: str = '', recursive: bool = True) -> List[Dict[str, Any]]:
        """List objects in a bucket with optional prefix"""
        try:
            objects = self.client.list_objects(bucket_name, prefix=prefix, recursive=recursive)
            return [
                {
                    "name": obj.object_name,
                    "size": obj.size,
                    "last_modified": obj.last_modified,
                    "etag": obj.etag
                } 
                for obj in objects
            ]
        except Exception as e:
            logger.error(f"Failed to list objects in MinIO: {e}")
            return []
    
    def remove_file(self, bucket_name: str, object_name: str) -> bool:
        """Remove a file from MinIO bucket"""
        try:
            self.client.remove_object(bucket_name, object_name)
            logger.info(f"Removed {object_name} from {bucket_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to remove file from MinIO: {e}")
            return False
EOF

# Update config.py to include MinIO settings
sudo tee metadata-service/app/core/config.py << 'EOF'
import os
from typing import List
from pydantic import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Cdaprod Metadata Service Control Plane"
    PROJECT_DESCRIPTION: str = "API for controlling metadata services and processing events"
    VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "5000"))
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:8080",
        "http://localhost:3000",
    ]
    RABBITMQ_HOST: str = os.getenv("RABBITMQ_HOST", "rabbitmq")
    RABBITMQ_PORT: int = int(os.getenv("RABBITMQ_PORT", "5672"))
    RABBITMQ_USER: str = os.getenv("RABBITMQ_DEFAULT_USER", "guest")
    RABBITMQ_PASS: str = os.getenv("RABBITMQ_DEFAULT_PASS", "guest")
    DOCKER_COMPOSE_FILE: str = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")
    DOCKER_PROJECT_NAME: str = os.getenv("DOCKER_PROJECT_NAME", "cdaprod")
    
    # MinIO settings
    MINIO_ENDPOINT: str = os.getenv("MINIO_ENDPOINT", "minio:9000")
    MINIO_ACCESS_KEY: str = os.getenv("MINIO_ROOT_USER", "minioadmin")
    MINIO_SECRET_KEY: str = os.getenv("MINIO_ROOT_PASSWORD", "minioadmin")
    MINIO_SECURE: bool = os.getenv("MINIO_SECURE", "False").lower() == "true"
    
    # Default buckets
    MINIO_METADATA_BUCKET: str = os.getenv("MINIO_METADATA_BUCKET", "metadata")
    MINIO_ASSETS_BUCKET: str = os.getenv("MINIO_ASSETS_BUCKET", "assets")
    MINIO_RECORDINGS_BUCKET: str = os.getenv("MINIO_RECORDINGS_BUCKET", "recordings")

    class Config:
        case_sensitive = True

settings = Settings()
EOF

# Create storage API module with MinIO endpoints
sudo tee metadata-service/app/api/storage.py << 'EOF'
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
EOF

# Update main.py to include the storage router
sudo tee metadata-service/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import events, health, control, storage
from app.core.config import settings
from app.core.logger import setup_logger

# Setup application logger
logger = setup_logger("metadata_service")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(events.router, prefix="/events", tags=["Events"])
app.include_router(control.router, prefix="/control", tags=["Control Plane"])
app.include_router(storage.router, prefix="/storage", tags=["Storage"])

@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION}")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info(f"Shutting down {settings.PROJECT_NAME}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
EOF

# Update health.py to include MinIO health check
sudo tee metadata-service/app/api/health.py << 'EOF'
from fastapi import APIRouter, Depends
from typing import Dict, Any
from pydantic import BaseModel
from app.core.rabbitmq import RabbitMQClient
from app.core.dockerctl import DockerControl
from app.core.minio_client import MinIOClient

router = APIRouter()

class HealthResponse(BaseModel):
    status: str
    components: Dict[str, Any]

def get_rabbitmq_client():
    return RabbitMQClient()

def get_docker_control():
    return DockerControl()

def get_minio_client():
    return MinIOClient()

@router.get("/", response_model=HealthResponse)
async def health(
    rabbitmq: RabbitMQClient = Depends(get_rabbitmq_client),
    docker: DockerControl = Depends(get_docker_control),
    minio: MinIOClient = Depends(get_minio_client)
):
    rabbitmq_status = "healthy"
    docker_status = "healthy"
    minio_status = "healthy"
    
    try:
        rabbitmq.check_connection()
    except Exception:
        rabbitmq_status = "unhealthy"
    
    try:
        docker.check_daemon()
    except Exception:
        docker_status = "unhealthy"
    
    try:
        minio.check_connection()
    except Exception:
        minio_status = "unhealthy"
    
    overall_status = "healthy" if all(
        status == "healthy" for status in [rabbitmq_status, docker_status, minio_status]
    ) else "degraded"
    
    return {
        "status": overall_status,
        "components": {
            "api": "healthy",
            "rabbitmq": rabbitmq_status,
            "docker": docker_status,
            "minio": minio_status
        }
    }
EOF

# Update requirements.txt to include minio
sudo tee metadata-service/requirements.txt << 'EOF'
fastapi>=0.95.0
uvicorn>=0.21.1
pydantic>=1.10.7
python-multipart>=0.0.6
pika>=1.3.1
requests>=2.28.2
minio>=7.1.15
EOF

# Update Dockerfile to install dependencies
sudo tee metadata-service/Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies for Docker CLI
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/download/v2.19.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the application port
EXPOSE 5000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000", "--reload"]
EOF

# Create a script for initializing MinIO buckets
sudo tee metadata-service/app/services/minio_init.py << 'EOF'
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
EOF

# Update startup event to initialize MinIO
sudo tee -a metadata-service/app/main.py.tmp << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import events, health, control, storage
from app.core.config import settings
from app.core.logger import setup_logger
from app.services.minio_init import initialize_minio

# Setup application logger
logger = setup_logger("metadata_service")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(events.router, prefix="/events", tags=["Events"])
app.include_router(control.router, prefix="/control", tags=["Control Plane"])
app.include_router(storage.router, prefix="/storage", tags=["Storage"])

@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION}")
    
    # Initialize MinIO buckets
    try:
        await initialize_minio()
        logger.info("MinIO initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize MinIO: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info(f"Shutting down {settings.PROJECT_NAME}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
EOF
mv metadata-service/app/main.py.tmp metadata-service/app/main.py

# Create an update script for easy deployment
sudo tee metadata-service/update_service.sh << 'EOF'
#!/bin/bash

# Update the metadata service with MinIO integration
echo "Updating metadata-service with MinIO integration..."

# Rebuild and restart the service
docker-compose build metadata-service
docker-compose stop metadata-service
docker-compose up -d metadata-service

echo "Update complete. Service restarted."
EOF
chmod +x metadata-service/update_service.sh

echo "MinIO integration files have been created successfully!"