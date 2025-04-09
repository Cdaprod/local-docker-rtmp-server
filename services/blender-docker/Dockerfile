FROM blender:3.6.4

LABEL maintainer="David Cannan <Cdaprod@Cdaprod.dev>"
ENV DEBIAN_FRONTEND=noninteractive

# Base system and X11
RUN apt update && apt install -y \
  wget curl git supervisor \
  xfce4 xfce4-goodies xterm \
  novnc websockify tigervnc-standalone-server \
  python3-pip x11vnc xvfb fastapi uvicorn \
  blender \
  && apt clean

# Setup VNC password
RUN mkdir -p ~/.vnc && \
  x11vnc -storepasswd 1234 ~/.vnc/passwd

# Setup noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -sf /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Copy App Code and Blender Script
COPY app/ /app/
COPY blender_script.py /app/blender_script.py

# Add scripts/assets
RUN mkdir -p /root/assets /root/scripts
COPY assets/ /root/assets/
COPY scripts/ /root/scripts/
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Entrypoint setup
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /app
EXPOSE 5800 5900 8000
ENTRYPOINT ["/entrypoint.sh"]