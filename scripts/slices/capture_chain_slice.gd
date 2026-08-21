extends Control

# Headless-first evidence slice for Ticket #11: the bathroom danger chain running inside the
# live Night through the public GameSession API only. Each scenario drives one acceptance
# criterion; --report writes a machine-checkable validation file, --capture writes a PNG.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const SCENARIOS := {
	"trapdoor_capture": "TRAPDOOR CAPTURE",
	"seated_witness": "SEATED WITNESS",
	"missing_investigation": "MISSING → INVESTIGATION",
	"escape_intercept": "ESCAPE + INTERCEPT",
	"front_exit_defeat": "FRONT-EXIT DEFEAT",
}

var _session = GAME_SESSION_SCRIPT.new()
var _scenario: String = "trapdoor_capture"
var _focus_patron_id: StringName = &"patron_june"
var _scenario_trace: String = ""
var _capture_mode: bool = false
var _scenario_buttons: Dictionary = {}
var _state_text: RichTextLabel
var _patron_text: RichTextLabel
var _trace_text: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	_build_ui()
	_set_scenario(_command_line_value("--stage=", "trapdoor_capture"))
	await _finish_command_line_work()


func _build_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 14
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("182630")
	normal.border_color = Color("314653")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(9)
	var hover := normal.duplicate()
	hover.bg_color = Color("223743")
	hover.border_color = Color("7399a6")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("704936")
	pressed.border_color = Color("e2a56e")
	ui_theme.set_stylebox("normal", "Button", normal)
	ui_theme.set_stylebox("hover", "Button", hover)
	ui_theme.set_stylebox("focus", "Button", hover)
	ui_theme.set_stylebox("pressed", "Button", pressed)
	ui_theme.set_color("font_color", "Button", Color("dce7ec"))
	ui_theme.set_color("font_pressed_color", "Button", Color("fff3df"))
	theme = ui_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("081117")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_scenario_strip())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.add_child(_build_state_column())
	body.add_child(_build_trace_column())
	body.add_child(_build_rules_column())
	root.add_child(body)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_box)
	var title := Label.new()
	title.text = "UNDER THE BRIDGE"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f0dbc1"))
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "CAPTURE CHAIN IN THE FULL NIGHT  /  TICKET #11"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8195a2"))
	title_box.add_child(subtitle)

	var rule := Label.new()
	rule.text = "NO AUTONOMOUS CAPTURE  •  the player arms every route"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rule.add_theme_font_size_override("font_size", 15)
	rule.add_theme_color_override("font_color", Color("df9d65"))
	row.add_child(rule)
	return row


func _build_scenario_strip() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	for scenario_id: String in SCENARIOS:
		var button := Button.new()
		button.text = SCENARIOS[scenario_id]
		button.toggle_mode = true
		button.custom_minimum_size.y = 35
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_scenario.bind(scenario_id))
		_scenario_buttons[scenario_id] = button
		row.add_child(button)
	return _panel(row, Color("101d25"), 7)


func _build_state_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 360
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("NIGHT STATE", "Outcome, captures, Trapdoor, Escape"))
	_state_text = RichTextLabel.new()
	_state_text.bbcode_enabled = true
	_state_text.scroll_active = false
	_state_text.custom_minimum_size.y = 150
	_state_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_state_text, Color("14242d"), 13))

	column.add_child(_section_title("FOCUS PATRON", "The Patron this scenario acts on"))
	_patron_text = RichTextLabel.new()
	_patron_text.bbcode_enabled = true
	_patron_text.scroll_active = false
	_patron_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_patron_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_patron_text, Color("101b22"), 13))
	return column


func _build_trace_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.2
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("SCENARIO TRACE", "What the danger chain did, step by step"))
	_trace_text = RichTextLabel.new()
	_trace_text.bbcode_enabled = true
	_trace_text.scroll_active = false
	_trace_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trace_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_trace_text, Color("101b22"), 13))
	return column


