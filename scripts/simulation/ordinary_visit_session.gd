class_name OrdinaryVisitSession
extends RefCounted

signal snapshot_changed(snapshot: Dictionary)

const INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")
const ORDER_SYSTEM_SCRIPT := preload("res://scripts/orders/order_system.gd")
const PATRON_SUSPICION_SCRIPT := preload("res://scripts/patrons/patron_suspicion.gd")
const PATRON_PERCEPTION_SCRIPT := preload("res://scripts/patrons/patron_perception.gd")
# Which room each activity places a Patron in, for line of sight and room hearing.
const ACTIVITY_ROOMS := {
	&"not_arrived": &"front",
	&"entering": &"front",
	&"normal_departure": &"front",
	&"awaiting_drink": &"main_hall",
	&"drinking": &"main_hall",
	&"socializing": &"main_hall",
	&"entering_bathroom": &"hallway",
	&"seated_bathroom_use": &"bathroom",
	&"standing_bathroom_exit": &"hallway",
	&"investigation_search": &"bathroom",
	&"waiting_investigation": &"bathroom",
	&"captured": &"bathroom",
	&"shock": &"front",
	&"escaping": &"front",
	&"intercepted": &"front",
	&"unconscious": &"main_hall",
	&"helper_reacting": &"main_hall",
	&"helper_lifting": &"main_hall",
	&"helper_carrying": &"front",
	&"helper_persuading": &"front",
	&"being_dragged": &"main_hall",
}
const PERCEPTION_LOG_LIMIT := 8
const BAR_POSITION := Vector2(0.0, 0.0)
const SEAT_POSITIONS := {
	&"seat_01": Vector2(-12.0, 6.0), &"seat_02": Vector2(-10.5, 6.0),
	&"seat_03": Vector2(-6.0, 6.0), &"seat_04": Vector2(-4.5, 6.0),
	&"seat_05": Vector2(4.5, 6.0), &"seat_06": Vector2(6.0, 6.0),
	&"seat_07": Vector2(10.5, 6.0), &"seat_08": Vector2(12.0, 6.0),
}
const STEP_SECONDS := 0.1
const GROUP_ID := &"arrival_group_pair_01"
const BATHROOM_SLOT := &"bathroom_occupant"
const INTERCEPT_SLOT := &"intercept_position"
const DEPARTURE_AFTER_SEATED_SECONDS := 540.0
const DRINK_SECONDS := 30.0
const INTOXICATION_DECAY_SECONDS := 240.0
const BATHROOM_CHECK_SECONDS := 5.0
# Danger-chain timings, ported from the bathroom danger spike and TECHNICAL_DESIGN §6/§7.1.
const TRAPDOOR_OPEN_SECONDS := 2.0
const TRAPDOOR_COOLDOWN_SECONDS := 3.0
const INVESTIGATION_SECONDS := 5.0
const ESCAPE_SHOCK_SECONDS := 2.0
const ESCAPE_TRAVEL_SECONDS := 6.0
const INTERCEPT_SECONDS := 5.0
const MISSING_COMPANION_20_SECONDS := 20.0
const MISSING_COMPANION_30_SECONDS := 30.0
const MISSING_COMPANION_40_SECONDS := 40.0
# Drugged Drink and Helper Rescue timings, from the GDD §10.2 / §11 and TECHNICAL_DESIGN §7.2.
const DRUG_DOSES_AT_START := 2
const DRUG_PREPARE_SECONDS := 8.0
const DRUG_DROWSY_SECONDS := 10.0
const DRUG_COLLAPSE_SECONDS := 20.0
const HELPER_REACTION_SECONDS := 2.0
const HELPER_LIFT_SECONDS := 4.0
# 60%-speed carry to the front, the same path Escape covers in 6 s at 140% (tunable).
const HELPER_CARRY_SECONDS := 14.0
const RESCUE_PERSUASION_SECONDS := 6.0
const RESCUE_FAILURE_SUSPICION := 25.0
# Manual knockout and dragging, from the GDD §10.3 and TECHNICAL_DESIGN §6.3.
const KNOCKOUT_WINDUP_SECONDS := 2.0
const BODY_PICKUP_SECONDS := 1.0
# 50%-speed drag to the Tunnel Intake; the same abstract front path as the Helper carry.
const DRAG_TO_INTAKE_SECONDS := 14.0
const DRAG_MOVEMENT_SCALE := 0.5
const TIME_EPSILON := 0.0001
# Bathroom activities where the occupant stands (capturable by the Trapdoor pulse).
const STANDING_BATHROOM_ACTIVITIES: Array[StringName] = [
	&"entering_bathroom",
	&"standing_bathroom_exit",
	&"investigation_search",
]
# A Patron using the bathroom finishes that visit before a maximum-Suspicion response
# fires (a seated Hard-Evidence witness escapes through `escape_after_bathroom` instead).
const DISPATCH_EXCLUDED_ACTIVITIES: Array[StringName] = [
	&"entering_bathroom",
	&"seated_bathroom_use",
	&"standing_bathroom_exit",
]
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
var _perception = PATRON_PERCEPTION_SCRIPT.new()
var _perception_log: Dictionary = {}
var _trapdoor_state: StringName = &"closed"
var _trapdoor_remaining: float = 0.0
var _trapdoor_eligible_occupant: StringName = &""
var _captures: Array[Dictionary] = []
var _active_intercept: Dictionary = {}
var _defeat: bool = false
var _doses_remaining: int = DRUG_DOSES_AT_START
var _drug_prep: Dictionary = {}
var _collapses: Dictionary = {}
var _windup: Dictionary = {}
var _drags: Dictionary = {}


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
	_interaction_registry.register_slot(INTERCEPT_SLOT, &"intercept")
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
	_perception = PATRON_PERCEPTION_SCRIPT.new()
	_perception_log.clear()
	_trapdoor_state = &"closed"
	_trapdoor_remaining = 0.0
	_trapdoor_eligible_occupant = &""
	_captures.clear()
	_active_intercept.clear()
	_defeat = false
	_doses_remaining = DRUG_DOSES_AT_START
	_drug_prep.clear()
	_collapses.clear()
	_windup.clear()
	_drags.clear()
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
		_advance_trapdoor(step)
		_advance_missing_companions(step)
		_advance_investigations(step)
		_advance_escape(step)
		_advance_drug_prep(step)
		_advance_drug(step)
		_advance_collapses(step)
		_advance_windup(step)
		_advance_drags(step)
		_apply_body_pressure(step)
		_apply_companion_influence(step)
		_dispatch_maximum_responses()
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
	_interaction_registry.register_slot(INTERCEPT_SLOT, &"intercept")
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


