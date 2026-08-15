class_name BathroomDangerScenario
extends RefCounted

const INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")

const BATHROOM_SLOT := &"bathroom_occupant"
const QUEUE_SLOTS: Array[StringName] = [&"bathroom_queue_01", &"bathroom_queue_02"]
const INVESTIGATION_WAIT_SLOT := &"bathroom_investigation_wait"
const FRONT_EXIT_SLOT := &"front_exit"
const INTERCEPT_SLOT := &"intercept_position"

const STANDING_ENTRY_SECONDS := 2.0
const SEATED_USE_SECONDS := 8.0
const STANDING_EXIT_SECONDS := 3.0
const TRAPDOOR_OPEN_SECONDS := 2.0
const TRAPDOOR_COOLDOWN_SECONDS := 3.0
const INVESTIGATION_SECONDS := 5.0
const ESCAPE_SHOCK_SECONDS := 2.0
const ESCAPE_TRAVEL_SECONDS := 6.0
const INTERCEPT_SECONDS := 5.0
const STEP_SECONDS := 0.05
const TIME_EPSILON := 0.0001

var _seed: int = 0
var _simulated_seconds: float = 0.0
var _time_scale: float = 1.0
var _rng := RandomNumberGenerator.new()
var _registry = INTERACTION_REGISTRY_SCRIPT.new()
var _patrons: Dictionary = {}
var _queue: Array[StringName] = []
var _occupant_id: StringName = &""
var _pending_investigator_id: StringName = &""
var _trapdoor_state: StringName = &"closed"
var _trapdoor_remaining: float = 0.0
var _trapdoor_eligible_occupant: StringName = &""
var _active_intercept: Dictionary = {}
var _defeat: bool = false
var _recent_rolls: Array[Dictionary] = []
var _recent_events: Array[Dictionary] = []


func start(seed: int) -> void:
	_seed = seed
	_simulated_seconds = 0.0
	_time_scale = 1.0
	_rng.seed = seed
	_patrons.clear()
	_queue.clear()
	_occupant_id = &""
	_pending_investigator_id = &""
	_trapdoor_state = &"closed"
	_trapdoor_remaining = 0.0
	_trapdoor_eligible_occupant = &""
	_active_intercept.clear()
	_defeat = false
	_recent_rolls.clear()
	_recent_events.clear()
	_registry = INTERACTION_REGISTRY_SCRIPT.new()
	_registry.register_slot(BATHROOM_SLOT, &"bathroom")
	for slot_id in QUEUE_SLOTS:
		_registry.register_slot(slot_id, &"bathroom_queue")
	_registry.register_slot(INVESTIGATION_WAIT_SLOT, &"investigation_wait")
	_registry.register_slot(FRONT_EXIT_SLOT, &"front_exit")
	_registry.register_slot(INTERCEPT_SLOT, &"intercept")


func restart(seed: int = _seed) -> void:
	start(seed)


func add_patron(
	patron_id: StringName,
	bladder: float,
	max_drunk: bool = false,
	companion_id: StringName = &""
) -> bool:
	if patron_id.is_empty() or _patrons.has(patron_id):
		return false
	_patrons[patron_id] = {
		"id": patron_id,
		"lifecycle": &"active",
		"activity": &"normal",
		"phase_remaining": 0.0,
		"bladder": clampf(bladder, 0.0, 100.0),
		"max_drunk": max_drunk,
		"suspicion": 0.0,
		"suspicion_cause": &"none",
		"companion_id": companion_id,
		"missing_target": &"",
		"missing_seconds": 0.0,
		"missing_20_applied": false,
		"missing_30_applied": false,
		"missing_40_applied": false,
		"defer_remaining": 0.0,
		"escape_remaining": ESCAPE_TRAVEL_SECONDS,
		"intercept_attempted": false,
		"escape_after_bathroom": false,
	}
	return true


func bathroom_choice_probability(patron_id: StringName) -> float:
	if not _patrons.has(patron_id):
		return 0.0
	var bladder: float = _patrons[patron_id]["bladder"]
	if bladder < 50.0:
		return 0.0
	return clampf(1.0 + 89.0 * ((bladder - 50.0) / 50.0), 1.0, 90.0)


