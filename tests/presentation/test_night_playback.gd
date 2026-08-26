extends GutTest

const GAME_SESSION_PATH := "res://scripts/simulation/game_session.gd"
const NIGHT_PLAYBACK_PATH := "res://scripts/presentation/night_playback.gd"

var _session
var _playback


func before_each() -> void:
	_session = load(GAME_SESSION_PATH).new()
	_session.start_night(707)
	_playback = load(NIGHT_PLAYBACK_PATH).new()
	_playback.reset(_session, 1.0)


func _select(value: float) -> Dictionary:
	return _playback.submit(&"select_speed", {"value": value})


func _trigger_escape() -> void:
	_session.set_time_scale(1.0)
	var remaining := 200.0 - float(_session.snapshot()["simulated_seconds"])
	if remaining > 0.0:
		_session.advance(remaining)
	_session.set_time_scale(4.0)
	assert_true(_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen"))
	_session.advance(0.2)


func test_running_one_times_toggles_to_plain_pause_and_back() -> void:
	var paused: Dictionary = _playback.submit(&"toggle_plain_pause")
	assert_true(bool(paused["accepted"]))
	assert_eq(_playback.snapshot()["time_scale"], 0.0)
	assert_eq(_playback.snapshot()["selected_speed"], 1.0)
	assert_true(bool(_playback.snapshot()["plain_paused"]))

	var resumed: Dictionary = _playback.submit(&"toggle_plain_pause")
	assert_true(bool(resumed["accepted"]))
	assert_eq(_playback.snapshot()["time_scale"], 1.0)
	assert_false(bool(_playback.snapshot()["plain_paused"]))


func test_plain_pause_keeps_two_times_selected_and_four_times_resumes() -> void:
	assert_true(bool(_select(2.0)["accepted"]))
	assert_true(bool(_playback.submit(&"toggle_plain_pause")["accepted"]))
	var paused: Dictionary = _playback.snapshot()
	assert_eq(paused["time_scale"], 0.0)
	assert_eq(paused["selected_speed"], 2.0)

	assert_true(bool(_select(4.0)["accepted"]))
	var resumed: Dictionary = _playback.snapshot()
	assert_eq(resumed["time_scale"], 4.0)
	assert_eq(resumed["selected_speed"], 4.0)
	assert_false(bool(resumed["plain_paused"]))


func test_selecting_the_running_speed_is_an_accepted_repeatable_no_op() -> void:
	assert_true(bool(_select(2.0)["accepted"]))
	var before: Dictionary = _playback.snapshot()
	for index in range(12):
		var result: Dictionary = _select(2.0)
		assert_true(bool(result["accepted"]), "The selected speed stays an accepted command.")
		assert_eq(result["reason"], &"")
	assert_eq(_playback.snapshot(), before, "Repeated selected-speed presses cause no state drift.")


func test_dismissing_the_pause_menu_restores_running_two_times() -> void:
	_select(2.0)
	assert_true(bool(_playback.submit(&"open_pause_menu")["accepted"]))
	assert_true(bool(_playback.snapshot()["pause_menu_open"]))
	assert_eq(_playback.snapshot()["time_scale"], 0.0)

	assert_true(bool(_playback.submit(&"dismiss_pause_menu")["accepted"]))
	var restored: Dictionary = _playback.snapshot()
	assert_false(bool(restored["pause_menu_open"]))
	assert_false(bool(restored["plain_paused"]))
	assert_eq(restored["time_scale"], 2.0)


func test_dismissing_the_pause_menu_restores_plain_pause() -> void:
	_select(2.0)
	_playback.submit(&"toggle_plain_pause")
	_playback.submit(&"open_pause_menu")
	_playback.submit(&"dismiss_pause_menu")

	var restored: Dictionary = _playback.snapshot()
	assert_eq(restored["time_scale"], 0.0)
	assert_eq(restored["selected_speed"], 2.0)
	assert_true(bool(restored["plain_paused"]))


func test_resume_from_a_plain_paused_menu_starts_the_selected_speed() -> void:
	_select(2.0)
	_playback.submit(&"toggle_plain_pause")
	_playback.submit(&"open_pause_menu")
	assert_true(bool(_playback.submit(&"resume_from_pause_menu")["accepted"]))

	var resumed: Dictionary = _playback.snapshot()
	assert_eq(resumed["time_scale"], 2.0)
	assert_eq(resumed["selected_speed"], 2.0)
	assert_false(bool(resumed["plain_paused"]))
	assert_false(bool(resumed["pause_menu_open"]))


func test_escape_sync_selects_one_times_and_disables_faster_speeds() -> void:
	_select(4.0)
	_trigger_escape()
	var synchronized: Dictionary = _playback.synchronize()

	assert_eq(synchronized["time_scale"], 1.0)
	assert_eq(synchronized["selected_speed"], 1.0)
	assert_eq(synchronized["speed_lock_reason"], &"active_escape")
	assert_true(bool(synchronized["speed_enabled"][1.0]))
	assert_false(bool(synchronized["speed_enabled"][2.0]))
	assert_false(bool(synchronized["speed_enabled"][4.0]))

	assert_true(bool(_playback.submit(&"toggle_plain_pause")["accepted"]))
	assert_eq(_playback.snapshot()["time_scale"], 0.0)
	assert_eq(_playback.snapshot()["selected_speed"], 1.0)


func test_escape_rejection_keeps_accepted_state_and_repeats_feedback() -> void:
	_trigger_escape()
	_playback.synchronize()
	var first: Dictionary = _select(4.0)
	var first_state: Dictionary = _playback.snapshot()
	var second: Dictionary = _select(4.0)
	var second_state: Dictionary = _playback.snapshot()

	assert_false(bool(first["accepted"]))
	assert_eq(first["reason"], &"speed_locked")
	assert_false(bool(second["accepted"]))
	assert_eq(first_state["selected_speed"], 1.0)
	assert_eq(second_state["selected_speed"], 1.0)
	assert_eq(int(second_state["feedback_serial"]), int(first_state["feedback_serial"]) + 1)


func test_outcome_rejects_every_time_request_without_changing_state() -> void:
	_session.advance(1080.0)
	_playback.synchronize()
	var before: Dictionary = _playback.snapshot()
	for request: Array in [
		[&"select_speed", {"value": 2.0}],
		[&"toggle_plain_pause", {}],
		[&"open_pause_menu", {}],
		[&"dismiss_pause_menu", {}],
		[&"resume_from_pause_menu", {}],
	]:
		var result: Dictionary = _playback.submit(request[0], request[1])
		assert_false(bool(result["accepted"]))
		assert_eq(result["reason"], &"night_over")
		assert_eq(_playback.snapshot(), before, "The Outcome Modal keeps playback state unchanged.")


func test_rapid_space_presses_have_one_deterministic_transition_each() -> void:
	for index in range(31):
		assert_true(bool(_playback.submit(&"toggle_plain_pause")["accepted"]))
	var odd_state: Dictionary = _playback.snapshot()
	assert_eq(odd_state["time_scale"], 0.0)
	assert_true(bool(odd_state["plain_paused"]))

	assert_true(bool(_playback.submit(&"toggle_plain_pause")["accepted"]))
	var even_state: Dictionary = _playback.snapshot()
	assert_eq(even_state["time_scale"], 1.0)
	assert_false(bool(even_state["plain_paused"]))
