class_name GrimeStore
extends RefCounted

const CREATION_MINIMUM := 2.0
const PATCH_MAXIMUM := 30.0

var _patches: Dictionary = {}
var _reservations: Dictionary = {}
var _next_event_id := 1


func clear() -> void:
	_patches.clear()
	_reservations.clear()
	_next_event_id = 1


func add_to_slot(slot: Dictionary, amount: float) -> StringName:
	var patch_id := StringName(slot.get("patch_id", slot.get("slot_id", &"")))
	if patch_id.is_empty() or amount <= 0.0:
		return &""
	if _patches.has(patch_id):
		_patches[patch_id]["clean_seconds"] = minf(
			PATCH_MAXIMUM, float(_patches[patch_id]["clean_seconds"]) + amount
		)
		return patch_id
	var patch := _new_patch(patch_id, slot, maxf(CREATION_MINIMUM, amount))
	_patches[patch_id] = patch
	return patch_id


func add_fresh(slot: Dictionary, amount: float) -> StringName:
	var patch_id := StringName("grime_event_%04d" % _next_event_id)
	_next_event_id += 1
	var fresh := slot.duplicate(true)
	fresh["patch_id"] = patch_id
	return add_to_slot(fresh, amount)


func _new_patch(patch_id: StringName, slot: Dictionary, amount: float) -> Dictionary:
	return {
		"id": patch_id,
		"room": StringName(slot.get("room", &"main_hall")),
		"center": slot.get("center", Vector2.ZERO),
		"surface_id": StringName(slot.get("surface_id", &"floor")),
		"surface_type": StringName(slot.get("surface_type", &"floor")),
		"surface_bounds": slot.get("surface_bounds", Rect2()),
		"approach_position": slot.get("approach_position", Vector2.ZERO),
		"approach_slot": StringName(slot.get("approach_slot", "approach_%s" % patch_id)),
		"clean_seconds": minf(PATCH_MAXIMUM, amount),
		"blocking_bathroom": bool(slot.get("blocking_bathroom", false)),
		"variant": absi(hash(String(patch_id))) % 4,
	}


func has(patch_id: StringName) -> bool:
	return _patches.has(patch_id)


func patch(patch_id: StringName) -> Dictionary:
	return _patches.get(patch_id, {}).duplicate(true)


func patches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = _patches.keys()
	ids.sort()
	for patch_id: StringName in ids:
		result.append(_patches[patch_id].duplicate(true))
	return result


func reserve(patch_id: StringName, cultist_id: int) -> bool:
	if not has(patch_id) or cultist_id == ActorIds.NO_ACTOR:
		return false
	var owner := int(_reservations.get(patch_id, ActorIds.NO_ACTOR))
	if owner != ActorIds.NO_ACTOR and owner != cultist_id:
		return false
	_reservations[patch_id] = cultist_id
	return true


func release(patch_id: StringName, cultist_id: int) -> bool:
	if int(_reservations.get(patch_id, ActorIds.NO_ACTOR)) != cultist_id:
		return false
	_reservations.erase(patch_id)
	return true


func owner(patch_id: StringName) -> int:
	return int(_reservations.get(patch_id, ActorIds.NO_ACTOR))


func clean_snapshot(patch_id: StringName) -> float:
	return float(_patches.get(patch_id, {}).get("clean_seconds", 0.0))


func complete_clean(patch_id: StringName, snapshot_amount: float) -> float:
	if not has(patch_id) or snapshot_amount <= 0.0:
		return 0.0
	var before := float(_patches[patch_id]["clean_seconds"])
	var remainder := maxf(0.0, before - snapshot_amount)
	if remainder <= 0.0001:
		_patches.erase(patch_id)
		_reservations.erase(patch_id)
		return before
	_patches[patch_id]["clean_seconds"] = remainder
	return before - remainder


func bathroom_blocked() -> bool:
	for patch_id: StringName in _patches:
		if bool(_patches[patch_id]["blocking_bathroom"]):
			return true
	return false


func debug_snapshot() -> Dictionary:
	return {"patches": patches(), "reservations": _reservations.duplicate(true)}
