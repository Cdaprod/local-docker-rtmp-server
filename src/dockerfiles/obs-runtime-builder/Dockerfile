# ---------------------------------------------
# Stage 1: Base - Shared build environment
# ---------------------------------------------
FROM debian:bullseye AS base

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive
ARG CMAKE_VERSION=3.29.2

# Shared paths
ENV PATH="/usr/local/bin:$PATH"
ENV CMAKE_PREFIX_PATH="/usr/local"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV CMAKE_INCLUDE_PATH="/usr/local/include"
ENV CMAKE_LIBRARY_PATH="/usr/local/lib"

RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-utils curl ca-certificates gnupg lsb-release \
  build-essential git pkg-config wget unzip \
  yasm nasm \
  libgl1 libasound2 libv4l-0 libx11-xcb1 \
  libv4l-dev libdrm-dev v4l-utils \
  python3 python3-pip openbox fluxbox \
  libx264-dev libx265-dev libvpx-dev libmp3lame-dev \
  libopus-dev libvorbis-dev libaom-dev libass-dev \
  libfreetype6-dev libfontconfig1-dev \
  gstreamer1.0-omx gstreamer1.0-plugins-base gstreamer1.0-tools && \
  apt-get purge -y ffmpeg libav* || true && apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/*

# Install CMake
RUN curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  chmod +x cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  ./cmake-${CMAKE_VERSION}-linux-aarch64.sh --skip-license --prefix=/usr/local && \
  rm cmake-${CMAKE_VERSION}-linux-aarch64.sh && \
  ln -sf /usr/local/bin/cmake /usr/bin/cmake

# ---------------------------------------------
# Stage 2: Builder - Compile everything
# ---------------------------------------------
FROM base AS builder

# Build FFmpeg 6.1 with proper `.pc` files
RUN git clone --depth=1 -b release/6.1 https://github.com/FFmpeg/FFmpeg.git /ffmpeg && \
  cd /ffmpeg && \
  ./configure \
    --prefix=/usr/local \
    --enable-shared \
    --enable-gpl \
    --enable-nonfree \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libass \
    --enable-libfreetype \
    --enable-libfontconfig \
    --extra-libs="-lpthread -lm" && \
  make -j$(nproc) && make install && \
  ldconfig && \
  find /usr/local/lib/pkgconfig -name "*.pc"

RUN test -f /usr/local/include/libavcodec/version.h && echo "FFmpeg headers present." || (echo "Missing headers!" && exit 1) 

# Build OBS Studio
RUN git clone --recursive https://github.com/obsproject/obs-studio.git /tmp/obs && \
  cd /tmp/obs && mkdir build && cd build && \
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH \
    -DCMAKE_INCLUDE_PATH=$CMAKE_INCLUDE_PATH \
    -DCMAKE_LIBRARY_PATH=$CMAKE_LIBRARY_PATH \
    -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
    -DBUILD_BROWSER=OFF \
    -DFFmpeg_FIND_VERSION=ON \
    -DENABLE_PIPEWIRE=OFF \
    # -DFFMPEG_INCLUDE_DIRS="/usr/local/include" \
    # -DFFMPEG_LIBRARIES="/usr/local/lib/libavformat.so;/usr/local/lib/libavcodec.so;/usr/local/lib/libavutil.so;/usr/local/lib/libswscale.so;/usr/local/lib/libswresample.so" && \
  make -j$(nproc) && make install && \
  rm -rf /tmp/obs

# Build DistroAV (NDI support)
RUN git clone --recursive https://github.com/DistroAV/DistroAV.git /tmp/DistroAV && \
  cd /tmp/DistroAV && mkdir build && cd build && \
  cmake -DCMAKE_INSTALL_PREFIX=/usr .. && \
  make -j$(nproc) && make install && \
  rm -rf /tmp/DistroAV

# Install noVNC + Websockify
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
  ln -sf /opt/novnc/vnc_lite.html /opt/novnc/index.html && \
  git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# ---------------------------------------------
# Stage 3: Runtime - Slim container
# ---------------------------------------------
FROM debian:bullseye AS runtime

LABEL org.opencontainers.image.title="obs-runtime"
LABEL org.opencontainers.image.description="OBS Runtime with FFmpeg 6.1, DistroAV, noVNC"
LABEL org.opencontainers.image.authors="David Cannan <Cdaprod@Cdaprod.dev>"
LABEL org.opencontainers.image.version="1.2.1"
LABEL org.opencontainers.image.source="https://github.com/Cdaprod/obs-runtime-builder"
LABEL obs.capabilities="obs,ffmpeg6.1,ndi,novnc,supervisord"

ENV PATH="/usr/local/bin:$PATH"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
  libgl1 libasound2 libv4l-0 libx11-xcb1 \
  x11vnc xvfb novnc websockify supervisor \
  python3 python3-pip openbox fluxbox && \
  rm -rf /var/lib/apt/lists/*

# Copy built tools from builder stage
COPY --from=builder /usr /usr
COPY --from=builder /opt/novnc /opt/novnc

# Create expected runtime directories
RUN mkdir -p \
  /root/.config/obs-studio \
  /opt/obs/plugins \
  /root/assets \
  /root/scripts \
  /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4455

CMD ["/usr/bin/supervisord"]