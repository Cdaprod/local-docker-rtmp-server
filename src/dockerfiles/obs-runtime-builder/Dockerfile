FROM debian:bullseye

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    obs-studio ffmpeg curl \
    libgl1 libasound2 libv4l-0 libx11-xcb1 \
    x11vnc xvfb novnc websockify \
    openbox fluxbox \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    /root/.config/obs-studio \
    /opt/obs/plugins \
    /root/assets \
    /root/scripts

WORKDIR /root

COPY start-obs.sh /usr/local/bin/start-obs.sh
RUN chmod +x /usr/local/bin/start-obs.sh

EXPOSE 5800 5900 4455

ENTRYPOINT ["/usr/local/bin/start-obs.sh"]