extends GutTest

const SESSION_SCRIPT := preload("res://scripts/simulation/ordinary_visit_session.gd")


func test_group_gets_exclusive_seats_and_completes_service() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(43.9)
	var state: Dictionary = session.snapshot()
	assert_eq(state["seat_owners"].size(), 2)
	assert_ne(state["seat_owners"][&"seat_01"], state["seat_owners"][&"seat_02"])
	assert_eq(state["orders"]["revenue"], 10)
	assert_eq(state["orders"]["tips"], 4)
	assert_eq(state["normal_views"][ScenarioActors.opening_patron()]["order_state"], &"served")
	assert_eq(state["normal_views"][ScenarioActors.opening_companion()]["order_state"], &"served")


func test_seeded_bathroom_checks_are_five_seconds_apart_and_use_empties_bladder() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(178.9)
	var state: Dictionary = session.snapshot()
	var rolls: Array = state["debug_views"][ScenarioActors.opening_patron()]["recent_bathroom_rolls"]
	assert_gt(rolls.size(), 0)
	for index in range(1, rolls.size()):
		assert_almost_eq(float(rolls[index]["at"]) - float(rolls[index - 1]["at"]), 5.0, 0.001)
	assert_eq(state["debug_views"][ScenarioActors.opening_patron()]["bladder"], 0.0)
	assert_eq(state["bathroom_owner"], ActorIds.NO_ACTOR)
	assert_true(_has_event(state["events"], &"bathroom_visit_completed", ScenarioActors.opening_patron()))


func test_intoxication_progress_loses_one_point_each_forty_drink_free_seconds() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(43.9)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["intoxication_level"], 1)
	var decay_in := float(session.debug_patron_view(ScenarioActors.opening_patron())["intoxication_decay_in"])
	session.advance(decay_in - 0.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["intoxication_level"], 1)
	session.advance(0.2)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["intoxication_level"], 0)


func test_normal_view_excludes_hidden_values_and_debug_view_exposes_them() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(43.9)
	var normal: Dictionary = session.normal_patron_view(ScenarioActors.opening_patron())
	var debug: Dictionary = session.debug_patron_view(ScenarioActors.opening_patron())
	for hidden_key in ["bladder", "bathroom_probability", "next_bathroom_check_in", "intoxication_decay_in", "overdrink_limit", "excess_drinks", "night_seed", "recent_bathroom_rolls"]:
		assert_false(normal.has(hidden_key), "Normal view leaked %s" % hidden_key)
		assert_true(debug.has(hidden_key), "Debug view omitted %s" % hidden_key)
	assert_true(normal.has("visible_activity"))
	assert_true(normal.has("intoxication"))
	assert_true(normal.has("companions"))
	assert_true(normal.has("order_state"))


func test_debug_behavior_fields_are_one_machine_projection() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_patron()))
	for _transition in range(3):
		var view: Dictionary = session.debug_patron_view(ScenarioActors.opening_patron())
		assert_eq(view["activity"], view["behavior"]["state"])
		assert_eq(view["navigation_destination"], view["behavior"]["destination"])
		assert_eq(view["reservation"], view["behavior"]["reservation"])
		session.patron_destination_reached(ScenarioActors.opening_patron())
		session.advance(5.1)
	session.restart(707)
	var restarted: Dictionary = session.debug_patron_view(ScenarioActors.opening_patron())
	assert_eq(restarted["activity"], restarted["behavior"]["state"])
	assert_eq(restarted["navigation_destination"], restarted["behavior"]["destination"])


func test_completed_talk_identifies_patron_profile_for_the_whole_crew() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	var unknown: Dictionary = session.normal_patron_view(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0])
	assert_eq(unknown["name"], "???")
	assert_eq(unknown["arrival_group"], "???")
	assert_eq(unknown["victim_value"], "???")
	assert_eq(unknown["visible_activity"], "Waiting for drink")
	assert_true(session.begin_conversation(ActorIds.CULTIST_IDS[0], ScenarioActors.opening_patron()))
	assert_true(session.end_conversation(ActorIds.CULTIST_IDS[0]))
	var known_by_other_cultist: Dictionary = session.normal_patron_view(
		ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[2]
	)
	assert_true(known_by_other_cultist["identified"])
	assert_eq(known_by_other_cultist["name"], "June")
	assert_eq(known_by_other_cultist["arrival_group"], &"arrival_group_pair_01")
	assert_eq(known_by_other_cultist["victim_value"], "Ordinary")