# Fans a danger event out to the Patrons that perceive it. Visual events use
# facing and line of sight; auditory events use the room-hearing relationship.
# Each recipient routes the stimulus into its own PatronSuspicion. Returns the
# ids that perceived the event.
func report_danger_event(
		stimulus: StringName,
		channel: StringName,
		source_room: StringName,
		source_id: StringName = &"",
		source_position := Vector2.ZERO
) -> Array:
	var perceivers := _active_perceivers()
	var recipients: Array = []
	match channel:
		&"visual":
			recipients = _perception.visual_recipients(source_room, source_position, perceivers)
		&"auditory":
			recipients = _perception.auditory_recipients(source_room, perceivers)
		_:
			recipients = []
	var effective_source: StringName = source_id if not source_id.is_empty() else source_room
	var perceived: Array[StringName] = []
	for patron_id: StringName in recipients:
		if _route_stimulus(patron_id, stimulus, channel, effective_source):
			perceived.append(patron_id)
	_emit_snapshot()
	return perceived


func add_unattended_body(body_id: StringName, room: StringName, position := Vector2.ZERO) -> void:
	_perception.add_body(body_id, room, position)


func set_unattended_body_state(body_id: StringName, state: StringName) -> void:
	_perception.set_body_state(body_id, state)


func drop_unattended_body(body_id: StringName, room: StringName, position := Vector2.ZERO) -> void:
	_perception.drop_body(body_id, room, position)


func remove_unattended_body(body_id: StringName) -> void:
	_perception.remove_body(body_id)


func _apply_body_pressure(step: float) -> void:
	var ticks: Array = _perception.advance_bodies(step)
	for body_id: StringName in ticks:
		for patron_id: StringName in _patrons:
			if _patrons[patron_id]["lifecycle"] != &"active":
				continue
			_route_stimulus(patron_id, &"unattended_body_pressure", &"unattended_body", body_id)


func _apply_companion_influence(step: float) -> void:
	var rounds := _perception.advance_companion_timer(step)
	for _round in range(rounds):
		_run_companion_round()


func _run_companion_round() -> void:
	# Read every Suspicion before applying, so a round resolves from one shared
	# snapshot and the drift order does not bias the result.
	var scores: Dictionary = {}
	for patron_id: StringName in _patrons:
		if _patrons[patron_id]["lifecycle"] == &"active":
			scores[patron_id] = _suspicion_states[patron_id].snapshot()["score"]
	for patron_id: StringName in scores:
		var patron: Dictionary = _patrons[patron_id]
		var candidates: Array = []
		for companion_id: StringName in patron["companions"]:
			if not scores.has(companion_id):
				continue
			var companion: Dictionary = _patrons[companion_id]
			candidates.append({
				"id": companion_id,
				"room": _patron_room(companion),
				"position": _patron_position(companion),
				"score": scores[companion_id],
			})
		var winner := _perception.highest_nearby_influence(
			_patron_room(patron), _patron_position(patron), candidates
		)
		if winner.is_empty() or float(winner["score"]) <= float(scores[patron_id]):
			continue
		if _suspicion_states[patron_id].apply_companion_influence(float(winner["score"])):
			var cause: StringName = _suspicion_states[patron_id].snapshot()["cause"]
			_record(&"companion_influence", patron_id, {
				"source": winner["id"],
				"neighbor_suspicion": winner["score"],
				"cause": cause,
			})
			_log_perception(patron_id, winner["id"], &"companion", &"companion_influence", cause)


func _route_stimulus(
		patron_id: StringName,
		stimulus: StringName,
		channel: StringName,
		source_id: StringName
) -> bool:
	var patron: Dictionary = _patrons[patron_id]
	var observer_is_max_drunk := int(patron["intoxication"]) >= 3
	var suspicion = _suspicion_states[patron_id]
	if not suspicion.apply_stimulus(stimulus, observer_is_max_drunk):
		return false
	var cause: StringName = suspicion.snapshot()["cause"]
	_record(&"danger_perceived", patron_id, {
		"stimulus": stimulus,
		"channel": channel,
		"source": source_id,
		"cause": cause,
	})
	_log_perception(patron_id, source_id, channel, stimulus, cause)
	return true


func _log_perception(
		patron_id: StringName,
		source_id: StringName,
		channel: StringName,
		stimulus: StringName,
		cause: StringName
) -> void:
	if not _perception_log.has(patron_id):
		_perception_log[patron_id] = []
	var trace: Array = _perception_log[patron_id]
	trace.append({
		"at": _simulated_seconds,
		"source": source_id,
		"recipient": patron_id,
		"channel": channel,
		"stimulus": stimulus,
		"cause": cause,
	})
	while trace.size() > PERCEPTION_LOG_LIMIT:
		trace.pop_front()


func _active_perceivers() -> Array:
	var perceivers: Array = []
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"active":
			continue
		perceivers.append({
			"id": patron_id,
			"room": _patron_room(patron),
			"position": _patron_position(patron),
			"facing": _patron_facing(patron),
		})
	return perceivers


func _patron_room(patron: Dictionary) -> StringName:
	return ACTIVITY_ROOMS.get(patron["activity"], &"main_hall")


