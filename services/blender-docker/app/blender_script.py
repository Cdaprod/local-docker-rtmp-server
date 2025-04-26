/path/app/blender_script.py
```python
import bpy
import sys
import os
import argparse

def hex_to_rgb(normalized_hex: str):
    """Convert '#RRGGBB' to (r, g, b) floats in [0,1]."""
    h = normalized_hex.lstrip('#')
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))

def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    parser = argparse.ArgumentParser(description="Blender composite script")
    parser.add_argument("--bg",     required=True, help="Path to background video")
    parser.add_argument("--ov",     required=True, help="Path to overlay video")
    parser.add_argument("--chroma", default="#00FF00", help="Chroma key hex color")
    parser.add_argument("--out",    required=True, help="Output render path")
    return parser.parse_args(argv)

def setup_compositor(bg_path, ov_path, chroma_color):
    scene = bpy.context.scene
    scene.use_nodes = True
    tree = scene.node_tree
    # Clear default nodes
    for n in tree.nodes:
        tree.nodes.remove(n)

    # Load clips
    bg_clip = bpy.data.movieclips.load(bg_path)
    ov_clip = bpy.data.movieclips.load(ov_path)

    # Nodes
    node_bg = tree.nodes.new(type="CompositorNodeMovieClip")
    node_bg.movie_clip = bg_clip
    node_bg.location = -400, 200

    node_ov = tree.nodes.new(type="CompositorNodeMovieClip")
    node_ov.movie_clip = ov_clip
    node_ov.location = -400, -200

    node_key = tree.nodes.new(type="CompositorNodeKeying")
    node_key.location = -200, 0
    # Set key color
    node_key.key_color = chroma_color

    node_alpha = tree.nodes.new(type="CompositorNodeAlphaOver")
    node_alpha.location = 0, 0

    node_out = tree.nodes.new(type="CompositorNodeComposite")
    node_out.location = 200, 0

    # Links
    links = tree.links
    links.new(node_bg.outputs["Image"],     node_alpha.inputs[1])
    links.new(node_ov.outputs["Image"],     node_key.inputs[1])
    links.new(node_key.outputs["Image"],    node_alpha.inputs[2])
    links.new(node_alpha.outputs["Image"],  node_out.inputs["Image"])

    # Match frames to background clip length
    scene.frame_start = 1
    scene.frame_end   = bg_clip.frame_duration

def main():
    args = parse_args()

    # Ensure output directory exists
    out_dir = os.path.dirname(args.out)
    os.makedirs(out_dir, exist_ok=True)

    # Convert chroma hex to rgb tuple
    chroma_rgb = hex_to_rgb(args.chroma)

    # Setup compositor nodes
    setup_compositor(args.bg, args.ov, chroma_rgb)

    # Render settings
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec  = "H264"
    scene.render.filepath = args.out

    # Execute the animation render
    bpy.ops.render.render(animation=True)
    print(f"[DONE] Render complete → {args.out}")

if __name__ == "__main__":
    main()