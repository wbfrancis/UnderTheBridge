class_name OrdinaryVisitSession
extends RefCounted

signal snapshot_changed(snapshot: Dictionary)

const INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")
const ORDER_SYSTEM_SCRIPT := preload("res://scripts/orders/order_system.gd")
const PREPARED_DRINK_SYSTEM_SCRIPT := preload("res://scripts/drinks/prepared_drink_system.gd")
const PATRON_SUSPICION_SCRIPT := preload("res://scripts/patrons/patron_suspicion.gd")
const PATRON_PERCEPTION_SCRIPT := preload("res://scripts/patrons/patron_perception.gd")
const PATRON_INTENT_PLANNER_SCRIPT := preload("res://scripts/patrons/patron_intent_planner.gd")
const PATRON_ACTION_COORDINATOR_SCRIPT := preload("res://scripts/patrons/patron_action_coordinator.gd")
const CHARACTER_ACTION_SYSTEM_SCRIPT := preload("res://scripts/actions/character_action_system.gd")
const PATRON_SATISFACTION_SCRIPT := preload("res://scripts/patrons/patron_satisfaction.gd")
# Which room each activity places a Patron in, for line of sight and room hearing.
const ACTIVITY_ROOMS := {
	&"not_arrived": &"front",
	&"waiting_at_entrance": &"front",
	&"entering": &"front",
	&"normal_departure": &"front",
	&"awaiting_drink": &"main_hall",
	&"drinking": &"main_hall",
	&"socializing": &"main_hall",
	&"entering_bathroom": &"bathroom",
	&"bathroom_queued": &"hallway",
	&"mirror_check": &"bathroom",
	&"moving_to_toilet": &"bathroom",
	&"seated_bathroom_use": &"bathroom",
	&"moving_to_sink": &"bathroom",
	&"handwashing": &"bathroom",
	&"standing_bathroom_exit": &"bathroom",
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
	&"conversing": &"main_hall",
	&"following": &"front",
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
const BATHROOM_LINE_SLOT := &"bathroom_line_01"
const INTERCEPT_SLOT := &"intercept_position"
const DEPARTURE_AFTER_SEATED_SECONDS := 540.0
const PHYSICAL_DEPARTURE_TIMEOUT_SECONDS := 60.0
const DRINK_SECONDS := 30.0
const ORDER_IMPATIENT_SECONDS := 30.0
const ORDER_FAILURE_SECONDS := 60.0
const GROUP_WAIT_SECONDS := 30.0
const MISSED_ADMISSION_DEPARTURE_SECONDS := 15.0
const ADMIT_GROUP_SECONDS := 3.0
const ASK_TO_LEAVE_SECONDS := 10.0
const ASK_TO_LEAVE_SUSPICION := 5.0
const ASK_TO_LEAVE_MAX_SUSPICION := 75.0
const WRONG_DRINK_SATISFACTION := -10.0
const WRONG_DRINK_ACCEPTANCE_PERCENT := 50.0
const SOCIAL_MIN_SECONDS := 20.0
const SOCIAL_MAX_SECONDS := 40.0
const OFFER_ACCEPTANCE_PERCENT := 80.0
const OFFER_REFUSAL_COOLDOWN_SECONDS := 60.0
const INTOXICATION_DECAY_SECONDS := 240.0
const BATHROOM_CHECK_SECONDS := 5.0
# Bathroom Visit phase timings. Mirror Check and Handwashing are fixed standing
# phases; Seated Bathroom Use samples one whole-number duration per visit.
const BATHROOM_MIRROR_SECONDS := 5.0
const BATHROOM_HANDWASH_SECONDS := 5.0
const BATHROOM_USE_MIN_SECONDS := 8
const BATHROOM_USE_MAX_SECONDS := 15
# Danger-chain timings, ported from the bathroom danger spike and TECHNICAL_DESIGN §6/§7.1.
const TRAPDOOR_OPEN_SECONDS := 2.0
const TRAPDOOR_COOLDOWN_SECONDS := 3.0
# A captured Patron falls for a bounded time, then the panels close. Final removal
# and slot release happen only after the panels finish closing.
const TRAPDOOR_FALL_SECONDS := 0.6
const TRAPDOOR_CLOSE_SECONDS := 0.4
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
const KNOCKOUT_CHANCES: Array[float] = [40.0, 60.0, 80.0, 95.0]
const KNOCKOUT_HEARING_NOTICE_PERCENT := 50.0
const CULTIST_INCAPACITATED_SECONDS := 60.0
const STIR_SECONDS := 3.0
const BODY_PICKUP_SECONDS := 1.0
# 50%-speed drag to the Tunnel Intake; the same abstract front path as the Helper carry.
const DRAG_TO_INTAKE_SECONDS := 14.0
const DRAG_MOVEMENT_SCALE := 0.5
const DRAG_WITNESS_INTERVAL_SECONDS := 5.0
# Friendship Capture and stay-behind departures, from the GDD §5/§10.4/§11 and TECHNICAL_DESIGN §9.
const FRIENDSHIP_CIGARETTE_BONUS := 10.0
const FRIENDSHIP_CONVERSATION_PER_SECOND := 0.75
const FRIENDSHIP_TRUSTED_THRESHOLD := 75.0
const FRIENDSHIP_MAXIMUM := 100.0
# Deterministic walk that leads a Trusted follower to the Tunnel Intake (no roll).
const FOLLOW_TO_INTAKE_SECONDS := 14.0
const STAY_BEHIND_BASE := 10.0
const STAY_BEHIND_FRIENDSHIP_COEFF := 0.5
const STAY_BEHIND_INTOXICATION_COEFF := 15.0
const STAY_BEHIND_SUSPICION_COEFF := 0.6
const STAY_BEHIND_MAXIMUM := 90.0
const MAXIMUM_SUSPICION := 100.0
const TIME_EPSILON := 0.0001
# Bathroom activities where the occupant stands (capturable by the Trapdoor pulse).
# Every travel leg and both fixed standing phases are vulnerable; only the seated
# toilet phase protects the Patron.
const STANDING_BATHROOM_ACTIVITIES: Array[StringName] = [
	&"entering_bathroom",
	&"mirror_check",
	&"moving_to_toilet",
	&"moving_to_sink",
	&"handwashing",
	&"standing_bathroom_exit",
	&"investigation_search",
]
# A Patron using the bathroom finishes that visit before a maximum-Suspicion response
# fires (a seated Hard-Evidence witness escapes through `escape_after_bathroom` instead).
const DISPATCH_EXCLUDED_ACTIVITIES: Array[StringName] = [
	&"entering_bathroom",
	&"mirror_check",
	&"moving_to_toilet",
	&"seated_bathroom_use",
	&"moving_to_sink",
	&"handwashing",
	&"standing_bathroom_exit",
]
const CULTIST_IDS: Array[int] = ActorIds.CULTIST_IDS
const CAPTURE_ACTIONS: Array[StringName] = [
	&"activate_trapdoor",
	&"prepare_drugged_drink",
	&"knockout",
	&"drag_body",
	&"friendship_capture",
	&"rescue_persuasion",
]
const FULL_NIGHT_GROUP_DEFINITIONS = ActorRoster.FULL_NIGHT_GROUP_DEFINITIONS
const FULL_NIGHT_PATRON_DEFINITIONS = ActorRoster.FULL_NIGHT_PATRON_DEFINITIONS

var _seed: int = 0
var _rng := RandomNumberGenerator.new()
var _simulated_seconds: float = 0.0
var _seated_at: float = -1.0
var _full_night: bool = false
var _closing: bool = false
var _patrons: Dictionary = {}
var _patron_actions: Dictionary = {}
var _character_actions = CHARACTER_ACTION_SYSTEM_SCRIPT.new()
var _satisfaction: Dictionary = {}
var _patron_rngs: Dictionary = {}
var _groups: Dictionary = {}
var _seat_owners: Dictionary = {}
var _interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
var _order_system = ORDER_SYSTEM_SCRIPT.new()
var _prepared_drinks = PREPARED_DRINK_SYSTEM_SCRIPT.new()
var _events: Array[Dictionary] = []
var _autonomy_events: Array[Dictionary] = []
var _suspicion_states: Dictionary = {}
var _perception = PATRON_PERCEPTION_SCRIPT.new()
var _perception_log: Dictionary = {}
var _trapdoor_state: StringName = &"closed"
var _trapdoor_remaining: float = 0.0
var _trapdoor_eligible_occupant: int = ActorIds.NO_ACTOR
var _trapdoor_falling_patron: int = ActorIds.NO_ACTOR
var _trapdoor_fall_ratio: float = 0.0
var _captures: Array[Dictionary] = []
var _active_intercept: Dictionary = {}
var _defeat: bool = false
var _doses_remaining: int = DRUG_DOSES_AT_START
var _drug_prep: Dictionary = {}
var _admission: Dictionary = {}
var _ask_to_leave: Dictionary = {}
var _groups_missed_at_door := 0
var _collapses: Dictionary = {}
var _windup: Dictionary = {}
var _incapacitated_cultists: Dictionary = {}
var _stirs: Dictionary = {}
var _knockout_outcomes: Dictionary = {}
var _drags: Dictionary = {}
var _conversations: Dictionary = {}
var _follows: Dictionary = {}
var _peak_suspicion: float = 0.0
var _interceptions: int = 0
var _unattended_body_seconds: float = 0.0
var _physical_navigation_enabled := false
# One carried Prepared Drink per Cultist. This is the smallest state the GDD's
# Offer Drink precondition needs; it is not a general inventory.
var _carried_drinks: Dictionary = {}


func start(seed: int = 707, full_night: bool = false) -> void:
	_seed = seed
	_rng.seed = seed
	_simulated_seconds = 0.0
	_seated_at = -1.0
	_full_night = full_night
	_closing = false
	_events.clear()
	_autonomy_events.clear()
	_carried_drinks.clear()
	_seat_owners.clear()
	var seat_count := 8 if full_night else 2
	for index in range(seat_count):
		_seat_owners[StringName("seat_%02d" % (index + 1))] = ActorIds.NO_ACTOR
	_interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
	_interaction_registry.register_slot(BATHROOM_SLOT, &"bathroom")
	_interaction_registry.register_slot(BATHROOM_LINE_SLOT, &"bathroom_line")
	_interaction_registry.register_slot(INTERCEPT_SLOT, &"intercept")
	_order_system = ORDER_SYSTEM_SCRIPT.new()
	_prepared_drinks = PREPARED_DRINK_SYSTEM_SCRIPT.new()
	_patrons.clear()
	_patron_rngs.clear()
	_groups.clear()
	if full_night:
		_initialize_full_night_cast()
	else:
		_initialize_legacy_pair()
	_patron_actions.clear()
	_character_actions = CHARACTER_ACTION_SYSTEM_SCRIPT.new()
	for cultist_id: int in [1, 2, 3]:
		_character_actions.register_actor(cultist_id, &"cultist")
	_satisfaction.clear()
	for patron_id: int in _patrons:
		var initial_activity: StringName = _patrons[patron_id]["activity"]
		var initial_destination: StringName = _patrons[patron_id]["navigation_destination"]
		_patrons[patron_id].erase("activity")
		_patrons[patron_id].erase("activity_elapsed")
		_patrons[patron_id].erase("navigation_destination")
		_patrons[patron_id].erase("navigation_arrived")
		_patron_actions[patron_id] = PATRON_ACTION_COORDINATOR_SCRIPT.new(
			patron_id, _interaction_registry, _character_actions, initial_activity
		)
		_patron_actions[patron_id].submit(initial_activity, initial_destination)
		_satisfaction[patron_id] = PATRON_SATISFACTION_SCRIPT.new()
	_suspicion_states.clear()
	for patron_id: int in _patrons:
		_suspicion_states[patron_id] = PATRON_SUSPICION_SCRIPT.new()
	_perception = PATRON_PERCEPTION_SCRIPT.new()
	_perception_log.clear()
	_trapdoor_state = &"closed"
	_trapdoor_remaining = 0.0
	_trapdoor_eligible_occupant = ActorIds.NO_ACTOR
	_trapdoor_falling_patron = ActorIds.NO_ACTOR
	_trapdoor_fall_ratio = 0.0
	_captures.clear()
	_active_intercept.clear()
	_defeat = false
	_doses_remaining = DRUG_DOSES_AT_START
	_drug_prep.clear()
	_admission.clear()
	_ask_to_leave.clear()
	_groups_missed_at_door = 0
	_collapses.clear()
	_windup.clear()
	_incapacitated_cultists.clear()
	_stirs.clear()
	_knockout_outcomes.clear()
	_drags.clear()
	_conversations.clear()
	_follows.clear()
	_peak_suspicion = 0.0
	_interceptions = 0
	_unattended_body_seconds = 0.0
	_emit_snapshot()


func advance(simulated_seconds: float) -> void:
	if simulated_seconds <= 0.0:
		return
	var remaining := simulated_seconds
	while remaining > 0.0001:
		var step := minf(STEP_SECONDS, remaining)
		_simulated_seconds += step
		_activate_due_groups()
		_advance_waiting_groups(step)
		_advance_admission(step)
		_advance_ask_to_leave(step)
		for patron_id: int in _patrons:
			_advance_patron(patron_id, step)
		_advance_trapdoor(step)
		_advance_missing_companions(step)
		_advance_investigations(step)
		_advance_escape(step)
		_advance_drug_prep(step)
		_advance_drug(step)
		_advance_collapses(step)
		_advance_windup(step)
		_advance_incapacitated_cultists(step)
		_advance_stirs(step)
		_advance_drags(step)
		_advance_conversations(step)
		_advance_follows(step)
		_apply_body_pressure(step)
		_apply_companion_influence(step)
		_dispatch_maximum_responses()
		_try_group_departures()
		_try_stayer_departures()
		_track_peak_suspicion()
		remaining -= step
	_emit_snapshot()


func _track_peak_suspicion() -> void:
	for patron_id: int in _suspicion_states:
		_peak_suspicion = maxf(_peak_suspicion, float(_suspicion_states[patron_id].snapshot()["score"]))


func begin_closing() -> void:
	if _closing:
		return
	_closing = true
	_record(&"closing_started", &"night")
	_try_group_departures()
	_try_stayer_departures()
	_emit_snapshot()


func finish_night() -> void:
	_closing = true
	for patron_id: int in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] == &"leaving":
			patron["lifecycle"] = &"exited"
			_patron_actions[patron_id].submit(&"exited")
			_patrons[patron_id] = patron
			continue
		if patron["lifecycle"] != &"active":
			continue
		_depart_patron(patron_id, patron, &"night_ended")
	_interaction_registry = INTERACTION_REGISTRY_SCRIPT.new()
	_interaction_registry.register_slot(BATHROOM_SLOT, &"bathroom")
	_interaction_registry.register_slot(BATHROOM_LINE_SLOT, &"bathroom_line")
	_interaction_registry.register_slot(INTERCEPT_SLOT, &"intercept")
	_emit_snapshot()


func restart(seed: int = _seed, full_night: bool = _full_night) -> void:
	start(seed, full_night)


func set_physical_navigation_enabled(enabled: bool) -> void:
	_physical_navigation_enabled = enabled
	if not enabled:
		for patron_id: int in _patron_actions:
			_patron_actions[patron_id].report_navigation_arrival()


func patron_destination_reached(patron_id: int, action_id: int = -1) -> bool:
	if not _patrons.has(patron_id):
		return false
	if action_id >= 0 and int(_character_actions.active_request(patron_id).get("id", -1)) != action_id:
		return false
	_patron_actions[patron_id].report_navigation_arrival()
	if (
		_patrons[patron_id]["lifecycle"] == &"leaving"
		and _activity(_patrons[patron_id]) == &"normal_departure"
	):
		_patrons[patron_id]["lifecycle"] = &"exited"
		_patron_actions[patron_id].submit(&"exited")
		_record(&"front_exit_crossed", patron_id)
	return true


func request_patron_step_aside(
	patron_id: int, position: Vector3, incident_id: StringName
) -> bool:
	if not _patron_actions.has(patron_id):
		return false
	return _patron_actions[patron_id].request_step_aside(position, incident_id)


