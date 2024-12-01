FROM tiangolo/nginx-rtmp

# Install necessary tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    cifs-utils \
    streamlink \
    curl \
    gettext-base \
    jq \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create directories for assets, recordings, and HLS
RUN mkdir -p \
    /var/www/recordings \
    /usr/share/nginx/html/assets \
    /tmp/hls \
    /app/scripts \
    && chmod -R 755 /var/www/recordings /usr/share/nginx/html/assets /tmp/hls

# Copy specific asset files (ensure this path is correct)
COPY ./public/assets/*.jpeg /usr/share/nginx/html/assets/
COPY ./public/assets/stream-viewer.html /usr/share/nginx/html/assets/

# Copy configuration and scripts
COPY ./nginx.conf.template /etc/nginx/nginx.conf.template
COPY ./entrypoint.sh /entrypoint.sh
COPY ./scripts/ /app/scripts/

# Install Python dependencies (ensure requirements.txt exists)
RUN pip install -r /app/scripts/requirements.txt

# Set proper permissions for scripts
RUN chmod +x /entrypoint.sh /app/scripts/*

# Expose ports
EXPOSE 1935 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -f http://localhost:8080/health || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]