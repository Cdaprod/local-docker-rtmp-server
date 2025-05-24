import bpy
import json
import os

# Set render engine to Eevee and enable bloom for glow effects
bpy.context.scene.render.engine = 'BLENDER_EEVEE'
bpy.context.scene.eevee.use_bloom = True

# Load detection data
script_dir = os.path.dirname(bpy.data.filepath)
json_path = os.path.join(script_dir, 'detection_data.json')

with open(json_path) as f:
    data = json.load(f)

# Create materials
def create_emission_material(name, color, alpha=1.0, strength=5.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clear default nodes
    for node in nodes:
        nodes.remove(node)

    # Create nodes
    output = nodes.new(type='ShaderNodeOutputMaterial')
    emission = nodes.new(type='ShaderNodeEmission')
    transparent = nodes.new(type='ShaderNodeBsdfTransparent')
    mix_shader = nodes.new(type='ShaderNodeMixShader')

    # Set node properties
    emission.inputs['Color'].default_value = (*color, 1)
    emission.inputs['Strength'].default_value = strength
    mix_shader.inputs['Fac'].default_value = 1 - alpha

    # Link nodes
    links.new(emission.outputs['Emission'], mix_shader.inputs[2])
    links.new(transparent.outputs['BSDF'], mix_shader.inputs[1])
    links.new(mix_shader.outputs['Shader'], output.inputs['Surface'])

    # Enable transparency
    mat.blend_method = 'BLEND'
    mat.shadow_method = 'NONE'

    return mat

dialog_material = create_emission_material('DialogMaterial', (0.0, 1.0, 0.0), alpha=0.5, strength=5.0)
line_material = create_emission_material('LineMaterial', (1.0, 1.0, 1.0), alpha=1.0, strength=5.0)
smoke_material = create_emission_material('SmokeMaterial', (0.5, 0.5, 1.0), alpha=0.3, strength=2.0)

# Function to create a dialog box
def create_dialog_box(location, label):
    bpy.ops.mesh.primitive_plane_add(size=0.5, location=location)
    dialog = bpy.context.active_object
    dialog.name = f"Dialog_{label}"
    dialog.data.materials.append(dialog_material)

    # Add text
    bpy.ops.object.text_add(location=(location[0], location[1], location[2] + 0.1))
    text_obj = bpy.context.active_object
    text_obj.data.body = label
    text_obj.data.size = 0.2
    text_obj.name = f"Label_{label}"
    text_obj.parent = dialog

    return dialog

# Function to create a connecting line
def create_line(start, end, label):
    bpy.ops.curve.primitive_bezier_curve_add()
    curve = bpy.context.active_object
    curve.name = f"Line_{label}"
    curve.data.bevel_depth = 0.01
    curve.data.materials.append(line_material)

    # Set points
    p0 = curve.data.splines[0].bezier_points[0]
    p1 = curve.data.splines[0].bezier_points[1]
    p0.co = start
    p1.co = end
    p0.handle_right_type = p1.handle_left_type = 'AUTO'

    return curve

# Function to create glowing smoke
def create_smoke(location, label):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=location)
    smoke = bpy.context.active_object
    smoke.name = f"Smoke_{label}"
    smoke.data.materials.append(smoke_material)
    return smoke

# Create camera
bpy.ops.object.camera_add(location=(0, -5, 5), rotation=(1.1, 0, 0))
camera = bpy.context.active_object
bpy.context.scene.camera = camera

# Process each detected object
for obj in data['objects']:
    label = obj['label']
    position = (obj['x'], obj['y'], obj['z'])

    # Create empty as marker
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=position)
    marker = bpy.context.active_object
    marker.name = f"Marker_{label}"

    # Create dialog box offset above the marker
    dialog_location = (position[0], position[1], position[2] + 1.0)
    dialog = create_dialog_box(dialog_location, label)

    # Create connecting line
    create_line(position, dialog_location, label)

    # Create smoke effect
    create_smoke(position, label)

    # Animate dialog box appearance
    dialog.scale = (0, 0, 0)
    dialog.keyframe_insert(data_path="scale", frame=1)
    dialog.scale = (1, 1, 1)
    dialog.keyframe_insert(data_path="scale", frame=20)

# Set render settings
scene = bpy.context.scene
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.film_transparent = True
scene.frame_start = 1
scene.frame_end = 100