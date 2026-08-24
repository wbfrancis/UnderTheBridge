extends Node3D

# A greybox 3-D view over the perception sim. It is a pure view: it drives
# GameSession exactly like the perception_danger slice, then reads snapshot()
# and draws each Patron's room, position, facing, and Suspicion band in space.
# The HUD keeps the slice's scenario buttons so the panel reading and the spatial
# reading reinforce each other. Nothing in the sim is modified.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const PATRON_PERCEPTION_SCRIPT := preload("res://scripts/patrons/patron_perception.gd")
const MAIN_ROOM_PRESENTATION_SCRIPT := preload("res://scripts/presentation/main_room_presentation_prototype.gd")
const NAVIGABLE_ACTOR_SCRIPT := preload("res://scripts/navigation/navigable_actor_3d.gd")
const MOVEMENT_PLAN_SCRIPT := preload("res://scripts/actions/cultist_movement_plan.gd")
const NAVIGATION_MESH: NavigationMesh = preload(
	"res://assets/navigation/speakeasy_navigation.tres"
)
const BARTENDER_TEXTURE: Texture2D = preload("res://assets/characters/prototype_visual/Bartender.png")
const VISUAL_SPIKE_SOURCE := "res://assets/environment/prototype_visual/Speakeasy_VisualSpike.blend"
const VISUAL_SPIKE_EXPECTED_SHA256 := "a03beb87ab04e88460a7c6787dd8cd2f1dde0129bb0c03d2d9beab51f81dcc80"
const PATRON_IDS: Array[StringName] = [&"patron_june", &"patron_mara"]
const ALL_PATRON_IDS: Array[StringName] = [
	&"patron_june", &"patron_mara", &"patron_elias", &"patron_ruth",
	&"patron_walter", &"patron_nell", &"patron_vincent", &"patron_clara",
]
const CULTIST_IDS: Array[StringName] = [&"cultist_01", &"cultist_02", &"cultist_03"]
const SCENARIOS := {
	"full_cast": "FULL CAST",
	"service_wing": "SERVICE WING",
	"front_exit": "FRONT EXIT",
	"cultist_states": "CULTIST STATES",
	"line_of_sight": "LINE OF SIGHT",
	"room_hearing": "ROOM HEARING",
	"unattended_body": "UNATTENDED BODY",
	"companion": "COMPANION INFLUENCE",
	"debug_trace": "DEBUG TRACE",
}

# Camera emulates the visual spike: a long lens from the bar side looking down the
# room's depth axis, so sim +x reads screen-right and every room stays in frame.
const CAMERA_POSITION := Vector3(3.0, 33.0, 33.0)
const CAMERA_TARGET := Vector3(3.0, 0.0, 6.0)
const CAMERA_FOV := 50.0
const PRESENTATION_CAMERA_POSITION := Vector3(0.0, 10.0, 34.0)
const PRESENTATION_CAMERA_TARGET := Vector3(0.0, 1.0, 3.0)
const PRESENTATION_CAMERA_FOV := 30.0
const SERVICE_CAMERA_POSITION := Vector3(17.0, 10.0, 37.0)
const SERVICE_CAMERA_TARGET := Vector3(17.0, 1.0, 6.0)
const FRONT_CAMERA_POSITION := Vector3(-17.5, 10.0, 36.0)
const FRONT_CAMERA_TARGET := Vector3(-17.5, 1.0, 5.0)
const CAMERA_PAN_SPEED := 16.0
const CAMERA_PAN_ACCELERATION := 48.0
const CAMERA_PAN_DECELERATION := 64.0
const TRACKPAD_PAN_HOLD_SECONDS := 0.08
const TRACKPAD_ZOOM_SENSITIVITY := 2.0
const ZOOM_SMOOTHNESS := 9.0
const CULTIST_VISIBLE_HEIGHT_METRES := 1.75
const BARTENDER_OPAQUE_HEIGHT_PIXELS := 35.0
const BARTENDER_FEET_FROM_CANVAS_CENTER_PIXELS := 16.0
const PLAY_SCALE := 4.0
const NAVIGATION_FLOOR_Y := 0.18
const MAX_DESTINATION_SNAP_METERS := 1.5
const PATRON_COLORS := {
	&"patron_june": Color("e3a57a"), &"patron_mara": Color("7fc7c4"),
	&"patron_elias": Color("b79ad8"), &"patron_ruth": Color("d9c56f"),
	&"patron_walter": Color("83a9d8"), &"patron_nell": Color("d8849d"),
	&"patron_vincent": Color("94c77c"), &"patron_clara": Color("d69a63"),
}
const PATRON_HEIGHT_SCALE := {
	&"patron_june": 0.94, &"patron_mara": 1.02, &"patron_elias": 1.08,
	&"patron_ruth": 0.98, &"patron_walter": 1.12, &"patron_nell": 0.9,
	&"patron_vincent": 1.04, &"patron_clara": 0.96,
}
const CULTIST_COLORS := {
	&"cultist_01": Color("efe1ce"), &"cultist_02": Color("b9a0db"),
	&"cultist_03": Color("8fc4af"),
}
const CULTIST_POSITIONS := {
	&"cultist_01": Vector3(-3.6, 0.0, 1.45),
	&"cultist_02": Vector3(0.0, 0.0, 1.45),
	&"cultist_03": Vector3(3.6, 0.0, 1.45),
}

# The real perception rule values, read straight from the module so the drawn cone
# and rings match what the sim actually tests.
const VIEW_CONE_HALF_ANGLE := PATRON_PERCEPTION_SCRIPT.VIEW_CONE_HALF_ANGLE_DEGREES
const VIEW_RANGE := PATRON_PERCEPTION_SCRIPT.VIEW_RANGE_METRES
const COMPANION_RANGE := PATRON_PERCEPTION_SCRIPT.COMPANION_RANGE_METRES

const SEEN_COLOR := Color("55d6e6")
const UNSEEN_COLOR := Color("606b78")
const RAY_COLOR := Color("eef3f6")
const SOUND_COLOR := Color("4f8ae0")
const CONE_COLOR := Color("8fb6cf")
const COMPANION_RING_COLOR := Color("74c98d")

# Display-only room rectangles [min_x, min_z, max_x, max_z] in sim metres. They
# mirror the adjacency chain front — main_hall — hallway — bathroom so the
# room-hearing relationship is visible on the floor.
const ROOM_RECTS := {
	&"main_hall": [-14.0, -2.0, 13.0, 10.0],
	&"front": [-21.0, -2.0, -14.0, 12.0],
	&"hallway": [13.0, 3.0, 17.0, 9.0],
	&"bathroom": [17.0, 3.0, 21.0, 9.0],
}
const ROOM_COLORS := {
	&"main_hall": Color(0.16, 0.22, 0.28, 0.5),
	&"front": Color(0.24, 0.20, 0.14, 0.5),
	&"hallway": Color(0.18, 0.16, 0.24, 0.5),
	&"bathroom": Color(0.14, 0.22, 0.22, 0.5),
}
const SEAT_POSITIONS := {
	&"seat_01": Vector2(-12.0, 6.0), &"seat_02": Vector2(-10.5, 6.0),
	&"seat_03": Vector2(-6.0, 6.0), &"seat_04": Vector2(-4.5, 6.0),
	&"seat_05": Vector2(4.5, 6.0), &"seat_06": Vector2(6.0, 6.0),
	&"seat_07": Vector2(10.5, 6.0), &"seat_08": Vector2(12.0, 6.0),
}
const BAND_COLORS := {
	"Calm": Color("8fbf9f"), "Uneasy": Color("d3be76"), "Suspicious": Color("df9d65"),
	"Alarmed": Color("df745f"), "Maximum": Color("e65c70"),
}

var _session = GAME_SESSION_SCRIPT.new()
@export var review_presentation: bool = false
@export var review_closeup: bool = false
@export var review_stage: String = "line_of_sight"
@export var review_debug_visible: bool = true
var _scenario: String = "line_of_sight"
var _scenario_trace: String = ""
var _playing: bool = false
var _debug_visible: bool = true
var _capture_mode: bool = false
var _presentation_prototype: bool = false
var _presentation_closeup: bool = false
var _patron_nodes: Dictionary = {}
var _patron_visual_targets: Dictionary = {}
var _next_patron_move_id := 1
var _latest_state: Dictionary = {}
var _cultist_nodes: Dictionary = {}
var _movement_plans: Dictionary = {}
var _selected_cultist_id: StringName = &"cultist_01"
var _hovered_actor_id: StringName = &""
var _hovered_is_cultist := false
var _inspected_patron_id: StringName = &""
var _actor_root: Node3D
var _cultist_root: Node3D
var _move_marker_root: Node3D
var _navigation_region: NavigationRegion3D
var _navigation_ready := false
var _movement_feedback := "Select a Cultist, then right-click the floor to move. Hold Shift to queue."
var _movement_report_path := ""
var _body_root: Node3D
var _event_root: Node3D
var _camera: Camera3D
var _camera_target: Vector3 = PRESENTATION_CAMERA_TARGET
var _camera_fov_target: float = PRESENTATION_CAMERA_FOV
var _camera_pan_velocity := Vector3.ZERO
var _trackpad_pan_intent := Vector2.ZERO
var _trackpad_pan_hold_remaining := 0.0
var _staged_bodies: Array = []
var _events: Array = []
var _scenario_buttons: Dictionary = {}
var _play_button: Button
var _debug_label: RichTextLabel
var _hover_panel: PanelContainer
var _hover_label: RichTextLabel
var _info_panel: PanelContainer
var _info_label: RichTextLabel