func _build_rules_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 380
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("ACCEPTANCE CRITERIA", "Ticket #11 — one source of truth"))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 13)
	rules.text = "[color=#8195a2]TRAPDOOR CAPTURE[/color]\nA standing occupant falls; the captured Patron's Companion starts a missing-Companion clock. A seated occupant is not captured and gains Hard Evidence.\n\n[color=#8195a2]MISSING COMPANION[/color]\n+25 at 20 s, +25 at 30 s, Maximum at 40 s. Maximum from a missing Companion drives [color=#7fb0e0]Investigation[/color].\n\n[color=#8195a2]PROOF / GENERAL DANGER[/color]\nMaximum Suspicion from proof or general danger drives [color=#e7a06c]Escape[/color].\n\n[color=#8195a2]ESCAPE[/color]\nEscape forces the Night to 1x and permits exactly one 5-second Intercept per escaping Patron.\n\n[color=#8195a2]DEFEAT[/color]\nOnly a maximum-Suspicion Patron crossing the front exit causes immediate defeat. Normal Departures never do."
	column.add_child(_panel(rules, Color("121f27"), 13))
	return column


func _section_title(title: String, subtitle: String) -> Control:
	var box := VBoxContainer.new()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color("d8e2e7"))
	box.add_child(heading)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("708591"))
	box.add_child(sub)
	return box


