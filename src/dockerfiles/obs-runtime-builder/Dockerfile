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
    apt-utils \
    ca-certificates \
    curl \
    dpkg-dev \
    gcc \
    g++ \
    gnupg \
    git \
    lsb-release \
    pkg-config \
    python3 \
    python3-pip \
    unzip \
    wget \
    yasm \
    nasm \
    build-essential \
    libgl1 \
    libasound2 \
    libv4l-0 \
    libx11-xcb1 \
    libv4l-dev \
    libdrm-dev \
    v4l-utils \
    openbox \
    fluxbox \
    libx264-dev \
    libx265-dev \
    libvpx-dev \
    libmp3lame-dev \
    libopus-dev \
    libvorbis-dev \
    libaom-dev \
    libass-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    gstreamer1.0-omx \
    gstreamer1.0-plugins-base \
    gstreamer1.0-tools \
    qt6-base-dev \
    uthash-dev \
  && apt-get purge -y ffmpeg libav* || true \
  && apt-get autoremove -y \
  && apt-get install gcc g++ curl git -y \
  && rm -rf /var/lib/apt/lists/*

# Install CMake
RUN mkdir -p /tmp/cmake && \
    cd /tmp/cmake && \
    curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xzf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./bootstrap --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/cmake

# ---------------------------------------------
# Stage 2: Builder - Compile everything
# ---------------------------------------------
FROM base AS builder

# 1) Build FFmpeg 6.1 (native ARM64 build)
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
      --extra-libs="-lpthread -lm" \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && rm -rf /ffmpeg

# 2) Sanity-check that at least one version.h exists
RUN test -f /usr/local/include/libavcodec/version.h && echo "Headers OK" || (echo "Missing version.h!" && exit 1)

# 3) Patch every header for FFMPEG_VERSION
RUN grep -Rl "FFMPEG_VERSION" /usr/local/include \
    | xargs -I{} sed -i 's/^#define\s*FFMPEG_VERSION.*$/#define FFMPEG_VERSION "6.1"/' {}

# 4) Build OBS Studio (inject Qt6 path at configure time)
RUN git clone --recursive https://github.com/obsproject/obs-studio.git /tmp/obs && \
    cd /tmp/obs && mkdir build && cd build && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_PREFIX_PATH="/usr/local:/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/cmake/Qt6" \
      -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
      -DBUILD_BROWSER=OFF \
      -DENABLE_PIPEWIRE=OFF \
      -DUSE_PKG_CONFIG=ON \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/obs

# 5) Build DistroAV (NDI support)
RUN git clone --recursive https://github.com/DistroAV/DistroAV.git /tmp/DistroAV && \
    cd /tmp/DistroAV && mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr .. && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/DistroAV

# 6) noVNC + websockify
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    ln -sf /opt/novnc/vnc_lite.html /opt/novnc/index.html && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# ---------------------------------------------
# Stage 3: Runtime - Slim OBS runtime image
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

COPY --from=builder /usr /usr
COPY --from=builder /opt/novnc /opt/novnc

RUN mkdir -p \
    /root/.config/obs-studio \
    /opt/obs/plugins \
    /root/assets \
    /root/scripts \
    /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4455

CMD ["/usr/bin/supervisord"]
