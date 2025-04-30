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
