extends GutTest

const BOTTOM_HUD_SCENE := "res://scenes/ui/bottom_hud.tscn"
const GAME_SESSION_PATH := "res://scripts/simulation/game_session.gd"
const NIGHT_PLAYBACK_PATH := "res://scripts/presentation/night_playback.gd"

var _session
var _playback
var _hud
var _last_result: Dictionary = {}


func before_each() -> void:
	_session = load(GAME_SESSION_PATH).new()
	_session.start_night(707)
	_playback = load(NIGHT_PLAYBACK_PATH).new()
	_playback.reset(_session, 1.0)
	_hud = load(BOTTOM_HUD_SCENE).instantiate()
	add_child_autofree(_hud)
	_hud.intent_submitted.connect(_route_hud_intent)
	await get_tree().process_frame
	await _render_authoritative_state()


func _route_hud_intent(kind: StringName, payload: Dictionary) -> void:
	match kind:
		&"set_time_scale":
			_last_result = _playback.submit(&"select_speed", payload)
		&"toggle_pause":
			_last_result = _playback.submit(&"toggle_plain_pause")
		&"open_pause_menu":
			_last_result = _playback.submit(&"open_pause_menu")
		&"dismiss_pause_menu":
			_last_result = _playback.submit(&"dismiss_pause_menu")
		&"resume_night":
			_last_result = _playback.submit(&"resume_from_pause_menu")


func _render_authoritative_state() -> void:
	var playback_state: Dictionary = _playback.synchronize()
	playback_state.merge({
		"clock_label": _session.snapshot()["clock_label"],
		"clock_minutes": _session.snapshot()["clock_minutes"],
		"closing_label": _session.snapshot()["closing_label"],
		"remaining_label": "18m 00s",
		"progress_ratio": 0.0,
	}, true)
	_hud.render({
		"night": playback_state,
		"pause_menu_open": playback_state["pause_menu_open"],
		"feedback": {
			"text": playback_state["feedback"],
			"serial": playback_state["feedback_serial"],
		},
	})
	await get_tree().process_frame
	await get_tree().process_frame


func test_hud_space_speed_and_selected_speed_no_op_cross_every_real_seam() -> void:
	_hud.activate(&"toggle_pause")
	await _render_authoritative_state()
	assert_true(bool(_last_result["accepted"]))
	assert_eq(_session.snapshot()["time_scale"], 0.0)
	assert_true(bool(_hud.inspect()["night"]["plain_paused"]))
	assert_eq(_hud.inspect()["night"]["selected_speed"], 1.0)

	_hud.activate(&"speed_2")
	await _render_authoritative_state()
	assert_eq(_session.snapshot()["time_scale"], 2.0)
	assert_eq(_hud.inspect()["night"]["selected_speed"], 2.0)

	var before: Dictionary = _playback.snapshot()
	_hud.activate(&"speed_2")
	await _render_authoritative_state()
	assert_true(bool(_last_result["accepted"]))
	assert_eq(_playback.snapshot(), before, "A selected-speed click causes no local or authority drift.")


func test_hud_escape_dismiss_restores_but_resume_starts_the_selected_speed() -> void:
	_hud.activate(&"speed_2")
	await _render_authoritative_state()
	_hud.activate(&"toggle_pause")
	await _render_authoritative_state()

	_hud.activate(&"escape")
	await _render_authoritative_state()
	assert_true(bool(_hud.inspect()["pause_menu_open"]))
	_hud.activate(&"escape")
	await _render_authoritative_state()
	assert_eq(_session.snapshot()["time_scale"], 0.0)
	assert_true(bool(_hud.inspect()["night"]["plain_paused"]))

	_hud.activate(&"escape")
	await _render_authoritative_state()
	_hud.activate(&"resume")
	await _render_authoritative_state()
	assert_eq(_session.snapshot()["time_scale"], 2.0)
	assert_false(bool(_hud.inspect()["night"]["plain_paused"]))


func test_escape_lock_reaches_disabled_hud_buttons_and_plain_pause_stays_available() -> void:
	_hud.activate(&"speed_4")
	await _render_authoritative_state()
	_session.set_time_scale(1.0)
	_session.advance(200.0)
	_session.set_time_scale(4.0)
	assert_true(_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen"))
	_session.advance(0.2)
	await _render_authoritative_state()

	var night: Dictionary = _hud.inspect()["night"]
	var playback_state: Dictionary = _playback.snapshot()
	assert_eq(night["time_scale"], 1.0)
	assert_eq(night["selected_speed"], 1.0)
	assert_eq(playback_state["speed_lock_reason"], &"active_escape")
	assert_false(bool(night["speed_enabled"][2.0]))
	assert_false(bool(night["speed_enabled"][4.0]))

	_hud.activate(&"toggle_pause")
	await _render_authoritative_state()
	assert_eq(_session.snapshot()["time_scale"], 0.0)
	assert_true(bool(_hud.inspect()["night"]["plain_paused"]))
