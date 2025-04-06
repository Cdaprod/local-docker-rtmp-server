#!/bin/sh

: "${CAPTURE_MODE:=desktop}"
: "${VIDEO_DEVICE:=/dev/video0}"
: "${STREAM_KEY:=cam01}"
: "${RTMP_URL:=rtmp://rtmp-service/live}"

if [ "$CAPTURE_MODE" = "desktop" ]; then
    echo "[videos-relayed] Capturing Wayland desktop via PipeWire to $RTMP_URL/$STREAM_KEY"
    exec ffmpeg -f pipewire -i default -c:v libx264 -preset veryfast -f flv "$RTMP_URL/$STREAM_KEY"
else
    echo "[videos-relayed] Capturing video device $VIDEO_DEVICE to $RTMP_URL/$STREAM_KEY"
    exec ffmpeg -f v4l2 -i "$VIDEO_DEVICE" -c:v libx264 -preset veryfast -f flv "$RTMP_URL/$STREAM_KEY"
fi