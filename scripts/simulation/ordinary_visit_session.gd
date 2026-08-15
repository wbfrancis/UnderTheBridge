class_name OrdinaryVisitSession
extends RefCounted

signal snapshot_changed(snapshot: Dictionary)

const INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")
const ORDER_SYSTEM_SCRIPT := preload("res://scripts/orders/order_system.gd")
const STEP_SECONDS := 0.1
const GROUP_ID := &"arrival_group_pair_01"
const BATHROOM_SLOT := &"bathroom_occupant"
const DEPARTURE_AFTER_SEATED_SECONDS := 540.0
const DRINK_SECONDS := 30.0
const INTOXICATION_DECAY_SECONDS := 240.0
const BATHROOM_CHECK_SECONDS := 5.0

var _seed: int = 0
var _rng := RandomNumberGenerator.new()
var _simulated_seconds: float = 0.0
var _seated_at: float = -1.0
var _patrons: Dictionary = {}
var _seat_owners: Dictionary = {}
var _interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
var _order_system = ORDER_SYSTEM_SCRIPT.new()
var _events: Array[Dictionary] = []


func start(seed: int = 707) -> void:
	_seed = seed
	_rng.seed = seed
	_simulated_seconds = 0.0
	_seated_at = -1.0
	_events.clear()
	_seat_owners = {&"seat_01": &"", &"seat_02": &""}
	_interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
	_interaction_registry.register_slot(BATHROOM_SLOT, &"bathroom")
	_order_system = ORDER_SYSTEM_SCRIPT.new()
	_patrons = {
		&"patron_june": _new_patron(&"patron_june", "June", [&"patron_mara"], 75.0),
		&"patron_mara": _new_patron(&"patron_mara", "Mara", [&"patron_june"], 45.0),
	}
	_record(&"arrival_group_arrived", GROUP_ID)
	_emit_snapshot()


func advance(simulated_seconds: float) -> void:
	if simulated_seconds <= 0.0:
		return
	var remaining := simulated_seconds
	while remaining > 0.0001:
		var step := minf(STEP_SECONDS, remaining)
		_simulated_seconds += step
		for patron_id: StringName in _patrons:
			_advance_patron(patron_id, step)
		_try_group_departure()
		remaining -= step
	_emit_snapshot()


func restart(seed: int = _seed) -> void:
	start(seed)


func normal_patron_view(patron_id: StringName, selected_cultist_id: StringName = &"cultist_01") -> Dictionary:
	if not _patrons.has(patron_id):
		return {}
	var patron: Dictionary = _patrons[patron_id]
	return {
		"id": patron_id,
		"name": patron["name"],
		"visible_activity": _visible_activity(patron["activity"]),
		"mood": "content",
		"suspicion_band": "Calm",
		"intoxication": _intoxication_label(patron["intoxication"]),
		"arrival_group": GROUP_ID,
		"companions": patron["companions"].duplicate(),
		"friendship": _friendship_band(patron["friendship"].get(selected_cultist_id, 0)),
		"order_state": _patron_order_state(patron),
		"known_drugged_drink": "None",
		"victim_value": "Ordinary",
		"victim_risk": "Low",
	}


func debug_patron_view(patron_id: StringName) -> Dictionary:
	if not _patrons.has(patron_id):
		return {}
	var patron: Dictionary = _patrons[patron_id]
	var probability := bathroom_probability(float(patron["bladder"]))
	return {
		"id": patron_id,
		"bladder": patron["bladder"],
		"bathroom_probability": probability,
		"next_bathroom_check_in": maxf(0.0, float(patron["next_bathroom_check_at"]) - _simulated_seconds) if patron["bathroom_checks_active"] else -1.0,
		"intoxication_level": patron["intoxication"],
		"intoxication_decay_in": patron["intoxication_decay_in"],
		"mood_value": 75,
		"suspicion": 0,
		"suspicion_cause": &"none",
		"friendship": patron["friendship"].duplicate(true),
		"lifecycle": patron["lifecycle"],
		"activity": patron["activity"],
		"seat": patron["seat"],
		"reservation": _interaction_registry.actor_slot(patron_id),
		"navigation_destination": patron["navigation_destination"],
		"night_seed": _seed,
		"recent_bathroom_rolls": patron["recent_bathroom_rolls"].duplicate(true),
	}


