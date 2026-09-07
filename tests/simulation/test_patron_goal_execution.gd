extends GutTest
const SESSION = preload("res://scripts/simulation/ordinary_visit_session.gd")

func test_failed_attack_interrupts_investigation_before_any_bathroom_routine() -> void:
	var session = SESSION.new()
	session.start(1)
	session.advance(1.1)
	var patron := ScenarioActors.opening_companion()
	# Establish the same missing-friend knowledge through the perception input.
	for count in range(4):
		session.apply_suspicion_stimulus(patron, &"missing_companion_40")
	session.advance(0.1)
	assert_eq(session.debug_patron_view(patron)["lifecycle"], &"investigating")
	assert_true(session.begin_knockout(ActorIds.CULTIST_IDS[0], patron))
	session.advance(2.1)
	assert_true(session.cultist_is_incapacitated(ActorIds.CULTIST_IDS[0]))
	assert_eq(session.debug_patron_view(patron)["lifecycle"], &"escaping")
	assert_eq(session.debug_patron_view(patron)["activity"], &"shock")
	session.advance(3)
	assert_eq(session.debug_patron_view(patron)["activity"], &"escaping")
	for event: Dictionary in session.snapshot()["events"]:
		if is_same(event["actor_id"], patron):
			assert_ne(event["event"], &"bathroom_handwashing")


func _investigator(physical: bool = true):
	var session = SESSION.new()
	session.start(1)
	session.advance(1.1)
	session.set_physical_navigation_enabled(physical)
	session.apply_suspicion_stimulus(ScenarioActors.opening_companion(), &"missing_companion_40")
	session.advance(0.1)
	return session


func _action_id(session, patron: int) -> int:
	return int(session.character_actions().active_request(patron)["id"])


func test_search_requires_actual_arrival_and_uses_its_own_clock() -> void:
	var session = _investigator()
	var patron := ScenarioActors.opening_companion()
	var travel := _action_id(session, patron)
	session.advance(12)
	assert_eq(session.debug_patron_view(patron)["activity"], &"investigation_travel")
	assert_false(session.debug_patron_view(patron)["goal_planner"]["facts"]["searched"])
	assert_true(session.patron_destination_reached(patron, travel))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(patron)["activity"], &"investigation_search")
	assert_lt(session.debug_patron_view(patron)["behavior"]["elapsed_seconds"], 0.2)
	assert_false(session.patron_destination_reached(patron, travel))
	session.advance(4.8)
	assert_eq(session.debug_patron_view(patron)["lifecycle"], &"investigating")
	session.advance(0.3)
	assert_eq(session.debug_patron_view(patron)["lifecycle"], &"escaping")
	assert_eq(session.snapshot()["bathroom_owner"], ActorIds.NO_ACTOR)


func test_navigation_failure_does_not_discover_trapdoor_or_expose_operation() -> void:
	var session = _investigator()
	var patron := ScenarioActors.opening_companion()
	for attempt in range(3):
		var action := _action_id(session, patron)
		assert_true(session.patron_navigation_failed(patron, action))
		assert_false(session.patron_destination_reached(patron, action))
		assert_eq(session.snapshot()["bathroom_owner"], ActorIds.NO_ACTOR)
		session.advance(2.1)
	assert_eq(session.debug_patron_view(patron)["goal_planner"]["status"], &"blocked")
	var count: int = session.debug_patron_view(patron)["goal_planner"]["planning_count"]
	session.advance(10)
	assert_eq(session.debug_patron_view(patron)["goal_planner"]["planning_count"], count)
	assert_false(session.debug_patron_view(patron)["goal_planner"]["facts"]["searched"])
	session.navigation_changed()
	session.advance(0.1)
	assert_eq(session.debug_patron_view(patron)["activity"], &"investigation_travel")
	assert_gt(session.debug_patron_view(patron)["goal_planner"]["planning_count"], count)


func test_occupied_bathroom_blocks_plan_until_world_changes() -> void:
	var session = SESSION.new()
	session.start(1)
	session.advance(1.1)
	session.set_physical_navigation_enabled(true)
	var occupant := ScenarioActors.opening_patron()
	var investigator := ScenarioActors.opening_companion()
	session.debug_force_bathroom(occupant)
	session.apply_suspicion_stimulus(investigator, &"missing_companion_40")
	session.advance(7)
	assert_eq(session.snapshot()["bathroom_owner"], occupant)
	assert_eq(session.debug_patron_view(investigator)["goal_planner"]["status"], &"blocked")
	assert_true(session.activate_trapdoor())
	session.advance(1.1)
	assert_eq(session.snapshot()["bathroom_owner"], investigator)
	assert_eq(session.debug_patron_view(investigator)["activity"], &"investigation_travel")


