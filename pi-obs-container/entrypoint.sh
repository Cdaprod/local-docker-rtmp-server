#!/bin/bash
set -e

# ====== Set XDG_RUNTIME_DIR and Permissions ======
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

# ====== Start Xvfb (Virtual Display) ======
echo "[INFO] Starting Xvfb on DISPLAY :99..."
Xvfb :99 -screen 0 1920x1080x24 -ac &
sleep 1  # Give Xvfb a moment to initialize
export DISPLAY=:99

# ====== Merge External OBS Configurations ======
if [ -d "/config/basic" ]; then
  echo "[INFO] Merging external OBS configuration from /config..."

  # Ensure required directories exist
  mkdir -p /root/.config/obs-studio/basic/scenes
  mkdir -p /root/.config/obs-studio/basic/profiles/CdaprodOBS
  mkdir -p /root/.config/obs-studio/plugin_config/obs-websocket/
  mkdir -p /root/.config/obs-studio/plugin_config/rtmp-services/
  mkdir -p /root/.config/obs-studio/plugin_config/win-capture/

  # Copy OBS configurations (with error suppression to avoid warnings)
  cp -rf /config/basic/scenes/* /root/.config/obs-studio/basic/scenes/ 2>/dev/null || true
  cp -rf /config/basic/profiles/CdaprodOBS/* /root/.config/obs-studio/basic/profiles/CdaprodOBS/ 2>/dev/null || true
  cp -rf /config/plugin_config/obs-websocket/* /root/.config/obs-studio/plugin_config/obs-websocket/ 2>/dev/null || true
  cp -rf /config/plugin_config/rtmp-services/* /root/.config/obs-studio/plugin_config/rtmp-services/ 2>/dev/null || true
  cp -rf /config/plugin_config/win-capture/* /root/.config/obs-studio/plugin_config/win-capture/ 2>/dev/null || true
fi

# ====== Start XFCE and VNC Services ======
echo "[INFO] Starting XFCE4 and VNC services..."
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# ====== Start OBS with Appropriate Mode ======
if [ -n "$DISPLAY" ]; then
  echo "[INFO] Starting OBS with GUI and VNC enabled..."
  exec obs --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes' &
else
  echo "[INFO] Starting OBS in headless mode..."
  exec obs --startstreaming --minimize-to-tray --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes' &
fi