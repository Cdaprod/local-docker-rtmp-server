# ===== Stage 1: Build obs-cli =====
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies
RUN apt-get update && apt-get install -y golang-go git && rm -rf /var/lib/apt/lists/*

# Clone obs-cli and build it
RUN git clone https://github.com/muesli/obs-cli.git && \
    cd obs-cli && \
    go build -o /obs-cli-binary  # <-- Rename the output binary explicitly

# ===== Stage 2: Final runtime image =====
FROM ubuntu:22.04
LABEL maintainer="David Cannan - Cdaprod@Cdaprod.dev"
LABEL version="1.1"
LABEL description="pi-obs-container with VNC and OBS Studio access via a browser."

ENV DEBIAN_FRONTEND=noninteractive

# Install essential dependencies, OBS Studio, XFCE, VNC, and noVNC
RUN apt-get update && apt-get install -y \
    ffmpeg \
    v4l-utils \
    libv4l-dev \
    qtbase5-dev \
    libxcb-xinerama0 \
    libxcomposite-dev \
    libx11-dev \
    libgl1-mesa-glx \
    libwayland-dev \
    libpulse-dev \
    curl \
    cmake \
    build-essential \
    ca-certificates \
    vlc \
    obs-studio \
    obs-websocket \
    xfce4 \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy obs-cli binary from builder stage
COPY --from=builder /obs-cli-binary /usr/local/bin/obs-cli

# Copy helper scripts
COPY detect-devices.sh /usr/local/bin/detect-devices.sh
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/supervisord.conf
RUN chmod +x /usr/local/bin/detect-devices.sh /entrypoint.sh

# Create noVNC web directory
RUN mkdir -p /usr/share/novnc/utils/websockify && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Expose VNC, WebSockets, and OBS WebSocket ports
EXPOSE 5900 6080 4455

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]