func test_captured_investigator_cannot_resume_or_accept_stale_completion() -> void:
	var session = _investigator()
	var patron := ScenarioActors.opening_companion()
	var travel := _action_id(session, patron)
	assert_true(session.activate_trapdoor())
	session.advance(1.1)
	assert_eq(session.debug_patron_view(patron)["lifecycle"], &"captured")
	assert_eq(session.debug_patron_view(patron)["goal_planner"]["goal"], &"")
	assert_false(session.patron_destination_reached(patron, travel))
	session.advance(10)
	assert_eq(session.debug_patron_view(patron)["lifecycle"], &"captured")


func test_blocked_escape_keeps_escape_goal_and_only_arrival_exposes_operation() -> void:
	var session = _investigator()
	var patron := ScenarioActors.opening_companion()
	assert_true(session.apply_suspicion_stimulus(patron, &"knockout_witnessed"))
	session.advance(2.2)
	assert_eq(session.debug_patron_view(patron)["activity"], &"escaping")
	var movement := _action_id(session, patron)
	assert_true(session.patron_navigation_failed(patron, movement))
	assert_eq(session.debug_patron_view(patron)["goal_planner"]["goal"], &"escape")
	assert_eq(session.patron_emote_row(patron)["state"], &"escaping")
	session.advance(2.1)
	assert_false(session.snapshot()["defeat"])
	assert_true(session.patron_destination_reached(patron, _action_id(session, patron)))
	session.advance(0.1)
	assert_true(session.snapshot()["defeat"])


func test_interception_resumes_leave_without_repeating_shock() -> void:
	var session = _investigator()
	var patron := ScenarioActors.opening_companion()
	session.apply_suspicion_stimulus(patron, &"knockout_witnessed")
	session.advance(2.2)
	var old_action := _action_id(session, patron)
	assert_true(session.begin_intercept(patron, ActorIds.CULTIST_IDS[0]))
	session.advance(1)
	assert_eq(session.debug_patron_view(patron)["activity"], &"intercepted")
	assert_true(session.cancel_intercept())
	assert_eq(session.debug_patron_view(patron)["activity"], &"escaping")
	assert_ne(_action_id(session, patron), old_action)
	assert_false(session.patron_destination_reached(patron, old_action))
	assert_true(session.patron_destination_reached(patron, _action_id(session, patron)))
	session.advance(0.1)
	assert_true(session.snapshot()["defeat"])


func test_danger_interrupts_each_bathroom_phase_and_releases_reservations() -> void:
	for phase: StringName in [&"entering_bathroom", &"mirror_check", &"moving_to_toilet",
			&"seated_bathroom_use", &"moving_to_sink", &"handwashing", &"standing_bathroom_exit"]:
		var session = SESSION.new()
		session.start(1)
		session.advance(1.1)
		var patron := ScenarioActors.opening_patron()
		session.debug_force_bathroom(patron)
		for tick in range(600):
			if session.debug_patron_view(patron)["activity"] == phase:
				break
			session.advance(0.1)
		assert_eq(session.debug_patron_view(patron)["activity"], phase)
		session.apply_suspicion_stimulus(patron, &"knockout_witnessed")
		session.advance(0.1)
		assert_eq(session.debug_patron_view(patron)["activity"], &"shock", str(phase))
		assert_eq(session.snapshot()["bathroom_owner"], ActorIds.NO_ACTOR)
		assert_true(session.debug_patron_view(patron)["behavior"]["deferred"].is_empty())


func test_observed_companion_return_invalidates_investigation() -> void:
	var session = SESSION.new()
	session.start(1)
	session.advance(1.1)
	var companion := ScenarioActors.opening_patron()
	var investigator := ScenarioActors.opening_companion()
	session.debug_force_bathroom(companion)
	session.apply_suspicion_stimulus(investigator, &"missing_companion_40")
	session.advance(0.1)
	assert_eq(session.debug_patron_view(investigator)["lifecycle"], &"investigating")
	for tick in range(600):
		if session.debug_patron_view(investigator)["missing_target"] == ActorIds.NO_ACTOR:
			break
		session.advance(0.1)
	assert_eq(session.debug_patron_view(investigator)["goal_planner"]["reason"], &"companion_returned")
	assert_eq(session.debug_patron_view(investigator)["lifecycle"], &"active")
	assert_eq(session.debug_patron_view(investigator)["goal_planner"]["goal"], &"")
	session.advance(0.2)
	assert_eq(session.debug_patron_view(investigator)["goal_planner"]["goal"], &"",
		"Old missing-Companion Suspicion cannot restart a resolved investigation.")
