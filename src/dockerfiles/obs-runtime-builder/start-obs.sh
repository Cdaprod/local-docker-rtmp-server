#!/bin/bash

# Start OBS inside virtual framebuffer
xvfb-run --auto-servernum --server-num=1 \
  --server-args="-screen 0 1280x720x24" \
  /usr/bin/obs &

# Wait a few seconds for Xvfb to start
sleep 5

# Start VNC server for display :99 (xvfb default)
x11vnc -display :99 -forever -nopw -shared