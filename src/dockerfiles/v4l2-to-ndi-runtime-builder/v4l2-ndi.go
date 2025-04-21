package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Config holds all configuration options for the streamer
type Config struct {
	// V4L2 settings
	DevicePath  string
	Width       int
	Height      int
	FrameRate   int
	PixelFormat string

	// NDI settings
	NDIName string
}

// NDIStreamer handles V4L2 capture and NDI output
type NDIStreamer struct {
	config  Config
	cmd     *exec.Cmd
	running bool
}

// NewNDIStreamer creates a new NDI streamer
func NewNDIStreamer(config Config) *NDIStreamer {
	return &NDIStreamer{
		config:  config,
		running: false,
	}
}

// Start begins capturing from the camera and streaming to NDI
func (s *NDIStreamer) Start() error {
	if s.running {
		return fmt.Errorf("streamer is already running")
	}

	log.Printf("Starting V4L2 to NDI stream from %s at %dx%d @ %dfps",
		s.config.DevicePath, s.config.Width, s.config.Height, s.config.FrameRate)

	// We use FFmpeg as the intermediary between V4L2 and NDI
	// This approach leverages FFmpeg's excellent V4L2 support and the NDI SDK
	// For an ultra-low latency solution, we use specific FFmpeg flags
	
	// Check if FFmpeg is available
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		return fmt.Errorf("ffmpeg not found in PATH: %w", err)
	}
	
	// Build the FFmpeg command for low latency
	// Note: You'll need to have ffmpeg compiled with libndi_newtek support
	// or use the NDI Tools with FFmpeg integration
	args := []string{
		// Input settings for V4L2 capture
		"-f", "v4l2",
		"-framerate", strconv.Itoa(s.config.FrameRate),
		"-video_size", fmt.Sprintf("%dx%d", s.config.Width, s.config.Height),
		"-input_format", s.config.PixelFormat,
		"-i", s.config.DevicePath,
		
		// Video encoding settings for low latency
		"-c:v", "libx264",
		"-preset", "ultrafast",
		"-tune", "zerolatency",
		"-profile:v", "baseline",
		"-level", "3.0",
		"-pix_fmt", "yuv420p",
		
		// Buffer and latency settings
		"-probesize", "32",        // Small probe size for faster startup
		"-analyzeduration", "0",   // Don't analyze input streams
		"-fflags", "nobuffer",     // Reduce input buffering
		"-flags", "low_delay",     // Minimize encoding delay
		"-strict", "experimental", // Allow experimental codecs
		"-vsync", "0",             // Disable video sync to avoid frame dropping
		"-thread_queue_size", "512", // Increase queue for stability
		
		// NDI output
		"-f", "libndi_newtek",
		"-ndi_name", s.config.NDIName,
	}
	
	// Some V4L2 devices might need additional parameters
	// For example, forcing a specific format
	// args = append(args, "-vf", "format=yuv420p")

	// Create the FFmpeg command
	s.cmd = exec.Command("ffmpeg", args...)
	
	// Set up pipes for stdout and stderr
	s.cmd.Stdout = os.Stdout
	s.cmd.Stderr = os.Stderr
	
	// Start the process
	if err := s.cmd.Start(); err != nil {
		return fmt.Errorf("failed to start FFmpeg: %w", err)
	}
	
	s.running = true
	
	// Watch for process completion
	go func() {
		err := s.cmd.Wait()
		s.running = false
		if err != nil {
			log.Printf("FFmpeg process ended with error: %v", err)
		} else {
			log.Println("FFmpeg process completed successfully")
		}
	}()
	
	return nil
}

