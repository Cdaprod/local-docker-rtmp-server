#!/bin/bash

# Detect connected video inputs
/usr/local/bin/detect-devices.sh

# Setup OBS Scene Collection
mkdir -p /root/.config/obs-studio/basic/scenes/
cp /config/basic/scenes/*.json /root/.config/obs-studio/basic/scenes/

# Setup OBS Profiles
mkdir -p /root/.config/obs-studio/basic/profiles/CdaprodOBS/
cp /config/basic/profiles/CdaprodOBS/* /root/.config/obs-studio/basic/profiles/CdaprodOBS/

# OBS-Websocket Config
mkdir -p /root/.config/obs-studio/plugin_config/obs-websocket/
cp /config/plugin_config/obs-websocket/config.json /root/.config/obs-studio/plugin_config/obs-websocket/

# Launch OBS directly (GUI or CLI)
if [ -n "$DISPLAY" ]; then
  echo "Starting OBS with GUI..."
  exec obs --startstreaming --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes'
else
  echo "Starting OBS in headless CLI mode..."
  exec obs --startstreaming --minimize-to-tray --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes'
fi