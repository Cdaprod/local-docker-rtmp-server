package discovery

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/grandcat/zeroconf"
)

// Advertise publishes this service instance (_service._udp.local) on the LAN.
func Advertise(instance, service string, port int) {
	server, err := zeroconf.Register(instance, service, "local.", port, nil, nil)
	if err != nil {
		log.Fatalf("mDNS register failed: %v", err)
	}
	// keep it alive until program exit
	go func() {
		<-context.Background().Done()
		server.Shutdown()
	}()
}

// Find looks for the first instance of `service` via mDNS within timeout.
func Find(service string, timeout time.Duration) (string, error) {
	resolver, err := zeroconf.NewResolver(nil)
	if err != nil {
		return "", fmt.Errorf("mDNS resolver init: %w", err)
	}
	entries := make(chan *zeroconf.ServiceEntry)
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	go func() {
		if err := resolver.Browse(ctx, service, "local.", entries); err != nil {
			log.Printf("mDNS browse error: %v", err)
		}
	}()

	for entry := range entries {
		if len(entry.AddrIPv4) > 0 {
			return fmt.Sprintf("%s:%d", entry.AddrIPv4[0], entry.Port), nil
		}
	}
	return "", fmt.Errorf("service %s not found", service)
}