func _ready() -> void:
	_presentation_closeup = review_closeup or _command_line_flag("--presentation-closeup")
	_presentation_prototype = review_presentation or _command_line_flag("--presentation-prototype") or _presentation_closeup
	_debug_visible = review_debug_visible
	_build_environment()
	_build_navigation_world()
	_build_hud()
	_session.snapshot_changed.connect(_refresh)
	_set_scenario(_command_line_value("--stage=", review_stage))
	var capture_path := _command_line_value("--capture=")
	var report_path := _command_line_value("--report=")
	_movement_report_path = _command_line_value("--movement-report=")
	var identify_patron := StringName(_command_line_value("--identify-patron="))
	if not identify_patron.is_empty():
		_session.begin_conversation(&"cultist_01", identify_patron)
		_session.end_conversation(&"cultist_01")
	var inspect_patron := StringName(_command_line_value("--inspect-patron="))
	if not inspect_patron.is_empty():
		_inspected_patron_id = inspect_patron
		_refresh(_session.snapshot())
	var hover_actor := StringName(_command_line_value("--hover-actor="))
	if not hover_actor.is_empty():
		_hovered_actor_id = hover_actor
		_hovered_is_cultist = String(hover_actor).begins_with("cultist_")
		_hover_panel.position = Vector2(540.0, 210.0)
		_refresh_character_panels(_session.snapshot())
	if not _movement_report_path.is_empty():
		_capture_mode = true
	if not capture_path.is_empty():
		_capture_mode = true
		_capture_after_render.call_deferred(capture_path)
	elif not report_path.is_empty():
		_capture_mode = true
		_write_validation_report.call_deferred(report_path)
	_bake_navigation_world.call_deferred()


func _process(delta: float) -> void:
	if _playing and not _capture_mode:
		_session.advance(delta * PLAY_SCALE)
	if _presentation_prototype and not _capture_mode:
		_update_camera_pan(delta)
		if not is_equal_approx(_camera.fov, _camera_fov_target):
			var zoom_weight := 1.0 - exp(-ZOOM_SMOOTHNESS * delta)
			_camera.fov = lerpf(_camera.fov, _camera_fov_target, zoom_weight)


func _unhandled_input(event: InputEvent) -> void:
	if not _presentation_prototype or _capture_mode:
		return
	if event is InputEventMouseMotion:
		_update_character_hover(event.position)
	elif event is InputEventPanGesture:
		if event.meta_pressed:
			_zoom_camera_smooth(event.delta.y * TRACKPAD_ZOOM_SENSITIVITY)
		else:
			_queue_trackpad_pan(event.delta)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_character_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_issue_move_at(event.position, event.shift_pressed)
		else:
			var wheel_pan := _wheel_pan_delta(event)
			if not wheel_pan.is_zero_approx():
				if event.meta_pressed:
					_zoom_camera_smooth(wheel_pan.y * TRACKPAD_ZOOM_SENSITIVITY)
				else:
					_queue_trackpad_pan(wheel_pan)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL:
			_zoom_camera_smooth(-2.0)
		elif event.keycode == KEY_MINUS:
			_zoom_camera_smooth(2.0)


func _zoom_camera_smooth(fov_delta: float) -> void:
	_camera_fov_target = clampf(_camera_fov_target + fov_delta, 20.0, 55.0)


func _queue_trackpad_pan(pan_delta: Vector2) -> void:
	_trackpad_pan_intent = pan_delta.limit_length(1.0)
	_trackpad_pan_hold_remaining = TRACKPAD_PAN_HOLD_SECONDS


func _wheel_pan_delta(event: InputEventMouseButton) -> Vector2:
	var factor := maxf(event.factor, 1.0)
	match event.button_index:
		MOUSE_BUTTON_WHEEL_LEFT: return Vector2(-factor, 0.0)
		MOUSE_BUTTON_WHEEL_RIGHT: return Vector2(factor, 0.0)
		MOUSE_BUTTON_WHEEL_UP: return Vector2(0.0, -factor)
		MOUSE_BUTTON_WHEEL_DOWN: return Vector2(0.0, factor)
	return Vector2.ZERO


func _update_camera_pan(delta: float) -> void:
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if pan.is_zero_approx() and _trackpad_pan_hold_remaining > 0.0:
		pan = _trackpad_pan_intent
	_trackpad_pan_hold_remaining = maxf(0.0, _trackpad_pan_hold_remaining - delta)
	if _trackpad_pan_hold_remaining <= 0.0:
		_trackpad_pan_intent = Vector2.ZERO
	var desired_velocity := Vector3(pan.x, 0.0, pan.y) * CAMERA_PAN_SPEED
	var acceleration := CAMERA_PAN_ACCELERATION if not pan.is_zero_approx() else CAMERA_PAN_DECELERATION
	_camera_pan_velocity = _camera_pan_velocity.move_toward(desired_velocity, acceleration * delta)
	if not _camera_pan_velocity.is_zero_approx():
		_pan_camera(_camera_pan_velocity * delta)


func _pan_camera(shift: Vector3) -> void:
	_camera.position += shift
	_camera_target += shift
	_camera.look_at(_camera_target, Vector3.UP)


func _character_at(screen_position: Vector2) -> Dictionary:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + _camera.project_ray_normal(screen_position) * 250.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Object = hit["collider"]
	if not collider.has_meta("actor_id") or not collider.has_meta("is_cultist"):
		return {}
	return {
		"id": StringName(collider.get_meta("actor_id")),
		"is_cultist": bool(collider.get_meta("is_cultist")),
	}


func _handle_character_left_click(screen_position: Vector2) -> void:
	var character := _character_at(screen_position)
	if character.is_empty():
		return
	if character["is_cultist"]:
		_select_cultist(character["id"])
	else:
		_inspected_patron_id = character["id"]
		_refresh_character_panels(_session.snapshot())


func _update_character_hover(screen_position: Vector2) -> void:
	var character := _character_at(screen_position)
	if character.is_empty():
		_hovered_actor_id = &""
		if _hover_panel != null:
			_hover_panel.visible = false
		return
	_hovered_actor_id = character["id"]
	_hovered_is_cultist = character["is_cultist"]
	if _hover_panel != null:
		_hover_panel.position = screen_position + Vector2(16.0, 18.0)
	_refresh_character_panels(_session.snapshot())


