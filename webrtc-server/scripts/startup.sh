#!/bin/sh
set -e

# ==============================================================================
# WebRTC Server Startup Script
# This script launches Coturn and the Node.js signaling server together
# ==============================================================================

echo "[INIT] Starting WebRTC Service Stack..."

# --- Validate required environment variables ---
: "${TURN_USERNAME:?TURN_USERNAME is not set. Exiting.}"
: "${TURN_PASSWORD:?TURN_PASSWORD is not set. Exiting.}"

# --- Start Coturn (TURN/STUN Server) ---
echo "[INIT] Launching Coturn server with provided credentials..."
turnserver \
  --listening-port=3478 \
  --realm=webrtc.local \
  --user="${TURN_USERNAME}:${TURN_PASSWORD}" \
  --min-port=49152 \
  --max-port=65535 \
  --fingerprint \
  --lt-cred-mech \
  --no-tls \
  --verbose \
  --allow-loopback-peers \
  --mobility \
  --listening-ip=0.0.0.0 \
  --relay-ip=0.0.0.0 \
  --total-quota=100 \
  --max-bps=0 \
  --no-rest \
  --daemon

echo "[OK] Coturn server is running."

# --- Start the Node.js signaling server ---
echo "[INIT] Launching WebRTC signaling server..."
cd /app

if [ ! -d "node_modules" ]; then
  echo "[INFO] Installing Node.js dependencies..."
  npm install
fi

echo "[INFO] Starting signaling server..."
exec node server.js