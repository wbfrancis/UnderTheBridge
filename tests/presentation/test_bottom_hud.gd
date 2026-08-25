extends GutTest

## Interface tests for the Green Folio Bottom HUD.
##
## Every check goes through the module's own seam: a display-ready `view` in,
## `inspect()` out, and `activate()` for one piece of player intent. Nothing here
## walks the control tree, so the HUD can be re-laid-out without rewriting tests.

const BOTTOM_HUD_SCENE := "res://scenes/ui/bottom_hud.tscn"

var _hud
var _intents: Array[Dictionary] = []


func before_each() -> void:
	_intents = []
	_hud = load(BOTTOM_HUD_SCENE).instantiate()
	add_child_autofree(_hud)
	_hud.intent_submitted.connect(
		func(kind: StringName, payload: Dictionary) -> void:
			_intents.append({"kind": kind, "payload": payload})
	)
	await get_tree().process_frame


# Two frames: one for the render, one for the containers to settle their rects.
func _render(view: Dictionary) -> void:
	_hud.render(view)
	await get_tree().process_frame
	await get_tree().process_frame


func _cultist(status: String = "") -> Dictionary:
	return {
		"id": &"cultist_01",
		"name": "Vera",
		"portrait": null,
		"tint": Color.WHITE,
		"activity": "Talking to June",
		"inspected_patron_status": status,
	}


func _patron() -> Dictionary:
	return {
		"id": &"patron_june",
		"name": "June",
		"portrait": null,
		"tint": Color.WHITE,
		"visible_activity": "Drinking",
		"mood": "Content",
		"suspicion_band": "Uneasy",
		"intoxication": "Buzzed",
		"order_state": "Served",
	}


func _tile(
		id: int,
		command: StringName,
		label: String,
		target_label: String,
		active: bool,
		ratio: Variant = null
) -> Dictionary:
	return {
		"id": id,
		"icon": command,
		"label": label,
		"target_label": target_label,
		"active": active,
		"cancellable": true,
		"progress_ratio": ratio,
	}


func _night(scale: float, paused: bool, last_nonzero: float = 1.0) -> Dictionary:
	return {
		"time_scale": scale,
		"paused": paused,
		"last_nonzero_scale": last_nonzero,
		"progress_ratio": 0.47,
		"clock_label": "10:48 PM",
		"clock_minutes": 22.0 * 60.0 + 48.0,
	}


func _outcome(kind: StringName, captures: int = 1) -> Dictionary:
	return {
		"visible": true,
		"kind": kind,
		"cause": "The Night closed short of the Capture quota.",
		"captures": captures,
		"capture_quota": 3,
		"progress_ratio": float(captures) / 3.0,
	}


func _kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for entry: Dictionary in _intents:
		kinds.append(entry["kind"])
	return kinds


func _last(kind: StringName) -> Dictionary:
	for index in range(_intents.size() - 1, -1, -1):
		if _intents[index]["kind"] == kind:
			return _intents[index]["payload"]
	return {}


# --- Action Tiles -------------------------------------------------------------

func test_a_selected_cultist_renders_four_action_tile_slots() -> void:
	await _render({
		"selected_cultist": _cultist(),
		"action_tiles": [
			_tile(1, &"talk", "Talk", "June", true, 0.62),
			_tile(2, &"prepare_drink", "Prepare Drink", "Bar Work Position", false),
		],
	})

	var tiles: Array = _hud.inspect()["action_tiles"]
	assert_eq(tiles.size(), 4, "The strip always shows one active and three pending slots.")
	assert_true(bool(tiles[0]["filled"]) and bool(tiles[0]["active"]),
		"The active Action comes first.")
	assert_true(bool(tiles[1]["filled"]) and not bool(tiles[1]["active"]))
	for index in [2, 3]:
		assert_false(bool(tiles[index]["filled"]), "An unused slot stays empty.")
		assert_false(bool(tiles[index]["cancel_visible"]),
			"An empty slot offers no cancel affordance.")


func test_action_tiles_are_square() -> void:
	await _render({"selected_cultist": _cultist(), "action_tiles": []})

	for tile: Dictionary in _hud.inspect()["action_tiles"]:
		var rect: Rect2 = tile["rect"]
		assert_almost_eq(rect.size.x, rect.size.y, 0.5, "An Action Tile is square.")


