# ===== Stage 1: Build obs-cli =====
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y golang-go git && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/muesli/obs-cli.git && \
    cd obs-cli && \
    go build && \
    mv obs-cli /obs-cli

# ===== Stage 2: Final runtime image =====
FROM ubuntu:22.04
LABEL maintainer="Your Name <your.email@example.com>"
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
    xfce4 \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install OBS NDI Plugin and runtime
RUN curl -LO https://github.com/Palakis/obs-ndi/releases/download/4.9.1/obs-ndi-4.9.1-Ubuntu20.04.deb && \
    dpkg -i obs-ndi-4.9.1-Ubuntu20.04.deb && rm obs-ndi-4.9.1-Ubuntu20.04.deb && \
    curl -LO https://github.com/obsproject/obs-studio/releases/download/27.2.4/NDI-runtime-4.5.1-Linux-x86_64.deb && \
    dpkg -i NDI-runtime-4.5.1-Linux-x86_64.deb && rm NDI-runtime-4.5.1-Linux-x86_64.deb

# Copy obs-cli binary from builder stage
COPY --from=builder /obs-cli /usr/local/bin/obs-cli

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