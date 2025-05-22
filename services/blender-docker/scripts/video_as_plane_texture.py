import bpy

def create_video_plane(video_path, location=(0, 0, 0), scale=(4, 2.5, 1)):
    bpy.ops.mesh.primitive_plane_add(location=location)
    plane = bpy.context.active_object
    plane.scale = scale

    # Create new material
    mat = bpy.data.materials.new(name="VideoMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clean up default nodes
    for node in nodes:
        nodes.remove(node)

    # Add nodes
    tex_node = nodes.new(type='ShaderNodeTexImage')
    tex_node.image = bpy.data.images.load(filepath=video_path)
    tex_node.image.source = 'MOVIE'
    tex_node.image.use_auto_refresh = True

    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    output = nodes.new(type='ShaderNodeOutputMaterial')

    # Link nodes
    links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    # Assign material
    plane.data.materials.append(mat)

    return plane