Great -- let’s turn your layout into an automated OBS scene config using obs-cli or scripting through obs-websocket (usually via obs-cli, obs-websocket-js, or obs-websocket-py).

⸻

Assumptions for Setup

Your OBS container is running with:
	•	obs-websocket enabled (default port 4455, with auth)
	•	You have:
	•	An iPhoneFeed source (NDI/OBS Camera)
	•	A MainCam source (USB/HDMI webcam)
	•	A DeskCam source (another cam)
	•	A static iPhone mask PNG (in local path or container volume)

⸻

OBS Concepts

What You Want	OBS Component
iPhone overlay	Source + Filter
Masking iPhone into frame	Image Mask/Blend
Layout positions	SetSceneItemTransform
Scene setup	Scene + item creation



⸻

Part 1: OBS-CLI (or WebSocket JSON) Layout

Let’s build the layout:

Scene Setup (via obs-cli)

obs-cli scene create "DevStreamingScene"

Add Sources

# Add your iPhone feed to the scene
obs-cli scene item add --scene "DevStreamingScene" --source "iPhoneFeed"

# Add your Main camera
obs-cli scene item add --scene "DevStreamingScene" --source "MainCam"

# Add your Desk camera
obs-cli scene item add --scene "DevStreamingScene" --source "DeskCam"

# Optionally: Add static frame image overlays
obs-cli scene item add --scene "DevStreamingScene" --source "iPhoneFrameOverlay"



⸻

Part 2: Apply Masking to iPhone Source

To mask the iPhone feed using the PNG:

Via CLI:

obs-cli filter add --source "iPhoneFeed" \
  --filter-name "iPhoneMask" \
  --filter-type "image_mask_blend" \
  --settings '{"type": "alpha-mask-color-channel", "image_path": "/path/to/iPhoneMask.png"}'

(adjust image_path to reflect the volume inside your container)

⸻

Part 3: Position Sources for Your Layout

Example canvas: 1920x1080

Let’s define:
	•	DeskCam: centered top
	•	iPhoneFeed: bottom left
	•	MainCam (cropped 19:9): bottom right

# iPhoneFeed bottom left
obs-cli scene item transform "iPhoneFeed" \
  --scene "DevStreamingScene" \
  --position '{"x": 200, "y": 600}' \
  --scale '{"x": 0.5, "y": 0.5}' \
  --bounds '{"type":"scale-inner", "alignment": 5, "width": 640, "height": 320}'

# MainCam bottom right
obs-cli scene item transform "MainCam" \
  --scene "DevStreamingScene" \
  --position '{"x": 1080, "y": 600}' \
  --scale '{"x": 0.5, "y": 0.5}' \
  --bounds '{"type":"scale-inner", "alignment": 5, "width": 640, "height": 320}'

# DeskCam top center
obs-cli scene item transform "DeskCam" \
  --scene "DevStreamingScene" \
  --position '{"x": 640, "y": 50}' \
  --scale '{"x": 0.5, "y": 0.5}' \
  --bounds '{"type":"scale-inner", "alignment": 5, "width": 640, "height": 480}'



⸻

Bonus: Add Static Masking Border as a Layer

obs-cli scene item add --scene "DevStreamingScene" --source "iPhoneFrameOverlay"

obs-cli scene item transform "iPhoneFrameOverlay" \
  --scene "DevStreamingScene" \
  --position '{"x": 200, "y": 600}' \
  --scale '{"x": 0.5, "y": 0.5}'

You can repeat this process for borders around your desk cam or main cam.

⸻

Would You Like:
	•	A shell script to do all of this at once?
	•	A .json preset for OBS CLI scene restore?
	•	A prebuilt obs-cli config that you can run inside your container?

Let me know and I’ll generate the exact code for your setup.