#!/bin/bash
set -e

LOGFILE="/var/log/obs/detect-devices.log"
mkdir -p "$(dirname $LOGFILE)"

echo "[OBS DEVICES] $(date)" | tee -a "$LOGFILE"

# -- Auto-load v4l2loopback if not loaded
if ! lsmod | grep -q v4l2loopback; then
  echo "[INFO] v4l2loopback not loaded. Attempting to modprobe..." | tee -a "$LOGFILE"
  modprobe v4l2loopback devices=1 video_nr=10 card_label="obs_gui_stream" exclusive_caps=1 || {
    echo "[ERROR] modprobe failed. Run container with --privileged and mount /lib/modules" | tee -a "$LOGFILE"
  }
else
  echo "[INFO] v4l2loopback is already loaded." | tee -a "$LOGFILE"
fi

# -- List /dev/video* devices
echo "[INFO] Scanning for /dev/video* devices..." | tee -a "$LOGFILE"
for device in /dev/video*; do
  if [ -e "$device" ]; then
    echo "Found device: $device" | tee -a "$LOGFILE"
    v4l2-ctl --device="$device" --all | grep -E "Card type|Driver name" | tee -a "$LOGFILE"
  fi
done

# -- Check X display
if [ -n "$DISPLAY" ]; then
  echo "[INFO] X DISPLAY found: $DISPLAY" | tee -a "$LOGFILE"
else
  echo "[WARN] No DISPLAY variable -- likely running headless" | tee -a "$LOGFILE"
fi