class_name InteractionRegistry
extends RefCounted

var _slots: Dictionary = {}
var _actor_slots: Dictionary = {}
var _requests: int = 0
var _rejections: int = 0
var _releases: int = 0


func register_slot(slot_id: StringName, kind: StringName) -> bool:
	if slot_id.is_empty() or _slots.has(slot_id):
		return false
	_slots[slot_id] = {"kind": kind, "owner": ActorIds.NO_ACTOR}
	return true


func request_slot(actor_id: int, slot_id: StringName) -> bool:
	_requests += 1
	if actor_id == ActorIds.NO_ACTOR or not _slots.has(slot_id):
		_rejections += 1
		return false
	if _actor_slots.has(actor_id):
		var already_owned: bool = _actor_slots[actor_id] == slot_id
		if not already_owned:
			_rejections += 1
		return already_owned
	var slot: Dictionary = _slots[slot_id]
	if int(slot["owner"]) != ActorIds.NO_ACTOR:
		_rejections += 1
		return false
	slot["owner"] = actor_id
	_slots[slot_id] = slot
	_actor_slots[actor_id] = slot_id
	return true


func release_actor(actor_id: int) -> StringName:
	if not _actor_slots.has(actor_id):
		return &""
	var slot_id: StringName = _actor_slots[actor_id]
	_actor_slots.erase(actor_id)
	var slot: Dictionary = _slots[slot_id]
	slot["owner"] = ActorIds.NO_ACTOR
	_slots[slot_id] = slot
	_releases += 1
	return slot_id


func slot_owner(slot_id: StringName) -> int:
	if not _slots.has(slot_id):
		return ActorIds.NO_ACTOR
	return _slots[slot_id]["owner"]


func actor_slot(actor_id: int) -> StringName:
	return _actor_slots.get(actor_id, &"")


func available_slots(kind: StringName = &"") -> Array[StringName]:
	var result: Array[StringName] = []
	for slot_id: StringName in _slots:
		var slot: Dictionary = _slots[slot_id]
		if int(slot["owner"]) == ActorIds.NO_ACTOR and (kind.is_empty() or slot["kind"] == kind):
			result.append(slot_id)
	return result


func snapshot() -> Dictionary:
	return {
		"slots": _slots.duplicate(true),
		"actor_slots": _actor_slots.duplicate(true),
		"requests": _requests,
		"rejections": _rejections,
		"releases": _releases,
		"invariant_violations": _find_invariant_violations(),
	}


func _find_invariant_violations() -> Array[String]:
	var violations: Array[String] = []
	var seen_actors: Dictionary = {}
	for slot_id: StringName in _slots:
		var owner: int = _slots[slot_id]["owner"]
		if owner == ActorIds.NO_ACTOR:
			continue
		if seen_actors.has(owner):
			violations.append("Actor %s owns both %s and %s" % [owner, seen_actors[owner], slot_id])
		seen_actors[owner] = slot_id
		if _actor_slots.get(owner, &"") != slot_id:
			violations.append("Slot %s and actor %s disagree" % [slot_id, owner])
	for actor_id: int in _actor_slots:
		var owned_slot: StringName = _actor_slots[actor_id]
		if not _slots.has(owned_slot) or _slots[owned_slot]["owner"] != actor_id:
			violations.append("Actor %s points to invalid slot %s" % [actor_id, owned_slot])
	return violations
