extends Node3D

const AVATAR_MOTION_SCRIPT := preload(
	"res://scripts/presentation/avatar_motion_controller.gd"
)
const BARTENDER_TEXTURE: Texture2D = preload(
	"res://assets/characters/prototype_visual/Bartender.png"
)

const PIXEL_SIZE := 0.05
const FEET_OFFSET := 16.0 * PIXEL_SIZE
const REVIEW_STATES: Array[Dictionary] = [
	{"id": &"idle", "label": "IDLE", "gait": &"walk", "moving": false, "doing": false, "prone": false},
	{"id": &"doing", "label": "DOING", "gait": &"walk", "moving": false, "doing": true, "prone": false},
	{"id": &"walking", "label": "WALKING", "gait": &"walk", "moving": true, "doing": false, "prone": false},
	{"id": &"running", "label": "RUNNING", "gait": &"run", "moving": true, "doing": false, "prone": false},
	{"id": &"passive_body", "label": "MOVED BODY", "gait": &"walk", "moving": true, "doing": false, "prone": true},
	{"id": &"blocked", "label": "BLOCKED → IDLE", "gait": &"walk", "moving": true, "doing": false, "prone": false},
]
const COLORS := [
	Color("77b89a"), Color("d5b76e"), Color("a8c97d"),
	Color("db7c6c"), Color("a98bc4"), Color("7d9fc9"),
]

var _controllers: Dictionary = {}
var _review_scale := 1.0
var _paused := false
var _elapsed := 0.0


func _ready() -> void:
	_review_scale = clampf(float(_argument("--scale=", "1")), 1.0, 4.0)
	_paused = _flag("--paused")
	_build_world()
	for index in REVIEW_STATES.size():
		_add_actor(REVIEW_STATES[index], index)
	var capture_path := _argument("--capture=")
	var report_path := _argument("--report=")
	if not capture_path.is_empty():
		_capture.call_deferred(capture_path, maxi(12, int(_argument("--frames=", "90"))))
	elif not report_path.is_empty():
		_write_report.call_deferred(report_path)


func _process(delta: float) -> void:
	_elapsed += delta
	var scale := 0.0 if _paused else _review_scale
	for state: Dictionary in REVIEW_STATES:
		var controller := _controllers[state["id"]] as AvatarMotionController
		controller.set_simulation_scale(scale)
		var moving: bool = bool(state["moving"])
		var travelled := 0.0
		if moving and state["id"] != &"blocked" and scale > 0.0:
			var metres_per_second := 2.05 if state["id"] == &"running" else 1.3
			if state["id"] == &"passive_body":
				metres_per_second = 0.75
			travelled = metres_per_second * scale * delta
		controller.advance_motion(delta, travelled)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("161a1d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("fff2d0")
	settings.ambient_light_energy = 1.4
	environment.environment = settings
	add_child(environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 5.5, 24.0)
	camera.fov = 34.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	add_child(camera)

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(22.0, 0.08, 5.0)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.04, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("273a34")
	floor_material.roughness = 1.0
	floor.material_override = floor_material
	add_child(floor)

	var title := Label3D.new()
	title.text = "FULL-AVATAR MOTION  ·  %s" % ("PAUSED" if _paused else "%dx" % int(_review_scale))
	title.position = Vector3(0.0, 3.5, 0.0)
	title.font_size = 52
	title.pixel_size = 0.008
	title.modulate = Color("e8d8b5")
	title.outline_size = 12
	title.outline_modulate = Color("111416")
	title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(title)


func _add_actor(state: Dictionary, index: int) -> void:
	var root := Node3D.new()
	root.name = String(state["id"])
	root.position = Vector3(-7.5 + float(index) * 3.0, 0.0, 0.0)
	add_child(root)

	var controller := AVATAR_MOTION_SCRIPT.new() as AvatarMotionController
	controller.configure(StringName(state["id"]))
	controller.set_process(false)
	controller.set_simulation_scale(0.0 if _paused else _review_scale)
	controller.set_context(
		StringName(state["gait"]), bool(state["moving"]), bool(state["doing"]), bool(state["prone"])
	)
	root.add_child(controller)
	_controllers[state["id"]] = controller

	var body := Sprite3D.new()
	body.name = "Body"
	body.texture = BARTENDER_TEXTURE
	body.pixel_size = PIXEL_SIZE
	body.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body.modulate = COLORS[index]
	if bool(state["prone"]):
		body.scale = Vector3(1.25, 0.38, 1.0)
		body.position.y = 0.32
	else:
		body.position.y = FEET_OFFSET
	controller.add_child(body)

	var label := Label3D.new()
	label.text = String(state["label"])
	label.position = Vector3(0.0, 2.25, 0.0)
	label.font_size = 38
	label.pixel_size = 0.006
	label.modulate = Color("e8d8b5")
	label.outline_size = 12
	label.outline_modulate = Color("111416")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(label)


func _capture(path: String, frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(absolute)
	get_tree().quit(result)


func _write_report(path: String) -> void:
	await get_tree().process_frame
	for _frame in 30:
		_process(1.0 / 60.0)
	var states: Dictionary = {}
	for state: Dictionary in REVIEW_STATES:
		states[state["id"]] = (_controllers[state["id"]] as AvatarMotionController).snapshot()
	var controller := AVATAR_MOTION_SCRIPT.new() as AvatarMotionController
	controller.configure(&"blocked_contract")
	controller.set_simulation_scale(1.0)
	controller.set_context(&"walk", true, false, false)
	controller.advance_motion(0.05, 0.04)
	controller.advance_motion(0.23, 0.0)
	var blocked_settles := controller.current_state() == AvatarMotionController.IDLE
	controller.free()
	var paused_controller := AVATAR_MOTION_SCRIPT.new() as AvatarMotionController
	paused_controller.configure(&"pause_contract")
	paused_controller.set_simulation_scale(1.0)
	paused_controller.set_context(&"walk", false, true, false)
	paused_controller.advance_motion(0.2, 0.0)
	var before_pause: Dictionary = paused_controller.snapshot()
	paused_controller.set_simulation_scale(0.0)
	paused_controller.advance_motion(2.0, 4.0)
	var after_pause: Dictionary = paused_controller.snapshot()
	var pause_freezes := before_pause == after_pause
	paused_controller.free()
	var passed: bool = (
		states[&"idle"]["state"] == AvatarMotionController.IDLE
		and states[&"doing"]["state"] == AvatarMotionController.DOING
		and states[&"walking"]["state"] == AvatarMotionController.WALKING
		and states[&"running"]["state"] == AvatarMotionController.RUNNING
		and states[&"passive_body"]["state"] == AvatarMotionController.PASSIVE_BODY
		and states[&"blocked"]["state"] == AvatarMotionController.IDLE
		and blocked_settles
		and pause_freezes
	)
	var report := {
		"slice": "avatar_motion_review",
		"passed": passed,
		"scale": _review_scale,
		"paused": _paused,
		"blocked_settles": blocked_settles,
		"pause_freezes": pause_freezes,
		"states": states,
	}
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	get_tree().quit(0 if passed else 1)


func _argument(prefix: String, fallback := "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _flag(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()
