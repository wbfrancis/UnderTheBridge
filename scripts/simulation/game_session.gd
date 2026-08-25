class_name GameSession
extends RefCounted

signal snapshot_changed(snapshot: Dictionary)

const ORDINARY_VISIT_SESSION_SCRIPT := preload("res://scripts/simulation/ordinary_visit_session.gd")
const SUPPORTED_TIME_SCALES: Array[float] = [0.0, 1.0, 2.0, 4.0]
const CULTIST_IDS: Array[StringName] = [&"cultist_01", &"cultist_02", &"cultist_03"]
const PREPARATION_END_SECONDS := 60.0
const CLOSING_START_SECONDS := 960.0
const NIGHT_END_SECONDS := 1080.0
const CAPTURE_QUOTA := 3
const REPRESENTATIVE_ROLL_INTERVAL_SECONDS := 5.0
const REPRESENTATIVE_ROLLS_FOR_OUTCOME := 4

var _night_seed: int = 0
var _simulated_seconds: float = 0.0
var _time_scale: float = 1.0
var _phase: StringName = &"preparation"
var _outcome: StringName = &"running"
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


func report_patron_stimulus(
		patron_id: StringName,
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
		source_id: StringName = &"",
		source_position := Vector2.ZERO
) -> Array:
	var perceived: Array = _ordinary_visits.report_danger_event(
		stimulus, channel, source_room, source_id, source_position
	)
	if not perceived.is_empty():
		_record(&"danger_event_perceived", {
			"stimulus": stimulus,
			"channel": channel,
			"source": source_id if not source_id.is_empty() else source_room,
			"recipients": perceived,
		})
		_emit_snapshot()
	return perceived


func add_unattended_body(body_id: StringName, room: StringName, position := Vector2.ZERO) -> void:
	_ordinary_visits.add_unattended_body(body_id, room, position)
	_record(&"unattended_body_added", {"body_id": body_id, "room": room})
	_emit_snapshot()


func set_unattended_body_state(body_id: StringName, state: StringName) -> void:
	_ordinary_visits.set_unattended_body_state(body_id, state)
	_record(&"unattended_body_state_changed", {"body_id": body_id, "state": state})
	_emit_snapshot()


func drop_unattended_body(body_id: StringName, room: StringName, position := Vector2.ZERO) -> void:
	_ordinary_visits.drop_unattended_body(body_id, room, position)
	_record(&"unattended_body_dropped", {"body_id": body_id, "room": room})
	_emit_snapshot()


func remove_unattended_body(body_id: StringName) -> void:
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


func begin_intercept(patron_id: StringName, cultist_id: StringName) -> bool:
	var started: bool = _ordinary_visits.begin_intercept(patron_id, cultist_id)
	if started:
		_record(&"intercept_started", {"patron_id": patron_id, "cultist_id": cultist_id})
		_emit_snapshot()
	return started


func debug_force_bathroom(patron_id: StringName) -> bool:
	var forced: bool = _ordinary_visits.debug_force_bathroom(patron_id)
	if forced:
		_record(&"debug_bathroom_forced", {"patron_id": patron_id})
		_emit_snapshot()
	return forced


func serve_patron_order(patron_id: StringName, cultist_id: StringName) -> bool:
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


func offer_drink(patron_id: StringName, cultist_id: StringName, drugged: bool = false) -> Dictionary:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return {"accepted": false, "reason": &"invalid_cultist", "roll": -1.0}
	var result: Dictionary = _ordinary_visits.offer_drink(patron_id, cultist_id, drugged)
	_emit_snapshot()
	return result


func debug_set_patron_drink_state(
	patron_id: StringName,
	intoxication: int,
	overdrink_limit: int,
	excess_drinks: int = 0,
	ideal_intoxication: int = -1
) -> bool:
	return _ordinary_visits.debug_set_patron_drink_state(
		patron_id, intoxication, overdrink_limit, excess_drinks, ideal_intoxication
	)


func debug_change_patron_mood(patron_id: StringName, amount: float) -> bool:
	return _ordinary_visits.debug_change_patron_mood(patron_id, amount)


