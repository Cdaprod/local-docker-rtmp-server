# rtmp-server/Dockerfile
FROM tiangolo/nginx-rtmp

# Install FFmpeg for transcoding
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

RUN groupadd -g 9999 nginx && useradd -u 9999 -g nginx -s /sbin/nologin -M nginx

# Create directories
RUN mkdir -p /data/recordings \
    && mkdir -p /tmp/hls \
    && chown -R nginx:nginx /data/recordings /tmp/hls

# Expose RTMP and HTTP ports
EXPOSE 1935 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8080/health || exit 1