func check_bathroom_choice(patron_id: StringName) -> bool:
	if not _is_bathroom_choice_eligible(patron_id):
		return false
	var chance := bathroom_choice_probability(patron_id)
	if chance <= 0.0:
		return false
	var roll := _rng.randf_range(0.0, 100.0)
	_recent_rolls.append({"patron_id": patron_id, "roll": roll, "chance": chance})
	if roll > chance:
		_record_event(&"bathroom_choice_rejected", patron_id)
		return false
	_record_event(&"bathroom_choice_selected", patron_id)
	return _request_bathroom(patron_id)


func force_bathroom_intent(patron_id: StringName) -> bool:
	if not _is_bathroom_choice_eligible(patron_id):
		return false
	_record_event(&"bathroom_intent_forced", patron_id)
	return _request_bathroom(patron_id)


func activate_trapdoor() -> bool:
	if _trapdoor_state != &"closed":
		return false
	_trapdoor_state = &"open"
	_trapdoor_remaining = TRAPDOOR_OPEN_SECONDS
	_trapdoor_eligible_occupant = _occupant_id
	_record_event(&"trapdoor_opened", _occupant_id)
	if _occupant_id.is_empty():
		return true
	var patron: Dictionary = _patrons[_occupant_id]
	if _is_standing_activity(patron["activity"]):
		_capture_occupant(&"trapdoor")
	elif patron["activity"] == &"seated_use":
		_apply_seated_hard_evidence(_occupant_id)
	return true


func begin_intercept(patron_id: StringName, cultist_id: StringName) -> bool:
	if not _patrons.has(patron_id) or cultist_id.is_empty() or not _active_intercept.is_empty():
		return false
	var patron: Dictionary = _patrons[patron_id]
	if patron["lifecycle"] != &"escaping" or patron["activity"] != &"escaping":
		return false
	if patron["intercept_attempted"] or not _registry.request_slot(cultist_id, INTERCEPT_SLOT):
		return false
	patron["intercept_attempted"] = true
	patron["activity"] = &"intercepted"
	_active_intercept = {
		"patron_id": patron_id,
		"cultist_id": cultist_id,
		"remaining": INTERCEPT_SECONDS,
	}
	_record_event(&"intercept_started", patron_id, {"cultist_id": cultist_id})
	return true


func cancel_intercept() -> bool:
	if _active_intercept.is_empty():
		return false
	var patron_id: StringName = _active_intercept["patron_id"]
	var cultist_id: StringName = _active_intercept["cultist_id"]
	_registry.release_actor(cultist_id)
	_active_intercept.clear()
	if _patrons.has(patron_id) and _patrons[patron_id]["lifecycle"] == &"escaping":
		_patrons[patron_id]["activity"] = &"escaping"
	_record_event(&"intercept_cancelled", patron_id)
	return true


func cancel_actor(actor_id: StringName) -> bool:
	if actor_id.is_empty():
		return false
	if not _active_intercept.is_empty() and _active_intercept["cultist_id"] == actor_id:
		return cancel_intercept()
	if actor_id == _occupant_id:
		_cancel_occupant(actor_id)
		return true
	var queue_index := _queue.find(actor_id)
	if queue_index >= 0:
		_queue.remove_at(queue_index)
		_registry.release_actor(actor_id)
		_shift_queue_reservations()
		_set_cancelled(actor_id)
		return true
	if actor_id == _pending_investigator_id:
		_pending_investigator_id = &""
		_registry.release_actor(actor_id)
		_set_cancelled(actor_id)
		return true
	if _patrons.has(actor_id) and _registry.actor_slot(actor_id) == FRONT_EXIT_SLOT:
		_registry.release_actor(actor_id)
		_set_cancelled(actor_id)
		return true
	return false


func advance(simulated_seconds: float) -> void:
	if simulated_seconds <= 0.0:
		return
	var remaining := simulated_seconds
	while remaining > 0.0001:
		var step := minf(STEP_SECONDS, remaining)
		_simulated_seconds += step
		_advance_deferred(step)
		_advance_occupant(step)
		_advance_trapdoor(step)
		_advance_missing_companions(step)
		_advance_escape(step)
		remaining -= step


func snapshot() -> Dictionary:
	return {
		"seed": _seed,
		"simulated_seconds": _simulated_seconds,
		"time_scale": _time_scale,
		"patrons": _patrons.duplicate(true),
		"occupant_id": _occupant_id,
		"queue": _queue.duplicate(),
		"pending_investigator_id": _pending_investigator_id,
		"trapdoor_state": _trapdoor_state,
		"trapdoor_remaining": _trapdoor_remaining,
		"trapdoor_eligible_occupant": _trapdoor_eligible_occupant,
		"active_intercept": _active_intercept.duplicate(true),
		"defeat": _defeat,
		"recent_rolls": _recent_rolls.duplicate(true),
		"recent_events": _recent_events.duplicate(true),
		"registry": _registry.snapshot(),
		"ownership_clean": _ownership_is_clean(),
	}


