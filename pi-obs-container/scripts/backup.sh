#!/bin/bash

# Export Scenes via OBS WebSocket API
curl -X POST -H "Content-Type: application/json" \
     -d '{"request-type": "SaveReplayBuffer", "message-id": "1"}' \
     ws://localhost:4455

# Save Scene Collection to Backup Directory
curl -X POST -H "Content-Type: application/json" \
     -d '{"request-type": "SaveSceneCollection", "message-id": "2"}' \
     ws://localhost:4455