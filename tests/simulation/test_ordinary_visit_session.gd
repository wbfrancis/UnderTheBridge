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
	assert_eq(state["orders"]["tips"], 6)
	assert_eq(state["normal_views"][&"patron_june"]["order_state"], &"served")
	assert_eq(state["normal_views"][&"patron_mara"]["order_state"], &"served")


func test_seeded_bathroom_checks_are_five_seconds_apart_and_use_empties_bladder() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(178.9)
	var state: Dictionary = session.snapshot()
	var rolls: Array = state["debug_views"][&"patron_june"]["recent_bathroom_rolls"]
	assert_gt(rolls.size(), 0)
	for index in range(1, rolls.size()):
		assert_almost_eq(float(rolls[index]["at"]) - float(rolls[index - 1]["at"]), 5.0, 0.001)
	assert_eq(state["debug_views"][&"patron_june"]["bladder"], 0.0)
	assert_eq(state["bathroom_owner"], &"")
	assert_true(_has_event(state["events"], &"bathroom_visit_completed", &"patron_june"))


func test_intoxication_rises_then_decays_after_four_drink_free_minutes() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(43.9)
	assert_eq(session.debug_patron_view(&"patron_june")["intoxication_level"], 1)
	session.advance(225.0)
	assert_eq(session.debug_patron_view(&"patron_june")["intoxication_level"], 1)
	session.advance(2.0)
	assert_eq(session.debug_patron_view(&"patron_june")["intoxication_level"], 0)


func test_normal_view_excludes_hidden_values_and_debug_view_exposes_them() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	_serve_opening_orders(session)
	session.advance(43.9)
	var normal: Dictionary = session.normal_patron_view(&"patron_june")
	var debug: Dictionary = session.debug_patron_view(&"patron_june")
	for hidden_key in ["bladder", "bathroom_probability", "next_bathroom_check_in", "intoxication_decay_in", "overdrink_limit", "excess_drinks", "night_seed", "recent_bathroom_rolls"]:
		assert_false(normal.has(hidden_key), "Normal view leaked %s" % hidden_key)
		assert_true(debug.has(hidden_key), "Debug view omitted %s" % hidden_key)
	assert_true(normal.has("visible_activity"))
	assert_true(normal.has("intoxication"))
	assert_true(normal.has("companions"))
	assert_true(normal.has("order_state"))


func test_completed_talk_identifies_patron_profile_for_the_whole_crew() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	var unknown: Dictionary = session.normal_patron_view(&"patron_june", &"cultist_01")
	assert_eq(unknown["name"], "???")
	assert_eq(unknown["arrival_group"], "???")
	assert_eq(unknown["victim_value"], "???")
	assert_eq(unknown["visible_activity"], "Waiting for drink")
	assert_true(session.begin_conversation(&"cultist_01", &"patron_june"))
	assert_true(session.end_conversation(&"cultist_01"))
	var known_by_other_cultist: Dictionary = session.normal_patron_view(
		&"patron_june", &"cultist_03"
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
	assert_eq(state["normal_views"][&"patron_june"]["visible_activity"], "Normal Departure")
	assert_eq(state["normal_views"][&"patron_mara"]["visible_activity"], "Normal Departure")
	assert_eq(state["seat_owners"][&"seat_01"], &"")
	assert_eq(state["seat_owners"][&"seat_02"], &"")
	assert_eq(_count_events(state["events"], &"normal_departure"), 2)


func test_physical_bathroom_phases_wait_for_navigation_thresholds() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	session.set_physical_navigation_enabled(true)
	assert_true(session.debug_force_bathroom(&"patron_june"))
	session.advance(30.0)
	assert_eq(session.debug_patron_view(&"patron_june")["activity"], &"entering_bathroom")
	assert_true(session.patron_destination_reached(&"patron_june"))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(&"patron_june")["activity"], &"seated_bathroom_use")
	session.advance(8.1)
	assert_eq(session.debug_patron_view(&"patron_june")["activity"], &"standing_bathroom_exit")
	session.advance(30.0)
	assert_eq(session.debug_patron_view(&"patron_june")["activity"], &"standing_bathroom_exit")
	assert_true(session.patron_destination_reached(&"patron_june"))
	session.advance(0.1)
	assert_eq(session.debug_patron_view(&"patron_june")["activity"], &"socializing")


func test_physical_closing_departure_has_a_sixty_second_failsafe() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	session.debug_set_patron_drink_state(&"patron_june", 0, 5, 0, 0)
	session.debug_set_patron_drink_state(&"patron_mara", 0, 5, 0, 0)
	session.set_physical_navigation_enabled(true)
	session.begin_closing()
	assert_eq(session.debug_patron_view(&"patron_june")["lifecycle"], &"leaving")
	session.advance(59.9)
	assert_eq(session.debug_patron_view(&"patron_june")["lifecycle"], &"leaving")
	session.advance(0.2)
	assert_eq(session.debug_patron_view(&"patron_june")["lifecycle"], &"exited")