func debug_force_finish_drink(patron_id: StringName) -> bool:
	return _ordinary_visits.debug_force_finish_drink(patron_id)


func set_physical_patron_navigation_enabled(enabled: bool) -> void:
	_ordinary_visits.set_physical_navigation_enabled(enabled)


func patron_destination_reached(patron_id: StringName) -> bool:
	var reached := _ordinary_visits.patron_destination_reached(patron_id)
	if reached:
		_emit_snapshot()
	return reached


func patron_view(patron_id: StringName, selected_cultist_id: StringName) -> Dictionary:
	return _ordinary_visits.normal_patron_view(patron_id, selected_cultist_id)


func prepare_drugged_drink(patron_id: StringName, cultist_id: StringName) -> bool:
	if _phase == &"results":
		return false
	var prepared: bool = _ordinary_visits.prepare_drugged_drink(patron_id, cultist_id)
	if prepared:
		_record(&"drugged_drink_prepared", {"patron_id": patron_id, "cultist_id": cultist_id})
		_emit_snapshot()
	return prepared


func attempt_rescue_persuasion(cultist_id: StringName) -> bool:
	var chance := _ordinary_visits.rescue_persuasion_chance(cultist_id)
	var attempted: bool = _ordinary_visits.attempt_rescue_persuasion(cultist_id)
	if attempted:
		_record(&"rescue_persuasion_attempted", {"cultist_id": cultist_id, "chance": chance})
		_emit_snapshot()
	return attempted


func rescue_persuasion_chance(cultist_id: StringName) -> float:
	return _ordinary_visits.rescue_persuasion_chance(cultist_id)


func begin_knockout(cultist_id: StringName, victim_id: StringName) -> bool:
	if _phase == &"results":
		return false
	var started: bool = _ordinary_visits.begin_knockout(cultist_id, victim_id)
	if started:
		_record(&"knockout_windup_started", {"cultist_id": cultist_id, "victim_id": victim_id})
		_emit_snapshot()
	return started


func cancel_knockout(cultist_id: StringName) -> bool:
	var cancelled: bool = _ordinary_visits.cancel_knockout(cultist_id)
	if cancelled:
		_record(&"knockout_windup_cancelled", {"cultist_id": cultist_id})
		_emit_snapshot()
	return cancelled


func pick_up_body(cultist_id: StringName, victim_id: StringName) -> bool:
	if _phase == &"results":
		return false
	var picked: bool = _ordinary_visits.pick_up_body(cultist_id, victim_id)
	if picked:
		_record(&"body_pickup_started", {"cultist_id": cultist_id, "victim_id": victim_id})
		_emit_snapshot()
	return picked


func drop_body(cultist_id: StringName) -> bool:
	var dropped: bool = _ordinary_visits.drop_body(cultist_id)
	if dropped:
		_record(&"body_dropped", {"cultist_id": cultist_id})
		_emit_snapshot()
	return dropped


func is_cultist_busy(cultist_id: StringName) -> bool:
	return _ordinary_visits.is_cultist_busy(cultist_id)


func offer_cigarette(cultist_id: StringName, patron_id: StringName) -> bool:
	if _phase == &"results":
		return false
	var offered: bool = _ordinary_visits.offer_cigarette(cultist_id, patron_id)
	if offered:
		_record(&"cigarette_offered", {"cultist_id": cultist_id, "patron_id": patron_id})
		_emit_snapshot()
	return offered


func begin_conversation(cultist_id: StringName, patron_id: StringName) -> bool:
	if _phase == &"results":
		return false
	var started: bool = _ordinary_visits.begin_conversation(cultist_id, patron_id)
	if started:
		_record(&"conversation_started", {"cultist_id": cultist_id, "patron_id": patron_id})
		_emit_snapshot()
	return started


func end_conversation(cultist_id: StringName) -> bool:
	var ended: bool = _ordinary_visits.end_conversation(cultist_id)
	if ended:
		_record(&"conversation_ended", {"cultist_id": cultist_id})
		_emit_snapshot()
	return ended


