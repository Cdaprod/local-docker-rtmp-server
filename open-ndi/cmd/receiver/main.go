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
	mdnsService    = "_openndi._udp"
	controlPort    = "9000"
	discoveryTimeout = 5 * time.Second
)

func main() {
	// 1) Find sender via mDNS
	senderAddr, err := discovery.Find(mdnsService, discoveryTimeout)
	if err != nil {
		log.Fatalf("mDNS lookup failed: %v", err)
	}
	log.Printf("Found sender at %s\n", senderAddr)

	// 2) Connect & negotiate via TCP
	cfg := control.Connect(senderAddr + ":" + controlPort)
	log.Printf("Negotiated local UDP listen at %s\n", cfg.ReceiverAddr)

	// 3) Start listening for UDP packets
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := streaming.StartReceiver(ctx, cfg); err != nil {
		log.Fatalf("receiving failed: %v", err)
	}
}