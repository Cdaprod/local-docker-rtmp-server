# ---------------------------------------------
# Base: Common system and build tool dependencies
# ---------------------------------------------
FROM debian:bullseye AS base

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive
ARG CMAKE_VERSION=3.29.2
ENV PATH="/usr/local/bin:$PATH"

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-utils curl ca-certificates gnupg lsb-release \
  build-essential git pkg-config wget unzip \
  libgl1 libasound2 libv4l-0 libx11-xcb1 \
  libv4l-dev libdrm-dev v4l-utils \
  python3 python3-pip \
  openbox fluxbox \
  yasm nasm libx264-dev libx265-dev libvpx-dev \
  libmp3lame-dev libopus-dev libvorbis-dev libaom-dev \
  libass-dev libfreetype6-dev libfontconfig1-dev \
  gstreamer1.0-omx gstreamer1.0-plugins-base gstreamer1.0-tools && \
  apt-get purge -y ffmpeg libav* || true && apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/*

# Install upgraded CMake
RUN curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  chmod +x cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  ./cmake-${CMAKE_VERSION}-linux-aarch64.sh --skip-license --prefix=/usr/local && \
  rm cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  ln -sf /usr/local/bin/cmake /usr/bin/cmake

ENV CMAKE_PREFIX_PATH="/usr/local"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV CMAKE_INCLUDE_PATH="/usr/local/include"
ENV CMAKE_LIBRARY_PATH="/usr/local/lib"

# ---------------------------------------------
# Builder: Compile FFmpeg, OBS, DistroAV
# ---------------------------------------------
FROM base AS builder

# Build FFmpeg 6.1+
RUN git clone --depth=1 -b release/6.1 https://github.com/FFmpeg/FFmpeg.git /ffmpeg && \
  cd /ffmpeg && \
  ./configure --prefix=/usr/local --enable-shared --enable-gpl --enable-nonfree \
    --enable-libx264 --enable-libx265 --enable-libmp3lame --enable-libopus \
    --enable-libvorbis --enable-libvpx --enable-libass \
    --enable-libfreetype --enable-libfontconfig && \
  make -j$(nproc) && make install && \
  rm -rf /ffmpeg

# Build OBS Studio
RUN git clone --recursive https://github.com/obsproject/obs-studio.git /tmp/obs && \
  cd /tmp/obs && mkdir build && cd build && \
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH} \
    -DCMAKE_INCLUDE_PATH=${CMAKE_INCLUDE_PATH} \
    -DCMAKE_LIBRARY_PATH=${CMAKE_LIBRARY_PATH} \
    -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
    -DFFMPEG_INCLUDE_DIRS=/usr/local/include \
    -DFFMPEG_LIBRARIES="/usr/local/lib/libavcodec.so;/usr/local/lib/libavformat.so;/usr/local/lib/libavutil.so;/usr/local/lib/libswscale.so;/usr/local/lib/libswresample.so" \
    -DFFMPEG_FOUND=TRUE \
    -DBUILD_BROWSER=OFF \
    -DENABLE_PIPEWIRE=OFF && \
  make -j$(nproc) && make install && \
  rm -rf /tmp/obs

# Build DistroAV (NDI support)
RUN git clone --recursive https://github.com/DistroAV/DistroAV.git /tmp/DistroAV && \
  cd /tmp/DistroAV && mkdir build && cd build && \
  cmake -DCMAKE_INSTALL_PREFIX=/usr .. && \
  make -j$(nproc) && make install && \
  rm -rf /tmp/DistroAV

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
  ln -sf /opt/novnc/vnc_lite.html /opt/novnc/index.html && \
  git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# ---------------------------------------------
# Runtime: Minimal final image with supervisor and OBS tools
# ---------------------------------------------
FROM debian:bullseye AS runtime

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  libgl1 libasound2 libv4l-0 libx11-xcb1 \
  x11vnc xvfb novnc websockify supervisor \
  python3 python3-pip \
  openbox fluxbox \
  gstreamer1.0-omx gstreamer1.0-plugins-base gstreamer1.0-tools && \
  rm -rf /var/lib/apt/lists/*

# Copy built binaries and assets
COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr /usr
COPY --from=builder /opt/novnc /opt/novnc

# Setup OBS runtime directories
RUN mkdir -p \
  /root/.config/obs-studio \
  /opt/obs/plugins \
  /root/assets \
  /root/scripts \
  /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4455

CMD ["/usr/bin/supervisord"]