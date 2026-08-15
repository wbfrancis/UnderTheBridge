extends Node3D

const AGENT_SCRIPT := preload("res://scripts/prototypes/navigation_stress_agent.gd")
const REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")

const DEFAULT_DURATION_SECONDS := 600.0
const STRESS_SEED := 41_904
const CAMERA_POSITION := Vector3(-28.0, 3.15, 0.0)
const CAMERA_TARGET := Vector3(1.0, 0.62, 0.0)

var _registry = REGISTRY_SCRIPT.new()
var _rng := RandomNumberGenerator.new()
var _navigation_region: NavigationRegion3D
var _actors: Dictionary = {}
var _runtime: Dictionary = {}
var _slot_positions: Dictionary = {}
var _slot_kinds: Dictionary = {}
var _slot_markers: Dictionary = {}
var _spawn_positions: Array[Vector3] = []

var _simulation_scale: float = 1.0
var _duration_seconds: float = DEFAULT_DURATION_SECONDS
var _simulated_seconds: float = 0.0
var _next_cancel_at: float = 19.0
var _next_terminal_at: float = 71.0
var _transition_index: int = 0
var _running: bool = false
var _finishing: bool = false
var _capture_started: bool = false
var _capture_path: String = ""
var _capture_at_seconds: float = 30.0
var _report_path: String = ""

var _completed_interactions: int = 0
var _cancellations: int = 0
var _terminal_transitions: int = 0
var _cleanup_failures: int = 0
var _stuck_events: int = 0
var _closest_agent_distance: float = INF
var _close_encounters: int = 0
var _invariant_violations: Array[String] = []
var _decisions_by_kind: Dictionary = {}

var _status_label: Label
var _owners_label: Label
var _last_overlay_update: float = -1.0


func _ready() -> void:
	_rng.seed = STRESS_SEED
	_read_arguments()
	_build_presentation()
	_build_navigation_geometry()
	_build_interaction_slots()
	_bake_and_start.call_deferred()


func _physics_process(delta: float) -> void:
	if not _running or _finishing:
		return
	var simulated_delta := delta * _simulation_scale
	_simulated_seconds += simulated_delta
	_update_actor_states(simulated_delta)
	_run_scheduled_transitions()
	_measure_avoidance()
	_check_registry_invariants()
	_update_overlay()

	if not _capture_started and not _capture_path.is_empty() and _simulated_seconds >= _capture_at_seconds:
		_capture_started = true
		_capture_frame.call_deferred()
	if _simulated_seconds >= _duration_seconds:
		_finish_run.call_deferred()


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stress-scale="):
			_simulation_scale = maxf(argument.trim_prefix("--stress-scale=").to_float(), 0.1)
		elif argument.begins_with("--stress-duration="):
			_duration_seconds = maxf(argument.trim_prefix("--stress-duration=").to_float(), 1.0)
		elif argument.begins_with("--report="):
			_report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-at="):
			_capture_at_seconds = maxf(argument.trim_prefix("--capture-at=").to_float(), 1.0)


func _build_presentation() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11151d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8d1dc")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 1.1
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-56.0, -24.0, 0.0)
	key_light.light_color = Color("ffe7c4")
	key_light.light_energy = 1.0
	key_light.shadow_enabled = true
	add_child(key_light)

	var camera := Camera3D.new()
	camera.position = CAMERA_POSITION
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 16.0
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)
	camera.look_at(CAMERA_TARGET, Vector3.UP)
	camera.current = true

	_build_overlay()


func _build_navigation_geometry() -> void:
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion3D"
	var navigation_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(navigation_map, 0.2)
	NavigationServer3D.map_set_cell_height(navigation_map, 0.1)
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.agent_radius = 0.4
	navigation_mesh.agent_height = 1.4
	navigation_mesh.agent_max_climb = 0.2
	navigation_mesh.agent_max_slope = 35.0
	navigation_mesh.cell_size = 0.2
	navigation_mesh.cell_height = 0.1
	navigation_mesh.region_min_size = 2.0
	_navigation_region.navigation_mesh = navigation_mesh
	add_child(_navigation_region)

	_add_box("Floor", Vector3(0.0, -0.08, 0.0), Vector3(18.0, 0.16, 12.0), Color("202a31"))
	_add_box("BackWall", Vector3(8.9, 1.0, 0.0), Vector3(0.2, 2.0, 12.0), Color("323943"))
	_add_box("NorthWall", Vector3(0.0, 1.0, -5.9), Vector3(18.0, 2.0, 0.2), Color("323943"))
	_add_box("SouthWall", Vector3(0.0, 1.0, 5.9), Vector3(18.0, 2.0, 0.2), Color("323943"))
	_add_box("Bar", Vector3(6.55, 0.52, -0.35), Vector3(0.9, 1.04, 7.5), Color("76523b"))
	_add_box("TableA", Vector3(-0.5, 0.38, -2.45), Vector3(1.0, 0.76, 1.15), Color("4d3a34"))
	_add_box("TableB", Vector3(1.3, 0.38, 2.25), Vector3(1.0, 0.76, 1.15), Color("4d3a34"))
	_add_box("CenterDivider", Vector3(2.4, 0.8, 0.0), Vector3(0.32, 1.6, 2.25), Color("3d4650"))
	_add_box("BathroomDivider", Vector3(4.5, 0.9, 4.15), Vector3(3.4, 1.8, 0.22), Color("53616d"))


