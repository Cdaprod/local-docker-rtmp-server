# cdaprod/video-indexer:dev
FROM alpine:latest

RUN apk add --no-cache bash inotify-tools coreutils jq

WORKDIR /app
COPY index_videos.sh /app/index_videos.sh

ENTRYPOINT ["sh", "/app/index_videos.sh"]