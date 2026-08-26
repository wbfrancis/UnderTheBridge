class_name AvatarMotionController
extends Node3D

## Presentation-only full-avatar motion. The parent actor supplies movement and
## logical activity facts; this node moves only its visual child. No animation
## state or event can change navigation or gameplay.

const IDLE := &"idle"
const DOING := &"doing"
const WALKING := &"walking"
const RUNNING := &"running"
const PASSIVE_BODY := &"passive_body"
const STILL_BODY := &"still_body"

const GAIT_WALK := &"walk"
const GAIT_RUN := &"run"

const BLOCKED_SETTLE_SECONDS := 0.22
const TRANSITION_SECONDS := 0.15
const DISTANCE_EPSILON := 0.0005

# Each named state has its own profile even where states share one procedural
# cycle. Later sprite-frame or activity-specific states can replace one profile
# without changing the selection seam.
const PROFILES := {
	IDLE: {
		"height": 0.014, "tilt": 0.010, "squash": 0.006,
		"cycles_per_second": 0.62, "cycles_per_metre": 0.0,
	},
	DOING: {
		"height": 0.032, "tilt": 0.022, "squash": 0.012,
		"cycles_per_second": 1.05, "cycles_per_metre": 0.0,
	},
	WALKING: {
		"height": 0.072, "tilt": 0.052, "squash": 0.024,
		"cycles_per_second": 0.0, "cycles_per_metre": 0.82,
	},
	RUNNING: {
		"height": 0.12, "tilt": 0.087, "squash": 0.038,
		"cycles_per_second": 0.0, "cycles_per_metre": 1.05,
	},
	PASSIVE_BODY: {
		"height": 0.026, "tilt": 0.028, "squash": 0.0,
		"cycles_per_second": 0.0, "cycles_per_metre": 0.72,
	},
	STILL_BODY: {
		"height": 0.0, "tilt": 0.0, "squash": 0.0,
		"cycles_per_second": 0.0, "cycles_per_metre": 0.0,
	},
}

var _actor_id: StringName
var _simulation_scale := 0.0
var _gait_intent: StringName = GAIT_WALK
var _is_navigating := false
var _is_doing := false
var _is_prone := false
var _movement_hold := 0.0
var _state: StringName = IDLE
var _phase := 0.0
var _last_parent_position := Vector3.ZERO
var _has_parent_position := false
var _transition_elapsed := TRANSITION_SECONDS
var _transition_from_position := Vector3.ZERO
var _transition_from_rotation := 0.0
var _transition_from_scale := Vector3.ONE


func configure(actor_id: StringName) -> void:
	_actor_id = actor_id
	# Stable phase offsets stop the full cast from moving in lockstep. Motion
	# strength and rate stay shared until a visible character need earns an override.
	var phase_step := absi(String(actor_id).hash()) % 997
	_phase = TAU * float(phase_step) / 997.0
	name = "VisualPivot"


func set_simulation_scale(value: float) -> void:
	_simulation_scale = maxf(value, 0.0)


func set_context(
		gait_intent: StringName,
		is_navigating: bool,
		is_doing: bool,
		is_prone: bool
) -> void:
	_gait_intent = GAIT_RUN if gait_intent == GAIT_RUN else GAIT_WALK
	if is_navigating and not _is_navigating:
		_movement_hold = BLOCKED_SETTLE_SECONDS
	_is_navigating = is_navigating
	_is_doing = is_doing
	_is_prone = is_prone


func current_state() -> StringName:
	return _state


func snapshot() -> Dictionary:
	return {
		"actor_id": _actor_id,
		"state": _state,
		"position": position,
		"rotation_z": rotation.z,
		"scale": scale,
		"phase": _phase,
	}


func _process(delta: float) -> void:
	var parent := get_parent_node_3d()
	if parent == null:
		return
	var travelled := 0.0
	if _has_parent_position:
		var shift := parent.global_position - _last_parent_position
		shift.y = 0.0
		travelled = shift.length()
	_last_parent_position = parent.global_position
	_has_parent_position = true
	advance_motion(delta, travelled)


# Public for deterministic contract tests and the review harness. Production
# calls this through _process with the parent actor's measured travel distance.
func advance_motion(delta: float, travelled_distance: float) -> void:
	if _simulation_scale <= 0.0:
		return
	var simulation_delta := maxf(delta, 0.0) * _simulation_scale
	var moved := travelled_distance > DISTANCE_EPSILON
	if moved:
		_movement_hold = BLOCKED_SETTLE_SECONDS
	else:
		_movement_hold = maxf(0.0, _movement_hold - simulation_delta)

	var next_state := select_state(
		_is_prone,
		_is_navigating and (moved or _movement_hold > 0.0),
		_gait_intent,
		_is_doing
	)
	if next_state != _state:
		_begin_transition(next_state)

	var profile: Dictionary = PROFILES[_state]
	if _state in [WALKING, RUNNING, PASSIVE_BODY]:
		_phase = fmod(
			_phase + travelled_distance * float(profile["cycles_per_metre"]) * TAU,
			TAU
		)
	else:
		_phase = fmod(
			_phase + simulation_delta * float(profile["cycles_per_second"]) * TAU,
			TAU
		)
	_apply_profile(profile, simulation_delta)


static func select_state(
		is_prone: bool,
		is_moving: bool,
		gait_intent: StringName,
		is_doing: bool
) -> StringName:
	if is_prone:
		return PASSIVE_BODY if is_moving else STILL_BODY
	if is_moving:
		return RUNNING if gait_intent == GAIT_RUN else WALKING
	if is_doing:
		return DOING
	return IDLE


func _begin_transition(next_state: StringName) -> void:
	_transition_from_position = position
	_transition_from_rotation = rotation.z
	_transition_from_scale = scale
	_transition_elapsed = 0.0
	_state = next_state


func _apply_profile(profile: Dictionary, simulation_delta: float) -> void:
	var hop := 0.5 - 0.5 * cos(_phase * 2.0)
	var rock := sin(_phase)
	var compression := cos(_phase * 2.0)
	var target_position := Vector3(0.0, float(profile["height"]) * hop, 0.0)
	var target_rotation := float(profile["tilt"]) * rock
	var squash := float(profile["squash"])
	var target_scale := Vector3(
		1.0 + squash * compression,
		1.0 - squash * compression,
		1.0
	)

	_transition_elapsed = minf(TRANSITION_SECONDS, _transition_elapsed + simulation_delta)
	var weight := 1.0
	if TRANSITION_SECONDS > 0.0:
		var linear := clampf(_transition_elapsed / TRANSITION_SECONDS, 0.0, 1.0)
		weight = linear * linear * (3.0 - 2.0 * linear)
	position = _transition_from_position.lerp(target_position, weight)
	rotation.z = lerpf(_transition_from_rotation, target_rotation, weight)
	scale = _transition_from_scale.lerp(target_scale, weight)