func apply_suspicion_stimulus(
		patron_id: int,
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
		source_id: Variant = ActorIds.NO_ACTOR,
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
	var effective_source: Variant = source_id if not is_same(source_id, ActorIds.NO_ACTOR) else source_room
	var perceived: Array[int] = []
	for patron_id: int in recipients:
		if _route_stimulus(patron_id, stimulus, channel, effective_source):
			perceived.append(patron_id)
	_emit_snapshot()
	return perceived


func add_unattended_body(body_id: int, room: StringName, position := Vector2.ZERO) -> void:
	_perception.add_body(body_id, room, position)


func set_unattended_body_state(body_id: int, state: StringName) -> void:
	_perception.set_body_state(body_id, state)


func drop_unattended_body(body_id: int, room: StringName, position := Vector2.ZERO) -> void:
	_perception.drop_body(body_id, room, position)


func remove_unattended_body(body_id: int) -> void:
	_perception.remove_body(body_id)


func _apply_body_pressure(step: float) -> void:
	_unattended_body_seconds += step * float(_perception.unattended_body_count())
	var ticks: Array = _perception.advance_bodies(step)
	for body_id: int in ticks:
		for patron_id: int in _patrons:
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
	for patron_id: int in _patrons:
		if _patrons[patron_id]["lifecycle"] == &"active":
			scores[patron_id] = _suspicion_states[patron_id].snapshot()["score"]
	for patron_id: int in scores:
		var patron: Dictionary = _patrons[patron_id]
		var candidates: Array = []
		for companion_id: int in patron["companions"]:
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
		patron_id: int,
		stimulus: StringName,
		channel: StringName,
		source_id: Variant
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
		patron_id: int,
		source_id: Variant,
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
	for patron_id: int in _patrons:
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
	return ACTIVITY_ROOMS.get(_activity(patron), &"main_hall")


# Deterministic 2-D layout in metres. Seated Patrons sit at fixed table seats and
# face the bar counter; unseated Patrons take a representative spot for their room.
# Tables hold two seats 1.5 m apart and stand well over 5 m from each other, so a
# seated pair shares a table (Companion range) while other tables do not.
func _patron_position(patron: Dictionary) -> Vector2:
	var seat: StringName = patron["seat"]
	if SEAT_POSITIONS.has(seat):
		return SEAT_POSITIONS[seat]
	match _patron_room(patron):
		&"front": return Vector2(-17.5, 5.0)
		&"hallway": return Vector2(14.0, 6.0)
		&"bathroom": return Vector2(18.0, 6.0)
	return Vector2(0.0, 8.0)


func _patron_facing(patron: Dictionary) -> Vector2:
	var to_bar := BAR_POSITION - _patron_position(patron)
	if to_bar.length() <= 0.0001:
		return Vector2(0.0, -1.0)
	return to_bar.normalized()


func normal_patron_view(
		patron_id: int,
		selected_cultist_id: int = 1
) -> Dictionary:
	if not _patrons.has(patron_id):
		return {}
	var patron: Dictionary = _patrons[patron_id]
	var suspicion = _suspicion_states[patron_id]
	return {
		"id": patron_id,
		"identified": patron["identified"],
		"interactive": not bool(patron.get("missed_admission", false)),
		"name": patron["name"] if patron["identified"] else "???",
		"visible_activity": _visible_activity(_activity(patron)),
		# Mood is the derived word; the two bands beneath it are its inputs. The
		# prototype shows all three so the derivation can be judged against what
		# fed it. The settled design shows Mood alone.
		"mood": PatronMood.label(
			_satisfaction[patron_id].value(), float(suspicion.snapshot()["score"])
		),
		"satisfaction_band": _satisfaction[patron_id].band(),
		"suspicion_band": suspicion.normal_band(),
		"suspicion_cue": suspicion.normal_cue(),
		"intoxication": _intoxication_label(patron["intoxication"]),
		"ideal_intoxication": _intoxication_label(patron["ideal_intoxication"]) if patron["identified"] else "???",
		"arrival_group": patron["group_id"] if patron["identified"] else "???",
		"companions": patron["companions"].duplicate() if patron["identified"] else "???",
		"friendship": _friendship_band(patron["friendship"].get(selected_cultist_id, 0)) if patron["identified"] else "???",
		"order_state": _patron_order_state(patron),
		"ordered_drink": _patron_order_type(patron),
		"known_drugged_drink": "None",
		"victim_value": patron["victim_value"] if patron["identified"] else "???",
		"victim_risk": patron["victim_risk"] if patron["identified"] else "???",
		"urgent_intention": _urgent_intention(patron),
	}


# The single observable overhead intention, if any: ordering, choosing/queueing for the
# bathroom, Investigation, or Escape. Everything else reads as no urgent intention.
func _urgent_intention(patron: Dictionary) -> StringName:
	match _activity(patron):
		&"awaiting_drink":
			return &"ordering"
		&"bathroom_queued", &"entering_bathroom", &"mirror_check", &"moving_to_toilet", &"seated_bathroom_use", &"moving_to_sink", &"handwashing", &"waiting_investigation":
			return &"bathroom"
		&"investigation_search":
			return &"investigating"
		&"shock", &"escaping", &"intercepted":
			return &"escaping"
	return &"none"


# The sanitized projection the Emote system reads. It carries only what the
# player may already see: identity, presence, one public state, public band
# labels, and public change events. No exact value or internal timer crosses it.
func patron_emote_row(patron_id: int) -> Dictionary:
	if not _patrons.has(patron_id):
		return {}
	var patron: Dictionary = _patrons[patron_id]
	var view := normal_patron_view(patron_id)
	var lifecycle: StringName = patron["lifecycle"]
	var state: StringName = _public_emote_state(patron, view)
	var row := {
		"id": patron_id,
		"kind": &"patron",
		"present": lifecycle not in [&"not_arrived", &"capturing", &"captured", &"exited"],
		"state": state,
		"changes": [],
		"events": _patron_public_emote_events(patron_id),
		"public": {
			"activity": view["visible_activity"],
			# Service reactions step through the Satisfaction bands. The derived
			# Mood word is not a ladder, so it cannot drive a step comparison.
			"satisfaction": view["satisfaction_band"],
			"danger": view["suspicion_band"],
			"rapport": view["friendship"],
			"order": String(view["order_state"]),
			"ordered_drink": String(view["ordered_drink"]),
			"drug_cue": String(view["known_drugged_drink"]),
		},
	}
	# Prototype information policy: the bathroom emote exposes the three phase names
	# and their normalized progress. A future locked policy would omit this field;
	# the bathroom simulation never branches on it.
	if state == &"bathroom":
		row["progress"] = _bathroom_emote_progress(patron)
	elif state == &"ordering" and _order_system.is_open(patron["order_id"]):
		var requested_at := float(_order_system.order_snapshot(patron["order_id"])["requested_at"])
		row["progress"] = {
			"phase": &"order_patience",
			"ratio": clampf((_simulated_seconds - requested_at) / ORDER_FAILURE_SECONDS, 0.0, 1.0),
		}
	return row


func _patron_public_emote_events(patron_id: int) -> Array[Dictionary]:
	for index in range(_events.size() - 1, -1, -1):
		var event: Dictionary = _events[index]
		if not is_same(event["actor_id"], patron_id):
			continue
		if event["event"] == &"drink_service_result":
			return [{
				"id": index + 1,
				"kind": &"service_smile" if event["details"].get("expression", &"frown") == &"smile" else &"service_frown",
			}]
		if event["event"] == &"ask_to_leave_result":
			return [{"id": index + 1, "kind": &"service_frown"}]
	return []


# The three consecutive vertical fills of the Bathroom Visit. Walking between
# stations invents no progress; only the timed phases carry a ratio. The UI owns
# no timer: it receives one normalized ratio and the phase identity.
func _bathroom_emote_progress(patron: Dictionary) -> Dictionary:
	var elapsed := _behavior_elapsed(patron)
	match _activity(patron):
		&"mirror_check":
			return _phase_progress(&"mirror", 0, elapsed, BATHROOM_MIRROR_SECONDS)
		&"seated_bathroom_use":
			return _phase_progress(&"toilet", 1, elapsed, maxf(float(patron["bathroom_use_seconds"]), 0.001))
		&"handwashing":
			return _phase_progress(&"handwashing", 2, elapsed, BATHROOM_HANDWASH_SECONDS)
	return {"phase": &"", "index": -1, "count": 3, "ratio": 0.0}


func _phase_progress(phase: StringName, index: int, elapsed: float, duration: float) -> Dictionary:
	return {
		"phase": phase,
		"index": index,
		"count": 3,
		"ratio": clampf(elapsed / duration, 0.0, 1.0),
	}


# One public state for each Patron, in the order the Emote catalog ranks them.
func _public_emote_state(patron: Dictionary, view: Dictionary) -> StringName:
	match StringName(view["urgent_intention"]):
		&"escaping":
			return &"escaping"
		&"investigating":
			return &"investigating"
		&"bathroom":
			return &"bathroom"
		&"ordering":
			return &"ordering"
	if patron["lifecycle"] == &"unconscious" or _activity(patron) == &"being_dragged":
		return &"unconscious"
	if _activity(patron) == &"conversing":
		return &"conversation"
	return &"none"


func conversing_cultists() -> Array[int]:
	var result: Array[int] = []
	for cultist_id: int in _conversations:
		result.append(cultist_id)
	return result


func peak_suspicion() -> float:
	return _peak_suspicion


func interception_count() -> int:
	return _interceptions


func unattended_body_seconds() -> float:
	return _unattended_body_seconds


# Capture counts grouped by route cause, for the results screen.
func capture_methods() -> Dictionary:
	var methods: Dictionary = {}
	for capture: Dictionary in _captures:
		var cause: StringName = capture["cause"]
		methods[cause] = int(methods.get(cause, 0)) + 1
	return methods


# The exact Rescue Persuasion odds for the current carrying collapse, or -1 when none is
# available. Surfaced so the HUD can display the committed chance before the roll.
func current_rescue_odds() -> float:
	var victim_id := _active_collapse_with_helper()
	if victim_id == ActorIds.NO_ACTOR:
		return -1.0
	return rescue_persuasion_chance(_collapses[victim_id]["acting_cultist"] if int(_collapses[victim_id]["acting_cultist"]) != ActorIds.NO_ACTOR else 1)


func character_actions():
	return _character_actions


func debug_cancel_patron_action(patron_id: int, action_id: int, current_position: Variant = null) -> bool:
	if not _patron_actions.has(patron_id):
		return false
	var active: Dictionary = _character_actions.active_request(patron_id)
	var fallback := &"socializing" if _patrons[patron_id]["lifecycle"] == &"active" else _activity(_patrons[patron_id])
	var cancelled: bool = _patron_actions[patron_id].cancel(action_id, fallback, false, current_position)
	if cancelled and int(active.get("id", -1)) == action_id and active.get("name", &"") != &"step_aside":
		_cleanup_debug_patron_action(patron_id)
	return cancelled


func debug_force_complete_patron_action(patron_id: int) -> bool:
	if not _patron_actions.has(patron_id) or not _patron_actions[patron_id].force_ready():
		return false
	var activity := _activity(_patrons[patron_id])
	if activity in [&"shock", &"escaping"]:
		_patrons[patron_id]["escape_remaining"] = 0.0
	for victim_id: int in _collapses:
		if _collapses[victim_id].get("helper_id", ActorIds.NO_ACTOR) == patron_id:
			_collapses[victim_id]["remaining"] = 0.0
	_advance_patron(patron_id, 0.0)
	_advance_investigations(0.0)
	_advance_escape(0.0)
	_advance_collapses(0.0)
	return true


func debug_clear_patron_queue(patron_id: int) -> bool:
	if not _patron_actions.has(patron_id):
		return false
	var active: Dictionary = _character_actions.active_request(patron_id)
	if active.is_empty():
		return true
	var fallback := &"socializing" if _patrons[patron_id]["lifecycle"] == &"active" else _activity(_patrons[patron_id])
	var cleared: bool = _patron_actions[patron_id].cancel(int(active["id"]), fallback, true)
	if cleared:
		_cleanup_debug_patron_action(patron_id)
	return cleared


func _cleanup_debug_patron_action(patron_id: int) -> void:
	var patron: Dictionary = _patrons[patron_id]
	var order_id := StringName(patron["order_id"])
	if _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"debug_cancelled")
	for cultist_id: int in _conversations.keys():
		if _conversations[cultist_id] == patron_id:
			_conversations.erase(cultist_id)
	if not _ask_to_leave.is_empty() and _ask_to_leave["patron_id"] == patron_id:
		_ask_to_leave["state"] = &"failed"


func debug_set_patron_planner_paused(patron_id: int, paused: bool) -> bool:
	if not _patron_actions.has(patron_id):
		return false
	_patron_actions[patron_id].set_planner_paused(paused)
	return true


func debug_patron_view(patron_id: int) -> Dictionary:
	if not _patrons.has(patron_id):
		return {}
	var patron: Dictionary = _patrons[patron_id]
	var suspicion: Dictionary = _suspicion_states[patron_id].snapshot()
	var probability := bathroom_probability(float(patron["bladder"]))
	return {
		"id": patron_id,
		"name": patron["name"],
		"identified": patron["identified"],
		"bladder": patron["bladder"],
		"bathroom_probability": probability,
		"next_bathroom_check_in": maxf(0.0, float(patron["next_bathroom_check_at"]) - _simulated_seconds) if patron["bathroom_checks_active"] else -1.0,
		"bathroom_use_seconds": patron["bathroom_use_seconds"],
		"intoxication_level": patron["intoxication"],
		"ideal_intoxication_level": patron["ideal_intoxication"],
		"overdrink_limit": patron["overdrink_limit"],
		"excess_drinks": patron["excess_drinks"],
		"collapse_cause": patron["collapse_cause"],
		"intoxication_decay_in": patron["intoxication_decay_in"],
		"satisfaction_value": _satisfaction[patron_id].value(),
		"satisfaction_band": _satisfaction[patron_id].band(),
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
		"missed_admission": bool(patron.get("missed_admission", false)),
		"activity": _activity(patron),
		"behavior": _patron_actions[patron_id].snapshot(),
		"seat": patron["seat"],
		"reservation": _interaction_registry.actor_slot(patron_id),
		"navigation_destination": _behavior_snapshot(patron)["destination"],
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
		"friendship_capturable": patron["friendship_capturable"],
		"stay_rolled": patron["stay_rolled"],
		"stayed_behind": patron["stayed_behind"],
	}


func snapshot() -> Dictionary:
	var normal_views: Dictionary = {}
	var debug_views: Dictionary = {}
	for patron_id: int in _patrons:
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
		"bathroom_line_owner": _interaction_registry.slot_owner(BATHROOM_LINE_SLOT),
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
			"locked": _trapdoor_locked(),
			"falling_patron": _trapdoor_falling_patron,
			"fall_ratio": _trapdoor_fall_ratio,
			"close_ratio": _trapdoor_close_ratio(),
		},
		"captures": _captures.duplicate(true),
		"defeat": _defeat,
		"active_intercept": _active_intercept.duplicate(true),
		"escaping_patrons": _escaping_patron_ids(),
		"doses_remaining": _doses_remaining,
		"drug_prep": _drug_prep.duplicate(true),
		"prepared_drinks": _prepared_drinks.snapshot(),
		"admission": _admission.duplicate(true),
		"ask_to_leave": _ask_to_leave.duplicate(true),
		"groups_missed_at_door": _groups_missed_at_door,
		"collapses": _collapses.duplicate(true),
		"windup": _windup.duplicate(true),
		"incapacitated_cultists": _incapacitated_cultists.duplicate(true),
		"stirs": _stirs.duplicate(true),
		"drags": _drags.duplicate(true),
		"conversations": _conversations.duplicate(true),
		"follows": _follows.duplicate(true),
		"peak_suspicion": _peak_suspicion,
		"interceptions": _interceptions,
		"unattended_body_seconds": _unattended_body_seconds,
		"capture_methods": capture_methods(),
		"rescue_odds": current_rescue_odds(),
	}


func _escaping_patron_ids() -> Array[int]:
	var ids: Array[int] = []
	for patron_id: int in _patrons:
		if _patrons[patron_id]["lifecycle"] == &"escaping":
			ids.append(patron_id)
	return ids


static func bathroom_probability(bladder: float) -> float:
	if bladder < 50.0:
		return 0.0
	return clampf(1.0 + 89.0 * ((bladder - 50.0) / 50.0), 1.0, 90.0)


