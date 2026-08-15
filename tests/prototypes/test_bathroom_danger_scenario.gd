extends GutTest

const SCENARIO_PATH := "res://scripts/prototypes/bathroom_danger_scenario.gd"


func test_seeded_choice_and_fifo_cleanup_are_repeatable() -> void:
	var scenario_script := load(SCENARIO_PATH)
	assert_not_null(scenario_script)
	if scenario_script == null:
		return

	var first = scenario_script.new()
	var replay = scenario_script.new()
	for scenario in [first, replay]:
		scenario.start(41_904)
		scenario.add_patron(&"patron_01", 100.0)
		scenario.check_bathroom_choice(&"patron_01")
	assert_eq(first.snapshot()["recent_rolls"], replay.snapshot()["recent_rolls"])
	assert_eq(first.snapshot()["occupant_id"], replay.snapshot()["occupant_id"])

	first.restart(41_904)
	for patron_id in [&"patron_01", &"patron_02", &"patron_03"]:
		first.add_patron(patron_id, 100.0)
		assert_true(first.force_bathroom_intent(patron_id))
	var queued: Dictionary = first.snapshot()
	assert_eq(queued["occupant_id"], &"patron_01")
	assert_eq(queued["queue"], [&"patron_02", &"patron_03"])

	assert_true(first.cancel_actor(&"patron_01"))
	assert_eq(first.snapshot()["occupant_id"], &"patron_02")
	assert_eq(first.snapshot()["queue"], [&"patron_03"])
	assert_true(first.cancel_actor(&"patron_02"))
	assert_true(first.cancel_actor(&"patron_03"))
	assert_true(first.snapshot()["ownership_clean"])


func test_trapdoor_captures_standing_but_seated_evidence_does_not_arm_next_patron() -> void:
	var scenario_script := load(SCENARIO_PATH)
	var scenario = scenario_script.new()
	scenario.start(9)
	scenario.add_patron(&"standing_patron", 100.0)
	scenario.force_bathroom_intent(&"standing_patron")
	assert_true(scenario.activate_trapdoor())
	assert_eq(scenario.snapshot()["patrons"][&"standing_patron"]["lifecycle"], &"captured")
	assert_true(scenario.snapshot()["ownership_clean"])

	scenario.restart(10)
	scenario.add_patron(&"hallway_patron", 0.0)
	scenario.add_patron(&"seated_patron", 100.0)
	scenario.add_patron(&"next_patron", 100.0)
	scenario.force_bathroom_intent(&"seated_patron")
	scenario.force_bathroom_intent(&"next_patron")
	scenario.advance(2.05)
	assert_eq(scenario.snapshot()["patrons"][&"seated_patron"]["activity"], &"seated_use")
	assert_true(scenario.activate_trapdoor())
	var misfire: Dictionary = scenario.snapshot()
	assert_eq(float(misfire["patrons"][&"seated_patron"]["suspicion"]), 100.0)
	assert_eq(misfire["patrons"][&"seated_patron"]["activity"], &"seated_use")
	assert_eq(misfire["occupant_id"], &"seated_patron")
	assert_eq(float(misfire["patrons"][&"hallway_patron"]["suspicion"]), 0.0)
	assert_eq(misfire["patrons"][&"hallway_patron"]["activity"], &"normal")
	assert_true(scenario.cancel_actor(&"seated_patron"))
	scenario.advance(1.0)
	assert_eq(scenario.snapshot()["patrons"][&"next_patron"]["lifecycle"], &"active")
	assert_eq(scenario.snapshot()["occupant_id"], &"next_patron")
	assert_eq(scenario.snapshot()["trapdoor_eligible_occupant"], &"seated_patron")
	scenario.advance(4.1)
	assert_eq(scenario.snapshot()["trapdoor_state"], &"closed")

	scenario.restart(11)
	scenario.add_patron(&"max_drunk_patron", 100.0, true)
	scenario.force_bathroom_intent(&"max_drunk_patron")
	scenario.advance(2.05)
	scenario.activate_trapdoor()
	var max_drunk: Dictionary = scenario.snapshot()["patrons"][&"max_drunk_patron"]
	assert_eq(float(max_drunk["suspicion"]), 25.0)
	assert_eq(max_drunk["suspicion_cause"], &"soft")

	scenario.restart(12)
	scenario.add_patron(&"sober_witness", 100.0)
	scenario.force_bathroom_intent(&"sober_witness")
	scenario.advance(2.05)
	scenario.activate_trapdoor()
	scenario.advance(11.05)
	var escaped_after_visit: Dictionary = scenario.snapshot()["patrons"][&"sober_witness"]
	assert_eq(escaped_after_visit["lifecycle"], &"escaping")
	assert_eq(escaped_after_visit["activity"], &"shock")


