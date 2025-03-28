FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Dependencies and OBS Studio
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
    vlc \
    golang-go \
    obs-studio \
    && apt-get clean

# Install OBS NDI Plugin and Runtime
RUN curl -LO https://github.com/Palakis/obs-ndi/releases/download/4.9.1/obs-ndi-4.9.1-Ubuntu20.04.deb && \
    dpkg -i obs-ndi-4.9.1-Ubuntu20.04.deb && rm obs-ndi-4.9.1-Ubuntu20.04.deb && \
    curl -LO https://github.com/obsproject/obs-studio/releases/download/27.2.4/NDI-runtime-4.5.1-Linux-x86_64.deb && \
    dpkg -i NDI-runtime-4.5.1-Linux-x86_64.deb && rm NDI-runtime-4.5.1-Linux-x86_64.deb

# Install obs-cli
RUN git clone https://github.com/muesli/obs-cli.git && \
    cd obs-cli && \
    go build && \
    mv obs-cli /usr/local/bin/obs-cli && \
    cd .. && rm -rf obs-cli

# Copy necessary scripts
COPY detect-devices.sh /usr/local/bin/detect-devices.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/detect-devices.sh /entrypoint.sh

# Expose OBS WebSocket port
EXPOSE 4455

ENTRYPOINT ["/entrypoint.sh"]