#!/bin/bash

# Create advanced systemd service file for autostart
sudo tee virtual-studio/virtual-studio.service > /dev/null <<'EOF'
[Unit]
Description=Virtual Studio HDMI Capture and Streaming
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/virtual-studio
ExecStart=/opt/virtual-studio/bin/virtual-studio --config /opt/virtual-studio/config.json
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=virtual-studio

[Install]
WantedBy=multi-user.target
EOF

# Create advanced RTSP-SRT bridge module
sudo mkdir -p virtual-studio/pkg/bridge
sudo tee virtual-studio/pkg/bridge/bridge.go > /dev/null <<'EOF'
package bridge

import (
	"context"
	"fmt"
	"log"
	"os/exec"
	"strings"
	"sync"
	"virtual-studio/pkg/config"
)

// BridgeStats holds statistics about the RTSP-SRT bridge
type BridgeStats struct {
	ActiveConnections int
	TotalBytes        int64
	Uptime            int64
}

var (
	stats      BridgeStats
	statsMutex sync.RWMutex
)

// GetStats returns a copy of the current bridge statistics
func GetStats() BridgeStats {
	statsMutex.RLock()
	defer statsMutex.RUnlock()
	return stats
}

// StartRTSPBridge starts a RTSP server that clients can connect to
func StartRTSPBridge(ctx context.Context, cfg config.Config, in <-chan []byte) error {
	// Set up an RTSP server using FFmpeg
	args := []string{
		"-f", "mpegts",
		"-i", "pipe:0",
		"-c", "copy",
		"-f", "rtsp",
		"-rtsp_transport", "tcp",
		fmt.Sprintf("rtsp://0.0.0.0:8554/stream"),
	}

	// Create FFmpeg command
	cmd := exec.CommandContext(ctx, "ffmpeg", args...)

	// Connect stdin pipe
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdin pipe: %w", err)
	}

	// Redirect stderr to logger
	cmd.Stderr = newLogWriter("rtsp-bridge")

	// Start FFmpeg process
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start RTSP bridge: %w", err)
	}

	log.Printf("Started RTSP bridge at rtsp://0.0.0.0:8554/stream")

	// Process frames
	go func() {
		defer stdin.Close()
		defer cmd.Process.Kill()

		frameCount := 0
		var totalBytes int64

		for {
			select {
			case <-ctx.Done():
				log.Printf("RTSP bridge received shutdown signal, finalizing...")
				stdin.Close()
				cmd.Wait()
				return
			case frame, ok := <-in:
				if !ok {
					return
				}

				// Write frame to FFmpeg
				if _, err := stdin.Write(frame); err != nil {
					log.Printf("Error writing to RTSP bridge: %v", err)
					return
				}

				frameCount++
				totalBytes += int64(len(frame))

				// Update stats periodically
				if frameCount%300 == 0 {
					statsMutex.Lock()
					stats.TotalBytes = totalBytes
					statsMutex.Unlock()
				}
			}
		}
	}()

	return nil
}

// StartMulticastBridge starts a UDP multicast server for LAN streaming
func StartMulticastBridge(ctx context.Context, cfg config.Config, in <-chan []byte) error {
	// Multicast address (default or from config)
	multicastAddr := "239.255.42.42:5004"
	if cfg.MulticastAddr != "" {
		multicastAddr = cfg.MulticastAddr
	}

	// Set up UDP multicast using FFmpeg
	args := []string{
		"-f", "mpegts",
		"-i", "pipe:0",
		"-c", "copy",
		"-f", "mpegts",
		"-muxdelay", "0.1",
		fmt.Sprintf("udp://%s?pkt_size=1316", multicastAddr),
	}

	// Create FFmpeg command
	cmd := exec.CommandContext(ctx, "ffmpeg", args...)

	// Connect stdin pipe
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdin pipe: %w", err)
	}

	// Redirect stderr to logger
	cmd.Stderr = newLogWriter("multicast-bridge")

	// Start FFmpeg process
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start multicast bridge: %w", err)
	}

	log.Printf("Started multicast bridge at %s", multicastAddr)

	// Process frames
	go func() {
		defer stdin.Close()
		defer cmd.Process.Kill()

		for {
			select {
			case <-ctx.Done():
				log.Printf("Multicast bridge received shutdown signal, finalizing...")
				stdin.Close()
				cmd.Wait()
				return
			case frame, ok := <-in:
				if !ok {
					return
				}

				// Write frame to FFmpeg
				if _, err := stdin.Write(frame); err != nil {
					log.Printf("Error writing to multicast bridge: %v", err)
					return
				}
			}
		}
	}()

	return nil
}

