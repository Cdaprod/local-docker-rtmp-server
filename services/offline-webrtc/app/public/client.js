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
