#!/bin/bash

echo "Detecting video devices..."
for device in /dev/video*; do
  if [ -e "$device" ]; then
    echo "Found device: $device"
    v4l2-ctl --device="$device" --all | grep -E "Card type|Driver name"
  fi
done

echo "Checking display env..."
if [ -n "$DISPLAY" ]; then
  echo "X Display available: $DISPLAY"
else
  echo "No DISPLAY detected — fallback to tty/headless"
fi