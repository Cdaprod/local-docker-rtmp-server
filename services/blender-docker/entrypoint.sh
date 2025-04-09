#!/bin/bash

# Start virtual X session
Xvfb :0 -screen 0 1920x1080x24 &

# VNC
x11vnc -display :0 -forever -usepw -shared -rfbport 5900 &

# noVNC proxy
nohup /opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 5800 &

# Start FastAPI server
cd /app
DISPLAY=:0 uvicorn main:app --host 0.0.0.0 --port 8000