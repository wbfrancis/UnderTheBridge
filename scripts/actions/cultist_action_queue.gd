class_name CultistActionQueue
extends RefCounted

## One ordered Action Queue for one Cultist: a single active Action and any
## number of pending Actions. The queue never rejects an Action because of its
## length. Dependent Actions carry a shared Action Chain identity so a cancel or
## a failure can remove every unfinished link of that chain at once, while a
## completed link and its gameplay effect never return to the queue.

var _next_action_id: int = 1
var _next_chain_id: int = 1
var _active: Dictionary = {}
var _pending: Array[Dictionary] = []
var _recent_events: Array[Dictionary] = []


func append(
		name: StringName,
		target_id: StringName,
		duration_seconds: float = 1.0,
		commitment_seconds: float = 0.5,
		target_is_valid: bool = true,
		payload: Dictionary = {}
) -> int:
	var action := _make_action(
		name, target_id, duration_seconds, commitment_seconds, target_is_valid, payload
	)
	_place(action)
	return action["id"]


func remove_pending(action_id: int) -> bool:
	for index in range(_pending.size()):
		if _pending[index]["id"] == action_id:
			_pending.remove_at(index)
			return true
	return false


# Writes one payload field on a queued Action. The snapshot is a deep copy, so
# owners of an Action need this seam to record approach and commitment progress.
func set_payload_value(action_id: int, key: String, value: Variant) -> bool:
	if not _active.is_empty() and _active["id"] == action_id:
		_active["payload"][key] = value
		return true
	for action in _pending:
		if action["id"] == action_id:
			action["payload"][key] = value
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
		target_is_valid: bool = true,
		payload: Dictionary = {}
) -> int:
	return _replace(
		name, target_id, duration_seconds, commitment_seconds, target_is_valid, payload, &"do_now"
	)


func replace(
		name: StringName,
		target_id: StringName,
		duration_seconds: float = 1.0,
		commitment_seconds: float = 0.5,
		target_is_valid: bool = true,
		payload: Dictionary = {}
) -> int:
	return _replace(
		name, target_id, duration_seconds, commitment_seconds, target_is_valid, payload, &"replace"
	)


# --- Action Chains -----------------------------------------------------------

## Appends one Action Chain to the tail of the queue and returns its stable
## identifiers. A single-Action spec list stays a standalone Action.
func append_chain(action_specs: Array) -> Dictionary:
	var chain_id := _chain_id_for(action_specs)
	var action_ids: Array[int] = []
	for index in range(action_specs.size()):
		var action := _action_from_spec(action_specs[index], chain_id, index, action_specs.size())
		_place(action)
		action_ids.append(int(action["id"]))
	return {"chain_id": chain_id, "action_ids": action_ids}


## Replaces the pending queue with one Action Chain. Uncommitted active work is
## cancelled first; a committed active Action stays and the chain becomes the new
## pending tail, so its already-fired effect is never undone.
func replace_with_chain(action_specs: Array) -> Dictionary:
	var removed: Array[Dictionary] = []
	for action in _pending:
		_record_event(action, &"cancelled", &"replace")
		removed.append(action.duplicate(true))
	_pending.clear()

	var chain_id := _chain_id_for(action_specs)
	var action_ids: Array[int] = []
	var actions: Array[Dictionary] = []
	for index in range(action_specs.size()):
		actions.append(_action_from_spec(action_specs[index], chain_id, index, action_specs.size()))
		action_ids.append(int(actions[index]["id"]))

	if _active.is_empty():
		for action in actions:
			_place(action)
	elif _is_active_committed():
		for action in actions:
			_pending.append(action)
	else:
		_record_event(_active, &"cancelled", &"replace")
		removed.append(_active.duplicate(true))
		_active = {}
		for action in actions:
			_place(action)
	return {"chain_id": chain_id, "action_ids": action_ids, "removed": removed}


## Moves the current active Action behind a new prerequisite while keeping one
## Action Chain identity. Used when a Patron Action reaches the head but its
## Cultist is no longer adjacent, so a Generated Move must run first.
func insert_prerequisite_for_active(action_spec: Dictionary) -> Dictionary:
	if _active.is_empty():
		return {"chain_id": -1, "action_id": -1}
	var chain_id := int(_active["chain_id"])
	if chain_id < 0:
		chain_id = _next_chain_id
		_next_chain_id += 1
		_active["chain_id"] = chain_id
	var prerequisite := _action_from_spec(action_spec, chain_id, 0, 0)
	var displaced := _active
	_active = prerequisite
	_pending.push_front(displaced)
	_reindex_chain(chain_id)
	return {"chain_id": chain_id, "action_id": int(prerequisite["id"])}


## Removes every unfinished Action that shares the target's Action Chain. A
## standalone Action removes only itself. A committed active link stays. Returns
## the removed Action snapshots so the caller can release one reservation and
## record one event per link without re-reading the queue.
func cancel_chain(action_id: int) -> Dictionary:
	var target := _find(action_id)
	if target.is_empty():
		return {"removed": [], "chain_id": -1}
	var chain_id := int(target["chain_id"])
	var removed: Array[Dictionary] = []
	if chain_id < 0:
		return _cancel_standalone(action_id)
	var kept: Array[Dictionary] = []
	for action in _pending:
		if int(action["chain_id"]) == chain_id:
			_record_event(action, &"cancelled", &"chain_cancelled")
			removed.append(action.duplicate(true))
		else:
			kept.append(action)
	_pending = kept
	if not _active.is_empty() and int(_active["chain_id"]) == chain_id and not _is_active_committed():
		_record_event(_active, &"cancelled", &"chain_cancelled")
		removed.append(_active.duplicate(true))
		_activate_next()
	return {"removed": removed, "chain_id": chain_id}


