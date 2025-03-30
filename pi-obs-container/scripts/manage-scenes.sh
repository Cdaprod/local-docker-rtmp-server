import json
import websocket

OBS_WS_URL = "ws://localhost:4455"
OBS_WS_PASSWORD = "your_password"

def change_scene(scene_name):
    payload = {
        "request-type": "SetCurrentScene",
        "scene-name": scene_name,
        "message-id": "1"
    }
    ws = websocket.create_connection(OBS_WS_URL)
    ws.send(json.dumps(payload))
    result = ws.recv()
    ws.close()
    print(f"Scene changed to {scene_name}")

def list_scenes():
    payload = {
        "request-type": "GetSceneList",
        "message-id": "2"
    }
    ws = websocket.create_connection(OBS_WS_URL)
    ws.send(json.dumps(payload))
    result = json.loads(ws.recv())
    ws.close()
    for scene in result['scenes']:
        print(f"Scene: {scene['name']}")

# Example usage:
# change_scene("Intro_Scene")
# list_scenes()