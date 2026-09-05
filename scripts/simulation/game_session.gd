class_name GameSession
extends RefCounted

signal snapshot_changed(snapshot: Dictionary)

const ORDINARY_VISIT_SESSION_SCRIPT := preload("res://scripts/simulation/ordinary_visit_session.gd")
const SUPPORTED_TIME_SCALES: Array[float] = [0.0, 1.0, 2.0, 4.0]
const CULTIST_IDS: Array[int] = ActorIds.CULTIST_IDS
const PREPARATION_END_SECONDS := 60.0
const CLOSING_START_SECONDS := 960.0
const NIGHT_END_SECONDS := 1080.0
const CAPTURE_QUOTA := 3
## The Night Clock reads 8:00 PM when the Night starts and 2:00 AM when it ends
## (CONTEXT.md). This is the only mapping from Night progress to a clock face;
## no phase boundary, duration, or gameplay rule reads it.
const CLOCK_OPENING_MINUTES := 20 * 60
const CLOCK_CLOSING_MINUTES := 26 * 60
const REPRESENTATIVE_ROLL_INTERVAL_SECONDS := 5.0
const REPRESENTATIVE_ROLLS_FOR_OUTCOME := 4

var _night_seed: int = 0
var _simulated_seconds: float = 0.0
var _time_scale: float = 1.0
var _phase: StringName = &"preparation"
var _outcome: StringName = &"running"
var _outcome_cause: StringName = &""
var _next_representative_roll_at: float = REPRESENTATIVE_ROLL_INTERVAL_SECONDS
var _representative_rolls: Array[int] = []
var _representative_outcome: StringName = &"running"
var _rng := RandomNumberGenerator.new()
var _ordinary_visits = ORDINARY_VISIT_SESSION_SCRIPT.new()
var _session_events: Array[Dictionary] = []


func start_night(night_seed: int) -> void:
	_night_seed = night_seed
	_simulated_seconds = 0.0
	_time_scale = 1.0
	_phase = &"preparation"
	_outcome = &"running"
	_outcome_cause = &""
	_next_representative_roll_at = REPRESENTATIVE_ROLL_INTERVAL_SECONDS
	_representative_rolls.clear()
	_representative_outcome = &"running"
	_rng.seed = night_seed
	_ordinary_visits = ORDINARY_VISIT_SESSION_SCRIPT.new()
	_ordinary_visits.start(night_seed, true)
	_session_events.clear()
	_record(&"night_started", {"seed": night_seed})
	_emit_snapshot()


func restart_night(night_seed: int) -> void:
	start_night(night_seed)


func set_time_scale(value: float) -> bool:
	if value not in SUPPORTED_TIME_SCALES or _phase == &"results":
		return false
	# An active Escape forces 1x (TECHNICAL_DESIGN §4: "Starting Escape requests 1x").
	if value > 1.0 and _ordinary_visits.has_active_escape():
		return false
	_time_scale = value
	_record(&"time_scale_changed", {"value": value})
	_emit_snapshot()
	return true


## The current selected time scale. NightPlayback reads it to synchronize the HUD
## after the simulation changes the scale on its own (an Escape forcing 1x).
func current_time_scale() -> float:
	return _time_scale


## True while the Night still accepts a Simulation Speed change. It closes at
## Results, where the Outcome Modal owns the screen.
func accepts_time_control() -> bool:
	return _phase != &"results"


## The player-readable Simulation Speed lock. Escape is observable, so exposing
## the reduced set of speeds is safe; no hidden escaping-Patron value crosses it.
func time_control() -> Dictionary:
	if _phase != &"results" and _ordinary_visits.has_active_escape():
		return {"available_scales": [0.0, 1.0], "lock_reason": &"active_escape"}
	return {"available_scales": SUPPORTED_TIME_SCALES.duplicate(), "lock_reason": &""}


func report_patron_stimulus(
		patron_id: int,
		stimulus: StringName,
		observer_is_max_drunk: bool = false
) -> bool:
	var applied: bool = _ordinary_visits.apply_suspicion_stimulus(
		patron_id, stimulus, observer_is_max_drunk
	)
	if applied:
		_record(&"patron_stimulus_reported", {
			"patron_id": patron_id,
			"stimulus": stimulus,
			"max_drunk_observation": observer_is_max_drunk,
		})
		_emit_snapshot()
	return applied


