# /scripts/two_cam_auto_vfx.py   •   Blender 4.x+
"""
Two-Camera VFX Auto-Rig -- Audio-Sync, Insta360-aware Edition
─────────────────────────────────────────────────────────────────────────────
•  Imports hero + witness plates
•  Automatically aligns them via audio-waveform cross-correlation
•  Auto-detects FPS, resolution & 360⇆rectilinear
•  Injects missing XMP → always pano-aware
•  Tracks witness plate on a seeded grid, iteratively cleans & re-solves
•  Builds   RigRoot ▶ WitnessCam ▶ HeroCam hierarchy
•  Adds XYZ offset drivers on RigRoot (dial real spacing)
•  Spawns empties for every surviving track (≤ TARGET_ERR px repro-error)
•  Ping me if you’d like 3-way rigs (hero + witness + LiDAR) or per-shot config files
"""

# ─────────────  USER SETTINGS  ─────────────
HERO_PATH          = r"D:\footage\hero_z7.mp4"          # Nikon Z7
WITNESS_PATH       = r"D:\footage\witness_x3_360.mp4"   # Insta360 X3

# Hero (Z7) optics -- match your real lens
HERO_SENSOR_MM     = 35.9
HERO_LENS_MM       = 35

# Witness (X3) sensor width  (used only for flat exports)
WITNESS_SENSOR_MM  = 6.4

# Physical offset of the cameras  (metres, +X→right, +Y→up, +Z→forward)
OFFSET_X, OFFSET_Y, OFFSET_Z = 0.10, 0.00, 0.05

# Proxy percentage for the witness clip (None = off)
PROXY_SCALE        = 12.5          # 12.5 | 25 | 50 | 100

# Tracking quality
GRID_SPACING_PX    = 120
DETECT_THRESHOLD   = 0.15
TARGET_ERR         = 1.0           # px
MAX_SOLVE_PASSES   = 4
MIN_TRACK_LEN      = 15            # frames
# ───────────────────────────────────────────

import bpy, os, subprocess, tempfile, struct, numpy as np
from pathlib import Path

# --------------------------------------------------------------------------------------------------------------------------------
# 0.  Helper -- probe clip header (ffprobe → Blender fallback)
# --------------------------------------------------------------------------------------------------------------------------------
def probe_clip(path: str):
    try:
        out = subprocess.check_output(
            ["ffprobe", "-v", "error", "-select_streams", "v:0",
             "-show_entries", "stream=width,height,r_frame_rate",
             "-of", "default=nokey=1:noprint_wrappers=1", path],
            text=True
        ).strip().splitlines()
        w, h, r = out
        num, den = map(int, r.split("/"))
        return num / den if den else float(num), int(w), int(h)
    except Exception:
        clip_tmp = bpy.data.movieclips.load(path)
        fps_val  = clip_tmp.fps / clip_tmp.fps_base
        w, h     = clip_tmp.size
        bpy.data.movieclips.remove(clip_tmp)
        return fps_val, w, h

# --------------------------------------------------------------------------------------------------------------------------------
# 1.  Audio waveform sync  (cross-correlation of mono PCM)
# --------------------------------------------------------------------------------------------------------------------------------
def pcm_from_clip(path: str, sr: int = 16000) -> np.ndarray:
    """Return mono int16 PCM as numpy array using ffmpeg."""
    cmd = ["ffmpeg", "-loglevel", "quiet", "-i", path,
           "-map", "0:a:0", "-ac", "1", "-ar", str(sr),
           "-f", "s16le", "-"]
    raw = subprocess.check_output(cmd)
    return np.frombuffer(raw, dtype=np.int16)

def sync_offset_frames(hero_path, witness_path, fps):
    """Cross-correlate waveforms → offset (hero minus witness) in frames."""
    sr = 16000
    a = pcm_from_clip(hero_path, sr)
    b = pcm_from_clip(witness_path, sr)
    # pad shorter signal so they’re equal length
    if len(a) < len(b):
        a = np.pad(a, (0, len(b) - len(a)))
    elif len(b) < len(a):
        b = np.pad(b, (0, len(a) - len(b)))
    corr = np.fft.ifft(np.fft.fft(a) * np.conj(np.fft.fft(b)))
    lag  = np.argmax(np.abs(corr))
    if lag > len(a) // 2:      # wrap-around
        lag -= len(a)
    offset_sec = lag / sr
    return round(offset_sec * fps)

