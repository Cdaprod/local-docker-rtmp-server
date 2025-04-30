# RTMP-Server for Cdaprod/Local-Docker-RTMP-Server

#### Docker run command

``` 
docker run -d --restart unless-stopped \
  -p 1935:1935 -p 8080:8080 \
  -e FFMPEG_ENCODER="h264_v4l2m2m" \
  -e FFMPEG_HWACCEL="v4l2m2m" \
  -e FFMPEG_BITRATE="3500k" \
  -e FFMPEG_AUDIO_BITRATE="128k" \
  -e FFMPEG_THREADS="4" \
  -e NAS_USERNAME=admin \
  -e NAS_PASSWORD=secret \
  -e NAS_IP_OR_HOSTNAME=192.168.0.19 \
  -e NAS_SHARE_NAME=volume1/videos \
  cdaprod/rtmp-server:latest
``` 

## RTMP Integration Webhooks

The following endpoints are triggered by the RTMP server (`nginx.conf.template`):
- `/on_publish?app=...&name=...&addr=...&clientid=...`
- `/on_publish_done?app=...&name=...&addr=...&clientid=...`

Both events are enriched and forwarded to RabbitMQ (`stream_events` queue).