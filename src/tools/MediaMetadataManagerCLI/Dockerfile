FROM node:18-slim

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    exiftool \
    python3 \
    python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install required Python packages
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu \
    && pip3 install librosa transformers

# Create app directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install Node.js dependencies
RUN npm install

# Copy project files
COPY . .

# Create necessary directories
RUN mkdir -p src/tools/config \
    src/tools/cache \
    src/tools/analysis \
    src/tools/backups \
    src/tools/models \
    src/tools/python_scripts \
    src/tools/modules

# Make CLI executable
RUN chmod +x src/tools/MediaMetadataManagerCLI.js

# Create symlink to make the CLI easily accessible
RUN npm link

# Set environment variables
ENV NODE_ENV=production

# Set entrypoint
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]