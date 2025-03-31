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
    build-essential \
    cmake \
    supervisor \
    gpg \
    dirmngr \
    # OBS WebSocket v5+ is built-in from v28+, no plugin needed
    ffmpeg \
    vlc \
    # VNC, X11, and GUI utilities
    xfce4 \
    x11vnc \
    xvfb \
    novnc \
    websockify \
    xserver-xorg-video-dummy \
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
    # OpenGL and EGL support for graphics
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libegl1-mesa \
    mesa-utils \
    # Audio and multimedia
    libasound2 \
    libpulse-dev \
    # Video4Linux utilities and drivers
    v4l-utils \
    libv4l-dev \
    # Wayland support
    libwayland-dev \
    # Clean up APT cache to reduce image size
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Install OBS Studio with Correct GPG Keyring =====
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    gnupg \
    ca-certificates && \
    # Disable init-related services to avoid D-Bus and policy-rc.d errors
    echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d && \
    mkdir -p /var/run/dbus && \
    echo 'exit 0' > /usr/sbin/invoke-rc.d && chmod +x /usr/sbin/invoke-rc.d && \
    # Create directory for keyrings
    mkdir -p /etc/apt/keyrings && \
    # Download correct GPG key from Launchpad and dearmor
    # Correct method to fetch OBS Studio key
    curl -fsSL http://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBC7345F522079769F5BBE987EFC71127F425E228 | \
    gpg --dearmor | tee /etc/apt/keyrings/obs-studio.gpg > /dev/null || { echo "GPG Key download failed"; exit 1; }
    # Add OBS Studio PPA with signed-by key
    echo "deb [signed-by=/etc/apt/keyrings/obs-studio.gpg] http://ppa.launchpad.net/obsproject/obs-studio/ubuntu jammy main" | tee /etc/apt/sources.list.d/obs-studio.list
    apt-get update && \
    apt-get install -y obs-studio && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Ensure Supervisor Log Directory Exists =====
RUN mkdir -p /var/log/supervisor

# ===== Copy obs-cli binary from builder stage =====
COPY --from=builder /obs-cli-binary /usr/local/bin/obs-cli

# ===== Set Working Directory =====
WORKDIR /root

# ===== Create OBS Profile Directory If Missing =====
RUN [ -d /root/.config/obs-studio/basic/profiles/CdaprodOBS ] || mkdir -p /root/.config/obs-studio/basic/profiles/CdaprodOBS

# ===== Copy OBS profiles and scenes =====
COPY config/basic/profiles/CdaprodOBS /root/.config/obs-studio/basic/profiles/CdaprodOBS/
COPY config/basic/scenes /root/.config/obs-studio/basic/scenes/

# ===== Copy global and user settings =====
COPY config/global.ini /root/.config/obs-studio/global.ini
COPY config/user.ini /root/.config/obs-studio/user.ini

# ===== Copy plugin configurations =====
COPY config/plugin_config /root/.config/obs-studio/plugin_config/

# ===== Copy helper scripts =====
COPY detect-devices.sh /usr/local/bin/detect-devices.sh
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Make sure all scripts are executable
RUN chmod +x /usr/local/bin/detect-devices.sh /entrypoint.sh

# ===== Set Correct Permissions for OBS Configuration =====
RUN chown -R root:root /root/.config/obs-studio

# ===== Create noVNC web directory =====
RUN mkdir -p /usr/share/novnc/utils/websockify && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# ===== Fix noVNC Proxy Path if Missing =====
RUN [ -f /usr/share/novnc/utils/novnc_proxy ] || ln -s /usr/share/novnc/utils/novnc_proxy /usr/bin/novnc_proxy

# ===== Healthcheck to Ensure NoVNC and OBS Services Are Up =====
HEALTHCHECK --interval=10s --timeout=5s --retries=3 CMD curl -f http://localhost:6080 || exit 1

# ===== Expose VNC, WebSockets, and OBS WebSocket ports =====
EXPOSE 5900 6080 4455

# ===== Set entrypoint =====
ENTRYPOINT ["/entrypoint.sh"]