func report_danger_event(
		stimulus: StringName,
		channel: StringName,
		source_room: StringName,
		source_id: Variant = ActorIds.NO_ACTOR,
		source_position := Vector2.ZERO
) -> Array:
	var perceived: Array = _ordinary_visits.report_danger_event(
		stimulus, channel, source_room, source_id, source_position
	)
	if not perceived.is_empty():
		_record(&"danger_event_perceived", {
			"stimulus": stimulus,
			"channel": channel,
			"source": source_id if source_id != ActorIds.NO_ACTOR else source_room,
			"recipients": perceived,
		})
		_emit_snapshot()
	return perceived


func add_unattended_body(body_id: int, room: StringName, position := Vector2.ZERO) -> void:
	_ordinary_visits.add_unattended_body(body_id, room, position)
	_record(&"unattended_body_added", {"body_id": body_id, "room": room})
	_emit_snapshot()


func set_unattended_body_state(body_id: int, state: StringName) -> void:
	_ordinary_visits.set_unattended_body_state(body_id, state)
	_record(&"unattended_body_state_changed", {"body_id": body_id, "state": state})
	_emit_snapshot()


func drop_unattended_body(body_id: int, room: StringName, position := Vector2.ZERO) -> void:
	_ordinary_visits.drop_unattended_body(body_id, room, position)
	_record(&"unattended_body_dropped", {"body_id": body_id, "room": room})
	_emit_snapshot()


func remove_unattended_body(body_id: int) -> void:
	_ordinary_visits.remove_unattended_body(body_id)
	_record(&"unattended_body_removed", {"body_id": body_id})
	_emit_snapshot()


func activate_trapdoor() -> bool:
	if _phase == &"results":
		return false
	var armed: bool = _ordinary_visits.activate_trapdoor()
	if armed:
		_apply_escape_speed_lock()
		_record(&"trapdoor_activated", {"captures": _ordinary_visits.snapshot()["captures"].size()})
		_emit_snapshot()
	return armed


func begin_intercept(patron_id: int, cultist_id: int) -> bool:
	var started: bool = _ordinary_visits.begin_intercept(patron_id, cultist_id)
	if started:
		_record(&"intercept_started", {"patron_id": patron_id, "cultist_id": cultist_id})
		_emit_snapshot()
	return started


func debug_force_bathroom(patron_id: int) -> bool:
	var forced: bool = _ordinary_visits.debug_force_bathroom(patron_id)
	if forced:
		_record(&"debug_bathroom_forced", {"patron_id": patron_id})
		_emit_snapshot()
	return forced


func character_actions():
	return _ordinary_visits.character_actions()


func request_patron_step_aside(
	patron_id: int, position: Vector3, incident_id: StringName
) -> bool:
	return _ordinary_visits.request_patron_step_aside(patron_id, position, incident_id)


func debug_cancel_patron_action(patron_id: int, action_id: int, current_position: Variant = null) -> bool:
	return _ordinary_visits.debug_cancel_patron_action(patron_id, action_id, current_position)


func debug_force_complete_patron_action(patron_id: int) -> bool:
	return _ordinary_visits.debug_force_complete_patron_action(patron_id)


func debug_clear_patron_queue(patron_id: int) -> bool:
	return _ordinary_visits.debug_clear_patron_queue(patron_id)


func debug_set_patron_planner_paused(patron_id: int, paused: bool) -> bool:
	return _ordinary_visits.debug_set_patron_planner_paused(patron_id, paused)


func serve_patron_order(patron_id: int, cultist_id: int) -> bool:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return false
	var served: bool = _ordinary_visits.serve_patron_order(patron_id)
	if served:
		_record(&"order_served_by_command", {
			"patron_id": patron_id,
			"cultist_id": cultist_id,
		})
		_emit_snapshot()
	return served


func offer_drink(patron_id: int, cultist_id: int, drugged: bool = false) -> Dictionary:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return {"accepted": false, "reason": &"invalid_cultist", "roll": -1.0}
	var result: Dictionary = _ordinary_visits.offer_drink(patron_id, cultist_id, drugged)
	_emit_snapshot()
	return result


