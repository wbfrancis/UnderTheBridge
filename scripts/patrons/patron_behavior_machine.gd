class_name PatronBehaviorMachine
extends "res://scripts/patrons/patron_action_coordinator.gd"

## Compatibility entry point for existing fixtures. Runtime behavior uses
## PatronIntentPlanner with the Night's shared CharacterActionSystem.
const ACCEPT = PLANNER_SCRIPT.ACCEPT
const DEFER = PLANNER_SCRIPT.DEFER
const REJECT = PLANNER_SCRIPT.REJECT
const STATE_CLASS = PLANNER_SCRIPT.STATE_CLASS
const CLASS_PRIORITY = PLANNER_SCRIPT.CLASS_PRIORITY

func _init(
	patron_id: int,
	registry = null,
	initial_state: StringName = &"not_arrived"
) -> void:
	super(patron_id, registry,
		preload("res://scripts/actions/character_action_system.gd").new(), initial_state)

static func decision_for(current_state: StringName, requested_state: StringName) -> StringName:
	return PLANNER_SCRIPT.decision_for(current_state, requested_state)
