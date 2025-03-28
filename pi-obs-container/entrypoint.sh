#!/bin/bash
set -e

# Detect connected video devices
/usr/local/bin/detect-devices.sh

# Merge external OBS configuration if available
if [ -d "/config" ]; then
  echo "Merging external OBS configuration from /config..."
  mkdir -p /root/.config/obs-studio/basic/scenes
  mkdir -p /root/.config/obs-studio/basic/profiles/CdaprodOBS
  mkdir -p /root/.config/obs-studio/plugin_config/obs-websocket/
  cp -r /config/basic/scenes/* /root/.config/obs-studio/basic/scenes/ 2>/dev/null || true
  cp -r /config/basic/profiles/CdaprodOBS/* /root/.config/obs-studio/basic/profiles/CdaprodOBS/ 2>/dev/null || true
  cp -r /config/plugin_config/obs-websocket/* /root/.config/obs-studio/plugin_config/obs-websocket/ 2>/dev/null || true
fi

# Start XFCE desktop and VNC services
echo "Starting XFCE4 and VNC..."
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# Launch OBS based on GUI availability
if [ -n "$DISPLAY" ]; then
  echo "Starting OBS with GUI..."
  exec obs --startstreaming --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes'
else
  echo "Starting OBS in headless CLI mode..."
  exec obs --startstreaming --minimize-to-tray --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes'
fi