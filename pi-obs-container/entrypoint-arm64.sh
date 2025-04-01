#!/bin/bash

# Start pulse if not already
pulseaudio --start

# Start Xvfb
Xvfb :0 -screen 0 1280x720x24 &

# Start window manager if needed (optional)

# Start VNC server
x11vnc -display :0 -forever -nopw -shared -bg

# Start noVNC web
novnc_proxy --vnc localhost:5900 &

# Start OBS
DISPLAY=:0 obs --startstreaming --scene "Default" &

# Wait forever
tail -f /dev/null