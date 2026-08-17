extends GutTest

const GAME_SESSION_PATH := "res://scripts/simulation/game_session.gd"


func test_time_controls_advance_without_rendering() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	assert_not_null(game_session_script, "GameSession should be available through its public script.")
	if game_session_script == null:
		return

	var session = game_session_script.new()
	session.start_night(12_345)

	assert_true(session.set_time_scale(0.0))
	session.advance(10.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 0.0, 0.0001)

	assert_true(session.set_time_scale(1.0))
	session.advance(5.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 5.0, 0.0001)

	assert_true(session.set_time_scale(2.0))
	session.advance(3.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 11.0, 0.0001)

	assert_true(session.set_time_scale(4.0))
	session.advance(2.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 19.0, 0.0001)

	assert_false(session.set_time_scale(3.0), "Only pause, 1x, 2x, and 4x are supported.")
	assert_almost_eq(float(session.snapshot()["time_scale"]), 4.0, 0.0001)


func test_seeded_replay_is_repeatable_and_restart_is_clean() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	assert_not_null(game_session_script)
	if game_session_script == null:
		return

	var first_session = game_session_script.new()
	var replay_session = game_session_script.new()
	first_session.start_night(77_031)
	replay_session.start_night(77_031)
	first_session.set_time_scale(4.0)
	replay_session.set_time_scale(4.0)
	first_session.advance(5.0)
	replay_session.advance(5.0)

	var first_snapshot: Dictionary = first_session.snapshot()
	var replay_snapshot: Dictionary = replay_session.snapshot()
	assert_eq(first_snapshot["night_seed"], 77_031)
	assert_gt(first_snapshot["representative_rolls"].size(), 0)
	assert_eq(first_snapshot["representative_rolls"], replay_snapshot["representative_rolls"])
	assert_eq(first_snapshot["representative_outcome"], replay_snapshot["representative_outcome"])

	first_session.restart_night(88_042)
	var restarted_snapshot: Dictionary = first_session.snapshot()
	assert_eq(restarted_snapshot["night_seed"], 88_042)
	assert_almost_eq(float(restarted_snapshot["simulated_seconds"]), 0.0, 0.0001)
	assert_almost_eq(float(restarted_snapshot["time_scale"]), 1.0, 0.0001)
	assert_true(restarted_snapshot["representative_rolls"].is_empty())
	assert_eq(restarted_snapshot["representative_outcome"], &"running")


func test_all_authored_arrival_groups_complete_non_capture_visits() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.set_time_scale(4.0)
	session.advance(270.0)

	var state: Dictionary = session.snapshot()
	assert_eq(state["patrons"]["authored_count"], 8)
	assert_eq(state["patrons"]["arrived_count"], 8)
	assert_eq(state["patrons"]["normal_departure_count"], 8)
	assert_eq(state["patrons"]["active_count"], 0)
	assert_eq(state["patrons"]["arrival_groups"].size(), 4)
	assert_eq(state["orders"]["served_count"], 8)
	assert_eq(state["captures"], 0)


func test_safe_autonomy_serves_or_idles_and_never_starts_capture() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(210.0)

	var state: Dictionary = session.snapshot()
	assert_gt(state["safe_autonomy"]["events"].size(), 0)
	assert_eq(state["safe_autonomy"]["capture_actions_started"], 0)
	assert_eq(state["cultists"].size(), 3)
	for cultist_id: StringName in state["cultists"]:
		assert_true(
			state["cultists"][cultist_id]["activity"] in [&"safe_service", &"idle"],
			"Safe autonomy may only perform service or idle behavior."
		)


func test_time_controls_reach_closing_and_basic_non_capture_results() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)

	session.set_time_scale(0.0)
	session.advance(120.0)
	assert_eq(session.snapshot()["phase"], &"preparation")
	assert_eq(session.snapshot()["simulated_seconds"], 0.0)

	session.set_time_scale(1.0)
	session.advance(60.0)
	assert_eq(session.snapshot()["phase"], &"active_operation")
	session.set_time_scale(2.0)
	session.advance(450.0)
	assert_eq(session.snapshot()["phase"], &"closing")
	session.set_time_scale(4.0)
	session.advance(30.0)

	var results_state: Dictionary = session.snapshot()
	assert_eq(results_state["phase"], &"results")
	assert_eq(results_state["outcome"], &"failed_operation")
	assert_true(results_state["results"]["visible"])
	assert_eq(results_state["results"]["night_seed"], 707)
	assert_false(session.set_time_scale(1.0), "Results stop the Night clock until restart.")


func test_restart_constructs_a_clean_second_night() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.set_time_scale(4.0)
	session.advance(270.0)
	assert_gt(session.snapshot()["orders"]["served_count"], 0)

	session.restart_night(808)
	var restarted: Dictionary = session.snapshot()
	assert_eq(restarted["night_seed"], 808)
	assert_eq(restarted["phase"], &"preparation")
	assert_eq(restarted["simulated_seconds"], 0.0)
	assert_eq(restarted["time_scale"], 1.0)
	assert_eq(restarted["patrons"]["active_count"], 0)
	assert_eq(restarted["orders"]["all"].size(), 0)
	assert_eq(restarted["runtime"]["spawned_patrons"], 0)
	assert_eq(restarted["runtime"]["prepared_drinks"], 0)
	assert_eq(restarted["runtime"]["actions"], 0)
	assert_eq(restarted["runtime"]["reservations"], 0)
	assert_eq(restarted["runtime"]["timers"], 0)
	assert_true(restarted["visit_events"].is_empty())
	assert_false(restarted["results"]["visible"])
