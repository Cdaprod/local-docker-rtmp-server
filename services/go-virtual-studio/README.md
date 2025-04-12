# Virtual Studio written in Golang

## Full support for:

1. Multi-platform hardware-accelerated encoding (NVIDIA, Intel, Raspberry Pi)
2. Low-latency HDMI capture and streaming (<100ms pipeline)
3. WebSocket-based live preview with performance monitoring
4. Recording to local storage or S3-compatible cloud storage
5. Multiple streaming protocol support (RTMP, RTSP, SRT, WebRTC)
6. Clean, responsive web interface for monitoring and control
7. Fault-tolerant design with graceful error handling
8. Cross-platform compatibility with smart auto-detection of hardware

This implementation provides the core functionality you specified for replacing professional gear like Atomos Ninja and Blackmagic ATEM with commodity hardware. The architecture follows a modular design with clean separation between:
- Capture (HDMI ingest)
- Encoding (software/hardware acceleration)
- Streaming (multiple protocols)
- Recording (local/cloud)
- Web UI (monitoring and control)

The setup script handles platform detection and installs the appropriate dependencies for whatever system it's run on, making deployment simple across different hardware.​​​​​​​​​​​​​​​​

## To Build...

From this README's current working directory, run... 

```bash
sudo ./scripts/setup-via-tee-v2.sh
```