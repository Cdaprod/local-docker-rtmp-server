blender_script.py

What this does:
	1.	Parses --bg, --ov, --chroma, and --out from the Blender command line.
	2.	Clears any existing compositor nodes and builds a new node tree:
	•	Loads your background and overlay clips.
	•	Applies a Keying node to remove the chroma color.
	•	Alpha Over to composite the keyed overlay atop the background.
	•	Composite node for final output.
	3.	Configures render settings to use H.264 in an FFMPEG container.
	4.	Renders the full frame range (matching your background clip length) to args.out.

You can now call it exactly as your render.py does:

```bash
blender --background --python app/blender_script.py -- \
   --bg /mnt/b/assets/input/xxx_bg.mov \
   --ov /mnt/b/assets/input/yyy_ov.mov \
   --chroma "#00FF00" \
   --out /mnt/b/app/exports/final.mp4
``` 