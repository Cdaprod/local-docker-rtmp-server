# src/dockerfiles/obs-runtime-builder/Dockerfile

FROM debian:bullseye

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

# Install core OBS Studio + plugins + runtime deps
RUN apt-get update && apt-get install -y \
    obs-studio ffmpeg curl \
    libgl1 libasound2 libv4l-0 libx11-xcb1 \
    x11vnc xvfb novnc websockify \
    openbox fluxbox \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create runtime dirs but don’t copy your personal configs yet
RUN mkdir -p \
    /root/.config/obs-studio \
    /opt/obs/plugins \
    /root/assets \
    /root/scripts

# Set default working directory
WORKDIR /root

EXPOSE 5800 5900 4455

ENTRYPOINT ["xvfb-run", "--auto-servernum", "/usr/bin/obs"]
CMD ["x11vnc", "-display", ":99", "-forever", "-nopw", "-shared"]