#!/bin/bash
set -e

BASE="/mnt/b/rpi_sync"
BUCKETS_DIR="/scripts/buckets"

# Create the base directory if it doesn't exist
mkdir -p "$BASE"

# First, ensure we have the default paths
default_paths=(
  "$BASE/minio/data"
  "$BASE/shared-assets"
  "$BASE/scratch"
)

for path in "${default_paths[@]}"; do
  mkdir -p "$path"
  touch "$path/.gitkeep"
  echo "[+] Initialized default path: $path"
done

# If bucket configuration directory exists, create matching paths
if [ -d "$BUCKETS_DIR" ]; then
  echo "[+] Creating storage paths based on bucket configuration..."
  
  for config_file in "$BUCKETS_DIR"/*.buckets; do
    if [ -f "$config_file" ]; then
      service_name=$(basename "$config_file" .buckets)
      echo "[+] Processing storage paths for service: $service_name"
      
      while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        bucket=$(echo "$line" | sed 's/#.*//g' | xargs)
        if [ -n "$bucket" ]; then
          storage_path="$BASE/$bucket"
          mkdir -p "$storage_path"
          touch "$storage_path/.gitkeep"
          echo "[+] Initialized storage path: $storage_path"
        fi
      done < "$config_file"
    fi
  done
else
  echo "[!] Warning: Bucket configuration directory not found."
  echo "[+] Using default storage layout..."
  
  # Define default storage paths if bucket config not available
  declare -A paths=(
    ["$BASE/minio/data/recordings"]=".gitkeep"
    ["$BASE/minio/data/assets"]=".gitkeep"
    ["$BASE/minio/data/logs"]=".gitkeep"
    ["$BASE/obs/recordings"]=".gitkeep"
    ["$BASE/obs/logs"]=".gitkeep"
    ["$BASE/rtmp/recordings"]=".gitkeep"
    ["$BASE/rtmp/logs"]=".gitkeep"
    ["$BASE/rtmp/hls"]=".gitkeep"
    ["$BASE/shared-assets"]=".gitkeep"
    ["$BASE/scratch"]=".gitkeep"
    ["$BASE/screenshots"]=".gitkeep"
    ["$BASE/metadata-service/logs"]=".gitkeep"
    ["$BASE/metadata-service/thumbnails"]=".gitkeep"
    ["$BASE/metadata-service/jobs"]=".gitkeep"
    ["$BASE/metadata-service/metadata"]=".gitkeep"
  )

  for dir in "${!paths[@]}"; do
    mkdir -p "$dir"
    touch "$dir/${paths[$dir]}"
    echo "[+] Initialized $dir"
  done
fi

echo "[+] Storage layout under /mnt/b is ready."