// Stop ends the streaming process
func (s *NDIStreamer) Stop() error {
	if !s.running {
		return nil // Nothing to do
	}
	
	log.Println("Stopping NDI streamer...")
	
	// Try to gracefully terminate the process
	if s.cmd.Process != nil {
		// Send SIGINT to allow FFmpeg to clean up
		if err := s.cmd.Process.Signal(syscall.SIGINT); err != nil {
			log.Printf("Warning: Failed to send SIGINT to FFmpeg: %v", err)
			
			// If SIGINT fails, force kill after a timeout
			time.Sleep(2 * time.Second)
			if s.running {
				if err := s.cmd.Process.Kill(); err != nil {
					return fmt.Errorf("failed to kill FFmpeg process: %w", err)
				}
			}
		}
		
		// Wait for process to exit
		timeout := time.NewTimer(5 * time.Second)
		done := make(chan struct{})
		
		go func() {
			for s.running {
				time.Sleep(100 * time.Millisecond)
			}
			done <- struct{}{}
		}()
		
		select {
		case <-done:
			log.Println("FFmpeg process terminated gracefully")
		case <-timeout.C:
			log.Println("Timeout waiting for FFmpeg to exit, forcing termination")
			if err := s.cmd.Process.Kill(); err != nil {
				return fmt.Errorf("failed to force kill FFmpeg: %w", err)
			}
		}
	}
	
	s.running = false
	return nil
}

// ListV4L2Devices attempts to list available V4L2 devices on the system
func ListV4L2Devices() {
	fmt.Println("Searching for V4L2 devices...")
	
	// Check if v4l2-ctl is available
	v4l2CtlPath, err := exec.LookPath("v4l2-ctl")
	if err == nil {
		// Use v4l2-ctl to list devices
		cmd := exec.Command(v4l2CtlPath, "--list-devices")
		output, err := cmd.CombinedOutput()
		if err == nil {
			fmt.Println("Available V4L2 devices:")
			fmt.Println(string(output))
			return
		}
	}
	
	// Fallback method: check common device paths
	devices := []string{}
	for i := 0; i < 10; i++ {
		devicePath := fmt.Sprintf("/dev/video%d", i)
		if _, err := os.Stat(devicePath); err == nil {
			devices = append(devices, devicePath)
		}
	}
	
	if len(devices) > 0 {
		fmt.Println("Found V4L2 devices:")
		for _, device := range devices {
			fmt.Println(" -", device)
		}
	} else {
		fmt.Println("No V4L2 devices found. Make sure your camera is connected.")
	}
}

// DetectNDISupport checks if the system supports NDI output
func DetectNDISupport() bool {
	// Check if FFmpeg has NDI support
	cmd := exec.Command("ffmpeg", "-hide_banner", "-formats")
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Error checking FFmpeg formats: %v", err)
		return false
	}
	
	// Check if libndi_newtek is in the supported formats
	return strings.Contains(string(output), "libndi_newtek")
}

func main() {
	// Parse command line flags
	devicePath := flag.String("device", "/dev/video0", "V4L2 device path")
	width := flag.Int("width", 1280, "Video width")
	height := flag.Int("height", 720, "Video height")
	frameRate := flag.Int("fps", 30, "Frame rate")
	pixelFormat := flag.String("format", "yuyv422", "Pixel format (yuyv422, mjpeg, h264, etc)")
	ndiName := flag.String("ndi-name", "Go V4L2 Camera", "NDI stream name")
	listDevices := flag.Bool("list-devices", false, "List available V4L2 devices and exit")
	
	flag.Parse()
	
	// If requested, list devices and exit
	if *listDevices {
		ListV4L2Devices()
		return
	}
	
	// Check for NDI support
	if !DetectNDISupport() {
		log.Fatal("FFmpeg does not have NDI support. Make sure you have FFmpeg compiled with libndi_newtek support.")
	}
	
	// Create the configuration
	config := Config{
		DevicePath:  *devicePath,
		Width:       *width,
		Height:      *height,
		FrameRate:   *frameRate,
		PixelFormat: *pixelFormat,
		NDIName:     *ndiName,
	}
	
	// Create and start the streamer
	streamer := NewNDIStreamer(config)
	if err := streamer.Start(); err != nil {
		log.Fatalf("Failed to start streamer: %v", err)
	}
	
	// Set up signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	
	// Wait for termination signal
	sig := <-sigChan
	log.Printf("Received signal %v, shutting down...", sig)
	
	// Stop the streamer
	if err := streamer.Stop(); err != nil {
		log.Printf("Error stopping streamer: %v", err)
	}
	
	log.Println("Shutdown complete")
}