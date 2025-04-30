#!/bin/bash

set -e

BASE="/mnt/b/rpi_sync"
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

  ["$BASE/metadata/logs"]=".gitkeep"
)

for dir in "${!paths[@]}"; do
  mkdir -p "$dir"
  touch "$dir/${paths[$dir]}"
  echo "[+] Initialized $dir"
done

echo "Storage layout under /mnt/b is ready."