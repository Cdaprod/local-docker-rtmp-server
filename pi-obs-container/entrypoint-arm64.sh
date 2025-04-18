#!/bin/bash

echo "[ENTRYPOINT] Starting OBS stack..."

# Start PulseAudio if not already running
pulseaudio --start

# Load loopback device (for OBS virtual cam or hw acceleration fallback)
modprobe v4l2loopback devices=1 video_nr=10 card_label="obs_gui_stream" exclusive_caps=1 || echo "v4l2loopback not available"

# Start everything else via Supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

# -------------------------------------------
# The following block was originally duplicated twice.
# It's commented out and handled cleanly above.
# -------------------------------------------

# #!/bin/bash
# pulseaudio --start
# Xvfb :0 -screen 0 1280x720x24 &
# x11vnc -display :0 -forever -nopw -shared -bg
# novnc_proxy --vnc localhost:5900 &
# DISPLAY=:0 obs --startstreaming --scene "Default" &
# tail -f /dev/null