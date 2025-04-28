FROM cdaprod/webrtc-runtime:latest

WORKDIR /app

COPY app/package.json .
RUN npm install

COPY app/ .
COPY config/turnserver.conf /etc/coturn/turnserver.conf
COPY scripts/startup.sh /startup.sh

RUN chmod +x /startup.sh

EXPOSE 8080
EXPOSE 3478
EXPOSE 3478/udp
EXPOSE 49152-65535/udp

ENTRYPOINT ["/bin/sh", "/scripts/startup.sh"]