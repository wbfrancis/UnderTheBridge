extends GutTest

const MACHINE_SCRIPT := preload("res://scripts/patrons/patron_behavior_machine.gd")
const REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")


func _machine(initial_state: StringName = &"socializing"):
	return MACHINE_SCRIPT.new(1001, REGISTRY_SCRIPT.new(), initial_state)


func test_step_aside_resumes_original_action_and_cancel_does_not_repeat_incident() -> void:
	var machine = _machine()
	machine.advance(3.0)
	var original: int = machine.snapshot()["action_queue"]["active"]["id"]
	assert_true(machine.request_step_aside(Vector3.RIGHT, &"incident"))
	var interrupt_id: int = machine.snapshot()["action_queue"]["active"]["id"]
	assert_true(machine.cancel(interrupt_id, &"socializing", false, Vector3(0.5, 0, 0)))
	assert_eq(machine.snapshot()["action_queue"]["active"]["id"], original)
	assert_eq(machine.snapshot()["elapsed_seconds"], 3.0)
	assert_eq(machine.snapshot()["hold_position"], Vector3(0.5, 0, 0))
	assert_false(machine.request_step_aside(Vector3.RIGHT, &"incident"))


func test_debug_clear_and_planner_pause_leave_no_active_work() -> void:
	var machine = _machine()
	machine.set_planner_paused(true)
	var action_id: int = machine.snapshot()["action_queue"]["active"]["id"]
	assert_true(machine.cancel(action_id, &"socializing", true))
	assert_true(machine.snapshot()["action_queue"]["active"].is_empty())
	assert_eq(machine.submit(&"conversing")["decision"], MACHINE_SCRIPT.REJECT)
	machine.set_planner_paused(false)
	assert_eq(machine.submit(&"conversing")["decision"], MACHINE_SCRIPT.ACCEPT)


func test_transition_matrix_has_a_decision_for_every_known_pair() -> void:
	for current_state: StringName in MACHINE_SCRIPT.STATE_CLASS:
		for requested_state: StringName in MACHINE_SCRIPT.STATE_CLASS:
			var decision: StringName = MACHINE_SCRIPT.decision_for(current_state, requested_state)
			assert_has([MACHINE_SCRIPT.ACCEPT, MACHINE_SCRIPT.DEFER, MACHINE_SCRIPT.REJECT], decision)


func test_priority_examples_match_the_accepted_interruption_rules() -> void:
	assert_eq(MACHINE_SCRIPT.decision_for(&"socializing", &"escaping"), MACHINE_SCRIPT.ACCEPT)
	assert_eq(MACHINE_SCRIPT.decision_for(&"conversing", &"entering_bathroom"), MACHINE_SCRIPT.ACCEPT)
	assert_eq(MACHINE_SCRIPT.decision_for(&"drinking", &"entering_bathroom"), MACHINE_SCRIPT.DEFER)
	assert_eq(MACHINE_SCRIPT.decision_for(&"seated_bathroom_use", &"escaping"), MACHINE_SCRIPT.DEFER)
	assert_eq(MACHINE_SCRIPT.decision_for(&"awaiting_drink", &"normal_departure"), MACHINE_SCRIPT.DEFER)
	assert_eq(MACHINE_SCRIPT.decision_for(&"escaping", &"socializing"), MACHINE_SCRIPT.REJECT)
	assert_eq(MACHINE_SCRIPT.decision_for(&"captured", &"escaping"), MACHINE_SCRIPT.REJECT)


func test_deferred_intents_resolve_by_priority_after_committed_phase() -> void:
	var machine = _machine(&"drinking")
	assert_eq(machine.submit(&"entering_bathroom")["decision"], MACHINE_SCRIPT.DEFER)
	assert_eq(machine.submit(&"normal_departure")["decision"], MACHINE_SCRIPT.DEFER)
	assert_eq(machine.submit(&"escaping")["decision"], MACHINE_SCRIPT.DEFER)
	var resolved: Dictionary = machine.complete_committed(&"socializing")
	assert_eq(resolved["to"], &"escaping")
	assert_eq(machine.snapshot()["state"], &"escaping")
	assert_true(machine.snapshot()["deferred"].is_empty())


func test_transition_releases_old_reservation_before_acquiring_new_one() -> void:
	var registry = REGISTRY_SCRIPT.new()
	registry.register_slot(&"bar_wait", &"bar")
	registry.register_slot(&"bathroom_line", &"bathroom")
	var machine = MACHINE_SCRIPT.new(1001, registry, &"socializing")
	machine.submit(&"awaiting_drink", &"bar", &"bar_wait")
	machine.drain_events()
	machine.submit(&"entering_bathroom", &"bathroom", &"bathroom_line")
	var events: Array[Dictionary] = machine.drain_events()
	assert_eq(events[1], {"event": &"reservation_released", "slot": &"bar_wait"})
	assert_eq(events[2], {"event": &"reservation_acquired", "slot": &"bathroom_line"})
	assert_eq(registry.actor_slot(1001), &"bathroom_line")


func test_terminal_transition_clears_deferred_work_and_rejects_later_intents() -> void:
	var machine = _machine(&"drinking")
	machine.submit(&"normal_departure")
	assert_eq(machine.submit(&"captured")["decision"], MACHINE_SCRIPT.ACCEPT)
	assert_true(machine.snapshot()["deferred"].is_empty())
	var rejected: Dictionary = machine.submit(&"escaping")
	assert_eq(rejected["decision"], MACHINE_SCRIPT.REJECT)
	assert_eq(rejected["reason"], &"terminal_state")


func test_machine_owns_elapsed_destination_and_navigation_arrival() -> void:
	var machine = _machine()
	assert_eq(machine.submit(&"entering_bathroom", &"bathroom", &"", true)["decision"], MACHINE_SCRIPT.ACCEPT)
	assert_eq(machine.snapshot()["destination"], &"bathroom")
	assert_false(machine.snapshot()["navigation_arrived"])
	machine.advance(1.25)
	assert_almost_eq(float(machine.snapshot()["elapsed_seconds"]), 1.25, 0.001)
	assert_true(machine.report_navigation_arrival())
	assert_true(machine.snapshot()["navigation_arrived"])
	machine.submit(&"mirror_check", &"mirror")
	assert_almost_eq(float(machine.snapshot()["elapsed_seconds"]), 0.0, 0.001)