func _add_box(node_name: String, position: Vector3, size: Vector3, color: Color, collision := true) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name + "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.position = position
	_navigation_region.add_child(mesh_instance)
	if not collision:
		return
	var body := StaticBody3D.new()
	body.name = node_name + "Collision"
	body.position = position
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	_navigation_region.add_child(body)


func _build_interaction_slots() -> void:
	_register_slot(&"seat_01", &"seat", Vector3(-1.45, 0.0, -3.25))
	_register_slot(&"seat_02", &"seat", Vector3(0.45, 0.0, -3.25))
	_register_slot(&"seat_03", &"seat", Vector3(-1.45, 0.0, -1.65))
	_register_slot(&"seat_04", &"seat", Vector3(0.45, 0.0, -1.65))
	_register_slot(&"seat_05", &"seat", Vector3(0.35, 0.0, 1.45))
	_register_slot(&"seat_06", &"seat", Vector3(2.25, 0.0, 1.45))
	_register_slot(&"seat_07", &"seat", Vector3(0.35, 0.0, 3.05))
	_register_slot(&"seat_08", &"seat", Vector3(2.25, 0.0, 3.05))
	_register_slot(&"bar_01", &"bar_position", Vector3(5.55, 0.0, -2.75))
	_register_slot(&"bar_02", &"bar_position", Vector3(5.55, 0.0, -0.35))
	_register_slot(&"bar_03", &"bar_position", Vector3(5.55, 0.0, 2.05))
	_register_slot(&"bathroom_occupant", &"bathroom", Vector3(6.4, 0.0, 4.85))
	_register_slot(&"bathroom_queue_01", &"bathroom_queue", Vector3(3.75, 0.0, 4.85))
	_register_slot(&"bathroom_queue_02", &"bathroom_queue", Vector3(2.65, 0.0, 4.85))
	_register_slot(&"approach_01", &"approach", Vector3(-2.2, 0.0, 0.0))
	_register_slot(&"approach_02", &"approach", Vector3(3.35, 0.0, -3.4))
	_register_slot(&"approach_03", &"approach", Vector3(3.45, 0.0, 3.25))
	_register_slot(&"approach_04", &"approach", Vector3(5.25, 0.0, 3.35))
	_register_slot(&"front_exit", &"exit", Vector3(-7.65, 0.0, 0.0))

	_spawn_positions = [
		Vector3(-7.2, 0.0, -4.5), Vector3(-7.2, 0.0, -3.55),
		Vector3(-7.2, 0.0, -2.6), Vector3(-7.2, 0.0, -1.65),
		Vector3(-7.2, 0.0, -0.7), Vector3(-7.2, 0.0, 0.7),
		Vector3(-7.2, 0.0, 1.65), Vector3(-7.2, 0.0, 2.6),
		Vector3(-7.2, 0.0, 3.55), Vector3(-6.2, 0.0, -4.5),
		Vector3(-6.2, 0.0, 4.5),
	]


func _register_slot(slot_id: StringName, kind: StringName, position: Vector3) -> void:
	_registry.register_slot(slot_id, kind)
	_slot_positions[slot_id] = position
	_slot_kinds[slot_id] = kind
	_decisions_by_kind[kind] = 0

	var marker := MeshInstance3D.new()
	marker.name = String(slot_id)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.18
	cylinder.bottom_radius = 0.18
	cylinder.height = 0.055
	var material := StandardMaterial3D.new()
	material.albedo_color = _slot_color(kind)
	material.emission_enabled = true
	material.emission = _slot_color(kind)
	material.emission_energy_multiplier = 0.35
	cylinder.material = material
	marker.mesh = cylinder
	marker.position = position + Vector3(0.0, 0.035, 0.0)
	add_child(marker)

	var label := Label3D.new()
	label.text = _slot_short_label(slot_id, kind)
	label.position = Vector3(0.0, 0.18, 0.0)
	label.font_size = 22
	label.outline_size = 7
	label.modulate = _slot_color(kind).lightened(0.25)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)
	_slot_markers[slot_id] = marker


