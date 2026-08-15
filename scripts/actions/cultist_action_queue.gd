class_name CultistActionQueue
extends RefCounted

const MAX_PENDING_ACTIONS := 3

var _next_action_id: int = 1
var _active: Dictionary = {}
var _pending: Array[Dictionary] = []
var _recent_events: Array[Dictionary] = []


func append(
		name: StringName,
		target_id: StringName,
		duration_seconds: float = 1.0,
		commitment_seconds: float = 0.5,
		target_is_valid: bool = true
) -> int:
	if not _active.is_empty() and _pending.size() >= MAX_PENDING_ACTIONS:
		return -1
	var action := _make_action(name, target_id, duration_seconds, commitment_seconds, target_is_valid)
	if _active.is_empty():
		_active = action
	else:
		_pending.append(action)
	return action["id"]


func remove_pending(action_id: int) -> bool:
	for index in range(_pending.size()):
		if _pending[index]["id"] == action_id:
			_pending.remove_at(index)
			return true
	return false


func set_target_valid(action_id: int, is_valid: bool) -> bool:
	if not _active.is_empty() and _active["id"] == action_id:
		_active["target_is_valid"] = is_valid
		return true
	for action in _pending:
		if action["id"] == action_id:
			action["target_is_valid"] = is_valid
			return true
	return false


func do_now(
		name: StringName,
		target_id: StringName,
		duration_seconds: float = 1.0,
		commitment_seconds: float = 0.5,
		target_is_valid: bool = true
) -> int:
	var urgent_action := _make_action(
		name, target_id, duration_seconds, commitment_seconds, target_is_valid
	)
	for action in _pending:
		_record_event(action, &"cancelled", &"do_now")
	_pending.clear()

	if _active.is_empty():
		_active = urgent_action
	elif _is_active_committed():
		_pending.append(urgent_action)
	else:
		_record_event(_active, &"cancelled", &"do_now")
		_active = urgent_action
	return urgent_action["id"]


func cancel_active() -> bool:
	if _active.is_empty() or _is_active_committed():
		return false
	_record_event(_active, &"cancelled", &"player_request")
	_activate_next()
	return true


func advance(simulated_seconds: float) -> void:
	if _active.is_empty() or simulated_seconds < 0.0:
		return
	_discard_invalid_actions()
	if _active.is_empty():
		return
	_active["elapsed_seconds"] += simulated_seconds
	if _active["elapsed_seconds"] >= _active["commitment_seconds"]:
		_active["state"] = &"committed"
	else:
		_active["state"] = &"executing"
	if _active["elapsed_seconds"] >= _active["duration_seconds"]:
		_record_event(_active, &"completed")
		_activate_next()


func snapshot() -> Dictionary:
	return {
		"active": _active.duplicate(true),
		"pending": _pending.duplicate(true),
		"recent_events": _recent_events.duplicate(true),
	}


func _make_action(
		name: StringName,
		target_id: StringName,
		duration_seconds: float,
		commitment_seconds: float,
		target_is_valid: bool
) -> Dictionary:
	var action := {
		"id": _next_action_id,
		"name": name,
		"target_id": target_id,
		"duration_seconds": maxf(duration_seconds, 0.0),
		"commitment_seconds": maxf(commitment_seconds, 0.0),
		"elapsed_seconds": 0.0,
		"target_is_valid": target_is_valid,
		"state": &"validating",
	}
	_next_action_id += 1
	return action


func _is_active_committed() -> bool:
	return not _active.is_empty() and (
		_active["state"] == &"committed"
		or _active["elapsed_seconds"] >= _active["commitment_seconds"]
	)


func _activate_next() -> void:
	if _pending.is_empty():
		_active = {}
		return
	_active = _pending.pop_front()


func _discard_invalid_actions() -> void:
	while not _active.is_empty() and not _active["target_is_valid"]:
		_record_event(_active, &"failed", &"invalid_target")
		_activate_next()


func _record_event(action: Dictionary, state: StringName, reason: StringName = &"") -> void:
	_recent_events.append({
		"id": action["id"],
		"name": action["name"],
		"state": state,
		"reason": reason,
	})
