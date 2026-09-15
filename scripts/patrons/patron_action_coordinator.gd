class_name PatronActionCoordinator
extends RefCounted

## Converts PatronIntentPlanner decisions into the shared character queue. This
## is the sole Patron Action lifecycle adapter used by the simulation.

const PLANNER_SCRIPT := preload("res://scripts/patrons/patron_intent_planner.gd")

var _patron_id: int
var _registry = null
var _actions = null
var _queue = null
var _planner = PLANNER_SCRIPT.new()
var _events: Array[Dictionary] = []
var _hold_position: Variant = null
var _idle_state: StringName = &"not_arrived"
var _suppressed_incidents: Dictionary = {}


func _init(
	patron_id: int,
	registry,
	actions,
	initial_state: StringName = &"not_arrived"
) -> void:
	_patron_id = patron_id
	_registry = registry
	_actions = actions
	if not _actions.has_actor(patron_id):
		_actions.register_actor(patron_id, &"patron")
	_queue = _actions.queue_for_coordinator(patron_id)
	_activate(initial_state, &"", &"", false)


func submit(
	requested_state: StringName,
	destination: StringName = &"",
	reservation: StringName = &"",
	requires_movement: bool = false
) -> Dictionary:
	var current := _state()
	var decision := _planner.decide(current, requested_state)
	if decision == PLANNER_SCRIPT.ACCEPT and not _can_take_reservation(reservation):
		decision = PLANNER_SCRIPT.REJECT
	var result := {
		"decision": decision, "from": current, "to": requested_state,
		"reason": _reason_for(decision),
	}
	_events.append(result.duplicate(true))
	var intent := {
		"state": requested_state, "destination": destination,
		"reservation": reservation, "requires_movement": requires_movement,
	}
	if decision == PLANNER_SCRIPT.DEFER:
		_planner.defer(intent)
	elif decision == PLANNER_SCRIPT.ACCEPT:
		_activate(requested_state, destination, reservation, requires_movement)
	return result


## The goal executor owns these actions; the legacy transition table must not
## defer an emergency behind a bathroom phase. Terminal/capture guards remain.
func activate_goal_action(state: StringName, destination: StringName, reservation: StringName,
		requires_movement: bool, duration: float) -> bool:
	if PLANNER_SCRIPT.STATE_CLASS.get(_state(), &"") in [&"incapacitated", &"capturing", &"terminal"]:
		return false
	if not _can_take_reservation(reservation):
		return false
	_planner.clear()
	_activate(state, destination, reservation, requires_movement)
	configure_timing(duration)
	return true


func complete_committed(
	fallback_state: StringName,
	fallback_destination: StringName = &"",
	fallback_reservation: StringName = &"",
	fallback_requires_movement: bool = false
) -> Dictionary:
	var next := _planner.take_highest()
	if next.is_empty():
		return submit(
			fallback_state, fallback_destination, fallback_reservation,
			fallback_requires_movement
		)
	var from := _state()
	_activate(next["state"], next["destination"], next["reservation"], next["requires_movement"])
	var result := {
		"decision": PLANNER_SCRIPT.ACCEPT, "from": from, "to": next["state"],
		"reason": &"committed_phase_completed",
	}
	_events.append(result.duplicate(true))
	return result


func advance(simulated_seconds: float) -> void:
	if simulated_seconds > 0.0:
		_queue.advance_clock(simulated_seconds)


func configure_timing(duration: float) -> void:
	_queue.configure_active_timing(duration, duration)


func force_ready() -> bool:
	if _active().is_empty():
		return false
	_queue.force_active_ready()
	report_navigation_arrival()
	return true


func cancel(action_id: int, fallback: StringName, clear_queue: bool = false, current_position: Variant = null) -> bool:
	var active := _active()
	if active.is_empty():
		return false
	if StringName(active["name"]) == &"step_aside" and (clear_queue or int(active["id"]) == action_id):
		_suppressed_incidents[StringName(active["target_id"])] = true
		_hold_position = current_position
	if clear_queue:
		_actions.clear(_patron_id, true)
	else:
		var result: Dictionary = _actions.cancel(_patron_id, action_id, true)
		if not bool(result["cancelled"]):
			return false
	_idle_state = fallback
	if _active().is_empty() and _registry != null:
		_registry.release_actor(_patron_id)
	return true


func has_action() -> bool:
	return not _active().is_empty()


func report_navigation_arrival() -> bool:
	var action := _active()
	if action.is_empty() or bool(action["payload"].get("navigation_arrived", true)):
		return false
	if StringName(action["name"]) == &"step_aside":
		_hold_position = action["payload"]["target"]["position"]
		_queue.complete_active()
		_events.append({"event": &"navigation_arrived", "state": &"step_aside"})
		return true
	_queue.set_payload_value(int(action["id"]), "navigation_arrived", true)
	_events.append({"event": &"navigation_arrived", "state": _state()})
	return true