func _bake_and_start() -> void:
	var navigation_map := get_world_3d().navigation_map
	var previous_iteration := NavigationServer3D.map_get_iteration_id(navigation_map)
	_navigation_region.bake_navigation_mesh(false)
	var wait_frames := 0
	var sample_point := Vector3(-7.0, 0.0, -4.0)
	while (
		NavigationServer3D.map_get_iteration_id(navigation_map) <= previous_iteration
		or NavigationServer3D.map_get_closest_point(navigation_map, sample_point).is_zero_approx()
	) and wait_frames < 120:
		await get_tree().physics_frame
		wait_frames += 1
	if (
		NavigationServer3D.map_get_iteration_id(navigation_map) <= previous_iteration
		or NavigationServer3D.map_get_closest_point(navigation_map, sample_point).is_zero_approx()
	):
		_invariant_violations.append("Navigation map did not synchronize")
		_finish_run()
		return

	_snap_slots_to_navigation(navigation_map)
	_spawn_agents()
	_running = true
	print("NAV_SPIKE_READY scale=%.1f duration=%.1f seed=%d polygons=%d bounds=%s waits=%d" % [
		_simulation_scale,
		_duration_seconds,
		STRESS_SEED,
		_navigation_region.navigation_mesh.get_polygon_count(),
		_navigation_region.get_bounds(),
		wait_frames,
	])
	print("NAV_SPIKE_SAMPLE spawn=%s seat=%s bathroom=%s" % [
		_spawn_positions[0], _slot_positions[&"seat_01"], _slot_positions[&"bathroom_occupant"]
	])


func _snap_slots_to_navigation(navigation_map: RID) -> void:
	for slot_id: StringName in _slot_positions:
		var snapped := NavigationServer3D.map_get_closest_point(navigation_map, _slot_positions[slot_id])
		_slot_positions[slot_id] = snapped
		var marker: MeshInstance3D = _slot_markers[slot_id]
		marker.position = snapped + Vector3(0.0, 0.035, 0.0)
	for index in _spawn_positions.size():
		_spawn_positions[index] = NavigationServer3D.map_get_closest_point(navigation_map, _spawn_positions[index])


func _spawn_agents() -> void:
	var colors: Array[Color] = [
		Color("e7a13f"), Color("c66bd6"), Color("47b8d6"),
		Color("e85d69"), Color("74c365"), Color("d9cb5c"), Color("6f8fe8"),
		Color("dc85ad"), Color("75c5b7"), Color("d88b55"), Color("a7b66b"),
	]
	for index in 11:
		var is_cultist := index < 3
		var actor_id := StringName(("cultist_%02d" if is_cultist else "patron_%02d") % (index + 1 if is_cultist else index - 2))
		var actor = AGENT_SCRIPT.new()
		add_child(actor)
		actor.global_position = _spawn_positions[index]
		actor.configure(actor_id, colors[index], is_cultist)
		actor.set_simulation_scale(_simulation_scale)
		actor.destination_reached.connect(_on_destination_reached)
		actor.stuck.connect(_on_actor_stuck)
		_actors[actor_id] = actor
		_runtime[actor_id] = {
			"state": &"waiting",
			"timer": _rng.randf_range(0.1, 1.0),
			"completed": 0,
			"is_cultist": is_cultist,
		}


func _update_actor_states(simulated_delta: float) -> void:
	for actor_id: StringName in _runtime:
		var runtime: Dictionary = _runtime[actor_id]
		var state: StringName = runtime["state"]
		if state == &"navigating":
			continue
		runtime["timer"] = float(runtime["timer"]) - simulated_delta
		if runtime["timer"] > 0.0:
			continue
		if state == &"interacting":
			_registry.release_actor(actor_id)
			_completed_interactions += 1
			runtime["completed"] = int(runtime["completed"]) + 1
			runtime["state"] = &"waiting"
			runtime["timer"] = _rng.randf_range(0.2, 1.2)
		elif state == &"departed":
			var actor = _actors[actor_id]
			actor.teleport_to(_spawn_positions[_actor_index(actor_id)])
			runtime["state"] = &"waiting"
			runtime["timer"] = 0.2
		elif state == &"waiting":
			_assign_destination(actor_id)


