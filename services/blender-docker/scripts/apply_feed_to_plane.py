import bpy
import os

# === USER SETTINGS ===
# Path to your terminal-feed image
IMAGE_PATH = "/absolute/path/to/your/image.png"

# Plane dimensions (to match your scene scale)
PLANE_SIZE_X = 5.0
PLANE_SIZE_Y = 3.0

# Plane location / rotation
PLANE_LOCATION = (0.0, 0.0, 0.01)  # slightly above ground
PLANE_ROTATION = (1.5708, 0.0, 0.0)  # lay flat on X-axis

# === END SETTINGS ===

# 1. Load the image
if os.path.isfile(IMAGE_PATH):
    img = bpy.data.images.load(IMAGE_PATH)
else:
    raise FileNotFoundError(f"Cannot find image at {IMAGE_PATH!r}")

# 2. Create a new material with emission + alpha
mat = bpy.data.materials.new(name="Mat_TerminalFeed")
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links

# clear default nodes
for n in nodes:
    nodes.remove(n)

# create nodes
tex_node = nodes.new(type="ShaderNodeTexImage")
tex_node.image = img
tex_node.interpolation = 'Linear'
tex_node.extension = 'REPEAT'
tex_node.location = (-300, 0)

# add a Transparent BSDF
trans_node = nodes.new(type="ShaderNodeBsdfTransparent")
trans_node.location = (0, -200)

# add an Emission shader
emit_node = nodes.new(type="ShaderNodeEmission")
emit_node.inputs["Strength"].default_value = 1.5
emit_node.location = (0, 0)

# mix Transparent + Emission via alpha
mix_node = nodes.new(type="ShaderNodeMixShader")
mix_node.location = (200, 0)

# output
out_node = nodes.new(type="ShaderNodeOutputMaterial")
out_node.location = (400, 0)

# link nodes
links.new(tex_node.outputs["Color"], emit_node.inputs["Color"])
links.new(tex_node.outputs["Alpha"], mix_node.inputs["Fac"])
links.new(emit_node.outputs["Emission"], mix_node.inputs[2])
links.new(trans_node.outputs["BSDF"], mix_node.inputs[1])
links.new(mix_node.outputs["Shader"], out_node.inputs["Surface"])

# enable transparency in material settings
mat.blend_method = 'BLEND'
mat.shadow_method = 'NONE'

# 3. Create a plane and assign the material
bpy.ops.mesh.primitive_plane_add(size=1.0, location=PLANE_LOCATION, rotation=PLANE_ROTATION)
plane = bpy.context.object
plane.name = "TerminalFeedPlane"
plane.scale.x = PLANE_SIZE_X
plane.scale.y = PLANE_SIZE_Y

# assign material
if plane.data.materials:
    plane.data.materials[0] = mat
else:
    plane.data.materials.append(mat)

# 4. Ensure UVs cover the whole plane
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.uv.reset()  
bpy.ops.object.mode_set(mode='OBJECT')

print("✅ Terminal feed plane created and textured!")