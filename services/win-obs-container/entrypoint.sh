#!/bin/bash

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
backup_dir="/workspace/data/obs-backup/$timestamp"

echo "[INFO] Backing up OBS config and assets to: $backup_dir"
mkdir -p "$backup_dir"

rsync -av /workspace/config/ "$backup_dir/config/"
rsync -av /workspace/assets/ "$backup_dir/assets/"

echo "[INFO] Backup complete."
exec bash