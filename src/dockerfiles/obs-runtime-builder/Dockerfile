# ---------------------------------------------
# Stage 1: Base - Shared build environment
# ---------------------------------------------
FROM ubuntu:24.04 AS base

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
     build-essential make gnupg lsb-release unzip wget \
     python3 python3-pip yasm nasm libgl1 libasound2-dev \
     libv4l-0 libx11-xcb1 libv4l-dev libdrm-dev v4l-utils \
     openbox fluxbox libx264-dev libx265-dev libvpx-dev \
     libaom-dev libxext-dev libxfixes-dev zlib1g-dev \
     openssl libssl-dev \
     gstreamer1.0-plugins-base gstreamer1.0-tools \
     qt6-base-dev qt6-base-dev-tools qt6-tools-dev qt6-tools-dev-tools \
     qt6-multimedia-dev qt6-wayland-dev \
     libqt6svg6-dev libqt6opengl6-dev \
     ca-certificates curl git cmake \
 && update-ca-certificates \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------
# Stage 2: Builder – compile everything
# ---------------------------------------------
FROM base AS builder
ENV DEBIAN_FRONTEND=noninteractive

# install all the -devs FFmpeg needs
ENV DEV_DEPS="\
      dpkg-dev pkg-config libtool autoconf automake gettext texinfo \
      libx264-dev libx265-dev libmp3lame-dev libopus-dev \
      libvorbis-dev libvpx-dev libass-dev \
      libfreetype6-dev libfontconfig1-dev \
      libssl-dev libfribidi-dev libharfbuzz-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      libjansson-dev libpulse-dev libxkbcommon-dev \
      libxcb1-dev libxcb-xinput-dev libxcb-shm0-dev libxcb-xinerama0-dev \
      libxcb-randr0-dev libxcomposite-dev libxcursor-dev"