func _initialize_legacy_pair() -> void:
	var members: Array[int] = []
	var group_label := ""
	for definition in FULL_NIGHT_PATRON_DEFINITIONS:
		if definition["group_id"] != GROUP_ID:
			continue
		var patron_id: int = definition["id"]
		members.append(patron_id)
		_patrons[patron_id] = _new_patron(
			patron_id, definition["name"], GROUP_ID, definition["companions"],
			definition["bladder_gain"], definition["service_delay"], &"active",
			definition["victim_value"], definition["victim_risk"],
			definition.get("friendship_capturable", false), definition["seed_key"]
		)
	for definition in FULL_NIGHT_GROUP_DEFINITIONS:
		if definition["id"] == GROUP_ID:
			group_label = definition["label"]
	_groups[GROUP_ID] = {
		"id": GROUP_ID,
		"label": group_label,
		"arrival_at": 0.0,
		"patrons": members,
		"arrived": true,
		"waiting": false,
		"wait_remaining": 0.0,
		"admitted": true,
		"missed": false,
		"asked_to_leave": false,
		"seated_at": -1.0,
		"departed": false,
	}
	_reserve_group_seats(GROUP_ID)
	_record(&"arrival_group_arrived", GROUP_ID)


func _initialize_full_night_cast() -> void:
	for definition in FULL_NIGHT_PATRON_DEFINITIONS:
		var patron_id: int = definition["id"]
		_patrons[patron_id] = _new_patron(
			patron_id,
			definition["name"],
			definition["group_id"],
			definition["companions"],
			definition["bladder_gain"],
			definition["service_delay"],
			&"not_arrived",
			definition["victim_value"],
			definition["victim_risk"],
			definition.get("friendship_capturable", false),
			definition["seed_key"]
		)
	for definition in FULL_NIGHT_GROUP_DEFINITIONS:
		var group_id: StringName = definition["id"]
		_groups[group_id] = {
			"id": group_id,
			"label": definition["label"],
			"arrival_at": definition["arrival_at"],
			"patrons": definition["patrons"].duplicate(),
			"arrived": false,
			"waiting": false,
			"wait_remaining": GROUP_WAIT_SECONDS,
			"admitted": false,
			"missed": false,
			"asked_to_leave": false,
			"seated_at": -1.0,
			"departed": false,
		}


func _new_patron(
		id: int,
		display_name: String,
		group_id: StringName,
		companions: Array,
		bladder_gain: float,
		service_delay: float,
		lifecycle: StringName,
		victim_value: String,
		victim_risk: String,
		friendship_capturable: bool,
		seed_key: StringName
) -> Dictionary:
	var patron_rng := RandomNumberGenerator.new()
	# Seeded rolls hang off an authored content key, never off identity, so that
	# renaming or renumbering a Patron cannot silently reroll their Night.
	assert(not seed_key.is_empty(), "Every Patron needs an authored seed key.")
	patron_rng.seed = hash("%d:%s:patron" % [_seed, seed_key])
	_patron_rngs[id] = patron_rng
	var ideal_intoxication := clampi(int(round(patron_rng.randfn(2.0, 0.6))), 0, 3)
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
		"ideal_intoxication": ideal_intoxication,
		"overdrink_limit": patron_rng.randi_range(1, 5),
		"excess_drinks": 0,
		"collapse_cause": &"",
		"body_room": &"",
		"body_position": Vector2.ZERO,
		"intoxication_decay_in": -1.0,
		"social_interval": patron_rng.randf_range(SOCIAL_MIN_SECONDS, SOCIAL_MAX_SECONDS),
		"order_impatient": false,
		"failed_orders": 0,
		"offer_refused_until": -1.0,
		"bathroom_checks_active": false,
		"next_bathroom_check_at": -1.0,
		"bathroom_use_seconds": 0.0,
		"recent_bathroom_rolls": [],
		"navigation_destination": &"entrance" if lifecycle == &"not_arrived" else &"seat",
		"navigation_arrived": true,
		"departure_timeout": -1.0,
		"identified": false,
		"friendship": {1: 0.0, 2: 0.0, 3: 0.0},
		"friendship_capturable": friendship_capturable,
		"victim_value": victim_value,
		"victim_risk": victim_risk,
		"missing_target": ActorIds.NO_ACTOR,
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
		"helper_id": ActorIds.NO_ACTOR,
		"helping_victim": ActorIds.NO_ACTOR,
		"stay_rolled": false,
		"stayed_behind": false,
	}


func _activate_due_groups() -> void:
	if not _full_night:
		return
	for group_id: StringName in _groups:
		var group: Dictionary = _groups[group_id]
		if group["arrived"] or group["waiting"] or group["missed"] or _simulated_seconds + 0.0001 < float(group["arrival_at"]):
			continue
		group["waiting"] = true
		group["wait_remaining"] = GROUP_WAIT_SECONDS
		_groups[group_id] = group
		for patron_id: int in group["patrons"]:
			var patron: Dictionary = _patrons[patron_id]
			patron["lifecycle"] = &"waiting_at_entrance"
			_set_activity(patron, &"waiting_at_entrance", &"entrance")
			_patrons[patron_id] = patron
		_record(&"arrival_group_waiting", group_id)


func _advance_waiting_groups(step: float) -> void:
	for group_id: StringName in _groups:
		var group: Dictionary = _groups[group_id]
		if not group.get("waiting", false) or group.get("missed", false):
			continue
		if not _admission.is_empty() and _admission["group_id"] == group_id:
			continue
		group["wait_remaining"] = maxf(0.0, float(group["wait_remaining"]) - step)
		if float(group["wait_remaining"]) <= TIME_EPSILON:
			group["waiting"] = false
			group["missed"] = true
			group["departed"] = true
			_groups_missed_at_door += 1
			for patron_id: int in group["patrons"]:
				var patron: Dictionary = _patrons[patron_id]
				patron["missed_admission"] = true
				patron["lifecycle"] = &"leaving" if _physical_navigation_enabled else &"exited"
				patron["departure_timeout"] = MISSED_ADMISSION_DEPARTURE_SECONDS
				_set_activity(patron, &"normal_departure", &"front_exit")
				if not _physical_navigation_enabled:
					_patron_actions[patron_id].submit(&"exited", &"front_exit")
			_record(&"arrival_group_missed", group_id)
		_groups[group_id] = group


func begin_admit_group(cultist_id: int, group_id: StringName) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _admission.is_empty() or not _groups.has(group_id):
		return false
	var group: Dictionary = _groups[group_id]
	if not group.get("waiting", false) or group.get("missed", false):
		return false
	_admission = {
		"cultist_id": cultist_id, "group_id": group_id,
		"phase": &"opening", "remaining": ADMIT_GROUP_SECONDS,
	}
	_record(&"admission_started", group_id, {"cultist_id": cultist_id})
	return true


func cancel_admit_group(cultist_id: int) -> bool:
	if _admission.is_empty() or _admission["cultist_id"] != cultist_id or _admission["phase"] != &"opening":
		return false
	_admission.clear()
	return true


func _advance_admission(step: float) -> void:
	if _admission.is_empty() or _admission["phase"] != &"opening":
		return
	_admission["remaining"] = float(_admission["remaining"]) - step
	if float(_admission["remaining"]) > TIME_EPSILON:
		return
	var group_id: StringName = _admission["group_id"]
	var group: Dictionary = _groups[group_id]
	if not _reserve_group_seats(group_id):
		_admission.clear()
		return
	group["waiting"] = false
	group["admitted"] = true
	group["arrived"] = true
	_groups[group_id] = group
	_admission["phase"] = &"holding"
	_admission["remaining"] = 0.0
	for patron_id: int in group["patrons"]:
		var patron: Dictionary = _patrons[patron_id]
		patron["lifecycle"] = &"active"
		_set_activity(patron, &"entering", &"seat")
		_patrons[patron_id] = patron
	_record(&"arrival_group_admitted", group_id, {"cultist_id": _admission["cultist_id"]})


func _admission_complete() -> bool:
	if _admission.is_empty() or _admission["phase"] != &"holding":
		return false
	var group: Dictionary = _groups[_admission["group_id"]]
	for patron_id: int in group["patrons"]:
		if _activity(_patrons[patron_id]) == &"entering":
			return false
	return true


func _advance_patron(patron_id: int, delta: float) -> void:
	if not _windup.is_empty() and _windup["victim_id"] == patron_id:
		return
	var patron: Dictionary = _patrons[patron_id]
	_patron_actions[patron_id].advance(delta)
	if not _patron_actions[patron_id].has_action() and patron["lifecycle"] == &"active":
		_set_activity(patron, &"socializing", &"seat")
	if patron["lifecycle"] == &"leaving":
		patron["departure_timeout"] = float(patron["departure_timeout"]) - delta
		if float(patron["departure_timeout"]) <= TIME_EPSILON:
			patron["lifecycle"] = &"exited"
			_patron_actions[patron_id].submit(&"exited", &"front_exit")
			_record(&"departure_timeout_expired", patron_id)
		_patrons[patron_id] = patron
		return
	if patron["lifecycle"] != &"active":
		return
	var recovered: float = _suspicion_states[patron_id].advance(delta)
	if recovered > 0.0:
		_record(&"suspicion_recovered", patron_id, {"amount": recovered})
	_apply_overdrink_body_satisfaction(patron_id, patron)
	_advance_intoxication(patron_id, patron, delta)
	if _character_actions.active_request(patron_id).get("name", &"") == &"step_aside":
		return
	match _activity(patron):
		&"entering":
			if _movement_complete(patron, 1.0):
				_assign_seat(patron_id, patron)
		&"awaiting_drink":
			_advance_open_order(patron_id, patron)
		&"drinking":
			if _behavior_elapsed(patron) >= DRINK_SECONDS:
				_finish_drink(patron_id, patron)
		&"socializing":
			_advance_bathroom_checks(patron_id, patron)
			if (
				_activity(patron) == &"socializing"
				and not _closing
				and _behavior_elapsed(patron) >= float(patron["social_interval"])
				and _patron_can_order(patron)
			):
				_start_order(patron_id, patron)
		&"bathroom_queued":
			if _bathroom_occupant() == ActorIds.NO_ACTOR and not _trapdoor_locked():
				_interaction_registry.release_actor(patron_id)
				if _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
					_begin_bathroom_visit(patron_id, patron)
					_start_missing_companion_clock(patron_id)
					_record(&"bathroom_line_promoted", patron_id)
		&"entering_bathroom":
			if _movement_complete(patron, 2.0):
				_set_activity(patron, &"mirror_check", &"mirror")
				_record(&"bathroom_mirror_check", patron_id)
		&"mirror_check":
			if _behavior_elapsed(patron) >= BATHROOM_MIRROR_SECONDS:
				_set_activity(patron, &"moving_to_toilet", &"toilet")
		&"moving_to_toilet":
			if _movement_complete(patron, 2.0):
				_set_activity(patron, &"seated_bathroom_use", &"toilet")
				_record(&"bathroom_seated", patron_id)
		&"seated_bathroom_use":
			if _behavior_elapsed(patron) >= float(patron["bathroom_use_seconds"]):
				patron["bladder"] = 0.0
				_set_activity(patron, &"moving_to_sink", &"sink")
				_record(&"bladder_emptied", patron_id)
		&"moving_to_sink":
			if _movement_complete(patron, 2.0):
				_set_activity(patron, &"handwashing", &"sink")
				_record(&"bathroom_handwashing", patron_id)
		&"handwashing":
			if _behavior_elapsed(patron) >= BATHROOM_HANDWASH_SECONDS:
				_set_activity(patron, &"standing_bathroom_exit", &"bathroom_exit")
		&"standing_bathroom_exit":
			if _movement_complete(patron, 3.0):
				_interaction_registry.release_actor(patron_id)
				_clear_missing_companion_clock(patron_id)
				_record(&"bathroom_visit_completed", patron_id)
				if patron["escape_after_bathroom"]:
					patron["escape_after_bathroom"] = false
					_patrons[patron_id] = patron
					_begin_escape(patron_id)
					return
				_complete_activity(patron, &"socializing", &"seat")
	_patrons[patron_id] = patron


func _assign_seat(patron_id: int, patron: Dictionary) -> void:
	var seat_id: StringName = patron["seat"]
	if seat_id.is_empty() or _seat_owners.get(seat_id, ActorIds.NO_ACTOR) != patron_id:
		return
	if _patron_can_order(patron):
		_start_order(patron_id, patron)
	else:
		_set_activity(patron, &"socializing", &"seat")
	_record(&"seat_acquired", patron_id, {"seat": seat_id, "order_id": patron["order_id"]})
	_update_group_seated_at(patron["group_id"])


func _patron_can_order(patron: Dictionary) -> bool:
	return (
		patron["lifecycle"] == &"active"
		and not bool(_groups[patron["group_id"]].get("asked_to_leave", false))
		and int(patron["intoxication"]) < int(patron["ideal_intoxication"])
		and (StringName(patron["order_id"]).is_empty() or not _order_system.is_open(patron["order_id"]))
	)


func _start_order(patron_id: int, patron: Dictionary) -> void:
	_set_activity(patron, &"awaiting_drink", &"seat")
	var requested_type: StringName = PREPARED_DRINK_SYSTEM_SCRIPT.DRINK_TYPES[
		_patron_rngs[patron_id].randi_range(0, PREPARED_DRINK_SYSTEM_SCRIPT.DRINK_TYPES.size() - 1)
	]
	patron["order_id"] = _order_system.create_order(patron_id, _simulated_seconds, requested_type)
	patron["order_impatient"] = false
	_record(&"order_created", patron_id, {
		"order_id": patron["order_id"], "drink_type": requested_type,
	})


func _patron_order_type(patron: Dictionary) -> StringName:
	var order_id: StringName = patron["order_id"]
	if order_id.is_empty():
		return &"none"
	return StringName(_order_system.order_snapshot(order_id).get("drink_type", &"none"))


func _advance_open_order(patron_id: int, patron: Dictionary) -> void:
	var order_id: StringName = patron["order_id"]
	if order_id.is_empty() or not _order_system.is_open(order_id):
		return
	var elapsed := _simulated_seconds - float(_order_system.order_snapshot(order_id)["requested_at"])
	if elapsed >= ORDER_IMPATIENT_SECONDS and not patron["order_impatient"]:
		patron["order_impatient"] = true
		_record(&"order_impatient", patron_id, {"order_id": order_id})
	if elapsed < ORDER_FAILURE_SECONDS:
		return
	_order_system.cancel_order(order_id, _simulated_seconds, &"failed_service")
	patron["failed_orders"] = int(patron["failed_orders"]) + 1
	_satisfaction[patron_id].change(-20.0, &"failed_order")
	_suspicion_states[patron_id].apply_stimulus(&"cancelled_order")
	_record(&"order_failed", patron_id, {
		"order_id": order_id,
		"failed_orders": patron["failed_orders"],
		"satisfaction": _satisfaction[patron_id].value(),
	})
	if int(patron["failed_orders"]) >= 2 or _satisfaction[patron_id].value() <= 0.0:
		_depart_patron(patron_id, patron, &"failed_orders")
	else:
		patron["social_interval"] = _patron_rngs[patron_id].randf_range(
			SOCIAL_MIN_SECONDS, SOCIAL_MAX_SECONDS
		)
		_set_activity(patron, &"socializing", &"seat")


func _reserve_group_seats(group_id: StringName) -> bool:
	var group: Dictionary = _groups[group_id]
	var members: Array = group["patrons"]
	var available: Array[StringName] = []
	for seat_id: StringName in _seat_owners:
		if int(_seat_owners[seat_id]) == ActorIds.NO_ACTOR:
			available.append(seat_id)
	if available.size() < members.size():
		return false
	for index in range(members.size()):
		var patron_id: int = members[index]
		var seat_id: StringName = available[index]
		_seat_owners[seat_id] = patron_id
		_patrons[patron_id]["seat"] = seat_id
	_record(&"arrival_group_seats_reserved", group_id, {"seat_count": members.size()})
	return true


func _update_group_seated_at(group_id: StringName) -> void:
	var group: Dictionary = _groups[group_id]
	if float(group["seated_at"]) >= 0.0:
		return
	for member_id: int in group["patrons"]:
		if StringName(_patrons[member_id]["seat"]).is_empty():
			return
	group["seated_at"] = _simulated_seconds
	_groups[group_id] = group
	if group_id == GROUP_ID:
		_seated_at = _simulated_seconds
	_record(&"arrival_group_seated", group_id)


