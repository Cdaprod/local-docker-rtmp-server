#!/bin/bash

echo "Mounting NAS storage..."
if ! mount | grep -q "/mnt/nas"; then
  mount -t cifs \
    -o username=${NAS_USERNAME},password=${NAS_PASSWORD},rw,iocharset=utf8,vers=3.0 \
    //${NAS_IP_OR_HOSTNAME}/${NAS_SHARE_NAME} /mnt/nas
  if [ $? -eq 0 ]; then
    echo "NAS mounted successfully."
  else
    echo "Failed to mount NAS. Check your configuration."
  fi
else
  echo "NAS is already mounted."
fi