func _assign_destination(actor_id: StringName) -> void:
	var runtime: Dictionary = _runtime[actor_id]
	var candidates := _candidate_slots(bool(runtime["is_cultist"]))
	_shuffle_with_seed(candidates)
	for slot_id: StringName in candidates:
		if not _registry.request_slot(actor_id, slot_id):
			continue
		var actor = _actors[actor_id]
		actor.navigate_to(slot_id, _slot_positions[slot_id])
		runtime["state"] = &"navigating"
		runtime["timer"] = 0.0
		var kind: StringName = _slot_kinds[slot_id]
		_decisions_by_kind[kind] = int(_decisions_by_kind[kind]) + 1
		return
	runtime["timer"] = 1.0


func _candidate_slots(is_cultist: bool) -> Array[StringName]:
	var result: Array[StringName] = []
	for slot_id: StringName in _slot_positions:
		var kind: StringName = _slot_kinds[slot_id]
		if is_cultist or kind != &"bar_position":
			result.append(slot_id)
	return result


func _shuffle_with_seed(values: Array[StringName]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _on_destination_reached(actor_id: StringName, slot_id: StringName) -> void:
	if _registry.actor_slot(actor_id) != slot_id:
		_invariant_violations.append("%s reached %s without owning it" % [actor_id, slot_id])
		return
	var runtime: Dictionary = _runtime[actor_id]
	runtime["state"] = &"interacting"
	runtime["timer"] = _rng.randf_range(1.5, 4.5)


func _run_scheduled_transitions() -> void:
	if _simulated_seconds >= _next_cancel_at:
		_interrupt_actor(_actor_id_at(_transition_index), false)
		_transition_index += 1
		_next_cancel_at += 19.0
	if _simulated_seconds >= _next_terminal_at:
		_interrupt_actor(_actor_id_at(_transition_index + 4), true)
		_transition_index += 1
		_next_terminal_at += 71.0


func _interrupt_actor(actor_id: StringName, terminal: bool) -> void:
	var released_slot := _registry.release_actor(actor_id)
	var actor = _actors[actor_id]
	actor.cancel_navigation()
	var runtime: Dictionary = _runtime[actor_id]
	if terminal:
		_terminal_transitions += 1
		runtime["state"] = &"departed"
		runtime["timer"] = 4.0
	else:
		_cancellations += 1
		runtime["state"] = &"waiting"
		runtime["timer"] = 0.5
	if not released_slot.is_empty() and not _registry.actor_slot(actor_id).is_empty():
		_cleanup_failures += 1


func _on_actor_stuck(actor_id: StringName, _slot_id: StringName) -> void:
	_stuck_events += 1
	_registry.release_actor(actor_id)
	var actor = _actors[actor_id]
	actor.cancel_navigation()
	actor.teleport_to(_spawn_positions[_actor_index(actor_id)])
	var runtime: Dictionary = _runtime[actor_id]
	runtime["state"] = &"waiting"
	runtime["timer"] = 0.5


func _measure_avoidance() -> void:
	var actor_ids: Array = _actors.keys()
	for first_index in actor_ids.size():
		for second_index in range(first_index + 1, actor_ids.size()):
			var first_actor = _actors[actor_ids[first_index]]
			var second_actor = _actors[actor_ids[second_index]]
			var distance: float = first_actor.global_position.distance_to(second_actor.global_position)
			_closest_agent_distance = minf(_closest_agent_distance, distance)
			if distance < 0.46:
				_close_encounters += 1


func _check_registry_invariants() -> void:
	var violations: Array = _registry.snapshot()["invariant_violations"]
	for violation: String in violations:
		if violation not in _invariant_violations:
			_invariant_violations.append(violation)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(16.0, 16.0)
	panel.size = Vector2(440.0, 190.0)
	panel.color = Color(0.025, 0.035, 0.05, 0.9)
	canvas.add_child(panel)

	_status_label = Label.new()
	_status_label.position = Vector2(14.0, 10.0)
	_status_label.add_theme_color_override("font_color", Color("f3e9d4"))
	_status_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(_status_label)

	var owners_panel := ColorRect.new()
	owners_panel.position = Vector2(980.0, 16.0)
	owners_panel.size = Vector2(284.0, 320.0)
	owners_panel.color = Color(0.025, 0.035, 0.05, 0.88)
	canvas.add_child(owners_panel)

	_owners_label = Label.new()
	_owners_label.position = Vector2(12.0, 10.0)
	_owners_label.add_theme_color_override("font_color", Color("dce7ef"))
	_owners_label.add_theme_font_size_override("font_size", 12)
	owners_panel.add_child(_owners_label)


func _update_overlay() -> void:
	if _simulated_seconds - _last_overlay_update < 0.2:
		return
	_last_overlay_update = _simulated_seconds
	var repaths := _total_repaths()
	_status_label.text = (
		"TICKET #4 — 11-AGENT NAVIGATION + RESERVATIONS\n"
		+ "LONG-LENS PERSPECTIVE • NAVIGATIONAGENT3D • 2D RVO AVOIDANCE\n"
		+ "SIM %02d:%02d / 10:00   SPEED %.0fx   SEED %d\n" % [
			int(_simulated_seconds) / 60, int(_simulated_seconds) % 60, _simulation_scale, STRESS_SEED
		]
		+ "COMPLETED %d   CANCEL %d   TERMINAL %d   REPATH %d\n" % [
			_completed_interactions, _cancellations, _terminal_transitions, repaths
		]
		+ "STUCK %d   CLEANUP FAIL %d   INVARIANT FAIL %d" % [
			_stuck_events, _cleanup_failures, _invariant_violations.size()
		]
	)

	var owners_text := "EXCLUSIVE DESTINATIONS\n"
	var snapshot: Dictionary = _registry.snapshot()
	for slot_id: StringName in snapshot["slots"]:
		var owner: StringName = snapshot["slots"][slot_id]["owner"]
		owners_text += "%s  %s\n" % [String(slot_id), "—" if owner.is_empty() else String(owner)]
	_owners_label.text = owners_text


func _capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var absolute_path := ProjectSettings.globalize_path(_capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(absolute_path)
	print("NAV_SPIKE_CAPTURE path=%s result=%s" % [absolute_path, error_string(result)])


func _finish_run() -> void:
	if _finishing:
		return
	_finishing = true
	_running = false
	if not _capture_path.is_empty() and not _capture_started:
		_capture_started = true
		await _capture_frame()

	var all_actors_completed := true
	var actor_results: Dictionary = {}
	for actor_id: StringName in _runtime:
		var completed: int = _runtime[actor_id]["completed"]
		all_actors_completed = all_actors_completed and completed > 0
		actor_results[actor_id] = {
			"completed_interactions": completed,
			"repaths": _actors[actor_id].repath_count,
		}
	var passed := (
		_stuck_events == 0
		and _cleanup_failures == 0
		and _invariant_violations.is_empty()
		and all_actors_completed
	)
	var registry_snapshot: Dictionary = _registry.snapshot()
	var report := {
		"passed": passed,
		"seed": STRESS_SEED,
		"simulation_scale": _simulation_scale,
		"simulated_seconds": _simulated_seconds,
		"completed_interactions": _completed_interactions,
		"cancellations": _cancellations,
		"terminal_transitions": _terminal_transitions,
		"cleanup_failures": _cleanup_failures,
		"stuck_events": _stuck_events,
		"repaths": _total_repaths(),
		"closest_agent_distance": _closest_agent_distance,
		"close_encounters": _close_encounters,
		"invariant_violations": _invariant_violations,
		"reservation_requests": registry_snapshot["requests"],
		"reservation_rejections": registry_snapshot["rejections"],
		"reservation_releases": registry_snapshot["releases"],
		"decisions_by_kind": _decisions_by_kind,
		"actors": actor_results,
	}
	if not _report_path.is_empty():
		_write_report(report)
	print("NAV_STRESS_RESULT %s" % JSON.stringify(report))
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)


func _write_report(report: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(_report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_invariant_violations.append("Could not write report %s" % absolute_path)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()


func _total_repaths() -> int:
	var result := 0
	for actor in _actors.values():
		result += actor.repath_count
	return result


func _actor_id_at(index: int) -> StringName:
	var ids: Array = _actors.keys()
	return ids[index % ids.size()]


func _actor_index(actor_id: StringName) -> int:
	return _actors.keys().find(actor_id)


func _slot_color(kind: StringName) -> Color:
	match kind:
		&"seat": return Color("63b3d2")
		&"bar_position": return Color("e0a44f")
		&"bathroom": return Color("c96fd2")
		&"bathroom_queue": return Color("9f7adb")
		&"approach": return Color("68be78")
		&"exit": return Color("e86666")
	return Color.WHITE


func _slot_short_label(slot_id: StringName, kind: StringName) -> String:
	var suffix := String(slot_id).get_slice("_", String(slot_id).get_slice_count("_") - 1)
	match kind:
		&"seat": return "S%s" % suffix
		&"bar_position": return "B%s" % suffix
		&"bathroom": return "WC"
		&"bathroom_queue": return "Q%s" % suffix
		&"approach": return "A%s" % suffix
		&"exit": return "EXIT"
	return String(slot_id)
