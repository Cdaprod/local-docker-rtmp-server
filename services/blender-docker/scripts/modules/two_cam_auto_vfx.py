# /scripts/two_cam_auto_vfx.py   •   Blender 4.x+
"""
Two-Camera VFX Auto-Rig -- Insta360-aware Edition
────────────────────────────────────────────────────────────
•  Imports hero + witness plates
•  Auto-detects FPS, resolution & 360⇆rectilinear
•  Injects missing XMP → always pano-aware
•  Syncs via timeline markers  (HERO / WITNESS)
•  Auto-tracks witness plate on a feature grid
•  Iteratively cleans high-error tracks, re-solves, ≤ TARGET_ERR px
•  Builds   RigRoot ▶ WitnessCam ▶ HeroCam hierarchy
•  Adds XYZ offset drivers on RigRoot (dial real spacing)
•  Drops 3-D empties for every surviving track
•  Ping me if you’d like audio-waveform auto-sync or 3-way rigs (hero + witness + LiDAR)
"""

# ───── USER SETTINGS ─────
HERO_PATH          = r"D:\footage\hero_z7.mp4"
WITNESS_PATH       = r"D:\footage\witness_x3_360.mp4"

# Hero (Nikon Z7) optics – change lens if needed
HERO_SENSOR_MM     = 35.9       # FX width
HERO_LENS_MM       = 35         # mm of the lens you shot with

# Witness (Insta360 X3) single-lens sensor width (ignored when 360°)
WITNESS_SENSOR_MM  = 6.4

# Physical spacing of the two lenses (metres, +X→right, +Y→up, +Z→fwd)
OFFSET_X, OFFSET_Y, OFFSET_Z = 0.10, 0.00, 0.05

# Proxy resolution for the witness clip (None = off)
PROXY_SCALE        = 12.5       # 12.5 | 25 | 50 | 100

# --- Tracking quality targets ---
GRID_SPACING_PX    = 120        # distance between seed points
DETECT_THRESHOLD   = 0.15       # 0–1, lower = more features
TARGET_ERR         = 1.0        # stop when average reprojection error ≤ px
MAX_SOLVE_PASSES   = 4          # safety-valve to avoid endless loops
MIN_TRACK_LEN      = 15         # prune tracks shorter than this (frames)
# ─────────────────────────────────

import bpy, subprocess, tempfile, os
from pathlib import Path

# -----------------------------------------------------------
# 0.  Probe witness clip  (ffprobe → fallback Blender header)
# -----------------------------------------------------------
def probe_clip(path: str):
    try:
        cmd = ["ffprobe", "-v", "error",
               "-select_streams", "v:0",
               "-show_entries", "stream=width,height,r_frame_rate",
               "-of", "default=nokey=1:noprint_wrappers=1", path]
        w, h, r = subprocess.check_output(cmd, text=True).strip().splitlines()
        n, d    = map(int, r.split('/'))
        return n / d if d else float(n), int(w), int(h)
    except Exception:
        c   = bpy.data.movieclips.load(path)
        fps = c.fps / c.fps_base
        w, h = c.size
        bpy.data.movieclips.remove(c)
        return fps, w, h

FPS, WIDTH, HEIGHT = probe_clip(WITNESS_PATH)
is_360 = abs(WIDTH/HEIGHT - 2.0) < .05 or any(k in Path(WITNESS_PATH).stem.lower()
                                              for k in ("_360", "equi", "360"))
print(f"▶ Witness plate: {WIDTH}×{HEIGHT} @ {FPS:.2f} fps   ({'360°' if is_360 else 'flat'})")

# -----------------------------------------------------------
# 1.  Scene / timeline
# -----------------------------------------------------------
scn = bpy.context.scene
scn.render.fps, scn.render.fps_base = (round(FPS), 1) if FPS.is_integer() \
    else (round(FPS * 1001 / 1000), 1.001)

seq = scn.sequence_editor_create()
seq.sequences_all.clear()

hero_strip    = seq.sequences.new_movie("HeroStrip",    HERO_PATH,    2, 1)
witness_strip = seq.sequences.new_movie("WitnessStrip", WITNESS_PATH, 1, 1)

mh, mw = (scn.timeline_markers.get(k) for k in ("HERO", "WITNESS"))
if not (mh and mw):
    raise RuntimeError("Add timeline markers named HERO and WITNESS on the clap frame first.")
witness_strip.frame_start += mh.frame - mw.frame

scn.frame_start = min(hero_strip.frame_start, witness_strip.frame_start)
scn.frame_end   = max(hero_strip.frame_final_end, witness_strip.frame_final_end)
scn.frame_current = scn.frame_start

# -----------------------------------------------------------
# 2.  Restore stripped 360 XMP if needed
# -----------------------------------------------------------
def inject_xmp(src):
    xmp = (b"<x:xmpmeta xmlns:x='adobe:ns:meta/'><rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
           b"<rdf:Description xmlns:GSpherical='http://ns.google.com/videos/1.0/spherical/'>"
           b"<GSpherical:Spherical>true</GSpherical:Spherical>"
           b"<GSpherical:Stitched>true</GSpherical:Stitched>"
           b"<GSpherical:ProjectionType>equirectangular</GSpherical:ProjectionType>"
           b"</rdf:Description></rdf:RDF></x:xmpmeta>")
    tmp = Path(tempfile.mkstemp(suffix=Path(src).suffix)[1])
    with open(src, 'rb') as fi, open(tmp, 'wb') as fo:
        data = fi.read()
        moov = data.find(b"moov")
        fo.write(data[:moov-4] + b"\0\0\0\0uuid" + xmp + data[moov-4:])
    return str(tmp)

