class_name PatronBehaviorMachine
extends RefCounted

## One authority for Patron behavior priority and transition cleanup.
## Callers submit a desired state. They do not compare priorities themselves.

const ACCEPT := &"accept"
const DEFER := &"defer"
const REJECT := &"reject"

const STATE_CLASS := {
	&"not_arrived": &"absent",
	&"entering": &"routine",
	&"finding_seat": &"routine",
	&"socializing": &"routine",
	&"awaiting_drink": &"order",
	&"conversing": &"talk",
	&"drinking": &"drink",
	&"bathroom_queued": &"bathroom",
	&"entering_bathroom": &"bathroom",
	&"seated_bathroom_use": &"bathroom",
	&"standing_bathroom_exit": &"bathroom",
	&"normal_departure": &"departure",
	&"helper_reacting": &"helper",
	&"helper_lifting": &"helper",
	&"helper_carrying": &"helper",
	&"helper_persuading": &"helper",
	&"waiting_investigation": &"investigation",
	&"investigation_search": &"investigation",
	&"shock": &"escape",
	&"escaping": &"escape",
	&"intercepted": &"escape",
	&"unconscious": &"incapacitated",
	&"being_dragged": &"incapacitated",
	&"following": &"incapacitated",
	&"captured": &"terminal",
	&"exited": &"terminal",
}

const CLASS_PRIORITY := {
	&"routine": 0,
	&"order": 1,
	&"talk": 2,
	&"drink": 3,
	&"bathroom": 4,
	&"departure": 5,
	&"helper": 6,
	&"investigation": 7,
	&"escape": 8,
	&"incapacitated": 9,
	&"terminal": 10,
}

