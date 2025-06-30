import bpy

# ==================== CONFIG ====================
# Set these to your clip file names and sync marker names
hero_clip_name = "Hero"         # Name of hero strip in VSE
witness_clip_name = "Witness"   # Name of witness strip in VSE
hero_marker = "HERO"
witness_marker = "WITNESS"
# ===============================================

scene = bpy.context.scene
seq = scene.sequence_editor_create()

# === STEP 1: Clear existing strips ===
for s in seq.sequences:
    seq.sequences.remove(s)

# === STEP 2: Add video strips ===
# Assumes video files are in the same directory as the blend file
blend_dir = Path(bpy.data.filepath).parent

hero_path = str(blend_dir / "hero_clip.mp4")
witness_path = str(blend_dir / "witness_clip.mp4")

hero = seq.sequences.new_movie(name=hero_clip_name, filepath=hero_path, channel=1, frame_start=1)
witness = seq.sequences.new_movie(name=witness_clip_name, filepath=witness_path, channel=2, frame_start=1)

print(f"Added Hero: {hero_path} at frame {hero.frame_start}")
print(f"Added Witness: {witness_path} at frame {witness.frame_start}")

# === STEP 3: Fetch sync markers ===
m_w = scene.timeline_markers.get(witness_marker)
m_h = scene.timeline_markers.get(hero_marker)

if not m_w or not m_h:
    raise RuntimeError("Place timeline markers at sync points and name them 'HERO' and 'WITNESS'")

# === STEP 4: Sync witness clip by offsetting it ===
offset = m_h.frame - m_w.frame
witness.frame_start += offset

print(f"Witness strip shifted by {offset} frames to start at {witness.frame_start}")

# === STEP 5: Adjust scene range based on both clips ===
all_strips = list(seq.sequences_all)
start = min(s.frame_start for s in all_strips)
end = max(s.frame_start + s.frame_final_duration for s in all_strips)

scene.frame_start = start
scene.frame_end = end

print(f"Scene playback range set to: {start} – {end}")

# === STEP 6: Optional - Set resolution and FPS based on hero clip ===
scene.render.resolution_x = 3840
scene.render.resolution_y = 2160
scene.render.fps = 24

print("Set scene resolution to 4K and FPS to 24")
