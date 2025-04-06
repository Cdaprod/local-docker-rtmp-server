# videos-relayed service replaced need for RTSP

## This service layer is the final layer between Docker Host and /dev/video* ingestion.

This configuration uses an ARM‑compatible Alpine image, installs ffmpeg from Alpine’s repos (which should include PipeWire support on your Pi OS host), and captures the Wayland desktop when CAPTURE_MODE=desktop is set. If you later decide to capture a USB camera instead, you can simply change CAPTURE_MODE to another value (or omit it) and adjust VIDEO_DEVICE.

```text
repo-root/
├── videos-relayed/
│   ├── docker-compose.videos-relayed.yaml
│   ├── Dockerfile
│   ├── supervisord.conf
│   └── entrypoint.sh
└── .env.example
``` 

The service is written for Raspberry Pi OS and is designed to always capture the Wayland desktop (via a PipeWire input) as the initial video source. This assumes your host’s PipeWire is set up so that ffmpeg can grab the desktop using the "default" source. (If needed, you can later tweak the input source via an environment variable.)

- videos-relayed/Dockerfile

Use the ARM‑optimized Alpine base image for Raspberry Pi OS. We install ffmpeg from Alpine’s repositories, which (in this configuration) should include PipeWire support.

- videos-relayed/supervisord.conf

Supervisor will manage our relay process.

- videos-relayed/entrypoint.sh

This script checks the CAPTURE_MODE environment variable. In "desktop" mode it captures the Wayland desktop via PipeWire (using the "default" source), otherwise it falls back to capturing a video device.