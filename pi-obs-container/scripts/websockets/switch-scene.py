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

# Switch scene function
def change_scene(scene_name):
    payload = {
        "request-type": "SetCurrentScene",
        "scene-name": scene_name,
        "message-id": "1"
    }
    obs_request(payload)
    print(f"Switched to scene: {scene_name}")

# Example usage
change_scene("iPhone_Scene")