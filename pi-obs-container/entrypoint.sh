#!/bin/bash

# Detect connected video inputs
/usr/local/bin/detect-devices.sh

# If display available, launch full GUI OBS
if [ -n "$DISPLAY" ]; then
  echo "Starting OBS with GUI..."
  exec obs --startstreaming --profile 'PiProfile' --collection 'Default'
else
  echo "Starting OBS in CLI mode..."
  exec obs --startstreaming --minimize-to-tray
fi