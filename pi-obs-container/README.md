# pi-obs-container

A containerized OBS Studio setup optimized for Raspberry Pi and headless environments.

## noVNC Browser URL

`http://192.168.0.21:6080/vnc.html?autoconnect=true&resize=scale&reconnect=true`

## Docker run command for build testing `osb-pi` container with `cdaprod/obs-runtime-build:v1.1.0` aka `:latest`.

``` 
docker run --rm -it \
  --name obs-pi \
  --privileged \
  -v $(pwd)/config:/root/.config/obs-studio \
  -v $(pwd)/assets:/root/assets \
  -v $(pwd)/scripts:/root/scripts \
  -p 5800:5800 -p 5900:5900 -p 6080:6080 -p 4455:4455 \
  --device /dev/video0 \
  obs-pi:latest
``` 

## Manually run virtual headless OBS with this command:

```bash
xvfb-run --server-num=99 --server-args="-screen 0 1920x1080x24" obs --startstreaming --profile 'CdaprodOBS' --collection 'Laptop OBS Scenes'
``` 

## 🎯 Overview

This project provides a Docker container running OBS Studio with:
- Remote access via VNC and WebSocket
- Headless operation capabilities
- Pre-configured for video streaming without audio
- RTMP streaming support for various services

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/pi-obs-container.git
cd pi-obs-container

# Start the container
docker-compose -f docker-compose.obs.yaml up -d
```

Access the OBS interface:
- Web browser: http://your-host-ip:6080
- VNC client: vnc://your-host-ip:5900

## 📋 Features

- **Fully Containerized**: Runs in Docker for easy deployment
- **Headless Operation**: No physical display required
- **Remote Control**: WebSocket API for programmatic control
- **GUI Access**: VNC and noVNC for remote desktop access
- **RTMP Streaming**: Pre-configured for streaming platforms
- **Audio Control**: Options for muted audio streaming

## 🎛️ Audio Configuration Options

### Option 1: Mute Audio Sources in OBS GUI

If using OBS with GUI access (X11 or VNC):
1. Launch OBS
2. In the Audio Mixer, click the speaker icon next to:
   - Mic/Aux
   - Desktop Audio
3. Right-click > Properties or Filters to remove audio input completely

### Option 2: Mute Audio via obs-cli or WebSocket API

For headless or automated operation:

```bash
# Use the obs-cli or WebSocket API to mute audio sources
obs-cli --password "your_ws_password" SourceSettings SetMute \
  --source-name "Mic/Aux" \
  --mute true

# Or mute both sources
obs-cli SourceSettings SetMute --source-name "Mic/Aux" --mute true
obs-cli SourceSettings SetMute --source-name "Desktop Audio" --mute true
```

### Option 3: CLI Launch with Audio Disabled

When starting OBS with `--startstreaming` (no GUI):

```bash
obs --startstreaming --scene "CameraOnly" --collection "Minimal" --profile "NoAudio"
```

In the NoAudio profile, configure:
```ini
# ~/.config/obs-studio/basic/profiles/NoAudio/basic.ini
[Audio]
SampleRate=44100
Channels=2
DesktopAudioDevice1=disabled
DesktopAudioDevice2=disabled
Mic/AuxAudioDevice=disabled
```

### Bonus: Stream to RTMP Without Audio via FFmpeg

If bypassing OBS:
```bash
ffmpeg -f v4l2 -i /dev/video0 -an -f flv rtmp://your.server/live/stream
```

The `-an` flag disables audio.

## 📁 Project Structure

```
.
├── config
│   ├── basic
│   │   ├── profiles
│   │   │   └── CdaprodOBS
│   │   │       ├── basic.ini
│   │   │       ├── obs-multi-rtmp.json
│   │   │       ├── service.json
│   │   │       └── streamEncoder.json
│   │   └── scenes
│   ├── global.ini
│   ├── plugin_config
│   │   ├── obs-websocket
│   │   │   └── config.json
│   │   ├── rtmp-services
│   │   └── win-capture
│   └── user.ini
├── detect-devices.sh
├── docker-compose.obs.yaml
├── Dockerfile
├── entrypoint.sh
├── frame_overlay.png
├── scripts
│   └── setup-obs-machine.sh
└── supervisord.conf
```

## 🔧 Configuration

### Customizing the Container

Edit the Docker Compose file to customize the container:

```yaml
# docker-compose.obs.yaml
version: '3'
services:
  obs:
    build: .
    container_name: pi-obs
    restart: unless-stopped
    ports:
      - "4455:4455"  # WebSocket API
      - "5900:5900"  # VNC
      - "6080:6080"  # noVNC
    volumes:
      - ./config:/home/obs/.config/obs-studio
      - /dev/video0:/dev/video0  # Pass through camera
    devices:
      - /dev/video0:/dev/video0
    environment:
      - DISPLAY=:1
      - VNC_PASSWORD=your_password
      - OBS_WEBSOCKET_PASSWORD=your_ws_password
```

### WebSocket Configuration

Edit the WebSocket configuration to secure remote control:

```json
// config/plugin_config/obs-websocket/config.json
{
  "server_enabled": true,
  "server_port": 4455,
  "server_password": "your_secure_password"
}
```

## 📖 Usage Examples

### Starting a Stream Programmatically

```bash
# Start a stream using obs-cli
obs-cli --password "your_ws_password" Stream Start

# Switch scenes
obs-cli --password "your_ws_password" Scenes SetCurrentScene --scene-name "Camera"
```

### Running Completely Headless

```bash
# Start container with minimal resources
docker run -d --name obs-headless \
  -e START_STREAMING=true \
  -e OBS_SCENE="Camera" \
  -e DISABLE_GUI=true \
  -p 4455:4455 \
  yourusername/pi-obs-container
```

## 🔒 Security Recommendations

1. **Change Default Passwords**:
   - Set strong passwords for VNC and WebSocket access
   - Update all default credentials

2. **Network Restrictions**:
   - Limit external access to management ports (4455, 5900, 6080)
   - Consider using a reverse proxy for secure remote access

3. **RTMP Security**:
   - Use stream keys and other authentication for RTMP streams
   - Secure sensitive streaming URLs in your configuration

---  

## ✅ Port Overview: What We're Using

Here's a breakdown of the ports used across all services and components in your pi-obs-container:

⸻

### 📡 1. OBS WebSocket API (4455)
- **Port**: 4455
- **Purpose**: Allows remote control of OBS using the WebSocket protocol.
- **Usage**:
  - obs-cli communicates with this port to modify scenes, start/stop streaming, etc.
  - External tools like OBS Studio WebSocket clients or automation scripts can use this port.

⸻

### 🌐 2. VNC Server (5900)
- **Port**: 5900
- **Purpose**: Provides VNC access to the OBS desktop.
- **Usage**:
  - Direct VNC access using any VNC client (vnc://<your-host-ip>:5900).
  - Allows control over the OBS GUI running inside the container.
  - Useful for remote access to a full XFCE desktop.

⸻

### 🌐 3. noVNC Web Interface (6080)
- **Port**: 6080
- **Purpose**: Provides a browser-based VNC client that exposes the OBS desktop GUI over HTTP.
- **Usage**:
  - Access the OBS GUI through a web browser (http://<your-host-ip>:6080).
  - Provides a lightweight, easily accessible alternative to a dedicated VNC client.

⸻

### 🎥 4. RTMP Streaming (Default OBS Output Ports)
- **Port**: Typically 1935 (RTMP Standard) but can be customized.
- **Purpose**: Stream live video content from OBS to external services (e.g., YouTube, Twitch).
- **Usage**:
  - Defined within OBS's service.json or obs-multi-rtmp.json files.
  - Configured based on the streaming service's RTMP ingestion URL.

⸻

### 📡 5. HTTP Live Streaming / HLS (Optional if Configured in OBS)
- **Port**: Varies depending on configuration (8080 or 1936 in some cases).
- **Purpose**: HTTP Live Streaming (HLS) if configured for adaptive bitrate streaming.
- **Usage**:
  - Provides low-latency streaming to web clients.
  - Configured via OBS or NGINX (if RTMP/HLS proxy is enabled).

⸻

### 🎛️ Summary of All Relevant Ports

| Port | Service | Protocol | Purpose |
|------|---------|----------|---------|
| 4455 | OBS WebSocket | WebSocket | Remote control API for OBS |
| 5900 | VNC Server | VNC | Direct access to OBS GUI |
| 6080 | noVNC | HTTP | Web-based VNC interface for OBS GUI |
| 1935 | RTMP Stream | RTMP | Streaming to YouTube/Twitch/Custom RTMP |
| 8080 | HLS (Optional) | HTTP/HLS | HTTP Live Streaming (if enabled) |

⸻

### 📝 Recommended Actions to Manage and Secure Ports

1. **Restrict External Access**:
   - If you only need internal LAN access to VNC and WebSockets, use a firewall to block external access to these ports.
   - For external access, consider using a reverse proxy (like Traefik or Nginx) to protect and route traffic securely.

2. **Configure WebSocket Authentication**:
   - Enable a password for WebSocket access in config/plugin_config/obs-websocket/config.json:

```json
{
  "server_enabled": true,
  "server_port": 4455,
  "server_password": "secure_password_here"
}
```
   - This ensures that only authenticated clients can control OBS remotely.

3. **Limit noVNC/VNC Access**:
   - Use an SSH tunnel if accessing the VNC session remotely for added security:

```bash
ssh -L 6080:localhost:6080 user@your-host
```

4. **Stream with RTMP Secure URLs**:
   - Double-check the RTMP ingestion URL and ensure it uses secure keys or authentication to prevent unauthorized access.

⸻

### 🕹️ Next Steps:

To apply the updated configuration:

- **Rebuild and Restart the Container**:

```bash
docker-compose -f docker-compose.obs.yaml build
docker-compose -f docker-compose.obs.yaml up -d
```

- **Access OBS via**:
  - Browser: http://<your-host-ip>:6080 (noVNC)
  - VNC Client: vnc://<your-host-ip>:5900
  - WebSocket API: ws://<your-host-ip>:4455

✅ You now have full control over OBS and its streaming services across multiple platforms and hosts!

## 🛠️ Troubleshooting

### No Video Device Detected

Run the detect-devices.sh script to check available video devices:

```bash
docker exec pi-obs ./detect-devices.sh
```

Ensure your video device is properly connected and permissions are set correctly.

### High CPU Usage

For Raspberry Pi and other low-power devices:

1. Lower the video resolution in OBS settings
2. Reduce the frame rate to 15 or 20 fps
3. Use hardware encoding when available (H.264/H.265)
4. Disable unnecessary plugins and sources

## 📝 License

MIT License

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

---

For additional information or questions, open an issue on GitHub.