# /app/jobs/load_latest_obs_clips.py
import bpy
import glob
import os

recordings = glob.glob("/mnt/b/recordings/*.mkv")
if not recordings:
    raise FileNotFoundError("No recordings found in /mnt/b/recordings")
latest = max(recordings, key=os.path.getctime)

# Add it to the video sequencer on channel 1, starting at frame 1
bpy.ops.sequencer.movie_strip_add(
    filepath=latest,
    frame_start=1,
    channel=1
)
print(f"[LOAD] Added latest clip: {latest}")