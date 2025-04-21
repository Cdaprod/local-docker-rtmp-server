The code I’ve created is specifically focused on capturing from a camera using v4l2, encoding the video, and streaming it to NDI. It no longer includes the WebRTC component from the original file.

This new implementation:
	1.	Uses direct v4l2 system calls through Go’s syscall interface for capturing video frames
	2.	Provides a proper memory-mapped buffer implementation for efficient frame capture
	3.	Uses FFmpeg (via exec.Command) to handle the NDI output streaming
	
The NDI output is achieved by piping the captured frames to FFmpeg with the libndi_newtek output format. This approach gives you ultra-low latency by:
	1.	Using direct memory mapping for frame capture
	2.	Minimizing buffer copies
	3.	Using the "ultrafast" preset and "zerolatency" tuning options for the encoder
	4.	Eliminating B-frames to reduce encoding latency

This implementation completely replaces the previous WebRTC code, as you mentioned you only needed:
	•	Camera capture
	•	Encoding
	•	NDI streaming
	
Perfect -- this makes it an ideal candidate to isolate into a dedicated microservice container that’s:
	•	Built independently
	•	Volume-mounted or composed alongside your obs-runtime-builder
	•	Optional to use as a base image layer if needed by OBS/NDI pipelines

⸻

Recommended Setup

1. Directory Layout

/project-root/
├── obs-runtime-builder/
│   └── Dockerfile
├── go-v4l2-ndi/
│   ├── v4l2-ndi.go
│   └── README.md



⸻

2. Dockerfile for go-v4l2-ndi

go-v4l2-ndi/Dockerfile:

FROM golang:1.21-bookworm AS builder

WORKDIR /app

# Copy only the Go file
COPY v4l2-ndi.go .

# Compile the Go file into a static binary
RUN go build -o v4l2-ndi .

# Runtime container with FFmpeg and v4l2 support
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg v4l-utils libv4l-0 libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled binary
COPY --from=builder /app/v4l2-ndi /usr/local/bin/v4l2-ndi

ENTRYPOINT ["v4l2-ndi"]



⸻

3. Build & Run

docker build -t cdaprod/go-v4l2-ndi ./go-v4l2-ndi

docker run --rm -it \
  --device /dev/video0 \
  --network host \
  cdaprod/go-v4l2-ndi \
  --device /dev/video0 --width 1920 --height 1080 --fps 30 --ndi-name "PiCam"



⸻

4. Volume Mount for NDI SDK

If you’re piping to FFmpeg compiled with libndi_newtek, and you have the SDK locally, mount it like this:

-v /path/to/NDI/sdk:/usr/local/lib/ndi \
-e LD_LIBRARY_PATH=/usr/local/lib/ndi

If it’s a binary plugin for FFmpeg like libndi_newtek.so, make sure it’s on the LD_LIBRARY_PATH and that FFmpeg knows to output to -f libndi_newtek.

⸻

5. Integrate into Docker Compose

You could drop this into your OBS stack by creating a docker-compose.override.yml like:

services:
  v4l2-ndi:
    build: ./go-v4l2-ndi
    devices:
      - /dev/video0
    network_mode: host
    environment:
      - NDI_NAME=PiCam
    command: [
      "--device", "/dev/video0",
      "--width", "1920",
      "--height", "1080",
      "--fps", "30",
      "--ndi-name", "PiCam"
    ]



⸻

TL;DR
	•	Treat your Go app as a dedicated Docker service
	•	Use --device=/dev/videoX for camera input
	•	Build FFmpeg with libndi_newtek, or install NDI SDK inside or mount as a volume
	•	Compose it with OBS stack as a streaming node
	•	You now have a portable NDI capture box

⸻

Want me to generate the full docker-compose.yml and Makefile to bundle both OBS + this NDI streamer as a full system?