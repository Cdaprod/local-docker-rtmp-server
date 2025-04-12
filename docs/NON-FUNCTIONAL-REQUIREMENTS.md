David, this is badass. You’re building a software-defined multi-cam video studio pipeline that rivals pro gear like Atomos Ninja, Teradek Bolt, and Blackmagic ATEM -- using commodity HDMI capture dongles + application logic for ingest, preview, encode, route, and store.

This is what I call a "Virtualized HDMI Stack", and I’m all in to help you spec and build it.

⸻

Your NFR Summary (Rephrased for Engineering)

Function	Non-Functional Constraint
Capture HDMI via USB	Support USB UVC dongles, low latency
Encode H.264	Software/hardware encoding with offload
Replace HDMI wireless	Must stream + multicast over LAN/WiFi
Replace Ninja-style recorder	High-quality local display, record to file or S3
Virtual Studio Control	Preview, scene switch, live out, stream
Streaming & Multicast	RTMP/RTSP/WebRTC out, peer multicam ingest
Modular	Hot-pluggable cameras and scalable
Realtime	60 FPS, < 100ms delay pipeline
Storage	S3-compatible (MinIO?) file backend



⸻

Phase 1: Hardware + Streaming Stack

1. Peripheral: USB HDMI Capture Dongle
	•	Plug & Play HDMI-to-USB3 capture card (UVC class)
	•	Shows up as /dev/videoX on Linux
	•	Supports 1080p@60 → confirmed via:

v4l2-ctl --list-formats-ext -d /dev/video0



⸻

2. Application Device

Think ZimaBoard, Raspberry Pi 5, Jetson Nano, or N100 mini PC

Requirements:
	•	GPU or VPU offload (Pi: V4L2M2M, Jetson: NVENC)
	•	Display output (HDMI or framebuffer preview)
	•	Ethernet/WiFi (Tailscale multicast-friendly)
	•	App written in C++/Golang (real-time) + Electron or QT for GUI

⸻

Phase 2: Core Pipeline

Modular Components

A. Ingest (Capture Layer)
	•	USB capture → raw YUV frames
	•	Frame timestamps → async pipelines
	•	Frame buffer for preview + encode

B. Encode / Transcode
	•	H.264 encode via:
	•	libx264 (software)
	•	h264_v4l2m2m (Raspberry Pi)
	•	nvenc (Jetson)
	•	Control bitrate, CRF, latency tuning

C. Stream Manager
	•	RTMP, SRT, or custom UDP multicast sender
	•	Optional WebRTC module (Pion/mediasoup)

D. Preview UI
	•	Local render of all sources (multicam grid)
	•	Zoom-in full screen preview per input
	•	Realtime overlays, FPS/bitrate stats

E. Recorder
	•	Save .mp4 chunks or .ts segments
	•	Auto-upload to S3 (MinIO preferred)

F. Controller
	•	Preview switching
	•	Virtual scene builder (layouts, overlays)
	•	Stream toggle per feed

⸻

Phase 3: Languages and Frameworks

C++ (Core Pipeline)
	•	FFmpeg C++ bindings for low-level control
	•	GStreamer C API for pipelines
	•	DeckLink SDK optional for higher-end

Golang (High-Level Controller)
	•	FFmpeg via CGo
	•	Pion for WebRTC
	•	goav, gstreamer-go, or just spawn subprocesses for encoding
	•	WebSockets + WebRTC for UI sync

Frontend
	•	Electron or QT for display UI
	•	Or use WebView/WebSocket GUI served over LAN

⸻

Phase 4: Deployment + Integration

Component	Stack
Capture	v4l2 / FFmpeg / GStreamer
Encode	h264_v4l2m2m / libx264 / nvenc
Control	Go + REST/WebSocket/CLI
UI	QT / Electron / React
Stream Out	RTMP / WebRTC / UDP
Object Storage	MinIO S3
Preview Render	OpenGL / EGL framebuffer



⸻

Bonus Features to Design For
	•	Multicam NDI-style LAN sync
	•	WebRTC control room
	•	Auto-upload to S3 + CDN (e.g. BunnyNet)
	•	Metadata overlays (frame ID, cam ID, bitrate, FPS)
	•	AI tasks (frame diffing, stabilization, auto-cuts)

⸻

Next Steps

If you’re serious about building this:
	1.	Pick your dev board (Raspberry Pi 5, Jetson Nano, or ZimaBoard)
	2.	Tell me:
	•	How many HDMI sources?
	•	Which protocols you want to stream?
	•	Do you want C++ or Go core?
	•	Do you need a browser-based UI?
	3.	I’ll:
	•	Sketch the multi-threaded ingest/encode pipeline
	•	Scaffold the app architecture
	•	Include Makefile/build scripts
	•	Define how to build the "Atomos replacement" app

Let’s make this the open-source wireless video studio that Blackmagic and Atomos should’ve made.