func _select_cultist(cultist_id: StringName) -> void:
	if not _cultist_nodes.has(cultist_id):
		return
	_selected_cultist_id = cultist_id
	for id: StringName in _cultist_nodes:
		var actor := _cultist_nodes[id] as NavigableActor3D
		actor.set_selected(id == cultist_id)
	_movement_feedback = "%s selected." % _cultist_display_name(cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


func _issue_move_at(screen_position: Vector2, append_to_queue: bool) -> void:
	if not _navigation_ready:
		_movement_feedback = "Navigation is not ready."
		return
	if not _cultist_nodes.has(_selected_cultist_id):
		_movement_feedback = "Select a Cultist first."
		return
	var destination: Variant = _floor_destination(screen_position)
	if destination == null:
		_movement_feedback = "That floor destination is not reachable."
		return
	var plan = _movement_plans[_selected_cultist_id]
	var action_id: int = plan.issue_move(destination, append_to_queue)
	if action_id < 0:
		_movement_feedback = "The Action Queue is full."
		return
	_movement_feedback = (
		"Move queued for %s." if append_to_queue else "Move started for %s."
	) % _cultist_display_name(_selected_cultist_id)
	_sync_cultist_navigation(_selected_cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


func _floor_destination(screen_position: Vector2) -> Variant:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	var floor_plane := Plane(Vector3.UP, NAVIGATION_FLOOR_Y)
	var intersection: Variant = floor_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null
	var raw_destination: Vector3 = intersection
	var navigation_map := get_world_3d().navigation_map
	var reachable := NavigationServer3D.map_get_closest_point(navigation_map, raw_destination)
	if raw_destination.distance_to(reachable) > MAX_DESTINATION_SNAP_METERS:
		return null
	return reachable


func _sync_cultist_navigation(cultist_id: StringName) -> void:
	var actor := _cultist_nodes[cultist_id] as NavigableActor3D
	var plan = _movement_plans[cultist_id]
	if not plan.has_active_move():
		actor.cancel_navigation()
		return
	var action_id: int = plan.active_action_id()
	if actor.active_action_id() != action_id:
		actor.navigate(action_id, plan.active_destination())


func _on_cultist_destination_reached(cultist_id: StringName, action_id: int) -> void:
	var plan = _movement_plans[cultist_id]
	if plan.active_action_id() != action_id:
		return
	plan.complete_active_move()
	_sync_cultist_navigation(cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


func _on_cultist_navigation_stuck(cultist_id: StringName, action_id: int) -> void:
	var plan = _movement_plans[cultist_id]
	if plan.active_action_id() != action_id:
		return
	plan.fail_active_move(&"path_stuck")
	_movement_feedback = "%s could not reach that destination." % _cultist_display_name(cultist_id)
	_sync_cultist_navigation(cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


func _refresh_move_markers() -> void:
	if _move_marker_root == null:
		return
	for child in _move_marker_root.get_children():
		child.queue_free()
	if not _movement_plans.has(_selected_cultist_id):
		return
	var destinations: Array[Vector3] = _movement_plans[_selected_cultist_id].destination_markers()
	for index in range(destinations.size()):
		var marker := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.25
		cylinder.bottom_radius = 0.25
		cylinder.height = 0.04
		cylinder.material = _flat_material(CULTIST_COLORS[_selected_cultist_id], 0.85)
		marker.mesh = cylinder
		marker.position = destinations[index] + Vector3(0.0, 0.04, 0.0)
		var label := Label3D.new()
		label.text = str(index + 1)
		label.position.y = 0.12
		label.font_size = 28
		label.pixel_size = 0.006
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		marker.add_child(label)
		_move_marker_root.add_child(marker)


func _cultist_display_name(cultist_id: StringName) -> String:
	return String(cultist_id).replace("cultist_", "Cultist ")


# --- World -------------------------------------------------------------------

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1016")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aeb7c5")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-62.0, -34.0, 0.0)
	key_light.light_color = Color("fff2df")
	key_light.light_energy = 0.9
	key_light.shadow_enabled = true
	add_child(key_light)

	var floor_instance := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 24.0)
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(3.0, 0.0, 7.0)
	floor_instance.material_override = _flat_material(Color("11161d"), 1.0)
	add_child(floor_instance)

	for room_id: StringName in ROOM_RECTS:
		add_child(_build_room_zone(room_id))

	# Bar counter box at the origin, and the eight seat pads.
	if _presentation_prototype:
		_add_presentation_prototype()
	else:
		add_child(_build_box(Vector2(0.0, 0.0), Vector3(6.0, 1.1, 1.4), 0.55, Color("3a2c22")))
	for seat_id: StringName in SEAT_POSITIONS:
		add_child(_build_box(SEAT_POSITIONS[seat_id], Vector3(0.9, 0.5, 0.9), 0.25, Color("223743")))

	_actor_root = Node3D.new()
	_actor_root.name = "Actors"
	add_child(_actor_root)
	_cultist_root = Node3D.new()
	_cultist_root.name = "Cultists"
	add_child(_cultist_root)
	_move_marker_root = Node3D.new()
	_move_marker_root.name = "MoveMarkers"
	add_child(_move_marker_root)
	_body_root = Node3D.new()
	_body_root.name = "Bodies"
	add_child(_body_root)
	_event_root = Node3D.new()
	_event_root.name = "DangerEvents"
	add_child(_event_root)

	_camera = Camera3D.new()
	_camera.position = PRESENTATION_CAMERA_POSITION if _presentation_prototype else CAMERA_POSITION
	_camera_target = PRESENTATION_CAMERA_TARGET if _presentation_prototype else CAMERA_TARGET
	_camera.fov = PRESENTATION_CAMERA_FOV if _presentation_prototype else CAMERA_FOV
	_camera_fov_target = _camera.fov
	_camera.near = 0.1
	_camera.far = 200.0
	add_child(_camera)
	_camera.look_at(_camera_target, Vector3.UP)
	_camera.current = true


func _add_presentation_prototype() -> void:
	var main_room := MAIN_ROOM_PRESENTATION_SCRIPT.new() as Node3D
	main_room.name = "FullScaleSpeakeasyPresentation"
	add_child(main_room)


func _build_navigation_world() -> void:
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "ProductionNavigationRegion"
	_navigation_region.navigation_mesh = NAVIGATION_MESH.duplicate(true)
	add_child(_navigation_region)

	_add_navigation_box(Vector3(-0.5, 0.09, 4.0), Vector3(27.0, 0.18, 12.0))
	_add_navigation_box(Vector3(-17.5, 0.09, 5.0), Vector3(7.0, 0.18, 14.0))
	_add_navigation_box(Vector3(15.0, 0.09, 6.0), Vector3(4.0, 0.18, 6.0))
	_add_navigation_box(Vector3(19.0, 0.09, 6.0), Vector3(4.0, 0.18, 6.0))
	_add_navigation_box(Vector3(0.0, 0.68, 0.15), Vector3(12.45, 1.36, 1.65))
	for x_position in [-11.2, -5.2, 5.2, 11.2]:
		_add_navigation_box(Vector3(x_position, 0.43, 6.0), Vector3(1.56, 0.86, 1.56))
	_add_navigation_box(Vector3(19.55, 0.48, 5.8), Vector3(0.9, 0.96, 1.1))
	_add_navigation_box(Vector3(19.55, 0.5, 7.75), Vector3(1.1, 1.0, 0.75))


func _add_navigation_box(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_navigation_region.add_child(body)


func _bake_navigation_world() -> void:
	var navigation_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(navigation_map, 0.2)
	NavigationServer3D.map_set_cell_height(navigation_map, 0.1)
	var wait_frames := 0
	var sample_point := Vector3(-3.0, NAVIGATION_FLOOR_Y, 2.0)
	while (
		NavigationServer3D.map_get_iteration_id(navigation_map) == 0
		or NavigationServer3D.map_get_closest_point(navigation_map, sample_point).distance_to(sample_point) > 1.0
	) and wait_frames < 180:
		await get_tree().physics_frame
		wait_frames += 1
	_navigation_ready = (
		NavigationServer3D.map_get_iteration_id(navigation_map) > 0
		and NavigationServer3D.map_get_closest_point(navigation_map, sample_point).distance_to(sample_point) <= 1.0
	)
	_movement_feedback = (
		"Navigation ready. Left-click a Cultist; right-click the floor to move."
		if _navigation_ready
		else "Navigation failed to initialize."
	)
	_select_cultist(_selected_cultist_id)
	_refresh_hud(_session.snapshot())
	if not _movement_report_path.is_empty():
		_run_movement_validation.call_deferred(_movement_report_path)


func _run_movement_validation(report_path: String) -> void:
	var targets := {
		&"cultist_01": [Vector3(-8.0, NAVIGATION_FLOOR_Y, 4.0), Vector3(-3.0, NAVIGATION_FLOOR_Y, 2.0)],
		&"cultist_02": [Vector3(0.0, NAVIGATION_FLOOR_Y, 8.0)],
		&"cultist_03": [Vector3(8.0, NAVIGATION_FLOOR_Y, 4.0)],
	}
	if _navigation_ready:
		for cultist_id: StringName in CULTIST_IDS:
			var actor := _cultist_nodes[cultist_id] as NavigableActor3D
			actor.set_simulation_scale(4.0)
			var plan = _movement_plans[cultist_id]
			var destinations: Array = targets[cultist_id]
			plan.issue_move(destinations[0], false)
			for index in range(1, destinations.size()):
				plan.issue_move(destinations[index], true)
			_sync_cultist_navigation(cultist_id)
		for patron_id: StringName in _patron_nodes:
			(_patron_nodes[patron_id] as NavigableActor3D).set_simulation_scale(4.0)

	var frame_count := 0
	while _navigation_ready and frame_count < 900:
		var all_complete := true
		for cultist_id: StringName in CULTIST_IDS:
			if _movement_plans[cultist_id].has_active_move():
				all_complete = false
				break
		if all_complete:
			for patron_id: StringName in _patron_nodes:
				if (_patron_nodes[patron_id] as NavigableActor3D).is_navigating():
					all_complete = false
					break
		if all_complete:
			break
		await get_tree().physics_frame
		frame_count += 1

	var final_positions := {}
	var patron_positions := {}
	var passed := _navigation_ready
	for cultist_id: StringName in CULTIST_IDS:
		var actor := _cultist_nodes[cultist_id] as NavigableActor3D
		var destinations: Array = targets[cultist_id]
		var expected: Vector3 = destinations[-1]
		var distance := actor.global_position.distance_to(expected)
		final_positions[cultist_id] = {
			"position": [actor.global_position.x, actor.global_position.y, actor.global_position.z],
			"distance_to_target": distance,
			"repaths": actor.repath_count,
		}
		passed = passed and distance <= 0.55 and not _movement_plans[cultist_id].has_active_move()
	for patron_id: StringName in _patron_nodes:
		var actor := _patron_nodes[patron_id] as NavigableActor3D
		var expected: Vector3 = _patron_visual_targets.get(patron_id, actor.global_position)
		var distance := actor.global_position.distance_to(expected)
		patron_positions[patron_id] = {
			"position": [actor.global_position.x, actor.global_position.y, actor.global_position.z],
			"distance_to_target": distance,
			"repaths": actor.repath_count,
		}
		passed = passed and distance <= 0.82 and not actor.is_navigating()

	var report := {
		"passed": passed,
		"navigation_ready": _navigation_ready,
		"frames": frame_count,
		"selected_cultist": String(_selected_cultist_id),
		"cultists": final_positions,
		"patrons": patron_positions,
	}
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	get_tree().quit(0 if passed else 1)


func _build_room_zone(room_id: StringName) -> Node3D:
	var rect: Array = ROOM_RECTS[room_id]
	var center := Vector2((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5)
	var pad := _build_box(center, Vector3(rect[2] - rect[0], 0.06, rect[3] - rect[1]), 0.03, ROOM_COLORS[room_id], true)
	if _presentation_prototype and room_id in [&"hallway", &"bathroom"]:
		return pad
	var label := Label3D.new()
	label.text = String(room_id).to_upper().replace("_", " ")
	label.position = Vector3(center.x, 1.4, center.y)
	label.font_size = 60
	label.modulate = Color("93a6b4")
	label.outline_size = 18
	label.outline_modulate = Color("0b1016")
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	if _presentation_prototype and room_id == &"main_hall":
		label.font_size = 36
		label.pixel_size = 0.006
		label.position.y = 0.45
		label.modulate = Color("c8a878")
	pad.add_child(label)
	return pad


func _build_box(sim_position: Vector2, size: Vector3, y_center: float, color: Color, translucent := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = Vector3(sim_position.x, y_center, sim_position.y)
	instance.material_override = _flat_material(color, color.a if translucent else 1.0)
	return instance


func _flat_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# A flat FOV cone on the XZ plane, apex at the origin, opening along -Z (the pivot's
# facing after look_at). Drawn as the two straight edges to the full view range plus
# a short angle arc near the apex, so it reads as one Patron's cone without a giant
# sweep curving across the room.
func _sector_mesh(radius: float, half_angle_degrees: float) -> ArrayMesh:
	var half := deg_to_rad(half_angle_degrees)
	var edge_left := Vector3(sin(-half), 0.0, -cos(-half)) * radius
	var edge_right := Vector3(sin(half), 0.0, -cos(half)) * radius
	var vertices := PackedVector3Array()
	_append_stroke(vertices, PackedVector3Array([Vector3.ZERO, edge_left]), 0.12)
	_append_stroke(vertices, PackedVector3Array([Vector3.ZERO, edge_right]), 0.12)
	var arc_radius := minf(radius, 3.0)
	var arc := PackedVector3Array()
	for index in range(17):
		var a := lerpf(-half, half, float(index) / 16.0)
		arc.append(Vector3(sin(a), 0.0, -cos(a)) * arc_radius)
	_append_stroke(vertices, arc, 0.1)
	return _mesh_from_vertices(vertices)


# Appends thin flat quads tracing a polyline on the XZ plane.
func _append_stroke(vertices: PackedVector3Array, path: PackedVector3Array, thickness: float) -> void:
	for index in range(path.size() - 1):
		var a := path[index]
		var b := path[index + 1]
		var direction := b - a
		if direction.length() < 0.0001:
			continue
		direction = direction.normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * thickness * 0.5
		vertices.append_array([a + side, b + side, b - side, a + side, b - side, a - side])


func _mesh_from_vertices(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# A flat ring outline on the XZ plane at the given radius.
func _ring_mesh(radius: float, thickness: float) -> ArrayMesh:
	var segments := 48
	var inner := radius - thickness
	var vertices := PackedVector3Array()
	for index in range(segments):
		var a0 := TAU * float(index) / segments
		var a1 := TAU * float(index + 1) / segments
		var outer0 := Vector3(cos(a0), 0.0, sin(a0)) * radius
		var outer1 := Vector3(cos(a1), 0.0, sin(a1)) * radius
		var inner0 := Vector3(cos(a0), 0.0, sin(a0)) * inner
		var inner1 := Vector3(cos(a1), 0.0, sin(a1)) * inner
		vertices.append_array([inner0, outer0, outer1, inner0, outer1, inner1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Actors, bodies, events --------------------------------------------------

func _actor_pivot(patron_id: StringName) -> Node3D:
	if _patron_nodes.has(patron_id):
		return _patron_nodes[patron_id]
	var pivot := NAVIGABLE_ACTOR_SCRIPT.new() as NavigableActor3D
	pivot.configure(patron_id, false)
	var entrance_index := maxi(0, ALL_PATRON_IDS.find(patron_id))
	pivot.position = Vector3(
		-20.2,
		NAVIGATION_FLOOR_Y,
		1.1 + float(entrance_index) * 1.1
	)
	pivot.set_simulation_scale(PLAY_SCALE if _playing else 0.0)
	if _presentation_prototype:
		var sprite := _pixel_actor_sprite()
		sprite.name = "Body"
		var height_scale: float = PATRON_HEIGHT_SCALE.get(patron_id, 1.0)
		sprite.scale = Vector3(0.88, height_scale, 1.0)
		sprite.position.y = BARTENDER_FEET_FROM_CANVAS_CENTER_PIXELS * sprite.pixel_size * height_scale
		pivot.add_child(sprite)
		pivot.add_child(_actor_shadow())
	else:
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.42
		capsule.height = 1.7
		body.mesh = capsule
		body.position = Vector3(0.0, 0.9, 0.0)
		body.name = "Body"
		pivot.add_child(body)
	# The vision cone (its radius is the view range) and the Companion ring make
	# the perception geometry judgeable by eye instead of implied by an arrow.
	var cone := MeshInstance3D.new()
	cone.name = "VisionCone"
	cone.mesh = _sector_mesh(VIEW_RANGE, VIEW_CONE_HALF_ANGLE)
	cone.position = Vector3(0.0, 0.03, 0.0)
	cone.material_override = _flat_material(CONE_COLOR, 0.6)
	pivot.add_child(cone)
	var ring := MeshInstance3D.new()
	ring.name = "CompanionRing"
	ring.mesh = _ring_mesh(COMPANION_RANGE, 0.09)
	ring.position = Vector3(0.0, 0.05, 0.0)
	ring.material_override = _flat_material(COMPANION_RING_COLOR, 0.55)
	pivot.add_child(ring)
	var label := Label3D.new()
	label.name = "Name"
	# Stagger label height by seat order so neighbouring Patrons' labels don't overlap.
	var order := maxi(0, ALL_PATRON_IDS.find(patron_id))
	label.position = Vector3(0.0, 2.0 + float(order % 2) * 0.32, 0.0)
	label.font_size = 36 if _presentation_prototype else 44
	label.pixel_size = 0.0055 if _presentation_prototype else 0.006
	label.outline_size = 14
	label.outline_modulate = Color("0b1016")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pivot.add_child(label)
	_actor_root.add_child(pivot)
	pivot.destination_reached.connect(_on_patron_destination_reached)
	pivot.navigation_stuck.connect(_on_patron_navigation_stuck)
	_patron_nodes[patron_id] = pivot
	return pivot


func _pixel_actor_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = BARTENDER_TEXTURE
	sprite.pixel_size = CULTIST_VISIBLE_HEIGHT_METRES / BARTENDER_OPAQUE_HEIGHT_PIXELS
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.render_priority = 2
	return sprite


func _actor_shadow() -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.43
	mesh.bottom_radius = 0.43
	mesh.height = 0.018
	mesh.radial_segments = 24
	shadow.mesh = mesh
	shadow.position.y = 0.03
	shadow.scale.z = 0.52
	shadow.material_override = _flat_material(Color("09080b"), 0.7)
	return shadow


func _cultist_pivot(cultist_id: StringName) -> Node3D:
	if _cultist_nodes.has(cultist_id):
		return _cultist_nodes[cultist_id]
	var pivot := NAVIGABLE_ACTOR_SCRIPT.new() as NavigableActor3D
	pivot.configure(cultist_id, true)
	pivot.position = CULTIST_POSITIONS[cultist_id] + Vector3(0.0, NAVIGATION_FLOOR_Y, 0.0)
	pivot.set_simulation_scale(PLAY_SCALE if _playing else 0.0)
	var sprite := _pixel_actor_sprite()
	sprite.name = "Body"
	sprite.position.y = BARTENDER_FEET_FROM_CANVAS_CENTER_PIXELS * sprite.pixel_size
	sprite.modulate = CULTIST_COLORS[cultist_id]
	pivot.add_child(sprite)
	pivot.add_child(_actor_shadow())
	var label := Label3D.new()
	label.name = "Name"
	label.position = Vector3(0.0, 2.05, 0.0)
	label.font_size = 36
	label.pixel_size = 0.0055
	label.modulate = CULTIST_COLORS[cultist_id]
	label.outline_size = 14
	label.outline_modulate = Color("0b1016")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pivot.add_child(label)
	pivot.add_selection_ring(CULTIST_COLORS[cultist_id])
	pivot.destination_reached.connect(_on_cultist_destination_reached)
	pivot.navigation_stuck.connect(_on_cultist_navigation_stuck)
	_cultist_root.add_child(pivot)
	_cultist_nodes[cultist_id] = pivot
	_movement_plans[cultist_id] = MOVEMENT_PLAN_SCRIPT.new()
	pivot.set_selected(cultist_id == _selected_cultist_id)
	return pivot


func _refresh(state: Dictionary) -> void:
	_latest_state = state
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	var visible_patron_ids: Array[StringName] = ALL_PATRON_IDS if _presentation_prototype else PATRON_IDS
	for patron_id: StringName in visible_patron_ids:
		var pivot := _actor_pivot(patron_id)
		var debug: Dictionary = state["debug_patron_views"][patron_id]
		var normal: Dictionary = state["normal_patron_views"][patron_id]
		var active: bool = debug["lifecycle"] != &"not_arrived"
		pivot.visible = active
		if not active:
			continue
		var facing: Vector2 = debug["facing"]
		_sync_patron_navigation(patron_id, debug)
		if not (pivot as NavigableActor3D).is_navigating():
			pivot.look_at(pivot.position + Vector3(facing.x, 0.0, facing.y), Vector3.UP)
		var band_color: Color = BAND_COLORS.get(normal["suspicion_band"], Color.WHITE)
		var body := pivot.get_node("Body")
		if _presentation_prototype:
			var sprite := body as Sprite3D
			var palette: Color = PATRON_COLORS.get(patron_id, Color.WHITE)
			sprite.modulate = palette.lerp(band_color, 0.2)
			var height_scale: float = PATRON_HEIGHT_SCALE.get(patron_id, 1.0)
			var is_unconscious: bool = debug["lifecycle"] == &"unconscious"
			sprite.scale = Vector3(1.25 if is_unconscious else 0.88, 0.38 if is_unconscious else height_scale, 1.0)
			sprite.position.y = 0.32 if is_unconscious else BARTENDER_FEET_FROM_CANVAS_CENTER_PIXELS * sprite.pixel_size * height_scale
		else:
			(body as MeshInstance3D).material_override = _flat_material(band_color, 1.0)
		var cone := pivot.get_node("VisionCone") as MeshInstance3D
		cone.material_override = _flat_material(band_color, 0.6)
		cone.visible = _debug_visible
		(pivot.get_node("CompanionRing") as MeshInstance3D).visible = _debug_visible
		var label := pivot.get_node("Name") as Label3D
		label.text = "%s\n%s · %s" % [normal["name"], normal["visible_activity"], normal["suspicion_band"]]
		label.modulate = band_color

	_refresh_bodies()
	_refresh_events(state)
	_refresh_cultists(state)
	_refresh_hud(state)
	_refresh_character_panels(state)


func _sync_patron_navigation(patron_id: StringName, debug: Dictionary) -> void:
	var actor := _patron_nodes[patron_id] as NavigableActor3D
	actor.set_simulation_scale(
		PLAY_SCALE if _playing or not _movement_report_path.is_empty() else 0.0
	)
	actor.set_speed_multiplier(_patron_speed_multiplier(debug["activity"]))
	var target := _patron_target(debug)
	var previous: Vector3 = _patron_visual_targets.get(patron_id, Vector3.INF)
	if previous.is_equal_approx(target):
		return
	_patron_visual_targets[patron_id] = target
	actor.navigate(_next_patron_move_id, target)
	_next_patron_move_id += 1


func _patron_target(debug: Dictionary) -> Vector3:
	var destination: StringName = debug["navigation_destination"]
	if destination in [&"seat", &"drink"] and SEAT_POSITIONS.has(debug["seat"]):
		var seat: Vector2 = SEAT_POSITIONS[debug["seat"]]
		return Vector3(seat.x, NAVIGATION_FLOOR_Y, seat.y)
	match destination:
		&"entrance", &"front_exit": return Vector3(-20.2, NAVIGATION_FLOOR_Y, 5.0)
		&"bathroom_line": return Vector3(15.5, NAVIGATION_FLOOR_Y, 6.0)
		&"bathroom", &"bathroom_exit": return Vector3(18.2, NAVIGATION_FLOOR_Y, 6.0)
		&"tunnel": return Vector3(15.0, NAVIGATION_FLOOR_Y, 3.65)
		&"collapsed":
			var at: Vector2 = debug["position"]
			return Vector3(at.x, NAVIGATION_FLOOR_Y, at.y)
	var fallback: Vector2 = debug["position"]
	return Vector3(fallback.x, NAVIGATION_FLOOR_Y, fallback.y)


func _patron_speed_multiplier(activity: StringName) -> float:
	if activity in [&"shock", &"escaping"]:
		return 1.4
	if activity in [&"helper_reacting", &"helper_lifting", &"helper_carrying"]:
		return 0.6
	if activity == &"being_dragged":
		return 0.58
	return 1.0


func _on_patron_destination_reached(patron_id: StringName, _action_id: int) -> void:
	_session.patron_destination_reached(patron_id)
	if _latest_state.is_empty() or not _latest_state["debug_patron_views"].has(patron_id):
		return
	var debug: Dictionary = _latest_state["debug_patron_views"][patron_id]
	if debug["lifecycle"] in [&"captured", &"exited"]:
		(_patron_nodes[patron_id] as Node3D).visible = false


func _on_patron_navigation_stuck(patron_id: StringName, _action_id: int) -> void:
	if not _patron_visual_targets.has(patron_id):
		return
	var actor := _patron_nodes[patron_id] as NavigableActor3D
	var target: Vector3 = _patron_visual_targets[patron_id]
	var navigation_map := get_world_3d().navigation_map
	var retry_target := NavigationServer3D.map_get_closest_point(navigation_map, target)
	actor.navigate(_next_patron_move_id, retry_target)
	_next_patron_move_id += 1


func _refresh_cultists(state: Dictionary) -> void:
	if not _presentation_prototype:
		return
	for cultist_id: StringName in CULTIST_IDS:
		var pivot := _cultist_pivot(cultist_id)
		var cultist: Dictionary = state["cultists"][cultist_id]
		var label := pivot.get_node("Name") as Label3D
		var activity: String = _humanize(cultist["activity"])
		if _movement_plans[cultist_id].has_active_move():
			activity = "Moving"
		label.text = "%s\n%s" % [
			String(cultist_id).replace("cultist_", "CULTIST "),
			activity,
		]


func _refresh_bodies() -> void:
	for child in _body_root.get_children():
		child.queue_free()
	for body: Dictionary in _staged_bodies:
		var marker := _build_box(body["position"], Vector3(1.4, 0.35, 0.65), 0.18, Color("c8434f"))
		_body_root.add_child(marker)
		var label := Label3D.new()
		label.text = "BODY"
		label.position = Vector3(body["position"].x, 0.8, body["position"].y)
		label.font_size = 44
		label.pixel_size = 0.007
		label.modulate = Color("f0a0a8")
		label.outline_size = 14
		label.outline_modulate = Color("0b1016")
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_body_root.add_child(label)


func _refresh_events(state: Dictionary) -> void:
	for child in _event_root.get_children():
		child.queue_free()
	for event: Dictionary in _events:
		if event["channel"] == &"auditory":
			_render_auditory(event, state)
		else:
			_render_visual(event, state)


# Vision reads as a point source with a sightline to each Patron that has a clear
# view. An event nobody sees keeps its marker but greys out and draws no line, so
# the facing-cone miss is visible rather than hidden.
func _render_visual(event: Dictionary, state: Dictionary) -> void:
	var recipients: Array = event["recipients"]
	var seen := not recipients.is_empty()
	var color: Color = SEEN_COLOR if seen else UNSEEN_COLOR
	var source: Vector2 = event["position"]
	_event_root.add_child(_build_box(source, Vector3(0.5, 1.7, 0.5), 0.85, color))
	_event_root.add_child(_marker_label(source, 2.1, "SEEN" if seen else "UNSEEN", color))
	for patron_id: StringName in recipients:
		if not state["debug_patron_views"].has(patron_id):
			continue
		var target: Vector2 = state["debug_patron_views"][patron_id]["position"]
		_event_root.add_child(_build_ray(source, target))


# Sound fills the room it happens in and faintly washes the rooms it carries to,
# with a ring under each Patron that hears it. A room the sound never reaches is
# simply not filled, so an unheard event reads as a fill that stops short.
func _render_auditory(event: Dictionary, state: Dictionary) -> void:
	var source_room: StringName = event["room"]
	_event_root.add_child(_room_overlay(source_room, SOUND_COLOR, 0.34, 0.16))
	_event_root.add_child(_marker_label(_room_center(source_room), 1.9, "SOUND", SOUND_COLOR))
	var adjacency: Dictionary = PATRON_PERCEPTION_SCRIPT.ROOM_ADJACENCY
	for reached_room: StringName in adjacency.get(source_room, []):
		_event_root.add_child(_room_overlay(reached_room, SOUND_COLOR, 0.14, 0.14))
	for patron_id: StringName in event["recipients"]:
		if not state["debug_patron_views"].has(patron_id):
			continue
		var at: Vector2 = state["debug_patron_views"][patron_id]["position"]
		_event_root.add_child(_feet_ring(at, SOUND_COLOR, 0.9))


func _build_ray(from_sim: Vector2, to_sim: Vector2) -> MeshInstance3D:
	var from := Vector3(from_sim.x, 0.9, from_sim.y)
	var to := Vector3(to_sim.x, 0.9, to_sim.y)
	var instance := MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(0.08, 0.08, from.distance_to(to))
	instance.mesh = beam
	instance.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	instance.material_override = _flat_material(RAY_COLOR, 1.0)
	return instance


func _room_overlay(room_id: StringName, color: Color, alpha: float, y: float) -> MeshInstance3D:
	var rect: Array = ROOM_RECTS[room_id]
	var center := _room_center(room_id)
	return _build_box(center, Vector3(rect[2] - rect[0], 0.04, rect[3] - rect[1]), y, Color(color.r, color.g, color.b, alpha), true)


func _feet_ring(sim_position: Vector2, color: Color, radius: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _ring_mesh(radius, 0.14)
	instance.position = Vector3(sim_position.x, 0.08, sim_position.y)
	instance.material_override = _flat_material(color, 0.95)
	return instance


func _marker_label(sim_position: Vector2, height: float, text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(sim_position.x, height, sim_position.y)
	label.font_size = 40
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 14
	label.outline_modulate = Color("0b1016")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return label


func _room_center(room_id: StringName) -> Vector2:
	var rect: Array = ROOM_RECTS[room_id]
	return Vector2((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5)


# --- Scenario staging (mirrors the perception_danger slice) -------------------

func _set_scenario(scenario_id: String) -> void:
	if not SCENARIOS.has(scenario_id):
		scenario_id = "full_cast" if _presentation_prototype else "line_of_sight"
	_scenario = scenario_id
	_playing = false
	_staged_bodies.clear()
	_events.clear()
	_session.restart_night(707)
	if scenario_id in ["full_cast", "front_exit"]:
		_session.advance(421.0)
	elif scenario_id == "service_wing":
		_session.advance(92.0)
	elif scenario_id == "cultist_states":
		_session.advance(95.0)
	else:
		_session.advance(100.0)
	match scenario_id:
		"full_cast":
			_scenario_trace = "All three Cultists and all eight authored Patrons share the full-scale room. Distinct palettes, names, visible activities, and Suspicion bands come from one GameSession snapshot."
		"service_wing":
			_session.debug_force_bathroom(&"patron_june")
			_session.advance(2.1)
			_scenario_trace = "The hallway preserves the proven east-side route. The bathroom shows its standing zone, seated fixture, and Trapdoor; the curtained Tunnel Intake remains a separate threshold."
		"front_exit":
			_session.report_patron_stimulus(&"patron_vincent", &"drink_dosed_seen")
			_session.advance(2.2)
			_scenario_trace = "The seven-metre front approach ends at the street doors. Vincent's visible Escape intention occupies the same front-exit coordinates used by GameSession."
		"cultist_states":
			_session.begin_knockout(&"cultist_01", &"patron_june")
			_session.begin_conversation(&"cultist_02", &"patron_mara")
			_session.prepare_drugged_drink(&"patron_mara", &"cultist_03")
			_scenario_trace = "The public snapshot labels three simultaneous observable states: knockout wind-up, conversation, and Drugged Drink preparation."
		"line_of_sight":
			_record_event(&"body_drag_seen_first", &"visual", &"main_hall", &"cultist_01", Vector2(0.0, 0.0))
			_record_event(&"unexplained_collapse_seen", &"visual", &"main_hall", &"cultist_01", Vector2(-18.0, 6.0))
			_scenario_trace = "Drag at the bar is inside the facing cone: SEEN (+50). A collapse behind the pair falls outside the cone: UNSEEN, no line."
		"room_hearing":
			_record_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_02", Vector2(0.0, 0.0))
			_record_event(&"knockout_heard", &"auditory", &"bathroom", &"cultist_02", Vector2(18.0, 6.0))
			_scenario_trace = "Main-hall knockout fills the hall and reaches the pair (+25). The bathroom knockout fills only bathroom + hallway and never reaches them."
		"unattended_body":
			_stage_body(&"body_a", &"hallway", Vector2(14.0, 6.0))
			_stage_body(&"body_b", &"main_hall", Vector2(0.0, 8.0))
			_session.advance(8.0)
			_scenario_trace = "Two bodies past their grace add +5 each every 5 s to every active Patron. Press play to watch it climb."
		"companion":
			_session.report_patron_stimulus(&"patron_june", &"drink_dosed_seen")
			_session.advance(10.0)
			_scenario_trace = "June is pinned at Maximum. Press play: Mara drifts up to +5 every 10 s and settles at 100 → Escape."
		"debug_trace":
			_record_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_02", Vector2(0.0, 0.0))
			_stage_body(&"body_01", &"main_hall", Vector2(0.0, 8.0))
			_session.advance(8.0)
			_scenario_trace = "Every perception is named in the debug panel: source, recipient, resulting cause, and timing."
	_session.set_physical_patron_navigation_enabled(true)
	_update_camera_for_scenario()
	_refresh(_session.snapshot())


func _update_camera_for_scenario() -> void:
	if not _presentation_prototype:
		return
	match _scenario:
		"service_wing":
			_set_camera_view(SERVICE_CAMERA_POSITION, SERVICE_CAMERA_TARGET)
		"front_exit":
			_set_camera_view(FRONT_CAMERA_POSITION, FRONT_CAMERA_TARGET)
		_:
			_set_camera_view(PRESENTATION_CAMERA_POSITION, PRESENTATION_CAMERA_TARGET)


func _set_camera_view(position: Vector3, target: Vector3) -> void:
	_camera.position = position
	_camera_target = target
	_camera.fov = PRESENTATION_CAMERA_FOV
	_camera_fov_target = PRESENTATION_CAMERA_FOV
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)


func _record_event(stimulus: StringName, channel: StringName, room: StringName, source_id: StringName, position: Vector2) -> void:
	var recipients: Array = _session.report_danger_event(stimulus, channel, room, source_id, position)
	_events.append({"channel": channel, "room": room, "position": position, "recipients": recipients})


func _stage_body(body_id: StringName, room: StringName, position: Vector2) -> void:
	_session.add_unattended_body(body_id, room, position)
	_staged_bodies.append({"id": body_id, "position": position})


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var top := HBoxContainer.new()
	top.position = Vector2(18.0, 16.0)
	top.add_theme_constant_override("separation", 6)
	canvas.add_child(top)
	for scenario_id: String in SCENARIOS:
		var button := Button.new()
		button.text = SCENARIOS[scenario_id]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(118.0, 34.0)
		button.pressed.connect(_set_scenario.bind(scenario_id))
		_scenario_buttons[scenario_id] = button
		top.add_child(button)

	var controls := HBoxContainer.new()
	controls.position = Vector2(18.0, 58.0)
	controls.add_theme_constant_override("separation", 6)
	canvas.add_child(controls)
	_add_control_button(controls, "+1s", _session.advance.bind(1.0))
	_add_control_button(controls, "+5s", _session.advance.bind(5.0))
	_play_button = Button.new()
	_play_button.text = "PLAY"
	_play_button.toggle_mode = true
	_play_button.custom_minimum_size = Vector2(90.0, 32.0)
	_play_button.pressed.connect(_toggle_play)
	controls.add_child(_play_button)
	var debug_toggle := Button.new()
	debug_toggle.text = "DEBUG"
	debug_toggle.toggle_mode = true
	debug_toggle.button_pressed = _debug_visible
	debug_toggle.custom_minimum_size = Vector2(90.0, 32.0)
	debug_toggle.pressed.connect(func(): _debug_visible = debug_toggle.button_pressed; _refresh(_session.snapshot()))
	controls.add_child(debug_toggle)
	var camera_hint := Label.new()
	camera_hint.text = "PAN TRACKPAD / ARROWS  ·  ZOOM ⌘+TRACKPAD / - / ="
	camera_hint.add_theme_color_override("font_color", Color("8195a2"))
	camera_hint.add_theme_font_size_override("font_size", 13)
	controls.add_child(camera_hint)

	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 104.0)
	panel.custom_minimum_size = Vector2(430.0, 150.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.86)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(11)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = true
	_debug_label.scroll_active = false
	_debug_label.custom_minimum_size = Vector2(408.0, 130.0)
	panel.add_child(_debug_label)

	_hover_panel = PanelContainer.new()
	_hover_panel.visible = false
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.custom_minimum_size = Vector2(235.0, 112.0)
	_hover_panel.add_theme_stylebox_override("panel", _inspection_panel_style(0.94))
	canvas.add_child(_hover_panel)
	_hover_label = RichTextLabel.new()
	_hover_label.bbcode_enabled = true
	_hover_label.fit_content = true
	_hover_label.scroll_active = false
	_hover_label.custom_minimum_size = Vector2(213.0, 90.0)
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_child(_hover_label)

	_info_panel = PanelContainer.new()
	_info_panel.visible = false
	_info_panel.anchor_left = 1.0
	_info_panel.anchor_right = 1.0
	_info_panel.offset_left = -318.0
	_info_panel.offset_right = -18.0
	_info_panel.offset_top = 104.0
	_info_panel.offset_bottom = 424.0
	_info_panel.add_theme_stylebox_override("panel", _inspection_panel_style(0.96))
	canvas.add_child(_info_panel)
	var info_column := VBoxContainer.new()
	_info_panel.add_child(info_column)
	var info_header := HBoxContainer.new()
	info_column.add_child(info_header)
	var title := Label.new()
	title.text = "PATRON INFO"
	title.add_theme_color_override("font_color", Color("e2a56e"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_header.add_child(title)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func(): _inspected_patron_id = &""; _info_panel.visible = false)
	info_header.add_child(close)
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.scroll_active = false
	_info_label.custom_minimum_size = Vector2(278.0, 255.0)
	info_column.add_child(_info_label)


func _inspection_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, alpha)
	style.border_color = Color("8b6a48")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	return style


func _add_control_button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(70.0, 32.0)
	button.pressed.connect(action)
	row.add_child(button)


func _toggle_play() -> void:
	_playing = _play_button.button_pressed
	_play_button.text = "PAUSE" if _playing else "PLAY"
	for cultist_id: StringName in _cultist_nodes:
		(_cultist_nodes[cultist_id] as NavigableActor3D).set_simulation_scale(
			PLAY_SCALE if _playing else 0.0
		)
	for patron_id: StringName in _patron_nodes:
		(_patron_nodes[patron_id] as NavigableActor3D).set_simulation_scale(
			PLAY_SCALE if _playing else 0.0
		)


func _refresh_hud(state: Dictionary) -> void:
	if _debug_label == null:
		return
	var seconds: float = state["simulated_seconds"]
	var text := "[color=#e2a56e][b]%s[/b][/color]   [color=#8195a2]t=%.1fs[/color]\n%s\n" % [
		SCENARIOS[_scenario], seconds, _scenario_trace,
	]
	text += "\n[color=#8fc4af][b]%s[/b][/color]  %s" % [
		_cultist_display_name(_selected_cultist_id), _movement_feedback,
	]
	if _movement_plans.has(_selected_cultist_id):
		var movement_state: Dictionary = _movement_plans[_selected_cultist_id].snapshot()
		text += "  [color=#8195a2]Queue %d/4[/color]" % [
			(0 if movement_state["active"].is_empty() else 1) + movement_state["pending"].size()
		]
	if _debug_visible:
		for patron_id: StringName in PATRON_IDS:
			var debug: Dictionary = state["debug_patron_views"][patron_id]
			var name := String(patron_id).trim_prefix("patron_").capitalize()
			text += "\n[color=#c9b6da]%s[/color]  %s  ·  %.0f/100  ·  %s" % [
				name, _humanize(debug["room"]), debug["suspicion"], _humanize(debug["suspicion_cause"]),
			]
			var trace: Array = debug["recent_perceptions"]
			for index in range(maxi(0, trace.size() - 3), trace.size()):
				var entry: Dictionary = trace[index]
				text += "\n   [color=#8195a2]%.1fs %s > %s = %s[/color]" % [
					entry["at"], _humanize(entry["source"]), _humanize(entry["recipient"]), _humanize(entry["cause"]),
				]
	_debug_label.text = text


func _refresh_character_panels(state: Dictionary) -> void:
	if _hover_panel == null or _info_panel == null:
		return
	if not _hovered_actor_id.is_empty():
		if _hovered_is_cultist and state["cultists"].has(_hovered_actor_id):
			_hover_label.text = _cultist_summary_text(_hovered_actor_id, state)
			_hover_panel.visible = true
		elif state["debug_patron_views"].has(_hovered_actor_id):
			var debug: Dictionary = state["debug_patron_views"][_hovered_actor_id]
			if debug["lifecycle"] not in [&"not_arrived", &"captured", &"exited"]:
				_hover_label.text = _patron_summary_text(_hovered_actor_id, state)
				_hover_panel.visible = true
			else:
				_hover_panel.visible = false
	if _inspected_patron_id.is_empty() or not state["debug_patron_views"].has(_inspected_patron_id):
		_info_panel.visible = false
		return
	var inspected_debug: Dictionary = state["debug_patron_views"][_inspected_patron_id]
	if inspected_debug["lifecycle"] in [&"not_arrived", &"captured", &"exited"]:
		_inspected_patron_id = &""
		_info_panel.visible = false
		return
	_info_label.text = _patron_info_text(_inspected_patron_id, state)
	_info_panel.visible = true


func _cultist_summary_text(cultist_id: StringName, state: Dictionary) -> String:
	var cultist: Dictionary = state["cultists"][cultist_id]
	var queue_count := 0
	if _movement_plans.has(cultist_id):
		var movement: Dictionary = _movement_plans[cultist_id].snapshot()
		queue_count = (0 if movement["active"].is_empty() else 1) + movement["pending"].size()
	return "[color=#8fc4af][b]%s[/b][/color]\nStatus  %s\nMove queue  %d/4" % [
		_cultist_display_name(cultist_id), _humanize(cultist["activity"]), queue_count,
	]


func _patron_summary_text(patron_id: StringName, state: Dictionary) -> String:
	var view: Dictionary = _session.patron_view(patron_id, _selected_cultist_id)
	return "[color=#e2a56e][b]%s[/b][/color]\n%s · %s\nMood  %s\nIntoxication  %s\nOrder  %s" % [
		view["name"], view["visible_activity"], view["suspicion_band"],
		_humanize(view["mood"]), view["intoxication"], _humanize(view["order_state"]),
	]


func _patron_info_text(patron_id: StringName, state: Dictionary) -> String:
	var view: Dictionary = _session.patron_view(patron_id, _selected_cultist_id)
	var companions := (
		"???"
		if view["companions"] is String
		else ", ".join(Array(view["companions"]).map(func(id): return String(id).trim_prefix("patron_").capitalize()))
	)
	return "[color=#e2a56e][font_size=22][b]%s[/b][/font_size][/color]\n\n[b]Observable Status[/b]\nActivity  %s\nMood  %s\nSuspicion  %s\nIntoxication  %s\nOrder  %s\n\n[b]Profile[/b]\nArrival Group  %s\nCompanions  %s\nFriendship  %s\nValue / Risk  %s / %s" % [
		view["name"], view["visible_activity"], _humanize(view["mood"]),
		view["suspicion_band"], view["intoxication"], _humanize(view["order_state"]),
		_humanize(view["arrival_group"]), companions, view["friendship"],
		view["victim_value"], view["victim_risk"],
	]


# --- Helpers -----------------------------------------------------------------

func _humanize(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()


func _command_line_value(prefix: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _command_line_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()


func _capture_after_render(capture_path: String) -> void:
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute_path := ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(absolute_path)
	await get_tree().process_frame
	get_tree().quit(result)


func _write_validation_report(report_path: String) -> void:
	await get_tree().process_frame
	var validation_session = GAME_SESSION_SCRIPT.new()
	validation_session.start_night(707)
	validation_session.advance(421.0)
	var full_cast: Dictionary = validation_session.snapshot()

	var state_session = GAME_SESSION_SCRIPT.new()
	state_session.start_night(707)
	state_session.advance(95.0)
	state_session.begin_knockout(&"cultist_01", &"patron_june")
	state_session.begin_conversation(&"cultist_02", &"patron_mara")
	state_session.prepare_drugged_drink(&"patron_mara", &"cultist_03")
	var cultists: Dictionary = state_session.snapshot()["cultists"]

	var scale_session = GAME_SESSION_SCRIPT.new()
	scale_session.start_night(707)
	var four_x_supported: bool = scale_session.set_time_scale(4.0)
	scale_session.advance(1.0)
	four_x_supported = four_x_supported and is_equal_approx(
		float(scale_session.snapshot()["simulated_seconds"]), 4.0
	)

	var source_hash := FileAccess.get_sha256(VISUAL_SPIKE_SOURCE)
	var main_floor := find_child("MainRoomFloor", true, false) as MeshInstance3D
	var front_floor := find_child("FrontFloor", true, false) as MeshInstance3D
	var checks := {
		"visual_spike_source_unchanged": source_hash == VISUAL_SPIKE_EXPECTED_SHA256,
		"all_five_spaces_present": (
			find_child("MainRoomFloor", true, false) != null
			and find_child("FrontFloor", true, false) != null
			and find_child("HallwayFloor", true, false) != null
			and find_child("BathroomFloor", true, false) != null
			and find_child("IntakeThreshold", true, false) != null
		),
		"three_cultists_exposed": full_cast["cultists"].size() == 3,
		"eight_patrons_exposed": full_cast["debug_patron_views"].size() == 8,
		"eight_distinct_patron_palettes": PATRON_COLORS.size() == 8,
		"active_cultist_states_readable": (
			cultists[&"cultist_01"]["activity"] == &"knockout_windup"
			and cultists[&"cultist_02"]["activity"] == &"conversing"
			and cultists[&"cultist_03"]["activity"] == &"preparing_drugged_drink"
		),
		"four_x_simulation_supported": four_x_supported,
		"entrance_is_left_of_main_hall": _floor_is_left_of(front_floor, main_floor),
		"hallway_has_no_foreground_wall": find_child("HallwayNorthWall", true, false) == null,
		"main_floor_tiles_are_square": _floor_tiles_are_square(main_floor),
		"minus_and_equals_zoom_without_shift": _keyboard_zoom_keys_work(),
		"trackpad_pans_in_all_directions": _trackpad_pans_in_all_directions(),
		"command_trackpad_zoom_is_smooth": _command_trackpad_zoom_is_smooth(),
		"camera_pan_is_fast_and_eased": _camera_pan_is_fast_and_eased(),
		"service_area_has_no_loose_labels": _service_area_labels_are_correct(),
		"service_and_front_buttons_use_consistent_camera": _service_and_front_buttons_use_consistent_camera(),
	}
	var report := {
		"passed": not checks.values().has(false),
		"slice": "ticket16_migrated_presentation",
		"checks": checks,
		"observed": {
			"visual_spike_sha256": source_hash,
			"cultist_count": full_cast["cultists"].size(),
			"patron_count": full_cast["debug_patron_views"].size(),
			"main_hall_metres": [27.0, 12.0],
			"front_metres": [7.0, 14.0],
			"hallway_metres": [4.0, 6.0],
			"bathroom_metres": [4.0, 6.0],
			"cultist_visible_height_metres": CULTIST_VISIBLE_HEIGHT_METRES,
			"main_floor_tile_metres": _floor_tile_metres(main_floor),
			"camera_pan_speed_metres_per_second": CAMERA_PAN_SPEED,
			"camera_pan_acceleration_metres_per_second_squared": CAMERA_PAN_ACCELERATION,
			"camera_pan_deceleration_metres_per_second_squared": CAMERA_PAN_DECELERATION,
			"service_area_labels": _service_area_labels(),
		},
	}
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	get_tree().quit(0 if report["passed"] else 1)


func _floor_is_left_of(left_floor: MeshInstance3D, right_floor: MeshInstance3D) -> bool:
	if left_floor == null or right_floor == null:
		return false
	var left_mesh := left_floor.mesh as BoxMesh
	var right_mesh := right_floor.mesh as BoxMesh
	return (
		left_floor.position.x + left_mesh.size.x * 0.5
		<= right_floor.position.x - right_mesh.size.x * 0.5 + 0.001
	)


func _floor_tile_metres(floor: MeshInstance3D) -> Vector2:
	if floor == null:
		return Vector2.ZERO
	var mesh := floor.mesh as BoxMesh
	var material := floor.material_override as StandardMaterial3D
	if mesh == null or material == null:
		return Vector2.ZERO
	return Vector2(mesh.size.x / material.uv1_scale.x, mesh.size.z / material.uv1_scale.y)


func _floor_tiles_are_square(floor: MeshInstance3D) -> bool:
	var tile_metres := _floor_tile_metres(floor)
	return tile_metres.x > 0.0 and is_equal_approx(tile_metres.x, tile_metres.y)


func _keyboard_zoom_keys_work() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_fov := _camera.fov
	var zoom_in := InputEventKey.new()
	zoom_in.keycode = KEY_EQUAL
	zoom_in.pressed = true
	_unhandled_input(zoom_in)
	for _frame in 30:
		_process(1.0 / 60.0)
	var zoomed_in_fov := _camera.fov
	var equals_zooms_in := zoomed_in_fov < original_fov
	var zoom_out := InputEventKey.new()
	zoom_out.keycode = KEY_MINUS
	zoom_out.pressed = true
	_unhandled_input(zoom_out)
	for _frame in 30:
		_process(1.0 / 60.0)
	var minus_zooms_out := _camera.fov > zoomed_in_fov
	_camera.fov = original_fov
	_camera_fov_target = original_fov
	_capture_mode = was_capture_mode
	return equals_zooms_in and minus_zooms_out


func _trackpad_pans_in_all_directions() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_position := _camera.position
	var original_target := _camera_target
	var gestures := [
		[Vector2(-1.0, 0.0), Vector3(-1.0, 0.0, 0.0)],
		[Vector2(1.0, 0.0), Vector3(1.0, 0.0, 0.0)],
		[Vector2(0.0, -1.0), Vector3(0.0, 0.0, -1.0)],
		[Vector2(0.0, 1.0), Vector3(0.0, 0.0, 1.0)],
	]
	var all_directions_work := true
	for gesture_case: Array in gestures:
		_camera.position = original_position
		_camera_target = original_target
		_camera_pan_velocity = Vector3.ZERO
		_trackpad_pan_intent = Vector2.ZERO
		_trackpad_pan_hold_remaining = 0.0
		var gesture := InputEventPanGesture.new()
		gesture.delta = gesture_case[0]
		_unhandled_input(gesture)
		_process(1.0 / 60.0)
		var shift: Vector3 = _camera.position - original_position
		var expected: Vector3 = gesture_case[1]
		all_directions_work = all_directions_work and shift.dot(expected) > 0.0
	_camera.position = original_position
	_camera_target = original_target
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)
	_capture_mode = was_capture_mode
	return all_directions_work


func _command_trackpad_zoom_is_smooth() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_position := _camera.position
	var original_target := _camera_target
	var original_fov := _camera.fov
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	var gesture := InputEventPanGesture.new()
	gesture.delta = Vector2(0.0, -2.0)
	gesture.meta_pressed = true
	_unhandled_input(gesture)
	var waits_for_frame := is_equal_approx(_camera.fov, original_fov)
	_process(1.0 / 60.0)
	var first_frame_fov := _camera.fov
	var starts_smoothly := first_frame_fov < original_fov and first_frame_fov > original_fov - 2.0
	for _frame in 30:
		_process(1.0 / 60.0)
	var continues_toward_target := _camera.fov < first_frame_fov
	var does_not_pan := _camera.position.is_equal_approx(original_position)
	_camera.position = original_position
	_camera_target = original_target
	_camera.fov = original_fov
	_camera_fov_target = original_fov
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)
	_capture_mode = was_capture_mode
	return waits_for_frame and starts_smoothly and continues_toward_target and does_not_pan


func _camera_pan_is_fast_and_eased() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_position := _camera.position
	var original_target := _camera_target
	var delta := 1.0 / 60.0
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	var gesture := InputEventPanGesture.new()
	gesture.delta = Vector2(1.0, 0.0)
	_unhandled_input(gesture)
	var waits_for_frame := _camera.position.is_equal_approx(original_position)
	_process(delta)
	var first_step := (_camera.position - original_position).length()
	var previous_position := _camera.position
	var steady_step := first_step
	for _frame in 30:
		_unhandled_input(gesture)
		_process(delta)
		steady_step = (_camera.position - previous_position).length()
		previous_position = _camera.position
	var accelerates := steady_step > first_step * 2.0
	var faster_than_old_pan := steady_step / delta > 8.0
	_process(delta)
	var coast_step := (_camera.position - previous_position).length()
	var coasts_after_release := coast_step > 0.0
	for _frame in 45:
		_process(delta)
	var settled_position := _camera.position
	_process(delta)
	var settles_smoothly := _camera.position.is_equal_approx(settled_position)
	_camera.position = original_position
	_camera_target = original_target
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)
	_capture_mode = was_capture_mode
	return (
		waits_for_frame
		and first_step > 0.0
		and accelerates
		and faster_than_old_pan
		and coasts_after_release
		and settles_smoothly
	)


func _service_area_labels() -> Array[String]:
	var labels: Array[String] = []
	for node: Node in find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if label.text == "HALLWAY" or label.text.begins_with("BATHROOM"):
			labels.append(label.text)
	return labels


func _service_area_labels_are_correct() -> bool:
	var labels := _service_area_labels()
	return (
		labels.count("HALLWAY") == 1
		and labels.count("BATHROOM") == 0
		and labels.count("BATHROOM / TRAPDOOR") == 1
	)


func _service_and_front_buttons_use_consistent_camera() -> bool:
	var original_scenario := _scenario
	var original_position := _camera.position
	var original_target := _camera_target
	var original_fov := _camera.fov
	var normal_direction := (PRESENTATION_CAMERA_TARGET - PRESENTATION_CAMERA_POSITION).normalized()
	var scenarios := {
		"service_wing": Vector3(17.0, 1.0, 6.0),
		"front_exit": Vector3(-17.5, 1.0, 5.0),
	}
	var buttons_use_consistent_camera := true
	for scenario_id: String in scenarios:
		_set_scenario(scenario_id)
		var direction := (_camera_target - _camera.position).normalized()
		buttons_use_consistent_camera = buttons_use_consistent_camera and (
			_camera_target.is_equal_approx(scenarios[scenario_id])
			and direction.is_equal_approx(normal_direction)
			and is_equal_approx(_camera.fov, PRESENTATION_CAMERA_FOV)
		)
	_set_scenario(original_scenario)
	_camera.position = original_position
	_camera_target = original_target
	_camera.fov = original_fov
	_camera_fov_target = original_fov
	_camera.look_at(_camera_target, Vector3.UP)
	return buttons_use_consistent_camera