// StartWebRTCBridge starts a WebRTC server for browser-based peer-to-peer streaming
func StartWebRTCBridge(ctx context.Context, cfg config.Config, in <-chan []byte) error {
	// This is a simplified placeholder for what would be a more complex WebRTC implementation
	// In a real setup this would use Pion WebRTC or similar

	log.Printf("WebRTC bridge not fully implemented yet")

	// Mock implementation to just consume frames
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case _, ok := <-in:
				if !ok {
					return
				}
				// Just consume frames for now
			}
		}
	}()

	return nil
}

// Custom writer to prefix log messages
type logWriter struct {
	prefix string
}

func newLogWriter(prefix string) *logWriter {
	return &logWriter{prefix: prefix}
}

func (w *logWriter) Write(p []byte) (n int, err error) {
	message := strings.TrimSpace(string(p))
	if message != "" {
		log.Printf("[%s] %s", w.prefix, message)
	}
	return len(p), nil
}
EOF

# Create multi-camera manager module
sudo mkdir -p virtual-studio/pkg/multicam
sudo tee virtual-studio/pkg/multicam/manager.go > /dev/null <<'EOF'
package multicam

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
	"virtual-studio/pkg/config"
)

// Camera represents a single camera stream
type Camera struct {
	ID          string
	Name        string
	DevicePath  string
	IsLive      bool
	LastUpdate  time.Time
	FrameWidth  int
	FrameHeight int
	Framerate   float64
}

// Manager handles multiple camera streams
type Manager struct {
	cameras      map[string]*Camera
	activeCamID  string
	pipelineFunc func(context.Context, *Camera) error
	mu           sync.RWMutex
}

// NewManager creates a new multi-camera manager
func NewManager() *Manager {
	return &Manager{
		cameras: make(map[string]*Camera),
	}
}

// RegisterCamera adds a camera to the manager
func (m *Manager) RegisterCamera(id, name, devicePath string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.cameras[id]; exists {
		return fmt.Errorf("camera with ID %s already exists", id)
	}

	m.cameras[id] = &Camera{
		ID:         id,
		Name:       name,
		DevicePath: devicePath,
		IsLive:     false,
		LastUpdate: time.Now(),
	}

	// If this is the first camera, make it active
	if len(m.cameras) == 1 {
		m.activeCamID = id
	}

	log.Printf("Registered camera %s (%s) at %s", id, name, devicePath)
	return nil
}

// SetActiveCamera changes the active camera
func (m *Manager) SetActiveCamera(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.cameras[id]; !exists {
		return fmt.Errorf("camera with ID %s not found", id)
	}

	if m.activeCamID != id {
		prevID := m.activeCamID
		m.activeCamID = id
		log.Printf("Switched active camera from %s to %s", prevID, id)
	}

	return nil
}

// GetActiveCamera returns the currently active camera
func (m *Manager) GetActiveCamera() *Camera {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if cam, exists := m.cameras[m.activeCamID]; exists {
		return cam
	}
	return nil
}

// GetAllCameras returns all registered cameras
func (m *Manager) GetAllCameras() []*Camera {
	m.mu.RLock()
	defer m.mu.RUnlock()

	cameras := make([]*Camera, 0, len(m.cameras))
	for _, cam := range m.cameras {
		cameras = append(cameras, cam)
	}
	return cameras
}

// StartCameraScanner periodically scans for new cameras
func (m *Manager) StartCameraScanner(ctx context.Context, scanInterval time.Duration) {
	ticker := time.NewTicker(scanInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			m.scanForNewCameras()
		}
	}
}

