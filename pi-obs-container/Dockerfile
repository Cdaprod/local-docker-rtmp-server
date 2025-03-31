# ===== Stage 1: Build obs-cli =====
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies for building obs-cli
RUN apt-get update && apt-get install -y \
    golang-go \
    git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Clone obs-cli and build it
RUN git clone https://github.com/muesli/obs-cli.git && \
    cd obs-cli && \
    go build -o /obs-cli-binary

# ===== Stage 2: Final runtime image =====
FROM ubuntu:22.04
LABEL maintainer="David Cannan - Cdaprod@Cdaprod.dev"
LABEL version="1.1"
LABEL description="pi-obs-container with VNC and OBS Studio access via a browser."

ENV DEBIAN_FRONTEND=noninteractive

# ===== System and OBS Dependencies =====
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core system utilities and build tools
    curl \
    ca-certificates \
    build-essential \
    cmake \
    supervisor \
    \
    # OBS and multimedia utilities
    obs-studio \
    obs-websocket \
    ffmpeg \
    vlc \
    \
    # VNC, X11, and GUI utilities
    xfce4 \
    x11vnc \
    xvfb \
    novnc \
    websockify \
    xserver-xorg-video-dummy \
    \
    # X11 and GUI-related dependencies
    libx11-dev \
    libxcb1 \
    libxcb-xinerama0 \
    libxext6 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libxrender1 \
    libxi6 \
    libxtst6 \
    \
    # OpenGL and EGL support for graphics
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libegl1-mesa \
    mesa-utils \
    \
    # Audio and multimedia
    libasound2 \
    libpulse-dev \
    \
    # Video4Linux utilities and drivers
    v4l-utils \
    libv4l-dev \
    \
    # Wayland support
    libwayland-dev \
    \
    # Clean up APT cache to reduce image size
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Copy obs-cli binary from builder stage =====
COPY --from=builder /obs-cli-binary /usr/local/bin/obs-cli

# ===== Copy OBS Config Files Correctly =====
COPY config/basic/profiles/CdaprodOBS /root/.config/obs-studio/basic/profiles/CdaprodOBS/
COPY config/basic/scenes /root/.config/obs-studio/basic/scenes/
COPY config/global.ini /root/.config/obs-studio/global.ini
COPY config/user.ini /root/.config/obs-studio/user.ini

# Copy plugin configurations in one go
COPY config/plugin_config /root/.config/obs-studio/plugin_config/

# ===== Copy helper scripts =====
COPY detect-devices.sh /usr/local/bin/detect-devices.sh
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Make sure all scripts are executable
RUN chmod +x /usr/local/bin/detect-devices.sh /entrypoint.sh

# ===== Create noVNC web directory =====
RUN mkdir -p /usr/share/novnc/utils/websockify && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# ===== Expose VNC, WebSockets, and OBS WebSocket ports =====
EXPOSE 5900 6080 4455

# ===== Set entrypoint =====
ENTRYPOINT ["/entrypoint.sh"]