const express = require('express');
const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const app = express();

// Serve a basic page (optional)
app.get('/', (req, res) => res.send('WebRTC signaling server is running.'));

const server = app.listen(PORT, () => {
  console.log(`HTTP/WebSocket server listening on port ${PORT}`);
});

// WebSocket server for signaling
const wss = new WebSocket.Server({ server });

wss.on('connection', ws => {
  ws.on('message', message => {
    // Broadcast incoming messages to all connected clients
    wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  });

  ws.send('Welcome to the WebRTC signaling server!');
});