// scanForNewCameras looks for new video devices and registers them
func (m *Manager) scanForNewCameras() {
	// This would be implemented using the v4l2 subsystem to detect new devices
	// For now, this is just a placeholder
	log.Println("Scanning for new cameras...")
}

// UpdateCameraStats updates the statistics for a camera
func (m *Manager) UpdateCameraStats(id string, width, height int, fps float64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if cam, exists := m.cameras[id]; exists {
		cam.FrameWidth = width
		cam.FrameHeight = height
		cam.Framerate = fps
		cam.LastUpdate = time.Now()
	}
}

// StartGridView creates a composite view of all cameras
func (m *Manager) StartGridView(ctx context.Context, cfg config.Config, out chan<- []byte) error {
	// This would create a grid view of all active cameras
	// It would use FFmpeg to composite multiple inputs
	// For now, this is just a placeholder
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case <-time.After(1 * time.Second):
				// Just a placeholder
			}
		}
	}()

	return nil
}
EOF

# Create NDI bridge for network device interface support
sudo mkdir -p virtual-studio/pkg/ndi
sudo tee virtual-studio/pkg/ndi/bridge.go > /dev/null <<'EOF'
package ndi

import (
	"context"
	"fmt"
	"log"
	"os/exec"
	"strings"
	"sync"
	"time"
	"virtual-studio/pkg/config"
)

// NDISource represents an NDI source on the network
type NDISource struct {
	Name        string
	Address     string
	IsConnected bool
	LastSeen    time.Time
}

// NDIStats holds statistics about the NDI bridge
type NDIStats struct {
	ActiveSources int
	TotalBytes    int64
	Uptime        int64
}

var (
	stats      NDIStats
	statsMutex sync.RWMutex
	sources    = make(map[string]*NDISource)
	sourcesMu  sync.RWMutex
)

// StartNDIOutput creates an NDI output from the H.264 stream
func StartNDIOutput(ctx context.Context, cfg config.Config, in <-chan []byte) error {
	// Check if we have NDI tools installed
	if !checkNDITools() {
		log.Println("NDI tools not detected, NDI output disabled")
		return nil
	}

	// NDI source name (from config or default)
	sourceName := "VirtualStudio"
	if cfg.DevicePath != "" {
		// Extract camera ID from device path
		parts := strings.Split(cfg.DevicePath, "/")
		if len(parts) > 0 {
			sourceName = fmt.Sprintf("VirtualStudio_%s", parts[len(parts)-1])
		}
	}

	// Set up NDI output using FFmpeg
	args := []string{
		"-f", "mpegts",
		"-i", "pipe:0",
		"-c:v", "libx264", // Re-encode for compatibility
		"-preset", "veryfast",
		"-tune", "zerolatency",
		"-f", "libndi_newtek",
		"-ndi_name", sourceName,
		"-"
	}

	// Create FFmpeg command
	cmd := exec.CommandContext(ctx, "ffmpeg", args...)

	// Connect stdin pipe
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("failed to create stdin pipe: %w", err)
	}

	// Redirect stderr to logger
	cmd.Stderr = newLogWriter("ndi-output")

	// Start FFmpeg process
	if err := cmd.Start(); err != nil {
		if strings.Contains(err.Error(), "exec: \"ffmpeg\"") {
			log.Println("FFmpeg not found, NDI output disabled")
			return nil
		}
		return fmt.Errorf("failed to start NDI output: %w", err)
	}

	log.Printf("Started NDI output with source name: %s", sourceName)

	// Process frames
	go func() {
		defer stdin.Close()
		defer cmd.Process.Kill()

		frameCount := 0
		var totalBytes int64

		for {
			select {
			case <-ctx.Done():
				log.Printf("NDI output received shutdown signal, finalizing...")
				stdin.Close()
				cmd.Wait()
				return
			case frame, ok := <-in:
				if !ok {
					return
				}

				// Write frame to FFmpeg
				if _, err := stdin.Write(frame); err != nil {
					log.Printf("Error writing to NDI output: %v", err)
					return
				}

				frameCount++
				totalBytes += int64(len(frame))

				// Update stats periodically
				if frameCount%300 == 0 {
					statsMutex.Lock()
					stats.TotalBytes = totalBytes
					statsMutex.Unlock()
				}
			}
		}
	}()

	return nil
}

