"""PROTOTYPE: print scene evidence for the ticket #2 Blender/Godot spike."""

import bpy
import json
import os


def rounded(values):
    return [round(float(value), 4) for value in values]


scene = bpy.context.scene
mesh_objects = []

for obj in sorted((item for item in scene.objects if item.type == "MESH"), key=lambda item: item.name):
    mesh_objects.append(
        {
            "name": obj.name,
            "mesh": obj.data.name,
            "location": rounded(obj.location),
            "rotation_degrees": rounded(value * 57.295779513 for value in obj.rotation_euler),
            "scale": rounded(obj.scale),
            "dimensions": rounded(obj.dimensions),
            "polygons": len(obj.data.polygons),
            "materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
        }
    )

images = []
for image in sorted(bpy.data.images, key=lambda item: item.name):
    absolute_path = bpy.path.abspath(image.filepath) if image.filepath else ""
    images.append(
        {
            "name": image.name,
            "filepath": image.filepath,
            "absolute_path": absolute_path,
            "exists": bool(absolute_path and os.path.exists(absolute_path)),
            "packed": image.packed_file is not None,
            "size": list(image.size),
            "colorspace": image.colorspace_settings.name,
        }
    )

payload = {
    "blender_version": bpy.app.version_string,
    "scene": scene.name,
    "unit_system": scene.unit_settings.system,
    "unit_scale": scene.unit_settings.scale_length,
    "object_count": len(scene.objects),
    "mesh_objects": mesh_objects,
    "materials": sorted(material.name for material in bpy.data.materials),
    "images": images,
}

print("VISUAL_SPIKE_INSPECTION=" + json.dumps(payload, sort_keys=True))