witness_src = inject_xmp(WITNESS_PATH) if is_360 else WITNESS_PATH

# -----------------------------------------------------------
# 3.  Track, clean, re-solve loop
# -----------------------------------------------------------
clip = bpy.data.movieclips.load(witness_src)
clip.tracking.camera.sensor_width = WITNESS_SENSOR_MM
clip.tracking.settings.use_normalization = True

if is_360:
    clip.tracking.camera.type = 'EQUIRECTANGULAR'
    clip.tracking.camera.focal_length = 1.0    # 180 ° FOV
else:
    clip.tracking.camera.type = 'PERSP'
    clip.tracking.camera.focal_length = 8.0    # flat X3 export default

if PROXY_SCALE:
    clip.proxy.build_25  = PROXY_SCALE in {25, 12.5}
    clip.proxy.build_50  = PROXY_SCALE == 50
    clip.proxy.build_100 = PROXY_SCALE == 100
    clip.proxy.build_12  = getattr(clip.proxy, "build_12", False) and PROXY_SCALE == 12.5
    bpy.ops.clip.rebuild_proxy()

# find a CLIP_EDITOR for context overrides
area = next(a for a in bpy.context.window.screen.areas if a.type == 'CLIP_EDITOR')
override = bpy.context.copy(); override['area'] = area; override['space_data'] = area.spaces.active
override['clip'] = clip

with bpy.context.temp_override(**override):
    # ---- seed a grid of features on frame 1 ----
    bpy.context.scene.frame_set(scn.frame_start)
    bpy.ops.clip.detect_features(placement='FRAME',
                                 margin=16,
                                 threshold=DETECT_THRESHOLD,
                                 min_distance=GRID_SPACING_PX)
    # ---- track forward for full shot ----
    bpy.ops.clip.track_markers(backwards=False)

    # ---- iterative clean → re-solve loop ----
    for i in range(1, MAX_SOLVE_PASSES + 1):
        bpy.ops.clip.solve_camera(refine_intrinsics={'FOCAL_LENGTH','RADIAL_DISTORTION'})
        err = clip.tracking.reconstruction.average_error   #  [oai_citation:0‡docs.blender.org](https://docs.blender.org/api/current/bpy.types.MovieTrackingReconstruction.html?utm_source=chatgpt.com)
        print(f"  • Solve pass {i}:  RMS error = {err:.3f} px")
        if err <= TARGET_ERR:
            break
        # delete tracks shorter than MIN_TRACK_LEN or with high repro error
        bpy.ops.clip.clean_tracks(frames=MIN_TRACK_LEN, error=err*1.1, action='DELETE_TRACK')  #  [oai_citation:1‡docs.blender.org](https://docs.blender.org/api/current/bpy.ops.clip.html?utm_source=chatgpt.com)
        if not clip.tracking.tracks:
            raise RuntimeError("All tracks deleted -- try lowering DETECT_THRESHOLD or TARGET_ERR.")
    else:
        print(f"⚠  Reached {MAX_SOLVE_PASSES} passes; RMS error still {err:.2f}px")

    # finalize: create camera object from solve
    bpy.ops.clip.camera_from_tracking()

witness_cam = bpy.context.object
witness_cam.name = "WitnessCam"
witness_cam.data.type = 'PANO' if is_360 else 'PERSP'

# -----------------------------------------------------------
# 4.  Rig root + hero cam (Nikon Z7)
# -----------------------------------------------------------
rig = bpy.data.objects.new("RigRoot", None); scn.collection.objects.link(rig)
witness_cam.parent = rig

hero_cam = bpy.data.objects.get("HeroCam")
if not hero_cam:
    hero_cam = bpy.data.objects.new("HeroCam", bpy.data.cameras.new("HeroCam_Data"))
    scn.collection.objects.link(hero_cam)
hero_cam.parent = rig

hero_cam.data.sensor_width = HERO_SENSOR_MM
hero_cam.data.lens         = HERO_LENS_MM

for axis, off in zip("XYZ", (OFFSET_X, OFFSET_Y, OFFSET_Z)):
    pname = f"offset_{axis}"
    rig[pname] = off
    rig["_RNA_UI"] = rig.get("_RNA_UI", {}); rig["_RNA_UI"][pname] = {"min": -1, "max": 1}
    fcu = hero_cam.driver_add("location", "XYZ".index(axis))
    d   = fcu.driver; d.expression = f"var + Rig.{pname}"
    var = d.variables.new(); var.name = "var"; var.type = 'TRANSFORMS'
    var.targets[0].id = witness_cam
    var.targets[0].transform_type = f'LOC_{axis}'

# -----------------------------------------------------------
# 5.  Spawn empties for every surviving track
# -----------------------------------------------------------
for tr in clip.tracking.tracks:
    if not tr.has_bundle:
        continue
    empty = bpy.data.objects.new(f"trk_{tr.name}", None)
    empty.empty_display_size = 0.06
    scn.collection.objects.link(empty)
    empty.parent   = witness_cam
    empty.location = tr.bundle

scn.camera = hero_cam
print(f"✅  Rig ready • {len([t for t in clip.tracking.tracks if t.has_bundle])} anchors • RMS error {clip.tracking.reconstruction.average_error:.3f}px")
"""
🛠 Quick-start

1.  Open Blender 4.x ➜ Scripting
2.  Paste script → tweak HERO_PATH / WITNESS_PATH / OFFSETS.
3.  Scrub each strip, press M, name one marker HERO, the other WITNESS.
4.  Run ▶  Blender does the rest (import ⇢ sync ⇢ track ⇢ solve ⇢ rig).
5.  Parent text, planes, particles to any "trk_*" empty – motion is locked.
""" 
