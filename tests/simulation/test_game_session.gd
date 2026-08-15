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