// StartNDIScanner starts a scanner for NDI sources on the network
func StartNDIScanner(ctx context.Context, scanInterval time.Duration) {
	// Check if we have NDI tools installed
	if !checkNDITools() {
		log.Println("NDI tools not detected, NDI scanner disabled")
		return
	}

	ticker := time.NewTicker(scanInterval)
	defer ticker.Stop()

	log.Println("Started NDI network scanner")

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			scanForNDISources()
		}
	}
}

// scanForNDISources searches for NDI sources on the network
func scanForNDISources() {
	// This would use NDI Find API in a real implementation
	// For now, this is just a placeholder
	log.Println("Scanning for NDI sources...")
}

// GetNDISources returns all detected NDI sources
func GetNDISources() []*NDISource {
	sourcesMu.RLock()
	defer sourcesMu.RUnlock()

	result := make([]*NDISource, 0, len(sources))
	for _, src := range sources {
		result = append(result, src)
	}
	return result
}

// GetStats returns a copy of the current NDI statistics
func GetStats() NDIStats {
	statsMutex.RLock()
	defer statsMutex.RUnlock()
	return stats
}

// checkNDITools verifies if NDI tools are installed
func checkNDITools() bool {
	// Check for NDI runtime
	cmd := exec.Command("bash", "-c", "ldconfig -p | grep -q libndi")
	err := cmd.Run()
	return err == nil
}

// Custom writer to prefix log messages
type logWriter struct {
	prefix string
}

func newLogWriter(prefix string) *logWriter {
	return &logWriter{prefix: prefix}
}

func (w *logWriter) Write(p []byte) (n int, err error) {
	message := strings.TrimSpace(string(p))
	if message != "" {
		log.Printf("[%s] %s", w.prefix, message)
	}
	return len(p), nil
}
EOF

# Create advanced Docker deployment
sudo tee virtual-studio/Dockerfile > /dev/null <<'EOF'
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    v4l-utils \
    golang-go \
    git \
    make \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# For NVIDIA support (uncomment if needed)
# ENV NVIDIA_VISIBLE_DEVICES all
# ENV NVIDIA_DRIVER_CAPABILITIES=all

WORKDIR /app

# Copy source code
COPY . .

# Build the application
RUN make build

# Expose web UI port
EXPOSE 8080

# Expose RTSP port
EXPOSE 8554

# Expose SRT port
EXPOSE 1935

# Volume for recordings
VOLUME ["/app/recordings"]

# Default command
CMD ["./bin/virtual-studio"]
EOF

# Create Docker Compose setup for multi-container deployment
sudo tee virtual-studio/docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  virtual-studio:
    build: .
    restart: unless-stopped
    privileged: true  # Needed for access to video devices
    ports:
      - "8080:8080"   # Web UI
      - "8554:8554"   # RTSP
      - "1935:1935"   # RTMP/SRT
    volumes:
      - ./recordings:/app/recordings
      - /dev:/dev     # Pass through video devices
    devices:
      - /dev/video0:/dev/video0  # Primary camera
    environment:
      - DEVICE_PATH=/dev/video0
      - RESOLUTION=1920x1080
      - FRAMERATE=60
      - BITRATE=6M
      - ENCODER_TYPE=auto
      - STREAM_PROTOCOL=rtmp
      - STREAM_URL=rtmp://localhost:1935/live/stream
    
  # Optional MinIO S3-compatible storage
  minio:
    image: minio/minio
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - ./minio-data:/data
    environment:
      - MINIO_ROOT_USER=minioadmin
      - MINIO_ROOT_PASSWORD=minioadmin
    command: server /data --console-address ":9001"
EOF

# Create an advanced install script for auto-detection and installation
sudo tee virtual-studio/install.sh > /dev/null <<'EOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}Virtual Studio Professional Installer${NC}"
echo "======================================="
echo

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

