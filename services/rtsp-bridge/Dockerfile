# Start from lightweight Raspberry Pi-compatible base image
FROM balenalib/rpi-raspbian:bullseye-run

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    libcamera-apps \
    libcamera-utils \
    ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download rtsp-simple-server
RUN mkdir -p /rtsp-simple-server
WORKDIR /rtsp-simple-server
RUN curl -L -o rtsp-simple-server.tar.gz https://github.com/aler9/rtsp-simple-server/releases/latest/download/rtsp-simple-server_v0.21.1_linux_armv7.tar.gz && \
    tar -xvzf rtsp-simple-server.tar.gz && \
    rm rtsp-simple-server.tar.gz

# Copy local rtsp-simple-server.yml config
COPY rtsp-simple-server.yml .

# Expose RTSP port
EXPOSE 8554/tcp

# Entrypoint: Start rtsp-simple-server
CMD ["./rtsp-simple-server", "rtsp-simple-server.yml"]