func snapshot() -> Dictionary:
	var normal_views: Dictionary = {}
	var debug_views: Dictionary = {}
	for patron_id: StringName in _patrons:
		normal_views[patron_id] = normal_patron_view(patron_id)
		debug_views[patron_id] = debug_patron_view(patron_id)
	return {
		"seed": _seed,
		"simulated_seconds": _simulated_seconds,
		"group_id": GROUP_ID,
		"seated_at": _seated_at,
		"seat_owners": _seat_owners.duplicate(true),
		"bathroom_owner": _interaction_registry.slot_owner(BATHROOM_SLOT),
		"normal_views": normal_views,
		"debug_views": debug_views,
		"orders": _order_system.snapshot(),
		"events": _events.duplicate(true),
	}


static func bathroom_probability(bladder: float) -> float:
	if bladder < 50.0:
		return 0.0
	return clampf(1.0 + 89.0 * ((bladder - 50.0) / 50.0), 1.0, 90.0)


func _new_patron(id: StringName, display_name: String, companions: Array[StringName], bladder_gain: float) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"companions": companions,
		"lifecycle": &"active",
		"activity": &"entering",
		"activity_elapsed": 0.0,
		"seat": &"",
		"order_id": &"",
		"bladder": 0.0,
		"bladder_gain": bladder_gain,
		"intoxication": 0,
		"intoxication_decay_in": -1.0,
		"bathroom_checks_active": false,
		"next_bathroom_check_at": -1.0,
		"recent_bathroom_rolls": [],
		"navigation_destination": &"seat",
		"friendship": {&"cultist_01": 0, &"cultist_02": 0, &"cultist_03": 0},
	}


func _advance_patron(patron_id: StringName, delta: float) -> void:
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] == &"exited":
		return
	patron["activity_elapsed"] += delta
	_advance_intoxication(patron_id, patron, delta)
	match patron["activity"]:
		&"entering":
			if patron["activity_elapsed"] >= 1.0:
				_assign_seat(patron_id, patron)
		&"awaiting_drink":
			var service_delay := 9.0 if patron_id == &"patron_june" else 13.0
			if patron["activity_elapsed"] >= service_delay:
				_serve_patron(patron_id, patron)
		&"drinking":
			if patron["activity_elapsed"] >= DRINK_SECONDS:
				_finish_drink(patron_id, patron)
		&"socializing":
			_advance_bathroom_checks(patron_id, patron)
		&"entering_bathroom":
			if patron["activity_elapsed"] >= 2.0:
				_set_activity(patron, &"seated_bathroom_use", &"bathroom")
				_record(&"bathroom_seated", patron_id)
		&"seated_bathroom_use":
			if patron["activity_elapsed"] >= 8.0:
				patron["bladder"] = 0.0
				_set_activity(patron, &"standing_bathroom_exit", &"bathroom_exit")
				_record(&"bladder_emptied", patron_id)
		&"standing_bathroom_exit":
			if patron["activity_elapsed"] >= 3.0:
				_interaction_registry.release_actor(patron_id)
				_set_activity(patron, &"socializing", &"seat")
				_record(&"bathroom_visit_completed", patron_id)
	_patrons[patron_id] = patron


func _assign_seat(patron_id: StringName, patron: Dictionary) -> void:
	for seat_id: StringName in _seat_owners:
		if StringName(_seat_owners[seat_id]).is_empty():
			_seat_owners[seat_id] = patron_id
			patron["seat"] = seat_id
			_set_activity(patron, &"awaiting_drink", &"seat")
			patron["order_id"] = _order_system.create_order(patron_id, _simulated_seconds)
			if _seated_at < 0.0:
				_seated_at = _simulated_seconds
			_record(&"seat_acquired", patron_id, {"seat": seat_id, "order_id": patron["order_id"]})
			return


func _serve_patron(patron_id: StringName, patron: Dictionary) -> void:
	if _order_system.serve_order(patron["order_id"], _simulated_seconds):
		_set_activity(patron, &"drinking", &"drink")
		_record(&"order_served", patron_id, {"order_id": patron["order_id"]})


