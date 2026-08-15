class_name NavigationStressAgent
extends CharacterBody3D

signal destination_reached(actor_id: StringName, slot_id: StringName)
signal stuck(actor_id: StringName, slot_id: StringName)

const ARRIVAL_DISTANCE := 0.38
const REPATH_AFTER_SECONDS := 4.0
const STUCK_AFTER_SECONDS := 15.0

var actor_id: StringName
var current_slot_id: StringName = &""
var navigation_agent: NavigationAgent3D
var base_speed: float = 1.35
var simulation_scale: float = 1.0
var repath_count: int = 0

var _is_navigating: bool = false
var _target_position: Vector3
var _last_position: Vector3
var _no_progress_seconds: float = 0.0


func configure(id: StringName, color: Color, is_cultist: bool) -> void:
	actor_id = id
	name = String(id)
	base_speed = 1.5 if is_cultist else 1.3
	collision_layer = 2
	collision_mask = 3

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.26
	capsule_shape.height = 1.25
	collision.shape = capsule_shape
	collision.position.y = 0.625
	add_child(collision)

	var body := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.26
	capsule_mesh.height = 1.25
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.emission_enabled = true
	material.emission = color.darkened(0.45)
	material.emission_energy_multiplier = 0.18
	capsule_mesh.material = material
	body.mesh = capsule_mesh
	body.position.y = 0.625
	add_child(body)

	var label := Label3D.new()
	label.text = String(id).replace("patron_", "P").replace("cultist_", "C")
	label.position = Vector3(0.0, 1.48, 0.0)
	label.font_size = 32
	label.outline_size = 8
	label.modulate = Color.WHITE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

	navigation_agent = NavigationAgent3D.new()
	navigation_agent.name = "NavigationAgent3D"
	navigation_agent.radius = 0.29
	navigation_agent.height = 1.3
	navigation_agent.path_desired_distance = 0.24
	navigation_agent.target_desired_distance = ARRIVAL_DISTANCE
	navigation_agent.path_max_distance = 1.2
	navigation_agent.neighbor_distance = 2.7
	navigation_agent.max_neighbors = 10
	navigation_agent.time_horizon_agents = 0.65
	navigation_agent.avoidance_enabled = true
	navigation_agent.use_3d_avoidance = false
	navigation_agent.debug_enabled = DisplayServer.get_name() != "headless"
	navigation_agent.debug_use_custom = true
	navigation_agent.debug_path_custom_color = color.lightened(0.25)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	add_child(navigation_agent)

	_last_position = global_position
	_set_navigation_speed()


func set_simulation_scale(value: float) -> void:
	simulation_scale = value
	_set_navigation_speed()


func navigate_to(slot_id: StringName, target: Vector3) -> void:
	current_slot_id = slot_id
	_target_position = target
	_is_navigating = true
	_no_progress_seconds = 0.0
	_last_position = global_position
	navigation_agent.target_position = target


func cancel_navigation() -> void:
	_is_navigating = false
	current_slot_id = &""
	velocity = Vector3.ZERO
	if navigation_agent != null:
		navigation_agent.velocity = Vector3.ZERO


func teleport_to(target: Vector3) -> void:
	global_position = target
	_last_position = target
	velocity = Vector3.ZERO
	if navigation_agent != null:
		navigation_agent.set_velocity_forced(Vector3.ZERO)


func is_navigating() -> bool:
	return _is_navigating


func _physics_process(delta: float) -> void:
	if not _is_navigating or navigation_agent == null:
		return
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return
	if global_position.distance_to(_target_position) <= ARRIVAL_DISTANCE:
		_finish_navigation()
		return
	if navigation_agent.is_navigation_finished():
		_repath()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var desired_velocity := global_position.direction_to(next_path_position) * base_speed * simulation_scale
	desired_velocity.y = 0.0
	navigation_agent.velocity = desired_velocity
	_measure_progress(delta * simulation_scale)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _is_navigating:
		return
	velocity = safe_velocity
	velocity.y = 0.0
	move_and_slide()


func _measure_progress(simulated_delta: float) -> void:
	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	if moved >= 0.008 * simulation_scale:
		_no_progress_seconds = 0.0
		return
	_no_progress_seconds += simulated_delta
	if _no_progress_seconds >= STUCK_AFTER_SECONDS:
		_is_navigating = false
		velocity = Vector3.ZERO
		stuck.emit(actor_id, current_slot_id)
	elif _no_progress_seconds >= REPATH_AFTER_SECONDS:
		_repath()


func _repath() -> void:
	repath_count += 1
	_no_progress_seconds = 0.0
	navigation_agent.target_position = _target_position


func _finish_navigation() -> void:
	_is_navigating = false
	velocity = Vector3.ZERO
	navigation_agent.velocity = Vector3.ZERO
	var reached_slot := current_slot_id
	current_slot_id = &""
	destination_reached.emit(actor_id, reached_slot)


func _set_navigation_speed() -> void:
	if navigation_agent != null:
		navigation_agent.max_speed = base_speed * simulation_scale
