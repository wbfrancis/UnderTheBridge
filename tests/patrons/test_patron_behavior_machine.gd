extends GutTest

const MACHINE_SCRIPT := preload("res://scripts/patrons/patron_behavior_machine.gd")


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
	var machine = MACHINE_SCRIPT.new(&"drinking")
	assert_eq(machine.submit(&"entering_bathroom")["decision"], MACHINE_SCRIPT.DEFER)
	assert_eq(machine.submit(&"normal_departure")["decision"], MACHINE_SCRIPT.DEFER)
	assert_eq(machine.submit(&"escaping")["decision"], MACHINE_SCRIPT.DEFER)
	var resolved: Dictionary = machine.complete_committed(&"socializing")
	assert_eq(resolved["to"], &"escaping")
	assert_eq(machine.snapshot()["state"], &"escaping")
	assert_true(machine.snapshot()["deferred"].is_empty())


func test_transition_releases_old_reservation_before_acquiring_new_one() -> void:
	var machine = MACHINE_SCRIPT.new(&"socializing")
	machine.submit(&"awaiting_drink", &"bar_wait")
	machine.drain_events()
	machine.submit(&"entering_bathroom", &"bathroom_line")
	var events: Array[Dictionary] = machine.drain_events()
	assert_eq(events[1], {"event": &"reservation_released", "slot": &"bar_wait"})
	assert_eq(events[2], {"event": &"reservation_acquired", "slot": &"bathroom_line"})


func test_terminal_transition_clears_deferred_work_and_rejects_later_intents() -> void:
	var machine = MACHINE_SCRIPT.new(&"drinking")
	machine.submit(&"normal_departure")
	assert_eq(machine.submit(&"captured")["decision"], MACHINE_SCRIPT.ACCEPT)
	assert_true(machine.snapshot()["deferred"].is_empty())
	var rejected: Dictionary = machine.submit(&"escaping")
	assert_eq(rejected["decision"], MACHINE_SCRIPT.REJECT)
	assert_eq(rejected["reason"], &"terminal_state")
