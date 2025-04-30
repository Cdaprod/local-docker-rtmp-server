import websocket
import json
import time

# OBS WebSocket Config
OBS_WS_URL = "ws://localhost:4455"
OBS_WS_PASSWORD = "your_obs_password"

# Helper function to send WebSocket requests
def obs_request(payload):
    """Send a request to OBS WebSocket."""
    ws = websocket.create_connection(OBS_WS_URL)
    ws.send(json.dumps(payload))
    response = json.loads(ws.recv())
    ws.close()
    return response

# Authenticate with WebSocket
def authenticate():
    auth_payload = {
        "request-type": "GetAuthRequired",
        "message-id": "1"
    }
    response = obs_request(auth_payload)

    # Check if auth is required
    if response.get("authRequired", False):
        auth_payload = {
            "request-type": "Authenticate",
            "auth": OBS_WS_PASSWORD,
            "message-id": "2"
        }
        response = obs_request(auth_payload)
        if response.get("status") != "ok":
            raise Exception("Failed to authenticate with OBS WebSocket")

# Change active scene
def change_scene(scene_name):
    payload = {
        "request-type": "SetCurrentScene",
        "scene-name": scene_name,
        "message-id": "3"
    }
    obs_request(payload)
    print(f"Scene switched to: {scene_name}")

# Create a new scene
def create_scene(scene_name):
    payload = {
        "request-type": "CreateScene",
        "sceneName": scene_name,
        "message-id": "4"
    }
    obs_request(payload)
    print(f"Scene '{scene_name}' created successfully.")

# List available scenes
def list_scenes():
    payload = {
        "request-type": "GetSceneList",
        "message-id": "5"
    }
    response = obs_request(payload)
    for scene in response['scenes']:
        print(f"- {scene['name']}")

# Add an image or overlay to a scene
def add_overlay(scene_name, source_name, file_path, x=0, y=0, width=1920, height=1080):
    payload = {
        "request-type": "CreateSource",
        "scene-name": scene_name,
        "sourceName": source_name,
        "sourceKind": "image_source",
        "sourceSettings": {
            "file": file_path
        },
        "message-id": "6"
    }
    obs_request(payload)

    # Set the position and size of the source
    transform_payload = {
        "request-type": "SetSceneItemProperties",
        "scene-name": scene_name,
        "item": {
            "name": source_name
        },
        "position": {"x": x, "y": y},
        "scale": {"x": width / 1920, "y": height / 1080},
        "message-id": "7"
    }
    obs_request(transform_payload)
    print(f"Added '{source_name}' overlay to '{scene_name}'.")

# Hot reload sources in a scene
def reload_source(source_name):
    payload = {
        "request-type": "RefreshBrowserSource",
        "sourceName": source_name,
        "message-id": "8"
    }
    obs_request(payload)
    print(f"Source '{source_name}' reloaded.")

# Run a demo with automated scene switching
def demo_scene_switch():
    scenes = ["Intro_Scene", "iPhone_Scene", "Gameplay_Scene", "Outro_Scene"]
    for scene in scenes:
        change_scene(scene)
        time.sleep(3)

# Authenticate and manage OBS
try:
    authenticate()
    print("Connected to OBS WebSocket!")
    list_scenes()
    
    # Demo: Auto-switch between scenes
    demo_scene_switch()
    
except Exception as e:
    print(f"Error: {str(e)}")