func test_group_makes_normal_departure_and_releases_seats() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(548.9)
	var state: Dictionary = session.snapshot()
	assert_eq(state["normal_views"][ScenarioActors.opening_patron()]["visible_activity"], "Normal Departure")
	assert_eq(state["normal_views"][ScenarioActors.opening_companion()]["visible_activity"], "Normal Departure")
	assert_eq(state["seat_owners"][&"seat_01"], ActorIds.NO_ACTOR)
	assert_eq(state["seat_owners"][&"seat_02"], ActorIds.NO_ACTOR)
	assert_eq(_count_events(state["events"], &"normal_departure"), 2)


func test_physical_bathroom_phases_wait_for_navigation_thresholds() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	session.set_physical_navigation_enabled(true)
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_patron()))
	# Travel to the mirror waits for a real arrival; a timer alone never completes it.
	session.advance(30.0)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"entering_bathroom")
	assert_true(session.patron_destination_reached(ScenarioActors.opening_patron()))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"mirror_check")
	# The walk to the toilet also blocks until navigation reports arrival.
	session.advance(5.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"moving_to_toilet")
	session.advance(30.0)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"moving_to_toilet")
	assert_true(session.patron_destination_reached(ScenarioActors.opening_patron()))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"seated_bathroom_use")
	# The exit travel completes only on its own arrival, at the end of the visit.
	_walk_seated_to_handwashing(session, ScenarioActors.opening_patron())
	session.advance(5.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"standing_bathroom_exit")
	session.advance(30.0)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"standing_bathroom_exit")
	assert_true(session.patron_destination_reached(ScenarioActors.opening_patron()))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"socializing")


func test_physical_closing_departure_has_a_sixty_second_failsafe() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	session.debug_set_patron_drink_state(ScenarioActors.opening_patron(), 0, 5, 0, 0)
	session.debug_set_patron_drink_state(ScenarioActors.opening_companion(), 0, 5, 0, 0)
	session.set_physical_navigation_enabled(true)
	session.begin_closing()
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"leaving")
	session.advance(59.9)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"leaving")
	session.advance(0.2)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"exited")


func test_bathroom_line_has_one_waiting_position_and_promotes_its_owner() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_patron()))
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_companion()))
	var queued: Dictionary = session.snapshot()
	assert_eq(queued["bathroom_owner"], ScenarioActors.opening_patron())
	assert_eq(queued["bathroom_line_owner"], ScenarioActors.opening_companion())
	assert_eq(queued["debug_views"][ScenarioActors.opening_companion()]["activity"], &"bathroom_queued")
	# June now runs the full Mirror -> Toilet -> Sink visit before the room frees,
	# so the line promotes its one waiting Patron only once that visit completes.
	session.advance(40.0)
	var promoted: Dictionary = session.snapshot()
	assert_eq(promoted["bathroom_owner"], ScenarioActors.opening_companion())
	assert_eq(promoted["bathroom_line_owner"], ActorIds.NO_ACTOR)
	assert_true(promoted["debug_views"][ScenarioActors.opening_companion()]["activity"] in [
		&"entering_bathroom", &"mirror_check", &"moving_to_toilet",
		&"seated_bathroom_use", &"moving_to_sink", &"handwashing", &"standing_bathroom_exit",
	], "The promoted Patron has entered the bathroom for their own visit.")


func test_ideal_intoxication_and_overdrink_limits_are_seeded_and_bounded() -> void:
	var ideals: Array[int] = []
	var sober_count := 0
	for seed in range(100, 600):
		var session = SESSION_SCRIPT.new()
		session.start(seed)
		var debug: Dictionary = session.debug_patron_view(ScenarioActors.opening_patron())
		var ideal: int = debug["ideal_intoxication_level"]
		ideals.append(ideal)
		sober_count += 1 if ideal == 0 else 0
		assert_between(ideal, 0, 3)
		assert_between(int(debug["overdrink_limit"]), 1, 5)
	var mean := float(ideals.reduce(func(total, value): return total + value, 0)) / ideals.size()
	assert_between(mean, 1.8, 2.2)
	assert_gt(sober_count, 0, "Sober Ideal Intoxication is rare, but possible.")
	var replay = SESSION_SCRIPT.new()
	replay.start(100)
	assert_eq(replay.debug_patron_view(ScenarioActors.opening_patron())["ideal_intoxication_level"], ideals[0])


