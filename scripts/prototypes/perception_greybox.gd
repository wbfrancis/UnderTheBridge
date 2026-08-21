extends Node3D

# A greybox 3-D view over the perception sim. It is a pure view: it drives
# GameSession exactly like the perception_danger slice, then reads snapshot()
# and draws each Patron's room, position, facing, and Suspicion band in space.
# The HUD keeps the slice's scenario buttons so the panel reading and the spatial
# reading reinforce each other. Nothing in the sim is modified.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const PATRON_PERCEPTION_SCRIPT := preload("res://scripts/patrons/patron_perception.gd")
const PATRON_IDS: Array[StringName] = [&"patron_june", &"patron_mara"]
const SCENARIOS := {
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
const PLAY_SCALE := 4.0

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
	&"front": [-7.0, 10.0, 7.0, 17.0],
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
var _scenario: String = "line_of_sight"
var _scenario_trace: String = ""
var _playing: bool = false
var _debug_visible: bool = true
var _capture_mode: bool = false
var _patron_nodes: Dictionary = {}
var _actor_root: Node3D
var _body_root: Node3D
var _event_root: Node3D
var _staged_bodies: Array = []
var _events: Array = []
var _scenario_buttons: Dictionary = {}
var _play_button: Button
var _debug_label: RichTextLabel


func _ready() -> void:
	_build_environment()
	_build_hud()
	_session.snapshot_changed.connect(_refresh)
	_set_scenario(_command_line_value("--stage=", "line_of_sight"))
	var capture_path := _command_line_value("--capture=")
	if not capture_path.is_empty():
		_capture_mode = true
		_capture_after_render.call_deferred(capture_path)


func _process(delta: float) -> void:
	if _playing and not _capture_mode:
		_session.advance(delta * PLAY_SCALE)


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
	add_child(_build_box(Vector2(0.0, 0.0), Vector3(6.0, 1.1, 1.4), 0.55, Color("3a2c22")))
	for seat_id: StringName in SEAT_POSITIONS:
		add_child(_build_box(SEAT_POSITIONS[seat_id], Vector3(0.9, 0.5, 0.9), 0.25, Color("223743")))

	_actor_root = Node3D.new()
	_actor_root.name = "Actors"
	add_child(_actor_root)
	_body_root = Node3D.new()
	_body_root.name = "Bodies"
	add_child(_body_root)
	_event_root = Node3D.new()
	_event_root.name = "DangerEvents"
	add_child(_event_root)

	var camera := Camera3D.new()
	camera.position = CAMERA_POSITION
	camera.fov = CAMERA_FOV
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)
	camera.current = true


func _build_room_zone(room_id: StringName) -> Node3D:
	var rect: Array = ROOM_RECTS[room_id]
	var center := Vector2((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5)
	var pad := _build_box(center, Vector3(rect[2] - rect[0], 0.06, rect[3] - rect[1]), 0.03, ROOM_COLORS[room_id], true)
	var label := Label3D.new()
	label.text = String(room_id).to_upper().replace("_", " ")
	label.position = Vector3(center.x, 1.4, center.y)
	label.font_size = 60
	label.modulate = Color("93a6b4")
	label.outline_size = 18
	label.outline_modulate = Color("0b1016")
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
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
	var pivot := Node3D.new()
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
	var order := maxi(0, PATRON_IDS.find(patron_id))
	label.position = Vector3(0.0, 2.5 + order * 0.9, 0.0)
	label.font_size = 44
	label.pixel_size = 0.006
	label.outline_size = 14
	label.outline_modulate = Color("0b1016")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pivot.add_child(label)
	_actor_root.add_child(pivot)
	_patron_nodes[patron_id] = pivot
	return pivot


func _refresh(state: Dictionary) -> void:
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	for patron_id: StringName in PATRON_IDS:
		var pivot := _actor_pivot(patron_id)
		var debug: Dictionary = state["debug_patron_views"][patron_id]
		var normal: Dictionary = state["normal_patron_views"][patron_id]
		var active: bool = debug["lifecycle"] == &"active"
		pivot.visible = active
		if not active:
			continue
		var position: Vector2 = debug["position"]
		var facing: Vector2 = debug["facing"]
		pivot.position = Vector3(position.x, 0.0, position.y)
		pivot.look_at(pivot.position + Vector3(facing.x, 0.0, facing.y), Vector3.UP)
		var band_color: Color = BAND_COLORS.get(normal["suspicion_band"], Color.WHITE)
		var body := pivot.get_node("Body") as MeshInstance3D
		body.material_override = _flat_material(band_color, 1.0)
		var cone := pivot.get_node("VisionCone") as MeshInstance3D
		cone.material_override = _flat_material(band_color, 0.6)
		var label := pivot.get_node("Name") as Label3D
		label.text = "%s\n%s" % [normal["name"], normal["suspicion_band"]]
		label.modulate = band_color

	_refresh_bodies()
	_refresh_events(state)
	_refresh_hud(state)


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
		scenario_id = "line_of_sight"
	_scenario = scenario_id
	_playing = false
	_staged_bodies.clear()
	_events.clear()
	_session.restart_night(707)
	_session.advance(100.0)
	match scenario_id:
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
	_refresh(_session.snapshot())


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
		button.custom_minimum_size = Vector2(150.0, 34.0)
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


func _add_control_button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(70.0, 32.0)
	button.pressed.connect(action)
	row.add_child(button)


func _toggle_play() -> void:
	_playing = _play_button.button_pressed
	_play_button.text = "PAUSE" if _playing else "PLAY"


func _refresh_hud(state: Dictionary) -> void:
	if _debug_label == null:
		return
	var seconds: float = state["simulated_seconds"]
	var text := "[color=#e2a56e][b]%s[/b][/color]   [color=#8195a2]t=%.1fs[/color]\n%s\n" % [
		SCENARIOS[_scenario], seconds, _scenario_trace,
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


# --- Helpers -----------------------------------------------------------------

func _humanize(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()


func _command_line_value(prefix: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _capture_after_render(capture_path: String) -> void:
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute_path := ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(absolute_path)
	await get_tree().process_frame
	get_tree().quit(result)
