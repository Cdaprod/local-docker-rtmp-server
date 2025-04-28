#!/bin/bash

# Create project directory structure
mkdir -p offline-webrtc
cd offline-webrtc

# Create app directory structure
mkdir -p app/public

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  # Coturn STUN/TURN server
  coturn:
    image: coturn/coturn:latest
    container_name: webrtc-coturn
    # Changed from host network mode to expose specific ports
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
      - "8088:8080"  # Changed from 8080:8080 to 8088:8080
    depends_on:
      - coturn
    command: sh -c "cd /app && npm install && npm start"
    restart: unless-stopped
    # Create a network alias for the signaling server
    # This makes accessing by hostname more reliable
    networks:
      default:
        aliases:
          - webrtc-signaling

# Define the default network with a custom name for easier reference
networks:
  default:
    name: webrtc-network
EOF

# Create turnserver.conf
cat > turnserver.conf << 'EOF'
# TURN server configuration for offline WebRTC

# TURN listener port for UDP and TCP
listening-port=3478

# TURN server realm
realm=webrtc.local

# Static authentication credentials (username:password)
user=webrtc:webrtc123

# Specify the relay ports range
min-port=49152
max-port=65535

# Use fingerprint for STUN/TURN messages
fingerprint

# Use long-term credential mechanism
lt-cred-mech

# Disable TLS for simplicity in an offline environment
no-tls

# Log file settings
verbose

# Allow loopback addresses for local testing
allow-loopback-peers

# Enable the mobility ICE extension
mobility

# Listen on all interfaces
listening-ip=0.0.0.0

# Specify the relay IP - use the container's IP address
relay-ip=0.0.0.0

# Total number of relays permitted
total-quota=100

# Bandwidth limitations (in kbps) - 0 means unlimited
max-bps=0

# Disable REST API
no-rest

# Set the external IP if you're running this in a production environment
# external-ip=YOUR_SERVER_PUBLIC_IP
EOF

# Create package.json
cat > app/package.json << 'EOF'
{
  "name": "webrtc-signaling-server",
  "version": "1.0.0",
  "description": "Simple WebRTC signaling server for offline use",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "ws": "^8.13.0"
  }
}
EOF

# Create server.js
cat > app/server.js << 'EOF'
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');

// Create Express app
const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// WebSocket connections
const clients = new Map();

wss.on('connection', (ws) => {
  const id = generateUniqueId();
  const color = getRandomColor();
  const metadata = { id, color };

  clients.set(ws, metadata);

  // Send the client their assigned ID
  ws.send(JSON.stringify({
    type: 'connect',
    id: id,
    clients: [...clients.values()].map(m => m.id).filter(clientId => clientId !== id)
  }));

  // Broadcast new client connection to all other clients
  [...clients.keys()].forEach(client => {
    if (client !== ws && client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({
        type: 'user-joined',
        id: id
      }));
    }
  });

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      // Handle different message types
      switch (data.type) {
        case 'offer':
        case 'answer':
        case 'ice-candidate':
          // Forward the message to the target client
          if (data.target && data.sender) {
            [...clients.keys()].forEach(client => {
              const clientMetadata = clients.get(client);
              if (clientMetadata.id === data.target && client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                  type: data.type,
                  data: data.data,
                  sender: data.sender
                }));
              }
            });
          }
          break;
        
        case 'ping':
          ws.send(JSON.stringify({ type: 'pong' }));
          break;
          
        default:
          console.log('Unknown message type:', data.type);
      }
    } catch (error) {
      console.error('Error processing message:', error);
    }
  });

  ws.on('close', () => {
    const clientMetadata = clients.get(ws);
    
    // Broadcast client disconnection to all other clients
    [...clients.keys()].forEach(client => {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({
          type: 'user-left',
          id: clientMetadata.id
        }));
      }
    });
    
    clients.delete(ws);
  });
});

// Generate a unique client ID
function generateUniqueId() {
  return Math.random().toString(36).substr(2, 9);
}

// Generate a random color
function getRandomColor() {
  const colors = ['#2196F3', '#32c787', '#00BCD4', '#ff5652', '#ffc107', '#ff85af', '#FF9800', '#39bbb0'];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Start the server
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  console.log(`WebRTC signaling server ready at ws://localhost:${PORT}`);
  console.log(`Access the WebRTC demo at http://localhost:${PORT}`);
});
EOF