func test_failed_orders_change_mood_and_suspicion_then_second_failure_leaves() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_set_neutral_opening_traits(session)
	session.advance(1.1)
	assert_true(session.debug_set_patron_drink_state(ScenarioActors.opening_patron(), 0, 5, 0, 3))
	assert_true(session.debug_set_patron_drink_state(ScenarioActors.opening_companion(), 0, 5, 0, 0))
	# The debug setup cancels the opening Order, so let the next routine Order start.
	session.advance(40.1)
	assert_eq(session.normal_patron_view(ScenarioActors.opening_patron())["order_state"], &"open")
	session.advance(60.1)
	var first: Dictionary = session.debug_patron_view(ScenarioActors.opening_patron())
	assert_true(_has_event_with_detail(
		session.snapshot()["events"], &"order_failed",
		ScenarioActors.opening_patron(), "failed_orders", 1
	), "The Order failure remains explicit while Grime pressure also changes mood.")
	assert_lt(float(first["satisfaction_value"]), 55.0)
	assert_eq(first["suspicion"], 5.0)
	session.advance(40.1)
	session.advance(60.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"exited")


func test_refused_free_drink_is_discarded() -> void:
	var refused_session = null
	for seed in range(100, 200):
		var candidate = SESSION_SCRIPT.new()
		candidate.start(seed)
		candidate.advance(1.1)
		assert_true(candidate.prepare_drink(ActorIds.CULTIST_IDS[0]))
		candidate.debug_set_patron_drink_state(ScenarioActors.opening_patron(), 0, 5, 0, 0)
		var drink_id: StringName = candidate.snapshot()["prepared_drinks"]["drinks"][0]["id"]
		assert_true(candidate.reserve_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0]))
		assert_true(candidate.pick_up_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0]))
		if candidate.serve_prepared_drink(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0], drink_id)["reason"] == &"refused":
			refused_session = candidate
			break
	assert_not_null(refused_session, "The seeded 20% refusal path must be reachable.")
	if refused_session == null:
		return
	assert_false(refused_session.carries_prepared_drink(ActorIds.CULTIST_IDS[0]),
		"A refused free drink is discarded after the Patron sees it.")
	assert_true(refused_session.snapshot()["prepared_drinks"]["drinks"].is_empty())


func test_overdrink_collapse_uses_excess_limit_and_mood_instead_of_body_suspicion() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_set_patron_drink_state(ScenarioActors.opening_patron(), 3, 1, 0, 3))
	var accepted := false
	for _attempt in range(10):
		var offer: Dictionary = session.offer_drink(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0])
		if offer["accepted"]:
			accepted = true
			break
		session.advance(60.1)
	assert_true(accepted)
	assert_true(session.debug_force_finish_drink(ScenarioActors.opening_patron()))
	var state: Dictionary = session.snapshot()
	var subject: Dictionary = state["debug_views"][ScenarioActors.opening_patron()]
	var companion: Dictionary = state["debug_views"][ScenarioActors.opening_companion()]
	assert_eq(subject["lifecycle"], &"unconscious")
	assert_eq(subject["collapse_cause"], &"overdrink")
	assert_eq(subject["excess_drinks"], 1)
	assert_lte(float(companion["satisfaction_value"]), 60.0)
	assert_eq(companion["suspicion"], 0.0)
	assert_false(session.normal_patron_view(ScenarioActors.opening_patron()).has("overdrink_limit"))


func test_miserable_companion_does_not_become_collapse_helper() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_change_patron_satisfaction(ScenarioActors.opening_companion(), -60.0))
	assert_true(session.debug_set_patron_drink_state(ScenarioActors.opening_patron(), 3, 1, 0, 3))
	for _attempt in range(10):
		if session.offer_drink(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0])["accepted"]:
			break
		session.advance(60.1)
	assert_true(session.debug_force_finish_drink(ScenarioActors.opening_patron()))
	session.advance(2.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_companion())["satisfaction_band"], "Miserable")
	assert_eq(session.snapshot()["collapses"][ScenarioActors.opening_patron()]["phase"], &"unattended")


