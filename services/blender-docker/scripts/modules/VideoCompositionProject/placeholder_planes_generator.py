import bpy

def create_placeholder_plane(name, size=(1, 1), location=(0, 0, 0), color=(0.1, 0.1, 0.1, 1.0)):
    # Create plane
    bpy.ops.mesh.primitive_plane_add(size=1, location=location)
    plane = bpy.context.active_object
    plane.name = name
    plane.scale.x = size[0]
    plane.scale.y = size[1]

    # Create material
    mat = bpy.data.materials.new(name=f"{name}_Material")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs['Base Color'].default_value = color
    plane.data.materials.append(mat)
    
    return plane

# Example scene setup
create_placeholder_plane("Garage", size=(4, 3), location=(0, 0, 0), color=(0.3, 0.3, 0.3, 1))
create_placeholder_plane("Driveway", size=(4, 3), location=(0, 4, 0), color=(0.2, 0.2, 0.2, 1))
create_placeholder_plane("Street", size=(6, 4), location=(0, 8, 0), color=(0.1, 0.1, 0.1, 1))
create_placeholder_plane("TerminalFeed", size=(6, 4), location=(0, 8, 0.01), color=(0.0, 1.0, 0.2, 0.2))  # Slight z offset and transparency

def label_plane(obj, label_text):
    bpy.ops.object.text_add(location=obj.location)
    txt = bpy.context.active_object
    txt.data.body = label_text
    txt.scale = (0.3, 0.3, 0.3)
    txt.location.z += 0.5
    
label_plane(bpy.data.objects['Garage'], "Garage Shot")
label_plane(bpy.data.objects['Driveway'], "Driveway Clip")
label_plane(bpy.data.objects['TerminalFeed'], "Code Overlay")