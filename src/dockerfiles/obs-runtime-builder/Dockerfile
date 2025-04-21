# ---------------------------------------------
# Stage 1: Base - Shared build environment
# ---------------------------------------------
FROM ubuntu:22.04 AS base

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    make \
    gnupg \
    lsb-release \
    unzip \
    wget \
    python3 \
    python3-pip \
    yasm \
    nasm \
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
    libssl-dev \
    openssl \
    zlib1g-dev \
    libxext-dev \
    libxfixes-dev \
    gstreamer1.0-omx \
    gstreamer1.0-plugins-base \
    gstreamer1.0-tools \
    uthash-dev \
    qt6-base-dev \
    qt6-base-dev-tools \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    libqt6svg6-dev \
    libqt6opengl6-dev \
    libqt6multimedia6-dev \
    libqt6waylandclient6-dev \
  && apt-get purge -y ffmpeg libav* || true \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    cmake \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------
# Stage 2: Builder - Compile everything
# ---------------------------------------------
FROM base AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
  dpkg-dev \
  pkg-config \
  libtool \
  autoconf \
  automake \
  gettext \
  texinfo

# 1) Build FFmpeg 6.1 (native ARM64 build)
RUN ARCH_DIR=$(find /usr/lib -type d -name "*pkgconfig" | grep -E 'linux-gnu/pkgconfig' | head -n1) && \
    PKG_CONFIG_PATH="${ARCH_DIR}:/usr/share/pkgconfig" && \
    PKG_CONFIG_LIBDIR="${ARCH_DIR}:/usr/share/pkgconfig" && \
    echo "Using ARCH_DIR=$ARCH_DIR" && \
    find "$ARCH_DIR" -name "libass*.pc" && \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR" \
    pkg-config --exists libass && echo "libass FOUND" || (echo "libass NOT FOUND" && exit 1) && \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH" PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR" \
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
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /ffmpeg

# 2) Confirm FFmpeg install
RUN test -f /usr/local/include/libavcodec/version.h && echo "Headers OK" || (echo "Missing version.h!" && exit 1)

# 3) Patch headers with version string
RUN grep -Rl "FFMPEG_VERSION" /usr/local/include \
    | xargs -I{} sed -i 's/^#define\s*FFMPEG_VERSION.*$/#define FFMPEG_VERSION "6.1"/' {}

# 4) Build OBS Studio
RUN git clone --recursive https://github.com/obsproject/obs-studio.git /tmp/obs && \
    cd /tmp/obs && mkdir build && cd build && \
    ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH) && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_PREFIX_PATH="/usr/local:/usr/lib/${ARCH}/cmake:/usr/lib/${ARCH}/cmake/Qt6" \
      -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
      -DBUILD_BROWSER=OFF \
      -DBUILD_LIBOBS=ON \
      -DENABLE_PIPEWIRE=OFF \
      -DUSE_PKG_CONFIG=ON \
      -DCMAKE_MODULE_PATH="/usr/share/cmake-3.25/Modules" && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/obs

# 5) Build DistroAV (NDI support)
RUN git clone --recursive https://github.com/DistroAV/DistroAV.git /tmp/DistroAV && \
    cd /tmp/DistroAV && mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr .. && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/DistroAV

# 6) Add noVNC and websockify
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    ln -sf /opt/novnc/vnc_lite.html /opt/novnc/index.html && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# ---------------------------------------------
# Stage 3: Runtime - Slim OBS runtime image
# ---------------------------------------------
FROM debian:bookworm AS runtime

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