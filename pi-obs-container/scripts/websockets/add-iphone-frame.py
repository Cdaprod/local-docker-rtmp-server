""" 
Cron Job: `*/5 * * * * python3 /path/add-iphone-frame.py`
""" 
import websocket
import json

# WebSocket Configuration
OBS_WS_URL = "ws://localhost:4455"
OBS_WS_PASSWORD = "your_obs_password"

# iPhone source and overlay names
IPHONE_SOURCE_NAME = "iPhoneSource"
FRAME_SOURCE_NAME = "iPhoneFrame"
FRAME_IMAGE_PATH = "/config/basic/scenes/frame_overlay.png"

def obs_request(payload):
    """Send a request to the OBS WebSocket."""
    ws = websocket.create_connection(OBS_WS_URL)
    ws.send(json.dumps(payload))
    response = ws.recv()
    ws.close()
    return json.loads(response)

# Authenticate with OBS WebSocket
auth_payload = {
    "request-type": "Authenticate",
    "auth": OBS_WS_PASSWORD,
    "message-id": "1"
}
obs_request(auth_payload)

# Add the iPhone frame as an image source if it doesn't exist
add_frame_payload = {
    "request-type": "CreateSource",
    "scene-name": "Scene",
    "sourceName": FRAME_SOURCE_NAME,
    "sourceKind": "image_source",
    "sourceSettings": {
        "file": FRAME_IMAGE_PATH
    },
    "message-id": "2"
}
obs_request(add_frame_payload)

# Set frame order to be above the iPhone source
set_order_payload = {
    "request-type": "SetSceneItemOrder",
    "scene-name": "Scene",
    "item": {
        "name": FRAME_SOURCE_NAME
    },
    "order": {
        "after": IPHONE_SOURCE_NAME
    },
    "message-id": "3"
}
obs_request(set_order_payload)

print("Frame overlay added successfully!")