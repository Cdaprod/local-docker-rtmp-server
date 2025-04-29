package main

import (
	"context"
	"log"
	"time"

	"github.com/youruser/open-ndi/internal/control"
	"github.com/youruser/open-ndi/internal/discovery"
	"github.com/youruser/open-ndi/internal/streaming"
)

const (
	mdnsService = "_openndi._udp"
	controlPort = 9000
)

func main() {
	// 1) Advertise via mDNS
	discovery.Advertise("openndi-sender", mdnsService, controlPort)
	log.Println("mDNS service advertised")

	// 2) Wait for receiver to connect and send its UDP listen address
	cfg := control.ListenAndServe(":9000")
	log.Printf("Negotiated receiver address: %s\n", cfg.ReceiverAddr)

	// 3) Start sending UDP packets until cancelled
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	if err := streaming.StartSender(ctx, cfg); err != nil {
		log.Fatalf("streaming failed: %v", err)
	}
}