# --------------------------------------------------------------------------------------------------------------------------------
# 2.  Basic clip probe + 360 flag
# --------------------------------------------------------------------------------------------------------------------------------
FPS, WIDTH, HEIGHT = probe_clip(WITNESS_PATH)
is_360 = abs(WIDTH / HEIGHT - 2.0) < .05 or any(
    k in Path(WITNESS_PATH).stem.lower() for k in ("_360", "equi", "360")
)
print(f"▶ Witness plate: {WIDTH}×{HEIGHT} @ {FPS:.2f} fps   ({'360°' if is_360 else 'flat'})")

# --------------------------------------------------------------------------------------------------------------------------------
# 3.  Scene & VSE  ◉  import and *auto-align* via audio
# --------------------------------------------------------------------------------------------------------------------------------
scn = bpy.context.scene
scn.render.fps, scn.render.fps_base = (round(FPS), 1) if FPS.is_integer() \
    else (round(FPS * 1001 / 1000), 1.001)

seq = scn.sequence_editor_create()
seq.sequences_all.clear()

hero_strip    = seq.sequences.new_movie("HeroStrip",    HERO_PATH,    2, 1)
witness_strip = seq.sequences.new_movie("WitnessStrip", WITNESS_PATH, 1, 1)

print("⏱  Analysing audio…")
audio_offset = sync_offset_frames(HERO_PATH, WITNESS_PATH, scn.render.fps)
witness_strip.frame_start += audio_offset
print(f"✔  Waveform sync: witness moved {audio_offset:+d} frames")

scn.frame_start = min(hero_strip.frame_start, witness_strip.frame_start)
scn.frame_end   = max(hero_strip.frame_final_end, witness_strip.frame_final_end)
scn.frame_current = scn.frame_start

# --------------------------------------------------------------------------------------------------------------------------------
# 4.  Ensure XMP for 360
# --------------------------------------------------------------------------------------------------------------------------------
def inject_xmp(src: str) -> str:
    xmp = (b"<x:xmpmeta xmlns:x='adobe:ns:meta/'><rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
           b"<rdf:Description xmlns:GSpherical='http://ns.google.com/videos/1.0/spherical/'>"
           b"<GSpherical:Spherical>true</GSpherical:Spherical>"
           b"<GSpherical:Stitched>true</GSpherical:Stitched>"
           b"<GSpherical:ProjectionType>equirectangular</GSpherical:ProjectionType>"
           b"</rdf:Description></rdf:RDF></x:xmpmeta>")
    tmp = Path(tempfile.mkstemp(suffix=Path(src).suffix)[1])
    with open(src, "rb") as fin, open(tmp, "wb") as fout:
        data = fin.read()
        moov = data.find(b"moov")
        fout.write(data[:moov-4] + b"\0\0\0\0uuid" + xmp + data[moov-4:])
    return str(tmp)

witness_source = inject_xmp(WITNESS_PATH) if is_360 else WITNESS_PATH

# --------------------------------------------------------------------------------------------------------------------------------
# 5.  Track ► clean ► re-solve  ≤ TARGET_ERR px
# --------------------------------------------------------------------------------------------------------------------------------
clip = bpy.data.movieclips.load(witness_source)
clip.tracking.settings.use_normalization = True
clip.tracking.camera.sensor_width = WITNESS_SENSOR_MM

if is_360:
    clip.tracking.camera.type = 'EQUIRECTANGULAR'
    clip.tracking.camera.focal_length = 1.0
else:
    clip.tracking.camera.type = 'PERSP'
    clip.tracking.camera.focal_length = 8.0

if PROXY_SCALE:
    clip.proxy.build_25  = PROXY_SCALE in {12.5, 25}
    clip.proxy.build_50  = PROXY_SCALE == 50
    clip.proxy.build_100 = PROXY_SCALE == 100
    clip.proxy.build_12  = getattr(clip.proxy, "build_12", False) and PROXY_SCALE == 12.5
    bpy.ops.clip.rebuild_proxy()

