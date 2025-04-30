#!/bin/bash
# Backup OBS scene collections and push to GitHub
BACKUP_DIR="/config/basic/scenes"
REPO_DIR="/config/obs-assets"

# Copy scenes to repo
rsync -av --delete "$BACKUP_DIR/" "$REPO_DIR/scenes/"

# Commit and push changes
cd "$REPO_DIR" || exit
git add .
git commit -m "Backup OBS scenes: $(date)"
git push origin main

echo "OBS scenes backed up and pushed to GitHub."