# Rows are current behavior classes. Columns are requested behavior classes.
# State-specific terminal and arrival rules are applied before this table.
const TRANSITION_MATRIX := {
	&"routine": {
		&"routine": ACCEPT, &"order": ACCEPT, &"talk": ACCEPT, &"drink": ACCEPT,
		&"bathroom": ACCEPT, &"departure": ACCEPT, &"helper": ACCEPT,
		&"investigation": ACCEPT, &"escape": ACCEPT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"order": {
		&"routine": ACCEPT, &"order": ACCEPT, &"talk": ACCEPT, &"drink": ACCEPT,
		&"bathroom": ACCEPT, &"departure": DEFER, &"helper": ACCEPT,
		&"investigation": ACCEPT, &"escape": ACCEPT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"talk": {
		&"routine": ACCEPT, &"order": DEFER, &"talk": ACCEPT, &"drink": DEFER,
		&"bathroom": ACCEPT, &"departure": DEFER, &"helper": ACCEPT,
		&"investigation": ACCEPT, &"escape": ACCEPT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"drink": {
		&"routine": ACCEPT, &"order": DEFER, &"talk": DEFER, &"drink": ACCEPT,
		&"bathroom": DEFER, &"departure": DEFER, &"helper": DEFER,
		&"investigation": DEFER, &"escape": DEFER, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"bathroom": {
		&"routine": ACCEPT, &"order": DEFER, &"talk": DEFER, &"drink": DEFER,
		&"bathroom": ACCEPT, &"departure": DEFER, &"helper": DEFER,
		&"investigation": DEFER, &"escape": DEFER, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"departure": {
		&"routine": REJECT, &"order": REJECT, &"talk": REJECT, &"drink": REJECT,
		&"bathroom": REJECT, &"departure": ACCEPT, &"helper": ACCEPT,
		&"investigation": ACCEPT, &"escape": ACCEPT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"helper": {
		&"routine": REJECT, &"order": REJECT, &"talk": REJECT, &"drink": REJECT,
		&"bathroom": REJECT, &"departure": DEFER, &"helper": ACCEPT,
		&"investigation": ACCEPT, &"escape": ACCEPT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"investigation": {
		&"routine": REJECT, &"order": REJECT, &"talk": REJECT, &"drink": REJECT,
		&"bathroom": REJECT, &"departure": REJECT, &"helper": REJECT,
		&"investigation": ACCEPT, &"escape": ACCEPT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"escape": {
		&"routine": REJECT, &"order": REJECT, &"talk": REJECT, &"drink": REJECT,
		&"bathroom": REJECT, &"departure": REJECT, &"helper": REJECT,
		&"investigation": REJECT, &"escape": ACCEPT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
	&"incapacitated": {
		&"routine": REJECT, &"order": REJECT, &"talk": REJECT, &"drink": REJECT,
		&"bathroom": REJECT, &"departure": REJECT, &"helper": REJECT,
		&"investigation": REJECT, &"escape": REJECT, &"incapacitated": ACCEPT,
		&"terminal": ACCEPT,
	},
}

var _state: StringName
var _reservation: StringName = &""
var _deferred: Array[Dictionary] = []
var _events: Array[Dictionary] = []


func _init(initial_state: StringName = &"not_arrived") -> void:
	assert(STATE_CLASS.has(initial_state), "Unknown Patron behavior state")
	_state = initial_state


static func decision_for(current_state: StringName, requested_state: StringName) -> StringName:
	if not STATE_CLASS.has(current_state) or not STATE_CLASS.has(requested_state):
		return REJECT
	if current_state in [&"captured", &"exited"]:
		return REJECT
	if current_state == &"not_arrived":
		return ACCEPT if requested_state == &"entering" else REJECT
	var current_class: StringName = STATE_CLASS[current_state]
	var requested_class: StringName = STATE_CLASS[requested_state]
	return TRANSITION_MATRIX.get(current_class, {}).get(requested_class, REJECT)


func submit(requested_state: StringName, reservation: StringName = &"") -> Dictionary:
	var decision := decision_for(_state, requested_state)
	var result := {
		"decision": decision,
		"from": _state,
		"to": requested_state,
		"reason": _reason_for(decision, requested_state),
	}
	_events.append(result.duplicate())
	if decision == DEFER:
		_store_deferred(requested_state, reservation)
	elif decision == ACCEPT:
		_transition(requested_state, reservation)
	return result


func complete_committed(fallback_state: StringName, fallback_reservation: StringName = &"") -> Dictionary:
	if not _deferred.is_empty():
		_deferred.sort_custom(_higher_priority)
		var next: Dictionary = _deferred.pop_front()
		_deferred.clear()
		var result := {
			"decision": ACCEPT,
			"from": _state,
			"to": next["state"],
			"reason": &"committed_phase_completed",
		}
		_events.append(result.duplicate())
		_transition(next["state"], next["reservation"])
		return result
	return submit(fallback_state, fallback_reservation)


func snapshot() -> Dictionary:
	return {
		"state": _state,
		"class": STATE_CLASS[_state],
		"reservation": _reservation,
		"deferred": _deferred.duplicate(true),
		"events": _events.duplicate(true),
	}


func drain_events() -> Array[Dictionary]:
	var result := _events.duplicate(true)
	_events.clear()
	return result


func _transition(next_state: StringName, next_reservation: StringName) -> void:
	if not _reservation.is_empty() and _reservation != next_reservation:
		_events.append({"event": &"reservation_released", "slot": _reservation})
	_reservation = next_reservation
	_state = next_state
	if not _reservation.is_empty():
		_events.append({"event": &"reservation_acquired", "slot": _reservation})
	if _state in [&"captured", &"exited"]:
		_deferred.clear()


func _store_deferred(state: StringName, reservation: StringName) -> void:
	for index in range(_deferred.size()):
		if _deferred[index]["state"] == state:
			_deferred[index] = {"state": state, "reservation": reservation}
			return
	_deferred.append({"state": state, "reservation": reservation})


func _higher_priority(left: Dictionary, right: Dictionary) -> bool:
	return CLASS_PRIORITY.get(STATE_CLASS[left["state"]], -1) > CLASS_PRIORITY.get(STATE_CLASS[right["state"]], -1)


func _reason_for(decision: StringName, requested_state: StringName) -> StringName:
	if decision == ACCEPT:
		return &"accepted_by_priority"
	if decision == DEFER:
		return &"current_phase_committed"
	if _state in [&"captured", &"exited"]:
		return &"terminal_state"
	if not STATE_CLASS.has(requested_state):
		return &"unknown_state"
	return &"lower_priority_rejected"