func debug_set_patron_drink_state(
	patron_id: int,
	intoxication: int,
	overdrink_limit: int,
	excess_drinks: int = 0,
	ideal_intoxication: int = -1
) -> bool:
	return _ordinary_visits.debug_set_patron_drink_state(
		patron_id, intoxication, overdrink_limit, excess_drinks, ideal_intoxication
	)


func debug_change_patron_satisfaction(patron_id: int, amount: float) -> bool:
	return _ordinary_visits.debug_change_patron_satisfaction(patron_id, amount)


func debug_force_finish_drink(patron_id: int) -> bool:
	return _ordinary_visits.debug_force_finish_drink(patron_id)


func set_physical_patron_navigation_enabled(enabled: bool) -> void:
	_ordinary_visits.set_physical_navigation_enabled(enabled)


func patron_destination_reached(patron_id: int, action_id: int = -1) -> bool:
	var reached := _ordinary_visits.patron_destination_reached(patron_id, action_id)
	if reached:
		_emit_snapshot()
	return reached


func patron_view(patron_id: int, selected_cultist_id: int) -> Dictionary:
	return _ordinary_visits.normal_patron_view(patron_id, selected_cultist_id)


func prepare_drugged_drink(patron_id: int, cultist_id: int) -> bool:
	if _phase == &"results":
		return false
	var prepared: bool = _ordinary_visits.prepare_drugged_drink(patron_id, cultist_id)
	if prepared:
		_record(&"drugged_drink_prepared", {"patron_id": patron_id, "cultist_id": cultist_id})
		_emit_snapshot()
	return prepared


func attempt_rescue_persuasion(cultist_id: int) -> bool:
	var chance := _ordinary_visits.rescue_persuasion_chance(cultist_id)
	var attempted: bool = _ordinary_visits.attempt_rescue_persuasion(cultist_id)
	if attempted:
		_record(&"rescue_persuasion_attempted", {"cultist_id": cultist_id, "chance": chance})
		_emit_snapshot()
	return attempted


func rescue_persuasion_chance(cultist_id: int) -> float:
	return _ordinary_visits.rescue_persuasion_chance(cultist_id)


func begin_knockout(cultist_id: int, victim_id: int) -> bool:
	if _phase == &"results":
		return false
	var started: bool = _ordinary_visits.begin_knockout(cultist_id, victim_id)
	if started:
		_record(&"knockout_windup_started", {"cultist_id": cultist_id, "victim_id": victim_id})
		_emit_snapshot()
	return started


func cancel_knockout(cultist_id: int) -> bool:
	var cancelled: bool = _ordinary_visits.cancel_knockout(cultist_id)
	if cancelled:
		_record(&"knockout_windup_cancelled", {"cultist_id": cultist_id})
		_emit_snapshot()
	return cancelled


func knockout_chance(victim_id: int) -> float:
	return _ordinary_visits.knockout_chance(victim_id)


func cultist_is_incapacitated(cultist_id: int) -> bool:
	return _ordinary_visits.cultist_is_incapacitated(cultist_id)


func cultist_incapacitated_remaining(cultist_id: int) -> float:
	return _ordinary_visits.cultist_incapacitated_remaining(cultist_id)


func begin_stir(helper_id: int, target_id: Variant) -> bool:
	if _phase == &"results":
		return false
	var started := _ordinary_visits.begin_stir(helper_id, target_id)
	if started:
		_record(&"stir_started", {"cultist_id": helper_id, "target_id": target_id})
		_emit_snapshot()
	return started


func cancel_stir(helper_id: int) -> bool:
	var cancelled := _ordinary_visits.cancel_stir(helper_id)
	if cancelled:
		_record(&"stir_cancelled", {"cultist_id": helper_id})
		_emit_snapshot()
	return cancelled


func command_action_state(
		command: StringName, cultist_id: int, target_id: Variant
) -> StringName:
	return _ordinary_visits.command_action_state(command, cultist_id, target_id)


