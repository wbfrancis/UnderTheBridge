extends GutTest

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const COMMAND_SYSTEM_SCRIPT := preload("res://scripts/actions/cultist_command_system.gd")


func _seated(seed: int = 707) -> Array:
	var session = GAME_SESSION_SCRIPT.new()
	session.start_night(seed)
	session.advance(3.0)
	assert_true(session.begin_admit_group(ActorIds.CULTIST_IDS[0]))
	session.advance(4.1)
	var commands = COMMAND_SYSTEM_SCRIPT.new()
	commands.reset(session)
	return [session, commands]


func _patron_target(patron_id: int) -> Dictionary:
	return {"kind": &"patron", "id": patron_id, "position": Vector3.ZERO}


func test_hidden_and_known_trait_chances_use_one_command_projection() -> void:
	var pair := _seated()
	var session = pair[0]
	var commands = pair[1]
	var patron_id := ScenarioActors.opening_patron()
	assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker", &"weak"]))
	var hidden := _option(commands, patron_id, &"knock_out")
	assert_eq(hidden["chance"]["public_total"], "???")
	assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker", &"weak"], [&"weak"]))
	commands.refresh()
	var known := _option(commands, patron_id, &"knock_out")
	assert_eq(known["chance"]["public_total"], "55%")
	assert_eq(known["chance"]["modifiers"][0]["label"], "Weak")


func test_cancelled_reason_with_costs_no_attempt_and_can_start_again() -> void:
	var pair := _seated()
	var session = pair[0]
	var commands = pair[1]
	var patron_id := ScenarioActors.opening_patron()
	assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker", &"oblivious"], [&"oblivious"]))
	assert_true(session.debug_set_patron_suspicion(patron_id, 95.0))
	var issued: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"reason_with", _patron_target(patron_id), false,
		{"is_adjacent": true}
	)
	assert_true(issued["accepted"])
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], issued["action_id"])["started"])
	session.advance(4.9)
	commands.advance(4.9)
	assert_true(commands.request_cancel_active(ActorIds.CULTIST_IDS[0])["cancelled"])
	assert_false(session.snapshot()["debug_patron_views"][patron_id]["reason_with_attempted"])
	assert_true(_option(commands, patron_id, &"reason_with")["available"])


func test_clean_snapshots_duration_and_leaves_concurrent_growth() -> void:
	var pair := _seated()
	var session = pair[0]
	var commands = pair[1]
	var patch_id: StringName = session.debug_add_grime({
		"slot_id": &"test_table", "room": &"main_hall", "center": Vector2.ZERO,
		"surface_id": &"table_test", "surface_type": &"table",
		"surface_bounds": Rect2(-1.0, -1.0, 2.0, 2.0),
		"approach_position": Vector2(0.0, 1.0),
	}, 3.0)
	var issued: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"clean", session.grime_target(patch_id), false,
		{"is_adjacent": true}
	)
	assert_true(issued["accepted"])
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], issued["action_id"])["started"])
	commands.advance(1.5)
	assert_almost_eq(
		commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[0]]["active"]["progress_ratio"],
		0.5, 0.001
	)
	assert_eq(session.debug_add_grime({
		"slot_id": patch_id, "room": &"main_hall", "center": Vector2.ZERO,
		"surface_id": &"table_test", "surface_type": &"table",
		"surface_bounds": Rect2(-1.0, -1.0, 2.0, 2.0),
		"approach_position": Vector2(0.0, 1.0),
	}, 1.0), patch_id)
	commands.advance(1.5)
	assert_false(session.grime_target(patch_id).is_empty())
	assert_true(session.clean_duration(patch_id) < 2.0)


