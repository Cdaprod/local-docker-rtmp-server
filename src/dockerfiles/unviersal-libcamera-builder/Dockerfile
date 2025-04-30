FROM debian:bookworm

# Core tools and build dependencies
RUN apt-get update && apt-get install -y \
  git cmake ninja-build pkg-config libjpeg-dev libtiff5-dev \
  libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libswscale-dev \
  libdrm-dev libudev-dev libboost-dev libgnutls28-dev openssl \
  libexpat1-dev python3 python3-pip libtbb-dev \
  libyaml-cpp-dev python3-yaml \
  libpng-dev libtiff-dev libevent-dev libwebp-dev \
  g++ libegl1-mesa-dev libgles2-mesa-dev \
  qtbase5-dev qtdeclarative5-dev libqt5svg5-dev qtmultimedia5-dev \
  && apt-get clean

# Clone libcamera and build
RUN git clone https://git.libcamera.org/libcamera/libcamera.git && \
    cd libcamera && \
    meson setup build && \
    ninja -C build && \
    ninja -C build install

# Set up libcamera apps (optional: only works on Pi)
# Add this part only if you're building on a Raspberry Pi
# RUN git clone https://github.com/raspberrypi/libcamera-apps.git && \
#     cd libcamera-apps && \
#     mkdir build && cd build && \
#     cmake .. && \
#     make -j$(nproc) && \
#     make install

CMD ["/bin/bash"]