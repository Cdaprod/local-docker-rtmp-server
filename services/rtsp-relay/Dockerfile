# Base: Lightweight Debian-based image for ARM or AMD64
FROM debian:bullseye-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download rtsp-simple-server
RUN mkdir -p /rtsp-simple-server
WORKDIR /rtsp-simple-server
RUN curl -L -o rtsp-simple-server.tar.gz https://github.com/aler9/rtsp-simple-server/releases/latest/download/rtsp-simple-server_v0.21.1_linux_amd64.tar.gz && \
    tar -xvzf rtsp-simple-server.tar.gz && \
    rm rtsp-simple-server.tar.gz

# Copy your RTSP config
COPY rtsp-simple-server.yml .

# Expose RTSP port
EXPOSE 8554/tcp

# Entrypoint
CMD ["./rtsp-simple-server", "rtsp-simple-server.yml"]