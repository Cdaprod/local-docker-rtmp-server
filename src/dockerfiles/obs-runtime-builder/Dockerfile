FROM debian:bullseye

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

ARG CMAKE_VERSION=3.29.2

# Base system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils ca-certificates curl gnupg lsb-release \
    build-essential git cmake pkg-config \
    libgl1 libasound2 libv4l-0 libx11-xcb1 \
    libv4l-dev libdrm-dev v4l-utils \
    x11vnc xvfb novnc websockify supervisor \
    python3 python3-pip \
    openbox fluxbox \
    ffmpeg obs-studio \
 && rm -rf /var/lib/apt/lists/*

# Upgrade CMake (ensure consistent plugin compatibility with OBS >=3.28)
RUN curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
    chmod +x cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
    ./cmake-${CMAKE_VERSION}-linux-aarch64.sh --skip-license --prefix=/usr/local && \
    rm cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
    ln -sf /usr/local/bin/cmake /usr/bin/cmake

# Optional OMX codecs (legacy support)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gstreamer1.0-omx \
    gstreamer1.0-plugins-base \
    gstreamer1.0-tools \
 && rm -rf /var/lib/apt/lists/*

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    ln -sf /opt/novnc/vnc_lite.html /opt/novnc/index.html && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# Build DistroAV NDI support (for OBS scene piping)
RUN git clone --recursive https://github.com/DistroAV/DistroAV.git /tmp/DistroAV && \
    cd /tmp/DistroAV && mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr .. && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/DistroAV

# OBS Runtime Config Paths
RUN mkdir -p \
    /root/.config/obs-studio \
    /opt/obs/plugins \
    /root/assets \
    /root/scripts \
    /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4455
ENV PATH="/usr/local/bin:$PATH"

CMD ["/usr/bin/supervisord"]