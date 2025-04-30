FROM cdaprod/webrtc-runtime:latest

WORKDIR /app

# No need to COPY package.json or run npm install again!

# Optional: if you want to override app files (otherwise comment out)
# COPY app/ .

COPY config/turnserver.conf /etc/coturn/turnserver.conf
COPY scripts/startup.sh /startup.sh

RUN chmod +x /startup.sh

EXPOSE 8080
EXPOSE 3478
EXPOSE 3478/udp
EXPOSE 49152-65535/udp

ENTRYPOINT ["/bin/sh", "/startup.sh"]