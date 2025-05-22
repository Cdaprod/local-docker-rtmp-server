import bpy

def create_terminal_feed_plane(image_path, location=(0, 0, 0), scale=(4, 2.5, 1)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=location)
    plane = bpy.context.active_object
    plane.scale = scale

    mat = bpy.data.materials.new(name="TerminalMaterial")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")

    tex_node = mat.node_tree.nodes.new(type='ShaderNodeTexImage')
    tex_node.image = bpy.data.images.load(image_path)
    mat.node_tree.links.new(bsdf.inputs['Base Color'], tex_node.outputs['Color'])

    plane.data.materials.append(mat)
    return plane