# Installation path
INSTALL_DIR="/opt/virtual-studio"
CONFIG_FILE="$INSTALL_DIR/config.json"

# Create installation directory
mkdir -p $INSTALL_DIR

# Detect platform
echo -e "${BOLD}Detecting hardware platform...${NC}"
PLATFORM="unknown"
GPU_TYPE="none"

if grep -q "Raspberry Pi" /proc/cpuinfo; then
  PLATFORM="raspberrypi"
  echo -e "  ${GREEN}✓${NC} Detected ${BOLD}Raspberry Pi${NC}"
  GPU_TYPE="v4l2m2m"
elif [ -e /dev/nvidia0 ]; then
  PLATFORM="nvidia"
  echo -e "  ${GREEN}✓${NC} Detected ${BOLD}NVIDIA GPU system${NC}"
  GPU_TYPE="nvenc"
  
  # Check NVIDIA driver version
  NVIDIA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
  echo -e "  ${GREEN}✓${NC} NVIDIA driver version: ${BOLD}$NVIDIA_VERSION${NC}"
elif lspci | grep -q "Intel Corporation.*Graphics"; then
  PLATFORM="intel"
  echo -e "  ${GREEN}✓${NC} Detected ${BOLD}Intel GPU system${NC}"
  GPU_TYPE="qsv"
  
  # Check for Intel GPU type
  if lspci | grep -q "UHD Graphics"; then
    echo -e "  ${GREEN}✓${NC} Intel UHD Graphics detected"
  elif lspci | grep -q "Iris"; then
    echo -e "  ${GREEN}✓${NC} Intel Iris Graphics detected"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} No hardware acceleration detected, using software encoding"
  GPU_TYPE="software"
fi

# Check for video devices
echo -e "\n${BOLD}Scanning for video capture devices...${NC}"
DEVICES=$(v4l2-ctl --list-devices 2>/dev/null)

if [ -z "$DEVICES" ]; then
  echo -e "  ${YELLOW}⚠${NC} No video devices found"
  DEFAULT_DEVICE=""
else
  echo -e "$DEVICES" | while read -r line; do
    if [[ $line == *"video"* ]]; then
      echo -e "  ${GREEN}✓${NC} Found $line"
    fi
  done
  
  # Try to find first video device
  DEFAULT_DEVICE=$(echo -e "$DEVICES" | grep -o "/dev/video[0-9]" | head -n 1)
  if [ -n "$DEFAULT_DEVICE" ]; then
    echo -e "  ${GREEN}✓${NC} Default device: ${BOLD}$DEFAULT_DEVICE${NC}"
    
    # Try to get capabilities
    CAPS=$(v4l2-ctl -d $DEFAULT_DEVICE --list-formats-ext 2>/dev/null | grep -A2 -i "yuv" | head -n 3)
    if [ -n "$CAPS" ]; then
      echo -e "  ${GREEN}✓${NC} Device capabilities: "
      echo "$CAPS" | sed 's/^/      /'
    fi
  fi
fi

# Install dependencies
echo -e "\n${BOLD}Installing required packages...${NC}"

# Common packages
echo -e "  ${GREEN}→${NC} Installing base dependencies..."
apt-get update -qq
apt-get install -y ffmpeg v4l-utils golang-go git make curl wget > /dev/null

# Platform-specific packages
if [ "$PLATFORM" = "raspberrypi" ]; then
  echo -e "  ${GREEN}→${NC} Installing Raspberry Pi specific packages..."
  apt-get install -y libraspberrypi-bin libraspberrypi-dev > /dev/null
elif [ "$PLATFORM" = "nvidia" ]; then
  echo -e "  ${GREEN}→${NC} Installing NVIDIA specific packages..."
  apt-get install -y nvidia-cuda-toolkit nvidia-cuda-dev > /dev/null
elif [ "$PLATFORM" = "intel" ]; then
  echo -e "  ${GREEN}→${NC} Installing Intel specific packages..."
  apt-get install -y intel-media-va-driver-non-free vainfo intel-gpu-tools > /dev/null
fi

echo -e "  ${GREEN}✓${NC} All dependencies installed"