func pick_up_body(cultist_id: int, victim_id: int) -> bool:
	if _phase == &"results":
		return false
	var picked: bool = _ordinary_visits.pick_up_body(cultist_id, victim_id)
	if picked:
		_record(&"body_pickup_started", {"cultist_id": cultist_id, "victim_id": victim_id})
		_emit_snapshot()
	return picked


func drop_body(cultist_id: int) -> bool:
	var dropped: bool = _ordinary_visits.drop_body(cultist_id)
	if dropped:
		_record(&"body_dropped", {"cultist_id": cultist_id})
		_emit_snapshot()
	return dropped


func is_cultist_busy(cultist_id: int) -> bool:
	return _ordinary_visits.is_cultist_busy(cultist_id)


func offer_cigarette(cultist_id: int, patron_id: int) -> bool:
	if _phase == &"results":
		return false
	var offered: bool = _ordinary_visits.offer_cigarette(cultist_id, patron_id)
	if offered:
		_record(&"cigarette_offered", {"cultist_id": cultist_id, "patron_id": patron_id})
		_emit_snapshot()
	return offered


func begin_conversation(cultist_id: int, patron_id: int) -> bool:
	if _phase == &"results":
		return false
	var started: bool = _ordinary_visits.begin_conversation(cultist_id, patron_id)
	if started:
		_record(&"conversation_started", {"cultist_id": cultist_id, "patron_id": patron_id})
		_emit_snapshot()
	return started


func end_conversation(cultist_id: int) -> bool:
	var ended: bool = _ordinary_visits.end_conversation(cultist_id)
	if ended:
		_record(&"conversation_ended", {"cultist_id": cultist_id})
		_emit_snapshot()
	return ended


func begin_friendship_capture(cultist_id: int, patron_id: int) -> bool:
	if _phase == &"results":
		return false
	var started: bool = _ordinary_visits.begin_friendship_capture(cultist_id, patron_id)
	if started:
		_record(&"friendship_capture_started", {"cultist_id": cultist_id, "patron_id": patron_id})
		_emit_snapshot()
	return started


func friendship_value(patron_id: int, cultist_id: int) -> float:
	return _ordinary_visits.friendship_value(patron_id, cultist_id)


func friendship_band(patron_id: int, cultist_id: int) -> String:
	return _ordinary_visits.friendship_band(patron_id, cultist_id)


func stay_behind_chance(patron_id: int) -> float:
	return _ordinary_visits.stay_behind_chance(patron_id)


# --- Emote information-safety seam -------------------------------------------

# The only projection the Emote system may read. Patron rows come from normal
# Patron views; Cultist rows come from the unified command summary when the
# adapter supplies one, and from the session's public activity otherwise.
# Nothing hidden crosses this seam, so no bubble can leak a simulation value.
func emote_view(cultist_commands: Dictionary = {}) -> Dictionary:
	var visit: Dictionary = _ordinary_visits.snapshot()
	var rows: Dictionary = {}
	for patron_id: int in visit["debug_views"]:
		var row: Dictionary = _ordinary_visits.patron_emote_row(patron_id)
		if not row.is_empty():
			rows[patron_id] = row
	var summaries := _cultist_summary(visit)
	var talking: Array = _ordinary_visits.conversing_cultists()
	for cultist_id in CULTIST_IDS:
		var activity: StringName = summaries[cultist_id]["activity"]
		var state: StringName = &"none"
		if cultist_id in talking:
			state = &"conversation"
		elif activity == &"talk":
			state = &"conversation"
		if cultist_is_incapacitated(cultist_id):
			state = &"cultist_incapacitated"
		var changes: Array[StringName] = []
		var events: Array[Dictionary] = []
		rows[cultist_id] = {
			"id": cultist_id,
			"kind": &"cultist",
			"present": true,
			"state": state,
			"changes": changes,
			"events": events,
			"public": {"activity": String(activity).replace("_", " ").capitalize()},
		}
	return rows

# --- Cultist command seam ----------------------------------------------------
# CultistCommandSystem owns the Action Queue and the Commitment Point; the rules
# behind each command stay here, in the gameplay authority.

func command_availability(
		command: StringName,
		cultist_id: int,
		target_id: Variant
) -> Dictionary:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return {"visible": false, "available": false, "reason": &"night_over", "detail": ""}
	return _ordinary_visits.command_availability(command, cultist_id, target_id)