func _finish_drink(patron_id: StringName, patron: Dictionary) -> void:
	patron["bladder"] = minf(100.0, float(patron["bladder"]) + float(patron["bladder_gain"]))
	patron["intoxication"] = mini(3, int(patron["intoxication"]) + 1)
	patron["intoxication_decay_in"] = INTOXICATION_DECAY_SECONDS
	_set_activity(patron, &"socializing", &"seat")
	if patron["bladder"] >= 50.0:
		patron["bathroom_checks_active"] = true
		patron["next_bathroom_check_at"] = _simulated_seconds + BATHROOM_CHECK_SECONDS
	_record(&"drink_completed", patron_id, {"bladder": patron["bladder"], "intoxication": patron["intoxication"]})


func _advance_bathroom_checks(patron_id: StringName, patron: Dictionary) -> void:
	if not patron["bathroom_checks_active"]:
		return
	while _simulated_seconds + 0.0001 >= float(patron["next_bathroom_check_at"]):
		var probability := bathroom_probability(float(patron["bladder"]))
		var roll := _rng.randf_range(0.0, 100.0)
		var roll_event := {"at": patron["next_bathroom_check_at"], "roll": roll, "probability": probability}
		patron["recent_bathroom_rolls"].append(roll_event)
		_record(&"bathroom_check", patron_id, roll_event)
		patron["next_bathroom_check_at"] = float(patron["next_bathroom_check_at"]) + BATHROOM_CHECK_SECONDS
		if roll <= probability and _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
			patron["bathroom_checks_active"] = false
			_set_activity(patron, &"entering_bathroom", &"bathroom")
			_record(&"bathroom_chosen", patron_id, {"roll": roll, "probability": probability})
			return


func _advance_intoxication(patron_id: StringName, patron: Dictionary, delta: float) -> void:
	if int(patron["intoxication"]) <= 0:
		return
	patron["intoxication_decay_in"] = float(patron["intoxication_decay_in"]) - delta
	while int(patron["intoxication"]) > 0 and float(patron["intoxication_decay_in"]) <= 0.0:
		patron["intoxication"] = int(patron["intoxication"]) - 1
		_record(&"intoxication_decayed", patron_id, {"level": patron["intoxication"]})
		patron["intoxication_decay_in"] += INTOXICATION_DECAY_SECONDS
	if int(patron["intoxication"]) == 0:
		patron["intoxication_decay_in"] = -1.0


func _try_group_departure() -> void:
	if _seated_at < 0.0 or _simulated_seconds < _seated_at + DEPARTURE_AFTER_SEATED_SECONDS:
		return
	var active_patrons := 0
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] == &"exited":
			continue
		active_patrons += 1
		if patron["activity"] not in [&"socializing", &"awaiting_drink"]:
			return
	if active_patrons == 0:
		return
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] == &"exited":
			continue
		patron["lifecycle"] = &"exited"
		_set_activity(patron, &"normal_departure", &"front_exit")
		if not StringName(patron["seat"]).is_empty():
			_seat_owners[patron["seat"]] = &""
		_patrons[patron_id] = patron
		_record(&"normal_departure", patron_id)


func _set_activity(patron: Dictionary, activity: StringName, destination: StringName) -> void:
	patron["activity"] = activity
	patron["activity_elapsed"] = 0.0
	patron["navigation_destination"] = destination


func _patron_order_state(patron: Dictionary) -> StringName:
	if StringName(patron["order_id"]).is_empty():
		return &"none"
	var order: Dictionary = _order_system.order_snapshot(patron["order_id"])
	return order.get("state", &"none")


func _visible_activity(activity: StringName) -> String:
	var labels := {
		&"entering": "Arriving",
		&"awaiting_drink": "Waiting for drink",
		&"drinking": "Drinking",
		&"socializing": "Socializing",
		&"entering_bathroom": "Going to bathroom",
		&"seated_bathroom_use": "Using bathroom",
		&"standing_bathroom_exit": "Leaving bathroom",
		&"normal_departure": "Normal Departure",
	}
	return labels.get(activity, "Present")


func _intoxication_label(level: int) -> String:
	return ["Sober", "Buzzed", "Drunk", "Max Drunk"][clampi(level, 0, 3)]


func _friendship_band(value: int) -> String:
	if value >= 75:
		return "Trusted"
	if value >= 50:
		return "Friendly"
	if value >= 25:
		return "Familiar"
	return "Unknown"


func _record(event_name: StringName, actor_id: StringName, details: Dictionary = {}) -> void:
	_events.append({"at": _simulated_seconds, "event": event_name, "actor_id": actor_id, "details": details.duplicate(true)})


func _emit_snapshot() -> void:
	snapshot_changed.emit(snapshot())
