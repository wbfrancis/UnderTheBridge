"""PROTOTYPE: make one idempotent visible edit to prove direct reimport."""

import bpy


scene = bpy.context.scene
probe_version = int(scene.get("visual_spike_reimport_probe", 0))

if probe_version == 0:
    stool = bpy.data.objects.get("stool")
    if stool is None:
        raise RuntimeError("Expected stool in visual-spike vignette")
    stool.location.x += 0.05
    scene["visual_spike_reimport_probe"] = 1

bpy.ops.wm.save_as_mainfile(
    filepath=bpy.data.filepath,
    check_existing=False,
    relative_remap=False,
)

print("VISUAL_SPIKE_REIMPORT_PROBE=" + str(scene["visual_spike_reimport_probe"]))
print("VISUAL_SPIKE_STOOL_LOCATION=" + repr(tuple(bpy.data.objects["stool"].location)))