func test_bathroom_line_has_one_waiting_position_and_promotes_its_owner() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_force_bathroom(&"patron_june"))
	assert_true(session.debug_force_bathroom(&"patron_mara"))
	var queued: Dictionary = session.snapshot()
	assert_eq(queued["bathroom_owner"], &"patron_june")
	assert_eq(queued["bathroom_line_owner"], &"patron_mara")
	assert_eq(queued["debug_views"][&"patron_mara"]["activity"], &"bathroom_queued")
	session.advance(13.1)
	var promoted: Dictionary = session.snapshot()
	assert_eq(promoted["bathroom_owner"], &"patron_mara")
	assert_eq(promoted["bathroom_line_owner"], &"")
	assert_eq(promoted["debug_views"][&"patron_mara"]["activity"], &"entering_bathroom")


func test_ideal_intoxication_and_overdrink_limits_are_seeded_and_bounded() -> void:
	var ideals: Array[int] = []
	var sober_count := 0
	for seed in range(100, 600):
		var session = SESSION_SCRIPT.new()
		session.start(seed)
		var debug: Dictionary = session.debug_patron_view(&"patron_june")
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
	assert_eq(replay.debug_patron_view(&"patron_june")["ideal_intoxication_level"], ideals[0])


func test_failed_orders_change_mood_and_suspicion_then_second_failure_leaves() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_set_patron_drink_state(&"patron_june", 0, 5, 0, 3))
	assert_true(session.debug_set_patron_drink_state(&"patron_mara", 0, 5, 0, 0))
	# The debug setup cancels the opening Order, so let the next routine Order start.
	session.advance(40.1)
	assert_eq(session.normal_patron_view(&"patron_june")["order_state"], &"open")
	session.advance(60.1)
	var first: Dictionary = session.debug_patron_view(&"patron_june")
	assert_eq(first["mood_value"], 55.0)
	assert_eq(first["suspicion"], 5.0)
	session.advance(40.1)
	session.advance(60.1)
	assert_eq(session.debug_patron_view(&"patron_june")["lifecycle"], &"exited")


func test_refused_offered_drink_starts_a_sixty_second_cooldown() -> void:
	var refused_session = null
	for seed in range(100, 200):
		var candidate = SESSION_SCRIPT.new()
		candidate.start(seed)
		candidate.advance(1.1)
		candidate.debug_set_patron_drink_state(&"patron_june", 0, 5, 0, 0)
		if candidate.offer_drink(&"patron_june", &"cultist_01")["reason"] == &"refused":
			refused_session = candidate
			break
	assert_not_null(refused_session, "The seeded 20% refusal path must be reachable.")
	if refused_session == null:
		return
	var blocked: Dictionary = refused_session.offer_drink(&"patron_june", &"cultist_01")
	assert_eq(blocked["reason"], &"refusal_cooldown")
	refused_session.advance(60.1)
	assert_ne(
		refused_session.offer_drink(&"patron_june", &"cultist_01")["reason"],
		&"refusal_cooldown"
	)


func test_overdrink_collapse_uses_excess_limit_and_mood_instead_of_body_suspicion() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_set_patron_drink_state(&"patron_june", 3, 1, 0, 3))
	var accepted := false
	for _attempt in range(10):
		var offer: Dictionary = session.offer_drink(&"patron_june", &"cultist_01")
		if offer["accepted"]:
			accepted = true
			break
		session.advance(60.1)
	assert_true(accepted)
	assert_true(session.debug_force_finish_drink(&"patron_june"))
	var state: Dictionary = session.snapshot()
	var june: Dictionary = state["debug_views"][&"patron_june"]
	var mara: Dictionary = state["debug_views"][&"patron_mara"]
	assert_eq(june["lifecycle"], &"unconscious")
	assert_eq(june["collapse_cause"], &"overdrink")
	assert_eq(june["excess_drinks"], 1)
	assert_lte(float(mara["mood_value"]), 60.0)
	assert_eq(mara["suspicion"], 0.0)
	assert_false(session.normal_patron_view(&"patron_june").has("overdrink_limit"))


func test_miserable_companion_does_not_become_collapse_helper() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_change_patron_mood(&"patron_mara", -60.0))
	assert_true(session.debug_set_patron_drink_state(&"patron_june", 3, 1, 0, 3))
	for _attempt in range(10):
		if session.offer_drink(&"patron_june", &"cultist_01")["accepted"]:
			break
		session.advance(60.1)
	assert_true(session.debug_force_finish_drink(&"patron_june"))
	session.advance(2.1)
	assert_eq(session.debug_patron_view(&"patron_mara")["mood_band"], "Miserable")
	assert_eq(session.snapshot()["collapses"][&"patron_june"]["phase"], &"unattended")


func _has_event(events: Array, event_name: StringName, actor_id: StringName) -> bool:
	for event: Dictionary in events:
		if event["event"] == event_name and event["actor_id"] == actor_id:
			return true
	return false


func _serve_opening_orders(session) -> void:
	session.advance(1.1)
	assert_true(session.serve_patron_order(&"patron_june"))
	assert_true(session.serve_patron_order(&"patron_mara"))


func _count_events(events: Array, event_name: StringName) -> int:
	var count := 0
	for event: Dictionary in events:
		if event["event"] == event_name:
			count += 1
	return count
