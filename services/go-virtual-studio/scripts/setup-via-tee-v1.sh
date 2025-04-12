# Create the README
sudo tee virtual-studio/README.md > /dev/null <<'EOF'
# Virtual Studio

Minimal HDMI H.264 encoder and WebSocket preview app using Golang + FFmpeg + browser UI.

- Captures HDMI via USB dongle
- Pipes raw frames to FFmpeg for H.264 encoding
- Broadcasts preview frames to WebSocket-connected browser
- Frontend shows live preview using JS
EOF

# main.go: Entry point
sudo tee virtual-studio/main.go > /dev/null <<'EOF'
package main

import (
	"log"
	"os"
	"os/signal"
	"virtual-studio/pkg/capture"
	"virtual-studio/pkg/encoder"
	"virtual-studio/pkg/server"
)

func main() {
	rawFrames := make(chan []byte, 5)
	h264Frames := make(chan []byte, 5)

	go capture.StartCapture("/dev/video0", rawFrames)
	go encoder.EncodeYUVToH264(rawFrames, h264Frames)
	go server.StartWebServer(h264Frames)

	log.Println("Virtual Studio running... Press Ctrl+C to stop")
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt)
	<-sig
	log.Println("Shutting down...")
}
EOF

# capture.go
sudo mkdir -p virtual-studio/pkg/capture
sudo tee virtual-studio/pkg/capture/capture.go > /dev/null <<'EOF'
package capture

import (
	"log"
	"os"
	"os/exec"
)

func StartCapture(device string, out chan<- []byte) error {
	cmd := exec.Command("ffmpeg",
		"-f", "v4l2", "-i", device,
		"-pix_fmt", "yuv420p",
		"-s", "1280x720",
		"-f", "rawvideo", "-")

	stdout, _ := cmd.StdoutPipe()
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return err
	}

	go func() {
		buf := make([]byte, 1280*720*3/2)
		for {
			_, err := stdout.Read(buf)
			if err != nil {
				log.Println("Capture error:", err)
				break
			}
			out <- append([]byte{}, buf...)
		}
	}()
	return nil
}
EOF

# encoder.go
sudo mkdir -p virtual-studio/pkg/encoder
sudo tee virtual-studio/pkg/encoder/encoder.go > /dev/null <<'EOF'
package encoder

import (
	"log"
	"os"
	"os/exec"
)

func EncodeYUVToH264(in <-chan []byte, out chan<- []byte) {
	cmd := exec.Command("ffmpeg",
		"-f", "rawvideo", "-pix_fmt", "yuv420p", "-s", "1280x720", "-i", "-",
		"-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency",
		"-f", "mpegts", "-")

	stdin, _ := cmd.StdinPipe()
	stdout, _ := cmd.StdoutPipe()
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		log.Fatal("FFmpeg encoder start failed:", err)
	}

	go func() {
		for frame := range in {
			stdin.Write(frame)
		}
	}()

	go func() {
		buf := make([]byte, 4096)
		for {
			n, err := stdout.Read(buf)
			if err != nil {
				log.Println("Encode error:", err)
				break
			}
			out <- append([]byte{}, buf[:n]...)
		}
	}()
}
EOF

# server.go (WebSocket + static file server)
sudo mkdir -p virtual-studio/pkg/server
sudo tee virtual-studio/pkg/server/server.go > /dev/null <<'EOF'
package server

import (
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{}
var clients = make(map[*websocket.Conn]bool)
var mutex = sync.Mutex{}

func StartWebServer(frameChan <-chan []byte) {
	http.Handle("/", http.FileServer(http.Dir("virtual-studio/webui")))
	http.HandleFunc("/ws", handleWS)

	go func() {
		for frame := range frameChan {
			broadcast(frame)
		}
	}()

	log.Println("Web UI at http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	mutex.Lock()
	clients[conn] = true
	mutex.Unlock()
}

func broadcast(frame []byte) {
	mutex.Lock()
	defer mutex.Unlock()
	for c := range clients {
		err := c.WriteMessage(websocket.BinaryMessage, frame)
		if err != nil {
			c.Close()
			delete(clients, c)
		}
	}
}
EOF

# webui/index.html
sudo mkdir -p virtual-studio/webui
sudo tee virtual-studio/webui/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Virtual Studio Preview</title>
</head>
<body>
  <h2>HDMI Feed</h2>
  <video id="preview" autoplay muted playsinline></video>
  <script src="main.js"></script>
</body>
</html>
EOF

# webui/main.js
sudo tee virtual-studio/webui/main.js > /dev/null <<'EOF'
const ws = new WebSocket("ws://" + location.host + "/ws");
ws.binaryType = "arraybuffer";

const video = document.getElementById("preview");
const mediaSource = new MediaSource();
video.src = URL.createObjectURL(mediaSource);

let sourceBuffer;

mediaSource.addEventListener("sourceopen", () => {
  sourceBuffer = mediaSource.addSourceBuffer('video/mp2t; codecs="avc1.64001e"');
});

ws.onmessage = (e) => {
  if (sourceBuffer && !sourceBuffer.updating) {
    sourceBuffer.appendBuffer(new Uint8Array(e.data));
  }
};
EOF