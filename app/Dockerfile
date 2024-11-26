FROM tiangolo/nginx-rtmp

# Install necessary tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    streamlink \
    curl \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Set up directories
RUN mkdir -p \
    /var/www/recordings \
    /usr/share/nginx/html/assets \
    /tmp/hls \
    && chmod -R 755 /var/www/recordings /usr/share/nginx/html/assets /tmp/hls

# Copy configuration templates and assets
COPY ../credentials.json /etc/credentials.json       # Copy credentials.json
COPY ../.env /app/.env                               # Copy .env file (if needed by the container)
COPY ./nginx.conf.template /etc/nginx/nginx.conf.template
COPY ../public/assets/ /usr/share/nginx/html/assets/ # Copy public assets
COPY ./entrypoint.sh /entrypoint.sh

# Set permissions for entrypoint script
RUN chmod +x /entrypoint.sh

# Expose necessary ports
EXPOSE 1935 8080

# Health check for Nginx
HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the entrypoint script as the default command
CMD ["/entrypoint.sh"]