# Deterministic 2-D layout in metres. Seated Patrons sit at fixed table seats and
# face the bar counter; unseated Patrons take a representative spot for their room.
# Tables hold two seats 1.5 m apart and stand well over 5 m from each other, so a
# seated pair shares a table (Companion range) while other tables do not.
func _patron_position(patron: Dictionary) -> Vector2:
	var seat: StringName = patron["seat"]
	if SEAT_POSITIONS.has(seat):
		return SEAT_POSITIONS[seat]
	match _patron_room(patron):
		&"front": return Vector2(0.0, 14.0)
		&"hallway": return Vector2(14.0, 6.0)
		&"bathroom": return Vector2(18.0, 6.0)
	return Vector2(0.0, 8.0)


func _patron_facing(patron: Dictionary) -> Vector2:
	var to_bar := BAR_POSITION - _patron_position(patron)
	if to_bar.length() <= 0.0001:
		return Vector2(0.0, -1.0)
	return to_bar.normalized()


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
		"room": _patron_room(patron),
		"position": _patron_position(patron),
		"facing": _patron_facing(patron),
		"recent_perceptions": _perception_log.get(patron_id, []).duplicate(true),
		"night_seed": _seed,
		"recent_bathroom_rolls": patron["recent_bathroom_rolls"].duplicate(true),
		"missing_target": patron["missing_target"],
		"missing_seconds": patron["missing_seconds"],
		"escape_remaining": patron["escape_remaining"],
		"escape_after_bathroom": patron["escape_after_bathroom"],
		"intercept_attempted": patron["intercept_attempted"],
		"drug_countdown": patron["drug_countdown"],
		"dosed_pending": patron["dosed_pending"],
		"helper_id": patron["helper_id"],
		"helping_victim": patron["helping_victim"],
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
		"trapdoor": {
			"state": _trapdoor_state,
			"remaining": _trapdoor_remaining,
			"eligible_occupant": _trapdoor_eligible_occupant,
		},
		"captures": _captures.duplicate(true),
		"defeat": _defeat,
		"active_intercept": _active_intercept.duplicate(true),
		"escaping_patrons": _escaping_patron_ids(),
		"doses_remaining": _doses_remaining,
		"drug_prep": _drug_prep.duplicate(true),
		"collapses": _collapses.duplicate(true),
		"windup": _windup.duplicate(true),
		"drags": _drags.duplicate(true),
	}


func _escaping_patron_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for patron_id: StringName in _patrons:
		if _patrons[patron_id]["lifecycle"] == &"escaping":
			ids.append(patron_id)
	return ids


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
		"missing_target": &"",
		"missing_seconds": 0.0,
		"missing_20_applied": false,
		"missing_30_applied": false,
		"missing_40_applied": false,
		"escape_remaining": ESCAPE_TRAVEL_SECONDS,
		"escape_after_bathroom": false,
		"intercept_attempted": false,
		"dosed_pending": false,
		"drug_countdown": -1.0,
		"drug_drowsy_reported": false,
		"helper_id": &"",
		"helping_victim": &"",
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
				_clear_missing_companion_clock(patron_id)
				_record(&"bathroom_visit_completed", patron_id)
				if patron["escape_after_bathroom"]:
					patron["escape_after_bathroom"] = false
					_patrons[patron_id] = patron
					_begin_escape(patron_id)
					return
				_set_activity(patron, &"socializing", &"seat")
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
	# First sip: a prepared dose starts this consumer's countdown.
	if patron["dosed_pending"]:
		patron["dosed_pending"] = false
		patron["drug_countdown"] = 0.0
		patron["drug_drowsy_reported"] = false
		_record(&"drugged_drink_sipped", patron_id)
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
			_start_missing_companion_clock(patron_id)
			_record(&"bathroom_chosen", patron_id, {"roll": roll, "probability": probability})
			return


# --- Danger chain (Trapdoor, missing Companion, Investigation, Escape, Intercept) ---
# Ported from the isolated BathroomDangerScenario spike and adapted to the live Night's
# bathroom vocabulary. The Trapdoor, Investigation and Escape act on the single authoritative
# Patron model; maximum-Suspicion behaviour is driven by PatronSuspicion.maximum_response.


func activate_trapdoor() -> bool:
	if _trapdoor_state != &"closed":
		return false
	_trapdoor_state = &"open"
	_trapdoor_remaining = TRAPDOOR_OPEN_SECONDS
	var occupant := _bathroom_occupant()
	_trapdoor_eligible_occupant = occupant
	_record(&"trapdoor_opened", occupant)
	if not occupant.is_empty():
		var activity: StringName = _patrons[occupant]["activity"]
		if _is_standing_bathroom_activity(activity):
			_capture_occupant(&"trapdoor")
		elif activity == &"seated_bathroom_use":
			_apply_seated_hard_evidence(occupant)
	_emit_snapshot()
	return true


