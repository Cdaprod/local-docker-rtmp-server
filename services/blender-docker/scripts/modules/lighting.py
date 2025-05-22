import bpy

def setup_basic_lighting(location=(5, -5, 5)):
    light_data = bpy.data.lights.new(name="KeyLight", type='AREA')
    light_obj = bpy.data.objects.new(name="KeyLight", object_data=light_data)
    bpy.context.collection.objects.link(light_obj)

    light_obj.location = location
    light_data.energy = 1000