func serve_drink_availability(
		patron_id: int, cultist_id: int, drink_id: StringName
) -> Dictionary:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return {"visible": false, "available": false, "reason": &"night_over", "detail": ""}
	return _ordinary_visits.serve_drink_availability(patron_id, cultist_id, drink_id)


func prepare_drink(cultist_id: int) -> bool:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return false
	var prepared: bool = _ordinary_visits.prepare_drink(cultist_id)
	if prepared:
		_record(&"prepared_drink_taken", {"cultist_id": cultist_id})
		_emit_snapshot()
	return prepared


func make_drink(drink_type: StringName, cultist_id: int) -> bool:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return false
	var made: bool = _ordinary_visits.make_drink(drink_type, cultist_id)
	if made:
		_record(&"prepared_drink_made", {"cultist_id": cultist_id, "drink_type": drink_type})
		_emit_snapshot()
	return made


func reserve_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	return _ordinary_visits.reserve_prepared_drink(drink_id, cultist_id)


func prepared_drink(drink_id: StringName) -> Dictionary:
	return _ordinary_visits.prepared_drink(drink_id)


func pick_up_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	return _ordinary_visits.pick_up_prepared_drink(drink_id, cultist_id)


func release_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	return _ordinary_visits.release_prepared_drink(drink_id, cultist_id)


func dispose_prepared_drink(drink_id: StringName) -> Dictionary:
	return _ordinary_visits.dispose_prepared_drink(drink_id)


func drug_prepared_drink(drink_id: StringName, cultist_id: int) -> bool:
	return _ordinary_visits.drug_prepared_drink(drink_id, cultist_id)


func serve_prepared_drink(
		patron_id: int, cultist_id: int, drink_id: StringName
) -> Dictionary:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return {"served": false, "accepted": false, "reason": &"invalid_cultist"}
	return _ordinary_visits.serve_prepared_drink(patron_id, cultist_id, drink_id)


func begin_admit_group(cultist_id: int) -> bool:
	return _ordinary_visits.begin_admit_group(cultist_id, _ordinary_visits.waiting_group_id())


func cancel_admit_group(cultist_id: int) -> bool:
	return _ordinary_visits.cancel_admit_group(cultist_id)


func begin_ask_to_leave(cultist_id: int, patron_id: int) -> bool:
	return _ordinary_visits.begin_ask_to_leave(cultist_id, patron_id)


func cancel_ask_to_leave(cultist_id: int) -> bool:
	return _ordinary_visits.cancel_ask_to_leave(cultist_id)


func carries_prepared_drink(cultist_id: int) -> bool:
	return _ordinary_visits.carries_prepared_drink(cultist_id)


func prepare_drugged_drink_for_next_order(cultist_id: int) -> bool:
	if _phase == &"results":
		return false
	var prepared: bool = _ordinary_visits.prepare_drugged_drink_for_next_order(cultist_id)
	if prepared:
		_record(&"drugged_drink_prepared", {"cultist_id": cultist_id})
		_emit_snapshot()
	return prepared


func end_cultist_engagement(cultist_id: int) -> bool:
	var ended: bool = _ordinary_visits.end_cultist_engagement(cultist_id)
	if ended:
		_record(&"conversation_ended", {"cultist_id": cultist_id})
		_emit_snapshot()
	return ended


func conversation_is_active(cultist_id: int, patron_id: int) -> bool:
	return _ordinary_visits.conversation_is_active(cultist_id, patron_id)


func advance(real_seconds: float) -> void:
	if real_seconds <= 0.0 or _time_scale <= 0.0 or _phase == &"results":
		return
	var remaining := real_seconds * _time_scale
	while remaining > 0.0001 and _simulated_seconds < NIGHT_END_SECONDS:
		var boundary := _next_phase_boundary()
		var step := minf(remaining, boundary - _simulated_seconds)
		if step > 0.0001:
			_simulated_seconds += step
			_ordinary_visits.advance(step)
			_advance_representative_rolls()
			remaining -= step
			if _ordinary_visits.has_defeat():
				_finalize_defeat()
				break
			_apply_escape_speed_lock()
		_apply_phase_boundary()
	_emit_snapshot()


