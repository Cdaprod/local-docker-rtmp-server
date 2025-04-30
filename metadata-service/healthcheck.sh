#!/bin/bash
set -euo pipefail

# Define the RabbitMQ host and credentials from environment variables
RABBITMQ_HOST="${RABBITMQ_HOST:-localhost}"
RABBITMQ_USER="${RABBITMQ_DEFAULT_USER:-guest}"
RABBITMQ_PASS="${RABBITMQ_DEFAULT_PASS:-guest}"

# Check if RabbitMQ is accessible
check_rabbitmq() {
    curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" "http://${RABBITMQ_HOST}:15672/api/overview" | grep '"status":"ok"' > /dev/null 2>&1
}

# Check if the service is healthy
if check_rabbitmq; then
    echo "Metadata Enricher: RabbitMQ connection is healthy."
    exit 0
else
    echo "Metadata Enricher: Unable to connect to RabbitMQ."
    exit 1
fi