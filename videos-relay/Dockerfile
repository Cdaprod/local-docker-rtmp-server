FROM arm64v8/alpine:3.19

# Install required packages: curl, supervisor, and ffmpeg.
RUN apk add --no-cache curl supervisor ffmpeg

COPY supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]