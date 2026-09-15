class_name CharacterActionSystem
extends RefCounted

## Owns every character's Action Queue. Command and intent modules translate
## requests into Action specs, but they never own a second queue or lifecycle.

const QUEUE_SCRIPT := preload("res://scripts/actions/character_action_queue.gd")

var _queues: Dictionary = {}
var _kinds: Dictionary = {}
var _planner_paused: Dictionary = {}


func reset() -> void:
	_queues.clear()
	_kinds.clear()
	_planner_paused.clear()


func register_actor(actor_id: int, kind: StringName) -> bool:
	if actor_id == ActorIds.NO_ACTOR or _queues.has(actor_id):
		return false
	_queues[actor_id] = QUEUE_SCRIPT.new()
	_kinds[actor_id] = kind
	_planner_paused[actor_id] = false
	return true


func has_actor(actor_id: int) -> bool:
	return _queues.has(actor_id)


func actor_kind(actor_id: int) -> StringName:
	return StringName(_kinds.get(actor_id, &""))


func actor_ids(kind: StringName = &"") -> Array[int]:
	var result: Array[int] = []
	for actor_id: int in _queues:
		if kind.is_empty() or actor_kind(actor_id) == kind:
			result.append(actor_id)
	return result


## Restricted mutable seam for coordinators. The system remains the sole owner;
## presentation code receives snapshots and requests instead of queue objects.
func queue_for_coordinator(actor_id: int):
	return _queues.get(actor_id)


func snapshot(actor_id: int = ActorIds.NO_ACTOR) -> Dictionary:
	if actor_id != ActorIds.NO_ACTOR:
		return _queues[actor_id].snapshot() if _queues.has(actor_id) else {}
	var result: Dictionary = {}
	for id: int in _queues:
		result[id] = _queues[id].snapshot()
	return result


func active_request(actor_id: int) -> Dictionary:
	return _queues[actor_id].active_snapshot() if _queues.has(actor_id) else {}


func cancel(actor_id: int, action_id: int, debug_override: bool = false) -> Dictionary:
	if not _queues.has(actor_id):
		return {"cancelled": false, "removed": []}
	var queue = _queues[actor_id]
	if debug_override:
		var paused: Dictionary = queue.remove_paused(action_id)
		if not paused.is_empty():
			return {"cancelled": true, "removed": [paused]}
	var state: Dictionary = queue.snapshot()
	var active: Dictionary = state["active"]
	if debug_override and not active.is_empty() and int(active["id"]) == action_id:
		var removed: Array[Dictionary] = [active.duplicate(true)]
		queue.force_remove_active(&"debug_cancelled")
		return {"cancelled": true, "removed": removed}
	var result: Dictionary = queue.cancel_chain(action_id)
	return {"cancelled": not result["removed"].is_empty(), "removed": result["removed"]}


func force_complete(actor_id: int) -> bool:
	return _queues.has(actor_id) and _queues[actor_id].complete_active()


func clear(actor_id: int, debug_override: bool = false) -> Array[Dictionary]:
	if not _queues.has(actor_id):
		return []
	if debug_override:
		return _queues[actor_id].clear_all()
	var removed: Array[Dictionary] = []
	var state: Dictionary = _queues[actor_id].snapshot()
	if not state["active"].is_empty():
		var result := cancel(actor_id, int(state["active"]["id"]), debug_override)
		removed.append_array(result["removed"])
	state = _queues[actor_id].snapshot()
	for action: Dictionary in state["pending"].duplicate():
		var result := cancel(actor_id, int(action["id"]), debug_override)
		removed.append_array(result["removed"])
	return removed


func set_planner_paused(actor_id: int, paused: bool) -> bool:
	if not _queues.has(actor_id):
		return false
	_planner_paused[actor_id] = paused
	return true


func planner_is_paused(actor_id: int) -> bool:
	return bool(_planner_paused.get(actor_id, false))