RUN apt-get update && apt-get install -y --no-install-recommends $DEV_DEPS \
  && rm -rf /var/lib/apt/lists/*

# 0. Build and install LAME (libmp3lame) from source for pkg-config support
RUN git clone https://github.com/rbrito/lame.git /tmp/lame && \
    cd /tmp/lame && \
    ./configure --prefix=/usr --enable-shared --disable-static && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/lame
 
# 1. Build and install FreeType
RUN git clone --depth=1 https://gitlab.freedesktop.org/freetype/freetype.git /tmp/freetype && \
    cd /tmp/freetype && \
    ./autogen.sh && ./configure --prefix=/usr && make -j$(nproc) && \
    make install && ldconfig && rm -rf /tmp/freetype

# 2. Build and install libass
RUN git clone https://github.com/libass/libass.git /tmp/libass && \
    cd /tmp/libass && \
    ./autogen.sh && \
    ./configure --prefix=/usr --disable-require-system-font-provider && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/libass

# 1) Build FFmpeg 6.1 (native ARM64 build)
RUN apt-get update && apt-get install -y --no-install-recommends libass-dev && \
    git config --global http.sslVerify false && \
    git clone --depth=1 -b release/6.1 https://github.com/FFmpeg/FFmpeg.git /ffmpeg && \
    cd /ffmpeg && \
    ARCH_DIR=$(find /usr/lib -type d -name "*pkgconfig" | grep -E 'linux-gnu/pkgconfig' | head -n1) && \
    echo "Resolved ARCH_DIR=$ARCH_DIR" && \
    export PKG_CONFIG_PATH="${ARCH_DIR}:/usr/share/pkgconfig" && \
    export PKG_CONFIG_LIBDIR="${ARCH_DIR}:/usr/share/pkgconfig" && \
    export CPPFLAGS="-I/usr/include" && \
    export LDFLAGS="-L/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)" && \
    echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH" && \
    echo "PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR" && \
    echo "Searching for libass.pc in $ARCH_DIR..." && \
    find $ARCH_DIR -name "libass*.pc" && \
    pkg-config --exists libass && echo "libass FOUND, continuing..." && \
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

# Patch headers with version string
RUN grep -Rl "FFMPEG_VERSION" /usr/local/include \
    | xargs -I{} sed -i 's/^#define\s*FFMPEG_VERSION.*$/#define FFMPEG_VERSION "6.1"/' {}
    
# Manually install uthash to a known include path
RUN mkdir -p /usr/local/include/uthash && \
    curl -L -o /usr/local/include/uthash/uthash.h https://raw.githubusercontent.com/troydhanson/uthash/master/src/uthash.h
RUN ln -s /usr/local/include/uthash/uthash.h /usr/include/uthash.h
ENV CMAKE_INCLUDE_PATH="/usr/include:/usr/local/include"

# 3) Build and install the ajantv2 core lib using CMake install
RUN rm -rf /tmp/libajantv2 && \
  git clone --branch release https://github.com/aja-video/libajantv2.git /tmp/libajantv2 && \
  mkdir -p /tmp/libajantv2/build && cd /tmp/libajantv2/build && \
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DAJANTV2_BUILD_DEMOS=OFF \
    -DAJANTV2_BUILD_TESTS=OFF && \
  cmake --build . --target ajantv2 -j$(nproc) && \
  cmake --install . || true && \
  ldconfig && \
  rm -rf /tmp/libajantv2

# Make sure it's available for OBS Studio later
ENV CMAKE_PREFIX_PATH="/usr:/usr/local:/usr/lib/aarch64-linux-gnu/cmake"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libxcb1-dev \
    libxcb-composite0-dev \
    libxcb-xinerama0-dev \
    libxcb-xfixes0-dev \
    libxcb-shm0-dev \
    libxcb-randr0-dev \
    libxcb-image0-dev \
    libpci-dev \
    libspeexdsp-dev \
    libmbedtls-dev \
    libcurl4-openssl-dev \
    nlohmann-json3-dev \
    libqrcodegencpp-dev \
    libva-dev && \
    rm -rf /var/lib/apt/lists/*
    
RUN git clone --recursive https://github.com/paullouisageneau/libdatachannel.git /tmp/libdatachannel && \
    cd /tmp/libdatachannel && mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install && \
    ldconfig && rm -rf /tmp/libdatachannel

# Build and install crc32c from source
RUN git clone --recursive https://github.com/google/crc32c.git /tmp/crc32c && \
    cd /tmp/crc32c && \
    mkdir -p build && cd build && \
    cmake -DCRC32C_BUILD_TESTS=OFF -DCRC32C_BUILD_BENCHMARKS=OFF -DCMAKE_INSTALL_PREFIX=/usr .. && \
    make -j$(nproc) && make install && \
    ldconfig && \
    rm -rf /tmp/crc32c
    
# Install WebSocket++ from source
RUN git clone --depth=1 https://github.com/zaphoyd/websocketpp.git /tmp/websocketpp && \
    mkdir -p /usr/local/include/websocketpp && \
    cp -r /tmp/websocketpp/websocketpp /usr/local/include/ && \
    rm -rf /tmp/websocketpp
    
# Install standalone Asio (header-only)
RUN git clone --depth=1 https://github.com/chriskohlhoff/asio.git /tmp/asio && \
    cp -r /tmp/asio/asio/include/* /usr/local/include/ && \
    rm -rf /tmp/asio

# 4) Build OBS Studio
RUN git clone --recursive https://github.com/obsproject/obs-studio.git /tmp/obs && \
    cd /tmp/obs && mkdir build && cd build && \
    ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH) && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_PREFIX_PATH="/usr:/usr/local:/usr/lib/${ARCH}/cmake:/usr/lib/${ARCH}/cmake/Qt6" \
      -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
      -DBUILD_BROWSER=OFF \
      -DBUILD_LIBOBS=ON \
      -DENABLE_PIPEWIRE=OFF \
      -DENABLE_NEW_MPEGTS_OUTPUT=OFF \
      -DENABLE_SPEEXDSP=OFF \
      -DUSE_PKG_CONFIG=ON \
      -DENABLE_MBEDTLS=OFF \
      -DENABLE_RNNOISE=OFF \
      -DENABLE_DATACHANNEL=OFF \
      -DENABLE_WEBSOCKET_API=OFF \
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