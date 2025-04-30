# /app/jobs/generate_tracking_data.py
#
# Run this inside Blender headlessly: `blender --background --python /app/jobs/generate_tracking_data.py`
# Make sure the paths in video_path and output_json are volume-mounted in your container (e.g., /mnt/b for host-shared directories).
#
#

import bpy
import json
import os

# === CONFIGURATION ===
video_path = "/mnt/b/assets/footage/raw/shot001_desk_pan.mov"
output_json = "/mnt/b/app/exports/shot001_camera_path.json"
frame_start = 1
frame_end = 250
# =====================

# Clear existing scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Load movie clip into tracking workspace
clip = bpy.data.movieclips.load(video_path)
tracking = clip.tracking
tracking_settings = tracking.settings
tracking_settings.default_motion_model = 'LOC'
tracking_settings.use_default_red_channel = True

# Detect and track features
bpy.ops.clip.detect_features()
bpy.ops.clip.track_markers(forwards=True)
bpy.ops.clip.solve_camera()

# Set up 3D scene with tracking data
bpy.ops.clip.setup_tracking_scene()

# Ensure scene range matches
scene = bpy.context.scene
scene.frame_start = frame_start
scene.frame_end = frame_end

# Get camera object
camera = scene.camera

# Gather camera animation data
camera_data = []
for frame in range(frame_start, frame_end + 1):
    scene.frame_set(frame)
    loc = camera.matrix_world.to_translation()
    rot = camera.matrix_world.to_quaternion()
    camera_data.append({
        "frame": frame,
        "location": [loc.x, loc.y, loc.z],
        "rotation": [rot.x, rot.y, rot.z, rot.w]
    })

# Export to JSON
os.makedirs(os.path.dirname(output_json), exist_ok=True)
with open(output_json, "w") as f:
    json.dump(camera_data, f, indent=2)

print(f"[DONE] Exported camera tracking data to {output_json}")