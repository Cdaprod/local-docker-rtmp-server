#!/bin/bash
# Sync OBS assets from GitHub to Pi OBS container
REPO_URL="https://github.com/Cdaprod/obs-assets.git"
DEST_DIR="/config/obs-assets"

# Pull latest changes or clone if not existing
if [ ! -d "$DEST_DIR/.git" ]; then
    echo "Cloning OBS asset repository..."
    git clone "$REPO_URL" "$DEST_DIR"
else
    echo "Updating OBS asset repository..."
    cd "$DEST_DIR" || exit
    git pull
fi

# Copy assets to OBS config
rsync -av --delete "$DEST_DIR/assets/" /config/basic/scenes/
rsync -av --delete "$DEST_DIR/profiles/" /config/basic/profiles/

echo "OBS assets successfully synced."