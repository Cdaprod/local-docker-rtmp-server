# .../blender-docker/app/jobs/load_latest_obs_clip.py
import bpy
import glob

recordings = glob.glob("/mnt/b/recordings/*.mkv")
latest = max(recordings, key=os.path.getctime)

bpy.ops.sequencer.movie_strip_add(filepath=latest, frame_start=1, channel=1)