# --- Bathroom Visit: Mirror Check -> Seated Bathroom Use -> Handwashing --------
# The visit stands and travels through four stations. Only the seated toilet phase
# protects the Patron from the Trapdoor. Physical-navigation tests control each
# arrival explicitly; a timer never pretends an actor reached a station.

func test_bathroom_arrival_starts_mirror_check_not_seated_use() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	session.set_physical_navigation_enabled(true)
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_patron()))
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"entering_bathroom")
	assert_true(session.patron_destination_reached(ScenarioActors.opening_patron()))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"mirror_check",
		"Bathroom arrival starts Mirror Check, not Seated Bathroom Use.")


func test_mirror_check_lasts_five_seconds_then_travels_to_the_toilet() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_into_mirror_check(session, ScenarioActors.opening_patron())
	session.advance(4.8)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"mirror_check")
	session.advance(0.3)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"moving_to_toilet",
		"Mirror Check lasts five seconds, then the Patron walks to the toilet.")


func test_toilet_arrival_starts_seated_use_and_empties_bladder_at_its_end() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_into_mirror_check(session, ScenarioActors.opening_patron())
	session.advance(5.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"moving_to_toilet")
	assert_true(session.patron_destination_reached(ScenarioActors.opening_patron()))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"seated_bathroom_use")
	var use_seconds: float = session.debug_patron_view(ScenarioActors.opening_patron()).get("bathroom_use_seconds", -1.0)
	assert_between(use_seconds, 8.0, 15.0)
	session.advance(use_seconds + 0.1)
	var view: Dictionary = session.debug_patron_view(ScenarioActors.opening_patron())
	assert_eq(view["activity"], &"moving_to_sink",
		"Seated Bathroom Use ends into the walk to the sink.")
	assert_eq(float(view["bladder"]), 0.0, "Seated Bathroom Use empties Bladder at its end.")
	assert_true(_has_event(session.snapshot()["events"], &"bladder_emptied", ScenarioActors.opening_patron()),
		"The Bladder empties exactly at the end of Seated Bathroom Use.")


func test_seated_bathroom_duration_is_a_seeded_whole_number_sampled_once() -> void:
	var first: float = _sampled_bathroom_use_seconds(707)
	var again: float = _sampled_bathroom_use_seconds(707)
	assert_eq(first, again, "The seeded Seated Bathroom Use duration is reproducible.")
	assert_between(first, 8.0, 15.0)
	assert_eq(first, floorf(first), "Seated Bathroom Use lasts a whole number of seconds.")


func test_sink_arrival_starts_handwashing_for_five_seconds() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_into_handwashing(session, ScenarioActors.opening_patron())
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"handwashing")
	session.advance(4.8)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"handwashing")
	session.advance(0.3)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"standing_bathroom_exit",
		"Handwashing lasts five seconds, then the Patron leaves the bathroom.")


func test_full_bathroom_visit_releases_the_room_and_promotes_the_line_once() -> void:
	var session = SESSION_SCRIPT.new()
	_start_physical_session(session)
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_patron()))
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_companion()))
	assert_eq(session.snapshot()["bathroom_line_owner"], ScenarioActors.opening_companion())
	_walk_entering_to_mirror(session, ScenarioActors.opening_patron())
	_walk_mirror_to_seated(session, ScenarioActors.opening_patron())
	_walk_seated_to_handwashing(session, ScenarioActors.opening_patron())
	_walk_handwashing_to_socializing(session, ScenarioActors.opening_patron())
	var state: Dictionary = session.snapshot()
	assert_eq(_count_events(state["events"], &"bathroom_visit_completed"), 1)
	assert_eq(state["bathroom_owner"], ScenarioActors.opening_companion(),
		"Exit completion releases the room and promotes the one waiting Patron.")
	assert_eq(state["bathroom_line_owner"], ActorIds.NO_ACTOR)
	assert_eq(state["debug_views"][ScenarioActors.opening_companion()]["activity"], &"entering_bathroom")


func test_every_standing_bathroom_phase_is_trapdoor_vulnerable() -> void:
	for phase: StringName in [
		&"entering_bathroom", &"mirror_check", &"moving_to_toilet",
		&"moving_to_sink", &"handwashing", &"standing_bathroom_exit",
	]:
		var session = SESSION_SCRIPT.new()
		_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), phase)
		assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], phase,
			"Setup reached %s" % phase)
		assert_true(session.activate_trapdoor())
		assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"trapdoor_falling",
			"%s is a standing phase and begins the Trapdoor fall." % phase)
		session.advance(1.1)  # Fall then panels close.
		assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"captured",
			"%s is captured once the Trapdoor panels close." % phase)


