class_name OrdinaryVisitSession
extends RefCounted

signal snapshot_changed(snapshot: Dictionary)

const INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")
const ORDER_SYSTEM_SCRIPT := preload("res://scripts/orders/order_system.gd")
const PATRON_SUSPICION_SCRIPT := preload("res://scripts/patrons/patron_suspicion.gd")
const STEP_SECONDS := 0.1
const GROUP_ID := &"arrival_group_pair_01"
const BATHROOM_SLOT := &"bathroom_occupant"
const DEPARTURE_AFTER_SEATED_SECONDS := 540.0
const DRINK_SECONDS := 30.0
const INTOXICATION_DECAY_SECONDS := 240.0
const BATHROOM_CHECK_SECONDS := 5.0
const CULTIST_IDS: Array[StringName] = [&"cultist_01", &"cultist_02", &"cultist_03"]
const CAPTURE_ACTIONS: Array[StringName] = [
	&"activate_trapdoor",
	&"prepare_drugged_drink",
	&"knockout",
	&"drag_body",
	&"friendship_capture",
	&"rescue_persuasion",
]
const FULL_NIGHT_GROUP_DEFINITIONS: Array[Dictionary] = [
	{
		"id": &"arrival_group_pair_01",
		"label": "June + Mara",
		"arrival_at": 90.0,
		"patrons": [&"patron_june", &"patron_mara"],
	},
	{
		"id": &"arrival_group_solo_01",
		"label": "Elias",
		"arrival_at": 180.0,
		"patrons": [&"patron_elias"],
	},
	{
		"id": &"arrival_group_trio_01",
		"label": "Ruth + Walter + Nell",
		"arrival_at": 300.0,
		"patrons": [&"patron_ruth", &"patron_walter", &"patron_nell"],
	},
	{
		"id": &"arrival_group_pair_02",
		"label": "Vincent + Clara",
		"arrival_at": 420.0,
		"patrons": [&"patron_vincent", &"patron_clara"],
	},
]
const FULL_NIGHT_PATRON_DEFINITIONS: Array[Dictionary] = [
	{
		"id": &"patron_june", "name": "June", "group_id": &"arrival_group_pair_01",
		"companions": [&"patron_mara"], "bladder_gain": 75.0, "service_delay": 9.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
	{
		"id": &"patron_mara", "name": "Mara", "group_id": &"arrival_group_pair_01",
		"companions": [&"patron_june"], "bladder_gain": 45.0, "service_delay": 13.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
	{
		"id": &"patron_elias", "name": "Elias", "group_id": &"arrival_group_solo_01",
		"companions": [], "bladder_gain": 60.0, "service_delay": 10.0,
		"victim_value": "Promising", "victim_risk": "Low",
	},
	{
		"id": &"patron_ruth", "name": "Ruth", "group_id": &"arrival_group_trio_01",
		"companions": [&"patron_walter", &"patron_nell"], "bladder_gain": 55.0,
		"service_delay": 9.0, "victim_value": "Ordinary", "victim_risk": "Medium",
	},
	{
		"id": &"patron_walter", "name": "Walter", "group_id": &"arrival_group_trio_01",
		"companions": [&"patron_ruth", &"patron_nell"], "bladder_gain": 70.0,
		"service_delay": 12.0, "victim_value": "Ordinary", "victim_risk": "Medium",
	},
	{
		"id": &"patron_nell", "name": "Nell", "group_id": &"arrival_group_trio_01",
		"companions": [&"patron_ruth", &"patron_walter"], "bladder_gain": 40.0,
		"service_delay": 15.0, "victim_value": "Ordinary", "victim_risk": "Medium",
	},
	{
		"id": &"patron_vincent", "name": "Vincent", "group_id": &"arrival_group_pair_02",
		"companions": [&"patron_clara"], "bladder_gain": 65.0, "service_delay": 11.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
	{
		"id": &"patron_clara", "name": "Clara", "group_id": &"arrival_group_pair_02",
		"companions": [&"patron_vincent"], "bladder_gain": 50.0, "service_delay": 14.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
]

var _seed: int = 0
var _rng := RandomNumberGenerator.new()
var _simulated_seconds: float = 0.0
var _seated_at: float = -1.0
var _full_night: bool = false
var _closing: bool = false
var _patrons: Dictionary = {}
var _groups: Dictionary = {}
var _seat_owners: Dictionary = {}
var _interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
var _order_system = ORDER_SYSTEM_SCRIPT.new()
var _events: Array[Dictionary] = []
var _autonomy_events: Array[Dictionary] = []
var _next_service_cultist_index: int = 0
var _suspicion_states: Dictionary = {}


func start(seed: int = 707, full_night: bool = false) -> void:
	_seed = seed
	_rng.seed = seed
	_simulated_seconds = 0.0
	_seated_at = -1.0
	_full_night = full_night
	_closing = false
	_events.clear()
	_autonomy_events.clear()
	_next_service_cultist_index = 0
	_seat_owners.clear()
	var seat_count := 8 if full_night else 2
	for index in range(seat_count):
		_seat_owners[StringName("seat_%02d" % (index + 1))] = &""
	_interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
	_interaction_registry.register_slot(BATHROOM_SLOT, &"bathroom")
	_order_system = ORDER_SYSTEM_SCRIPT.new()
	_patrons.clear()
	_groups.clear()
	if full_night:
		_initialize_full_night_cast()
	else:
		_initialize_legacy_pair()
	_suspicion_states.clear()
	for patron_id: StringName in _patrons:
		_suspicion_states[patron_id] = PATRON_SUSPICION_SCRIPT.new()
	_emit_snapshot()


func advance(simulated_seconds: float) -> void:
	if simulated_seconds <= 0.0:
		return
	var remaining := simulated_seconds
	while remaining > 0.0001:
		var step := minf(STEP_SECONDS, remaining)
		_simulated_seconds += step
		_activate_due_groups()
		for patron_id: StringName in _patrons:
			_advance_patron(patron_id, step)
		_try_group_departures()
		remaining -= step
	_emit_snapshot()


func begin_closing() -> void:
	if _closing:
		return
	_closing = true
	_record(&"closing_started", &"night")
	_try_group_departures()
	_emit_snapshot()


func finish_night() -> void:
	_closing = true
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"active":
			continue
		_depart_patron(patron_id, patron, &"night_ended")
	_interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
	_interaction_registry.register_slot(BATHROOM_SLOT, &"bathroom")
	_emit_snapshot()


func restart(seed: int = _seed, full_night: bool = _full_night) -> void:
	start(seed, full_night)


func apply_suspicion_stimulus(
		patron_id: StringName,
		stimulus: StringName,
		observer_is_max_drunk: bool = false
) -> bool:
	if not _patrons.has(patron_id) or _patrons[patron_id]["lifecycle"] != &"active":
		return false
	var suspicion = _suspicion_states[patron_id]
	if not suspicion.apply_stimulus(stimulus, observer_is_max_drunk):
		return false
	_record(&"suspicion_stimulus", patron_id, {
		"stimulus": stimulus,
		"band": suspicion.normal_band(),
		"max_drunk_observation": observer_is_max_drunk,
	})
	_emit_snapshot()
	return true


func normal_patron_view(
		patron_id: StringName,
		selected_cultist_id: StringName = &"cultist_01"
) -> Dictionary:
	if not _patrons.has(patron_id):
		return {}
	var patron: Dictionary = _patrons[patron_id]
	var suspicion = _suspicion_states[patron_id]
	return {
		"id": patron_id,
		"name": patron["name"],
		"visible_activity": _visible_activity(patron["activity"]),
		"mood": "content",
		"suspicion_band": suspicion.normal_band(),
		"suspicion_cue": suspicion.normal_cue(),
		"intoxication": _intoxication_label(patron["intoxication"]),
		"arrival_group": patron["group_id"],
		"companions": patron["companions"].duplicate(),
		"friendship": _friendship_band(patron["friendship"].get(selected_cultist_id, 0)),
		"order_state": _patron_order_state(patron),
		"known_drugged_drink": "None",
		"victim_value": patron["victim_value"],
		"victim_risk": patron["victim_risk"],
	}


func debug_patron_view(patron_id: StringName) -> Dictionary:
	if not _patrons.has(patron_id):
		return {}
	var patron: Dictionary = _patrons[patron_id]
	var suspicion: Dictionary = _suspicion_states[patron_id].snapshot()
	var probability := bathroom_probability(float(patron["bladder"]))
	return {
		"id": patron_id,
		"bladder": patron["bladder"],
		"bathroom_probability": probability,
		"next_bathroom_check_in": maxf(0.0, float(patron["next_bathroom_check_at"]) - _simulated_seconds) if patron["bathroom_checks_active"] else -1.0,
		"intoxication_level": patron["intoxication"],
		"intoxication_decay_in": patron["intoxication_decay_in"],
		"mood_value": 75,
		"suspicion": suspicion["score"],
		"suspicion_cause": suspicion["cause"],
		"latest_suspicion_stimulus": suspicion["latest_stimulus"],
		"suspicion_recoverable": suspicion["recoverable"],
		"suspicion_quiet_seconds": suspicion["quiet_seconds"],
		"suspicion_next_recovery_in": suspicion["next_recovery_in"],
		"suspicion_maximum_response": suspicion["maximum_response"],
		"hard_evidence_downgrade_count": suspicion["hard_evidence_downgrade_count"],
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
		"full_night": _full_night,
		"closing": _closing,
		"group_id": GROUP_ID,
		"groups": _groups.duplicate(true),
		"seated_at": _seated_at,
		"seat_owners": _seat_owners.duplicate(true),
		"bathroom_owner": _interaction_registry.slot_owner(BATHROOM_SLOT),
		"normal_views": normal_views,
		"debug_views": debug_views,
		"orders": _order_system.snapshot(),
		"events": _events.duplicate(true),
		"safe_autonomy": {
			"events": _autonomy_events.duplicate(true),
			"capture_actions_started": _count_capture_autonomy_actions(),
		},
	}


static func bathroom_probability(bladder: float) -> float:
	if bladder < 50.0:
		return 0.0
	return clampf(1.0 + 89.0 * ((bladder - 50.0) / 50.0), 1.0, 90.0)


func _initialize_legacy_pair() -> void:
	_patrons = {
		&"patron_june": _new_patron(
			&"patron_june", "June", GROUP_ID, [&"patron_mara"], 75.0, 9.0, &"active"
		),
		&"patron_mara": _new_patron(
			&"patron_mara", "Mara", GROUP_ID, [&"patron_june"], 45.0, 13.0, &"active"
		),
	}
	_groups[GROUP_ID] = {
		"id": GROUP_ID,
		"label": "June + Mara",
		"arrival_at": 0.0,
		"patrons": [&"patron_june", &"patron_mara"],
		"arrived": true,
		"seated_at": -1.0,
		"departed": false,
	}
	_record(&"arrival_group_arrived", GROUP_ID)


func _initialize_full_night_cast() -> void:
	for definition in FULL_NIGHT_PATRON_DEFINITIONS:
		var patron_id: StringName = definition["id"]
		_patrons[patron_id] = _new_patron(
			patron_id,
			definition["name"],
			definition["group_id"],
			definition["companions"],
			definition["bladder_gain"],
			definition["service_delay"],
			&"not_arrived",
			definition["victim_value"],
			definition["victim_risk"]
		)
	for definition in FULL_NIGHT_GROUP_DEFINITIONS:
		var group_id: StringName = definition["id"]
		_groups[group_id] = {
			"id": group_id,
			"label": definition["label"],
			"arrival_at": definition["arrival_at"],
			"patrons": definition["patrons"].duplicate(),
			"arrived": false,
			"seated_at": -1.0,
			"departed": false,
		}


func _new_patron(
		id: StringName,
		display_name: String,
		group_id: StringName,
		companions: Array,
		bladder_gain: float,
		service_delay: float,
		lifecycle: StringName,
		victim_value: String = "Ordinary",
		victim_risk: String = "Low"
) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"group_id": group_id,
		"companions": companions.duplicate(),
		"lifecycle": lifecycle,
		"activity": &"not_arrived" if lifecycle == &"not_arrived" else &"entering",
		"activity_elapsed": 0.0,
		"seat": &"",
		"order_id": &"",
		"bladder": 0.0,
		"bladder_gain": bladder_gain,
		"service_delay": service_delay,
		"intoxication": 0,
		"intoxication_decay_in": -1.0,
		"bathroom_checks_active": false,
		"next_bathroom_check_at": -1.0,
		"recent_bathroom_rolls": [],
		"navigation_destination": &"entrance" if lifecycle == &"not_arrived" else &"seat",
		"friendship": {&"cultist_01": 0, &"cultist_02": 0, &"cultist_03": 0},
		"victim_value": victim_value,
		"victim_risk": victim_risk,
	}


func _activate_due_groups() -> void:
	if not _full_night:
		return
	for group_id: StringName in _groups:
		var group: Dictionary = _groups[group_id]
		if group["arrived"] or _simulated_seconds + 0.0001 < float(group["arrival_at"]):
			continue
		group["arrived"] = true
		_groups[group_id] = group
		for patron_id: StringName in group["patrons"]:
			var patron: Dictionary = _patrons[patron_id]
			patron["lifecycle"] = &"active"
			_set_activity(patron, &"entering", &"seat")
			_patrons[patron_id] = patron
		_record(&"arrival_group_arrived", group_id)


func _advance_patron(patron_id: StringName, delta: float) -> void:
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"active":
		return
	var recovered: float = _suspicion_states[patron_id].advance(delta)
	if recovered > 0.0:
		_record(&"suspicion_recovered", patron_id, {"amount": recovered})
	patron["activity_elapsed"] += delta
	_advance_intoxication(patron_id, patron, delta)
	match patron["activity"]:
		&"entering":
			if patron["activity_elapsed"] >= 1.0:
				_assign_seat(patron_id, patron)
		&"awaiting_drink":
			if patron["activity_elapsed"] >= float(patron["service_delay"]):
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
		if not StringName(_seat_owners[seat_id]).is_empty():
			continue
		_seat_owners[seat_id] = patron_id
		patron["seat"] = seat_id
		_set_activity(patron, &"awaiting_drink", &"seat")
		patron["order_id"] = _order_system.create_order(patron_id, _simulated_seconds)
		_record(&"seat_acquired", patron_id, {"seat": seat_id, "order_id": patron["order_id"]})
		_update_group_seated_at(patron["group_id"])
		return


func _update_group_seated_at(group_id: StringName) -> void:
	var group: Dictionary = _groups[group_id]
	if float(group["seated_at"]) >= 0.0:
		return
	for member_id: StringName in group["patrons"]:
		if StringName(_patrons[member_id]["seat"]).is_empty():
			return
	group["seated_at"] = _simulated_seconds
	_groups[group_id] = group
	if group_id == GROUP_ID:
		_seated_at = _simulated_seconds
	_record(&"arrival_group_seated", group_id)


func _serve_patron(patron_id: StringName, patron: Dictionary) -> void:
	if not _order_system.serve_order(patron["order_id"], _simulated_seconds):
		return
	var cultist_id: StringName = CULTIST_IDS[_next_service_cultist_index]
	_next_service_cultist_index = (_next_service_cultist_index + 1) % CULTIST_IDS.size()
	var autonomy_event := {
		"at": _simulated_seconds,
		"cultist_id": cultist_id,
		"action": &"serve_order",
		"target_id": patron_id,
		"capture_related": false,
	}
	_autonomy_events.append(autonomy_event)
	_record(&"safe_autonomy_service", cultist_id, {"patron_id": patron_id})
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


func _try_group_departures() -> void:
	for group_id: StringName in _groups:
		var group: Dictionary = _groups[group_id]
		if not group["arrived"] or group["departed"] or float(group["seated_at"]) < 0.0:
			continue
		var due := _closing or _simulated_seconds >= float(group["seated_at"]) + DEPARTURE_AFTER_SEATED_SECONDS
		if not due or not _group_ready_to_depart(group):
			continue
		for patron_id: StringName in group["patrons"]:
			var patron: Dictionary = _patrons[patron_id]
			if patron["lifecycle"] == &"active":
				_depart_patron(patron_id, patron, &"visit_complete")
		group["departed"] = true
		_groups[group_id] = group
		_record(&"arrival_group_departed", group_id)


func _group_ready_to_depart(group: Dictionary) -> bool:
	for patron_id: StringName in group["patrons"]:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"active":
			continue
		if patron["activity"] not in [&"socializing", &"awaiting_drink"]:
			return false
	return true


func _depart_patron(patron_id: StringName, patron: Dictionary, reason: StringName) -> void:
	_interaction_registry.release_actor(patron_id)
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = &""
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, reason)
	patron["lifecycle"] = &"exited"
	patron["bathroom_checks_active"] = false
	_set_activity(patron, &"normal_departure", &"front_exit")
	_patrons[patron_id] = patron
	_record(&"normal_departure", patron_id, {"reason": reason})


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
		&"not_arrived": "Not arrived",
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


func _count_capture_autonomy_actions() -> int:
	var count := 0
	for event: Dictionary in _autonomy_events:
		if event["capture_related"] or event["action"] in CAPTURE_ACTIONS:
			count += 1
	return count


func _record(event_name: StringName, actor_id: StringName, details: Dictionary = {}) -> void:
	_events.append({"at": _simulated_seconds, "event": event_name, "actor_id": actor_id, "details": details.duplicate(true)})


func _emit_snapshot() -> void:
	snapshot_changed.emit(snapshot())