func begin_intercept(patron_id: StringName, cultist_id: StringName) -> bool:
	if not _patrons.has(patron_id) or cultist_id.is_empty() or not _active_intercept.is_empty():
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"escaping" or patron["activity"] != &"escaping":
		return false
	if patron["intercept_attempted"] or not _interaction_registry.request_slot(cultist_id, INTERCEPT_SLOT):
		return false
	patron["intercept_attempted"] = true
	_set_activity(patron, &"intercepted", &"front_exit")
	_patrons[patron_id] = patron
	_active_intercept = {
		"patron_id": patron_id,
		"cultist_id": cultist_id,
		"remaining": INTERCEPT_SECONDS,
	}
	_record(&"intercept_started", patron_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func cancel_intercept() -> bool:
	if _active_intercept.is_empty():
		return false
	var patron_id: StringName = _active_intercept["patron_id"]
	var cultist_id: StringName = _active_intercept["cultist_id"]
	_interaction_registry.release_actor(cultist_id)
	_active_intercept.clear()
	if _patrons.has(patron_id) and _patrons[patron_id]["lifecycle"] == &"escaping":
		var patron: Dictionary = _patrons[patron_id]
		_set_activity(patron, &"escaping", &"front_exit")
		_patrons[patron_id] = patron
	_record(&"intercept_cancelled", patron_id)
	_emit_snapshot()
	return true


func has_active_escape() -> bool:
	for patron_id: StringName in _patrons:
		if _patrons[patron_id]["lifecycle"] == &"escaping":
			return true
	return false


func has_defeat() -> bool:
	return _defeat


# Debug-only seam: place an arrived Patron in the bathroom deterministically instead of
# waiting on seeded bladder rolls. Used by tests and the capture-chain validation slice.
func debug_force_bathroom(patron_id: StringName) -> bool:
	if not _patrons.has(patron_id):
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"active" or not _bathroom_occupant().is_empty():
		return false
	_interaction_registry.release_actor(patron_id)
	if not _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
		return false
	patron["bathroom_checks_active"] = false
	_set_activity(patron, &"entering_bathroom", &"bathroom")
	_patrons[patron_id] = patron
	_start_missing_companion_clock(patron_id)
	_record(&"debug_bathroom_forced", patron_id)
	_emit_snapshot()
	return true


func _advance_trapdoor(step: float) -> void:
	if _trapdoor_state == &"closed":
		return
	_trapdoor_remaining = maxf(0.0, _trapdoor_remaining - step)
	var occupant := _bathroom_occupant()
	if (
			_trapdoor_state == &"open"
			and not occupant.is_empty()
			and occupant == _trapdoor_eligible_occupant
			and _is_standing_bathroom_activity(_patrons[occupant]["activity"])
	):
		_capture_occupant(&"trapdoor")
	if _trapdoor_remaining > TIME_EPSILON:
		return
	if _trapdoor_state == &"open":
		_trapdoor_state = &"cooldown"
		_trapdoor_remaining = TRAPDOOR_COOLDOWN_SECONDS
		_trapdoor_eligible_occupant = &""
		_record(&"trapdoor_cooldown", &"trapdoor")
	else:
		_trapdoor_state = &"closed"
		_trapdoor_remaining = 0.0
		_record(&"trapdoor_ready", &"trapdoor")


func _advance_missing_companions(step: float) -> void:
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if StringName(patron["missing_target"]).is_empty() or patron["missing_40_applied"]:
			continue
		if patron["lifecycle"] != &"active":
			continue
		patron["missing_seconds"] = float(patron["missing_seconds"]) + step
		var elapsed: float = patron["missing_seconds"]
		if elapsed >= MISSING_COMPANION_20_SECONDS - TIME_EPSILON and not patron["missing_20_applied"]:
			patron["missing_20_applied"] = true
			_suspicion_states[patron_id].apply_stimulus(&"missing_companion_20")
			_record(&"missing_companion_20", patron_id)
		if elapsed >= MISSING_COMPANION_30_SECONDS - TIME_EPSILON and not patron["missing_30_applied"]:
			patron["missing_30_applied"] = true
			_suspicion_states[patron_id].apply_stimulus(&"missing_companion_30")
			_record(&"missing_companion_30", patron_id)
		if elapsed >= MISSING_COMPANION_40_SECONDS - TIME_EPSILON and not patron["missing_40_applied"]:
			patron["missing_40_applied"] = true
			_suspicion_states[patron_id].apply_stimulus(&"missing_companion_40")
			_record(&"missing_companion_40", patron_id)
		_patrons[patron_id] = patron


func _advance_investigations(step: float) -> void:
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"investigating":
			continue
		if patron["activity"] == &"waiting_investigation":
			if _bathroom_occupant().is_empty() and _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
				_set_activity(patron, &"investigation_search", &"bathroom")
				_patrons[patron_id] = patron
				_record(&"investigation_started", patron_id)
			continue
		if patron["activity"] != &"investigation_search":
			continue
		patron["activity_elapsed"] = float(patron["activity_elapsed"]) + step
		_patrons[patron_id] = patron
		if patron["activity_elapsed"] >= INVESTIGATION_SECONDS:
			_interaction_registry.release_actor(patron_id)
			_record(&"trapdoor_discovered", patron_id)
			_begin_escape(patron_id)


func _advance_escape(step: float) -> void:
	if not _active_intercept.is_empty():
		_active_intercept["remaining"] = maxf(0.0, float(_active_intercept["remaining"]) - step)
		if _active_intercept["remaining"] <= TIME_EPSILON:
			var intercepted_id: StringName = _active_intercept["patron_id"]
			var cultist_id: StringName = _active_intercept["cultist_id"]
			_interaction_registry.release_actor(cultist_id)
			_active_intercept.clear()
			if _patrons.has(intercepted_id) and _patrons[intercepted_id]["lifecycle"] == &"escaping":
				var resumed: Dictionary = _patrons[intercepted_id]
				_set_activity(resumed, &"escaping", &"front_exit")
				_patrons[intercepted_id] = resumed
			_record(&"intercept_completed", intercepted_id)
		return
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"escaping":
			continue
		if patron["activity"] == &"shock":
			patron["activity_elapsed"] = float(patron["activity_elapsed"]) + step
			if patron["activity_elapsed"] >= ESCAPE_SHOCK_SECONDS:
				_set_activity(patron, &"escaping", &"front_exit")
				_record(&"escape_started", patron_id)
			_patrons[patron_id] = patron
			continue
		if patron["activity"] != &"escaping":
			continue
		patron["escape_remaining"] = maxf(0.0, float(patron["escape_remaining"]) - step)
		if patron["escape_remaining"] <= TIME_EPSILON:
			_interaction_registry.release_actor(patron_id)
			patron["lifecycle"] = &"exited"
			_set_activity(patron, &"normal_departure", &"front_exit")
			_defeat = true
			_patrons[patron_id] = patron
			_record(&"defeat", patron_id)
		else:
			_patrons[patron_id] = patron


# The integration glue: a Patron that reaches maximum Suspicion acts on the response the
# Suspicion module selected (missing Companion -> Investigation; Hard Evidence, general
# danger, or Companion drift -> Escape). Patrons mid-bathroom finish that visit first.
func _dispatch_maximum_responses() -> void:
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"active":
			continue
		if patron["activity"] in DISPATCH_EXCLUDED_ACTIVITIES:
			continue
		var state: Dictionary = _suspicion_states[patron_id].snapshot()
		if float(state["score"]) < 100.0:
			continue
		match state["maximum_response"]:
			&"investigation":
				_request_investigation(patron_id)
			&"escape":
				_begin_escape(patron_id)


func _request_investigation(patron_id: StringName) -> void:
	var patron: Dictionary = _patrons[patron_id]
	patron["lifecycle"] = &"investigating"
	patron["bathroom_checks_active"] = false
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = &""
		patron["seat"] = &""
	if _bathroom_occupant().is_empty() and _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
		_set_activity(patron, &"investigation_search", &"bathroom")
		_record(&"investigation_started", patron_id)
	else:
		_set_activity(patron, &"waiting_investigation", &"bathroom")
		_record(&"investigation_waiting", patron_id)
	_patrons[patron_id] = patron


func _begin_escape(patron_id: StringName) -> void:
	var patron: Dictionary = _patrons[patron_id]
	_interaction_registry.release_actor(patron_id)
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = &""
		patron["seat"] = &""
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"escaping")
	patron["lifecycle"] = &"escaping"
	patron["bathroom_checks_active"] = false
	patron["escape_remaining"] = ESCAPE_TRAVEL_SECONDS
	patron["intercept_attempted"] = false
	_set_activity(patron, &"shock", &"front_exit")
	_patrons[patron_id] = patron
	_record(&"escape_shock", patron_id)