func test_only_seated_bathroom_use_is_protected_from_the_trapdoor() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"seated_bathroom_use")
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"seated_bathroom_use")
	assert_true(session.activate_trapdoor())
	assert_ne(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"captured",
		"A seated Patron is protected from the Trapdoor.")
	assert_true(_has_event(session.snapshot()["events"], &"trapdoor_seated_evidence", ScenarioActors.opening_patron()))


func test_a_stale_arrival_flag_cannot_complete_a_later_travel_station() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"seated_bathroom_use")
	var use_seconds: float = session.debug_patron_view(ScenarioActors.opening_patron()).get("bathroom_use_seconds", 12.0)
	# Fire a stale arrival while seated, then leave the toilet without a fresh one.
	session.patron_destination_reached(ScenarioActors.opening_patron())
	session.advance(use_seconds + 0.1)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"moving_to_sink")
	session.advance(30.0)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"moving_to_sink",
		"A travel station never completes on a stale arrival flag or a timer alone.")


func test_restart_clears_bathroom_visit_and_trapdoor_state() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"seated_bathroom_use")
	assert_ne(session.snapshot()["bathroom_owner"], ActorIds.NO_ACTOR)
	session.restart(707)
	var state: Dictionary = session.snapshot()
	assert_eq(state["bathroom_owner"], ActorIds.NO_ACTOR)
	assert_eq(state["trapdoor"]["state"], &"closed")
	# The legacy pair arrives immediately, so a clean restart returns June to the
	# fresh arrival state with no bathroom phase, sampled duration, or capture left.
	assert_eq(state["debug_views"][ScenarioActors.opening_patron()]["activity"], &"entering")
	assert_eq(float(state["debug_views"][ScenarioActors.opening_patron()]["bathroom_use_seconds"]), 0.0)


# --- Trapdoor: finite capture lifecycle and door lock -------------------------

func test_standing_capture_falls_then_closes_then_becomes_terminal_after_closure() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"mirror_check")
	assert_true(session.activate_trapdoor())
	var falling: Dictionary = session.snapshot()["trapdoor"]
	assert_eq(falling["state"], &"falling")
	assert_eq(falling["falling_patron"], ScenarioActors.opening_patron())
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["activity"], &"trapdoor_falling")
	assert_ne(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"captured",
		"The falling Patron is not terminal until the panels close.")
	assert_eq(session.snapshot()["bathroom_owner"], ScenarioActors.opening_patron(),
		"The bathroom stays reserved through the fall.")
	# The fall is bounded, then the panels close.
	session.advance(0.61)
	assert_eq(session.snapshot()["trapdoor"]["state"], &"closing")
	assert_ne(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"captured")
	assert_eq(session.snapshot()["bathroom_owner"], ScenarioActors.opening_patron())
	# Final removal and slot release happen only after the panels finish closing.
	session.advance(0.41)
	assert_eq(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"captured")
	assert_eq(session.snapshot()["bathroom_owner"], ActorIds.NO_ACTOR)
	assert_eq(session.snapshot()["captures"].size(), 1)


func test_trapdoor_fall_ratio_is_bounded_and_clamps_at_one() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"handwashing")
	assert_true(session.activate_trapdoor())
	session.advance(0.3)
	var mid: float = float(session.snapshot()["trapdoor"]["fall_ratio"])
	assert_between(mid, 0.0, 1.0)
	session.advance(5.0)
	assert_lte(float(session.snapshot()["trapdoor"]["fall_ratio"]), 1.0,
		"The fall ratio clamps at 1.0 and never continues downward.")


func test_seated_misfire_applies_evidence_once_and_never_captures() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"seated_bathroom_use")
	assert_true(session.activate_trapdoor())
	assert_ne(session.debug_patron_view(ScenarioActors.opening_patron())["lifecycle"], &"captured")
	assert_eq(session.snapshot()["trapdoor"]["falling_patron"], ActorIds.NO_ACTOR)
	assert_eq(_count_events(session.snapshot()["events"], &"trapdoor_seated_evidence"), 1,
		"A seated misfire records Hard Evidence exactly once.")
	session.advance(5.0)
	assert_eq(session.snapshot()["captures"].size(), 0)