func test_second_cultist_can_shift_queue_clean_without_reserving_until_activation() -> void:
	var pair := _seated()
	var session = pair[0]
	var commands = pair[1]
	var cultist_id := ActorIds.CULTIST_IDS[1]
	assert_gt(commands.debug_start_cultist_smoking(cultist_id), 0)
	var patch_id: StringName = session.debug_add_grime({
		"slot_id": &"queued_floor", "room": &"main_hall", "center": Vector2.ZERO,
		"surface_id": &"main_floor", "surface_type": &"floor",
		"surface_bounds": Rect2(-1.0, -1.0, 2.0, 2.0),
		"approach_position": Vector2(0.0, 1.0),
	}, 2.0)
	var issued: Dictionary = commands.issue(
		cultist_id, &"clean", session.grime_target(patch_id), true,
		{"is_adjacent": true}
	)
	assert_true(issued["accepted"])
	var queued: Dictionary = commands.snapshot()["cultists"][cultist_id]
	assert_eq(queued["active"]["command"], &"smoking")
	assert_eq(queued["pending"][0]["command"], &"clean")
	assert_false(commands.snapshot()["reserved_slots"].has(cultist_id),
		"Queued Clean does not reserve its approach early.")
	assert_true(commands.request_cancel_active(cultist_id)["cancelled"])
	assert_eq(commands.snapshot()["cultists"][cultist_id]["active"]["command"], &"clean")
	assert_true(commands.notify_reached(cultist_id, issued["action_id"])["started"])
	commands.advance(2.0)
	assert_true(session.grime_target(patch_id).is_empty())


func test_second_cultist_reason_with_pauses_and_cancel_resumes_intercept() -> void:
	var pair := _seated()
	var session = pair[0]
	var commands = pair[1]
	var patron_id := ScenarioActors.opening_patron()
	assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker", &"oblivious"], [&"oblivious"]))
	assert_true(session.report_patron_stimulus(patron_id, &"drink_dosed_seen"))
	session.advance(0.2)
	var intercept: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"intercept", _patron_target(patron_id), false,
		{"is_adjacent": true}
	)
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], intercept["action_id"])["committed"])
	session.advance(2.0)
	var before := float(session.snapshot()["active_intercept"]["remaining"])
	var reason: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[1], &"reason_with", _patron_target(patron_id), false,
		{"is_adjacent": true}
	)
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[1], reason["action_id"])["started"])
	session.advance(4.9)
	assert_almost_eq(float(session.snapshot()["active_intercept"]["remaining"]), before, 0.001)
	assert_true(commands.request_cancel_active(ActorIds.CULTIST_IDS[1])["cancelled"])
	session.advance(1.0)
	assert_lt(float(session.snapshot()["active_intercept"]["remaining"]), before)


func test_same_cultist_can_switch_directly_from_intercept_to_reason_with() -> void:
	var pair := _seated()
	var session = pair[0]
	var commands = pair[1]
	var patron_id := ScenarioActors.opening_patron()
	assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker", &"oblivious"], [&"oblivious"]))
	assert_true(session.report_patron_stimulus(patron_id, &"drink_dosed_seen"))
	session.advance(0.2)
	var intercept: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"intercept", _patron_target(patron_id), false,
		{"is_adjacent": true}
	)
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], intercept["action_id"])["committed"])
	var reason: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"reason_with", _patron_target(patron_id), false,
		{"is_adjacent": true}
	)
	assert_true(reason["accepted"])
	var active: Dictionary = commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[0]]["active"]
	assert_eq(active["command"], &"reason_with")
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], reason["action_id"])["started"])
	var intercept_remaining := float(session.snapshot()["active_intercept"]["remaining"])
	session.advance(2.0)
	assert_almost_eq(float(session.snapshot()["active_intercept"]["remaining"]), intercept_remaining, 0.001)
	assert_true(commands.request_cancel_active(ActorIds.CULTIST_IDS[0])["cancelled"])
	active = commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[0]]["active"]
	assert_eq(active["id"], intercept["action_id"], "Cancellation resumes the original Intercept tile.")
	assert_eq(active["command"], &"intercept")
	session.advance(1.0)
	assert_lt(float(session.snapshot()["active_intercept"]["remaining"]), intercept_remaining)