func report_navigation_failure() -> bool:
	var action := _active()
	if action.is_empty() or bool(action["payload"].get("navigation_arrived", true)):
		return false
	_queue.set_payload_value(int(action["id"]), "navigation_arrived", true)
	_events.append({"event": &"navigation_failed", "state": _state()})
	return true


func snapshot(include_debug: bool = true) -> Dictionary:
	var action := _active()
	var payload: Dictionary = action.get("payload", {})
	return {
		"state": _state(),
		"class": PLANNER_SCRIPT.STATE_CLASS.get(_state(), &"absent"),
		"reservation": _current_reservation(),
		"destination": &"step_aside_hold" if _hold_position != null else StringName(payload.get("destination", &"")),
		"hold_position": _hold_position,
		"elapsed_seconds": float(action.get("elapsed_seconds", 0.0)),
		"navigation_arrived": bool(payload.get("navigation_arrived", true)),
		"deferred": _planner.deferred() if include_debug else [],
		"events": _events.duplicate(true) if include_debug else [],
		"action_queue": _actions.snapshot(_patron_id) if include_debug else {},
		"planner_paused": _planner.is_paused(),
	}


func set_planner_paused(paused: bool) -> void:
	_planner.set_paused(paused)
	_actions.set_planner_paused(_patron_id, paused)


func force_normal(state: StringName, destination: StringName, reservation: StringName = &"") -> void:
	_planner.set_paused(false)
	_actions.set_planner_paused(_patron_id, false)
	_planner.clear()
	_activate(state, destination, reservation, false)


func request_step_aside(position: Vector3, incident_id: StringName) -> bool:
	var action := _active()
	if action.is_empty() or StringName(action["name"]) == &"step_aside" or _suppressed_incidents.has(incident_id):
		return false
	if PLANNER_SCRIPT.STATE_CLASS.get(StringName(action["name"]), &"") not in [
		&"routine", &"order",
	]:
		return false
	_queue.interrupt_with({
		"name": &"step_aside", "target_id": incident_id,
		"duration_seconds": INF, "commitment_seconds": INF,
		"payload": {
			"command": &"step_aside",
			"target": {"kind": &"floor", "id": incident_id, "position": position},
			"destination": &"step_aside", "reservation": &"",
			"navigation_arrived": false, "committed": false, "reserved": false,
			"stage": &"approaching", "visibility": &"debug",
			"paused_state": StringName(action["name"]),
		},
	})
	return true


func drain_events() -> Array[Dictionary]:
	var result := _events.duplicate(true)
	_events.clear()
	return result


func _activate(
	state: StringName, destination: StringName, reservation: StringName, requires_movement: bool
) -> void:
	_hold_position = null
	var previous := _current_reservation()
	if not previous.is_empty() and previous != reservation and _registry != null:
		_registry.release_actor(_patron_id)
		_events.append({"event": &"reservation_released", "slot": previous})
	_queue.clear_all(&"intent_transition")
	var payload := {
		"command": state,
		"target": {"kind": &"patron_intent", "id": destination},
		"destination": destination,
		"reservation": reservation,
		"navigation_arrived": not requires_movement,
		"committed": true,
		"reserved": not reservation.is_empty(),
		"stage": &"committed",
		"interruption_policy": &"pause_resume",
		"visibility": &"debug",
	}
	_queue.append(state, destination, INF, 0.0, true, payload)
	if not reservation.is_empty() and previous != reservation and _registry != null:
		_registry.request_slot(_patron_id, reservation)
		_events.append({"event": &"reservation_acquired", "slot": reservation})
	if state in [&"captured", &"exited"]:
		_planner.clear()


func _active() -> Dictionary:
	return _actions.active_request(_patron_id)


func _state() -> StringName:
	var action := _active()
	if StringName(action.get("name", &"")) == &"step_aside":
		return StringName(action.get("payload", {}).get("paused_state", &"socializing"))
	return StringName(action.get("name", _idle_state))


func _current_reservation() -> StringName:
	return _registry.actor_slot(_patron_id) if _registry != null else &""


func _can_take_reservation(reservation: StringName) -> bool:
	if reservation.is_empty() or _registry == null:
		return true
	var current: StringName = _registry.actor_slot(_patron_id)
	return current == reservation or _registry.slot_owner(reservation) == ActorIds.NO_ACTOR


func _reason_for(decision: StringName) -> StringName:
	if decision == PLANNER_SCRIPT.ACCEPT:
		return &"accepted_by_priority"
	if decision == PLANNER_SCRIPT.DEFER:
		return &"current_phase_committed"
	if _state() in [&"captured", &"exited"]:
		return &"terminal_state"
	return &"lower_priority_rejected"