func test_a_queued_patron_promotes_only_after_the_panels_close() -> void:
	var session = SESSION_SCRIPT.new()
	_start_physical_session(session)
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_patron()))
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_companion()))
	assert_true(session.activate_trapdoor())  # June stands in entering_bathroom; capture begins.
	# While the panels are open or closing, the door stays locked and Mara waits.
	session.advance(0.61)
	assert_eq(session.snapshot()["trapdoor"]["state"], &"closing")
	assert_eq(session.snapshot()["debug_views"][ScenarioActors.opening_companion()]["activity"], &"bathroom_queued")
	# After closure the room frees and the one waiting Patron promotes.
	session.advance(0.5)
	assert_eq(session.snapshot()["bathroom_owner"], ScenarioActors.opening_companion())
	assert_eq(session.snapshot()["debug_views"][ScenarioActors.opening_companion()]["activity"], &"entering_bathroom")


func test_an_investigator_cannot_claim_the_bathroom_while_it_is_locked() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"mirror_check")
	# A single missing-Companion maximum drives Mara to investigate the bathroom.
	assert_true(session.apply_suspicion_stimulus(ScenarioActors.opening_companion(), &"missing_companion_40"))
	assert_true(session.activate_trapdoor())  # June begins falling; the bathroom locks.
	assert_true(bool(session.snapshot()["trapdoor"]["locked"]))
	session.advance(0.1)
	assert_eq(session.snapshot()["debug_views"][ScenarioActors.opening_companion()]["activity"], &"waiting_investigation",
		"No investigator claims the bathroom while the Trapdoor is open or closing.")


func test_repeated_activation_is_rejected_through_open_falling_closing_and_cooldown() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"mirror_check")
	assert_true(session.activate_trapdoor())
	assert_false(session.activate_trapdoor(), "Rejected while falling.")
	session.advance(0.61)
	assert_false(session.activate_trapdoor(), "Rejected while closing.")
	session.advance(0.41)
	assert_false(session.activate_trapdoor(), "Rejected during the control cooldown.")
	session.advance(3.1)
	assert_eq(session.snapshot()["trapdoor"]["state"], &"closed")


func test_activation_never_captures_a_patron_who_entered_after_the_snapshot() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"seated_bathroom_use")
	# Seated June is a protected misfire, so the snapshot arms no one.
	assert_true(session.activate_trapdoor())
	# Let the whole open/close/cooldown pass; no one is captured by that activation.
	session.advance(6.0)
	assert_eq(session.snapshot()["captures"].size(), 0,
		"An activation only ever acts on the occupant it snapshotted.")


func test_activation_with_no_occupant_opens_and_closes_without_a_capture() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_eq(session.snapshot()["bathroom_owner"], ActorIds.NO_ACTOR)
	assert_true(session.activate_trapdoor())
	assert_eq(session.snapshot()["trapdoor"]["state"], &"open")
	assert_eq(session.snapshot()["trapdoor"]["falling_patron"], ActorIds.NO_ACTOR)
	# The empty pulse holds open, closes, then cools down; no one is captured.
	session.advance(2.1)
	assert_eq(session.snapshot()["trapdoor"]["state"], &"closing")
	session.advance(3.5)
	assert_eq(session.snapshot()["trapdoor"]["state"], &"closed")
	assert_eq(session.snapshot()["captures"].size(), 0)


func test_restart_clears_every_trapdoor_and_pending_capture_field() -> void:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"mirror_check")
	assert_true(session.activate_trapdoor())
	assert_eq(session.snapshot()["trapdoor"]["state"], &"falling")
	session.restart(707)
	var trap: Dictionary = session.snapshot()["trapdoor"]
	assert_eq(trap["state"], &"closed")
	assert_eq(trap["falling_patron"], ActorIds.NO_ACTOR)
	assert_eq(trap["eligible_occupant"], ActorIds.NO_ACTOR)
	assert_false(bool(trap["locked"]))


# --- Bathroom test drivers -----------------------------------------------------
# Setup and walking are separate so a test can stage its own occupants (a queued
# Companion, say) and then walk one Patron through the visit without a restart.

