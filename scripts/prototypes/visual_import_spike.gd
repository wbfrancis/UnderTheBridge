extends Node3D

const VIGNETTE: PackedScene = preload(
    "res://assets/environment/prototype_visual/Speakeasy_VisualSpike.blend"
)
const BARTENDER: Texture2D = preload(
    "res://assets/characters/prototype_visual/Bartender.png"
)

const CAMERA_POSITION := Vector3(-18.93, 2.31, 0.9)
const CAMERA_TARGET := Vector3(0.0, 0.65, 0.9)
const BARTENDER_POSITION := Vector3(-0.65, 0.4, 2.35)
const CUTAWAY_NODES := [
	"Light_Shade_Front",
	"Light_Shade_Rear",
	"Room",
	"stool",
	"walls01",
	"walls02",
]


func _ready() -> void:
	_build_scene()
	var capture_path := _capture_path_from_arguments()
	if not capture_path.is_empty():
		_capture_after_render.call_deferred(capture_path)


func _build_scene() -> void:
	var environment_root := VIGNETTE.instantiate()
	environment_root.name = "ImportedBlenderVignette"
	add_child(environment_root)
	_apply_cutaway(environment_root)
	_apply_material_overrides(environment_root)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171920")
	environment.background_energy_multiplier = 0.35
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aeb7c5")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.25
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-58.0, -18.0, 0.0)
	key_light.light_color = Color("fff2df")
	key_light.light_energy = 0.72
	key_light.shadow_enabled = true
	add_child(key_light)

	var bar_light := OmniLight3D.new()
	bar_light.name = "BarLight"
	bar_light.position = Vector3(0.0, 1.8, -0.4)
	bar_light.light_color = Color("ffd9ae")
	bar_light.light_energy = 0.5
	bar_light.omni_range = 3.0
	bar_light.shadow_enabled = true
	add_child(bar_light)

	var reflection_probe := ReflectionProbe.new()
	reflection_probe.name = "BarReflectionProbe"
	reflection_probe.position = Vector3(0.0, 1.0, 0.0)
	reflection_probe.size = Vector3(5.0, 3.0, 6.0)
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(reflection_probe)

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = CAMERA_POSITION
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 10.0
	camera.near = 0.05
	camera.far = 50.0
	add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)
	camera.current = true

	var bartender := Sprite3D.new()
	bartender.name = "Bartender"
	bartender.texture = BARTENDER
	bartender.position = BARTENDER_POSITION
	bartender.pixel_size = 0.025
	bartender.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	bartender.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bartender.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	bartender.render_priority = 1
	add_child(bartender)
	_add_bartender_shadow()

	_add_evidence_overlay()
	print("VISUAL_SPIKE_READY renderer=%s camera=%s target=%s sprite_pixel_size=%.3f" % [
		RenderingServer.get_current_rendering_method(),
		CAMERA_POSITION,
		CAMERA_TARGET,
		bartender.pixel_size,
	])


func _apply_cutaway(environment_root: Node) -> void:
	for node_name in CUTAWAY_NODES:
		var cutaway_node := environment_root.find_child(node_name, true, false)
		if cutaway_node is Node3D:
			cutaway_node.visible = false


func _add_bartender_shadow() -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "BartenderContactShadow"
	shadow.position = Vector3(BARTENDER_POSITION.x, 0.006, BARTENDER_POSITION.z)
	shadow.scale = Vector3(1.0, 1.0, 0.55)

	var disc := CylinderMesh.new()
	disc.top_radius = 0.14
	disc.bottom_radius = 0.14
	disc.height = 0.012
	disc.radial_segments = 24
	shadow.mesh = disc

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.02, 0.015, 0.025, 0.48)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	add_child(shadow)


func _apply_material_overrides(environment_root: Node) -> void:
	for descendant in environment_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var imported_material := mesh_instance.mesh.surface_get_material(surface_index)
			if imported_material == null:
				continue
			var material_name := imported_material.resource_name
			match material_name:
				"mirror":
					mesh_instance.set_surface_override_material(
						surface_index,
						_build_mirror_material()
					)
				"glass1":
					mesh_instance.set_surface_override_material(
						surface_index,
						_build_clear_glass_material()
					)
				"glass_lamp":
					mesh_instance.set_surface_override_material(
						surface_index,
						_build_lamp_glass_material()
					)


func _build_mirror_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "mirror_godot_override"
	material.albedo_color = Color("697380")
	material.metallic = 0.6
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = Color("4a535f")
	material.emission_energy_multiplier = 0.18
	return material


func _build_clear_glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "glass_godot_override"
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.42, 0.35, 0.28, 0.24)
	material.metallic = 0.15
	material.roughness = 0.12
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_lamp_glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "lamp_glass_godot_override"
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.65, 0.28, 0.38)
	material.emission_enabled = true
	material.emission = Color("d6833a")
	material.emission_energy_multiplier = 0.35
	material.roughness = 0.3
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _add_evidence_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EvidenceOverlay"
	canvas.layer = 100
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 620.0)
	panel.size = Vector2(620.0, 82.0)
	panel.color = Color(0.025, 0.02, 0.035, 0.88)
	canvas.add_child(panel)

	var label := Label.new()
	label.position = Vector2(14.0, 10.0)
	label.text = (
		"TICKET #2 — DIRECT .BLEND IMPORT\n"
		+ "LONG-LENS 2.5D • BAR-BACK WALL • 5° FLUSH CUTAWAY\n"
		+ "0.025 m/px • NEAREST • %s • MATERIAL OVERRIDES" % RenderingServer.get_current_rendering_method().to_upper()
	)
	label.add_theme_color_override("font_color", Color("f5e8d0"))
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)


func _capture_path_from_arguments() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			return argument.trim_prefix("--capture=")
	return ""


func _capture_after_render(capture_path: String) -> void:
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var absolute_path := ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(absolute_path)
	print("VISUAL_SPIKE_CAPTURE path=%s result=%s" % [absolute_path, error_string(result)])
	# Let the renderer release the captured viewport resources before shutdown.
	await get_tree().process_frame
	get_tree().quit(result)
