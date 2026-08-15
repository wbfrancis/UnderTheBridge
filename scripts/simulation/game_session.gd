class_name GameSession
extends RefCounted

const SUPPORTED_TIME_SCALES: Array[float] = [0.0, 1.0, 2.0, 4.0]
const REPRESENTATIVE_ROLL_INTERVAL_SECONDS := 5.0
const REPRESENTATIVE_ROLLS_FOR_OUTCOME := 4

var _night_seed: int = 0
var _simulated_seconds: float = 0.0
var _time_scale: float = 1.0
var _next_representative_roll_at: float = REPRESENTATIVE_ROLL_INTERVAL_SECONDS
var _representative_rolls: Array[int] = []
var _representative_outcome: StringName = &"running"
var _rng := RandomNumberGenerator.new()


func start_night(night_seed: int) -> void:
	_night_seed = night_seed
	_simulated_seconds = 0.0
	_time_scale = 1.0
	_next_representative_roll_at = REPRESENTATIVE_ROLL_INTERVAL_SECONDS
	_representative_rolls.clear()
	_representative_outcome = &"running"
	_rng.seed = night_seed


func restart_night(night_seed: int) -> void:
	start_night(night_seed)


func set_time_scale(value: float) -> bool:
	if value not in SUPPORTED_TIME_SCALES:
		return false
	_time_scale = value
	return true


func advance(real_seconds: float) -> void:
	if real_seconds <= 0.0:
		return
	_simulated_seconds += real_seconds * _time_scale
	while _simulated_seconds >= _next_representative_roll_at:
		_representative_rolls.append(_rng.randi_range(1, 100))
		_next_representative_roll_at += REPRESENTATIVE_ROLL_INTERVAL_SECONDS
		_update_representative_outcome()


func snapshot() -> Dictionary:
	return {
		"night_seed": _night_seed,
		"simulated_seconds": _simulated_seconds,
		"time_scale": _time_scale,
		"representative_rolls": _representative_rolls.duplicate(),
		"representative_outcome": _representative_outcome,
	}


func _update_representative_outcome() -> void:
	if _representative_rolls.size() < REPRESENTATIVE_ROLLS_FOR_OUTCOME:
		return
	var favorable_rolls := 0
	for roll in _representative_rolls:
		if roll <= 50:
			favorable_rolls += 1
	_representative_outcome = &"success" if favorable_rolls >= 2 else &"failure"