func _apply_escape_speed_lock() -> void:
	if _phase == &"results":
		return
	if _ordinary_visits.has_active_escape() and _time_scale > 1.0:
		_time_scale = 1.0
		_record(&"escape_speed_forced", {"value": 1.0})


func _finalize_defeat() -> void:
	if _phase == &"results":
		return
	_phase = &"results"
	_time_scale = 0.0
	_outcome = &"defeat"
	_outcome_cause = &"maximum_suspicion_escape"
	_ordinary_visits.finish_night()
	_record(&"results_reached", {"outcome": _outcome, "cause": _outcome_cause})


func snapshot() -> Dictionary:
	var visit: Dictionary = _ordinary_visits.snapshot()
	var patrons := _patron_summary(visit)
	var orders := _order_summary(visit["orders"])
	var captures: Array = visit["captures"]
	return {
		"night_seed": _night_seed,
		"simulated_seconds": _simulated_seconds,
		"time_scale": _time_scale,
		"time_control": time_control(),
		"phase": _phase,
		"phase_label": _phase_label(),
		"clock_label": _clock_label(),
		"clock_minutes": clock_minutes(),
		"closing_label": closing_label(),
		"outcome": _outcome,
		"captures": captures.size(),
		"capture_log": captures.duplicate(true),
		"defeat": visit["defeat"],
		"trapdoor": visit["trapdoor"],
		"active_intercept": visit["active_intercept"],
		"escaping_patrons": visit["escaping_patrons"],
		"doses_remaining": visit["doses_remaining"],
		"drug_prep": visit["drug_prep"],
		"prepared_drinks": visit["prepared_drinks"],
		"admission": visit["admission"],
		"ask_to_leave": visit["ask_to_leave"],
		"collapses": visit["collapses"],
		"windup": visit["windup"],
		"incapacitated_cultists": visit["incapacitated_cultists"],
		"stirs": visit["stirs"],
		"drags": visit["drags"],
		"conversations": visit["conversations"],
		"follows": visit["follows"],
		"patrons": patrons,
		"orders": orders,
		"safe_autonomy": visit["safe_autonomy"],
		"cultists": _cultist_summary(visit),
		"normal_patron_views": visit["normal_views"],
		"emote_view": emote_view(),
		"debug_patron_views": visit["debug_views"],
		"arrival_groups": visit["groups"],
		"seat_owners": visit["seat_owners"],
		"bathroom_owner": visit["bathroom_owner"],
		"bathroom_line_owner": visit["bathroom_line_owner"],
		"visit_events": visit["events"],
		"results": _results(orders, patrons, captures.size(), visit),
		"rescue_odds": visit["rescue_odds"],
		"escape_alerts": visit["escaping_patrons"],
		"runtime": {
			"spawned_patrons": patrons["active_count"],
			"prepared_drinks": visit["prepared_drinks"]["drinks"].size(),
			"actions": 0,
			"reservations": _reservation_count(visit),
			"timers": 0,
		},
		"events": _session_events.duplicate(true),
		"representative_rolls": _representative_rolls.duplicate(),
		"representative_outcome": _representative_outcome,
	}


func _next_phase_boundary() -> float:
	if _simulated_seconds < PREPARATION_END_SECONDS:
		return PREPARATION_END_SECONDS
	if _simulated_seconds < CLOSING_START_SECONDS:
		return CLOSING_START_SECONDS
	return NIGHT_END_SECONDS


func _apply_phase_boundary() -> void:
	if _simulated_seconds >= NIGHT_END_SECONDS - 0.0001 and _phase != &"results":
		_phase = &"results"
		_time_scale = 0.0
		_ordinary_visits.finish_night()
		# A safe Closing with the Capture quota met is a success; short of it, a failed operation.
		var captures: int = _ordinary_visits.snapshot()["captures"].size()
		_outcome = &"success" if captures >= CAPTURE_QUOTA else &"failed_operation"
		_outcome_cause = &"quota_met" if captures >= CAPTURE_QUOTA else &"quota_shortfall"
		_record(&"results_reached", {
			"outcome": _outcome, "cause": _outcome_cause, "captures": captures,
		})
	elif _simulated_seconds >= CLOSING_START_SECONDS - 0.0001 and _phase != &"closing":
		_phase = &"closing"
		_ordinary_visits.begin_closing()
		_record(&"closing_started")
	elif _simulated_seconds >= PREPARATION_END_SECONDS - 0.0001 and _phase == &"preparation":
		_phase = &"active_operation"
		_record(&"doors_opened")


