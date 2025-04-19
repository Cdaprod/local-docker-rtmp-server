FROM debian:bullseye

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive
ARG CMAKE_VERSION=3.29.2
ENV PATH="/usr/local/bin:$PATH"

# ---------------------------------------------
# Base System & Build Tools
# ---------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-utils curl ca-certificates gnupg lsb-release \
  build-essential git pkg-config wget unzip \
  libgl1 libasound2 libv4l-0 libx11-xcb1 \
  libv4l-dev libdrm-dev v4l-utils \
  x11vnc xvfb novnc websockify supervisor \
  python3 python3-pip \
  openbox fluxbox \
  yasm nasm libx264-dev libx265-dev libvpx-dev  \
  libmp3lame-dev libopus-dev libvorbis-dev libaom-dev \
  libass-dev libfreetype6-dev libfontconfig1-dev \
  gstreamer1.0-omx gstreamer1.0-plugins-base gstreamer1.0-tools \
  && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------
# Upgrade CMake
# ---------------------------------------------
RUN curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  chmod +x cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  ./cmake-${CMAKE_VERSION}-linux-aarch64.sh --skip-license --prefix=/usr/local && \
  rm cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  ln -sf /usr/local/bin/cmake /usr/bin/cmake

# ---------------------------------------------
# Build FFmpeg 6.1+
# ---------------------------------------------
RUN git clone --depth=1 -b release/6.1 https://github.com/FFmpeg/FFmpeg.git /ffmpeg && \
  cd /ffmpeg && \
  ./configure --prefix=/usr/local --enable-shared --enable-gpl --enable-nonfree \
    --enable-libx264 --enable-libx265 \
    --enable-libmp3lame --enable-libopus --enable-libvorbis \
    --enable-libvpx --enable-libass --enable-libfreetype --enable-libfontconfig && \
  make -j$(nproc) && make install && \
  rm -rf /ffmpeg && \
  apt-get purge -y ffmpeg libav* && apt-get autoremove -y

# ---------------------------------------------
# Set environment paths to prioritize /usr/local
# ---------------------------------------------
ENV CMAKE_PREFIX_PATH="/usr/local"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV CMAKE_INCLUDE_PATH="/usr/local/include"
ENV CMAKE_LIBRARY_PATH="/usr/local/lib"

# ---------------------------------------------
# Build OBS Studio (with correct FFmpeg linkage)
# ---------------------------------------------
RUN git clone --recursive https://github.com/obsproject/obs-studio.git /tmp/obs && \
  cd /tmp/obs && mkdir build && cd build && \
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_BROWSER=OFF \
    -DENABLE_PIPEWIRE=OFF \
    -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH \
    -DCMAKE_INCLUDE_PATH=$CMAKE_INCLUDE_PATH \
    -DCMAKE_LIBRARY_PATH=$CMAKE_LIBRARY_PATH \
    -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config && \
  make -j$(nproc) && make install && \
  rm -rf /tmp/obs

# ---------------------------------------------
# Build DistroAV (NDI support)
# ---------------------------------------------
RUN git clone --recursive https://github.com/DistroAV/DistroAV.git /tmp/DistroAV && \
  cd /tmp/DistroAV && mkdir build && cd build && \
  cmake -DCMAKE_INSTALL_PREFIX=/usr .. && \
  make -j$(nproc) && make install && \
  rm -rf /tmp/DistroAV

# ---------------------------------------------
# Install noVNC
# ---------------------------------------------
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
  ln -sf /opt/novnc/vnc_lite.html /opt/novnc/index.html && \
  git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# ---------------------------------------------
# OBS Runtime Configuration
# ---------------------------------------------
RUN mkdir -p \
  /root/.config/obs-studio \
  /opt/obs/plugins \
  /root/assets \
  /root/scripts \
  /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4455

CMD ["/usr/bin/supervisord"]