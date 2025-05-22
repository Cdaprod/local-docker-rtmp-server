import bpy

def setup_world_background(color=(0, 0, 0, 1), strength=1.0):
    world = bpy.context.scene.world
    world.use_nodes = True

    nodes = world.node_tree.nodes
    links = world.node_tree.links
    nodes.clear()

    bg_node = nodes.new(type='ShaderNodeBackground')
    output_node = nodes.new(type='ShaderNodeOutputWorld')

    links.new(bg_node.outputs['Background'], output_node.inputs['Surface'])

    bg_node.inputs[0].default_value = color
    bg_node.inputs[1].default_value = strength