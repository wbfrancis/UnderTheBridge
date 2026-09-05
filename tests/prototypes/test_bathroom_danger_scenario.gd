extends GutTest

const SUBJECT_ACTOR_ID: int = 1001
const OTHER_ACTOR_ID: int = 1002
const THIRD_ACTOR_ID: int = 1003

const STANDING_PATRON: int = 1109

const SOBER_WITNESS: int = 1108

const SEATED_PATRON: int = 1107

const QUEUED: int = 1106

const OCCUPANT: int = 1105

const NEXT_PATRON: int = 1104

const MISSING_PATRON: int = 1103

const MAX_DRUNK_PATRON: int = 1102

const HALLWAY_PATRON: int = 1101

const COMPANION: int = 1100

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
		scenario.add_patron(SUBJECT_ACTOR_ID, 100.0)
		scenario.check_bathroom_choice(SUBJECT_ACTOR_ID)
	assert_eq(first.snapshot()["recent_rolls"], replay.snapshot()["recent_rolls"])
	assert_eq(first.snapshot()["occupant_id"], replay.snapshot()["occupant_id"])

	first.restart(41_904)
	for patron_id in [SUBJECT_ACTOR_ID, OTHER_ACTOR_ID, THIRD_ACTOR_ID]:
		first.add_patron(patron_id, 100.0)
		assert_true(first.force_bathroom_intent(patron_id))
	var queued: Dictionary = first.snapshot()
	assert_eq(queued["occupant_id"], SUBJECT_ACTOR_ID)
	assert_eq(queued["queue"], [OTHER_ACTOR_ID, THIRD_ACTOR_ID])

	assert_true(first.cancel_actor(SUBJECT_ACTOR_ID))
	assert_eq(first.snapshot()["occupant_id"], OTHER_ACTOR_ID)
	assert_eq(first.snapshot()["queue"], [THIRD_ACTOR_ID])
	assert_true(first.cancel_actor(OTHER_ACTOR_ID))
	assert_true(first.cancel_actor(THIRD_ACTOR_ID))
	assert_true(first.snapshot()["ownership_clean"])


func test_trapdoor_captures_standing_but_seated_evidence_does_not_arm_next_patron() -> void:
	var scenario_script := load(SCENARIO_PATH)
	var scenario = scenario_script.new()
	scenario.start(9)
	scenario.add_patron(STANDING_PATRON, 100.0)
	scenario.force_bathroom_intent(STANDING_PATRON)
	assert_true(scenario.activate_trapdoor())
	assert_eq(scenario.snapshot()["patrons"][STANDING_PATRON]["lifecycle"], &"captured")
	assert_true(scenario.snapshot()["ownership_clean"])

	scenario.restart(10)
	scenario.add_patron(HALLWAY_PATRON, 0.0)
	scenario.add_patron(SEATED_PATRON, 100.0)
	scenario.add_patron(NEXT_PATRON, 100.0)
	scenario.force_bathroom_intent(SEATED_PATRON)
	scenario.force_bathroom_intent(NEXT_PATRON)
	scenario.advance(2.05)
	assert_eq(scenario.snapshot()["patrons"][SEATED_PATRON]["activity"], &"seated_use")
	assert_true(scenario.activate_trapdoor())
	var misfire: Dictionary = scenario.snapshot()
	assert_eq(float(misfire["patrons"][SEATED_PATRON]["suspicion"]), 100.0)
	assert_eq(misfire["patrons"][SEATED_PATRON]["activity"], &"seated_use")
	assert_eq(misfire["occupant_id"], SEATED_PATRON)
	assert_eq(float(misfire["patrons"][HALLWAY_PATRON]["suspicion"]), 0.0)
	assert_eq(misfire["patrons"][HALLWAY_PATRON]["activity"], &"normal")
	assert_true(scenario.cancel_actor(SEATED_PATRON))
	scenario.advance(1.0)
	assert_eq(scenario.snapshot()["patrons"][NEXT_PATRON]["lifecycle"], &"active")
	assert_eq(scenario.snapshot()["occupant_id"], NEXT_PATRON)
	assert_eq(scenario.snapshot()["trapdoor_eligible_occupant"], SEATED_PATRON)
	scenario.advance(4.1)
	assert_eq(scenario.snapshot()["trapdoor_state"], &"closed")

	scenario.restart(11)
	scenario.add_patron(MAX_DRUNK_PATRON, 100.0, true)
	scenario.force_bathroom_intent(MAX_DRUNK_PATRON)
	scenario.advance(2.05)
	scenario.activate_trapdoor()
	var max_drunk: Dictionary = scenario.snapshot()["patrons"][MAX_DRUNK_PATRON]
	assert_eq(float(max_drunk["suspicion"]), 25.0)
	assert_eq(max_drunk["suspicion_cause"], &"soft")

	scenario.restart(12)
	scenario.add_patron(SOBER_WITNESS, 100.0)
	scenario.force_bathroom_intent(SOBER_WITNESS)
	scenario.advance(2.05)
	scenario.activate_trapdoor()
	scenario.advance(11.05)
	var escaped_after_visit: Dictionary = scenario.snapshot()["patrons"][SOBER_WITNESS]
	assert_eq(escaped_after_visit["lifecycle"], &"escaping")
	assert_eq(escaped_after_visit["activity"], &"shock")