func test_an_empty_action_queue_stays_visible_for_a_selected_cultist() -> void:
	await _render({"selected_cultist": _cultist(), "action_tiles": []})

	var state: Dictionary = _hud.inspect()
	assert_true(bool(state["action_tiles_visible"]),
		"An idle Cultist still shows their Action Queue.")
	for tile: Dictionary in state["action_tiles"]:
		assert_false(bool(tile["filled"]))

	await _render({"selected_cultist": {}, "action_tiles": []})
	assert_false(bool(_hud.inspect()["action_tiles_visible"]),
		"With no Selected Cultist there is no queue to show.")


func test_an_active_tile_without_a_stable_ratio_shows_no_progress() -> void:
	await _render({
		"selected_cultist": _cultist(),
		"action_tiles": [_tile(7, &"talk", "Talk", "June", true, null)],
	})

	var tile: Dictionary = _hud.inspect()["action_tiles"][0]
	assert_true(bool(tile["active"]))
	assert_null(tile["progress_ratio"], "No invented percentage without a real ratio.")


func test_active_and_pending_cancel_intents_carry_stable_action_ids() -> void:
	await _render({
		"selected_cultist": _cultist(),
		"action_tiles": [
			_tile(11, &"talk", "Talk", "June", true, 0.3),
			_tile(12, &"move", "Move", "Floor", false),
		],
	})

	_hud.activate(&"cancel_tile", {"index": 0})
	_hud.activate(&"cancel_tile", {"index": 1})

	assert_has(_kinds(), &"cancel_active_action")
	assert_has(_kinds(), &"remove_pending_action")
	assert_eq(int(_last(&"cancel_active_action")["action_id"]), 11)
	assert_eq(int(_last(&"remove_pending_action")["action_id"]), 12)


func test_an_unknown_command_falls_back_instead_of_breaking_the_strip() -> void:
	await _render({
		"selected_cultist": _cultist(),
		"action_tiles": [_tile(3, &"summon_the_tide", "Summon", "Nobody", true)],
	})

	var tiles: Array = _hud.inspect()["action_tiles"]
	assert_eq(tiles.size(), 4)
	assert_true(bool(tiles[0]["filled"]), "A future Action still fills its slot.")


# --- Portraits and names ------------------------------------------------------

func test_the_inspected_patron_states_reuse_one_portrait_control() -> void:
	await _render({"selected_cultist": _cultist(), "inspected_patron": {}})
	var empty: Dictionary = _hud.inspect()["patron"]

	await _render({
		"selected_cultist": _cultist("June selected"), "inspected_patron": _patron(),
	})
	var selected: Dictionary = _hud.inspect()["patron"]

	assert_eq(empty["mode"], "empty")
	assert_eq(selected["mode"], "selected")
	assert_eq(
		empty["portrait_instance_id"],
		selected["portrait_instance_id"],
		"One portrait control serves both states."
	)
	assert_eq(
		empty["portrait_rect"],
		selected["portrait_rect"],
		"The empty portrait sits exactly where the Patron portrait appears."
	)
	assert_eq(empty["name"], "No patron selected")
	assert_eq(selected["name"], "June")


func test_names_render_below_both_portraits() -> void:
	await _render({
		"selected_cultist": _cultist("June selected"), "inspected_patron": _patron(),
	})

	var state: Dictionary = _hud.inspect()
	assert_true(bool(state["cultist"]["name_below_portrait"]),
		"The Cultist name sits below their portrait.")
	assert_true(bool(state["patron"]["name_below_portrait"]),
		"The Patron name sits below their portrait.")
	assert_eq(state["cultist"]["name"], "Vera")
	assert_eq(state["cultist"]["status"], "June selected",
		"The inspected Patron status belongs to the Cultist panel.")


func test_closing_the_inspected_patron_leaves_the_selected_cultist_alone() -> void:
	await _render({
		"selected_cultist": _cultist("June selected"), "inspected_patron": _patron(),
	})

	_hud.activate(&"close_patron")

	assert_eq(_kinds(), [&"close_inspected_patron"] as Array[StringName],
		"Clearing the Patron never touches the Cultist selection.")


# --- Night, speed, and pause --------------------------------------------------

