import bpy

def create_syntax_material(name, rgba):
    """Create a new emission-based material for syntax highlighting."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clear default nodes
    for node in nodes:
        nodes.remove(node)

    # Create Emission node
    emit = nodes.new(type='ShaderNodeEmission')
    emit.inputs['Color'].default_value = rgba
    emit.location = (0, 0)

    # Create Output node
    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (200, 0)

    # Link Emission to Output
    links.new(emit.outputs['Emission'], output.inputs['Surface'])

    mat.blend_method = 'BLEND'
    return mat

# Define your syntax colors here (RGBA)
SYNTAX_COLORS = {
    'keyword'  : (0.2, 0.6, 1.0, 1.0),   # blue
    'string'   : (0.9, 0.6, 0.0, 1.0),   # orange
    'comment'  : (0.4, 0.4, 0.4, 1.0),   # grey
    'default'  : (1.0, 1.0, 1.0, 1.0),   # white
    'terminal' : (0.0, 1.0, 0.2, 1.0),   # green
}

# Create materials in the blend file
for name, color in SYNTAX_COLORS.items():
    create_syntax_material(f"mat_{name}", color)

print("Syntax materials created:")
print([f"mat_{n}" for n in SYNTAX_COLORS.keys()])