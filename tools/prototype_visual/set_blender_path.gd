@tool
extends SceneTree

const DEFAULT_BLENDER_PATH := "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"


func _initialize() -> void:
    _configure.call_deferred()


func _configure() -> void:
    var blender_path := OS.get_environment("VISUAL_SPIKE_BLENDER_PATH")
    if blender_path.is_empty():
        blender_path = DEFAULT_BLENDER_PATH
    var settings: EditorSettings = EditorInterface.get_editor_settings()
    settings.set_setting("filesystem/import/blender/blender_path", blender_path)
    print("VISUAL_SPIKE_BLENDER_PATH=" + str(settings.get_setting(
        "filesystem/import/blender/blender_path"
    )))
    await process_frame
    quit()