func _request_bathroom(patron_id: StringName) -> bool:
	if _occupant_id.is_empty() and _pending_investigator_id.is_empty():
		return _occupy_standard_patron(patron_id)
	if _queue.size() < QUEUE_SLOTS.size():
		var slot_id: StringName = QUEUE_SLOTS[_queue.size()]
		if not _registry.request_slot(patron_id, slot_id):
			return false
		_queue.append(patron_id)
		_patrons[patron_id]["activity"] = &"bathroom_queue"
		_record_event(&"bathroom_queued", patron_id, {"slot_id": slot_id})
		return true
	_patrons[patron_id]["activity"] = &"bathroom_deferred"
	_patrons[patron_id]["defer_remaining"] = 10.0
	_record_event(&"bathroom_deferred", patron_id)
	return true


func _occupy_standard_patron(patron_id: StringName) -> bool:
	_registry.release_actor(patron_id)
	if not _registry.request_slot(patron_id, BATHROOM_SLOT):
		return false
	_occupant_id = patron_id
	var patron: Dictionary = _patrons[patron_id]
	patron["activity"] = &"standing_entry"
	patron["phase_remaining"] = STANDING_ENTRY_SECONDS
	_start_missing_companion_clock(patron_id)
	_record_event(&"bathroom_entered", patron_id)
	return true


func _occupy_investigator(patron_id: StringName) -> bool:
	_registry.release_actor(patron_id)
	if not _registry.request_slot(patron_id, BATHROOM_SLOT):
		return false
	_pending_investigator_id = &""
	_occupant_id = patron_id
	var patron: Dictionary = _patrons[patron_id]
	patron["lifecycle"] = &"investigating"
	patron["activity"] = &"investigation_search"
	patron["phase_remaining"] = INVESTIGATION_SECONDS
	_record_event(&"investigation_started", patron_id)
	return true


func _advance_occupant(delta: float) -> void:
	if _occupant_id.is_empty() or not _patrons.has(_occupant_id):
		return
	var patron: Dictionary = _patrons[_occupant_id]
	patron["phase_remaining"] = maxf(0.0, float(patron["phase_remaining"]) - delta)
	if patron["phase_remaining"] > 0.0001:
		return
	match patron["activity"]:
		&"standing_entry":
			patron["activity"] = &"seated_use"
			patron["phase_remaining"] = SEATED_USE_SECONDS
			_record_event(&"bathroom_seated", _occupant_id)
		&"seated_use":
			patron["bladder"] = 0.0
			patron["activity"] = &"standing_exit"
			patron["phase_remaining"] = STANDING_EXIT_SECONDS
			_record_event(&"bathroom_use_completed", _occupant_id)
		&"standing_exit":
			_complete_bathroom_visit()
		&"investigation_search":
			_begin_escape(_occupant_id)


func _advance_trapdoor(delta: float) -> void:
	if _trapdoor_state == &"closed":
		return
	_trapdoor_remaining = maxf(0.0, _trapdoor_remaining - delta)
	if (
		_trapdoor_state == &"open"
		and not _occupant_id.is_empty()
		and _occupant_id == _trapdoor_eligible_occupant
		and _is_standing_activity(_patrons[_occupant_id]["activity"])
	):
		_capture_occupant(&"trapdoor")
	if _trapdoor_remaining > 0.0001:
		return
	if _trapdoor_state == &"open":
		_trapdoor_state = &"cooldown"
		_trapdoor_remaining = TRAPDOOR_COOLDOWN_SECONDS
		_trapdoor_eligible_occupant = &""
		_record_event(&"trapdoor_cooldown")
	else:
		_trapdoor_state = &"closed"
		_trapdoor_remaining = 0.0
		_record_event(&"trapdoor_ready")


func _advance_deferred(delta: float) -> void:
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["activity"] != &"bathroom_deferred":
			continue
		patron["defer_remaining"] = maxf(0.0, float(patron["defer_remaining"]) - delta)
		if patron["defer_remaining"] <= 0.0001:
			patron["activity"] = &"normal"
			_request_bathroom(patron_id)


