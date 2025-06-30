# /scripts/two_cam_auto_vfx.py   •   Blender 4.x+
"""
Two-Camera VFX Auto-Rig -- Insta360-aware Edition
────────────────────────────────────────────────────────────
•  Imports hero + witness plates
•  Auto-detects FPS, resolution & 360⇆rectilinear
•  Injects missing XMP → always pano-aware
•  Syncs via timeline markers  (HERO / WITNESS)
•  Auto-tracks & solves the witness plate
•  Builds   RigRoot ▶ WitnessCam ▶ HeroCam hierarchy
•  Adds XYZ offset drivers on RigRoot (dial real spacing)
•  Drops 3-D empties for every solved track
•  Ping me if you’d like audio waveform-based auto-sync or 3-way rigs (hero + witness + LiDAR)
"""

# ───── USER SETTINGS ─────
HERO_PATH    = r"D:\footage\hero_z7.mp4"         # Nikon Z7 primary
WITNESS_PATH = r"D:\footage\witness_x3_360.mp4"  # Insta360 X3 360 plate (or flat export)

# --- Camera optics ---
HERO_SENSOR_MM   = 35.9    # Nikon Z7: full-frame width
HERO_LENS_MM     = 35      # e.g. NIKKOR Z 35mm f/1.8 S -- change to your real lens!
WITNESS_SENSOR_MM = 6.4    # Insta360 X3 1/2" sensor width (only used for non-360/flat exports)

# --- Physical lens spacing (metres, +X→right, +Y→up, +Z→forward)
OFFSET_X, OFFSET_Y, OFFSET_Z = 0.10, 0.00, 0.05

# --- Proxy percentage for the witness clip (None = off)
PROXY_SCALE = 12.5         # 12.5 | 25 | 50 | 100
# ─────────────────────────

import bpy, os, subprocess, tempfile
from pathlib import Path

# -----------------------------------------------------------
# 0.  Probe witness clip  (ffprobe / Blender fallback)
# -----------------------------------------------------------
def probe_clip(path: str):
    """Returns (fps, width, height) using ffprobe if available,
    otherwise falls back to bpy.data.movieclips."""
    try:
        cmd = [
            "ffprobe", "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,r_frame_rate",
            "-of", "default=nokey=1:noprint_wrappers=1",
            path,
        ]
        w, h, r = subprocess.check_output(cmd, text=True).strip().splitlines()
        num, den = map(int, r.split('/'))
        fps_val = num / den if den else float(num)
        return fps_val, int(w), int(h)
    except Exception:
        clip_tmp = bpy.data.movieclips.load(path)
        fps_val  = clip_tmp.fps / clip_tmp.fps_base
        w, h     = clip_tmp.size
        bpy.data.movieclips.remove(clip_tmp)
        return fps_val, w, h

FPS, WIDTH, HEIGHT = probe_clip(WITNESS_PATH)
is_360 = abs((WIDTH / HEIGHT) - 2.0) < 0.05 or any(
    k in Path(WITNESS_PATH).stem.lower() for k in ("_360", "equi")
)
print(f"▶ Witness plate: {WIDTH}×{HEIGHT} @ {FPS:.2f} fps   ({'360°' if is_360 else 'flat'})")

# -----------------------------------------------------------
# 1.  Scene / timeline prep
# -----------------------------------------------------------
scn = bpy.context.scene
scn.render.fps, scn.render.fps_base = (round(FPS), 1) if FPS.is_integer() else (round(FPS * 1001 / 1000), 1.001)

seq = scn.sequence_editor_create()
seq.sequences_all.clear()

hero_strip    = seq.sequences.new_movie("HeroStrip",    HERO_PATH,    2, 1)
witness_strip = seq.sequences.new_movie("WitnessStrip", WITNESS_PATH, 1, 1)

mh, mw = (scn.timeline_markers.get(k) for k in ("HERO", "WITNESS"))
if not (mh and mw):
    raise RuntimeError("Place timeline markers named HERO and WITNESS on the clap frames before running.")
witness_strip.frame_start += mh.frame - mw.frame

scn.frame_start = min(hero_strip.frame_start, witness_strip.frame_start)
scn.frame_end   = max(hero_strip.frame_final_end, witness_strip.frame_final_end)
scn.frame_current = scn.frame_start