func _advance_representative_rolls() -> void:
	while _simulated_seconds + 0.0001 >= _next_representative_roll_at:
		_representative_rolls.append(_rng.randi_range(1, 100))
		_next_representative_roll_at += REPRESENTATIVE_ROLL_INTERVAL_SECONDS
		_update_representative_outcome()


func _update_representative_outcome() -> void:
	if _representative_rolls.size() < REPRESENTATIVE_ROLLS_FOR_OUTCOME:
		return
	var favorable_rolls := 0
	for roll in _representative_rolls:
		if roll <= 50:
			favorable_rolls += 1
	_representative_outcome = &"success" if favorable_rolls >= 2 else &"failure"


func _patron_summary(visit: Dictionary) -> Dictionary:
	var arrived_count := 0
	var active_count := 0
	var departure_count := 0
	for patron_id: int in visit["debug_views"]:
		var lifecycle: StringName = visit["debug_views"][patron_id]["lifecycle"]
		if lifecycle != &"not_arrived":
			arrived_count += 1
		if lifecycle == &"active":
			active_count += 1
		elif lifecycle == &"exited":
			departure_count += 1
	return {
		"authored_count": visit["debug_views"].size(),
		"arrived_count": arrived_count,
		"active_count": active_count,
		"normal_departure_count": departure_count,
		"arrival_groups": visit["groups"].duplicate(true),
	}


func _order_summary(order_state: Dictionary) -> Dictionary:
	var served_count := 0
	var cancelled_count := 0
	var missed_count := 0
	for order_id: StringName in order_state["orders"]:
		var order: Dictionary = order_state["orders"][order_id]
		match order["state"]:
			&"served":
				served_count += 1
			&"cancelled":
				# Missed and cancelled are mutually exclusive: a failed service is
				# missed, every other terminal cancellation reason is cancelled.
				if order["terminal_reason"] == &"failed_service":
					missed_count += 1
				else:
					cancelled_count += 1
	return {
		"all": order_state["orders"].duplicate(true),
		"served_count": served_count,
		"cancelled_count": cancelled_count,
		"missed_count": missed_count,
		"revenue": order_state["revenue"],
		"tips": order_state["tips"],
	}


func _cultist_summary(visit: Dictionary) -> Dictionary:
	var summaries: Dictionary = {}
	for cultist_id in CULTIST_IDS:
		summaries[cultist_id] = {
			"activity": &"idle",
			"last_action": &"idle",
			"last_target_id": &"",
		}
	for event: Dictionary in visit["safe_autonomy"]["events"]:
		var cultist_id: int = event["cultist_id"]
		if not summaries.has(cultist_id):
			continue
		summaries[cultist_id]["activity"] = (
			&"safe_service" if _simulated_seconds - float(event["at"]) <= 15.0 else &"idle"
		)
		summaries[cultist_id]["last_action"] = event["action"]
		summaries[cultist_id]["last_target_id"] = event["target_id"]

	var drug_prep: Dictionary = visit["drug_prep"]
	if not drug_prep.is_empty():
		_set_active_cultist_summary(
			summaries, drug_prep["cultist_id"], &"preparing_drugged_drink", drug_prep["patron_id"]
		)
	var windup: Dictionary = visit["windup"]
	if not windup.is_empty():
		_set_active_cultist_summary(
			summaries, windup["cultist_id"], &"knockout_windup", windup["victim_id"]
		)
	for target_id: Variant in visit["incapacitated_cultists"]:
		_set_active_cultist_summary(summaries, target_id, &"knocked_out", &"")
	for target_id: Variant in visit["stirs"]:
		_set_active_cultist_summary(
			summaries, visit["stirs"][target_id]["helper_id"], &"stirring", target_id
		)
	for victim_id: int in visit["drags"]:
		var drag: Dictionary = visit["drags"][victim_id]
		var activity: StringName = &"body_pickup" if drag["phase"] == &"pickup" else &"dragging"
		_set_active_cultist_summary(summaries, drag["cultist_id"], activity, victim_id)
	for cultist_id: int in visit["conversations"]:
		_set_active_cultist_summary(
			summaries, cultist_id, &"conversing", visit["conversations"][cultist_id]
		)
	for patron_id: int in visit["follows"]:
		var follow: Dictionary = visit["follows"][patron_id]
		_set_active_cultist_summary(summaries, follow["cultist_id"], &"leading", patron_id)
	for victim_id: int in visit["collapses"]:
		var collapse: Dictionary = visit["collapses"][victim_id]
		if collapse["phase"] == &"persuading":
			_set_active_cultist_summary(
				summaries, collapse["acting_cultist"], &"rescue_persuasion", collapse["helper_id"]
			)
	var active_intercept: Dictionary = visit["active_intercept"]
	if not active_intercept.is_empty():
		_set_active_cultist_summary(
			summaries,
			active_intercept["cultist_id"],
			&"intercepting",
			active_intercept["patron_id"]
		)
	return summaries


