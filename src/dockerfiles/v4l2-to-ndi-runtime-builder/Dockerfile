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