func _capture_occupant(cause: StringName) -> void:
	var captured_id := _bathroom_occupant()
	if captured_id.is_empty() or not _patrons.has(captured_id):
		return
	var patron: Dictionary = _patrons[captured_id]
	_interaction_registry.release_actor(captured_id)
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = &""
		patron["seat"] = &""
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"captured")
	patron["lifecycle"] = &"captured"
	patron["missing_target"] = &""
	patron["bathroom_checks_active"] = false
	_set_activity(patron, &"captured", &"tunnel")
	_patrons[captured_id] = patron
	_captures.append({"id": captured_id, "cause": cause, "at": _simulated_seconds})
	_record(&"capture", captured_id, {"cause": cause})


func _apply_seated_hard_evidence(patron_id: StringName) -> void:
	var patron: Dictionary = _patrons[patron_id]
	var observer_is_max_drunk := int(patron["intoxication"]) >= 3
	_suspicion_states[patron_id].apply_stimulus(&"trapdoor_open_seen_seated", observer_is_max_drunk)
	if not observer_is_max_drunk:
		patron["escape_after_bathroom"] = true
		_patrons[patron_id] = patron
	_record(&"trapdoor_seated_evidence", patron_id, {"max_drunk": observer_is_max_drunk})


func _start_missing_companion_clock(entered_id: StringName) -> void:
	if not _patrons.has(entered_id):
		return
	for companion_id: StringName in _patrons[entered_id]["companions"]:
		if not _patrons.has(companion_id):
			continue
		var companion: Dictionary = _patrons[companion_id]
		if companion["lifecycle"] != &"active":
			continue
		companion["missing_target"] = entered_id
		companion["missing_seconds"] = 0.0
		companion["missing_20_applied"] = false
		companion["missing_30_applied"] = false
		companion["missing_40_applied"] = false
		_patrons[companion_id] = companion
		_record(&"companion_missing_started", companion_id, {"target_id": entered_id})


func _clear_missing_companion_clock(returned_id: StringName) -> void:
	for patron_id: StringName in _patrons:
		if _patrons[patron_id]["missing_target"] != returned_id:
			continue
		var patron: Dictionary = _patrons[patron_id]
		patron["missing_target"] = &""
		patron["missing_seconds"] = 0.0
		_patrons[patron_id] = patron
		_record(&"companion_returned", patron_id, {"target_id": returned_id})


func _bathroom_occupant() -> StringName:
	return _interaction_registry.slot_owner(BATHROOM_SLOT)


func _is_standing_bathroom_activity(activity: StringName) -> bool:
	return activity in STANDING_BATHROOM_ACTIVITIES


# --- Drugged Drink, collapse, Helper, and Rescue Persuasion (Ticket #12) ---
# The dose attaches to the target's open Order; the consumer-owned countdown starts at the
# first sip. On collapse the least-intoxicated conscious Companion carries the victim toward
# the front, where one Rescue Persuasion may capture both at the Tunnel Intake.


