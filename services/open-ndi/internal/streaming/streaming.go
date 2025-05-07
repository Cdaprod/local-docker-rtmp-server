package streaming

import (
	"context"
	"log"
	"net"
	"os"
	"os/exec"
	"runtime"
	"time"

	"github.com/Cdaprod/open-ndi/internal/control"
	"github.com/Cdaprod/open-ndi/internal/rudp"
)

// StartSender streams video using reliable UDP
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

	seq := uint32(0)
	ticker := time.NewTicker(33 * time.Millisecond) // ~30fps
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			payload := make([]byte, 1024) // dummy payload
			pkt := rudp.Packet{
				Seq:   seq,
				Ack:   0,
				Flags: rudp.FlagData,
				Data:  payload,
			}
			buf, _ := rudp.Encode(pkt)
			if _, err := conn.Write(buf); err != nil {
				log.Printf("UDP send error: %v", err)
			}
			seq++
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
				continue
			}
			pkt, err := rudp.Decode(buf[:n])
			if err != nil {
				log.Printf("Decode error from %s: %v", addr, err)
				continue
			}
			log.Printf("Received packet %d (%d bytes) from %s", pkt.Seq, len(pkt.Data), addr)
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