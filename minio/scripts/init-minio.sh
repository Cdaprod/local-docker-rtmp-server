#!/bin/bash
set -e

echo "[+] Waiting for MinIO to become healthy..."
# Wait until MinIO health endpoint returns ready status.
until curl -s http://localhost:9000/minio/health/ready; do
  echo "Waiting for MinIO..."
  sleep 2
done

echo "[+] Setting MC alias..."
mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

echo "[+] Creating buckets from configuration..."
# Check if the buckets directory exists
if [ -d "/scripts/buckets" ]; then
  # Loop over all bucket config files
  for config_file in /scripts/buckets/*.buckets; do
    if [ -f "$config_file" ]; then
      service_name=$(basename "$config_file" .buckets)
      echo "[+] Processing buckets for service: $service_name"
      
      while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        bucket=$(echo "$line" | sed 's/#.*//g' | xargs)
        if [ -n "$bucket" ]; then
          echo "Ensuring bucket: $bucket"
          mc mb "local/$bucket" || true
        fi
      done < "$config_file"
    fi
  done
else
  echo "[!] Warning: Bucket configuration directory not found."
  echo "[+] Using default bucket configuration..."
  
  # Define the buckets you need based on your architecture.
  buckets=(
    "blender"           # for blender special effect
    "minio"             # e.g., for internal assets
    "obs/recordings"    # for OBS recordings
    "obs/logs"          # for OBS logs
    "rtmp/recordings"   # for streaming recordings
    "rtmp/logs"         # for RTMP logs
    "rtmp/hls"          # for HLS fragments
    "shared-assets"     # shared overlays, etc.
    "scratch"           # temporary files
    "screenshots"       # screen captures
    "metadata-service/logs"      # for metadata logs
    "metadata-service/thumbnails" # for metadata thumbnails
    "metadata-service/jobs"      # for metadata jobs
    "metadata-service/metadata"  # for metadata storage
  )

  for bucket in "${buckets[@]}"; do
    echo "Ensuring bucket: $bucket"
    mc mb "local/$bucket" || true
  done
fi

# Optional: apply policies or make buckets public if desired.
echo "[+] Applying bucket policies..."
mc anonymous set download local/shared-assets || true

echo "[+] MinIO initialization complete."