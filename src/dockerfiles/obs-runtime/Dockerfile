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
      libxcb-randr0-dev libxcomposite-dev libxcursor-dev \
      libobs-dev"

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
    libva-dev \
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
    libvlc-dev \
    swig \
    python3-dev \
    vlc && \
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

# Install WebSocket++ and stub a config-mode CMake file
RUN git clone --depth=1 https://github.com/zaphoyd/websocketpp.git /tmp/websocketpp && \
    mkdir -p /usr/local/include/websocketpp /usr/local/lib/cmake/websocketpp && \
    cp -r /tmp/websocketpp/websocketpp /usr/local/include/ && \
    echo 'set(websocketpp_FOUND TRUE)' > /usr/local/lib/cmake/websocketpp/websocketppConfig.cmake && \
    echo 'set(websocketpp_INCLUDE_DIR /usr/local/include/websocketpp)' >> /usr/local/lib/cmake/websocketpp/websocketppConfig.cmake && \
    rm -rf /tmp/websocketpp
     
# Install standalone Asio (header-only)
RUN git clone --depth=1 https://github.com/chriskohlhoff/asio.git /tmp/asio && \
    cp -r /tmp/asio/asio/include/* /usr/local/include/ && \
    rm -rf /tmp/asio
    
# --- Build LuaJIT from upstream ---
RUN git clone https://github.com/LuaJIT/LuaJIT.git /tmp/LuaJIT && \
    cd /tmp/LuaJIT && \
    make && make install && \
    rm -rf /tmp/LuaJIT

ENV LD_LIBRARY_PATH="/usr/lib:/usr/local/lib:${LD_LIBRARY_PATH}"
ENV LUAJIT_INCLUDE_DIR=/usr/local/include/luajit-2.1
ENV LUAJIT_LIBRARY=/usr/local/lib/libluajit-5.1.a

# Enable Universe repo (Ubuntu-only step)
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository universe && \
    apt-get update

# Install OBS + dev headers (libobs-dev) + runtime deps you’re already using
RUN apt-get install -y --no-install-recommends \
    obs-studio \
    obs-plugins \
    libobs-dev \
    libx264-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev \
    libxcb-composite0-dev libxcb-randr0-dev libxcb-image0-dev \
    libxcb-xinerama0-dev libxcomposite-dev && \
    rm -rf /var/lib/apt/lists/*
    
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
    
# Install standalone Asio (header-only)
RUN git clone --depth=1 https://github.com/chriskohlhoff/asio.git /tmp/asio && \
    mkdir -p /usr/local/include/asio && \
    cp -r /tmp/asio/asio/include/asio /usr/local/include/asio && \
    rm -rf /tmp/asio

# --- Install qrcodegencpp headers and fake CMake module ---
RUN mkdir -p /usr/local/share/cmake/Modules \
 && git clone https://github.com/nayuki/QR-Code-generator.git /tmp/qrcodegen \
 && mkdir -p /usr/local/include/qrcodegencpp \
 && cp /tmp/qrcodegen/cpp/*.hpp /usr/local/include/qrcodegencpp \
 && echo 'set(qrcodegencpp_FOUND TRUE)'                                        \
      > /usr/local/share/cmake/Modules/Findqrcodegencpp.cmake \
 && echo 'set(qrcodegencpp_INCLUDE_DIR /usr/local/include/qrcodegencpp)'        \
      >> /usr/local/share/cmake/Modules/Findqrcodegencpp.cmake \
 && rm -rf /tmp/qrcodegen
    
# --------------------------------------------
# Stage N: Builder for obs-gstreamer plugin
# --------------------------------------------
FROM builder AS builder-gstreamer

RUN apt-get update && apt-get install -y --no-install-recommends \
    v4l2loopback-dkms \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --recursive https://github.com/fzwoch/obs-gstreamer.git /tmp/obs-gstreamer && \
    cd /tmp/obs-gstreamer && \
    cmake -S . -B build \
      -DBUILD_OUT_OF_TREE=On \
      -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build build -j$(nproc) && \
    cmake --install build && \
    rm -rf /tmp/obs-gstreamer

# --------------------------------------------
# Stage N+1: Builder for obs‑v4l2sink plugin
# --------------------------------------------
FROM builder AS builder-v4l2sink

# bring in the OBS headers so find_package(Libobs) works
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libobs-dev \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --recursive https://github.com/CatxFish/obs-v4l2sink.git /tmp/obs-v4l2sink \
 && cd /tmp/obs-v4l2sink \
 && cmake -S . -B build \
      -DBUILD_OUT_OF_TREE=On \
      -DCMAKE_INSTALL_PREFIX=/usr \
 && cmake --build build -j$(nproc) \
 && cmake --install build \
 && rm -rf /tmp/obs-v4l2sink

# --------------------------------------------
# Stage N: Builder for obs-3d-effect plugin
# --------------------------------------------
FROM builder AS builder-3d-effect

# --- Build obs-3d-effect plugin ---
RUN git clone https://github.com/exeldro/obs-3d-effect.git /tmp/obs-3d-effect && \
    cd /tmp/obs-3d-effect && \
    cmake -S . -B build -DBUILD_OUT_OF_TREE=On -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build build && cmake --install build && \
    rm -rf /tmp/obs-3d-effect

# --------------------------------------------
# Stage N: Builder for obs-websocket plugin
# --------------------------------------------
FROM builder AS builder-websocket

ENV CMAKE_PREFIX_PATH="/usr/local/lib/cmake/websocketpp:/usr:/usr/local"
ENV CMAKE_MODULE_PATH="/usr/local/share/cmake/Modules"

# Clone & patch obs-websocket
RUN git clone --recursive https://github.com/obsproject/obs-websocket.git /tmp/obs-websocket \
 && cd /tmp/obs-websocket \
 && bash -c "echo -e 'cmake_minimum_required(VERSION 3.10)\n\
project(obs_websocket)\n\
macro(target_export _)\nendmacro()\n' > CMakeLists.txt.patched" \
 && cat CMakeLists.txt >> CMakeLists.txt.patched \
 && mv CMakeLists.txt.patched CMakeLists.txt \
 && cmake -S . -B build \
      -DBUILD_OUT_OF_TREE=On \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH} \
      -DCMAKE_MODULE_PATH=${CMAKE_MODULE_PATH} \
 && cmake -LAH build | grep -i qrcode \
 && cmake --build build -j$(nproc) \
 && cmake --install build \
 && rm -rf /tmp/obs-websocket
 
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
LABEL obs.modules="ffmpeg,libobs,luajit,datachannel,crc32c,websocketpp,asio,distroav" \
      base.image="cdaprod/obs-runtime:latest"
      
ENV PATH="/usr/local/bin:$PATH"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libasound2 libv4l-0 libx11-xcb1 \
    x11vnc xvfb novnc websockify supervisor \
    python3 python3-pip openbox fluxbox && \
    rm -rf /var/lib/apt/lists/*

# Copy plugin builder artifacts
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