func test_missing_companion_reaches_investigation_intercept_and_defeat_once() -> void:
	var scenario_script := load(SCENARIO_PATH)
	var scenario = scenario_script.new()
	scenario.start(77)
	scenario.add_patron(MISSING_PATRON, 100.0, false, COMPANION)
	scenario.add_patron(COMPANION, 0.0, false, MISSING_PATRON)
	scenario.force_bathroom_intent(MISSING_PATRON)
	scenario.activate_trapdoor()

	scenario.advance(20.0)
	assert_almost_eq(float(scenario.snapshot()["patrons"][COMPANION]["suspicion"]), 25.0, 0.001)
	scenario.advance(10.0)
	assert_almost_eq(float(scenario.snapshot()["patrons"][COMPANION]["suspicion"]), 50.0, 0.001)
	scenario.advance(10.0)
	assert_eq(scenario.snapshot()["patrons"][COMPANION]["lifecycle"], &"investigating")
	assert_eq(scenario.snapshot()["occupant_id"], COMPANION)

	scenario.advance(5.05)
	assert_eq(scenario.snapshot()["patrons"][COMPANION]["lifecycle"], &"escaping")
	assert_eq(float(scenario.snapshot()["time_scale"]), 1.0)
	scenario.advance(2.05)
	assert_true(scenario.begin_intercept(COMPANION, ActorIds.CULTIST_IDS[0]))
	assert_false(scenario.begin_intercept(COMPANION, ActorIds.CULTIST_IDS[1]))
	scenario.advance(5.05)
	assert_false(scenario.snapshot()["active_intercept"].has("patron_id"))
	scenario.advance(6.05)
	assert_true(scenario.snapshot()["defeat"])
	assert_eq(scenario.snapshot()["patrons"][COMPANION]["lifecycle"], &"exited")
	assert_true(scenario.snapshot()["ownership_clean"])


func test_investigator_capture_cancellation_and_restart_release_ownership() -> void:
	var scenario_script := load(SCENARIO_PATH)
	var scenario = scenario_script.new()
	scenario.start(88)
	scenario.add_patron(MISSING_PATRON, 100.0, false, COMPANION)
	scenario.add_patron(COMPANION, 0.0, false, MISSING_PATRON)
	scenario.force_bathroom_intent(MISSING_PATRON)
	scenario.activate_trapdoor()
	scenario.advance(40.05)
	assert_eq(scenario.snapshot()["patrons"][COMPANION]["activity"], &"investigation_search")
	assert_true(scenario.activate_trapdoor())
	assert_eq(scenario.snapshot()["patrons"][COMPANION]["lifecycle"], &"captured")
	assert_true(scenario.snapshot()["ownership_clean"])

	scenario.restart(89)
	scenario.add_patron(OCCUPANT, 100.0)
	scenario.add_patron(QUEUED, 100.0)
	scenario.force_bathroom_intent(OCCUPANT)
	scenario.force_bathroom_intent(QUEUED)
	assert_true(scenario.cancel_actor(QUEUED))
	scenario.restart(90)
	var restarted: Dictionary = scenario.snapshot()
	assert_true(restarted["ownership_clean"])
	assert_true(restarted["patrons"].is_empty())
	assert_eq(restarted["trapdoor_state"], &"closed")
	assert_false(restarted["defeat"])
