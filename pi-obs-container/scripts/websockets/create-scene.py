import websocket
import json

OBS_WS_URL = "ws://localhost:4455"
OBS_WS_PASSWORD = "your_obs_password"

def obs_request(payload):
    ws = websocket.create_connection(OBS_WS_URL)
    ws.send(json.dumps(payload))
    response = json.loads(ws.recv())
    ws.close()
    return response

# Authenticate with OBS WebSocket
auth_payload = {
    "request-type": "Authenticate",
    "auth": OBS_WS_PASSWORD,
    "message-id": "1"
}
obs_request(auth_payload)

# Create a new scene
scene_name = "New_Scene"
payload = {
    "request-type": "CreateScene",
    "sceneName": scene_name,
    "message-id": "2"
}
response = obs_request(payload)
print(f"Scene '{scene_name}' created successfully!")