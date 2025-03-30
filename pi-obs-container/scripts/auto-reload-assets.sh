import os
import time
import websocket

OBS_WS_URL = "ws://localhost:4455"
OBS_WS_PASSWORD = "your_password"

def reload_scene():
    ws = websocket.create_connection(OBS_WS_URL)
    auth_payload = {
        "request-type": "GetAuthRequired",
        "message-id": "1"
    }
    ws.send(json.dumps(auth_payload))
    ws.close()
    print("OBS scenes reloaded successfully!")

def watch_directory(path):
    before = dict([(f, None) for f in os.listdir(path)])
    while True:
        time.sleep(2)
        after = dict([(f, None) for f in os.listdir(path)])
        added = [f for f in after if not f in before]
        if added:
            print(f"New asset detected: {', '.join(added)}")
            reload_scene()
        before = after

watch_directory("/config/basic/scenes")