func begin_friendship_capture(cultist_id: StringName, patron_id: StringName) -> bool:
	if _phase == &"results":
		return false
	var started: bool = _ordinary_visits.begin_friendship_capture(cultist_id, patron_id)
	if started:
		_record(&"friendship_capture_started", {"cultist_id": cultist_id, "patron_id": patron_id})
		_emit_snapshot()
	return started


func friendship_value(patron_id: StringName, cultist_id: StringName) -> float:
	return _ordinary_visits.friendship_value(patron_id, cultist_id)


func friendship_band(patron_id: StringName, cultist_id: StringName) -> String:
	return _ordinary_visits.friendship_band(patron_id, cultist_id)


func stay_behind_chance(patron_id: StringName) -> float:
	return _ordinary_visits.stay_behind_chance(patron_id)


# --- Emote information-safety seam -------------------------------------------

# The only projection the Emote system may read. Patron rows come from normal
# Patron views; Cultist rows come from the unified command summary when the
# adapter supplies one, and from the session's public activity otherwise.
# Nothing hidden crosses this seam, so no bubble can leak a simulation value.
func emote_view(cultist_commands: Dictionary = {}) -> Dictionary:
	var visit: Dictionary = _ordinary_visits.snapshot()
	var rows: Dictionary = {}
	for patron_id: StringName in visit["debug_views"]:
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
		elif cultist_commands.has(cultist_id):
			state = _command_emote_state(cultist_commands[cultist_id])
		elif activity != &"idle":
			state = &"cultist_action"
		var changes: Array[StringName] = []
		if cultist_commands.has(cultist_id):
			var outcome: StringName = StringName(
				cultist_commands[cultist_id]["feedback"]["outcome"]
			)
			if outcome in [&"completed", &"failed", &"rejected"]:
				changes.append(&"command_result")
		rows[cultist_id] = {
			"id": cultist_id,
			"kind": &"cultist",
			"present": true,
			"state": state,
			"changes": changes,
			"public": {"activity": String(activity).replace("_", " ").capitalize()},
		}
	return rows


# Ordinary Move needs no bubble: its destination marker already communicates it.
func _command_emote_state(command_summary: Dictionary) -> StringName:
	var active: Dictionary = command_summary["active"]
	if active.is_empty() or active["command"] == &"move":
		return &"none"
	return &"cultist_action"


# --- Cultist command seam ----------------------------------------------------
# CultistCommandSystem owns the Action Queue and the Commitment Point; the rules
# behind each command stay here, in the gameplay authority.

func command_availability(
		command: StringName,
		cultist_id: StringName,
		target_id: StringName
) -> Dictionary:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return {"visible": false, "available": false, "reason": &"night_over", "detail": ""}
	return _ordinary_visits.command_availability(command, cultist_id, target_id)


func prepare_drink(cultist_id: StringName) -> bool:
	if _phase == &"results" or cultist_id not in CULTIST_IDS:
		return false
	var prepared: bool = _ordinary_visits.prepare_drink(cultist_id)
	if prepared:
		_record(&"prepared_drink_taken", {"cultist_id": cultist_id})
		_emit_snapshot()
	return prepared


func carries_prepared_drink(cultist_id: StringName) -> bool:
	return _ordinary_visits.carries_prepared_drink(cultist_id)


func prepare_drugged_drink_for_next_order(cultist_id: StringName) -> bool:
	if _phase == &"results":
		return false
	var prepared: bool = _ordinary_visits.prepare_drugged_drink_for_next_order(cultist_id)
	if prepared:
		_record(&"drugged_drink_prepared", {"cultist_id": cultist_id})
		_emit_snapshot()
	return prepared


func end_cultist_engagement(cultist_id: StringName) -> bool:
	var ended: bool = _ordinary_visits.end_cultist_engagement(cultist_id)
	if ended:
		_record(&"conversation_ended", {"cultist_id": cultist_id})
		_emit_snapshot()
	return ended


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
	_ordinary_visits.finish_night()
	_record(&"results_reached", {"outcome": _outcome})