func test_the_speed_shortcuts_map_to_one_two_and_four_times() -> void:
	await _render({"night": _night(1.0, false)})

	_hud.activate(&"speed_1")
	_hud.activate(&"speed_2")
	_hud.activate(&"speed_4")

	var values: Array[float] = []
	for entry: Dictionary in _intents:
		assert_eq(entry["kind"], &"set_time_scale")
		values.append(float(entry["payload"]["value"]))
	assert_eq(values, [1.0, 2.0, 4.0] as Array[float],
		"Keys 1, 2, and 3 select 1x, 2x, and 4x.")


func test_space_pauses_and_resumes_the_last_nonzero_speed() -> void:
	assert_eq(_hud.resume_scale(2.0, 1.0), 0.0, "Space at a running speed pauses.")
	assert_eq(_hud.resume_scale(0.0, 2.0), 2.0, "Space at 0x resumes the remembered speed.")
	assert_eq(_hud.resume_scale(0.0, 0.0), 1.0, "With nothing remembered, resume runs at 1x.")

	await _render({"night": _night(2.0, false, 2.0)})
	_hud.activate(&"toggle_pause")
	assert_eq(_kinds(), [&"toggle_pause"] as Array[StringName])
	assert_eq(_hud.inspect()["night"]["selected_speed"], 2.0)

	await _render({"night": _night(0.0, true, 2.0)})
	var paused: Dictionary = _hud.inspect()["night"]
	assert_true(bool(paused["pause_pressed"]), "The pause control reads as pressed.")
	assert_eq(paused["selected_speed"], 0.0, "No speed is selected while paused.")

	await _render({"night": _night(2.0, false, 2.0)})
	assert_eq(_hud.inspect()["night"]["selected_speed"], 2.0,
		"Resuming shows the remembered speed as the pressed one.")


func test_the_hud_follows_a_speed_the_session_refused() -> void:
	await _render({"night": _night(4.0, false, 4.0)})
	assert_eq(_hud.inspect()["night"]["selected_speed"], 4.0)

	# An active Escape forces 1x. The HUD shows the accepted snapshot, not the ask.
	_hud.activate(&"speed_4")
	await _render({"night": _night(1.0, false, 1.0)})
	assert_eq(_hud.inspect()["night"]["selected_speed"], 1.0)


func test_a_refused_speed_shows_a_short_visible_line() -> void:
	await _render({"night": _night(1.0, false)})
	assert_eq(String(_hud.inspect()["feedback"]), "", "Nothing to say by default.")

	await _render({
		"night": _night(1.0, false),
		"feedback": {"text": "4x is not available right now.", "serial": 1},
	})
	assert_eq(
		String(_hud.inspect()["feedback"]),
		"4x is not available right now.",
		"A refused ask says so on screen."
	)

	# The same words asked for again still count as a new message.
	await _render({
		"night": _night(1.0, false),
		"feedback": {"text": "4x is not available right now.", "serial": 2},
	})
	assert_eq(String(_hud.inspect()["feedback"]), "4x is not available right now.")


func test_the_night_clock_reads_the_display_time_it_was_given() -> void:
	await _render({"night": _night(1.0, false)})

	var night: Dictionary = _hud.inspect()["night"]
	assert_eq(night["clock_label"], "10:48 PM")
	assert_almost_eq(float(night["clock_minutes"]), 22.0 * 60.0 + 48.0, 0.01)
	assert_almost_eq(float(night["progress_ratio"]), 0.47, 0.001)


# --- Menus, Pause Menu, and Escape --------------------------------------------

func test_settings_and_developer_popups_are_mutually_exclusive() -> void:
	await _render({
		"developer": {
			"visible": false,
			"scenario_id": "full_cast",
			"scenarios": [{"id": "full_cast", "label": "FULL CAST"}],
		},
	})

	_hud.activate(&"settings_menu")
	assert_true(bool(_hud.inspect()["settings_open"]))
	assert_false(bool(_hud.inspect()["developer_open"]))

	_hud.activate(&"developer_menu")
	assert_false(bool(_hud.inspect()["settings_open"]),
		"Opening one utility menu closes the other.")
	assert_true(bool(_hud.inspect()["developer_open"]))

	_hud.activate(&"developer_menu")
	assert_false(bool(_hud.inspect()["developer_open"]), "The same button closes it again.")


