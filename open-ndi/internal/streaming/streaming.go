package streaming

import (
	"context"
	"log"
	"net"

	"github.com/Cdaprod/open-ndi/internal/control"
)

// StartSender streams dummy UDP packets to cfg.ReceiverAddr until ctx is done.
func StartSender(ctx context.Context, cfg control.Config) error {
	udpAddr, err := net.ResolveUDPAddr("udp", cfg.ReceiverAddr)
	if err != nil {
		return err
	}
	conn, err := net.DialUDP("udp", nil, udpAddr)
	if err != nil {
		return err
	}
	defer conn.Close()

	buf := make([]byte, 1024)
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			if _, err := conn.Write(buf); err != nil {
				log.Printf("UDP send error: %v", err)
				return err
			}
		}
	}
}

// StartReceiver listens for UDP packets on cfg.ReceiverAddr and logs each packet.
func StartReceiver(ctx context.Context, cfg control.Config) error {
	udpAddr, err := net.ResolveUDPAddr("udp", cfg.ReceiverAddr)
	if err != nil {
		return err
	}
	conn, err := net.ListenUDP("udp", udpAddr)
	if err != nil {
		return err
	}
	defer conn.Close()

	buf := make([]byte, 65535)
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			n, addr, err := conn.ReadFromUDP(buf)
			if err != nil {
				log.Printf("UDP receive error: %v", err)
				return err
			}
			log.Printf("Received %d bytes from %s", n, addr)
		}
	}
}