func _set_active_cultist_summary(
		summaries: Dictionary,
		cultist_id: int,
		activity: StringName,
		target_id: Variant
) -> void:
	if not summaries.has(cultist_id):
		return
	summaries[cultist_id]["activity"] = activity
	summaries[cultist_id]["last_action"] = activity
	summaries[cultist_id]["last_target_id"] = target_id


func _results(orders: Dictionary, patrons: Dictionary, captures: int, visit: Dictionary) -> Dictionary:
	return {
		"visible": _phase == &"results",
		"night_seed": _night_seed,
		"outcome": _outcome,
		"outcome_cause": _outcome_cause,
		"captures": captures,
		"capture_quota": CAPTURE_QUOTA,
		"capture_methods": visit["capture_methods"],
		"revenue": orders["revenue"],
		"tips": orders["tips"],
		"orders_served": orders["served_count"],
		"orders_cancelled": orders["cancelled_count"],
		"orders_missed": orders["missed_count"],
		"groups_missed_at_door": visit["groups_missed_at_door"],
		"normal_departures": patrons["normal_departure_count"],
		"peak_suspicion": visit["peak_suspicion"],
		"peak_suspicion_band": PatronSuspicion.band_for_score(visit["peak_suspicion"]),
		"interceptions": visit["interceptions"],
		"unattended_body_seconds": visit["unattended_body_seconds"],
	}


func _reservation_count(visit: Dictionary) -> int:
	var count := 0
	for seat_id: StringName in visit["seat_owners"]:
		if int(visit["seat_owners"][seat_id]) != ActorIds.NO_ACTOR:
			count += 1
	if int(visit["bathroom_owner"]) != ActorIds.NO_ACTOR:
		count += 1
	return count


func _phase_label() -> String:
	match _phase:
		&"preparation": return "Preparation"
		&"active_operation": return "Active operation"
		&"closing": return "Closing"
		&"results": return "Results"
	return "Night"


## The clock-face reading, in minutes past midnight. The analog Night Clock and
## the clock label both come from this one number.
func clock_minutes() -> float:
	var ratio := clampf(_simulated_seconds / NIGHT_END_SECONDS, 0.0, 1.0)
	return float(CLOCK_OPENING_MINUTES) + ratio * float(
		CLOCK_CLOSING_MINUTES - CLOCK_OPENING_MINUTES
	)


func closing_label() -> String:
	return _format_clock(float(CLOCK_CLOSING_MINUTES))


func _clock_label() -> String:
	return _format_clock(clock_minutes())


static func _format_clock(minutes: float) -> String:
	var total := posmod(int(round(minutes)), 24 * 60)
	var hour: int = total / 60
	var minute: int = total % 60
	var suffix := "AM" if hour < 12 else "PM"
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minute, suffix]


func _record(event_name: StringName, details: Dictionary = {}) -> void:
	_session_events.append({
		"at": _simulated_seconds,
		"event": event_name,
		"details": details.duplicate(true),
	})


func _emit_snapshot() -> void:
	snapshot_changed.emit(snapshot())
