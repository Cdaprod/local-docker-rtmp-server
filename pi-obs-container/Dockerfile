FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# System deps
RUN apt-get update && apt-get install -y \
    ffmpeg \
    v4l-utils \
    libv4l-dev \
    qtbase5-dev \
    libxcb-xinerama0 \
    libxcomposite-dev \
    libx11-dev \
    libgl1-mesa-glx \
    libwayland-dev \
    libpulse-dev \
    curl \
    git \
    cmake \
    build-essential \
    ca-certificates \
    obs-studio \
    && apt-get clean

# Copy device detection script
COPY detect-devices.sh /usr/local/bin/detect-devices.sh
RUN chmod +x /usr/local/bin/detect-devices.sh

# Copy entrypoint for auto scene/source setup
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose OBS WebSocket port if enabled
EXPOSE 4455

# Runtime
ENTRYPOINT ["/entrypoint.sh"]