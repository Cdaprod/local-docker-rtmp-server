# Base image for Nginx with RTMP module
FROM tiangolo/nginx-rtmp

# Install FFmpeg and additional utilities
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    cifs-utils \
    && rm -rf /var/lib/apt/lists/*

# Set up directories for recordings and assets
RUN mkdir -p /var/www/recordings \
    /usr/share/nginx/html/assets \
    /mnt/nas \
    /tmp/hls && \
    chmod -R 755 /var/www/recordings /usr/share/nginx/html/assets /tmp/hls

# Mount network storage during container runtime
COPY mount-nas.sh /usr/local/bin/mount-nas.sh
RUN chmod +x /usr/local/bin/mount-nas.sh

# Copy Nginx configuration and assets
COPY nginx.conf /etc/nginx/nginx.conf
COPY public/assets/ /usr/share/nginx/html/assets/

# Expose RTMP and HTTP ports
EXPOSE 1935 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -f http://localhost:8080/health || exit 1

# Default command with NAS mounting
CMD ["/bin/bash", "-c", "/usr/local/bin/mount-nas.sh && nginx -g 'daemon off;'"]