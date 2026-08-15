"""PROTOTYPE: derive a small bar vignette without modifying the pristine source."""

import bpy
import os
import sys


KEEP_OBJECTS = {
    "Light_Shade_Front",
    "Light_Shade_Rear",
    "Room",
    "backbar",
    "bar",
    "bottle_round_shoulder_corked",
    "bottle_round_shoulder_not_corked",
    "bottle_square",
    "bottle_wide_shoulder",
    "floor",
    "shotglass",
    "shotglass_stacked",
    "stool",
    "walls01",
    "walls02",
    "walls03",
    "walls03.001",
    "walls03.002",
    "walls04",
    "walls04.001",
    "walls04.002",
}


def script_arguments() -> list[str]:
    if "--" not in sys.argv:
        raise RuntimeError("Expected destination and source hash after --")
    return sys.argv[sys.argv.index("--") + 1 :]


destination, source_sha256 = script_arguments()
destination = os.path.abspath(destination)

for obj in list(bpy.data.objects):
    if obj.name not in KEEP_OBJECTS:
        bpy.data.objects.remove(obj, do_unlink=True)

for image in bpy.data.images:
    if not image.filepath:
        continue
    filename = image.filepath.replace("\\", "/").rsplit("/", 1)[-1]
    image.filepath_raw = "//Textures/" + filename
    image.filepath = "//Textures/" + filename

scene = bpy.context.scene
scene["visual_spike_source_sha256"] = source_sha256
scene["visual_spike_purpose"] = "Ticket #2 direct Blender-to-Godot import evidence"

bpy.data.orphans_purge(do_recursive=True)
os.makedirs(os.path.dirname(destination), exist_ok=True)
bpy.ops.wm.save_as_mainfile(
    filepath=destination,
    check_existing=False,
    relative_remap=False,
)

print("VISUAL_SPIKE_SAVED=" + destination)
print("VISUAL_SPIKE_OBJECTS=" + ",".join(sorted(obj.name for obj in scene.objects)))
