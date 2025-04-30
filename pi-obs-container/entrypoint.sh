#!/bin/bash
set -e

# ====== Set XDG_RUNTIME_DIR and Permissions ======
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

# ====== Merge External OBS Configurations ======
if [ -d "/config/basic" ]; then
  echo "[INFO] Merging external OBS configuration from /config..."

  mkdir -p /root/.config/obs-studio/basic/scenes
  mkdir -p /root/.config/obs-studio/basic/profiles/CdaprodOBS
  mkdir -p /root/.config/obs-studio/plugin_config/obs-websocket/
  mkdir -p /root/.config/obs-studio/plugin_config/rtmp-services/
  mkdir -p /root/.config/obs-studio/plugin_config/win-capture/

  cp -rf /config/basic/scenes/* /root/.config/obs-studio/basic/scenes/ 2>/dev/null || true
  cp -rf /config/basic/profiles/CdaprodOBS/* /root/.config/obs-studio/basic/profiles/CdaprodOBS/ 2>/dev/null || true
  cp -rf /config/plugin_config/obs-websocket/* /root/.config/obs-studio/plugin_config/obs-websocket/ 2>/dev/null || true
  cp -rf /config/plugin_config/rtmp-services/* /root/.config/obs-studio/plugin_config/rtmp-services/ 2>/dev/null || true
  cp -rf /config/plugin_config/win-capture/* /root/.config/obs-studio/plugin_config/win-capture/ 2>/dev/null || true
fi

echo "[INFO] Starting all services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf