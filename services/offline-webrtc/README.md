# 🌐 offline-webrtc

A containerized WebRTC solution for offline or local network video streaming without reliance on external STUN/TURN servers.

## 🎯 Overview

This project provides a complete WebRTC infrastructure that works without internet connectivity:
- Local STUN/TURN server using Coturn
- Custom WebRTC signaling server with Express and WebSocket
- Easy integration with containerized OBS
- Browser-based streaming client with peer-to-peer capabilities

## 🚀 Quick Start

```bash
# Clone the repository or run the setup script
git clone https://github.com/Cdaprod/local-docker-rtmp-server.git
# OR
chmod +x cli-setup.sh && ./cli-setup.sh

# Start the WebRTC services
docker compose up -d
```

Access the WebRTC client interface:
- Web browser: http://your-host-ip:8088

## 📋 Features

- **Self-contained**: All WebRTC infrastructure runs locally
- **Low Latency**: Sub-second video streaming
- **Containerized**: Easy deployment with Docker
- **OBS Integration**: Works seamlessly with containerized OBS
- **Offline Ready**: Functions without internet connectivity
- **Mobile Compatible**: Works on modern mobile browsers
- **Dynamic Configuration**: Automatically uses the local hostname for STUN/TURN

## 🛠️ Components

### Coturn STUN/TURN Server

Handles NAT traversal and peer connectivity:
- Exposes port 3478 (TCP/UDP) for STUN/TURN negotiation
- Uses ports 49152-65535 (UDP) for media relay
- Simple authentication with preset credentials
- Configured to work in offline environments

### WebRTC Signaling Server

Coordinates connection between peers:
- Node.js Express server with WebSocket support
- Handles client ID assignment and room management
- Relays offers, answers, and ICE candidates
- Maintains client connection status

### Browser Client

Feature-rich interface for streaming and receiving:
- Automatic camera/microphone access
- WebRTC peer connection management
- User discovery and call initiation
- Connection status monitoring
- Responsive design with clean UI

## 📁 Project Structure

```
offline-webrtc/
├── app/
│   ├── public/
│   │   ├── index.html        # WebRTC client interface
│   │   └── client.js         # WebRTC client logic
│   ├── package.json          # Node.js dependencies
│   └── server.js             # Signaling server implementation
├── turnserver.conf           # Coturn server configuration
├── cli-setup.sh              # Automated setup script
└── docker-compose.yml        # Container configuration
```

## 🔧 Configuration

### Docker Compose Setup

The `docker-compose.yml` defines the complete infrastructure:

```yaml
services:
  # Coturn STUN/TURN server
  coturn:
    image: coturn/coturn:latest
    container_name: webrtc-coturn
    ports:
      - "3478:3478"
      - "3478:3478/udp"
      - "49152-65535:49152-65535/udp"
    volumes:
      - ./turnserver.conf:/etc/coturn/turnserver.conf
    command: -c /etc/coturn/turnserver.conf
    restart: unless-stopped

  # WebRTC signaling server
  signaling:
    image: node:18-alpine
    container_name: webrtc-signaling
    working_dir: /app
    volumes:
      - ./app:/app
    ports:
      - "8088:8080"
    depends_on:
      - coturn
    command: sh -c "cd /app && npm install && npm start"
    restart: unless-stopped
    networks:
      default:
        aliases:
          - webrtc-signaling

networks:
  default:
    name: webrtc-network
```

### Coturn Configuration

The `turnserver.conf` file defines the STUN/TURN server settings:

```conf
# TURN server configuration for offline WebRTC
listening-port=3478
realm=webrtc.local
user=webrtc:webrtc123
min-port=49152
max-port=65535
fingerprint
lt-cred-mech
no-tls
verbose
allow-loopback-peers
mobility
listening-ip=0.0.0.0
relay-ip=0.0.0.0
total-quota=100
max-bps=0
no-rest
# external-ip=YOUR_SERVER_PUBLIC_IP  # Uncomment for production
```

### WebRTC Client Configuration

The client automatically configures STUN/TURN servers using the current hostname:

```javascript
const peerConfiguration = {
  iceServers: [
    {
      urls: `stun:${window.location.hostname}:3478`
    },
    {
      urls: `turn:${window.location.hostname}:3478`,
      username: 'webrtc',
      credential: 'webrtc123'
    }
  ],
  iceCandidatePoolSize: 10
};
```

## 📖 Usage Examples

### Direct Peer-to-Peer Communication

The included demo application provides a simple interface for peer-to-peer video calls:

1. Open the WebRTC interface at http://your-host-ip:8088
2. Click "Start Camera" to access your camera and microphone
3. Click "Connect to Server" to join the signaling network
4. The interface will display other connected users
5. Click "Call" next to a user to initiate a WebRTC connection
6. The remote video will appear when the connection is established

### Integration with Other Services

To integrate with OBS or other services:

1. Use the WebRTC client as a browser source in OBS:
   - Add Browser Source > http://localhost:8088
   - Set appropriate width/height

2. For custom applications, connect to the signaling server and implement the WebRTC protocol:
   ```javascript
   const ws = new WebSocket('ws://your-host-ip:8088');
   // Follow standard WebRTC connection establishment
   ```

## 🌐 Integration with pi-obs-container

This project is designed to work alongside the pi-obs-container:

```bash
# Directory structure
/path/to/project
├── pi-obs-container/     # OBS studio container
└── offline-webrtc/       # WebRTC infrastructure
```

To add offline-webrtc to your existing OBS setup:

1. Add WebRTC service definitions to your docker-compose file or use a separate file
2. Configure OBS to use the WebRTC stream as a source:
   - Add a Browser Source in OBS
   - Point it to http://webrtc-signaling:8080 (internal network name)

## 🔍 Troubleshooting

### Connection Issues

If peers can't connect:

1. Verify STUN/TURN connectivity:
   ```bash
   docker logs webrtc-coturn
   ```

2. Check browser console for ICE connection failures

3. Verify container networking:
   ```bash
   docker network inspect webrtc-network
   ```

### Media Access Problems

If camera or microphone access fails:

1. Check browser permissions
2. Verify the requested media constraints in client.js
3. Try using specific video/audio constraints:
   ```javascript
   // Example of specific constraints
   const constraints = {
     video: {
       width: { ideal: 1280 },
       height: { ideal: 720 }
     },
     audio: true
   };
   ```

## 🔒 Security Considerations

For production use, consider these security enhancements:

1. **TURN Authentication**:
   - Change the default username/password in turnserver.conf
   - Implement time-limited credentials

2. **Signaling Security**:
   - Add authentication to the signaling server
   - Implement HTTPS for the signaling connections

3. **Network Isolation**:
   - Use Docker's network capabilities to isolate services
   - Implement proper firewalling for external access

## 📚 Technical Reference

### Key Technologies

- **WebRTC**: Web Real-Time Communication API
- **Coturn**: STUN/TURN server implementation
- **Express**: Web server framework for Node.js
- **ws**: WebSocket implementation for Node.js
- **Docker**: Container platform for deployment

### Relevant Ports

| Port | Service | Protocol | Purpose |
|------|---------|----------|---------|
| 3478 | Coturn | TCP/UDP | STUN/TURN negotiation |
| 49152-65535 | Coturn | UDP | Media relay ports |
| 8088 | Signaling | HTTP/WS | WebRTC signaling |

## 📝 License

MIT License

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

---

For additional information or questions, open an issue on GitHub.