func snapshot() -> Dictionary:
	var visit: Dictionary = _ordinary_visits.snapshot()
	var patrons := _patron_summary(visit)
	var orders := _order_summary(visit["orders"])
	var captures: Array = visit["captures"]
	return {
		"night_seed": _night_seed,
		"simulated_seconds": _simulated_seconds,
		"time_scale": _time_scale,
		"phase": _phase,
		"phase_label": _phase_label(),
		"clock_label": _clock_label(),
		"outcome": _outcome,
		"captures": captures.size(),
		"capture_log": captures.duplicate(true),
		"defeat": visit["defeat"],
		"trapdoor": visit["trapdoor"],
		"active_intercept": visit["active_intercept"],
		"escaping_patrons": visit["escaping_patrons"],
		"doses_remaining": visit["doses_remaining"],
		"drug_prep": visit["drug_prep"],
		"collapses": visit["collapses"],
		"windup": visit["windup"],
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
			"prepared_drinks": 0,
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
		_record(&"results_reached", {"outcome": _outcome, "captures": captures})
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
	for patron_id: StringName in visit["debug_views"]:
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
	for order_id: StringName in order_state["orders"]:
		match order_state["orders"][order_id]["state"]:
			&"served": served_count += 1
			&"cancelled": cancelled_count += 1
	return {
		"all": order_state["orders"].duplicate(true),
		"served_count": served_count,
		"cancelled_count": cancelled_count,
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
		var cultist_id: StringName = event["cultist_id"]
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
	for victim_id: StringName in visit["drags"]:
		var drag: Dictionary = visit["drags"][victim_id]
		var activity: StringName = &"body_pickup" if drag["phase"] == &"pickup" else &"dragging"
		_set_active_cultist_summary(summaries, drag["cultist_id"], activity, victim_id)
	for cultist_id: StringName in visit["conversations"]:
		_set_active_cultist_summary(
			summaries, cultist_id, &"conversing", visit["conversations"][cultist_id]
		)
	for patron_id: StringName in visit["follows"]:
		var follow: Dictionary = visit["follows"][patron_id]
		_set_active_cultist_summary(summaries, follow["cultist_id"], &"leading", patron_id)
	for victim_id: StringName in visit["collapses"]:
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
		cultist_id: StringName,
		activity: StringName,
		target_id: StringName
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
		"captures": captures,
		"capture_quota": CAPTURE_QUOTA,
		"capture_methods": visit["capture_methods"],
		"revenue": orders["revenue"],
		"tips": orders["tips"],
		"orders_served": orders["served_count"],
		"orders_cancelled": orders["cancelled_count"],
		"normal_departures": patrons["normal_departure_count"],
		"peak_suspicion": visit["peak_suspicion"],
		"interceptions": visit["interceptions"],
		"unattended_body_seconds": visit["unattended_body_seconds"],
	}


func _reservation_count(visit: Dictionary) -> int:
	var count := 0
	for seat_id: StringName in visit["seat_owners"]:
		if not StringName(visit["seat_owners"][seat_id]).is_empty():
			count += 1
	if not StringName(visit["bathroom_owner"]).is_empty():
		count += 1
	return count


func _phase_label() -> String:
	match _phase:
		&"preparation": return "Preparation"
		&"active_operation": return "Active operation"
		&"closing": return "Closing"
		&"results": return "Results"
	return "Night"


func _clock_label() -> String:
	var total_seconds := 18 * 60 * 60 + 59 * 60 + int(_simulated_seconds)
	var hour := total_seconds / 3600
	var minute := (total_seconds / 60) % 60
	var suffix := "PM"
	if hour > 12:
		hour -= 12
	return "%d:%02d %s" % [hour, minute, suffix]


func _record(event_name: StringName, details: Dictionary = {}) -> void:
	_session_events.append({
		"at": _simulated_seconds,
		"event": event_name,
		"details": details.duplicate(true),
	})


func _emit_snapshot() -> void:
	snapshot_changed.emit(snapshot())