func _advance_missing_companions(delta: float) -> void:
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if StringName(patron["missing_target"]).is_empty() or patron["missing_40_applied"]:
			continue
		patron["missing_seconds"] = float(patron["missing_seconds"]) + delta
		var missing_seconds: float = patron["missing_seconds"]
		if missing_seconds >= 20.0 - TIME_EPSILON and not patron["missing_20_applied"]:
			patron["missing_20_applied"] = true
			_apply_suspicion(patron_id, 25.0, &"missing_companion")
			_record_event(&"missing_companion_20", patron_id)
		if missing_seconds >= 30.0 - TIME_EPSILON and not patron["missing_30_applied"]:
			patron["missing_30_applied"] = true
			_apply_suspicion(patron_id, 25.0, &"missing_companion")
			_record_event(&"missing_companion_30", patron_id)
		if missing_seconds >= 40.0 - TIME_EPSILON and not patron["missing_40_applied"]:
			patron["missing_40_applied"] = true
			patron["suspicion"] = 100.0
			patron["suspicion_cause"] = &"missing_companion"
			_record_event(&"missing_companion_40", patron_id)
			_request_investigation(patron_id)


func _advance_escape(delta: float) -> void:
	if not _active_intercept.is_empty():
		_active_intercept["remaining"] = maxf(
			0.0, float(_active_intercept["remaining"]) - delta
		)
		if _active_intercept["remaining"] <= 0.0001:
			var intercepted_patron: StringName = _active_intercept["patron_id"]
			var cultist_id: StringName = _active_intercept["cultist_id"]
			_registry.release_actor(cultist_id)
			_active_intercept.clear()
			if _patrons.has(intercepted_patron):
				_patrons[intercepted_patron]["activity"] = &"escaping"
			_record_event(&"intercept_completed", intercepted_patron)
		return

	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["lifecycle"] != &"escaping":
			continue
		if patron["activity"] == &"shock":
			patron["phase_remaining"] = maxf(0.0, float(patron["phase_remaining"]) - delta)
			if patron["phase_remaining"] <= 0.0001:
				patron["activity"] = &"escaping"
				_record_event(&"escape_started", patron_id)
			continue
		if patron["activity"] != &"escaping":
			continue
		patron["escape_remaining"] = maxf(0.0, float(patron["escape_remaining"]) - delta)
		if patron["escape_remaining"] <= 0.0001:
			patron["lifecycle"] = &"exited"
			patron["activity"] = &"escaped"
			_defeat = true
			_registry.release_actor(patron_id)
			_record_event(&"defeat", patron_id)


func _request_investigation(patron_id: StringName) -> void:
	var patron: Dictionary = _patrons[patron_id]
	patron["lifecycle"] = &"investigating"
	if _occupant_id.is_empty():
		_occupy_investigator(patron_id)
		return
	_pending_investigator_id = patron_id
	patron["activity"] = &"waiting_investigation"
	_registry.request_slot(patron_id, INVESTIGATION_WAIT_SLOT)
	_record_event(&"investigation_waiting", patron_id)


func _begin_escape(patron_id: StringName) -> void:
	_registry.release_actor(patron_id)
	_occupant_id = &""
	var patron: Dictionary = _patrons[patron_id]
	patron["lifecycle"] = &"escaping"
	patron["activity"] = &"shock"
	patron["phase_remaining"] = ESCAPE_SHOCK_SECONDS
	patron["escape_remaining"] = ESCAPE_TRAVEL_SECONDS
	_time_scale = 1.0
	_registry.request_slot(patron_id, FRONT_EXIT_SLOT)
	_record_event(&"escape_shock", patron_id)
	_promote_next_bathroom_user()


func _capture_occupant(cause: StringName) -> void:
	if _occupant_id.is_empty():
		return
	var captured_id := _occupant_id
	var patron: Dictionary = _patrons[captured_id]
	patron["lifecycle"] = &"captured"
	patron["activity"] = &"captured"
	patron["phase_remaining"] = 0.0
	patron["missing_target"] = &""
	_registry.release_actor(captured_id)
	_occupant_id = &""
	_record_event(&"capture", captured_id, {"cause": cause})
	_promote_next_bathroom_user()


func _complete_bathroom_visit() -> void:
	var completed_id := _occupant_id
	_registry.release_actor(completed_id)
	_occupant_id = &""
	var patron: Dictionary = _patrons[completed_id]
	patron["phase_remaining"] = 0.0
	_clear_missing_companion_clock(completed_id)
	_record_event(&"bathroom_visit_completed", completed_id)
	if patron["escape_after_bathroom"]:
		patron["escape_after_bathroom"] = false
		_begin_escape(completed_id)
		return
	patron["activity"] = &"normal"
	_promote_next_bathroom_user()