## Fails the active Action, removes its unfinished dependent links, and activates
## the next unrelated Action. Returns the removed snapshots and the failure.
func fail_active_chain(reason: StringName) -> Dictionary:
	if _active.is_empty():
		return {"removed": [], "chain_id": -1, "reason": reason}
	var chain_id := int(_active["chain_id"])
	_record_event(_active, &"failed", reason)
	var removed: Array[Dictionary] = [_active.duplicate(true)]
	if chain_id >= 0:
		var kept: Array[Dictionary] = []
		for action in _pending:
			if int(action["chain_id"]) == chain_id:
				_record_event(action, &"cancelled", &"dependency_failed")
				removed.append(action.duplicate(true))
			else:
				kept.append(action)
		_pending = kept
	_activate_next()
	return {"removed": removed, "chain_id": chain_id, "reason": reason}


func cancel_active() -> bool:
	if _active.is_empty() or _is_active_committed():
		return false
	_record_event(_active, &"cancelled", &"player_request")
	_activate_next()
	return true


func complete_active() -> bool:
	if _active.is_empty():
		return false
	_record_event(_active, &"completed")
	_activate_next()
	return true


func fail_active(reason: StringName) -> bool:
	if _active.is_empty():
		return false
	_record_event(_active, &"failed", reason)
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


# --- Internals ---------------------------------------------------------------

func _replace(
		name: StringName,
		target_id: StringName,
		duration_seconds: float,
		commitment_seconds: float,
		target_is_valid: bool,
		payload: Dictionary,
		reason: StringName
) -> int:
	var urgent_action := _make_action(
		name, target_id, duration_seconds, commitment_seconds, target_is_valid, payload
	)
	for action in _pending:
		_record_event(action, &"cancelled", reason)
	_pending.clear()

	if _active.is_empty():
		_active = urgent_action
	elif _is_active_committed():
		_pending.append(urgent_action)
	else:
		_record_event(_active, &"cancelled", reason)
		_active = urgent_action
	return urgent_action["id"]


func _place(action: Dictionary) -> void:
	if _active.is_empty():
		_active = action
	else:
		_pending.append(action)


func _chain_id_for(action_specs: Array) -> int:
	if action_specs.size() <= 1:
		return -1
	var chain_id := _next_chain_id
	_next_chain_id += 1
	return chain_id


func _action_from_spec(
		spec: Dictionary, chain_id: int, chain_index: int, chain_size: int
) -> Dictionary:
	return _make_action(
		StringName(spec.get("name", &"")),
		StringName(spec.get("target_id", &"")),
		float(spec.get("duration_seconds", 1.0)),
		float(spec.get("commitment_seconds", 0.5)),
		bool(spec.get("target_is_valid", true)),
		spec.get("payload", {}),
		chain_id,
		chain_index,
		chain_size,
		bool(spec.get("generated", false)),
	)


func _make_action(
		name: StringName,
		target_id: StringName,
		duration_seconds: float,
		commitment_seconds: float,
		target_is_valid: bool,
		payload: Dictionary = {},
		chain_id: int = -1,
		chain_index: int = 0,
		chain_size: int = 1,
		generated: bool = false
) -> Dictionary:
	var action := {
		"id": _next_action_id,
		"name": name,
		"target_id": target_id,
		"duration_seconds": maxf(duration_seconds, 0.0),
		"commitment_seconds": maxf(commitment_seconds, 0.0),
		"elapsed_seconds": 0.0,
		"target_is_valid": target_is_valid,
		"payload": payload.duplicate(true),
		"state": &"validating",
		"chain_id": chain_id,
		"chain_index": chain_index,
		"chain_size": chain_size,
		"generated": generated,
	}
	_next_action_id += 1
	return action


func _cancel_standalone(action_id: int) -> Dictionary:
	var removed: Array[Dictionary] = []
	if not _active.is_empty() and int(_active["id"]) == action_id:
		if _is_active_committed():
			return {"removed": [], "chain_id": -1}
		_record_event(_active, &"cancelled", &"player_request")
		removed.append(_active.duplicate(true))
		_activate_next()
		return {"removed": removed, "chain_id": -1}
	for index in range(_pending.size()):
		if int(_pending[index]["id"]) == action_id:
			_record_event(_pending[index], &"cancelled", &"player_request")
			removed.append(_pending[index].duplicate(true))
			_pending.remove_at(index)
			break
	return {"removed": removed, "chain_id": -1}


func _find(action_id: int) -> Dictionary:
	if not _active.is_empty() and int(_active["id"]) == action_id:
		return _active
	for action in _pending:
		if int(action["id"]) == action_id:
			return action
	return {}


# Renumbers one Action Chain across the active and pending Actions so its links
# report a contiguous index and a shared size after an insertion.
func _reindex_chain(chain_id: int) -> void:
	var members: Array[Dictionary] = []
	if not _active.is_empty() and int(_active["chain_id"]) == chain_id:
		members.append(_active)
	for action in _pending:
		if int(action["chain_id"]) == chain_id:
			members.append(action)
	for index in range(members.size()):
		members[index]["chain_index"] = index
		members[index]["chain_size"] = members.size()


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
