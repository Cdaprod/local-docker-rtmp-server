# app/core/config.py

import os
from typing import List

# MinIO settings
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ROOT_USER", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_ROOT_PASSWORD", "minioadmin")
MINIO_SECURE = os.getenv("MINIO_SECURE", "False").lower() == "true"

# Default buckets
MINIO_METADATA_BUCKET = os.getenv("MINIO_METADATA_BUCKET", "metadata")
MINIO_ASSETS_BUCKET = os.getenv("MINIO_ASSETS_BUCKET", "assets")
MINIO_RECORDINGS_BUCKET = os.getenv("MINIO_RECORDINGS_BUCKET", "recordings")

# Project settings
PROJECT_NAME = "Cdaprod Metadata Service Control Plane"
PROJECT_DESCRIPTION = "API for controlling metadata services and processing events"
VERSION = "1.0.0"