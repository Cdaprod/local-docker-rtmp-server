#!/bin/bash
# Backup OBS scene configurations and push to GitHub
REPO_DIR="/config/obs-assets"
SCENE_DIR="/config/basic/scenes"
BACKUP_DIR="$REPO_DIR/scenes/backup"
DATE=$(date +'%Y-%m-%d_%H-%M-%S')

# Create a backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup current scenes
cp "$SCENE_DIR/Laptop_OBS_Scenes.json" "$BACKUP_DIR/scenes_backup_$DATE.json"
echo "Scenes backed up to $BACKUP_DIR/scenes_backup_$DATE.json"

# Push backup to GitHub
cd "$REPO_DIR" || exit
git add scenes/backup
git commit -m "Backup OBS scenes - $DATE"
git push origin main

echo "OBS scenes backed up and pushed to GitHub."