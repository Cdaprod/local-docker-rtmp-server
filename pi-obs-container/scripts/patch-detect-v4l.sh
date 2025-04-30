#!/bin/bash
set -e

echo "[INIT] Starting OBS video interface pre-check..."

# --- Check & Auto-load v4l2loopback ---
if ! lsmod | grep -q v4l2loopback; then
  echo "[INFO] v4l2loopback not loaded, attempting to load it..."
  modprobe v4l2loopback devices=1 video_nr=10 card_label="obs_gui_stream" exclusive_caps=1 || {
    echo "[ERROR] Failed to load v4l2loopback"
    exit 1
  }
else
  echo "[INFO] v4l2loopback already loaded"
fi

# --- Detect Devices ---
echo "[INFO] Enumerating /dev/video* devices..."
found=0
for device in /dev/video*; do
  if [ -e "$device" ]; then
    echo "[DEVICE] $device"
    v4l2-ctl --device="$device" --all | grep -E "Card type|Driver name"
    ((found++))
  fi
done

if [ "$found" -eq 0 ]; then
  echo "[WARN] No /dev/video* devices found."
fi

# --- Display Detection ---
if [ -n "$DISPLAY" ]; then
  echo "[INFO] X Display is active: $DISPLAY"
else
  echo "[INFO] No DISPLAY detected -- fallback to headless."
fi