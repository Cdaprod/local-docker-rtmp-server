FROM debian:bullseye

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

# Install OBS and GUI tooling
RUN apt-get update && apt-get install -y \
    obs-studio ffmpeg curl \
    libgl1 libasound2 libv4l-0 libx11-xcb1 \
    x11vnc xvfb novnc websockify supervisor \
    openbox fluxbox \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup directory structure
RUN mkdir -p \
    /root/.config/obs-studio \
    /opt/obs/plugins \
    /root/assets \
    /root/scripts \
    /var/log/supervisor

# Copy supervisord config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4455

CMD ["/usr/bin/supervisord"]