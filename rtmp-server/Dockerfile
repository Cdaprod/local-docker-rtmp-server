# -----------------------------------------------
# Stage 1: Builder – For Python and system deps
# -----------------------------------------------
FROM python:3.9-slim AS rtmp-builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    cifs-utils \
    curl \
    streamlink \
    ffmpeg \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for cache efficiency
COPY ./scripts/requirements.txt ./scripts/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r ./scripts/requirements.txt

# Copy scripts into place
COPY ./scripts /app/scripts
RUN chmod +x /app/scripts/*

# -----------------------------------------------
# Stage 2: Final Runtime – Based on nginx-rtmp
# -----------------------------------------------
FROM tiangolo/nginx-rtmp

LABEL org.opencontainers.image.title="rtmp-server" \
      org.opencontainers.image.description="Enhanced RTMP streaming server with FFmpeg, Streamlink, and Python scripting support" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="David Cannan <Cdaprod@Cdaprod.dev>" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/Cdaprod/local-docker-rtmp-server" \
      com.cdaprod.role="RTMP Streaming Server" \
      com.cdaprod.module="FFmpeg, Python overlay, web dashboard, auto-record" \
      com.cdaprod.env="production" 

# Copy dependencies and tools from builder
COPY --from=rtmp-builder /app/scripts /app/scripts

# Install runtime tools needed in container
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    cifs-utils \
    streamlink \
    curl \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Create persistent directories
RUN mkdir -p \
    /var/www/recordings \
    /usr/share/nginx/html/assets \
    /tmp/hls \
    && chmod -R 755 /var/www/recordings /usr/share/nginx/html/assets /tmp/hls

# Copy static assets
COPY ./public/assets/*.jpeg /usr/share/nginx/html/assets/
COPY ./public/assets/stream-viewer.html /usr/share/nginx/html/assets/

# Copy entrypoint and config
COPY ./nginx.conf.template /etc/nginx/nginx.conf.template
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1935 8080

HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]