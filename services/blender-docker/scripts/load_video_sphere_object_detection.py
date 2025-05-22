import bpy
import os
import cv2
import torch
from ultralytics import YOLO
from mathutils import Vector

# === CONFIGURABLE PARAMETERS ===
VIDEO_PATH = "/path/to/your/360video.mp4"  # Replace with your video path
OUTPUT_DIR = "/tmp/blender_output"         # Directory to save outputs
SPHERE_NAME = "VideoSphere"
DETECTION_MODEL = "yolov5s.pt"             # Pre-trained YOLOv5 model

# Create output directory if it doesn't exist
os.makedirs(OUTPUT_DIR, exist_ok=True)

# === LOAD 360° VIDEO ===
def load_video_texture(video_path):
    # Create a new image texture from the video
    bpy.ops.image.open(filepath=video_path)
    video_image = bpy.data.images.load(video_path)
    video_image.source = 'MOVIE'
    video_image.use_auto_refresh = True
    return video_image

# === CREATE SPHERE AND APPLY VIDEO TEXTURE ===
def create_video_sphere(image_texture):
    # Remove existing sphere if it exists
    if SPHERE_NAME in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[SPHERE_NAME], do_unlink=True)
    
    # Create UV sphere
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=64, radius=10, location=(0, 0, 0))
    sphere = bpy.context.active_object
    sphere.name = SPHERE_NAME
    sphere.scale.x = -1  # Invert normals for interior projection

    # Create material and assign video texture
    mat = bpy.data.materials.new(name="VideoMaterial")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex_image = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex_image.image = image_texture
    tex_image.projection = 'EQUIRECTANGULAR'
    mat.node_tree.links.new(bsdf.inputs['Base Color'], tex_image.outputs['Color'])
    sphere.data.materials.append(mat)

# === SETUP CAMERA AND LIGHTING ===
def setup_scene():
    # Add camera
    bpy.ops.object.camera_add(location=(0, -10, 0), rotation=(1.5708, 0, 0))
    camera = bpy.context.active_object
    bpy.context.scene.camera = camera

    # Add light
    bpy.ops.object.light_add(type='POINT', location=(0, 0, 0))
    light = bpy.context.active_object
    light.data.energy = 1000

# === PERFORM OBJECT DETECTION AND OVERLAY RESULTS ===
def perform_detection_and_overlay(video_path, output_dir):
    # Load YOLO model
    model = YOLO(DETECTION_MODEL)

    # Capture video
    cap = cv2.VideoCapture(video_path)
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = frame_count

    frame_idx = 1
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        # Perform detection
        results = model(frame)

        # Draw detections on frame
        for result in results:
            boxes = result.boxes
            for box in boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                label = model.names[int(box.cls[0])]
                confidence = box.conf[0]
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(frame, f"{label} {confidence:.2f}", (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.9, (36,255,12), 2)

        # Save annotated frame
        frame_filename = os.path.join(output_dir, f"frame_{frame_idx:04d}.png")
        cv2.imwrite(frame_filename, frame)

        # Load annotated frame into Blender as image sequence
        if frame_idx == 1:
            bpy.ops.image.open(filepath=frame_filename, directory=output_dir, files=[{"name": os.path.basename(frame_filename)}])
            image_sequence = bpy.data.images.load(frame_filename)
            image_sequence.source = 'SEQUENCE'
            image_sequence.frame_start = 1
            image_sequence.frame_end = frame_count
            image_sequence.use_auto_refresh = True

            # Apply image sequence to a new plane in front of the camera
            bpy.ops.mesh.primitive_plane_add(size=5, location=(0, -5, 0))
            plane = bpy.context.active_object
            mat = bpy.data.materials.new(name="OverlayMaterial")
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes["Principled BSDF"]
            tex_image = mat.node_tree.nodes.new('ShaderNodeTexImage')
            tex_image.image = image_sequence
            mat.node_tree.links.new(bsdf.inputs['Base Color'], tex_image.outputs['Color'])
            plane.data.materials.append(mat)

        frame_idx += 1

    cap.release()

# === MAIN EXECUTION ===
def main():
    video_image = load_video_texture(VIDEO_PATH)
    create_video_sphere(video_image)
    setup_scene()
    perform_detection_and_overlay(VIDEO_PATH, OUTPUT_DIR)

if __name__ == "__main__":
    main()