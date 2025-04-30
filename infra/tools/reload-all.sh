#!/bin/bash

set -e

echo "[streamstack] Reloading all Docker Compose stacks..."

COMPOSES=(
  "tailscale-traefik/docker-compose.tailscale-traefik.yaml"
  "rtmp-service/docker-compose.rtmp-service.yaml"
  "obs-pi/docker-compose.obs-pi.yaml"
  "metadata-service/docker-compose.metadata-service.yaml"
  "webrtc/docker-compose.webrtc.yaml"
)

for compose in "${COMPOSES[@]}"; do
  echo "[+] Bringing up: $compose"
  docker-compose -f "$compose" --env-file .env up -d --remove-orphans
done

echo "[streamstack] Reload complete."