func test_escape_closes_transient_ui_before_opening_the_pause_menu() -> void:
	await _render({})

	_hud.activate(&"settings_menu")
	_hud.activate(&"escape")
	assert_false(bool(_hud.inspect()["settings_open"]), "Escape closes the open menu first.")
	assert_eq(_kinds(), [] as Array[StringName], "That Escape reached no further.")

	_hud.activate(&"escape")
	assert_eq(_kinds(), [&"open_pause_menu"] as Array[StringName],
		"With nothing transient open, Escape reaches the Pause Menu.")

	await _render({"pause_menu_open": true})
	_hud.activate(&"escape")
	assert_has(_kinds(), &"resume_night", "Escape closes an open Pause Menu.")


func test_the_pause_menu_offers_resume_restart_settings_and_quit() -> void:
	await _render({"pause_menu_open": true})
	assert_true(bool(_hud.inspect()["pause_menu_open"]))

	_hud.activate(&"resume")
	_hud.activate(&"restart")
	_hud.activate(&"quit")
	assert_eq(
		_kinds(),
		[&"resume_night", &"restart_night", &"quit_game"] as Array[StringName]
	)


func test_developer_intents_carry_their_scenario_and_step() -> void:
	await _render({
		"developer": {
			"visible": false,
			"scenario_id": "full_cast",
			"scenarios": [{"id": "front_exit", "label": "FRONT EXIT"}],
		},
	})

	_hud.activate(&"scenario", {"scenario_id": "front_exit"})
	_hud.activate(&"debug_step", {"seconds": 5.0})
	_hud.activate(&"set_debug_visible", {"enabled": true})

	assert_eq(String(_last(&"select_scenario")["scenario_id"]), "front_exit")
	assert_eq(float(_last(&"advance_debug_time")["seconds"]), 5.0)
	assert_true(bool(_last(&"set_debug_visible")["enabled"]))


func test_settings_intents_carry_their_new_value() -> void:
	await _render({})

	_hud.activate(&"set_emote_labels", {"enabled": true})
	_hud.activate(&"set_ui_scale", {"scale": 1.25})
	_hud.activate(&"set_reduced_motion", {"enabled": true})

	assert_true(bool(_last(&"set_emote_labels")["enabled"]))
	assert_eq(float(_last(&"set_ui_scale")["scale"]), 1.25)
	assert_true(bool(_last(&"set_reduced_motion")["enabled"]))


func test_the_ui_scale_setting_keeps_the_hud_on_the_bottom_edge() -> void:
	await _render({"settings": {"emote_labels": false, "ui_scale": 1.25, "reduced_motion": false}})

	assert_almost_eq(float(_hud.inspect()["ui_scale"]), 1.25, 0.001)
	var viewport := get_viewport().get_visible_rect()
	for rect: Rect2 in _hud.reserved_rects():
		assert_almost_eq(rect.end.y, viewport.size.y, 2.0,
			"The scaled Bottom HUD still ends on the bottom screen edge.")
		break


# --- Outcome Modal ------------------------------------------------------------

func test_an_open_outcome_modal_blocks_every_time_control() -> void:
	await _render({"night": _night(2.0, false, 2.0), "outcome": _outcome(&"failed")})

	_hud.activate(&"speed_1")
	_hud.activate(&"speed_2")
	_hud.activate(&"speed_4")
	_hud.activate(&"toggle_pause")
	_hud.activate(&"escape")
	_hud.activate(&"scenario", {"scenario_id": "full_cast"})
	_hud.activate(&"debug_step", {"seconds": 1.0})

	assert_eq(_kinds(), [] as Array[StringName],
		"Nothing may advance or dismiss the Night while an outcome is on screen.")


func test_every_outcome_offers_restart_and_quit() -> void:
	for pair: Array in [
		[&"victory", "Success"], [&"failed", "Operation Failed"], [&"exposed", "Exposed"],
	]:
		_intents = []
		await _render({"outcome": _outcome(pair[0], 3 if pair[0] == &"victory" else 1)})

		var state: Dictionary = _hud.inspect()
		assert_true(bool(state["outcome_visible"]))
		assert_eq(state["outcome_title"], pair[1])
		assert_eq(state["outcome_actions"], ["restart", "quit"])

		_hud.activate(&"restart")
		_hud.activate(&"quit")
		assert_eq(
			_kinds(),
			[&"restart_night", &"quit_game"] as Array[StringName],
			"%s still offers Restart and Quit." % pair[1]
		)


func test_a_closed_outcome_leaves_the_time_controls_alive() -> void:
	await _render({"night": _night(1.0, false)})

	_hud.activate(&"speed_2")
	assert_eq(_kinds(), [&"set_time_scale"] as Array[StringName])