func _cancel_occupant(actor_id: StringName) -> void:
	_registry.release_actor(actor_id)
	_occupant_id = &""
	_set_cancelled(actor_id)
	_clear_missing_companion_clock(actor_id)
	_record_event(&"bathroom_cancelled", actor_id)
	_promote_next_bathroom_user()


func _promote_next_bathroom_user() -> void:
	if not _pending_investigator_id.is_empty():
		var investigator_id := _pending_investigator_id
		_occupy_investigator(investigator_id)
		return
	if _queue.is_empty():
		return
	var next_id: StringName = _queue.pop_front()
	_registry.release_actor(next_id)
	_shift_queue_reservations()
	_occupy_standard_patron(next_id)


func _shift_queue_reservations() -> void:
	for patron_id in _queue:
		_registry.release_actor(patron_id)
	for index in range(_queue.size()):
		_registry.request_slot(_queue[index], QUEUE_SLOTS[index])


func _start_missing_companion_clock(missing_patron_id: StringName) -> void:
	var companion_id: StringName = _patrons[missing_patron_id]["companion_id"]
	if companion_id.is_empty() or not _patrons.has(companion_id):
		return
	var companion: Dictionary = _patrons[companion_id]
	companion["missing_target"] = missing_patron_id
	companion["missing_seconds"] = 0.0
	companion["missing_20_applied"] = false
	companion["missing_30_applied"] = false
	companion["missing_40_applied"] = false
	_record_event(&"companion_missing_started", companion_id, {"target_id": missing_patron_id})


func _clear_missing_companion_clock(returned_patron_id: StringName) -> void:
	for patron_id: StringName in _patrons:
		var patron: Dictionary = _patrons[patron_id]
		if patron["missing_target"] != returned_patron_id:
			continue
		patron["missing_target"] = &""
		patron["missing_seconds"] = 0.0
		_record_event(&"companion_returned", patron_id, {"target_id": returned_patron_id})


func _apply_seated_hard_evidence(patron_id: StringName) -> void:
	var patron: Dictionary = _patrons[patron_id]
	if patron["max_drunk"]:
		_apply_suspicion(patron_id, 25.0, &"soft")
		_record_event(&"hard_evidence_downgraded", patron_id)
	else:
		patron["suspicion"] = 100.0
		patron["suspicion_cause"] = &"hard_evidence"
		patron["escape_after_bathroom"] = true
		_record_event(&"hard_evidence", patron_id)


func _apply_suspicion(patron_id: StringName, amount: float, cause: StringName) -> void:
	var patron: Dictionary = _patrons[patron_id]
	patron["suspicion"] = minf(100.0, float(patron["suspicion"]) + amount)
	patron["suspicion_cause"] = cause


func _set_cancelled(actor_id: StringName) -> void:
	if not _patrons.has(actor_id):
		return
	var patron: Dictionary = _patrons[actor_id]
	patron["lifecycle"] = &"active"
	patron["activity"] = &"cancelled"
	patron["phase_remaining"] = 0.0
	patron["escape_after_bathroom"] = false


func _is_bathroom_choice_eligible(patron_id: StringName) -> bool:
	if not _patrons.has(patron_id):
		return false
	var patron: Dictionary = _patrons[patron_id]
	return patron["lifecycle"] == &"active" and patron["activity"] == &"normal"


func _is_standing_activity(activity: StringName) -> bool:
	return activity in [&"standing_entry", &"standing_exit", &"investigation_search"]


func _ownership_is_clean() -> bool:
	var registry_snapshot: Dictionary = _registry.snapshot()
	return (
		_occupant_id.is_empty()
		and _queue.is_empty()
		and _pending_investigator_id.is_empty()
		and _active_intercept.is_empty()
		and registry_snapshot["actor_slots"].is_empty()
		and registry_snapshot["invariant_violations"].is_empty()
	)


func _record_event(
	event_name: StringName,
	actor_id: StringName = &"",
	details: Dictionary = {}
) -> void:
	_recent_events.append({
		"at": _simulated_seconds,
		"event": event_name,
		"actor_id": actor_id,
		"details": details.duplicate(true),
	})
	if _recent_events.size() > 40:
		_recent_events.pop_front()