func test_missing_companion_reaches_investigation_intercept_and_defeat_once() -> void:
	var scenario_script := load(SCENARIO_PATH)
	var scenario = scenario_script.new()
	scenario.start(77)
	scenario.add_patron(&"missing_patron", 100.0, false, &"companion")
	scenario.add_patron(&"companion", 0.0, false, &"missing_patron")
	scenario.force_bathroom_intent(&"missing_patron")
	scenario.activate_trapdoor()

	scenario.advance(20.0)
	assert_almost_eq(float(scenario.snapshot()["patrons"][&"companion"]["suspicion"]), 25.0, 0.001)
	scenario.advance(10.0)
	assert_almost_eq(float(scenario.snapshot()["patrons"][&"companion"]["suspicion"]), 50.0, 0.001)
	scenario.advance(10.0)
	assert_eq(scenario.snapshot()["patrons"][&"companion"]["lifecycle"], &"investigating")
	assert_eq(scenario.snapshot()["occupant_id"], &"companion")

	scenario.advance(5.05)
	assert_eq(scenario.snapshot()["patrons"][&"companion"]["lifecycle"], &"escaping")
	assert_eq(float(scenario.snapshot()["time_scale"]), 1.0)
	scenario.advance(2.05)
	assert_true(scenario.begin_intercept(&"companion", &"cultist_01"))
	assert_false(scenario.begin_intercept(&"companion", &"cultist_02"))
	scenario.advance(5.05)
	assert_false(scenario.snapshot()["active_intercept"].has("patron_id"))
	scenario.advance(6.05)
	assert_true(scenario.snapshot()["defeat"])
	assert_eq(scenario.snapshot()["patrons"][&"companion"]["lifecycle"], &"exited")
	assert_true(scenario.snapshot()["ownership_clean"])


func test_investigator_capture_cancellation_and_restart_release_ownership() -> void:
	var scenario_script := load(SCENARIO_PATH)
	var scenario = scenario_script.new()
	scenario.start(88)
	scenario.add_patron(&"missing_patron", 100.0, false, &"companion")
	scenario.add_patron(&"companion", 0.0, false, &"missing_patron")
	scenario.force_bathroom_intent(&"missing_patron")
	scenario.activate_trapdoor()
	scenario.advance(40.05)
	assert_eq(scenario.snapshot()["patrons"][&"companion"]["activity"], &"investigation_search")
	assert_true(scenario.activate_trapdoor())
	assert_eq(scenario.snapshot()["patrons"][&"companion"]["lifecycle"], &"captured")
	assert_true(scenario.snapshot()["ownership_clean"])

	scenario.restart(89)
	scenario.add_patron(&"occupant", 100.0)
	scenario.add_patron(&"queued", 100.0)
	scenario.force_bathroom_intent(&"occupant")
	scenario.force_bathroom_intent(&"queued")
	assert_true(scenario.cancel_actor(&"queued"))
	scenario.restart(90)
	var restarted: Dictionary = scenario.snapshot()
	assert_true(restarted["ownership_clean"])
	assert_true(restarted["patrons"].is_empty())
	assert_eq(restarted["trapdoor_state"], &"closed")
	assert_false(restarted["defeat"])
