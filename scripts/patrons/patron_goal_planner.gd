class_name PatronGoalPlanner
extends RefCounted

## Owns knowledge, goal selection, and plan validity, never clocks or world
## effects. The simulation acknowledges each queued Action by its identity.
const SEARCH := preload("res://scripts/patrons/goap_planner.gd")
const RETRY_SECONDS := 2.0
const MAX_FAILURES := 3
const ACTIONS := [
	{"name": &"approach_bathroom", "preconditions": {"missing": true, "at_bathroom": false},
		"effects": {"at_bathroom": true}, "cost": 2.0, "state": &"investigation_travel", "destination": &"bathroom"},
	{"name": &"search_bathroom", "preconditions": {"missing": true, "at_bathroom": true},
		"effects": {"searched": true}, "cost": 6.0, "state": &"investigation_search", "destination": &"bathroom"},
	{"name": &"recover_shock", "preconditions": {"danger": true, "shock_over": false},
		"effects": {"shock_over": true}, "cost": 1.0, "state": &"shock", "destination": &"front_exit"},
	{"name": &"leave", "preconditions": {"danger": true, "shock_over": true},
		"effects": {"exited": true}, "cost": 8.0, "state": &"escaping", "destination": &"front_exit"},
]

var _facts := {"missing": false, "danger": false, "at_bathroom": false,
	"searched": false, "shock_over": false, "exited": false}
var _goal: StringName = &""
var _steps: Array = []
var _action_id := -1
var _status: StringName = &"idle"
var _reason: StringName = &"not_needed"
var _failures := 0
var _retry_at := 0.0
var _world_signature := ""
var _planning_count := 0


func observe(missing: bool, danger: bool) -> void:
	_facts["missing"] = missing
	# Escape remains committed once selected. Capture ends this planner explicitly.
	_facts["danger"] = danger or bool(_facts["danger"])
	var selected: StringName = &"escape" if _facts["danger"] else (&"investigate" if missing else &"")
	if selected == _goal:
		return
	_goal = selected
	_steps.clear()
	_action_id = -1
	_status = &"idle" if selected.is_empty() else &"planning"
	_reason = &"goal_changed"
	_failures = 0
	_retry_at = 0.0


func next_action(now: float, world_signature: String) -> Dictionary:
	if _goal.is_empty() or _status == &"complete":
		return {}
	if world_signature != _world_signature:
		_world_signature = world_signature
		if _status == &"blocked":
			_failures = 0
			_retry_at = now
	if _status == &"blocked" and now < _retry_at:
		return {}
	if _steps.is_empty():
		var result := SEARCH.plan(_facts, {"exited": true} if _goal == &"escape" else {"searched": true}, ACTIONS)
		_planning_count += 1
		if result["status"] != &"ready":
			fail(-1, result["status"], now)
			return {}
		_steps = result["steps"]
		_status = &"ready" if not _steps.is_empty() else &"complete"
	if _steps.is_empty():
		return {}
	return _steps[0].duplicate(true)


func started(action_id: int) -> void:
	_action_id = action_id
	_status = &"running"


func complete(action_id: int) -> bool:
	if _status != &"running" or action_id != _action_id or _steps.is_empty():
		return false
	_facts.merge(_steps.pop_front()["effects"], true)
	_action_id = -1
	_failures = 0
	_status = &"ready" if not _steps.is_empty() else &"complete"
	_reason = &"action_completed"
	return true


func fail(action_id: int, reason: StringName, now: float) -> bool:
	if action_id >= 0 and action_id != _action_id:
		return false
	_steps.clear()
	if _goal == &"investigate":
		_facts["at_bathroom"] = false
	_action_id = -1
	_status = &"blocked"
	_reason = reason
	_failures += 1
	_retry_at = now + RETRY_SECONDS if _failures < MAX_FAILURES else INF
	return true


func stop(reason: StringName) -> void:
	_goal = &""
	_steps.clear()
	_action_id = -1
	_status = &"idle"
	_reason = reason
	_facts = {"missing": false, "danger": false, "at_bathroom": false,
		"searched": false, "shock_over": false, "exited": false}


func snapshot() -> Dictionary:
	var names: Array = []
	for action: Dictionary in _steps:
		names.append(action["name"])
	return {"goal": _goal, "facts": _facts.duplicate(), "plan": names,
		"action_id": _action_id, "status": _status, "reason": _reason,
		"failures": _failures, "retry_at": _retry_at, "planning_count": _planning_count}