# Create index.html
cat > app/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Offline WebRTC Demo</title>
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      margin: 0;
      padding: 20px;
      background-color: #f5f5f5;
      color: #333;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
      background-color: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 15px rgba(0,0,0,0.1);
    }
    h1 {
      text-align: center;
      color: #2c3e50;
      margin-bottom: 30px;
    }
    .connection-status {
      text-align: center;
      padding: 10px;
      margin-bottom: 20px;
      border-radius: 4px;
      font-weight: bold;
    }
    .connected {
      background-color: #d4edda;
      color: #155724;
    }
    .disconnected {
      background-color: #f8d7da;
      color: #721c24;
    }
    .connecting {
      background-color: #fff3cd;
      color: #856404;
    }
    .video-container {
      display: flex;
      justify-content: space-around;
      flex-wrap: wrap;
      margin: 20px 0;
    }
    .video-box {
      width: 45%;
      min-width: 300px;
      margin: 10px;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    }
    .video-header {
      background-color: #3498db;
      color: white;
      padding: 10px 15px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    video {
      width: 100%;
      background-color: #222;
      display: block;
    }
    .controls {
      display: flex;
      justify-content: center;
      margin: 30px 0;
      flex-wrap: wrap;
    }
    button {
      margin: 5px 10px;
      padding: 10px 20px;
      background-color: #3498db;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 16px;
      transition: all 0.3s ease;
    }
    button:disabled {
      background-color: #cccccc;
      cursor: not-allowed;
    }
    button:hover:not(:disabled) {
      background-color: #2980b9;
      transform: translateY(-2px);
    }
    button.danger {
      background-color: #e74c3c;
    }
    button.danger:hover:not(:disabled) {
      background-color: #c0392b;
    }
    button.success {
      background-color: #2ecc71;
    }
    button.success:hover:not(:disabled) {
      background-color: #27ae60;
    }
    .user-list {
      margin: 20px 0;
      border: 1px solid #ddd;
      border-radius: 4px;
      padding: 10px;
    }
    .user-list h3 {
      margin-top: 0;
      border-bottom: 1px solid #eee;
      padding-bottom: 10px;
    }
    .user-item {
      padding: 8px 12px;
      margin: 5px 0;
      background-color: #f1f1f1;
      border-radius: 4px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .user-item button {
      padding: 5px 10px;
      font-size: 14px;
    }
    .hidden {
      display: none;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Offline WebRTC Demo</h1>
    
    <div id="connectionStatus" class="connection-status disconnected">
      Not Connected
    </div>
    
    <div class="video-container">
      <div class="video-box">
        <div class="video-header">
          <h3>Local Video</h3>
          <span id="localVideoStatus">Inactive</span>
        </div>
        <video id="localVideo" autoplay muted playsinline></video>
      </div>
      <div class="video-box">
        <div class="video-header">
          <h3>Remote Video</h3>
          <span id="remoteVideoStatus">Inactive</span>
        </div>
        <video id="remoteVideo" autoplay playsinline></video>
      </div>
    </div>
    
    <div class="controls">
      <button id="startButton" class="success">Start Camera</button>
      <button id="connectButton">Connect to Server</button>
      <button id="hangupButton" class="danger" disabled>Hang Up</button>
    </div>
    
    <div id="userList" class="user-list hidden">
      <h3>Available Users</h3>
      <div id="users"></div>
    </div>
  </div>

  <script src="client.js"></script>
</body>
</html>
EOF

# Create client.js
cat > app/public/client.js << 'EOF'
// WebRTC client for offline communication

// Elements
const localVideo = document.getElementById('localVideo');
const remoteVideo = document.getElementById('remoteVideo');
const localVideoStatus = document.getElementById('localVideoStatus');
const remoteVideoStatus = document.getElementById('remoteVideoStatus');
const connectionStatus = document.getElementById('connectionStatus');
const startButton = document.getElementById('startButton');
const connectButton = document.getElementById('connectButton');
const hangupButton = document.getElementById('hangupButton');
const userList = document.getElementById('userList');
const usersContainer = document.getElementById('users');

// WebRTC variables
let localStream;
let peerConnection;
let ws;
let clientId;
let targetUserId;
let isConnected = false;

// Configuration for the STUN/TURN server
const peerConfiguration = {
  iceServers: [
    {
      // Use the current hostname instead of hardcoded values
      urls: `stun:${window.location.hostname}:3478`
    },
    {
      // Use the current hostname instead of hardcoded values
      urls: `turn:${window.location.hostname}:3478`,
      username: 'webrtc',
      credential: 'webrtc123'
    }
  ],
  iceCandidatePoolSize: 10
};

// Start local video stream
async function startLocalStream() {
  try {
    connectionStatus.className = 'connection-status connecting';
    connectionStatus.textContent = 'Accessing camera and microphone...';
    
    const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
    localVideo.srcObject = stream;
    localStream = stream;
    
    localVideoStatus.textContent = 'Active';
    startButton.disabled = true;
    connectButton.disabled = false;
    
    connectionStatus.className = 'connection-status connected';
    connectionStatus.textContent = 'Camera ready. Connect to start a call.';
  } catch (error) {
    console.error('Error accessing media devices:', error);
    connectionStatus.className = 'connection-status disconnected';
    connectionStatus.textContent = `Error: ${error.message}`;
  }
}

// Connect to the signaling server
function connectToServer() {
  connectionStatus.className = 'connection-status connecting';
  connectionStatus.textContent = 'Connecting to server...';
  
  // Create WebSocket connection
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}`;
  ws = new WebSocket(wsUrl);
  
  // WebSocket event handlers
  ws.onopen = function() {
    connectionStatus.className = 'connection-status connected';
    connectionStatus.textContent = 'Connected to server. Waiting for peers...';
    connectButton.textContent = 'Disconnect';
    
    // Send a ping every 30 seconds to keep the connection alive
    setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'ping' }));
      }
    }, 30000);
  };
  
  ws.onmessage = function(event) {
    const message = JSON.parse(event.data);
    handleSignalingMessage(message);
  };
  
  ws.onclose = function() {
    connectionStatus.className = 'connection-status disconnected';
    connectionStatus.textContent = 'Disconnected from server';
    connectButton.textContent = 'Connect to Server';
    userList.classList.add('hidden');
    hangupCall();
  };
  
  ws.onerror = function(error) {
    console.error('WebSocket error:', error);
    connectionStatus.className = 'connection-status disconnected';
    connectionStatus.textContent = 'Connection error';
  };
}

// Disconnect from the signaling server
function disconnectFromServer() {
  if (ws) {
    ws.close();
  }
}

// Handle signaling messages
function handleSignalingMessage(message) {
  switch (message.type) {
    case 'connect':
      clientId = message.id;
      updateUserList(message.clients);
      break;
      
    case 'user-joined':
      addUserToList(message.id);
      break;
      
    case 'user-left':
      removeUserFromList(message.id);
      // If the user we're connected to leaves, hang up
      if (targetUserId === message.id) {
        hangupCall();
      }
      break;
      
    case 'offer':
      handleVideoOffer(message);
      break;
      
    case 'answer':
      handleVideoAnswer(message);
      break;
      
    case 'ice-candidate':
      handleNewICECandidate(message);
      break;
      
    case 'pong':
      // Keep-alive response
      break;
      
    default:
      console.log('Unknown message type:', message.type);
  }
}

// Update the list of available users
function updateUserList(users) {
  userList.classList.remove('hidden');
  usersContainer.innerHTML = '';
  
  if (users.length === 0) {
    usersContainer.innerHTML = '<p>No other users available</p>';
    return;
  }
  
  users.forEach(userId => {
    addUserToList(userId);
  });
}

// Add a user to the list
function addUserToList(userId) {
  if (userId === clientId) return;
  
  // Check if the user is already in the list
  if (document.getElementById(`user-${userId}`)) return;
  
  const userItem = document.createElement('div');
  userItem.className = 'user-item';
  userItem.id = `user-${userId}`;
  
  const userLabel = document.createElement('span');
  userLabel.textContent = `User ${userId}`;
  
  const callButton = document.createElement('button');
  callButton.textContent = 'Call';
  callButton.className = 'success';
  callButton.onclick = () => startCall(userId);
  
  userItem.appendChild(userLabel);
  userItem.appendChild(callButton);
  usersContainer.appendChild(userItem);
  
  userList.classList.remove('hidden');
}

// Remove a user from the list
function removeUserFromList(userId) {
  const userItem = document.getElementById(`user-${userId}`);
  if (userItem) {
    userItem.remove();
  }
  
  if (usersContainer.children.length === 0) {
    usersContainer.innerHTML = '<p>No other users available</p>';
  }
}

// Start a call with another user
async function startCall(userId) {
  if (!localStream) {
    alert('Please start your camera first');
    return;
  }
  
  targetUserId = userId;
  connectionStatus.className = 'connection-status connecting';
  connectionStatus.textContent = `Calling user ${userId}...`;
  
  // Create RTCPeerConnection
  createPeerConnection();
  
  // Add local tracks to the connection
  localStream.getTracks().forEach(track => {
    peerConnection.addTrack(track, localStream);
  });
  
  try {
    // Create an offer
    const offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    
    // Send the offer to the remote peer
    sendToServer({
      type: 'offer',
      sender: clientId,
      target: targetUserId,
      data: offer
    });
    
    hangupButton.disabled = false;
  } catch (error) {
    console.error('Error creating offer:', error);
    connectionStatus.className = 'connection-status disconnected';
    connectionStatus.textContent = `Error: ${error.message}`;
    closePeerConnection();
  }
}

// Create RTCPeerConnection
function createPeerConnection() {
  closePeerConnection();
  
  peerConnection = new RTCPeerConnection(peerConfiguration);
  
  // Set up ICE candidate handling
  peerConnection.onicecandidate = event => {
    if (event.candidate) {
      sendToServer({
        type: 'ice-candidate',
        sender: clientId,
        target: targetUserId,
        data: event.candidate
      });
    }
  };
  
  // Handle ICE connection state changes
  peerConnection.oniceconnectionstatechange = () => {
    switch(peerConnection.iceConnectionState) {
      case 'connected':
      case 'completed':
        connectionStatus.className = 'connection-status connected';
        connectionStatus.textContent = `Connected to User ${targetUserId}`;
        isConnected = true;
        break;
      case 'failed':
      case 'disconnected':
      case 'closed':
        if (isConnected) {
          connectionStatus.className = 'connection-status disconnected';
          connectionStatus.textContent = 'Connection lost';
          hangupCall();
        }
        break;
    }
  };
  
  // Handle incoming tracks
  peerConnection.ontrack = event => {
    remoteVideo.srcObject = event.streams[0];
    remoteVideoStatus.textContent = 'Active';
  };
}

// Handle incoming video offer
async function handleVideoOffer(message) {
  targetUserId = message.sender;
  connectionStatus.className = 'connection-status connecting';
  connectionStatus.textContent = `Receiving call from User ${targetUserId}...`;
  
  // Create peer connection if not exists
  createPeerConnection();
  
  try {
    // Set remote description (the offer)
    await peerConnection.setRemoteDescription(new RTCSessionDescription(message.data));
    
    // Add local stream tracks to the connection
    if (localStream) {
      localStream.getTracks().forEach(track => {
        peerConnection.addTrack(track, localStream);
      });
    } else {
      console.warn('No local stream available when receiving call');
    }
    
    // Create answer
    const answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    
    // Send the answer
    sendToServer({
      type: 'answer',
      sender: clientId,
      target: targetUserId,
      data: answer
    });
    
    hangupButton.disabled = false;
  } catch (error) {
    console.error('Error handling offer:', error);
    connectionStatus.className = 'connection-status disconnected';
    connectionStatus.textContent = `Error: ${error.message}`;
    closePeerConnection();
  }
}

// Handle video answer
async function handleVideoAnswer(message) {
  try {
    await peerConnection.setRemoteDescription(new RTCSessionDescription(message.data));
  } catch (error) {
    console.error('Error handling answer:', error);
    connectionStatus.textContent = `Error: ${error.message}`;
  }
}

// Handle new ICE candidate
async function handleNewICECandidate(message) {
  try {
    if (peerConnection && message.data) {
      await peerConnection.addIceCandidate(new RTCIceCandidate(message.data));
    }
  } catch (error) {
    console.error('Error adding ICE candidate:', error);
  }
}

// Send message to the signaling server
function sendToServer(message) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  } else {
    console.error('WebSocket not connected');
    connectionStatus.className = 'connection-status disconnected';
    connectionStatus.textContent = 'Error: Not connected to server';
  }
}

// Hang up the call
function hangupCall() {
  closePeerConnection();
  
  remoteVideo.srcObject = null;
  remoteVideoStatus.textContent = 'Inactive';
  
  hangupButton.disabled = true;
  
  if (ws && ws.readyState === WebSocket.OPEN) {
    connectionStatus.className = 'connection-status connected';
    connectionStatus.textContent = 'Connected to server. Waiting for peers...';
  } else {
    connectionStatus.className = 'connection-status disconnected';
    connectionStatus.textContent = 'Call ended';
  }
}

// Close peer connection
function closePeerConnection() {
  if (peerConnection) {
    peerConnection.onicecandidate = null;
    peerConnection.ontrack = null;
    peerConnection.oniceconnectionstatechange = null;
    
    peerConnection.close();
    peerConnection = null;
  }
  
  isConnected = false;
  targetUserId = null;
}

// Toggle connection to server
function toggleConnection() {
  if (ws && ws.readyState === WebSocket.OPEN) {
    disconnectFromServer();
  } else {
    connectToServer();
  }
}

// Event listeners
startButton.addEventListener('click', startLocalStream);
connectButton.addEventListener('click', toggleConnection);
hangupButton.addEventListener('click', hangupCall);

// Handle page unload
window.addEventListener('beforeunload', () => {
  disconnectFromServer();
  hangupCall();
});
EOF