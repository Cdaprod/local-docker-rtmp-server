# /app/jobs/generate_ui_tracking_data.py
import bpy
import json
import os

# CONFIG -- mount your YOLO+DeepSORT output here:
tracking_json = "/mnt/b/app/exports/shot001_ui_tracking.json"
output_json = "/mnt/b/app/exports/shot001_ui_keyframes.json"

# Clear scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Load your precomputed tracking data
with open(tracking_json) as f:
    data = json.load(f)

# Map of object_id → Blender object
obj_map = {}

for frame_info in data:
    frame = frame_info["frame"]
    for det in frame_info["objects"]:
        oid = det["id"]
        x, y, w, h = det["bbox"]

        if oid not in obj_map:
            bpy.ops.mesh.primitive_plane_add(size=1)
            plane = bpy.context.active_object
            plane.name = oid
            # extrude for thickness
            mod = plane.modifiers.new("solidify", "SOLIDIFY")
            mod.thickness = 0.02
            obj_map[oid] = plane

        plane = obj_map[oid]
        # position & scale (normalize as needed)
        plane.location = (x/100, y/100, det.get("z", 0.1))
        plane.scale = (w/100, h/100, 1)

        # keyframe
        plane.keyframe_insert(data_path="location", frame=frame)
        plane.keyframe_insert(data_path="scale",    frame=frame)

# Optionally, export a summary of keyframes
os.makedirs(os.path.dirname(output_json), exist_ok=True)
with open(output_json, "w") as f:
    json.dump(
        [{"id": oid, "keyframes": [
            {"frame": f, 
             "loc": list(obj_map[oid].animation_data.action.fcurves[0].keyframe_points.values())
            } for f in data
        ]} for oid in obj_map],
        f, indent=2
)
print(f"[DONE] UI keyframes generated → {output_json}")