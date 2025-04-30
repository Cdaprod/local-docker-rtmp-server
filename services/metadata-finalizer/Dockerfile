# ==============================================================================
# CDA Metadata Finalizer Service
#
# Generates standardized thumbnails and metadata JSON from video inputs.
#
# Supported Inputs:
#  - Local filesystem path (mounted volumes)
#  - Remote HTTP/HTTPS URLs (auto-downloaded internally)
#  - stdin (pipe directly into container)
#
# Outputs:
#  - Thumbnail (.jpg at 5 seconds)
#  - Metadata (.json with SHA256 hash and descriptive metadata)
#
# Base image: slim Python + ffmpeg
# ==============================================================================
FROM python:3.12-slim

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>" \
      description="Metadata Finalizer for CDA cinematic pipeline"

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies (ffmpeg for thumbnailing, curl for robust download handling)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and prepare the finalization script
COPY finalize.py /app/finalize.py
RUN chmod +x /app/finalize.py

ENTRYPOINT ["python3", "/app/finalize.py"]
