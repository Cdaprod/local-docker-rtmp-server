#!/bin/bash

SERVICE_NAME="$1"
COMPOSE_PATH="./$SERVICE_NAME/docker-compose.$SERVICE_NAME.yaml"

if [[ -z "$SERVICE_NAME" ]]; then
  echo "Usage: $0 <service-name>"
  exit 1
fi

if [[ ! -f "$COMPOSE_PATH" ]]; then
  echo "Error: Compose file $COMPOSE_PATH not found."
  exit 1
fi

echo "[streamstack] Rebuilding $SERVICE_NAME..."
docker-compose -f "$COMPOSE_PATH" --env-file .env up -d --build

echo "[streamstack] $SERVICE_NAME rebuilt and started."