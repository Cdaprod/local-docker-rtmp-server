FROM debian:bullseye

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies with v4l2m2m and optional OMX
RUN apt-get update && apt-get install -y \
    obs-studio ffmpeg curl \
    libgl1 libasound2 libv4l-0 libx11-xcb1 \
    x11vnc xvfb novnc websockify supervisor \
    git python3 python3-pip \
    openbox fluxbox \
    libv4l-dev libdrm-dev v4l-utils \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Optional: install OMX support (sometimes helps with legacy tools)
RUN apt-get update && apt-get install -y \
    gstreamer1.0-omx \
    gstreamer1.0-plugins-base \
    gstreamer1.0-tools

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    ln -s /opt/novnc/vnc_lite.html /opt/novnc/index.html && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# Build DistroAV (NDI)
RUN git clone --recursive https://github.com/DistroAV/DistroAV.git /tmp/DistroAV && \
    cd /tmp/DistroAV && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr .. && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/DistroAV

# OBS config + plugin dir (default prerequsites)
RUN mkdir -p \
    /root/.config/obs-studio \
    /opt/obs/plugins \
    /root/assets \
    /root/scripts \
    /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4455

CMD ["/usr/bin/supervisord"]