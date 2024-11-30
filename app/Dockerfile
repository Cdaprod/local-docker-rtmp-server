FROM tiangolo/nginx-rtmp

# Install necessary tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    streamlink \
    curl \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy the specific asset file to the target directory
COPY /public/assets/*.jpeg /usr/share/nginx/html/assets/

# Set up directories
RUN mkdir -p \
    /var/www/recordings \
    /usr/share/nginx/html/assets \
    /tmp/hls \
    /app/scripts \
    && chmod -R 755 /var/www/recordings /usr/share/nginx/html/assets /tmp/hls

# Copy configuration files and scripts
COPY ./nginx.conf.template /etc/nginx/nginx.conf.template
COPY ./entrypoint.sh /entrypoint.sh
COPY ./scripts/ /app/scripts/
RUN chmod +x /entrypoint.sh /app/scripts/*

# Expose ports
EXPOSE 1935 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -f http://localhost:8080/health || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]