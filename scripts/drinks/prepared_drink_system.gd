class_name PreparedDrinkSystem
extends RefCounted

const CAPACITY := 3
const DRINK_TYPES: Array[StringName] = [&"wine", &"beer", &"liquor"]

var _next_number := 1
var _next_age := 1
var _drinks: Dictionary = {}


func add_drink(drink_type: StringName, drugged: bool = false) -> Dictionary:
	if drink_type not in DRINK_TYPES:
		return {"added": false, "reason": &"invalid_drink_type"}
	var evicted_id := &""
	if _drinks.size() >= CAPACITY:
		evicted_id = _oldest_unreserved_id()
		if evicted_id.is_empty():
			return {"added": false, "reason": &"bar_full"}
		_drinks.erase(evicted_id)
	var drink_id := StringName("drink_%03d" % _next_number)
	_next_number += 1
	_drinks[drink_id] = {
		"id": drink_id,
		"type": drink_type,
		"drugged": drugged,
		"age": _take_age(),
		"reserved_by": ActorIds.NO_ACTOR,
		"carried_by": ActorIds.NO_ACTOR,
	}
	return {"added": true, "drink_id": drink_id, "evicted_id": evicted_id, "reason": &""}


func can_add() -> bool:
	return _drinks.size() < CAPACITY or not _oldest_unreserved_id().is_empty()


func reserve(drink_id: StringName, cultist_id: int) -> bool:
	if not _drinks.has(drink_id) or cultist_id == ActorIds.NO_ACTOR:
		return false
	var current := int(_drinks[drink_id]["reserved_by"])
	if current != ActorIds.NO_ACTOR and current != cultist_id:
		return false
	_drinks[drink_id]["reserved_by"] = cultist_id
	return true


func release(drink_id: StringName, cultist_id: int = ActorIds.NO_ACTOR) -> bool:
	if not _drinks.has(drink_id):
		return false
	var current := int(_drinks[drink_id]["reserved_by"])
	if cultist_id != ActorIds.NO_ACTOR and current != cultist_id:
		return false
	_drinks[drink_id]["reserved_by"] = ActorIds.NO_ACTOR
	_drinks[drink_id]["carried_by"] = ActorIds.NO_ACTOR
	return true


func pick_up(drink_id: StringName, cultist_id: int) -> bool:
	if not reserve(drink_id, cultist_id):
		return false
	_drinks[drink_id]["carried_by"] = cultist_id
	return true


func drug(drink_id: StringName, cultist_id: int) -> bool:
	if not _drinks.has(drink_id) or not reserve(drink_id, cultist_id):
		return false
	_drinks[drink_id]["drugged"] = true
	_drinks[drink_id]["age"] = _take_age()
	return true


func dispose(drink_id: StringName) -> Dictionary:
	if not _drinks.has(drink_id):
		return {"disposed": false, "cultist_id": ActorIds.NO_ACTOR}
	var cultist_id := int(_drinks[drink_id]["reserved_by"])
	_drinks.erase(drink_id)
	return {"disposed": true, "cultist_id": cultist_id}


func consume(drink_id: StringName, cultist_id: int = ActorIds.NO_ACTOR) -> Dictionary:
	if not _drinks.has(drink_id):
		return {}
	var drink: Dictionary = _drinks[drink_id]
	if cultist_id != ActorIds.NO_ACTOR and int(drink["reserved_by"]) != cultist_id:
		return {}
	_drinks.erase(drink_id)
	return drink.duplicate(true)


func has(drink_id: StringName) -> bool:
	return _drinks.has(drink_id)


func drink(drink_id: StringName) -> Dictionary:
	return _drinks[drink_id].duplicate(true) if _drinks.has(drink_id) else {}


func snapshot() -> Dictionary:
	var ordered: Array[Dictionary] = []
	for drink: Dictionary in _drinks.values():
		ordered.append(drink.duplicate(true))
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["age"]) < int(right["age"])
	)
	return {"capacity": CAPACITY, "drinks": ordered}


func _oldest_unreserved_id() -> StringName:
	var result := &""
	var oldest := 0
	for drink_id: StringName in _drinks:
		var drink: Dictionary = _drinks[drink_id]
		if int(drink["reserved_by"]) != ActorIds.NO_ACTOR:
			continue
		if result.is_empty() or int(drink["age"]) < oldest:
			result = drink_id
			oldest = int(drink["age"])
	return result


func _take_age() -> int:
	var age := _next_age
	_next_age += 1
	return age
