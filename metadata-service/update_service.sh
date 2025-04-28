#!/bin/bash

# Update the metadata service with MinIO integration
echo "Updating metadata-service with MinIO integration..."

# Rebuild and restart the service
docker-compose build metadata-service
docker-compose stop metadata-service
docker-compose up -d metadata-service

echo "Update complete. Service restarted."
