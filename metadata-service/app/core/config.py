# app/core/config.py

import os
import socket
from typing import List, Dict, Any
from datetime import datetime

# Host identification
HOSTNAME = socket.gethostname()
CONTAINER_NAME = os.getenv("CONTAINER_NAME", "metadata-service")

# Version information - matches the Docker image version
VERSION = "v1.2.2"  # Aligns with cdaprod/metadata-service:v1.2.2
API_VERSION = "v1"

# Application settings
PROJECT_NAME = "CDA Metadata Service Control Plane"
PROJECT_DESCRIPTION = "API for controlling metadata services and processing events"
DEBUG = os.getenv("DEBUG", "False").lower() == "true"
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "5000"))
CORS_ORIGINS = [
    "http://localhost",
    "http://localhost:8080", 
    "http://localhost:3000",
    os.getenv("FRONTEND_URL", "")
]

# MinIO connection settings - matches your docker-compose.yaml
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "minio:9000")  # Service name in docker-compose
MINIO_ACCESS_KEY = os.getenv("MINIO_ROOT_USER", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_ROOT_PASSWORD", "minioadmin")
MINIO_SECURE = os.getenv("MINIO_SECURE", "False").lower() == "true"
MINIO_REGION = os.getenv("MINIO_REGION", "us-east-1")

# MinIO bucket configuration using service-based naming from metadata-service.buckets
SERVICE_NAME = "metadata-service"
MINIO_METADATA_BUCKET = f"{SERVICE_NAME}"
MINIO_LOGS_PATH = "logs"
MINIO_THUMBNAILS_PATH = "thumbnails"
MINIO_JOBS_PATH = "jobs"
MINIO_METADATA_PATH = "metadata"

# External service buckets
MINIO_RTMP_BUCKET = "rtmp"
MINIO_OBS_BUCKET = "obs"
MINIO_ASSETS_BUCKET = "shared-assets"

# Object prefixes within buckets/paths
THUMBNAIL_OBJECT_PREFIX = f"{MINIO_THUMBNAILS_PATH}/"
METADATA_OBJECT_PREFIX = f"{MINIO_METADATA_PATH}/"
JOBS_OBJECT_PREFIX = f"{MINIO_JOBS_PATH}/"
LOG_OBJECT_PREFIX = f"{MINIO_LOGS_PATH}/"
RECORDING_OBJECT_PREFIX = "recordings/"

# MinIO bucket policies
BUCKET_POLICIES = {
    # MINIO_METADATA_BUCKET: {
    #     "Version": "2012-10-17",
    #     "Statement": [
    #         {
    #             "Effect": "Allow",
    #             "Principal": {"AWS": ["*"]},
    #             "Action": ["s3:GetObject"],
    #             "Resource": [f"arn:aws:s3:::{MINIO_METADATA_BUCKET}/*"]
    #         }
    #     ]
    # },
    # MINIO_ASSETS_BUCKET: {
    #     "Version": "2012-10-17",
    #     "Statement": [
    #         {
    #             "Effect": "Allow",
    #             "Principal": {"AWS": ["*"]},
    #             "Action": ["s3:GetObject"],
    #             "Resource": [f"arn:aws:s3:::{MINIO_ASSETS_BUCKET}/*"]
    #         }
    #     ]
    # }
}

# RabbitMQ settings - matches docker-compose.yaml configuration
RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")  # Service name in docker-compose
RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT", "5672"))
RABBITMQ_USER = os.getenv("RABBITMQ_DEFAULT_USER", "guest")
RABBITMQ_PASS = os.getenv("RABBITMQ_DEFAULT_PASS", "guest")
RABBITMQ_VHOST = os.getenv("RABBITMQ_VHOST", "/")

# Queue names - matches your environment in docker-compose
QUEUE_STREAM_EVENTS = "stream_events"
QUEUE_METADATA = os.getenv("METADATA_QUEUE", "metadata_queue")
QUEUE_FINALIZER_JOBS = "finalizer_jobs"
QUEUE_NOTIFICATIONS = "notifications"

# Docker settings - for controlling Docker-in-Docker if needed
DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")
DOCKER_PROJECT_NAME = os.getenv("DOCKER_PROJECT_NAME", "cdaprod")

# Finalizer settings
THUMBNAIL_TIMESTAMP = os.getenv("THUMBNAIL_TIMESTAMP", "00:00:05")
THUMBNAIL_SIZE = os.getenv("THUMBNAIL_SIZE", "640x360")
THUMBNAIL_QUALITY = int(os.getenv("THUMBNAIL_QUALITY", "90"))
TEMP_DIR = os.getenv("TEMP_DIR", "/tmp")
FFMPEG_PATH = os.getenv("FFMPEG_PATH", "ffmpeg")

# Base storage path for local file access - matches mounted volume in docker-compose
BASE_STORAGE_PATH = "/mnt/b/rpi_sync"

# Storage paths mapping
STORAGE_PATHS = {
    "minio_data": f"{BASE_STORAGE_PATH}/minio/data",
    "obs_recordings": f"{BASE_STORAGE_PATH}/obs/recordings",
    "rtmp_recordings": f"{BASE_STORAGE_PATH}/rtmp/recordings",
    "shared_assets": f"{BASE_STORAGE_PATH}/shared-assets",
    "metadata_files": f"{BASE_STORAGE_PATH}/{SERVICE_NAME}"
}

# Logging configuration - includes services from your compose file
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
CONTAINER_LOG_SERVICES = [
    "metadata-service", 
    "rtmp-pi",
    "obs-pi",
    "minio-pi",
    "rabbitmq-pi",
    "webrtc-pi",
    "rtsp-server"
]

# Define metadata tags 
DEFAULT_METADATA_TAGS = [
    "CDAProd", 
    "CDA Cinematic Relay",
    "Metadata", 
    "RTMP"
]

# Generate standard metadata structure
def generate_standard_metadata(source_name: str, additional_data: Dict[str, Any] = None) -> Dict[str, Any]:
    """Generate standard metadata structure with consistent fields"""
    base_name = os.path.basename(source_name)
    file_name, ext = os.path.splitext(base_name)
    
    metadata = {
        "source_name": base_name,
        "source_path": source_name,
        "generated_by": "CDA Metadata Finalizer",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "version": VERSION,
        "title": f"CDA Artifact: {file_name}",
        "description": "Automatically generated by CDA pipeline",
        "tags": DEFAULT_METADATA_TAGS.copy(),
        "file_info": {
            "extension": ext.lstrip("."),
            "original_name": base_name
        },
        "storage_paths": {
            "nas": f"{STORAGE_PATHS['rtmp_recordings']}/{base_name}",
            "s3": f"s3://{MINIO_RTMP_BUCKET}/{RECORDING_OBJECT_PREFIX}{base_name}"
        }
    }
    
    if additional_data:
        # Recursively merge dictionaries to preserve nested structures
        def deep_update(source, updates):
            for key, value in updates.items():
                if key in source and isinstance(source[key], dict) and isinstance(value, dict):
                    deep_update(source[key], value)
                else:
                    source[key] = value
            return source
        
        metadata = deep_update(metadata, additional_data)
        
    return metadata