func prepare_drugged_drink(patron_id: StringName, cultist_id: StringName) -> bool:
	if _doses_remaining <= 0 or not _drug_prep.is_empty() or cultist_id.is_empty():
		return false
	if not _patrons.has(patron_id):
		return false
	if not _order_system.is_open(_patrons[patron_id]["order_id"]):
		return false
	_drug_prep = {
		"cultist_id": cultist_id,
		"patron_id": patron_id,
		"remaining": DRUG_PREPARE_SECONDS,
	}
	_record(&"drugged_drink_prepared", patron_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func attempt_rescue_persuasion(cultist_id: StringName) -> bool:
	if cultist_id.is_empty():
		return false
	var victim_id := _carrying_collapse_victim()
	if victim_id.is_empty():
		return false
	var collapse: Dictionary = _collapses[victim_id]
	if collapse["rescue_attempted"]:
		return false
	collapse["rescue_attempted"] = true
	collapse["acting_cultist"] = cultist_id
	collapse["carry_remaining"] = collapse["remaining"]
	collapse["last_chance"] = rescue_persuasion_chance(cultist_id)
	collapse["phase"] = &"persuading"
	collapse["remaining"] = RESCUE_PERSUASION_SECONDS
	_collapses[victim_id] = collapse
	_record(&"rescue_persuasion_started", collapse["helper_id"], {
		"cultist_id": cultist_id, "chance": collapse["last_chance"],
	})
	_emit_snapshot()
	return true


func rescue_persuasion_chance(cultist_id: StringName) -> float:
	var victim_id := _active_collapse_with_helper()
	if victim_id.is_empty() or cultist_id.is_empty():
		return 0.0
	var helper_id: StringName = _collapses[victim_id]["helper_id"]
	if not _patrons.has(helper_id):
		return 0.0
	var friendship: float = float(_patrons[helper_id]["friendship"].get(cultist_id, 0))
	var suspicion: float = _suspicion_states[helper_id].snapshot()["score"]
	return clampf(25.0 + 0.7 * (friendship - suspicion), 5.0, 95.0)


func _advance_drug_prep(step: float) -> void:
	if _drug_prep.is_empty():
		return
	_drug_prep["remaining"] = float(_drug_prep["remaining"]) - step
	if _drug_prep["remaining"] > TIME_EPSILON:
		return
	var patron_id: StringName = _drug_prep["patron_id"]
	_doses_remaining -= 1
	if _patrons.has(patron_id) and _order_system.is_open(_patrons[patron_id]["order_id"]):
		_patrons[patron_id]["dosed_pending"] = true
	_record(&"drugged_drink_ready", patron_id, {"doses_remaining": _doses_remaining})
	_drug_prep.clear()


func _advance_drug(step: float) -> void:
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if float(patron["drug_countdown"]) < 0.0 or patron["lifecycle"] != &"active":
			continue
		patron["drug_countdown"] = float(patron["drug_countdown"]) + step
		if float(patron["drug_countdown"]) >= DRUG_DROWSY_SECONDS and not patron["drug_drowsy_reported"]:
			patron["drug_drowsy_reported"] = true
			_record(&"drugged_drink_drowsy", patron_id)
		_patrons[patron_id] = patron
		if float(patron["drug_countdown"]) >= DRUG_COLLAPSE_SECONDS:
			_collapse_patron(patron_id)


func _advance_collapses(step: float) -> void:
	for victim_id: StringName in _collapses.keys():
		var collapse: Dictionary = _collapses[victim_id]
		match collapse["phase"]:
			&"reacting":
				collapse["remaining"] = float(collapse["remaining"]) - step
				if collapse["remaining"] <= TIME_EPSILON:
					_assign_helper(victim_id, collapse)
			&"lifting":
				collapse["remaining"] = float(collapse["remaining"]) - step
				if collapse["remaining"] <= TIME_EPSILON:
					collapse["phase"] = &"carrying"
					collapse["remaining"] = HELPER_CARRY_SECONDS
					_set_helper_activity(collapse["helper_id"], &"helper_carrying")
					_record(&"helper_carrying", collapse["helper_id"], {"victim_id": victim_id})
			&"carrying":
				collapse["remaining"] = float(collapse["remaining"]) - step
				if collapse["remaining"] <= TIME_EPSILON:
					_collapses[victim_id] = collapse
					_helper_reaches_front(victim_id)
					continue
			&"persuading":
				collapse["remaining"] = float(collapse["remaining"]) - step
				if collapse["remaining"] <= TIME_EPSILON:
					_collapses[victim_id] = collapse
					_resolve_rescue(victim_id)
					continue
		if _collapses.has(victim_id):
			_collapses[victim_id] = collapse


func _collapse_patron(patron_id: StringName) -> void:
	var patron: Dictionary = _patrons[patron_id]
	# The drink still raises Bladder and Intoxication before the Patron goes under.
	patron["bladder"] = minf(100.0, float(patron["bladder"]) + float(patron["bladder_gain"]))
	patron["intoxication"] = mini(3, int(patron["intoxication"]) + 1)
	patron["intoxication_decay_in"] = INTOXICATION_DECAY_SECONDS
	patron["drug_countdown"] = DRUG_COLLAPSE_SECONDS
	patron["bathroom_checks_active"] = false
	patron["lifecycle"] = &"unconscious"
	_set_activity(patron, &"unconscious", &"collapsed")
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = &""
		patron["seat"] = &""
	_interaction_registry.release_actor(patron_id)
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"collapsed")
	_patrons[patron_id] = patron
	_collapses[patron_id] = {
		"victim_id": patron_id,
		"helper_id": &"",
		"phase": &"reacting",
		"remaining": HELPER_REACTION_SECONDS,
		"carry_remaining": HELPER_CARRY_SECONDS,
		"acting_cultist": &"",
		"rescue_attempted": false,
		"last_chance": 0.0,
		"last_roll": -1.0,
		"last_success": false,
	}
	_record(&"drugged_drink_collapse", patron_id)