# --- Cultist commands --------------------------------------------------------

func waiting_group_id() -> StringName:
	for group_id: StringName in _groups:
		if bool(_groups[group_id].get("waiting", false)):
			return group_id
	return &""


func ask_to_leave_availability(patron_id: int) -> Dictionary:
	if not _patrons.has(patron_id) or _patrons[patron_id]["lifecycle"] != &"active":
		return _command_state(false, false, &"patron_unavailable")
	var group: Dictionary = _groups[_patrons[patron_id]["group_id"]]
	if bool(group.get("asked_to_leave", false)):
		return _command_state(false, false, &"patron_unavailable")
	for member_id: int in group["patrons"]:
		var lifecycle: StringName = _patrons[member_id]["lifecycle"]
		if lifecycle == &"unconscious":
			return _command_state(true, false, &"unconscious_group_member")
		if lifecycle == &"active" and float(_suspicion_states[member_id].snapshot()["score"]) >= ASK_TO_LEAVE_MAX_SUSPICION:
			return _command_state(true, false, &"too_suspicious_to_leave")
	return _command_state(true, true, &"")


func begin_ask_to_leave(cultist_id: int, patron_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _ask_to_leave.is_empty():
		return false
	var state := ask_to_leave_availability(patron_id)
	if not bool(state["available"]):
		return false
	_ask_to_leave = {
		"cultist_id": cultist_id,
		"patron_id": patron_id,
		"group_id": _patrons[patron_id]["group_id"],
		"remaining": ASK_TO_LEAVE_SECONDS,
		"state": &"talking",
	}
	_set_activity(_patrons[patron_id], &"conversing", &"conversation")
	_record(&"ask_to_leave_started", patron_id, {"cultist_id": cultist_id})
	return true


func cancel_ask_to_leave(cultist_id: int) -> bool:
	if _ask_to_leave.is_empty() or _ask_to_leave["cultist_id"] != cultist_id:
		return false
	var patron_id: int = _ask_to_leave["patron_id"]
	if _patrons.has(patron_id) and _patrons[patron_id]["lifecycle"] == &"active":
		_set_activity(_patrons[patron_id], &"socializing", &"seat")
	_ask_to_leave.clear()
	return true


func _advance_ask_to_leave(step: float) -> void:
	if _ask_to_leave.is_empty() or _ask_to_leave["state"] != &"talking":
		return
	var patron_id: int = _ask_to_leave["patron_id"]
	var state := ask_to_leave_availability(patron_id)
	if not bool(state["available"]):
		_ask_to_leave["state"] = &"failed"
		if _patrons.has(patron_id) and _patrons[patron_id]["lifecycle"] == &"active":
			_set_activity(_patrons[patron_id], &"socializing", &"seat")
		return
	_ask_to_leave["remaining"] = float(_ask_to_leave["remaining"]) - step
	if float(_ask_to_leave["remaining"]) > TIME_EPSILON:
		return
	var group_id: StringName = _ask_to_leave["group_id"]
	var group: Dictionary = _groups[group_id]
	group["asked_to_leave"] = true
	_groups[group_id] = group
	for member_id: int in group["patrons"]:
		if _patrons[member_id]["lifecycle"] == &"active":
			_suspicion_states[member_id].apply_stimulus(&"asked_to_leave")
			_record(&"ask_to_leave_result", member_id)
	_ask_to_leave["state"] = &"completed"
	_record(&"group_asked_to_leave", group_id, {"cultist_id": _ask_to_leave["cultist_id"]})
	_try_group_departures()


# Completes one five-second bar Action by placing a typed Prepared Drink in the
# oldest available bar position. Preparation does not need an open Order.
func make_drink(drink_type: StringName, cultist_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _prepared_drinks.can_add():
		return false
	var result: Dictionary = _prepared_drinks.add_drink(drink_type)
	if not bool(result["added"]):
		return false
	_record(&"prepared_drink_made", StringName(result["drink_id"]), {
		"cultist_id": cultist_id,
		"drink_type": drink_type,
		"evicted_id": result["evicted_id"],
	})
	_emit_snapshot()
	return true


# Kept as a narrow compatibility seam for older callers while menus migrate to
# the three explicit preparation commands.
func prepare_drink(cultist_id: int) -> bool:
	return make_drink(&"wine", cultist_id)


func carries_prepared_drink(cultist_id: int) -> bool:
	for drink: Dictionary in _prepared_drinks.snapshot()["drinks"]:
		if int(drink["carried_by"]) == cultist_id:
			return true
	return false


func prepared_drink(drink_id: StringName) -> Dictionary:
	return _prepared_drinks.drink(drink_id)


func reserve_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	return not is_cultist_busy(cultist_id) and _prepared_drinks.reserve(drink_id, cultist_id)


func pick_up_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	return _prepared_drinks.pick_up(drink_id, cultist_id)


func release_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	return _prepared_drinks.release(drink_id, cultist_id)


func dispose_prepared_drink(drink_id: StringName) -> Dictionary:
	var result: Dictionary = _prepared_drinks.dispose(drink_id)
	if bool(result["disposed"]):
		_record(&"prepared_drink_disposed", drink_id, {"cultist_id": result["cultist_id"]})
		_emit_snapshot()
	return result


func drug_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	if _doses_remaining <= 0 or not _prepared_drinks.drug(drink_id, cultist_id):
		return false
	_doses_remaining -= 1
	_record(&"prepared_drink_drugged", drink_id, {
		"cultist_id": cultist_id, "doses_remaining": _doses_remaining,
	})
	_emit_snapshot()
	return true


# Doses the longest-waiting open Order. The bar work position has no Patron of
# its own, so the target comes from the Order book, not from the player's click.
func prepare_drugged_drink_for_next_order(cultist_id: int) -> bool:
	var targets := _open_order_patrons()
	if targets.is_empty():
		return false
	return prepare_drugged_drink(targets[0], cultist_id)


func next_drug_target() -> int:
	var targets := _open_order_patrons()
	return ActorIds.NO_ACTOR if targets.is_empty() else targets[0]


# Ends a standing engagement so the Cultist's next Action can start. Only Talk
# holds a Cultist this way; every other operation ends on its own clock.
func end_cultist_engagement(cultist_id: int) -> bool:
	return end_conversation(cultist_id)


func conversation_is_active(cultist_id: int, patron_id: int) -> bool:
	return _conversations.get(cultist_id, ActorIds.NO_ACTOR) == patron_id


# The single authority for whether one command applies to one target right now.
# "visible" keeps structurally unrelated commands out of the menu; "available"
# with a short reason explains a temporary condition the player can act on.
func command_availability(
		command: StringName,
		cultist_id: int,
		target_id: Variant
) -> Dictionary:
	if cultist_is_incapacitated(cultist_id):
		return _command_state(true, false, &"cultist_incapacitated")
	match command:
		&"admit_group":
			var group_id := waiting_group_id()
			if group_id.is_empty():
				return _command_state(true, false, &"no_group_waiting")
			if not _admission.is_empty():
				return _command_state(true, false, &"cultist_busy")
			return _command_state(true, not _busy_for_command(cultist_id), &"cultist_busy")
		&"talk":
			var talk := _conscious_patron(target_id)
			if not talk:
				return _command_state(false, false, &"patron_unavailable")
			if _conversation_partner(target_id) != ActorIds.NO_ACTOR:
				return _command_state(true, false, &"not_receptive")
			return _command_state(true, not _busy_for_command(cultist_id), &"cultist_busy")
		&"ask_to_leave":
			var leave := ask_to_leave_availability(target_id)
			if not bool(leave["visible"]):
				return leave
			if not _ask_to_leave.is_empty():
				return _command_state(true, false, &"cultist_busy")
			return leave
		&"make_wine", &"make_beer", &"make_liquor":
			return _command_state(true, _prepared_drinks.can_add(), &"bar_full")
		&"drug_drink":
			if not _prepared_drinks.has(target_id):
				return _command_state(false, false, &"drink_unavailable")
			if _doses_remaining <= 0:
				return _command_state(true, false, &"no_doses")
			var drink: Dictionary = _prepared_drinks.drink(target_id)
			if bool(drink["drugged"]):
				return _command_state(true, false, &"already_drugged")
			if int(drink["reserved_by"]) != ActorIds.NO_ACTOR and drink["reserved_by"] != cultist_id:
				return _command_state(true, false, &"drink_reserved")
			return _command_state(true, true, &"")
		&"serve_order":
			if not _conscious_patron(target_id):
				return _command_state(false, false, &"patron_unavailable")
			if _activity(_patrons[target_id]) != &"awaiting_drink":
				return _command_state(false, false, &"no_open_order")
			return _command_state(true, true, &"")
		&"offer_drink":
			if not carries_prepared_drink(cultist_id):
				return _command_state(false, false, &"no_prepared_drink")
			if not _conscious_patron(target_id):
				return _command_state(false, false, &"patron_unavailable")
			var patron: Dictionary = _patrons[target_id]
			if _order_system.is_open(patron["order_id"]) or _activity(patron) != &"socializing":
				return _command_state(true, false, &"not_receptive")
			if _simulated_seconds < float(patron["offer_refused_until"]):
				return _command_state(true, false, &"not_receptive")
			return _command_state(true, true, &"")
		&"offer_cigarette":
			var smoker := _conscious_patron(target_id)
			return _command_state(smoker, smoker, &"patron_unavailable")
		&"knock_out":
			if not _knockout_target_available(target_id):
				return _command_state(false, false, &"patron_unavailable")
			if not _windup.is_empty():
				return _command_state(true, false, &"cultist_busy")
			var knockout := _command_state(true, not _busy_for_command(cultist_id), &"cultist_busy")
			knockout["detail"] = "%d%%" % int(knockout_chance(target_id))
			return knockout
		&"stir":
			if target_id == cultist_id or not cultist_is_incapacitated(target_id):
				return _command_state(false, false, &"invalid_target")
			if _stirs.has(target_id):
				return _command_state(true, false, &"already_helping")
			return _command_state(true, not _busy_for_command(cultist_id), &"cultist_busy")
		&"pick_up_body":
			if not _patrons.has(target_id) or _patrons[target_id]["lifecycle"] != &"unconscious":
				return _command_state(false, false, &"patron_unavailable")
			if _drags.has(target_id):
				return _command_state(false, false, &"patron_unavailable")
			if _collapses.has(target_id) and _collapses[target_id]["phase"] not in [
				&"reacting", &"unattended"
			]:
				return _command_state(true, false, &"not_receptive")
			return _command_state(true, not _busy_for_command(cultist_id), &"cultist_busy")
		&"intercept":
			if not _patrons.has(target_id) or _patrons[target_id]["lifecycle"] != &"escaping":
				return _command_state(false, false, &"patron_unavailable")
			if _activity(_patrons[target_id]) != &"escaping":
				return _command_state(true, false, &"not_receptive")
			if _patrons[target_id]["intercept_attempted"]:
				return _command_state(true, false, &"already_attempted")
			return _command_state(true, _active_intercept.is_empty(), &"cultist_busy")
		&"lead_to_tunnel":
			if not _conscious_patron(target_id):
				return _command_state(false, false, &"patron_unavailable")
			if not _patrons[target_id]["friendship_capturable"]:
				return _command_state(false, false, &"not_receptive")
			if _friendship_value(target_id, cultist_id) < FRIENDSHIP_TRUSTED_THRESHOLD:
				return _command_state(false, false, &"not_receptive")
			return _command_state(true, not _busy_for_command(cultist_id), &"cultist_busy")
		&"rescue_persuasion":
			var victim := _carrying_collapse_victim()
			if victim == ActorIds.NO_ACTOR or _collapses[victim]["helper_id"] != target_id:
				return _command_state(false, false, &"patron_unavailable")
			if _collapses[victim]["rescue_attempted"]:
				return _command_state(true, false, &"already_attempted")
			return _command_state(true, true, &"")
		&"prepare_drink":
			if carries_prepared_drink(cultist_id):
				return _command_state(true, false, &"already_carrying")
			if _open_order_patrons().is_empty():
				return _command_state(true, false, &"no_open_order")
			return _command_state(true, true, &"")
		&"prepare_drugged_drink":
			if _doses_remaining <= 0:
				return _command_state(true, false, &"no_doses")
			if not _drug_prep.is_empty():
				return _command_state(true, false, &"drug_prep_running")
			var dose_target := next_drug_target()
			if dose_target == ActorIds.NO_ACTOR:
				return _command_state(true, false, &"no_open_order")
			var state := _command_state(true, true, &"")
			state["detail"] = normal_patron_view(dose_target, cultist_id)["name"]
			return state
		&"activate_trapdoor":
			return _command_state(true, _trapdoor_state == &"closed", &"trapdoor_busy")
		&"drop_body":
			var carrying := _drag_victim_for_cultist(cultist_id) != ActorIds.NO_ACTOR
			return _command_state(carrying, carrying, &"not_carrying_body")
	return _command_state(false, false, &"unknown_command")


func serve_drink_availability(
		patron_id: int, cultist_id: int, drink_id: StringName
) -> Dictionary:
	if not _conscious_patron(patron_id):
		return _command_state(false, false, &"patron_unavailable")
	if is_cultist_busy(cultist_id):
		return _command_state(true, false, &"cultist_busy")
	var drink := _prepared_drinks.drink(drink_id)
	if drink.is_empty():
		return _command_state(false, false, &"drink_unavailable")
	var owner := int(drink["reserved_by"])
	if owner != ActorIds.NO_ACTOR and owner != cultist_id:
		return _command_state(true, false, &"drink_reserved")
	return _command_state(true, true, &"")


func _command_state(visible: bool, available: bool, reason: StringName) -> Dictionary:
	return {
		"visible": visible,
		"available": available,
		"reason": &"" if available else reason,
		"detail": "",
	}


func _conscious_patron(patron_id: int) -> bool:
	return _patrons.has(patron_id) and _patrons[patron_id]["lifecycle"] == &"active"


func _knockout_target_available(patron_id: int) -> bool:
	return (
		_patrons.has(patron_id)
		and StringName(_patrons[patron_id]["lifecycle"]) in [&"active", &"escaping", &"leaving"]
	)


# Busy for the purpose of offering a command. A running Talk does not count,
# because issuing the next command ends that Talk first.
func _busy_for_command(cultist_id: int) -> bool:
	if cultist_is_incapacitated(cultist_id):
		return true
	if not _admission.is_empty() and _admission["cultist_id"] == cultist_id:
		return true
	if not _ask_to_leave.is_empty() and _ask_to_leave["cultist_id"] == cultist_id:
		return true
	if not _windup.is_empty() and _windup["cultist_id"] == cultist_id:
		return true
	for target_id: int in _stirs:
		if _stirs[target_id]["helper_id"] == cultist_id:
			return true
	for patron_id: int in _follows:
		if _follows[patron_id]["cultist_id"] == cultist_id:
			return true
	return _drag_victim_for_cultist(cultist_id) != ActorIds.NO_ACTOR


# Patrons with an open Order, longest wait first, so bar work is deterministic.
func _open_order_patrons() -> Array[int]:
	var waiting: Array[Dictionary] = []
	for patron_id: int in _patrons:
		var order_id: StringName = _patrons[patron_id]["order_id"]
		if order_id.is_empty() or not _order_system.is_open(order_id):
			continue
		var order: Dictionary = _order_system.order_snapshot(order_id)
		waiting.append({"id": patron_id, "at": float(order["requested_at"])})
	waiting.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if is_equal_approx(left["at"], right["at"]):
			return int(left["id"]) < int(right["id"])
		return left["at"] < right["at"]
	)
	var result: Array[int] = []
	for entry: Dictionary in waiting:
		result.append(entry["id"])
	return result


func serve_patron_order(patron_id: int) -> bool:
	if not _patrons.has(patron_id):
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"active" or _activity(patron) != &"awaiting_drink":
		return false
	return _serve_patron(patron_id, patron)


func serve_prepared_drink(
		patron_id: int, cultist_id: int, drink_id: StringName
) -> Dictionary:
	var result := {
		"served": false, "accepted": false, "correct": false,
		"expression": &"frown", "reason": &"invalid_target", "roll": -1.0,
	}
	if not _conscious_patron(patron_id):
		return result
	var drink: Dictionary = _prepared_drinks.consume(drink_id, cultist_id)
	if drink.is_empty():
		result["reason"] = &"drink_unavailable"
		return result
	var patron: Dictionary = _patrons[patron_id]
	var order_id: StringName = patron["order_id"]
	var has_order := not order_id.is_empty() and _order_system.is_open(order_id)
	if not has_order:
		var offer_roll: float = _patron_rngs[patron_id].randf_range(0.0, 100.0)
		result["roll"] = offer_roll
		if offer_roll > OFFER_ACCEPTANCE_PERCENT:
			result["reason"] = &"refused"
			_record(&"drink_service_result", patron_id, result)
			_emit_snapshot()
			return result
		_start_served_drink(patron_id, patron, drink)
		result.merge({"served": true, "accepted": true, "reason": &"accepted", "expression": &"smile"}, true)
		_record(&"drink_service_result", patron_id, result)
		_emit_snapshot()
		return result

	var order: Dictionary = _order_system.order_snapshot(order_id)
	var correct := StringName(order["drink_type"]) == StringName(drink["type"])
	result["correct"] = correct
	if correct:
		var elapsed := _simulated_seconds - float(order["requested_at"])
		if elapsed <= ORDER_IMPATIENT_SECONDS:
			_satisfaction[patron_id].change(5.0, &"prompt_service")
		_order_system.serve_order(order_id, _simulated_seconds, _satisfaction[patron_id].tip_multiplier())
		_start_served_drink(patron_id, patron, drink)
		result.merge({"served": true, "accepted": true, "reason": &"correct", "expression": &"smile"}, true)
	else:
		_satisfaction[patron_id].change(WRONG_DRINK_SATISFACTION, &"wrong_drink")
		var wrong_roll: float = _patron_rngs[patron_id].randf_range(0.0, 100.0)
		result["roll"] = wrong_roll
		if wrong_roll <= WRONG_DRINK_ACCEPTANCE_PERCENT:
			_order_system.serve_order(
				order_id, _simulated_seconds, _satisfaction[patron_id].tip_multiplier() * 0.5
			)
			_start_served_drink(patron_id, patron, drink)
			result.merge({"served": true, "accepted": true, "reason": &"wrong_accepted"}, true)
		else:
			result["reason"] = &"wrong_refused"
	_record(&"drink_service_result", patron_id, result)
	_emit_snapshot()
	return result


func _start_served_drink(patron_id: int, patron: Dictionary, drink: Dictionary) -> void:
	_set_activity(patron, &"drinking", &"drink")
	if bool(drink["drugged"]):
		patron["drug_countdown"] = 0.0
		patron["drug_drowsy_reported"] = false
		_record(&"drugged_drink_sipped", patron_id)
	_patrons[patron_id] = patron


func offer_drink(patron_id: int, cultist_id: int, drugged: bool = false) -> Dictionary:
	var result := {"accepted": false, "reason": &"invalid_target", "roll": -1.0}
	if not _patrons.has(patron_id) or cultist_id == ActorIds.NO_ACTOR:
		return result
	var patron: Dictionary = _patrons[patron_id]
	if (
		patron["lifecycle"] != &"active"
		or _order_system.is_open(patron["order_id"])
		or _activity(patron) != &"socializing"
	):
		return result
	if _simulated_seconds < float(patron["offer_refused_until"]):
		result["reason"] = &"refusal_cooldown"
		return result
	var roll: float = _patron_rngs[patron_id].randf_range(0.0, 100.0)
	result["roll"] = roll
	if roll > OFFER_ACCEPTANCE_PERCENT:
		patron["offer_refused_until"] = _simulated_seconds + OFFER_REFUSAL_COOLDOWN_SECONDS
		_patrons[patron_id] = patron
		result["reason"] = &"refused"
		_record(&"offered_drink_refused", patron_id, {"cultist_id": cultist_id, "roll": roll})
		return result
	if bool(_carried_drinks.get(cultist_id, false)):
		_carried_drinks[cultist_id] = false
	_set_activity(patron, &"drinking", &"drink")
	if drugged:
		patron["drug_countdown"] = 0.0
		patron["drug_drowsy_reported"] = false
	_patrons[patron_id] = patron
	result["accepted"] = true
	result["reason"] = &"accepted"
	_record(&"offered_drink_accepted", patron_id, {
		"cultist_id": cultist_id, "roll": roll, "drugged": drugged,
	})
	return result


func debug_set_patron_drink_state(
	patron_id: int,
	intoxication: int,
	overdrink_limit: int,
	excess_drinks: int = 0,
	ideal_intoxication: int = -1
) -> bool:
	if not _patrons.has(patron_id):
		return false
	_patrons[patron_id]["intoxication"] = clampi(intoxication, 0, 3)
	_patrons[patron_id]["overdrink_limit"] = clampi(overdrink_limit, 1, 5)
	_patrons[patron_id]["excess_drinks"] = maxi(0, excess_drinks)
	if ideal_intoxication >= 0:
		_patrons[patron_id]["ideal_intoxication"] = clampi(ideal_intoxication, 0, 3)
	var order_id: StringName = _patrons[patron_id]["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"debug_setup")
	var patron: Dictionary = _patrons[patron_id]
	_set_activity(patron, &"socializing", &"seat")
	_patrons[patron_id] = patron
	return true


func debug_change_patron_satisfaction(patron_id: int, amount: float) -> bool:
	if not _satisfaction.has(patron_id):
		return false
	_satisfaction[patron_id].change(amount, &"debug_setup")
	return true


func debug_force_finish_drink(patron_id: int) -> bool:
	if not _patrons.has(patron_id):
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"active":
		return false
	_finish_drink(patron_id, patron)
	return true


func _serve_patron(patron_id: int, patron: Dictionary) -> bool:
	var order: Dictionary = _order_system.order_snapshot(patron["order_id"])
	if order.is_empty() or not _order_system.is_open(patron["order_id"]):
		return false
	var elapsed := _simulated_seconds - float(order["requested_at"])
	if elapsed <= ORDER_IMPATIENT_SECONDS:
		_satisfaction[patron_id].change(5.0, &"prompt_service")
	if not _order_system.serve_order(
		patron["order_id"], _simulated_seconds, _satisfaction[patron_id].tip_multiplier()
	):
		return false
	_set_activity(patron, &"drinking", &"drink")
	# First sip: a prepared dose starts this consumer's countdown.
	if patron["dosed_pending"]:
		patron["dosed_pending"] = false
		patron["drug_countdown"] = 0.0
		patron["drug_drowsy_reported"] = false
		_record(&"drugged_drink_sipped", patron_id)
	_record(&"order_served", patron_id, {"order_id": patron["order_id"]})
	_patrons[patron_id] = patron
	return true


func _finish_drink(patron_id: int, patron: Dictionary) -> void:
	var was_max_drunk := int(patron["intoxication"]) >= 3
	patron["bladder"] = minf(100.0, float(patron["bladder"]) + float(patron["bladder_gain"]))
	patron["intoxication"] = mini(3, int(patron["intoxication"]) + 1)
	patron["intoxication_decay_in"] = INTOXICATION_DECAY_SECONDS
	if was_max_drunk:
		patron["excess_drinks"] = int(patron["excess_drinks"]) + 1
		_record(&"excess_drink_finished", patron_id, {
			"count": patron["excess_drinks"], "limit": patron["overdrink_limit"],
		})
		if int(patron["excess_drinks"]) >= int(patron["overdrink_limit"]):
			_patrons[patron_id] = patron
			_collapse_patron(patron_id, &"overdrink", false)
			return
	patron["social_interval"] = _patron_rngs[patron_id].randf_range(
		SOCIAL_MIN_SECONDS, SOCIAL_MAX_SECONDS
	)
	_complete_activity(patron, &"socializing", &"seat")
	if patron["bladder"] >= 50.0:
		patron["bathroom_checks_active"] = true
		patron["next_bathroom_check_at"] = _simulated_seconds + BATHROOM_CHECK_SECONDS
	_record(&"drink_completed", patron_id, {"bladder": patron["bladder"], "intoxication": patron["intoxication"]})


func _advance_bathroom_checks(patron_id: int, patron: Dictionary) -> void:
	if not patron["bathroom_checks_active"]:
		return
	while _simulated_seconds + 0.0001 >= float(patron["next_bathroom_check_at"]):
		var probability := bathroom_probability(float(patron["bladder"]))
		var roll := _rng.randf_range(0.0, 100.0)
		var roll_event := {"at": patron["next_bathroom_check_at"], "roll": roll, "probability": probability}
		patron["recent_bathroom_rolls"].append(roll_event)
		_record(&"bathroom_check", patron_id, roll_event)
		patron["next_bathroom_check_at"] = float(patron["next_bathroom_check_at"]) + BATHROOM_CHECK_SECONDS
		if roll <= probability:
			if not _trapdoor_locked() and _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
				patron["bathroom_checks_active"] = false
				_begin_bathroom_visit(patron_id, patron)
				_start_missing_companion_clock(patron_id)
				_record(&"bathroom_chosen", patron_id, {"roll": roll, "probability": probability})
				return
			if _interaction_registry.request_slot(patron_id, BATHROOM_LINE_SLOT):
				patron["bathroom_checks_active"] = false
				_set_activity(patron, &"bathroom_queued", &"bathroom_line")
				_record(&"bathroom_line_joined", patron_id, {"roll": roll, "probability": probability})
				return


# --- Danger chain (Trapdoor, missing Companion, Investigation, Escape, Intercept) ---
# Ported from the isolated BathroomDangerScenario spike and adapted to the live Night's
# bathroom vocabulary. The Trapdoor, Investigation and Escape act on the single authoritative
# Patron model; maximum-Suspicion behaviour is driven by PatronSuspicion.maximum_response.


# One pulse. Activation snapshots the current occupant and resolves eligibility
# from that snapshot; it never arms a later Patron. A standing occupant begins a
# finite fall; a seated occupant is a protected misfire; an empty room just opens.
func activate_trapdoor() -> bool:
	if _trapdoor_state != &"closed":
		return false
	var occupant := _bathroom_occupant()
	_trapdoor_eligible_occupant = occupant
	_record(&"trapdoor_opened", occupant)
	if occupant != ActorIds.NO_ACTOR and _is_standing_bathroom_activity(_activity(_patrons[occupant])):
		_begin_trapdoor_fall(occupant)
	else:
		_trapdoor_state = &"open"
		_trapdoor_remaining = TRAPDOOR_OPEN_SECONDS
		if occupant != ActorIds.NO_ACTOR and _activity(_patrons[occupant]) == &"seated_bathroom_use":
			_apply_seated_hard_evidence(occupant)
	_emit_snapshot()
	return true


# A standing snapped occupant enters the finite capture: the door holds them in
# `trapdoor_falling`, the bathroom stays reserved, and only closure makes it terminal.
func _begin_trapdoor_fall(occupant: int) -> void:
	_trapdoor_state = &"falling"
	_trapdoor_remaining = TRAPDOOR_FALL_SECONDS
	_trapdoor_fall_ratio = 0.0
	_trapdoor_falling_patron = occupant
	var patron: Dictionary = _patrons[occupant]
	patron["lifecycle"] = &"capturing"
	patron["bathroom_checks_active"] = false
	_set_activity(patron, &"trapdoor_falling", &"trapdoor")
	_patrons[occupant] = patron
	_record(&"trapdoor_capture_started", occupant)


func _trapdoor_locked() -> bool:
	return _trapdoor_state in [&"open", &"falling", &"closing"]


func _bathroom_available_for_entry() -> bool:
	return _bathroom_occupant() == ActorIds.NO_ACTOR and not _trapdoor_locked()


func _trapdoor_close_ratio() -> float:
	if _trapdoor_state != &"closing":
		return 0.0
	return clampf(1.0 - _trapdoor_remaining / TRAPDOOR_CLOSE_SECONDS, 0.0, 1.0)


func begin_intercept(patron_id: int, cultist_id: int) -> bool:
	if not _patrons.has(patron_id) or cultist_id == ActorIds.NO_ACTOR or not _active_intercept.is_empty():
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"escaping" or _activity(patron) != &"escaping":
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
	_interceptions += 1
	_record(&"intercept_started", patron_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func cancel_intercept() -> bool:
	if _active_intercept.is_empty():
		return false
	var patron_id: int = _active_intercept["patron_id"]
	var cultist_id: int = _active_intercept["cultist_id"]
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
	for patron_id: int in _patrons:
		if _patrons[patron_id]["lifecycle"] == &"escaping":
			return true
	return false


func has_defeat() -> bool:
	return _defeat


# Debug-only seam: place an arrived Patron in the bathroom deterministically instead of
# waiting on seeded bladder rolls. Used by tests and the capture-chain validation slice.
func debug_force_bathroom(patron_id: int) -> bool:
	if not _patrons.has(patron_id):
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"active":
		return false
	_interaction_registry.release_actor(patron_id)
	patron["bathroom_checks_active"] = false
	if _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
		_begin_bathroom_visit(patron_id, patron)
		_start_missing_companion_clock(patron_id)
	elif _interaction_registry.request_slot(patron_id, BATHROOM_LINE_SLOT):
		_set_activity(patron, &"bathroom_queued", &"bathroom_line")
	else:
		return false
	_patrons[patron_id] = patron
	_record(&"debug_bathroom_forced", patron_id)
	_emit_snapshot()
	return true


# Finite state machine: open|falling -> closing -> cooldown -> closed. Eligibility
# was resolved at activation, so this only advances timers and finalizes the capture
# after the panels finish closing.
func _advance_trapdoor(step: float) -> void:
	if _trapdoor_state == &"closed":
		return
	_trapdoor_remaining = maxf(0.0, _trapdoor_remaining - step)
	if _trapdoor_state == &"falling":
		_trapdoor_fall_ratio = clampf(
			1.0 - _trapdoor_remaining / TRAPDOOR_FALL_SECONDS, 0.0, 1.0
		)
	if _trapdoor_remaining > TIME_EPSILON:
		return
	match _trapdoor_state:
		&"open", &"falling":
			_trapdoor_state = &"closing"
			_trapdoor_remaining = TRAPDOOR_CLOSE_SECONDS
			_record(&"trapdoor_closing", &"trapdoor")
		&"closing":
			# The panels have finished closing: remove the falling Patron now, not before.
			if _trapdoor_falling_patron != ActorIds.NO_ACTOR:
				_finalize_trapdoor_capture()
			_trapdoor_state = &"cooldown"
			_trapdoor_remaining = TRAPDOOR_COOLDOWN_SECONDS
			_trapdoor_eligible_occupant = ActorIds.NO_ACTOR
			_record(&"trapdoor_cooldown", &"trapdoor")
		&"cooldown":
			_trapdoor_state = &"closed"
			_trapdoor_remaining = 0.0
			_trapdoor_fall_ratio = 0.0
			_record(&"trapdoor_ready", &"trapdoor")


func _advance_missing_companions(step: float) -> void:
	for patron_id: int in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if int(patron["missing_target"]) == ActorIds.NO_ACTOR or patron["missing_40_applied"]:
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
	for patron_id: int in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"investigating":
			continue
		if _activity(patron) == &"waiting_investigation":
			if _bathroom_available_for_entry() and _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
				_set_activity(patron, &"investigation_search", &"bathroom")
				_patrons[patron_id] = patron
				_record(&"investigation_started", patron_id)
			continue
		if _activity(patron) != &"investigation_search":
			continue
		if _physical_navigation_enabled and not _behavior_arrived(patron):
			continue
		if _behavior_elapsed(patron) >= INVESTIGATION_SECONDS:
			_interaction_registry.release_actor(patron_id)
			_record(&"trapdoor_discovered", patron_id)
			_begin_escape(patron_id)


func _advance_escape(step: float) -> void:
	if not _active_intercept.is_empty():
		_active_intercept["remaining"] = maxf(0.0, float(_active_intercept["remaining"]) - step)
		if _active_intercept["remaining"] <= TIME_EPSILON:
			var intercepted_id: int = _active_intercept["patron_id"]
			var cultist_id: int = _active_intercept["cultist_id"]
			_interaction_registry.release_actor(cultist_id)
			_active_intercept.clear()
			if _patrons.has(intercepted_id) and _patrons[intercepted_id]["lifecycle"] == &"escaping":
				var resumed: Dictionary = _patrons[intercepted_id]
				_set_activity(resumed, &"escaping", &"front_exit")
				_patrons[intercepted_id] = resumed
			_record(&"intercept_completed", intercepted_id)
		return
	for patron_id: int in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if not _windup.is_empty() and _windup["victim_id"] == patron_id:
			continue
		if patron["lifecycle"] != &"escaping":
			continue
		if _activity(patron) == &"shock":
			if _behavior_elapsed(patron) >= ESCAPE_SHOCK_SECONDS:
				_set_activity(patron, &"escaping", &"front_exit")
				_record(&"escape_started", patron_id)
			_patrons[patron_id] = patron
			continue
		if _activity(patron) != &"escaping":
			continue
		if _physical_navigation_enabled:
			if not _behavior_arrived(patron):
				continue
			patron["escape_remaining"] = 0.0
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
	for patron_id: int in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"active":
			continue
		if _activity(patron) in DISPATCH_EXCLUDED_ACTIVITIES:
			continue
		var state: Dictionary = _suspicion_states[patron_id].snapshot()
		if float(state["score"]) < 100.0:
			continue
		match state["maximum_response"]:
			&"investigation":
				_request_investigation(patron_id)
			&"escape":
				_begin_escape(patron_id)


func _request_investigation(patron_id: int) -> void:
	var patron: Dictionary = _patrons[patron_id]
	patron["lifecycle"] = &"investigating"
	patron["bathroom_checks_active"] = false
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
		patron["seat"] = &""
	if _bathroom_available_for_entry() and _interaction_registry.request_slot(patron_id, BATHROOM_SLOT):
		_set_activity(patron, &"investigation_search", &"bathroom")
		_record(&"investigation_started", patron_id)
	else:
		_set_activity(patron, &"waiting_investigation", &"bathroom")
		_record(&"investigation_waiting", patron_id)
	_patrons[patron_id] = patron


func _begin_escape(patron_id: int) -> void:
	var patron: Dictionary = _patrons[patron_id]
	_interaction_registry.release_actor(patron_id)
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
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
	if captured_id == ActorIds.NO_ACTOR or not _patrons.has(captured_id):
		return
	var patron: Dictionary = _patrons[captured_id]
	_interaction_registry.release_actor(captured_id)
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
		patron["seat"] = &""
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"captured")
	patron["lifecycle"] = &"captured"
	patron["missing_target"] = ActorIds.NO_ACTOR
	patron["bathroom_checks_active"] = false
	_set_activity(patron, &"captured", &"tunnel")
	_patrons[captured_id] = patron
	_captures.append({"id": captured_id, "cause": cause, "at": _simulated_seconds})
	_record(&"capture", captured_id, {"cause": cause})


# Runs only after the Trapdoor panels finish closing: the falling Patron becomes
# terminal and the bathroom slot releases now, never before the panels are shut.
func _finalize_trapdoor_capture() -> void:
	_capture_occupant(&"trapdoor")
	_trapdoor_falling_patron = ActorIds.NO_ACTOR


func _apply_seated_hard_evidence(patron_id: int) -> void:
	var patron: Dictionary = _patrons[patron_id]
	var observer_is_max_drunk := int(patron["intoxication"]) >= 3
	_suspicion_states[patron_id].apply_stimulus(&"trapdoor_open_seen_seated", observer_is_max_drunk)
	if not observer_is_max_drunk:
		patron["escape_after_bathroom"] = true
		_patrons[patron_id] = patron
	_record(&"trapdoor_seated_evidence", patron_id, {"max_drunk": observer_is_max_drunk})


# Opens a Bathroom Visit: samples the one seeded Seated Bathroom Use duration for
# this visit and starts the standing walk from the door to the mirror. The seeded
# whole-number duration is drawn once here, never re-rolled mid-visit.
func _begin_bathroom_visit(patron_id: int, patron: Dictionary) -> void:
	patron["bathroom_use_seconds"] = float(_patron_rngs[patron_id].randi_range(
		BATHROOM_USE_MIN_SECONDS, BATHROOM_USE_MAX_SECONDS
	))
	_set_activity(patron, &"entering_bathroom", &"mirror")


func _start_missing_companion_clock(entered_id: int) -> void:
	if not _patrons.has(entered_id):
		return
	for companion_id: int in _patrons[entered_id]["companions"]:
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


func _clear_missing_companion_clock(returned_id: int) -> void:
	for patron_id: int in _patrons:
		if _patrons[patron_id]["missing_target"] != returned_id:
			continue
		var patron: Dictionary = _patrons[patron_id]
		patron["missing_target"] = ActorIds.NO_ACTOR
		patron["missing_seconds"] = 0.0
		_patrons[patron_id] = patron
		_record(&"companion_returned", patron_id, {"target_id": returned_id})


func _bathroom_occupant() -> int:
	return _interaction_registry.slot_owner(BATHROOM_SLOT)


func _is_standing_bathroom_activity(activity: StringName) -> bool:
	return activity in STANDING_BATHROOM_ACTIVITIES


# --- Drugged Drink, collapse, Helper, and Rescue Persuasion (Ticket #12) ---
# The dose attaches to the target's open Order; the consumer-owned countdown starts at the
# first sip. On collapse the least-intoxicated conscious Companion carries the victim toward
# the front, where one Rescue Persuasion may capture both at the Tunnel Intake.


func prepare_drugged_drink(patron_id: int, cultist_id: int) -> bool:
	if _doses_remaining <= 0 or not _drug_prep.is_empty() or cultist_id == ActorIds.NO_ACTOR:
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


func attempt_rescue_persuasion(cultist_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR:
		return false
	var victim_id := _carrying_collapse_victim()
	if victim_id == ActorIds.NO_ACTOR:
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


func rescue_persuasion_chance(cultist_id: int) -> float:
	var victim_id := _active_collapse_with_helper()
	if victim_id == ActorIds.NO_ACTOR or cultist_id == ActorIds.NO_ACTOR:
		return 0.0
	var helper_id: int = _collapses[victim_id]["helper_id"]
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
	var patron_id: int = _drug_prep["patron_id"]
	_doses_remaining -= 1
	if _patrons.has(patron_id) and _order_system.is_open(_patrons[patron_id]["order_id"]):
		_patrons[patron_id]["dosed_pending"] = true
	_record(&"drugged_drink_ready", patron_id, {"doses_remaining": _doses_remaining})
	_drug_prep.clear()


func _advance_drug(step: float) -> void:
	for patron_id: int in _patrons:
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
	for victim_id: int in _collapses.keys():
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
					_patron_actions[victim_id].submit(
						_activity(_patrons[victim_id]), &"front_exit",
						_interaction_registry.actor_slot(victim_id), _physical_navigation_enabled
					)
					_record(&"helper_carrying", collapse["helper_id"], {"victim_id": victim_id})
			&"carrying":
				var helper_id: int = collapse["helper_id"]
				if _physical_navigation_enabled and not _behavior_arrived(_patrons[helper_id]):
					continue
				collapse["remaining"] = 0.0 if _physical_navigation_enabled else float(collapse["remaining"]) - step
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


func _collapse_patron(
	patron_id: int,
	cause: StringName = &"drugged_drink",
	apply_drink_effect: bool = true
) -> void:
	var patron: Dictionary = _patrons[patron_id]
	var collapse_room := _patron_room(patron)
	var collapse_position := _patron_position(patron)
	# The drink still raises Bladder and Intoxication before the Patron goes under.
	if apply_drink_effect:
		patron["bladder"] = minf(100.0, float(patron["bladder"]) + float(patron["bladder_gain"]))
		patron["intoxication"] = mini(3, int(patron["intoxication"]) + 1)
		patron["intoxication_decay_in"] = INTOXICATION_DECAY_SECONDS
	patron["drug_countdown"] = DRUG_COLLAPSE_SECONDS if cause == &"drugged_drink" else -1.0
	patron["collapse_cause"] = cause
	patron["body_room"] = collapse_room
	patron["body_position"] = collapse_position
	patron["bathroom_checks_active"] = false
	patron["lifecycle"] = &"unconscious"
	_set_activity(patron, &"unconscious", &"collapsed")
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
		patron["seat"] = &""
	_interaction_registry.release_actor(patron_id)
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"collapsed")
	_patrons[patron_id] = patron
	_collapses[patron_id] = {
		"victim_id": patron_id,
		"helper_id": ActorIds.NO_ACTOR,
		"phase": &"reacting",
		"remaining": HELPER_REACTION_SECONDS,
		"carry_remaining": HELPER_CARRY_SECONDS,
		"acting_cultist": ActorIds.NO_ACTOR,
		"rescue_attempted": false,
		"last_chance": 0.0,
		"last_roll": -1.0,
		"last_success": false,
		"cause": cause,
		"room": collapse_room,
		"overdrink_noticed": {},
	}
	_apply_collapse_satisfaction_reactions(patron_id, collapse_room, cause)
	_record(&"overdrink_collapse" if cause == &"overdrink" else &"drugged_drink_collapse", patron_id)


func _apply_collapse_satisfaction_reactions(
	victim_id: int,
	room: StringName,
	cause: StringName
) -> void:
	var collapse: Dictionary = _collapses[victim_id]
	for patron_id: int in _patrons:
		if patron_id == victim_id or _patrons[patron_id]["lifecycle"] != &"active":
			continue
		if _patron_room(_patrons[patron_id]) != room:
			continue
		if cause == &"overdrink":
			_satisfaction[patron_id].change(-15.0, &"overdrink_body")
			collapse["overdrink_noticed"][patron_id] = true
			_record(&"satisfaction_changed", patron_id, {
				"cause": &"overdrink_body", "amount": -15.0, "value": _satisfaction[patron_id].value(),
			})
		var companion_roll: float = _patron_rngs[patron_id].randf_range(0.0, 100.0)
		if patron_id in _patrons[victim_id]["companions"] and companion_roll <= 50.0:
			_satisfaction[patron_id].change(-20.0, &"companion_collapse")
			_record(&"companion_collapse_satisfaction", patron_id, {
				"victim_id": victim_id, "value": _satisfaction[patron_id].value(),
			})
		if _satisfaction[patron_id].value() <= 0.0:
			_depart_patron(patron_id, _patrons[patron_id], &"satisfaction_zero")
	_collapses[victim_id] = collapse


func _apply_overdrink_body_satisfaction(patron_id: int, patron: Dictionary) -> void:
	for victim_id: int in _collapses:
		var collapse: Dictionary = _collapses[victim_id]
		if collapse.get("cause", &"") != &"overdrink":
			continue
		if collapse["overdrink_noticed"].has(patron_id):
			continue
		if _patron_room(patron) != StringName(collapse["room"]):
			continue
		_satisfaction[patron_id].change(-15.0, &"overdrink_body")
		collapse["overdrink_noticed"][patron_id] = true
		_collapses[victim_id] = collapse
		_record(&"satisfaction_changed", patron_id, {
			"cause": &"overdrink_body", "amount": -15.0, "value": _satisfaction[patron_id].value(),
		})
		if _satisfaction[patron_id].value() <= 0.0:
			_depart_patron(patron_id, patron, &"satisfaction_zero")


func _assign_helper(victim_id: int, collapse: Dictionary) -> void:
	var helper_id := _select_helper(victim_id)
	if helper_id == ActorIds.NO_ACTOR:
		collapse["phase"] = &"unattended"
		_collapses[victim_id] = collapse
		_record(&"collapse_unattended", victim_id)
		return
	var helper: Dictionary = _patrons[helper_id]
	helper["bathroom_checks_active"] = false
	if not StringName(helper["seat"]).is_empty():
		_seat_owners[helper["seat"]] = ActorIds.NO_ACTOR
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


func _select_helper(victim_id: int) -> int:
	var best_id: int = ActorIds.NO_ACTOR
	var best_intoxication := 4
	var best_index := 999
	for companion_id: int in _patrons[victim_id]["companions"]:
		if not _patrons.has(companion_id) or _patrons[companion_id]["lifecycle"] != &"active":
			continue
		if _satisfaction[companion_id].band() == "Miserable":
			continue
		if _patron_room(_patrons[companion_id]) != StringName(_collapses[victim_id].get("room", &"main_hall")):
			continue
		var intoxication := int(_patrons[companion_id]["intoxication"])
		var index := _definition_index(companion_id)
		if intoxication < best_intoxication or (intoxication == best_intoxication and index < best_index):
			best_id = companion_id
			best_intoxication = intoxication
			best_index = index
	return best_id


func _definition_index(patron_id: int) -> int:
	for index in range(FULL_NIGHT_PATRON_DEFINITIONS.size()):
		if FULL_NIGHT_PATRON_DEFINITIONS[index]["id"] == patron_id:
			return index
	return 999


func _helper_reaches_front(victim_id: int) -> void:
	var collapse: Dictionary = _collapses[victim_id]
	var helper_id: int = collapse["helper_id"]
	# Both Patrons leave. It is defeat only if the Helper is at maximum Suspicion.
	if _patrons.has(helper_id) and _suspicion_states[helper_id].snapshot()["score"] >= 100.0:
		_defeat = true
		_record(&"defeat", helper_id, {"reason": &"helper_max_suspicion_at_front"})
	for patron_id: int in [victim_id, helper_id]:
		if not _patrons.has(patron_id):
			continue
		var patron: Dictionary = _patrons[patron_id]
		_interaction_registry.release_actor(patron_id)
		patron["lifecycle"] = &"exited"
		patron["helper_id"] = ActorIds.NO_ACTOR
		patron["helping_victim"] = ActorIds.NO_ACTOR
		_set_activity(patron, &"normal_departure", &"front_exit")
		_patrons[patron_id] = patron
	_collapses.erase(victim_id)
	_record(&"helper_reached_front", helper_id, {"victim_id": victim_id})


func _resolve_rescue(victim_id: int) -> void:
	var collapse: Dictionary = _collapses[victim_id]
	var helper_id: int = collapse["helper_id"]
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


func _capture_pair(victim_id: int, helper_id: int, cause: StringName) -> void:
	for patron_id: int in [victim_id, helper_id]:
		if not _patrons.has(patron_id):
			continue
		var patron: Dictionary = _patrons[patron_id]
		_interaction_registry.release_actor(patron_id)
		if not StringName(patron["seat"]).is_empty():
			_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
			patron["seat"] = &""
		patron["lifecycle"] = &"captured"
		patron["helper_id"] = ActorIds.NO_ACTOR
		patron["helping_victim"] = ActorIds.NO_ACTOR
		_set_activity(patron, &"captured", &"tunnel")
		_patrons[patron_id] = patron
		_captures.append({"id": patron_id, "cause": cause, "at": _simulated_seconds})
		_record(&"capture", patron_id, {"cause": cause})
	_collapses.erase(victim_id)


func _set_helper_activity(helper_id: int, activity: StringName) -> void:
	if not _patrons.has(helper_id):
		return
	var helper: Dictionary = _patrons[helper_id]
	_set_activity(helper, activity, &"front")
	_patrons[helper_id] = helper


func _carrying_collapse_victim() -> int:
	for victim_id: int in _collapses:
		if _collapses[victim_id]["phase"] == &"carrying" and int(_collapses[victim_id]["helper_id"]) != ActorIds.NO_ACTOR:
			return victim_id
	return ActorIds.NO_ACTOR


func _active_collapse_with_helper() -> int:
	for victim_id: int in _collapses:
		var phase: StringName = _collapses[victim_id]["phase"]
		if phase in [&"carrying", &"persuading"] and int(_collapses[victim_id]["helper_id"]) != ActorIds.NO_ACTOR:
			return victim_id
	return ActorIds.NO_ACTOR


# --- Manual knockout and dragging (GDD §10.3) --------------------------------

# Begins the 2-second interruptible wind-up. Valid against an active Patron when
# the acting Cultist is free and no other wind-up is in progress.
func begin_knockout(cultist_id: int, victim_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _patrons.has(victim_id):
		return false
	if not _knockout_target_available(victim_id):
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


func knockout_chance(victim_id: int) -> float:
	if not _patrons.has(victim_id):
		return 0.0
	return KNOCKOUT_CHANCES[clampi(int(_patrons[victim_id]["intoxication"]), 0, 3)]


func cultist_is_incapacitated(cultist_id: int) -> bool:
	return _incapacitated_cultists.has(cultist_id)


func cultist_incapacitated_remaining(cultist_id: int) -> float:
	return float(_incapacitated_cultists.get(cultist_id, 0.0))


func begin_stir(helper_id: int, target_id: int) -> bool:
	if helper_id == target_id or helper_id not in CULTIST_IDS or target_id not in CULTIST_IDS:
		return false
	if not cultist_is_incapacitated(target_id) or _stirs.has(target_id) or _busy_for_command(helper_id):
		return false
	_stirs[target_id] = {"helper_id": helper_id, "remaining": STIR_SECONDS}
	_record(&"stir_started", target_id, {"cultist_id": helper_id})
	_emit_snapshot()
	return true


func cancel_stir(helper_id: int) -> bool:
	for target_id: int in _stirs:
		if _stirs[target_id]["helper_id"] == helper_id:
			_stirs.erase(target_id)
			_record(&"stir_cancelled", target_id, {"cultist_id": helper_id})
			_emit_snapshot()
			return true
	return false


# Interrupts the wind-up before impact. The Commitment Point has not passed, so
# the victim is unharmed. Only the Cultist who started the wind-up can cancel it.
func cancel_knockout(cultist_id: int) -> bool:
	if _windup.is_empty() or _windup["cultist_id"] != cultist_id:
		return false
	var victim_id: int = _windup["victim_id"]
	_windup.clear()
	_record(&"knockout_windup_cancelled", victim_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func command_action_state(
		command: StringName, cultist_id: int, target_id: Variant
) -> StringName:
	match command:
		&"admit_group":
			if _admission.is_empty() or _admission["cultist_id"] != cultist_id:
				return &"failed"
			if _admission["phase"] == &"holding" and _admission_complete():
				_admission.clear()
				return &"completed"
			return &"committed" if _admission["phase"] == &"holding" else &"executing"
		&"ask_to_leave":
			if _ask_to_leave.is_empty() or _ask_to_leave["cultist_id"] != cultist_id or _ask_to_leave["patron_id"] != target_id:
				return &"failed"
			var leave_state: StringName = _ask_to_leave["state"]
			if leave_state in [&"completed", &"failed"]:
				_ask_to_leave.clear()
			return leave_state
		&"knock_out":
			if (
				not _windup.is_empty()
				and _windup["cultist_id"] == cultist_id
				and _windup["victim_id"] == target_id
			):
				return &"executing"
			if (
				_patrons.has(target_id)
				and _patrons[target_id]["lifecycle"] == &"unconscious"
				and _patrons[target_id]["collapse_cause"] == &"knockout"
			):
				return &"completed"
			var outcome_key := "%s:%s" % [cultist_id, target_id]
			if _knockout_outcomes.get(outcome_key, &"") == &"failed":
				_knockout_outcomes.erase(outcome_key)
				return &"failed"
		&"stir":
			if _stirs.has(target_id) and _stirs[target_id]["helper_id"] == cultist_id:
				return &"executing"
			if not cultist_is_incapacitated(target_id):
				return &"completed"
		&"prepare_drugged_drink":
			if (
				not _drug_prep.is_empty()
				and _drug_prep["cultist_id"] == cultist_id
			):
				return &"executing"
			for patron_id: int in _patrons:
				if bool(_patrons[patron_id]["dosed_pending"]):
					return &"completed"
		&"pick_up_body":
			if _drags.has(target_id) and _drags[target_id]["cultist_id"] == cultist_id:
				return &"executing" if _drags[target_id]["phase"] == &"pickup" else &"completed"
		&"intercept":
			if (
				not _active_intercept.is_empty()
				and _active_intercept["cultist_id"] == cultist_id
				and _active_intercept["patron_id"] == target_id
			):
				return &"executing"
			if _patrons.has(target_id) and bool(_patrons[target_id]["intercept_attempted"]):
				return &"completed"
		&"lead_to_tunnel":
			if _follows.has(target_id) and _follows[target_id]["cultist_id"] == cultist_id:
				return &"executing"
			if _patrons.has(target_id) and _patrons[target_id]["lifecycle"] == &"captured":
				return &"completed"
		&"rescue_persuasion":
			for victim_id: int in _collapses:
				var collapse: Dictionary = _collapses[victim_id]
				if collapse["helper_id"] != target_id or collapse["acting_cultist"] != cultist_id:
					continue
				return &"executing" if collapse["phase"] == &"persuading" else &"completed"
			if _patrons.has(target_id) and _patrons[target_id]["lifecycle"] == &"captured":
				return &"completed"
	return &"failed"


# Starts the 1-second pickup of an Unconscious, unattended body. Pickup pauses the
# Unattended Body pressure and occupies the Cultist through the drag that follows.
func pick_up_body(cultist_id: int, victim_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _patrons.has(victim_id):
		return false
	if _patrons[victim_id]["lifecycle"] != &"unconscious" or _drags.has(victim_id):
		return false
	if is_cultist_busy(cultist_id):
		return false
	if _collapses.has(victim_id):
		var collapse: Dictionary = _collapses[victim_id]
		if collapse["phase"] not in [&"reacting", &"unattended"]:
			return false
		collapse["phase"] = &"cultist_dragged"
		collapse["remaining"] = 0.0
		collapse["helper_id"] = ActorIds.NO_ACTOR
		_collapses[victim_id] = collapse
	_perception.set_body_state(victim_id, &"held")
	_drags[victim_id] = {
		"victim_id": victim_id,
		"cultist_id": cultist_id,
		"phase": &"pickup",
		"remaining": BODY_PICKUP_SECONDS,
		"movement_scale": DRAG_MOVEMENT_SCALE,
		"witness_elapsed": 0.0,
		"source_room": _patrons[victim_id].get("body_room", &"main_hall"),
		"source_position": _patrons[victim_id].get("body_position", BAR_POSITION),
		# Preserve the causal collapse route so a dragged body reports its true
		# method (Drugged Drink, Overdrink, or Knockout) at the Tunnel Intake.
		"capture_cause": _patrons[victim_id].get("collapse_cause", &"knockout"),
	}
	_record(&"body_pickup_started", victim_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


# Drops the body the Cultist is holding or dragging. Dragging can always be
# interrupted this way; dropping restarts the victim's Unattended Body grace.
func drop_body(cultist_id: int) -> bool:
	var victim_id := _drag_victim_for_cultist(cultist_id)
	if victim_id == ActorIds.NO_ACTOR:
		return false
	_drags.erase(victim_id)
	var patron: Dictionary = _patrons[victim_id]
	_set_activity(patron, &"unconscious", &"collapsed")
	# A fresh grace period: the abandoned body is Unattended again.
	patron["body_room"] = _patron_room(patron)
	patron["body_position"] = _patron_position(patron)
	if _collapses.has(victim_id):
		var collapse: Dictionary = _collapses[victim_id]
		collapse["phase"] = &"unattended"
		collapse["room"] = patron["body_room"]
		_collapses[victim_id] = collapse
	if patron.get("collapse_cause", &"") != &"overdrink":
		_perception.drop_body(victim_id, patron["body_room"], patron["body_position"])
	_patrons[victim_id] = patron
	_record(&"body_dropped", victim_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func is_cultist_busy(cultist_id: int) -> bool:
	if cultist_is_incapacitated(cultist_id):
		return true
	if not _windup.is_empty() and _windup["cultist_id"] == cultist_id:
		return true
	if _conversations.has(cultist_id):
		return true
	for target_id: int in _stirs:
		if _stirs[target_id]["helper_id"] == cultist_id:
			return true
	for patron_id: int in _follows:
		if _follows[patron_id]["cultist_id"] == cultist_id:
			return true
	return _drag_victim_for_cultist(cultist_id) != ActorIds.NO_ACTOR


func _drag_victim_for_cultist(cultist_id: int) -> int:
	for victim_id: int in _drags:
		if _drags[victim_id]["cultist_id"] == cultist_id:
			return victim_id
	return ActorIds.NO_ACTOR


func _advance_windup(step: float) -> void:
	if _windup.is_empty():
		return
	var victim_id: int = _windup["victim_id"]
	# A victim who left or fell before impact aborts the wind-up harmlessly.
	if not _knockout_target_available(victim_id):
		_windup.clear()
		return
	_windup["remaining"] = float(_windup["remaining"]) - step
	if float(_windup["remaining"]) > TIME_EPSILON:
		return
	var cultist_id: int = _windup["cultist_id"]
	_windup.clear()
	_knockout_patron(victim_id, cultist_id)


func _advance_incapacitated_cultists(step: float) -> void:
	for cultist_id: int in _incapacitated_cultists.keys():
		_incapacitated_cultists[cultist_id] = maxf(
			0.0, float(_incapacitated_cultists[cultist_id]) - step
		)
		if float(_incapacitated_cultists[cultist_id]) <= TIME_EPSILON:
			_recover_cultist(cultist_id, &"natural")


func _advance_stirs(step: float) -> void:
	for target_id: int in _stirs.keys():
		if not cultist_is_incapacitated(target_id):
			_stirs.erase(target_id)
			continue
		var stir: Dictionary = _stirs[target_id]
		stir["remaining"] = maxf(0.0, float(stir["remaining"]) - step)
		_stirs[target_id] = stir
		if float(stir["remaining"]) <= TIME_EPSILON:
			_recover_cultist(target_id, &"stirred")


func _recover_cultist(cultist_id: int, cause: StringName) -> void:
	_incapacitated_cultists.erase(cultist_id)
	_stirs.erase(cultist_id)
	_record(&"cultist_recovered", cultist_id, {"cause": cause})


# The knockout impact. This is the Commitment Point: witnesses perceive it and the
# victim goes Unconscious for the Night, becoming an Unattended Body on the spot.
func _knockout_patron(victim_id: int, cultist_id: int) -> void:
	var patron: Dictionary = _patrons[victim_id]
	var source_room := _patron_room(patron)
	var source_position := _patron_position(patron)
	var chance := knockout_chance(victim_id)
	var roll := _rng.randi_range(1, 100)
	var succeeded := roll <= int(chance)
	_witness_knockout(victim_id, source_room, source_position)
	var outcome_key := "%s:%s" % [cultist_id, victim_id]
	_knockout_outcomes[outcome_key] = &"succeeded" if succeeded else &"failed"
	if not succeeded:
		_route_stimulus(victim_id, &"knockout_witnessed", &"visual", cultist_id)
		_incapacitated_cultists[cultist_id] = CULTIST_INCAPACITATED_SECONDS
		_record(&"knockout_failed", victim_id, {
			"cultist_id": cultist_id, "chance": chance, "roll": roll,
		})
		return
	patron["bathroom_checks_active"] = false
	patron["lifecycle"] = &"unconscious"
	patron["collapse_cause"] = &"knockout"
	patron["body_room"] = source_room
	patron["body_position"] = source_position
	_set_activity(patron, &"unconscious", &"collapsed")
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
		patron["seat"] = &""
	_interaction_registry.release_actor(victim_id)
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"knockout")
	_patrons[victim_id] = patron
	_perception.add_body(victim_id, source_room, source_position)
	_record(&"knockout", victim_id, {
		"cultist_id": cultist_id, "chance": chance, "roll": roll,
	})


# Fans the impact out: a Patron who sees it receives Hard Evidence, a Patron who
# only hears it receives the +25 soft increase, and the victim never witnesses it.
func _witness_knockout(victim_id: int, source_room: StringName, source_position: Vector2) -> void:
	var perceivers := _active_perceivers()
	var seen: Dictionary = {}
	for patron_id: int in _perception.visual_recipients(source_room, source_position, perceivers):
		if patron_id == victim_id:
			continue
		if _route_stimulus(patron_id, &"knockout_witnessed", &"visual", victim_id):
			seen[patron_id] = true
	for patron_id: int in _perception.auditory_recipients(source_room, perceivers):
		if patron_id == victim_id or seen.has(patron_id):
			continue
		var noticed := _rng.randi_range(1, 100) <= int(KNOCKOUT_HEARING_NOTICE_PERCENT)
		_record(&"knockout_hearing_check", patron_id, {
			"source_id": victim_id, "noticed": noticed,
		})
		if noticed:
			_route_stimulus(patron_id, &"knockout_heard", &"auditory", victim_id)


func _advance_drags(step: float) -> void:
	for victim_id: int in _drags.keys():
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
					_apply_drag_witnessing(victim_id, drag, true)
					_record(&"body_drag_started", victim_id, {"cultist_id": drag["cultist_id"]})
			&"dragging":
				if _physical_navigation_enabled and not _behavior_arrived(_patrons[victim_id]):
					continue
				drag["witness_elapsed"] = float(drag["witness_elapsed"]) + step
				while float(drag["witness_elapsed"]) + TIME_EPSILON >= DRAG_WITNESS_INTERVAL_SECONDS:
					drag["witness_elapsed"] = float(drag["witness_elapsed"]) - DRAG_WITNESS_INTERVAL_SECONDS
					_apply_drag_witnessing(victim_id, drag, false)
				drag["remaining"] = 0.0 if _physical_navigation_enabled else float(drag["remaining"]) - step
				if float(drag["remaining"]) <= TIME_EPSILON:
					_drags[victim_id] = drag
					_capture_dragged_body(victim_id)
					continue
		if _drags.has(victim_id):
			_drags[victim_id] = drag


# Crossing the Tunnel Intake completes the Capture exactly once: the record is
# erased and the body removed, so a finished drag cannot capture the victim again.
func _capture_dragged_body(victim_id: int) -> void:
	var drag: Dictionary = _drags[victim_id]
	_apply_intake_witnessing(victim_id, drag)
	_drags.erase(victim_id)
	_collapses.erase(victim_id)
	_perception.remove_body(victim_id)
	var patron: Dictionary = _patrons[victim_id]
	_interaction_registry.release_actor(victim_id)
	patron["lifecycle"] = &"captured"
	_set_activity(patron, &"captured", &"tunnel")
	_patrons[victim_id] = patron
	var cause: StringName = drag.get("capture_cause", &"knockout")
	_captures.append({"id": victim_id, "cause": cause, "at": _simulated_seconds})
	_record(&"capture", victim_id, {"cause": cause, "cultist_id": drag["cultist_id"]})


func _apply_drag_witnessing(victim_id: int, drag: Dictionary, first: bool) -> void:
	var stimulus: StringName
	if StringName(drag.get("capture_cause", &"knockout")) == &"overdrink":
		stimulus = &"overdrink_body_drag_seen_first" if first else &"overdrink_body_drag_seen_continuing"
	else:
		stimulus = &"body_drag_seen_first" if first else &"body_drag_seen_continuing"
	var source_position: Vector2 = drag["source_position"] if first else BAR_POSITION
	for patron_id: int in _perception.visual_recipients(
		drag["source_room"], source_position, _active_perceivers()
	):
		_route_stimulus(patron_id, stimulus, &"visual", victim_id)


func _apply_intake_witnessing(victim_id: int, drag: Dictionary) -> void:
	for patron_id: int in _perception.visual_recipients(
		drag["source_room"], BAR_POSITION, _active_perceivers()
	):
		_route_stimulus(patron_id, &"body_intake_seen", &"visual", victim_id)


# --- Friendship building and Friendship Capture (GDD §10.4/§11) --------------

# Offers a cigarette: an instant +10 Friendship from this Cultist. Repeatable, capped
# at the Friendship maximum. Valid against any active Patron.
func offer_cigarette(cultist_id: int, patron_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _patrons.has(patron_id):
		return false
	if _patrons[patron_id]["lifecycle"] != &"active":
		return false
	_add_friendship(patron_id, cultist_id, FRIENDSHIP_CIGARETTE_BONUS)
	_record(&"cigarette_offered", patron_id, {
		"cultist_id": cultist_id, "friendship": _friendship_value(patron_id, cultist_id),
	})
	_emit_snapshot()
	return true


# Begins a sustained conversation that accrues ~0.75 Friendship per second and occupies
# the Cultist. Valid against an active Patron when the Cultist is free.
func begin_conversation(cultist_id: int, patron_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _patrons.has(patron_id):
		return false
	if _patrons[patron_id]["lifecycle"] != &"active" or is_cultist_busy(cultist_id):
		return false
	if _conversation_partner(patron_id) != ActorIds.NO_ACTOR:
		return false
	var patron: Dictionary = _patrons[patron_id]
	if not _set_activity(patron, &"conversing", &"seat"):
		return false
	_patrons[patron_id] = patron
	_conversations[cultist_id] = patron_id
	_record(&"conversation_started", patron_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func end_conversation(cultist_id: int) -> bool:
	if not _conversations.has(cultist_id):
		return false
	var patron_id: int = _conversations[cultist_id]
	_conversations.erase(cultist_id)
	if _patrons.has(patron_id):
		var patron: Dictionary = _patrons[patron_id]
		if not patron["identified"]:
			patron["identified"] = true
			_record(&"patron_identified", patron_id, {"cultist_id": cultist_id})
		if _satisfaction[patron_id].complete_talk(cultist_id):
			_record(&"satisfaction_changed", patron_id, {
				"cause": &"first_talk", "amount": 5.0, "value": _satisfaction[patron_id].value(),
			})
		var fallback: StringName = (
			&"awaiting_drink"
			if not StringName(patron["order_id"]).is_empty() and _order_system.is_open(patron["order_id"])
			else &"socializing"
		)
		_complete_activity(patron, fallback, &"seat")
		_patrons[patron_id] = patron
	_record(&"conversation_ended", patron_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


# Leads a Trusted, receptive Patron to the Tunnel Intake. There is no roll — only the
# sad, friendship-capturable Patron follows, and only once at Trusted Friendship (75+).
func begin_friendship_capture(cultist_id: int, patron_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or not _patrons.has(patron_id):
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"active" or not patron["friendship_capturable"]:
		return false
	if _friendship_value(patron_id, cultist_id) < FRIENDSHIP_TRUSTED_THRESHOLD:
		return false
	if is_cultist_busy(cultist_id):
		return false
	_end_conversation_with(patron_id)
	patron["bathroom_checks_active"] = false
	patron["lifecycle"] = &"following"
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
		patron["seat"] = &""
	_interaction_registry.release_actor(patron_id)
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, &"following")
	_set_activity(patron, &"following", &"tunnel")
	_patrons[patron_id] = patron
	_follows[patron_id] = {"cultist_id": cultist_id, "remaining": FOLLOW_TO_INTAKE_SECONDS}
	_record(&"friendship_capture_started", patron_id, {"cultist_id": cultist_id})
	_emit_snapshot()
	return true


func friendship_value(patron_id: int, cultist_id: int) -> float:
	return _friendship_value(patron_id, cultist_id)


func friendship_band(patron_id: int, cultist_id: int) -> String:
	return _friendship_band(_friendship_value(patron_id, cultist_id))


func stay_behind_chance(patron_id: int) -> float:
	if not _patrons.has(patron_id):
		return 0.0
	var suspicion: float = _suspicion_states[patron_id].snapshot()["score"]
	if suspicion >= MAXIMUM_SUSPICION:
		return 0.0
	var friendship := _active_bartender_friendship(patron_id)
	var intoxication := float(_patrons[patron_id]["intoxication"])
	return clampf(
		STAY_BEHIND_BASE
			+ STAY_BEHIND_FRIENDSHIP_COEFF * friendship
			+ STAY_BEHIND_INTOXICATION_COEFF * intoxication
			- STAY_BEHIND_SUSPICION_COEFF * suspicion,
		0.0, STAY_BEHIND_MAXIMUM
	)


func _add_friendship(patron_id: int, cultist_id: int, amount: float) -> void:
	var friendship: Dictionary = _patrons[patron_id]["friendship"]
	friendship[cultist_id] = minf(FRIENDSHIP_MAXIMUM, float(friendship.get(cultist_id, 0.0)) + amount)


func _friendship_value(patron_id: int, cultist_id: int) -> float:
	if not _patrons.has(patron_id):
		return 0.0
	return float(_patrons[patron_id]["friendship"].get(cultist_id, 0.0))


# The Active Bartender Friendship: the Patron's highest Friendship toward a Cultist doing
# bar work. Every Cultist may serve, so we take the Patron's highest Friendship of all.
func _active_bartender_friendship(patron_id: int) -> float:
	var best := 0.0
	for cultist_id: int in _patrons[patron_id]["friendship"]:
		best = maxf(best, float(_patrons[patron_id]["friendship"][cultist_id]))
	return best


func _conversation_partner(patron_id: int) -> int:
	for cultist_id: int in _conversations:
		if _conversations[cultist_id] == patron_id:
			return cultist_id
	return ActorIds.NO_ACTOR


func _end_conversation_with(patron_id: int) -> void:
	var cultist_id := _conversation_partner(patron_id)
	if cultist_id != ActorIds.NO_ACTOR:
		_conversations.erase(cultist_id)


func _advance_conversations(step: float) -> void:
	for cultist_id: int in _conversations.keys():
		var patron_id: int = _conversations[cultist_id]
		if not _patrons.has(patron_id) or _patrons[patron_id]["lifecycle"] != &"active":
			_conversations.erase(cultist_id)
			continue
		_add_friendship(patron_id, cultist_id, FRIENDSHIP_CONVERSATION_PER_SECOND * step)


func _advance_follows(step: float) -> void:
	for patron_id: int in _follows.keys():
		var follow: Dictionary = _follows[patron_id]
		if _physical_navigation_enabled and not _behavior_arrived(_patrons[patron_id]):
			continue
		follow["remaining"] = 0.0 if _physical_navigation_enabled else float(follow["remaining"]) - step
		if float(follow["remaining"]) <= TIME_EPSILON:
			_capture_follower(patron_id, follow["cultist_id"])
			continue
		_follows[patron_id] = follow


func _capture_follower(patron_id: int, cultist_id: int) -> void:
	_follows.erase(patron_id)
	var patron: Dictionary = _patrons[patron_id]
	_interaction_registry.release_actor(patron_id)
	patron["lifecycle"] = &"captured"
	_set_activity(patron, &"captured", &"tunnel")
	_patrons[patron_id] = patron
	_captures.append({"id": patron_id, "cause": &"friendship_capture", "at": _simulated_seconds})
	_record(&"capture", patron_id, {"cause": &"friendship_capture", "cultist_id": cultist_id})


func _advance_intoxication(patron_id: int, patron: Dictionary, delta: float) -> void:
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
		var due := (
			_closing
			or bool(group.get("asked_to_leave", false))
			or _simulated_seconds >= float(group["seated_at"]) + DEPARTURE_AFTER_SEATED_SECONDS
		)
		if not due or not _group_ready_to_depart(group):
			continue
		# The departure anchor (first-defined member) always leaves. Every other eligible
		# member rolls its stay-behind chance once; a stayer becomes a solo Patron.
		var anchor_taken := false
		for patron_id: int in group["patrons"]:
			var patron: Dictionary = _patrons[patron_id]
			if patron["lifecycle"] != &"active":
				continue
			if not anchor_taken:
				anchor_taken = true
				_depart_patron(patron_id, patron, &"visit_complete")
				continue
			if not _closing and _roll_stay_behind(patron_id):
				continue
			_depart_patron(patron_id, patron, &"visit_complete")
		group["departed"] = true
		_groups[group_id] = group
		_record(&"arrival_group_departed", group_id)


# A single stay-behind roll on the seeded source. Returns true when the Patron stays.
func _roll_stay_behind(patron_id: int) -> bool:
	var patron: Dictionary = _patrons[patron_id]
	if patron["stay_rolled"]:
		return patron["stayed_behind"]
	patron["stay_rolled"] = true
	var chance := stay_behind_chance(patron_id)
	var roll := _rng.randf_range(0.0, 100.0)
	var stays := roll < chance
	patron["stayed_behind"] = stays
	_patrons[patron_id] = patron
	_record(&"stay_behind_rolled", patron_id, {"chance": chance, "roll": roll, "stays": stays})
	return stays


# A stayer is a solo Patron until Closing, when it finally leaves through the front.
func _try_stayer_departures() -> void:
	if not _closing:
		return
	for patron_id: int in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if not patron["stayed_behind"] or patron["lifecycle"] != &"active":
			continue
		if _activity(patron) not in [&"socializing", &"awaiting_drink"]:
			continue
		patron["stayed_behind"] = false
		_depart_patron(patron_id, patron, &"stayer_closing")


func _group_ready_to_depart(group: Dictionary) -> bool:
	for patron_id: int in group["patrons"]:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"active":
			continue
		if _activity(patron) not in [&"socializing", &"awaiting_drink"]:
			return false
	return true


func _depart_patron(patron_id: int, patron: Dictionary, reason: StringName) -> void:
	_interaction_registry.release_actor(patron_id)
	if not StringName(patron["seat"]).is_empty():
		_seat_owners[patron["seat"]] = ActorIds.NO_ACTOR
	var order_id: StringName = patron["order_id"]
	if not order_id.is_empty() and _order_system.is_open(order_id):
		_order_system.cancel_order(order_id, _simulated_seconds, reason)
	patron["bathroom_checks_active"] = false
	var departure_started := _set_activity(patron, &"normal_departure", &"front_exit")
	if not departure_started and _activity(patron) == &"awaiting_drink":
		# Cancelling the open Order completes that phase, so its deferred Departure can start.
		_complete_activity(patron, &"normal_departure", &"front_exit")
	patron["lifecycle"] = &"leaving" if _physical_navigation_enabled else &"exited"
	patron["departure_timeout"] = (
		PHYSICAL_DEPARTURE_TIMEOUT_SECONDS if _physical_navigation_enabled else -1.0
	)
	if not _physical_navigation_enabled:
		_patron_actions[patron_id].submit(&"exited")
	_patrons[patron_id] = patron
	_record(&"normal_departure", patron_id, {"reason": reason})


func _set_activity(patron: Dictionary, activity: StringName, destination: StringName) -> bool:
	var patron_id: int = patron["id"]
	if _patron_actions.has(patron_id):
		var reservation: StringName = _interaction_registry.actor_slot(patron_id)
		var result: Dictionary = _patron_actions[patron_id].submit(
			activity, destination, reservation,
			_physical_navigation_enabled and _activity_requires_movement(activity)
		)
		if result["decision"] != PATRON_INTENT_PLANNER_SCRIPT.ACCEPT:
			var event_name: StringName = (
				&"behavior_intent_deferred"
				if result["decision"] == PATRON_INTENT_PLANNER_SCRIPT.DEFER
				else &"behavior_intent_rejected"
			)
			_record(event_name, patron_id, {
				"from": result["from"], "to": activity, "reason": result["reason"],
			})
			return false
		_patron_actions[patron_id].configure_timing(_activity_duration(patron, activity))
	return true


func _activity_duration(patron: Dictionary, activity: StringName) -> float:
	match activity:
		&"drinking": return DRINK_SECONDS
		&"socializing": return float(patron["social_interval"])
		&"mirror_check": return BATHROOM_MIRROR_SECONDS
		&"seated_bathroom_use": return float(patron["bathroom_use_seconds"])
		&"handwashing": return BATHROOM_HANDWASH_SECONDS
		&"investigation_search": return INVESTIGATION_SECONDS
		&"shock": return ESCAPE_SHOCK_SECONDS
		&"escaping": return ESCAPE_TRAVEL_SECONDS
		&"helper_reacting": return HELPER_REACTION_SECONDS
		&"helper_lifting": return HELPER_LIFT_SECONDS
		&"helper_carrying": return HELPER_CARRY_SECONDS
	return INF


func _complete_activity(patron: Dictionary, fallback: StringName, destination: StringName) -> void:
	var patron_id: int = patron["id"]
	if not _patron_actions.has(patron_id):
		_set_activity(patron, fallback, destination)
		return
	var deferred: Array = _patron_actions[patron_id].snapshot()["deferred"]
	var next_destination := destination
	if not deferred.is_empty():
		deferred.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return PATRON_INTENT_PLANNER_SCRIPT.CLASS_PRIORITY.get(
				PATRON_INTENT_PLANNER_SCRIPT.STATE_CLASS[left["state"]], -1
			) > PATRON_INTENT_PLANNER_SCRIPT.CLASS_PRIORITY.get(
				PATRON_INTENT_PLANNER_SCRIPT.STATE_CLASS[right["state"]], -1
			)
		)
		next_destination = _destination_for_activity(deferred[0]["state"], patron)
	_patron_actions[patron_id].complete_committed(
		fallback, next_destination, _interaction_registry.actor_slot(patron_id),
		_physical_navigation_enabled and _activity_requires_movement(
			deferred[0]["state"] if not deferred.is_empty() else fallback
		)
	)
	_patron_actions[patron_id].configure_timing(_activity_duration(patron, _activity(patron)))


func _movement_complete(patron: Dictionary, fallback_seconds: float) -> bool:
	return (
		_behavior_arrived(patron)
		if _physical_navigation_enabled
		else _behavior_elapsed(patron) >= fallback_seconds
	)


func _behavior_snapshot(patron: Dictionary) -> Dictionary:
	return _patron_actions[patron["id"]].snapshot(false)


func _activity(patron: Dictionary) -> StringName:
	return _behavior_snapshot(patron)["state"]


func _behavior_elapsed(patron: Dictionary) -> float:
	return float(_behavior_snapshot(patron)["elapsed_seconds"])


func _behavior_arrived(patron: Dictionary) -> bool:
	return bool(_behavior_snapshot(patron)["navigation_arrived"])


func _activity_requires_movement(activity: StringName) -> bool:
	return activity in [
		&"entering", &"entering_bathroom", &"moving_to_toilet", &"moving_to_sink",
		&"standing_bathroom_exit", &"investigation_search", &"escaping",
		&"helper_carrying", &"being_dragged", &"following", &"normal_departure",
	]


func _destination_for_activity(activity: StringName, patron: Dictionary) -> StringName:
	match activity:
		&"entering", &"finding_seat", &"awaiting_drink", &"drinking", &"socializing", &"conversing":
			return &"seat"
		&"bathroom_queued":
			return &"bathroom_line"
		&"entering_bathroom":
			return &"mirror"
		&"mirror_check":
			return &"mirror"
		&"moving_to_toilet", &"seated_bathroom_use":
			return &"toilet"
		&"moving_to_sink", &"handwashing":
			return &"sink"
		&"investigation_search", &"waiting_investigation":
			return &"bathroom"
		&"standing_bathroom_exit":
			return &"bathroom_exit"
		&"shock", &"escaping", &"intercepted", &"normal_departure", &"helper_carrying", &"helper_persuading":
			return &"front_exit"
		&"unconscious":
			return &"collapsed"
		&"being_dragged", &"following", &"captured":
			return &"tunnel"
	return patron.get("navigation_destination", &"seat")


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
		&"bathroom_queued": "Waiting for bathroom",
		&"entering_bathroom": "Going to bathroom",
		&"mirror_check": "Checking the mirror",
		&"moving_to_toilet": "Using bathroom",
		&"seated_bathroom_use": "Using bathroom",
		&"moving_to_sink": "Washing up",
		&"handwashing": "Washing up",
		&"standing_bathroom_exit": "Leaving bathroom",
		&"waiting_investigation": "Waiting to investigate",
		&"investigation_search": "Investigating",
		&"shock": "Reacting",
		&"escaping": "Escaping",
		&"intercepted": "Intercepted",
		&"unconscious": "Unconscious",
		&"helper_reacting": "Helping companion",
		&"helper_lifting": "Helping companion",
		&"helper_carrying": "Helping companion",
		&"helper_persuading": "Rescue Persuasion",
		&"being_dragged": "Being dragged",
		&"conversing": "Conversing",
		&"following": "Following Cultist",
		&"captured": "Captured",
		&"normal_departure": "Normal Departure",
		&"exited": "Normal Departure",
	}
	return labels.get(activity, "Present")


func _intoxication_label(level: int) -> String:
	return ["Sober", "Buzzed", "Drunk", "Max Drunk"][clampi(level, 0, 3)]


func _friendship_band(value: float) -> String:
	if value >= 75.0:
		return "Trusted"
	if value >= 50.0:
		return "Friendly"
	if value >= 25.0:
		return "Acquainted"
	return "Stranger"


func _count_capture_autonomy_actions() -> int:
	var count := 0
	for event: Dictionary in _autonomy_events:
		if event["capture_related"] or event["action"] in CAPTURE_ACTIONS:
			count += 1
	return count


func _record(event_name: StringName, actor_id: Variant, details: Dictionary = {}) -> void:
	_events.append({"at": _simulated_seconds, "event": event_name, "actor_id": actor_id, "details": details.duplicate(true)})


func _emit_snapshot() -> void:
	snapshot_changed.emit(snapshot())
