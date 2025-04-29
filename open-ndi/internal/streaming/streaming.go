package streaming

import (
	"context"
	"log"
	"net"
	"os"
	"os/exec"
	"runtime"

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

// StartVideoStream captures from a V4L2 device, encodes to H.264 via FFmpeg,
// and sends an MPEG-TS stream over UDP to receiverAddr until ctx is done.
// internal/streaming/streaming.go

func StartVideoStream(ctx context.Context, receiverAddr, device string) error {
    // 1) Choose encoder based on architecture
    encoder := "libx264"
    if runtime.GOARCH == "arm" {
        encoder = "h264_v4l2m2m"
    }
    
    args := []string{
        // Input from your camera
        "-f", "v4l2",
        "-framerate", "30",           // optional: force 30 fps
        "-video_size", "1280x720",    // optional: force 720p
        "-i", device,

        // Encoder settings
        "-c:v", encoder,            // CPU encode; or "h264_v4l2m2m" on Pi
        "-preset", "ultrafast",       // fastest encode
        "-tune", "zerolatency",       // minimize encoder buffer

        // Output format & destination
        "-f", "mpegts",
        "udp://" + receiverAddr,
    }

    cmd := exec.CommandContext(ctx, "ffmpeg", args...)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    return cmd.Run()
}