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
    supervisor \
    gpg \
    dirmngr \
    # OBS WebSocket v5+ is built-in from v28+, no plugin needed
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
    libxcb-randr0 \
    libxcb-composite0 \
    libxcomposite-dev \
    libxinerama-dev \
    libxkbcommon-dev \
    libxcb-icccm4-dev \
    libxcb-keysyms1-dev \
    libxcb-shape0-dev \
    libavutil-dev \
    libx264-dev \
    libcurl4-openssl-dev \
    libfdk-aac-dev \
    libfontconfig1-dev \
    libluajit-5.1-dev \
    libpipewire-0.3-dev \
    libwayland-dev \
    qtbase5-dev \
    qtdeclarative5-dev \
    libqt5x11extras5-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libgl1-mesa-dev \
    mesa-common-dev \
    qt5-qmake \
    pkg-config \
    yasm \
    nasm \
    libx265-dev \
    libvpx-dev \
    libopus-dev \
    libvorbis-dev \
    # Clean up APT cache to reduce image size
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Build FFmpeg from Source =====
RUN cd /usr/src && \
    git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git -b release/5.1 && \
    cd FFmpeg && \
    ./configure \
      --prefix=/usr \
      --pkg-config-flags="--static" \
      --extra-cflags="-I/usr/local/include" \
      --extra-ldflags="-L/usr/local/lib" \
      --enable-gpl \
      --enable-libx264 \
      --enable-libx265 \
      --enable-libvpx \
      --enable-libfdk-aac \
      --enable-libopus \
      --enable-libvorbis \
      --enable-nonfree && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# ===== Verify FFmpeg Version =====
RUN ffmpeg -version

# ===== Install Latest CMake (v3.28+) =====
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    libcurl4-openssl-dev \
    libexpat1-dev \
    libz-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # Download and extract CMake 3.28+
    cd /usr/src && \
    curl -LO https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1.tar.gz && \
    tar -xvzf cmake-3.28.1.tar.gz && \
    cd cmake-3.28.1 && \
    ./bootstrap --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cmake --version

ENV PATH="/usr/local/bin:${PATH}"

# ===== Clone and Build OBS Studio from Source =====
RUN cd /usr/src && \
    git clone --recursive https://github.com/obsproject/obs-studio.git && \
    cd obs-studio && \
    mkdir build && cd build && \
    /usr/local/bin/cmake -DUNIX_STRUCTURE=1 -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_PIPEWIRE=OFF -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install

# ===== Ensure Supervisor Log Directory Exists =====
RUN mkdir -p /var/log/supervisor

# ===== Copy obs-cli binary from builder stage =====
COPY --from=builder /obs-cli-binary /usr/local/bin/obs-cli

# ===== Set Working Directory =====
WORKDIR /root

# ===== Create OBS Profile Directory If Missing =====
RUN mkdir -p /root/.config/obs-studio/basic/profiles/CdaprodOBS

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