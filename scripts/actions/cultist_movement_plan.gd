class_name CultistMovementPlan
extends RefCounted

const ACTION_QUEUE_SCRIPT := preload("res://scripts/actions/cultist_action_queue.gd")

var _queue = ACTION_QUEUE_SCRIPT.new()


func issue_move(destination: Vector3, append_to_queue: bool) -> int:
	var payload := {"destination": destination}
	if append_to_queue:
		return _queue.append(&"move", &"floor", INF, INF, true, payload)
	return _queue.replace(&"move", &"floor", INF, INF, true, payload)


func has_active_move() -> bool:
	var active: Dictionary = _queue.snapshot()["active"]
	return not active.is_empty() and active["name"] == &"move"


func active_destination() -> Vector3:
	var active: Dictionary = _queue.snapshot()["active"]
	if active.is_empty() or active["name"] != &"move":
		return Vector3.ZERO
	return active["payload"]["destination"]


func active_action_id() -> int:
	var active: Dictionary = _queue.snapshot()["active"]
	return -1 if active.is_empty() else int(active["id"])


func complete_active_move() -> bool:
	if not has_active_move():
		return false
	return _queue.complete_active()


func fail_active_move(reason: StringName) -> bool:
	if not has_active_move():
		return false
	return _queue.fail_active(reason)


func destination_markers() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var state := _queue.snapshot()
	if not state["active"].is_empty() and state["active"]["name"] == &"move":
		result.append(state["active"]["payload"]["destination"])
	for action: Dictionary in state["pending"]:
		if action["name"] == &"move":
			result.append(action["payload"]["destination"])
	return result


func snapshot() -> Dictionary:
	var state := _queue.snapshot()
	return {
		"active": _movement_view(state["active"]),
		"pending": state["pending"].map(_movement_view),
		"recent_events": state["recent_events"],
	}


func _movement_view(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	var result := action.duplicate(true)
	if action["name"] == &"move":
		result["destination"] = action["payload"]["destination"]
	return result