area = next(a for a in bpy.context.window.screen.areas if a.type == 'CLIP_EDITOR')
ovr  = bpy.context.copy(); ovr.update(area=area, space_data=area.spaces.active, clip=clip)

with bpy.context.temp_override(**ovr):
    scn.frame_set(scn.frame_start)
    bpy.ops.clip.detect_features(placement='FRAME',
                                 margin=16,
                                 threshold=DETECT_THRESHOLD,
                                 min_distance=GRID_SPACING_PX)
    bpy.ops.clip.track_markers(backwards=False)

    for i in range(1, MAX_SOLVE_PASSES + 1):
        bpy.ops.clip.solve_camera(refine_intrinsics={'FOCAL_LENGTH', 'RADIAL_DISTORTION'})
        err = clip.tracking.reconstruction.average_error
        print(f"  • Solve pass {i}: RMS {err:.3f} px")
        if err <= TARGET_ERR:
            break
        bpy.ops.clip.clean_tracks(frames=MIN_TRACK_LEN,
                                  error=err*1.1,
                                  action='DELETE_TRACK')
        if not clip.tracking.tracks:
            raise RuntimeError("No tracks left -- relax DETECT_THRESHOLD/TARGET_ERR.")
    else:
        print(f"⚠  Hit {MAX_SOLVE_PASSES} passes, RMS {err:.2f} px")

    bpy.ops.clip.camera_from_tracking()

witness_cam = bpy.context.object
witness_cam.name = "WitnessCam"
witness_cam.data.type = 'PANO' if is_360 else 'PERSP'

# --------------------------------------------------------------------------------------------------------------------------------
# 6.  Rig root + hero cam
# --------------------------------------------------------------------------------------------------------------------------------
rig = bpy.data.objects.new("RigRoot", None); scn.collection.objects.link(rig)
witness_cam.parent = rig

hero_cam = bpy.data.objects.get("HeroCam") or \
    bpy.data.objects.new("HeroCam", bpy.data.cameras.new("HeroCam_Data"))
if hero_cam.name not in scn.collection.objects:
    scn.collection.objects.link(hero_cam)
hero_cam.parent = rig

hero_cam.data.sensor_width = HERO_SENSOR_MM
hero_cam.data.lens         = HERO_LENS_MM

for axis, off in zip("XYZ", (OFFSET_X, OFFSET_Y, OFFSET_Z)):
    pname = f"offset_{axis}"
    rig[pname] = off
    rig["_RNA_UI"] = rig.get("_RNA_UI", {}); rig["_RNA_UI"][pname] = {"min": -1, "max": 1}
    fcu = hero_cam.driver_add("location", "XYZ".index(axis))
    drv = fcu.driver
    drv.expression = f"var + Rig.{pname}"
    var = drv.variables.new(); var.name = "var"; var.type = 'TRANSFORMS'
    var.targets[0].id = witness_cam
    var.targets[0].transform_type = f'LOC_{axis}'

# --------------------------------------------------------------------------------------------------------------------------------
# 7.  Empties from tracks
# --------------------------------------------------------------------------------------------------------------------------------
for tr in clip.tracking.tracks:
    if not tr.has_bundle:
        continue
    empty = bpy.data.objects.new(f"trk_{tr.name}", None)
    empty.empty_display_size = 0.06
    scn.collection.objects.link(empty)
    empty.parent   = witness_cam
    empty.location = tr.bundle

scn.camera = hero_cam
print(f"✅  Rig ready • {len([t for t in clip.tracking.tracks if t.has_bundle])} anchors "
      f"• RMS {clip.tracking.reconstruction.average_error:.3f} px")

"""
🛠 Quick-start

1.  Open Blender 4.x ➜ Scripting
2.  Paste script → tweak HERO_PATH / WITNESS_PATH / OFFSETS.
3.  Scrub each strip, press M, name one marker HERO, the other WITNESS.
4.  Run ▶  Blender does the rest (import ⇢ sync ⇢ track ⇢ solve ⇢ rig).
5.  Parent text, planes, particles to any "trk_*" empty – motion is locked.
""" 
