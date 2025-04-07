from obswebsocket import obsws, requests

# Connection
host = "192.168.0.21"
port = 4455
password = "cda123"
ws = obsws(host, port, password)
ws.connect()

# 1. Create new composite scene
scene = "LIVE_COMPOSITE"
ws.call(requests.CreateScene(scene))

# 2. Add Main Camera (Nikon)
ws.call(requests.CreateInput(scene, "MainCam", "scene", {"sceneName": "3-Nikon"}))
# 3. Add Desk Cam (OBSBot via desk scene)
ws.call(requests.CreateInput(scene, "DeskCam", "scene", {"sceneName": "Scene - Desk Scene"}))
# 4. Add iPhone Feed
ws.call(requests.CreateInput(scene, "iPhoneCam", "scene", {"sceneName": "1-iPhone"}))

# 5. Set layout
ws.call(requests.SetSceneItemTransform("MainCam", {
    "position": {"x": 1200, "y": 620},
    "scale": {"x": 0.5, "y": 0.5}
}))
ws.call(requests.SetSceneItemTransform("iPhoneCam", {
    "position": {"x": 200, "y": 620},
    "scale": {"x": 0.5, "y": 0.5}
}))
ws.call(requests.SetSceneItemTransform("DeskCam", {
    "position": {"x": 640, "y": 100},
    "scale": {"x": 0.6, "y": 0.6}
}))

# 6. (Optional) Start OBS virtual camera
ws.call(requests.StartVirtualCam())

# 7. Switch to LIVE_COMPOSITE scene
ws.call(requests.SetCurrentProgramScene(scene))

print("Scene configured successfully.")