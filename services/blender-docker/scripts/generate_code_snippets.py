import bpy
from mathutils import Vector

# Make sure you have run setup_syntax_materials.py first

# Sample code snippet lines
code_lines = [
    "class Singleton:",
    "    _instance = None",
    "    def __new__(cls):",
    "        if not cls._instance:",
    "            cls._instance = super().__new__(cls)",
    "        return cls._instance",
    "",
    "obj1 = Singleton()",
    "obj2 = Singleton()",
    "print(obj1 is obj2)  # True",
]

# A simple syntax category detector
def pick_material_name(line):
    line = line.strip()
    if line.startswith("class") or line.startswith("def"):
        return "mat_keyword"
    if '"' in line or "'" in line:
        return "mat_string"
    if line.startswith("#") or "#" in line:
        return "mat_comment"
    return "mat_default"

# Create each text object
for i, text in enumerate(code_lines):
    bpy.ops.object.text_add()
    txt_obj = bpy.context.object
    txt_obj.name = f"CodeLine_{i:02d}"
    txt_obj.data.body = text
    txt_obj.data.extrude = 0.02
    txt_obj.data.bevel_depth = 0.002
    txt_obj.data.size = 0.3
    txt_obj.rotation_euler = (1.5708, 0, 0)  # Lay flat on X-axis
    txt_obj.location = Vector((0, -i * 0.35, 0))

    # Assign material based on syntax
    mat_name = pick_material_name(text)
    mat = bpy.data.materials.get(mat_name)
    if mat:
        txt_obj.data.materials.clear()
        txt_obj.data.materials.append(mat)

print(f"Generated {len(code_lines)} code snippet text objects.")