func _start_physical_session(session) -> void:
	session.start(707)
	session.advance(1.1)
	session.set_physical_navigation_enabled(true)


func _arrive(session, patron_id: int) -> void:
	assert_true(session.patron_destination_reached(patron_id))
	session.advance(0.1)


func _walk_entering_to_mirror(session, patron_id: int) -> void:
	_arrive(session, patron_id)  # Reach the mirror; Mirror Check begins.


func _walk_mirror_to_seated(session, patron_id: int) -> void:
	session.advance(5.1)  # Mirror Check completes; walk to the toilet begins.
	_arrive(session, patron_id)  # Reach the toilet; Seated Bathroom Use begins.


func _walk_seated_to_handwashing(session, patron_id: int) -> void:
	var use_seconds: float = session.debug_patron_view(patron_id).get("bathroom_use_seconds", 12.0)
	session.advance(use_seconds + 0.1)  # Seated Use completes; walk to the sink begins.
	_arrive(session, patron_id)  # Reach the sink; Handwashing begins.


func _walk_handwashing_to_socializing(session, patron_id: int) -> void:
	session.advance(5.1)  # Handwashing completes; walk to the exit begins.
	_arrive(session, patron_id)  # Reach the exit; the visit completes.


func _drive_into_mirror_check(session, patron_id: int) -> void:
	_start_physical_session(session)
	assert_true(session.debug_force_bathroom(patron_id))
	_walk_entering_to_mirror(session, patron_id)


func _drive_into_seated_use(session, patron_id: int) -> void:
	_drive_into_mirror_check(session, patron_id)
	_walk_mirror_to_seated(session, patron_id)


func _drive_into_handwashing(session, patron_id: int) -> void:
	_drive_into_seated_use(session, patron_id)
	_walk_seated_to_handwashing(session, patron_id)


func _drive_to_bathroom_phase(session, patron_id: int, phase: StringName) -> void:
	match phase:
		&"entering_bathroom":
			_start_physical_session(session)
			assert_true(session.debug_force_bathroom(patron_id))
		&"mirror_check":
			_drive_into_mirror_check(session, patron_id)
		&"moving_to_toilet":
			_drive_into_mirror_check(session, patron_id)
			session.advance(5.1)
		&"seated_bathroom_use":
			_drive_into_seated_use(session, patron_id)
		&"moving_to_sink":
			_drive_into_seated_use(session, patron_id)
			var use_seconds: float = session.debug_patron_view(patron_id).get("bathroom_use_seconds", 12.0)
			session.advance(use_seconds + 0.1)
		&"handwashing":
			_drive_into_handwashing(session, patron_id)
		&"standing_bathroom_exit":
			_drive_into_handwashing(session, patron_id)
			session.advance(5.1)


func _sampled_bathroom_use_seconds(_seed: int) -> float:
	var session = SESSION_SCRIPT.new()
	_drive_to_bathroom_phase(session, ScenarioActors.opening_patron(), &"seated_bathroom_use")
	return session.debug_patron_view(ScenarioActors.opening_patron()).get("bathroom_use_seconds", -1.0)


func _has_event(events: Array, event_name: StringName, actor_id: int) -> bool:
	for event: Dictionary in events:
		if event["event"] == event_name and event["actor_id"] == actor_id:
			return true
	return false


func _serve_opening_orders(session) -> void:
	_set_neutral_opening_traits(session)
	session.advance(1.1)
	assert_true(session.serve_patron_order(ScenarioActors.opening_patron()))
	assert_true(session.serve_patron_order(ScenarioActors.opening_companion()))


func _set_neutral_opening_traits(session) -> void:
	assert_true(session.debug_set_patron_traits(ScenarioActors.opening_patron(), [&"wine_drinker"]))
	assert_true(session.debug_set_patron_traits(ScenarioActors.opening_companion(), [&"beer_drinker"]))


func _count_events(events: Array, event_name: StringName) -> int:
	var count := 0
	for event: Dictionary in events:
		if event["event"] == event_name:
			count += 1
	return count


func _has_event_with_detail(
		events: Array, event_name: StringName, actor_id: int, key: String, value: Variant
) -> bool:
	for event: Dictionary in events:
		if (
			event["event"] == event_name
			and event["actor_id"] == actor_id
			and event.get("details", {}).get(key) == value
		):
			return true
	return false
