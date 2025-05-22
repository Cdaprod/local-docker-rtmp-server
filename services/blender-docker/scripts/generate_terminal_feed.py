import bpy
from mathutils import Vector

# Sample terminal output lines
terminal_lines = [
    "$ python main.py",
    "[INFO] Starting service...",
    "[OK] Connected to database",
    "[WARN] Low disk space",
    "[INFO] Request completed: 200 OK",
    '$ echo "Skate and create!"',
    "Skate and create!",
]

# Create the terminal feed text
for i, text in enumerate(terminal_lines):
    bpy.ops.object.text_add()
    txt_obj = bpy.context.object
    txt_obj.name = f"TermLine_{i:02d}"
    txt_obj.data.body = text
    txt_obj.data.extrude = 0.015
    txt_obj.data.bevel_depth = 0.001
    txt_obj.data.size = 0.28
    txt_obj.rotation_euler = (1.5708, 0, 0)  # Lay flat
    txt_obj.location = Vector((2.0, -i * 0.30, 0))  # Offset to the right

    # Assign terminal material
    mat = bpy.data.materials.get("mat_terminal")
    if mat:
        txt_obj.data.materials.clear()
        txt_obj.data.materials.append(mat)

print(f"Generated {len(terminal_lines)} terminal feed text objects.")