func _assign_helper(victim_id: StringName, collapse: Dictionary) -> void:
	var helper_id := _select_helper(victim_id)
	if helper_id.is_empty():
		collapse["phase"] = &"unattended"
		_collapses[victim_id] = collapse
		_record(&"collapse_unattended", victim_id)
		return
	var helper: Dictionary = _patrons[helper_id]
	helper["bathroom_checks_active"] = false
	if not StringName(helper["seat"]).is_empty():
		_seat_owners[helper["seat"]] = &""
		helper["seat"] = &""
	_interaction_registry.release_actor(helper_id)
	var order_id: StringName = helper["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"helping")
	helper["lifecycle"] = &"helping"
	helper["helping_victim"] = victim_id
	_set_activity(helper, &"helper_lifting", &"front")
	_patrons[helper_id] = helper
	_patrons[victim_id]["helper_id"] = helper_id
	collapse["phase"] = &"lifting"
	collapse["remaining"] = HELPER_LIFT_SECONDS
	collapse["helper_id"] = helper_id
	_collapses[victim_id] = collapse
	_record(&"helper_assigned", helper_id, {"victim_id": victim_id})


func _select_helper(victim_id: StringName) -> StringName:
	var best_id: StringName = &""
	var best_intoxication := 4
	var best_index := 999
	for companion_id: StringName in _patrons[victim_id]["companions"]:
		if not _patrons.has(companion_id) or _patrons[companion_id]["lifecycle"] != &"active":
			continue
		var intoxication := int(_patrons[companion_id]["intoxication"])
		var index := _definition_index(companion_id)
		if intoxication < best_intoxication or (intoxication == best_intoxication and index < best_index):
			best_id = companion_id
			best_intoxication = intoxication
			best_index = index
	return best_id


func _definition_index(patron_id: StringName) -> int:
	for index in range(FULL_NIGHT_PATRON_DEFINITIONS.size()):
		if FULL_NIGHT_PATRON_DEFINITIONS[index]["id"] == patron_id:
			return index
	return 999


func _helper_reaches_front(victim_id: StringName) -> void:
	var collapse: Dictionary = _collapses[victim_id]
	var helper_id: StringName = collapse["helper_id"]
	# Both Patrons leave. It is defeat only if the Helper is at maximum Suspicion.
	if _patrons.has(helper_id) and _suspicion_states[helper_id].snapshot()["score"] >= 100.0:
		_defeat = true
		_record(&"defeat", helper_id, {"reason": &"helper_max_suspicion_at_front"})
	for patron_id: StringName in [victim_id, helper_id]:
		if not _patrons.has(patron_id):
			continue
		var patron: Dictionary = _patrons[patron_id]
		_interaction_registry.release_actor(patron_id)
		patron["lifecycle"] = &"exited"
		patron["helper_id"] = &""
		patron["helping_victim"] = &""
		_set_activity(patron, &"normal_departure", &"front_exit")
		_patrons[patron_id] = patron
	_collapses.erase(victim_id)
	_record(&"helper_reached_front", helper_id, {"victim_id": victim_id})


func _resolve_rescue(victim_id: StringName) -> void:
	var collapse: Dictionary = _collapses[victim_id]
	var helper_id: StringName = collapse["helper_id"]
	var roll := _rng.randf_range(0.0, 100.0)
	var success := roll <= float(collapse["last_chance"])
	collapse["last_roll"] = roll
	collapse["last_success"] = success
	_collapses[victim_id] = collapse
	if success:
		_record(&"rescue_persuasion_succeeded", helper_id, {"roll": roll, "chance": collapse["last_chance"]})
		_capture_pair(victim_id, helper_id, &"rescue_persuasion")
		return
	if _patrons.has(helper_id):
		_suspicion_states[helper_id].apply_stimulus(&"rescue_persuasion_failed")
	collapse["phase"] = &"carrying"
	collapse["remaining"] = float(collapse["carry_remaining"])
	_set_helper_activity(helper_id, &"helper_carrying")
	_collapses[victim_id] = collapse
	_record(&"rescue_persuasion_failed", helper_id, {"roll": roll, "chance": collapse["last_chance"]})


func _capture_pair(victim_id: StringName, helper_id: StringName, cause: StringName) -> void:
	for patron_id: StringName in [victim_id, helper_id]:
		if not _patrons.has(patron_id):
			continue
		var patron: Dictionary = _patrons[patron_id]
		_interaction_registry.release_actor(patron_id)
		if not StringName(patron["seat"]).is_empty():
			_seat_owners[patron["seat"]] = &""
			patron["seat"] = &""
		patron["lifecycle"] = &"captured"
		patron["helper_id"] = &""
		patron["helping_victim"] = &""
		_set_activity(patron, &"captured", &"tunnel")
		_patrons[patron_id] = patron
		_captures.append({"id": patron_id, "cause": cause, "at": _simulated_seconds})
		_record(&"capture", patron_id, {"cause": cause})
	_collapses.erase(victim_id)


func _set_helper_activity(helper_id: StringName, activity: StringName) -> void:
	if not _patrons.has(helper_id):
		return
	var helper: Dictionary = _patrons[helper_id]
	_set_activity(helper, activity, &"front")
	_patrons[helper_id] = helper


func _carrying_collapse_victim() -> StringName:
	for victim_id: StringName in _collapses:
		if _collapses[victim_id]["phase"] == &"carrying" and not StringName(_collapses[victim_id]["helper_id"]).is_empty():
			return victim_id
	return &""


func _active_collapse_with_helper() -> StringName:
	for victim_id: StringName in _collapses:
		var phase: StringName = _collapses[victim_id]["phase"]
		if phase in [&"carrying", &"persuading"] and not StringName(_collapses[victim_id]["helper_id"]).is_empty():
			return victim_id
	return &""


# --- Manual knockout and dragging (GDD §10.3) --------------------------------

# Begins the 2-second interruptible wind-up. Valid against an active Patron when
# the acting Cultist is free and no other wind-up is in progress.
func begin_knockout(cultist_id: StringName, victim_id: StringName) -> bool:
	if cultist_id.is_empty() or not _patrons.has(victim_id):
		return false
	if _patrons[victim_id]["lifecycle"] != &"active":
		return false
	if not _windup.is_empty() or is_cultist_busy(cultist_id):
		return false
	_windup = {
		"cultist_id": cultist_id,
		"victim_id": victim_id,
		"remaining": KNOCKOUT_WINDUP_SECONDS,
	}
	_record(&"knockout_windup_started", victim_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


# Interrupts the wind-up before impact. The Commitment Point has not passed, so
# the victim is unharmed. Only the Cultist who started the wind-up can cancel it.
func cancel_knockout(cultist_id: StringName) -> bool:
	if _windup.is_empty() or _windup["cultist_id"] != cultist_id:
		return false
	var victim_id: StringName = _windup["victim_id"]
	_windup.clear()
	_record(&"knockout_windup_cancelled", victim_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


# Starts the 1-second pickup of an Unconscious, unattended body. Pickup pauses the
# Unattended Body pressure and occupies the Cultist through the drag that follows.
func pick_up_body(cultist_id: StringName, victim_id: StringName) -> bool:
	if cultist_id.is_empty() or not _patrons.has(victim_id):
		return false
	if _patrons[victim_id]["lifecycle"] != &"unconscious" or _drags.has(victim_id):
		return false
	if is_cultist_busy(cultist_id):
		return false
	_perception.set_body_state(victim_id, &"held")
	_drags[victim_id] = {
		"victim_id": victim_id,
		"cultist_id": cultist_id,
		"phase": &"pickup",
		"remaining": BODY_PICKUP_SECONDS,
		"movement_scale": DRAG_MOVEMENT_SCALE,
	}
	_record(&"body_pickup_started", victim_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


# Drops the body the Cultist is holding or dragging. Dragging can always be
# interrupted this way; dropping restarts the victim's Unattended Body grace.
func drop_body(cultist_id: StringName) -> bool:
	var victim_id := _drag_victim_for_cultist(cultist_id)
	if victim_id.is_empty():
		return false
	_drags.erase(victim_id)
	var patron: Dictionary = _patrons[victim_id]
	_set_activity(patron, &"unconscious", &"collapsed")
	_patrons[victim_id] = patron
	# A fresh grace period: the abandoned body is Unattended again.
	_perception.drop_body(victim_id, _patron_room(patron), _patron_position(patron))
	_record(&"body_dropped", victim_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func is_cultist_busy(cultist_id: StringName) -> bool:
	if not _windup.is_empty() and _windup["cultist_id"] == cultist_id:
		return true
	return not _drag_victim_for_cultist(cultist_id).is_empty()


func _drag_victim_for_cultist(cultist_id: StringName) -> StringName:
	for victim_id: StringName in _drags:
		if _drags[victim_id]["cultist_id"] == cultist_id:
			return victim_id
	return &""


func _advance_windup(step: float) -> void:
	if _windup.is_empty():
		return
	var victim_id: StringName = _windup["victim_id"]
	# A victim who left or fell before impact aborts the wind-up harmlessly.
	if not _patrons.has(victim_id) or _patrons[victim_id]["lifecycle"] != &"active":
		_windup.clear()
		return
	_windup["remaining"] = float(_windup["remaining"]) - step
	if float(_windup["remaining"]) > TIME_EPSILON:
		return
	var cultist_id: StringName = _windup["cultist_id"]
	_windup.clear()
	_knockout_patron(victim_id, cultist_id)


# The knockout impact. This is the Commitment Point: witnesses perceive it and the
# victim goes Unconscious for the Night, becoming an Unattended Body on the spot.
func _knockout_patron(victim_id: StringName, cultist_id: StringName) -> void:
	var patron: Dictionary = _patrons[victim_id]
	var source_room := _patron_room(patron)
	var source_position := _patron_position(patron)
	_witness_knockout(victim_id, source_room, source_position)
	patron["bathroom_checks_active"] = false
	patron["lifecycle"] = &"unconscious"
	_set_activity(patron, &"unconscious", &"collapsed")
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = &""
		patron["seat"] = &""
	_interaction_registry.release_actor(victim_id)
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"knockout")
	_patrons[victim_id] = patron
	_perception.add_body(victim_id, source_room, source_position)
	_record(&"knockout", victim_id, {"cultist_id": cultist_id})


# Fans the impact out: a Patron who sees it receives Hard Evidence, a Patron who
# only hears it receives the +25 soft increase, and the victim never witnesses it.
func _witness_knockout(victim_id: StringName, source_room: StringName, source_position: Vector2) -> void:
	var perceivers := _active_perceivers()
	var seen: Dictionary = {}
	for patron_id: StringName in _perception.visual_recipients(source_room, source_position, perceivers):
		if patron_id == victim_id:
			continue
		if _route_stimulus(patron_id, &"knockout_witnessed", &"visual", victim_id):
			seen[patron_id] = true
	for patron_id: StringName in _perception.auditory_recipients(source_room, perceivers):
		if patron_id == victim_id or seen.has(patron_id):
			continue
		_route_stimulus(patron_id, &"knockout_heard", &"auditory", victim_id)


func _advance_drags(step: float) -> void:
	for victim_id: StringName in _drags.keys():
		var drag: Dictionary = _drags[victim_id]
		match drag["phase"]:
			&"pickup":
				drag["remaining"] = float(drag["remaining"]) - step
				if float(drag["remaining"]) <= TIME_EPSILON:
					drag["phase"] = &"dragging"
					drag["remaining"] = DRAG_TO_INTAKE_SECONDS
					var patron: Dictionary = _patrons[victim_id]
					_set_activity(patron, &"being_dragged", &"tunnel")
					_patrons[victim_id] = patron
					_record(&"body_drag_started", victim_id, {"cultist_id": drag["cultist_id"]})
			&"dragging":
				drag["remaining"] = float(drag["remaining"]) - step
				if float(drag["remaining"]) <= TIME_EPSILON:
					_drags[victim_id] = drag
					_capture_dragged_body(victim_id)
					continue
		if _drags.has(victim_id):
			_drags[victim_id] = drag


# Crossing the Tunnel Intake completes the Capture exactly once: the record is
# erased and the body removed, so a finished drag cannot capture the victim again.
func _capture_dragged_body(victim_id: StringName) -> void:
	var drag: Dictionary = _drags[victim_id]
	_drags.erase(victim_id)
	_perception.remove_body(victim_id)
	var patron: Dictionary = _patrons[victim_id]
	_interaction_registry.release_actor(victim_id)
	patron["lifecycle"] = &"captured"
	_set_activity(patron, &"captured", &"tunnel")
	_patrons[victim_id] = patron
	_captures.append({"id": victim_id, "cause": &"knockout", "at": _simulated_seconds})
	_record(&"capture", victim_id, {"cause": &"knockout", "cultist_id": drag["cultist_id"]})


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
