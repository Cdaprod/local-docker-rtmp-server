package main

import (
	"context"
	"flag"
	"log"
	"time"

	"github.com/Cdaprod/open-ndi/internal/control"
	"github.com/Cdaprod/open-ndi/internal/discovery"
	"github.com/Cdaprod/open-ndi/internal/streaming"
	"github.com/Cdaprod/open-ndi/internal/video"
)

const (
	mdnsService      = "_openndi._udp"
	controlPort      = "9000"
	discoveryTimeout = 5 * time.Second
)

func main() {
	preview := flag.Bool("preview", false, "Enable local video preview window")
	flag.Parse()

	senderAddr, err := discovery.Find(mdnsService, discoveryTimeout)
	if err != nil {
		log.Fatalf("mDNS lookup failed: %v", err)
	}
	log.Printf("Found sender at %s", senderAddr)

	cfg := control.Connect(senderAddr + ":" + controlPort)
	log.Printf("Negotiated UDP listen at %s", cfg.ReceiverAddr)

	if *preview {
		// decode via gocv directly from UDP stream
		err = video.PreviewStream("udp://" + cfg.ReceiverAddr)
		if err != nil {
			log.Fatalf("preview failed: %v", err)
		}
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := streaming.StartReceiver(ctx, cfg); err != nil {
		log.Fatalf("receiving failed: %v", err)
	}
}