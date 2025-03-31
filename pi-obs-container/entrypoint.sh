#!/bin/bash
set -e

export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

# Start Xvfb in the background on DISPLAY :99
Xvfb :99 -screen 0 1920x1080x24 -ac &
sleep 1
export DISPLAY=:99

# Merge external OBS configuration if available
if [ -d "/config/basic" ]; then
  echo "Merging external OBS configuration from /config..."
  mkdir -p /root/.config/obs-studio/basic/scenes
  mkdir -p /root/.config/obs-studio/basic/profiles/CdaprodOBS
  mkdir -p /root/.config/obs-studio/plugin_config/obs-websocket/
  mkdir -p /root/.config/obs-studio/plugin_config/rtmp-services/
  mkdir -p /root/.config/obs-studio/plugin_config/win-capture/

  # Copy basic settings
  cp -r /config/basic/scenes/* /root/.config/obs-studio/basic/scenes/ 2>/dev/null || true
  cp -r /config/basic/profiles/CdaprodOBS/* /root/.config/obs-studio/basic/profiles/CdaprodOBS/ 2>/dev/null || true
  cp -r /config/plugin_config/obs-websocket/* /root/.config/obs-studio/plugin_config/obs-websocket/ 2>/dev/null || true
  cp -r /config/plugin_config/rtmp-services/* /root/.config/obs-studio/plugin_config/rtmp-services/ 2>/dev/null || true
  cp -r /config/plugin_config/win-capture/* /root/.config/obs-studio/plugin_config/win-capture/ 2>/dev/null || true
fi

# Start XFCE desktop and VNC services
echo "Starting XFCE4 and VNC..."
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# Start OBS in GUI mode with the correct profile and scene collection
if [ -n "$DISPLAY" ]; then
  echo "Starting OBS with GUI and VNC enabled..."
  exec obs --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes' &
else
  echo "Starting OBS in headless mode..."
  exec obs --startstreaming --minimize-to-tray --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes' &
fi