func test_completed_reason_with_success_ends_both_actions_and_recovers_patron() -> void:
	var pair := _seated()
	var session = pair[0]
	var commands = pair[1]
	var patron_id := ScenarioActors.opening_patron()
	assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker", &"oblivious"], [&"oblivious"]))
	assert_true(session.report_patron_stimulus(patron_id, &"drink_dosed_seen"))
	session.advance(0.2)
	var intercept: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"intercept", _patron_target(patron_id), false,
		{"is_adjacent": true}
	)
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], intercept["action_id"])["committed"])
	var reason: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[1], &"reason_with", _patron_target(patron_id), false,
		{"is_adjacent": true}
	)
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[1], reason["action_id"])["started"])
	session.advance(5.1)
	commands.refresh()
	var state: Dictionary = session.snapshot()
	assert_eq(state["debug_patron_views"][patron_id]["suspicion"], 50.0)
	assert_eq(state["debug_patron_views"][patron_id]["lifecycle"], &"active")
	assert_true(state["active_intercept"].is_empty())
	assert_true(commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[0]]["active"].is_empty())
	assert_true(commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[1]]["active"].is_empty())


func test_completed_reason_with_failure_resumes_the_same_intercept_time() -> void:
	var failed_pair: Array = []
	var before := 0.0
	var patron_id := ScenarioActors.opening_patron()
	# Find the first deterministic failure seed. This tests the real seeded roll
	# without adding a result-forcing debug seam to production code.
	for seed in range(1, 33):
		var pair := _seated(seed)
		var session = pair[0]
		var commands = pair[1]
		assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker", &"oblivious"], [&"oblivious"]))
		assert_true(session.report_patron_stimulus(patron_id, &"drink_dosed_seen"))
		session.advance(0.2)
		var intercept: Dictionary = commands.issue(
			ActorIds.CULTIST_IDS[0], &"intercept", _patron_target(patron_id), false,
			{"is_adjacent": true}
		)
		assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], intercept["action_id"])["committed"])
		session.advance(1.0)
		before = float(session.snapshot()["active_intercept"]["remaining"])
		var reason: Dictionary = commands.issue(
			ActorIds.CULTIST_IDS[1], &"reason_with", _patron_target(patron_id), false,
			{"is_adjacent": true}
		)
		assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[1], reason["action_id"])["started"])
		session.advance(5.1)
		commands.refresh()
		if not session.snapshot()["active_intercept"].is_empty():
			failed_pair = pair
			break
	assert_false(failed_pair.is_empty(), "At least one seed in the fixed range produces the 80% failure path.")
	if failed_pair.is_empty():
		return
	var failed_session = failed_pair[0]
	var failed_commands = failed_pair[1]
	assert_true(failed_session.snapshot()["debug_patron_views"][patron_id]["reason_with_attempted"])
	assert_almost_eq(
		float(failed_session.snapshot()["active_intercept"]["remaining"]), before, 0.201,
		"Only the part of the final simulation step after the roll can resume Intercept."
	)
	failed_session.advance(1.0)
	failed_commands.refresh()
	assert_lt(float(failed_session.snapshot()["active_intercept"]["remaining"]), before)


func test_cultist_smoking_is_executable_queue_work_without_a_menu_command() -> void:
	var pair := _seated()
	var commands = pair[1]
	var action_id: int = commands.debug_start_cultist_smoking(ActorIds.CULTIST_IDS[0])
	assert_gt(action_id, 0)
	var active: Dictionary = commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[0]]["active"]
	assert_eq(active["command"], &"smoking")
	assert_eq(active["label"], "Smoking")
	assert_false(&"smoking" in CultistCommandSystem.PATRON_COMMANDS)


func _option(commands, patron_id: int, command: StringName) -> Dictionary:
	for option: Dictionary in commands.resolve_options(ActorIds.CULTIST_IDS[0], _patron_target(patron_id)):
		if option["command"] == command:
			return option
	return {}
