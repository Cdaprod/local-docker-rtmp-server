#!/bin/bash
set -e

echo "Installing runtime dependencies..."
npm install --save \
  yargs \
  openai \
  fluent-ffmpeg \
  aws-sdk \
  axios \
  @sanity/client \
  sanity-plugin-media-library

echo "Installing development dependencies..."
npm install --save-dev \
  ts-node \
  typescript \
  @types/node \
  @types/yargs \
  @types/aws-sdk \
  @types/axios

echo "Dependency installation complete."