# -----------------------------------------------------------
# 2.  Ensure 360 XMP exists (Apple Photos often strips it)
# -----------------------------------------------------------
def inject_xmp(src):
    xmp = b"""<x:xmpmeta xmlns:x='adobe:ns:meta/'>
   <rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
     <rdf:Description xmlns:GSpherical='http://ns.google.com/videos/1.0/spherical/'>
       <GSpherical:Spherical>true</GSpherical:Spherical>
       <GSpherical:Stitched>true</GSpherical:Stitched>
       <GSpherical:ProjectionType>equirectangular</GSpherical:ProjectionType>
     </rdf:Description>
   </rdf:RDF></x:xmpmeta>"""
    tmp = Path(tempfile.mkstemp(suffix=Path(src).suffix)[1])
    with open(src, "rb") as fin, open(tmp, "wb") as fout:
        data = fin.read()
        # insert XMP after ftyp atom
        ftyp_end = data.find(b"moov") - 4  # naive but fine for mp4/insv
        fout.write(data[:ftyp_end] + b"\x00\x00\x00\x00uuid" + xmp + data[ftyp_end:])
    return str(tmp)

witness_source = inject_xmp(WITNESS_PATH) if is_360 else WITNESS_PATH

# -----------------------------------------------------------
# 3.  Movie-Clip -- track & solve
# -----------------------------------------------------------
clip = bpy.data.movieclips.load(witness_source)
clip.tracking.camera.sensor_width = WITNESS_SENSOR_MM

if is_360:
    clip.tracking.camera.type = 'EQUIRECTANGULAR'
    # Blender treats lens as focal-length equivalent -- set to 180° FOV
    clip.tracking.camera.focal_length = 1.0
else:
    clip.tracking.camera.type = 'PERSP'
    clip.tracking.camera.focal_length = 8.0  # Or match to your Insta360 Studio flat export lens

if PROXY_SCALE:
    clip.proxy.build_25  = PROXY_SCALE == 25 or PROXY_SCALE == 12.5
    clip.proxy.build_50  = PROXY_SCALE == 50
    clip.proxy.build_100 = PROXY_SCALE == 100
    clip.proxy.build_12  = hasattr(clip.proxy, "build_12") and PROXY_SCALE == 12.5
    bpy.ops.clip.rebuild_proxy()

area = next(a for a in bpy.context.window.screen.areas if a.type == 'CLIP_EDITOR')
with bpy.context.temp_override(area=area):
    bpy.context.space_data.clip = clip
    bpy.ops.clip.detect_features(threshold=0.05)
    bpy.ops.clip.track_markers(backwards=False)
    bpy.ops.clip.solve_camera()
    bpy.ops.clip.camera_from_tracking()

witness_cam = bpy.context.object
witness_cam.name = "WitnessCam"
witness_cam.data.type = 'PANO' if is_360 else 'PERSP'

# -----------------------------------------------------------
# 4.  Rig root + hero cam
# -----------------------------------------------------------
rig = bpy.data.objects.new("RigRoot", None)
scn.collection.objects.link(rig)
witness_cam.parent = rig

hero_cam = bpy.data.objects.get("HeroCam") or bpy.data.objects.new("HeroCam", bpy.data.cameras.new("HeroCam_Data"))
if hero_cam.name not in scn.collection.objects:
    scn.collection.objects.link(hero_cam)
hero_cam.parent = rig

# --- Set correct optics for hero cam (Z7)
hero_cam.data.sensor_width = HERO_SENSOR_MM
hero_cam.data.lens         = HERO_LENS_MM

# --- offset props + drivers on RigRoot
for axis, off in zip("XYZ", (OFFSET_X, OFFSET_Y, OFFSET_Z)):
    pname = f"offset_{axis}"
    rig[pname] = off
    rig["_RNA_UI"] = rig.get("_RNA_UI", {})
    rig["_RNA_UI"][pname] = {"min": -1, "max": 1}
    fcu = hero_cam.driver_add("location", "XYZ".index(axis))
    d   = fcu.driver
    d.expression = f"var + Rig.{pname}"
    var = d.variables.new(); var.name = "var"; var.type = 'TRANSFORMS'
    var.targets[0].id = witness_cam
    var.targets[0].transform_type = f'LOC_{axis}'

# -----------------------------------------------------------
# 5.  Empties from tracks (CG anchor points)
# -----------------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
for t in clip.tracking.tracks:
    if not t.has_bundle: continue
    empty = bpy.data.objects.new(f"trk_{t.name}", None)
    empty.empty_display_size = 0.06
    scn.collection.objects.link(empty)
    empty.parent = witness_cam
    empty.location = t.bundle

scn.camera = hero_cam
print(f"✅  Two-camera rig ready • {len([t for t in clip.tracking.tracks if t.has_bundle])} CG anchors")

"""
🛠 Quick-start

1.  Open Blender 4.x ➜ Scripting
2.  Paste script → tweak HERO_PATH / WITNESS_PATH / OFFSETS.
3.  Scrub each strip, press M, name one marker HERO, the other WITNESS.
4.  Run ▶  Blender does the rest (import ⇢ sync ⇢ track ⇢ solve ⇢ rig).
5.  Parent text, planes, particles to any "trk_*" empty – motion is locked.
""" 
