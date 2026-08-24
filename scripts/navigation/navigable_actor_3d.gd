class_name NavigableActor3D
extends CharacterBody3D

signal destination_reached(actor_id: StringName, action_id: int)
signal navigation_stuck(actor_id: StringName, action_id: int)

const PROGRESS_TRACKER_SCRIPT := preload(
	"res://scripts/navigation/navigation_progress_tracker.gd"
)

const ARRIVAL_DISTANCE := 0.38

var actor_id: StringName
var navigation_agent: NavigationAgent3D
var base_speed := 1.3
var simulation_scale := 1.0
var speed_multiplier := 1.0
var repath_count := 0
var arrival_distance := ARRIVAL_DISTANCE

var _active_action_id := -1
var _target_position := Vector3.ZERO
var _progress = PROGRESS_TRACKER_SCRIPT.new()
var _selection_ring: MeshInstance3D


func configure(id: StringName, is_cultist: bool) -> void:
	actor_id = id
	name = String(id)
	base_speed = 1.5 if is_cultist else 1.3
	arrival_distance = ARRIVAL_DISTANCE if is_cultist else 0.7
	collision_layer = 2
	# Patron-to-Patron separation is handled by RVO. Hard body collision made a
	# seated Patron permanently block the next Patron's authored seat approach.
	collision_mask = 3 if is_cultist else 1
	set_meta("actor_id", actor_id)
	set_meta("is_cultist", is_cultist)

	var collision := CollisionShape3D.new()
	collision.name = "PickingCollision"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.32
	capsule_shape.height = 1.5
	collision.shape = capsule_shape
	collision.position.y = 0.75
	add_child(collision)

	navigation_agent = NavigationAgent3D.new()
	navigation_agent.name = "NavigationAgent3D"
	navigation_agent.radius = 0.34
	navigation_agent.height = 1.5
	navigation_agent.path_desired_distance = 0.24
	navigation_agent.target_desired_distance = arrival_distance
	navigation_agent.path_max_distance = 1.2
	navigation_agent.neighbor_distance = 2.7
	navigation_agent.max_neighbors = 10
	navigation_agent.time_horizon_agents = 0.65
	navigation_agent.avoidance_enabled = true
	navigation_agent.use_3d_avoidance = false
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	add_child(navigation_agent)
	_update_max_speed()
	_progress.reset(position)


func add_selection_ring(color: Color) -> void:
	_selection_ring = MeshInstance3D.new()
	_selection_ring.name = "SelectionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	torus.material = material
	_selection_ring.mesh = torus
	_selection_ring.position.y = 0.04
	_selection_ring.scale.y = 0.08
	_selection_ring.visible = false
	add_child(_selection_ring)


func set_selected(value: bool) -> void:
	if _selection_ring != null:
		_selection_ring.visible = value


func set_simulation_scale(value: float) -> void:
	simulation_scale = maxf(value, 0.0)
	_update_max_speed()


func set_speed_multiplier(value: float) -> void:
	speed_multiplier = maxf(value, 0.0)
	_update_max_speed()


func navigate(action_id: int, target: Vector3) -> void:
	_active_action_id = action_id
	_target_position = target
	_progress.reset(global_position)
	if navigation_agent != null:
		navigation_agent.target_position = target


func cancel_navigation() -> void:
	_active_action_id = -1
	velocity = Vector3.ZERO
	if navigation_agent != null:
		navigation_agent.velocity = Vector3.ZERO


func is_navigating() -> bool:
	return _active_action_id >= 0


func active_action_id() -> int:
	return _active_action_id


func _physics_process(delta: float) -> void:
	if _active_action_id < 0 or navigation_agent == null or simulation_scale <= 0.0:
		return
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return
	if global_position.distance_to(_target_position) <= arrival_distance:
		_finish_navigation()
		return
	if navigation_agent.is_navigation_finished():
		if global_position.distance_to(_target_position) <= arrival_distance + 0.12:
			_finish_navigation()
		else:
			_repath()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var desired_velocity := global_position.direction_to(next_path_position) * base_speed
	desired_velocity *= speed_multiplier * simulation_scale
	desired_velocity.y = 0.0
	navigation_agent.velocity = desired_velocity

	match _progress.observe(global_position, delta * simulation_scale):
		&"repath":
			_repath()
		&"stuck":
			_fail_navigation()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _active_action_id < 0:
		return
	velocity = safe_velocity
	velocity.y = 0.0
	move_and_slide()


func _repath() -> void:
	repath_count += 1
	navigation_agent.target_position = _target_position


func _finish_navigation() -> void:
	var completed_action_id := _active_action_id
	_active_action_id = -1
	velocity = Vector3.ZERO
	navigation_agent.velocity = Vector3.ZERO
	destination_reached.emit(actor_id, completed_action_id)


func _fail_navigation() -> void:
	var failed_action_id := _active_action_id
	_active_action_id = -1
	velocity = Vector3.ZERO
	navigation_agent.velocity = Vector3.ZERO
	navigation_stuck.emit(actor_id, failed_action_id)


func _update_max_speed() -> void:
	if navigation_agent != null:
		navigation_agent.max_speed = base_speed * speed_multiplier * simulation_scale
