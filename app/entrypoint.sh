#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define constants
MOUNT_POINT="/mnt/nas"
NGINX_TEMPLATE="/etc/nginx/nginx.conf.template"
NGINX_CONF="/etc/nginx/nginx.conf"
CREDENTIALS_SRC="/app/credentials.json"
CREDENTIALS_DEST="/etc/credentials.json"

# Function to mount NAS storage
mount_nas() {
  echo "Mounting NAS storage..."
  if ! mount | grep -q "$MOUNT_POINT"; then
    mkdir -p "$MOUNT_POINT"  # Ensure the mount point directory exists
    mount -t cifs \
      -o username="${NAS_USERNAME}",password="${NAS_PASSWORD}",rw,iocharset=utf8,vers=3.0 \
      //"${NAS_IP_OR_HOSTNAME}"/"${NAS_SHARE_NAME}" "$MOUNT_POINT"
    echo "NAS mounted successfully at $MOUNT_POINT."
  else
    echo "NAS is already mounted at $MOUNT_POINT."
  fi
}

# Function to fetch Twitch stream URL
fetch_twitch_url() {
  echo "Fetching Twitch stream URL..."
  if command -v streamlink > /dev/null 2>&1; then
    TWITCH_STREAM_URL=$(streamlink "https://twitch.tv/${TWITCH_CHANNEL_NAME}" best --stream-url)
    if [ -z "$TWITCH_STREAM_URL" ]; then
      echo "Failed to fetch Twitch stream URL. Ensure your Twitch channel name is correct."
      exit 1
    fi
    echo "Twitch stream URL fetched successfully: $TWITCH_STREAM_URL"
  else
    echo "Streamlink is not installed. Please install it to fetch Twitch stream URLs."
    exit 1
  fi
}

# Function to generate nginx.conf from template
generate_nginx_conf() {
  echo "Generating nginx configuration..."
  if [ -f "$NGINX_TEMPLATE" ]; then
    envsubst '$VIDEO_ID $STREAM_KEY $TWITCH_STREAM_URL' < "$NGINX_TEMPLATE" > "$NGINX_CONF"
    echo "nginx.conf generated successfully."
  else
    echo "nginx.conf.template not found at $NGINX_TEMPLATE. Ensure the template exists."
    exit 1
  fi
}

# Function to copy Google credentials.json
copy_credentials() {
  echo "Copying Google credentials.json..."
  if [ -f "$CREDENTIALS_SRC" ]; then
    cp "$CREDENTIALS_SRC" "$CREDENTIALS_DEST"
    echo "Google credentials.json copied successfully."
  else
    echo "credentials.json not found in $CREDENTIALS_SRC. Ensure the file exists."
    exit 1
  fi
}

# Mount NAS storage
mount_nas

# Fetch Twitch Stream URL
fetch_twitch_url

# Export variables for envsubst
export VIDEO_ID
export STREAM_KEY
export TWITCH_STREAM_URL

# Generate nginx.conf from template
generate_nginx_conf

# Copy Google credentials.json
copy_credentials

# Start Nginx
echo "Starting Nginx..."
nginx -g 'daemon off;'