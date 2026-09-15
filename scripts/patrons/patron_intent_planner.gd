class_name PatronIntentPlanner
extends RefCounted

## Chooses the next Patron Action Chain. It owns priority policy and deferred
## intent only; CharacterActionSystem owns every Action lifecycle and clock.

const ACCEPT := &"accept"
const DEFER := &"defer"
const REJECT := &"reject"

const STATE_CLASS := {
	&"not_arrived": &"absent",
	&"waiting_at_entrance": &"routine",
	&"entering": &"routine",
	&"finding_seat": &"routine",
	&"socializing": &"routine",
	&"smoking": &"routine",
	&"awaiting_drink": &"order",
	&"conversing": &"talk",
	&"drinking": &"drink",
	&"bathroom_queued": &"bathroom",
	&"entering_bathroom": &"bathroom",
	&"mirror_check": &"bathroom",
	&"moving_to_toilet": &"bathroom",
	&"seated_bathroom_use": &"bathroom",
	&"moving_to_sink": &"bathroom",
	&"handwashing": &"bathroom",
	&"standing_bathroom_exit": &"bathroom",
	&"normal_departure": &"departure",
	&"helper_reacting": &"helper",
	&"helper_lifting": &"helper",
	&"helper_carrying": &"helper",
	&"helper_persuading": &"helper",
	&"waiting_investigation": &"investigation",
	&"investigation_search": &"investigation",
	&"investigation_travel": &"investigation",
	&"goal_blocked": &"investigation",
	&"shock": &"escape",
	&"escaping": &"escape",
	&"intercepted": &"escape",
	&"unconscious": &"incapacitated",
	&"being_dragged": &"incapacitated",
	&"following": &"incapacitated",
	&"trapdoor_falling": &"capturing",
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
	&"capturing": 10,
	&"terminal": 11,
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
		&"capturing": ACCEPT, &"terminal": ACCEPT,
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
		&"capturing": ACCEPT, &"terminal": ACCEPT,
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
		&"capturing": ACCEPT, &"terminal": ACCEPT,
	},
	# The Trapdoor fall is a committed capture: only terminal removal follows it.
	&"capturing": {
		&"routine": REJECT, &"order": REJECT, &"talk": REJECT, &"drink": REJECT,
		&"bathroom": REJECT, &"departure": REJECT, &"helper": REJECT,
		&"investigation": REJECT, &"escape": REJECT, &"incapacitated": REJECT,
		&"capturing": ACCEPT, &"terminal": ACCEPT,
	},
}

var _deferred: Array[Dictionary] = []
var _paused := false


func decide(current_state: StringName, requested_state: StringName) -> StringName:
	if _paused and CLASS_PRIORITY.get(STATE_CLASS.get(requested_state, &""), 0) < 6:
		return REJECT
	return decision_for(current_state, requested_state)


func defer(intent: Dictionary) -> void:
	for index in range(_deferred.size()):
		if StringName(_deferred[index]["state"]) == StringName(intent["state"]):
			_deferred[index] = intent.duplicate(true)
			return
	_deferred.append(intent.duplicate(true))


func take_highest() -> Dictionary:
	if _deferred.is_empty():
		return {}
	_deferred.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return CLASS_PRIORITY.get(STATE_CLASS[left["state"]], -1) > CLASS_PRIORITY.get(
			STATE_CLASS[right["state"]], -1
		)
	)
	var result: Dictionary = _deferred.pop_front()
	_deferred.clear()
	return result


func deferred() -> Array[Dictionary]:
	return _deferred.duplicate(true)


func clear() -> void:
	_deferred.clear()


func set_paused(paused: bool) -> void:
	_paused = paused


func is_paused() -> bool:
	return _paused


static func decision_for(current_state: StringName, requested_state: StringName) -> StringName:
	if not STATE_CLASS.has(current_state) or not STATE_CLASS.has(requested_state):
		return REJECT
	if current_state in [&"captured", &"exited"]:
		return REJECT
	if current_state == &"not_arrived":
		return ACCEPT if requested_state == &"waiting_at_entrance" else REJECT
	var current_class: StringName = STATE_CLASS[current_state]
	var requested_class: StringName = STATE_CLASS[requested_state]
	return TRANSITION_MATRIX.get(current_class, {}).get(requested_class, REJECT)
