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

# Define the buckets you need based on your architecture.
buckets=(
  "minio"          # e.g., for internal assets
  "obs"            # for OBS recordings & configs
  "rtmp"           # for streaming recordings, HLS fragments, logs
  "shared-assets"  # shared overlays, etc.
  "scratch"        # temporary files
  "screenshots"    # screen captures
  "metadata-service" # for metadata logs and exports
)

echo "[+] Creating buckets..."
for bucket in "${buckets[@]}"; do
  echo "Ensuring bucket: $bucket"
  mc mb local/$bucket || true
done

# Optional: apply policies or make buckets public if desired.
echo "[+] Applying bucket policies..."
mc anonymous set download local/shared-assets || true

echo "[+] MinIO initialization complete."