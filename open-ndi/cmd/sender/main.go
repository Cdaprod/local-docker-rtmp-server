package main

import (
    "context"
    "log"
    "time"

    "github.com/Cdaprod/open-ndi/internal/control"
    "github.com/Cdaprod/open-ndi/internal/discovery"
    "github.com/Cdaprod/open-ndi/internal/streaming"
)

const (
    mdnsService = "_openndi._udp"
    controlPort = 9000
    videoDevice = "/dev/video0"
)

func main() {
    // 1) Advertise via mDNS
    discovery.Advertise("openndi-sender", mdnsService, controlPort)
    log.Println("mDNS service advertised")

    // 2) Handshake to get receiver UDP address
    cfg := control.ListenAndServe(":9000")
    log.Printf("Negotiated receiver address: %s\n", cfg.ReceiverAddr)

    // 3) Start the video stream (blocks until context done or ffmpeg exits)
    ctx, cancel := context.WithTimeout(context.Background(), 0) // 0 = run until killed
    defer cancel()

    if err := streaming.StartVideoStream(ctx, cfg.ReceiverAddr, "/dev/video0"); err != nil {
        log.Fatalf("video stream failed: %v", err)
    }

    log.Println("Video stream finished, exiting")
}