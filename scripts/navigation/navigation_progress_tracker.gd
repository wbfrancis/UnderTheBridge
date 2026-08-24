class_name NavigationProgressTracker
extends RefCounted

const REPATH_AFTER_SECONDS := 4.0
const STUCK_AFTER_SECONDS := 15.0
const MIN_PROGRESS_METERS := 0.008

var _last_position := Vector3.ZERO
var _without_progress_seconds := 0.0
var _next_repath_seconds := REPATH_AFTER_SECONDS


func reset(position: Vector3) -> void:
	_last_position = position
	_without_progress_seconds = 0.0
	_next_repath_seconds = REPATH_AFTER_SECONDS


func observe(position: Vector3, simulated_delta: float) -> StringName:
	var moved := position.distance_to(_last_position)
	_last_position = position
	if moved >= MIN_PROGRESS_METERS:
		_without_progress_seconds = 0.0
		_next_repath_seconds = REPATH_AFTER_SECONDS
		return &"progress"

	_without_progress_seconds += maxf(simulated_delta, 0.0)
	if _without_progress_seconds >= STUCK_AFTER_SECONDS:
		return &"stuck"
	if _without_progress_seconds >= _next_repath_seconds:
		_next_repath_seconds += REPATH_AFTER_SECONDS
		return &"repath"
	return &"waiting"


func without_progress_seconds() -> float:
	return _without_progress_seconds
