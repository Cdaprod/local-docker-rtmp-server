#!/bin/bash
set -e

echo "[win-obs-container] Starting OBS config sync..."

# Sync from mounted Windows OBS path into container (expect user to mount via -v)
if [ -d "/obs/config" ]; then
  echo "[sync] Pulling configs from host into workspace..."
  rsync -a /obs/config/ /workspace/config/
fi

# Run custom tooling for JSON transformations (patch overlays, scenes, etc.)
echo "[sync] Applying automated patches or overlays..."
/usr/local/bin/obs-tools/apply-patches.sh

# Stage changes
echo "[git] Staging changes..."
cd /workspace && git add config/ assets/ || true

exec "$@"