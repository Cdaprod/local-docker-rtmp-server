#!/bin/bash

set -e

# Read service name and version
SERVICE_NAME=$(basename "$PWD")
VERSION=$(cat .version 2>/dev/null || echo "0.0.1")

# Auto-increment patch version
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# Save new version back
echo "$NEW_VERSION" > .version

# Build and tag
docker build -t cdaprod/$SERVICE_NAME:latest -t cdaprod/$SERVICE_NAME:v$NEW_VERSION .

echo "Built and tagged cdaprod/$SERVICE_NAME:v$NEW_VERSION"