# Copy files to installation directory
echo -e "\n${BOLD}Installing Virtual Studio...${NC}"
cp -r ./* $INSTALL_DIR/

# Build the application
echo -e "  ${GREEN}→${NC} Building application..."
cd $INSTALL_DIR
make build > /dev/null

# Set up systemd service
echo -e "  ${GREEN}→${NC} Setting up system service..."
cp $INSTALL_DIR/virtual-studio.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable virtual-studio.service

# Create default configuration
echo -e "  ${GREEN}→${NC} Creating default configuration..."
cat > $CONFIG_FILE <<CONFIGJSON
{
  "device_path": "$DEFAULT_DEVICE", 
  "resolution": "1920x1080",
  "framerate": 60,
  "encoder_type": "$GPU_TYPE",
  "bitrate": "6M",
  "preset": "ultrafast",
  "http_port": "8080",
  "recording_path": "$INSTALL_DIR/recordings",
  "stream_protocol": "",
  "stream_url": ""
}
CONFIGJSON

# Create directories
mkdir -p $INSTALL_DIR/recordings
mkdir -p $INSTALL_DIR/logs

# Set file permissions
chmod +x $INSTALL_DIR/bin/virtual-studio
chmod +x $INSTALL_DIR/setup.sh

# Final message
echo -e "\n${GREEN}${BOLD}Installation complete!${NC}"
echo -e "\nVirtual Studio has been installed to: ${BOLD}$INSTALL_DIR${NC}"
echo -e "Configuration file: ${BOLD}$CONFIG_FILE${NC}"
echo -e "\nYou can start the service with: ${BOLD}systemctl start virtual-studio${NC}"
echo -e "Web interface will be available at: ${BOLD}http://localhost:8080${NC}"
echo -e "\nFor manual control, use: ${BOLD}$INSTALL_DIR/bin/virtual-studio --help${NC}"

# Offer to start the service
echo -e "\nWould you like to start Virtual Studio now? (y/n)"
read -r START_SERVICE

if [[ $START_SERVICE =~ ^[Yy]$ ]]; then
  echo -e "  ${GREEN}→${NC} Starting Virtual Studio service..."
  systemctl start virtual-studio
  sleep 2
  if systemctl is-active --quiet virtual-studio; then
    echo -e "  ${GREEN}✓${NC} Service started successfully!"
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo -e "\n${GREEN}${BOLD}Virtual Studio is now running!${NC}"
    echo -e "Access the web interface at: ${BOLD}http://$IP_ADDR:8080${NC}"
  else
    echo -e "  ${RED}✗${NC} Service failed to start. Check logs with: ${BOLD}journalctl -u virtual-studio${NC}"
  fi
else
  echo -e "\nYou can start the service later with: ${BOLD}systemctl start virtual-studio${NC}"
fi
EOF

# Make install script executable
sudo chmod +x virtual-studio/install.sh

# Update the main.go to include the new modules
sudo tee -a virtual-studio/main.go > /dev/null <<'EOF'

	// Initialize advanced modules if configured
	if cfg.EnableMulticast {
		log.Printf("Starting multicast bridge...")
		go func() {
			if err := bridge.StartMulticastBridge(ctx, cfg, encodedFrames); err != nil {
				log.Printf("Multicast bridge error: %v", err)
			}
		}()
	}

	// Initialize NDI output if available
	log.Printf("Checking for NDI capability...")
	go func() {
		if err := ndi.StartNDIOutput(ctx, cfg, encodedFrames); err != nil {
			log.Printf("NDI initialization error: %v", err)
		}
	}()

	// Start NDI scanner in the background
	go ndi.StartNDIScanner(ctx, 30*time.Second)

	// Initialize multi-camera manager if multiple sources
	camManager := multicam.NewManager()
	if cfg.DevicePath != "" {
		camManager.RegisterCamera("main", "Main Camera", cfg.DevicePath)
	}
	
	// Start camera scanner in the background
	go camManager.StartCameraScanner(ctx, 10*time.Second)
EOF

echo "Advanced extensions added to Virtual Studio"