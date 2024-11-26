# Base Image
FROM tiangolo/nginx-rtmp

# Install FFmpeg for transcoding
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy assets (e.g., placeholder image)
COPY public/assets /app/public/assets

# Set permissions for the assets directory
RUN chown -R www-data:www-data /app/public/assets

# Create required directories
RUN mkdir -p /data/recordings /tmp/hls \
    && chown -R www-data:www-data /data/recordings /tmp/hls

# Expose RTMP and HTTP ports
EXPOSE 1935 18080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:18080/health || exit 1