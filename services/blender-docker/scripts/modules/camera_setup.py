import bpy

def setup_camera(location=(0, -8, 2), rotation=(1.2, 0, 0)):
    cam_data = bpy.data.cameras.new("MainCam")
    cam_obj = bpy.data.objects.new("MainCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)

    cam_obj.location = location
    cam_obj.rotation_euler = rotation
    bpy.context.scene.camera = cam_obj
    return cam_obj