func _panel(content: Control, color: Color, inset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = content.size_flags_vertical
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("263945")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(inset)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func _set_scenario(scenario_id: String) -> void:
	if not SCENARIOS.has(scenario_id):
		scenario_id = "trapdoor_capture"
	_scenario = scenario_id
	_session.restart_night(707)
	match scenario_id:
		"trapdoor_capture":
			_focus_patron_id = &"patron_june"
			_session.advance(100.0)
			_session.debug_force_bathroom(&"patron_june")
			_session.activate_trapdoor()
			_session.advance(20.0)
			var mara: Dictionary = _debug_for(&"patron_mara")
			_scenario_trace = "June forced into the bathroom (standing).\nTrapdoor armed: June is captured. Captures now %d.\nMara (Companion) after 20 s: %.0f, %s." % [
				_session.snapshot()["captures"], mara["suspicion"], _humanize(mara["suspicion_cause"]),
			]
		"seated_witness":
			_focus_patron_id = &"patron_mara"
			_session.advance(100.0)
			_session.debug_force_bathroom(&"patron_mara")
			_session.advance(2.05)
			_session.activate_trapdoor()
			var seated: Dictionary = _debug_for(&"patron_mara")
			_scenario_trace = "Mara forced into the bathroom, seated (using it).\nTrapdoor armed: a seated occupant is not captured.\nMara gains Hard Evidence: %.0f, %s, still %s." % [
				seated["suspicion"], _humanize(seated["suspicion_cause"]), _humanize(seated["activity"]),
			]
		"missing_investigation":
			_focus_patron_id = &"patron_mara"
			_session.advance(100.0)
			_session.debug_force_bathroom(&"patron_june")
			_session.activate_trapdoor()
			_session.advance(40.0)
			var m: Dictionary = _debug_for(&"patron_mara")
			_scenario_trace = "June captured; Mara's missing-Companion clock runs.\n40 s later Mara reaches %.0f, %s.\nResponse %s → lifecycle %s." % [
				m["suspicion"], _humanize(m["suspicion_cause"]),
				_humanize(m["suspicion_maximum_response"]), _humanize(m["lifecycle"]),
			]
		"escape_intercept":
			_focus_patron_id = &"patron_elias"
			_session.advance(200.0)
			_session.set_time_scale(4.0)
			_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
			_session.advance(1.0)
			var scale_after: float = _session.snapshot()["time_scale"]
			var refused := not _session.set_time_scale(4.0)
			var started := _session.begin_intercept(&"patron_elias", &"cultist_01")
			var second := _session.begin_intercept(&"patron_elias", &"cultist_02")
			_scenario_trace = "Elias sees his drink dosed → Escape.\nNight was 4x; Escape forced it to %.0fx (faster refused: %s).\nIntercept started: %s. Second Intercept refused: %s." % [
				scale_after, str(refused), str(started), str(not second),
			]
		"front_exit_defeat":
			_focus_patron_id = &"patron_elias"
			_session.advance(200.0)
			_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
			_session.advance(0.2)
			_session.advance(10.0)
			var loss: Dictionary = _session.snapshot()
			_scenario_trace = "Elias escapes and is not intercepted.\nHe crosses the front exit at Maximum Suspicion.\nOutcome %s, phase %s, defeat %s." % [
				_humanize(loss["outcome"]), _humanize(loss["phase"]), str(loss["defeat"]),
			]
	_refresh(_session.snapshot())


func _refresh(state: Dictionary) -> void:
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	_state_text.text = _state_markup(state)
	_patron_text.text = _patron_markup(state)
	_trace_text.text = "[color=#e2a56e][b]%s[/b][/color]\n%s" % [SCENARIOS[_scenario], _scenario_trace]


func _state_markup(state: Dictionary) -> String:
	var trapdoor: Dictionary = state["trapdoor"]
	var outcome_color := "#e65c70" if state["outcome"] == &"defeat" else "#8fbf9f"
	var lines := "Phase  [b]%s[/b]     Clock  [b]%s[/b]\nSpeed  [b]%.0fx[/b]\nOutcome  [color=%s][b]%s[/b][/color]\nCaptures  [b]%d[/b] / %d\nDefeat  [b]%s[/b]" % [
		_humanize(state["phase"]), state["clock_label"], state["time_scale"],
		outcome_color, _humanize(state["outcome"]), state["captures"],
		state["results"]["capture_quota"], str(state["defeat"]),
	]
	lines += "\nTrapdoor  [b]%s[/b]     Escaping  [b]%d[/b]" % [
		_humanize(trapdoor["state"]), state["escaping_patrons"].size(),
	]
	if not state["active_intercept"].is_empty():
		lines += "\nIntercept  [b]%.1f s left[/b]" % float(state["active_intercept"]["remaining"])
	return lines


func _patron_markup(state: Dictionary) -> String:
	var debug: Dictionary = state["debug_patron_views"][_focus_patron_id]
	var normal: Dictionary = state["normal_patron_views"][_focus_patron_id]
	return "[color=#e9edf0][b]%s[/b][/color]\nLifecycle  [b]%s[/b]\nActivity  [b]%s[/b]     Room  [b]%s[/b]\nSuspicion  [b]%.0f[/b] / 100  ·  %s\nCause  [b]%s[/b]     Response  [b]%s[/b]\nMissing target  [b]%s[/b]" % [
		normal["name"], _humanize(debug["lifecycle"]), _humanize(debug["activity"]),
		_humanize(debug["room"]), debug["suspicion"], normal["suspicion_band"],
		_humanize(debug["suspicion_cause"]), _humanize(debug["suspicion_maximum_response"]),
		_actor_name(debug["missing_target"]) if not StringName(debug["missing_target"]).is_empty() else "None",
	]


func _debug_for(patron_id: StringName) -> Dictionary:
	return _session.snapshot()["debug_patron_views"][patron_id]


func _humanize(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()


func _actor_name(actor_id: StringName) -> String:
	return String(actor_id).trim_prefix("patron_").capitalize()


func _command_line_value(prefix: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _finish_command_line_work() -> void:
	var capture_path := _command_line_value("--capture=")
	var report_path := _command_line_value("--report=")
	_capture_mode = not capture_path.is_empty() or not report_path.is_empty()
	if not report_path.is_empty():
		var absolute_report := ProjectSettings.globalize_path(report_path)
		DirAccess.make_dir_recursive_absolute(absolute_report.get_base_dir())
		var report := FileAccess.open(absolute_report, FileAccess.WRITE)
		report.store_string(JSON.stringify(_validation_report(), "  "))
	if not capture_path.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		var absolute_capture := ProjectSettings.globalize_path(capture_path)
		DirAccess.make_dir_recursive_absolute(absolute_capture.get_base_dir())
		get_viewport().get_texture().get_image().save_png(absolute_capture)
		get_tree().quit()
	elif not report_path.is_empty():
		get_tree().quit()


func _validation_report() -> Dictionary:
	# AC1: a full-Night Trapdoor Capture takes a standing occupant and starts the captured
	# Patron's Companion missing-clock; a seated occupant becomes a Hard-Evidence witness.
	var cap = GAME_SESSION_SCRIPT.new()
	cap.start_night(707)
	cap.advance(100.0)
	cap.debug_force_bathroom(&"patron_june")
	cap.activate_trapdoor()
	var june_captured: StringName = cap.snapshot()["debug_patron_views"][&"patron_june"]["lifecycle"]
	var captures_after: int = cap.snapshot()["captures"]
	cap.advance(20.0)
	var mara_missing: Dictionary = cap.snapshot()["debug_patron_views"][&"patron_mara"]

	var witness = GAME_SESSION_SCRIPT.new()
	witness.start_night(707)
	witness.advance(100.0)
	witness.debug_force_bathroom(&"patron_mara")
	witness.advance(2.05)
	witness.activate_trapdoor()
	var seated: Dictionary = witness.snapshot()["debug_patron_views"][&"patron_mara"]
	var seated_captures: int = witness.snapshot()["captures"]

	# AC2: missing-Companion Maximum drives Investigation; proof drives Escape.
	var invest = GAME_SESSION_SCRIPT.new()
	invest.start_night(707)
	invest.advance(100.0)
	invest.debug_force_bathroom(&"patron_june")
	invest.activate_trapdoor()
	invest.advance(40.0)
	var investigator: Dictionary = invest.snapshot()["debug_patron_views"][&"patron_mara"]

	var proof = GAME_SESSION_SCRIPT.new()
	proof.start_night(707)
	proof.advance(200.0)
	proof.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
	proof.advance(0.2)
	var escaper: Dictionary = proof.snapshot()["debug_patron_views"][&"patron_elias"]

	# AC3: Escape forces 1x and permits exactly one 5-second Intercept.
	var esc = GAME_SESSION_SCRIPT.new()
	esc.start_night(707)
	esc.advance(200.0)
	esc.set_time_scale(4.0)
	esc.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
	esc.advance(1.0)
	var forced_scale: float = esc.snapshot()["time_scale"]
	var faster_refused := not esc.set_time_scale(4.0)
	var first_intercept := esc.begin_intercept(&"patron_elias", &"cultist_01")
	var second_intercept := esc.begin_intercept(&"patron_elias", &"cultist_02")
	esc.advance(5.0)
	var after_intercept: Dictionary = esc.snapshot()
	var resumed: StringName = after_intercept["debug_patron_views"][&"patron_elias"]["lifecycle"]

	# AC4: only a Maximum-Suspicion front-exit crossing is defeat; Normal Departures are not.
	var clean = GAME_SESSION_SCRIPT.new()
	clean.start_night(707)
	clean.set_time_scale(4.0)
	clean.advance(300.0)
	var clean_snapshot: Dictionary = clean.snapshot()

	var loss = GAME_SESSION_SCRIPT.new()
	loss.start_night(707)
	loss.advance(200.0)
	loss.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
	loss.advance(0.2)
	loss.advance(10.0)
	var loss_snapshot: Dictionary = loss.snapshot()

	var checks := {
		"trapdoor_captures_standing_occupant": june_captured == &"captured" and captures_after == 1,
		"capture_starts_companion_missing_clock": mara_missing["suspicion"] == 25.0
			and mara_missing["suspicion_cause"] == &"missing_companion",
		"seated_occupant_is_hard_evidence_witness": seated["suspicion"] == 100.0
			and seated["suspicion_cause"] == &"hard_evidence"
			and seated["activity"] == &"seated_bathroom_use" and seated_captures == 0,
		"missing_maximum_drives_investigation": investigator["suspicion"] == 100.0
			and investigator["suspicion_cause"] == &"missing_companion"
			and investigator["lifecycle"] == &"investigating",
		"proof_maximum_drives_escape": escaper["suspicion"] == 100.0
			and escaper["suspicion_cause"] == &"hard_evidence"
			and escaper["lifecycle"] == &"escaping",
		"escape_forces_single_speed": forced_scale == 1.0 and faster_refused,
		"one_intercept_per_escaper": first_intercept and not second_intercept
			and after_intercept["active_intercept"].is_empty() and resumed == &"escaping",
		"normal_departures_are_not_defeat": not clean_snapshot["defeat"]
			and clean_snapshot["outcome"] != &"defeat"
			and clean_snapshot["patrons"]["normal_departure_count"] > 0,
		"max_suspicion_crossing_is_defeat": loss_snapshot["defeat"]
			and loss_snapshot["outcome"] == &"defeat"
			and loss_snapshot["phase"] == &"results",
	}
	return {
		"passed": not checks.values().has(false),
		"slice": "capture_chain",
		"checks": checks,
		"observed": {
			"captures_after_trapdoor": captures_after,
			"mara_missing_suspicion": mara_missing["suspicion"],
			"forced_scale": forced_scale,
			"clean_normal_departures": clean_snapshot["patrons"]["normal_departure_count"],
			"loss_outcome": loss_snapshot["outcome"],
		},
	}
