extends Control

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const PATRON_IDS: Array[StringName] = [&"patron_june", &"patron_mara"]
const SCENARIOS := {
	"line_of_sight": "LINE OF SIGHT",
	"room_hearing": "ROOM HEARING",
	"unattended_body": "UNATTENDED BODY",
	"companion": "COMPANION INFLUENCE",
	"debug_trace": "DEBUG TRACE",
}

var _session = GAME_SESSION_SCRIPT.new()
var _selected_patron_id: StringName = &"patron_june"
var _scenario: String = "line_of_sight"
var _scenario_trace: String = ""
var _debug_visible: bool = false
var _capture_mode: bool = false
var _patron_buttons: Dictionary = {}
var _scenario_buttons: Dictionary = {}
var _selected_title: Label
var _selected_band: Label
var _selected_cue: Label
var _selected_detail: RichTextLabel
var _debug_panel: PanelContainer
var _debug_text: RichTextLabel
var _timeline_text: RichTextLabel
var _debug_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	_build_ui()
	_session.snapshot_changed.connect(_refresh)
	_set_scenario(_command_line_value("--stage=", "line_of_sight"))
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
	body.add_child(_build_patron_column())
	body.add_child(_build_selected_column())
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
	subtitle.text = "PERCEPTION & DANGER  /  TICKET #10"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8195a2"))
	title_box.add_child(subtitle)

	var visible_rule := Label.new()
	visible_rule.text = "PRODUCER  •  perception emits stimuli, never chooses states"
	visible_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	visible_rule.add_theme_font_size_override("font_size", 15)
	visible_rule.add_theme_color_override("font_color", Color("91c5a1"))
	row.add_child(visible_rule)
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


func _build_patron_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 0.8
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("PATRONS", "June and Mara share one table"))
	for patron_id in PATRON_IDS:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size.y = 73
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_patron.bind(patron_id))
		_patron_buttons[patron_id] = button
		column.add_child(button)
	var note := RichTextLabel.new()
	note.bbcode_enabled = true
	note.fit_content = false
	note.scroll_active = false
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("normal_font_size", 12)
	note.text = "[color=#8195a2]NORMAL PLAY[/color]\nA band and the visible cause are all the player reads. Facing, hearing, body pressure, and Companion nerves stay hidden."
	column.add_child(_panel(note, Color("101b22"), 11))
	return column


func _build_selected_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.25
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("SELECTED PATRON", "Player-readable state and hidden perception"))
	var hero := VBoxContainer.new()
	hero.add_theme_constant_override("separation", 5)
	_selected_title = Label.new()
	_selected_title.add_theme_font_size_override("font_size", 22)
	_selected_title.add_theme_color_override("font_color", Color("e9edf0"))
	hero.add_child(_selected_title)
	_selected_band = Label.new()
	_selected_band.add_theme_font_size_override("font_size", 27)
	hero.add_child(_selected_band)
	_selected_cue = Label.new()
	_selected_cue.add_theme_font_size_override("font_size", 15)
	_selected_cue.add_theme_color_override("font_color", Color("b7c6ce"))
	hero.add_child(_selected_cue)
	_selected_detail = RichTextLabel.new()
	_selected_detail.bbcode_enabled = true
	_selected_detail.custom_minimum_size.y = 30
	_selected_detail.scroll_active = false
	_selected_detail.add_theme_font_size_override("normal_font_size", 13)
	hero.add_child(_selected_detail)
	column.add_child(_panel(hero, Color("14242d"), 13))

	_debug_panel = PanelContainer.new()
	_debug_text = RichTextLabel.new()
	_debug_text.bbcode_enabled = true
	_debug_text.custom_minimum_size.y = 120
	_debug_text.scroll_active = false
	_debug_text.add_theme_font_size_override("normal_font_size", 13)
	_debug_panel.add_child(_debug_text)
	var debug_style := StyleBoxFlat.new()
	debug_style.bg_color = Color("241f2d")
	debug_style.border_color = Color("765f88")
	debug_style.set_border_width_all(1)
	debug_style.set_corner_radius_all(6)
	debug_style.set_content_margin_all(11)
	_debug_panel.add_theme_stylebox_override("panel", debug_style)
	column.add_child(_debug_panel)

	column.add_child(_section_title("PERCEPTION TRACE", "Source, recipient, resulting cause, timing"))
	_timeline_text = RichTextLabel.new()
	_timeline_text.bbcode_enabled = true
	_timeline_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline_text.scroll_active = false
	_timeline_text.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(_panel(_timeline_text, Color("101b22"), 11))
	return column


func _build_rules_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 390
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.1
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("APPROVED RULES", "One source of truth for perception"))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 13)
	rules.text = "[color=#8195a2]LINE OF SIGHT[/color]\nSame room, inside a 60° facing cone, within 20 m. No intra-room occluders.\n\n[color=#8195a2]ROOM HEARING[/color]\nSame room or a directly adjacent room. front — main hall — hallway — bathroom.\n\n[color=#8195a2]UNATTENDED BODY[/color]\nAfter a 3 s grace, +5 to every active Patron every 5 s, per body. Pauses while supported or dragged; a drop restarts the grace.\n\n[color=#8195a2]COMPANION INFLUENCE[/color]\nEvery 10 s, drift up to +5 toward the highest-Suspicion group member within 5 m and the same room. Reaching 100 selects [color=#e7a06c]Escape[/color]."
	column.add_child(_panel(rules, Color("121f27"), 11))

	_debug_button = Button.new()
	_debug_button.text = "SHOW DEBUG"
	_debug_button.toggle_mode = true
	_debug_button.custom_minimum_size.y = 38
	_debug_button.pressed.connect(_toggle_debug)
	column.add_child(_panel(_debug_button, Color("101d25"), 7))
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
		scenario_id = "line_of_sight"
	_scenario = scenario_id
	_session.restart_night(707)
	_session.advance(100.0)
	_selected_patron_id = &"patron_june"
	_debug_visible = scenario_id != "line_of_sight"
	match scenario_id:
		"line_of_sight":
			_session.report_danger_event(&"body_drag_seen_first", &"visual", &"main_hall", &"cultist_01", Vector2(0.0, 0.0))
			_session.report_danger_event(&"body_drag_seen_first", &"visual", &"main_hall", &"cultist_01", Vector2(-18.0, 6.0))
			_scenario_trace = "Drag at the bar (front, in cone): June & Mara see it, +50.\nDrag behind them (outside the cone): unseen, no change."
		"room_hearing":
			_session.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_02")
			_session.report_danger_event(&"knockout_heard", &"auditory", &"bathroom", &"cultist_02")
			_scenario_trace = "Knockout in the main hall: both hear it, +25.\nKnockout in the bathroom (not adjacent): unheard."
		"unattended_body":
			_session.add_unattended_body(&"body_01", &"hallway", Vector2(14.0, 6.0))
			_session.advance(3.0)
			var before_tick: float = _debug_for(&"patron_june")["suspicion"]
			_session.advance(5.0)
			var first_tick: float = _debug_for(&"patron_june")["suspicion"]
			_session.advance(5.0)
			var second_tick: float = _debug_for(&"patron_june")["suspicion"]
			_scenario_trace = "Grace 3.0 s: %.0f (no pressure yet)\n+5.0 s: %.0f (first +5)\n+5.0 s: %.0f (global to every active Patron)" % [before_tick, first_tick, second_tick]
		"companion":
			_selected_patron_id = &"patron_mara"
			_session.report_patron_stimulus(&"patron_june", &"drink_dosed_seen")
			_session.advance(10.0)
			var step_one: float = _debug_for(&"patron_mara")["suspicion"]
			_session.advance(200.0)
			var settled: Dictionary = _debug_for(&"patron_mara")
			_scenario_trace = "June pinned at 100 by Hard Evidence.\nMara after 10 s: %.0f (up to +5 toward the target)\nMara settled: %.0f → %s" % [
				step_one, settled["suspicion"], _humanize(settled["suspicion_maximum_response"]),
			]
		"debug_trace":
			_session.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_02")
			_session.add_unattended_body(&"body_01", &"main_hall", Vector2(0.0, 8.0))
			_session.advance(8.0)
			_scenario_trace = "The debug view names each perception: source, recipient, resulting cause, and the time it landed."
	_refresh(_session.snapshot())


func _select_patron(patron_id: StringName) -> void:
	_selected_patron_id = patron_id
	_refresh(_session.snapshot())


func _toggle_debug() -> void:
	_debug_visible = _debug_button.button_pressed
	_refresh(_session.snapshot())


func _refresh(state: Dictionary) -> void:
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	for patron_id in PATRON_IDS:
		var normal: Dictionary = state["normal_patron_views"][patron_id]
		var button: Button = _patron_buttons[patron_id]
		button.text = "%s\n%s  •  %s" % [normal["name"], normal["suspicion_band"], normal["suspicion_cue"]]
		button.button_pressed = patron_id == _selected_patron_id
	var normal: Dictionary = state["normal_patron_views"][_selected_patron_id]
	var debug: Dictionary = state["debug_patron_views"][_selected_patron_id]
	_selected_title.text = "%s  /  %s" % [normal["name"], normal["visible_activity"]]
	_selected_band.text = normal["suspicion_band"]
	_selected_band.add_theme_color_override("font_color", _band_color(normal["suspicion_band"]))
	_selected_cue.text = "VISIBLE CUE  •  %s" % normal["suspicion_cue"]
	_selected_detail.text = "Room  [b]%s[/b]     Companion  [b]%s[/b]" % [
		_humanize(debug["room"]), _companion_names(normal["companions"])
	]
	_debug_panel.visible = _debug_visible
	if _debug_button != null:
		_debug_button.button_pressed = _debug_visible
		_debug_button.text = "HIDE DEBUG" if _debug_visible else "SHOW DEBUG"
	_debug_text.text = _debug_markup(debug)
	_timeline_text.text = "[color=#e2a56e][b]%s[/b][/color]\n%s" % [SCENARIOS[_scenario], _scenario_trace]


func _debug_markup(debug: Dictionary) -> String:
	var lines := "[color=#ad8dc0][b]DEBUG — EXACT VALUE %.0f / 100[/b][/color]\nRoom  [b]%s[/b]     Cause  [b]%s[/b]     Response  [b]%s[/b]" % [
		debug["suspicion"], _humanize(debug["room"]), _humanize(debug["suspicion_cause"]),
		_humanize(debug["suspicion_maximum_response"]),
	]
	var trace: Array = debug["recent_perceptions"]
	if trace.is_empty():
		return "%s\n[color=#708591]No perception recorded.[/color]" % lines
	lines += "\n[color=#8195a2]RECENT PERCEPTIONS[/color]"
	for index in range(maxi(0, trace.size() - 4), trace.size()):
		var entry: Dictionary = trace[index]
		lines += "\n[color=#c9b6da]%.1fs[/color]  %s → %s  ·  %s  ⇒  %s" % [
			entry["at"], _humanize(entry["source"]), _humanize(entry["recipient"]),
			_humanize(entry["stimulus"]), _humanize(entry["cause"]),
		]
	return lines


func _debug_for(patron_id: StringName) -> Dictionary:
	return _session.snapshot()["debug_patron_views"][patron_id]


func _band_color(band: String) -> Color:
	match band:
		"Uneasy": return Color("d3be76")
		"Suspicious": return Color("df9d65")
		"Alarmed": return Color("df745f")
		"Maximum": return Color("e65c70")
	return Color("8fbf9f")


func _humanize(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()


func _actor_name(actor_id: StringName) -> String:
	return String(actor_id).trim_prefix("patron_").capitalize()


func _companion_names(companions: Array) -> String:
	var names: Array[String] = []
	for companion_id in companions:
		names.append(_actor_name(companion_id))
	return "None" if names.is_empty() else ", ".join(names)


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
	# Visual line of sight: seen in front and same room, unseen behind or cross-room.
	var sight = GAME_SESSION_SCRIPT.new()
	sight.start_night(707)
	sight.advance(100.0)
	var seen: Array = sight.report_danger_event(&"body_drag_seen_first", &"visual", &"main_hall", &"cultist_01", Vector2(0.0, 0.0))
	var behind: Array = sight.report_danger_event(&"body_drag_seen_first", &"visual", &"main_hall", &"cultist_01", Vector2(-18.0, 6.0))
	var cross: Array = sight.report_danger_event(&"drink_dosed_seen", &"visual", &"bathroom", &"cultist_01", Vector2(0.0, 0.0))

	# Room hearing: same room heard, non-adjacent room unheard.
	var hearing = GAME_SESSION_SCRIPT.new()
	hearing.start_night(707)
	hearing.advance(100.0)
	var heard: Array = hearing.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_02")
	var unheard: Array = hearing.report_danger_event(&"knockout_heard", &"auditory", &"bathroom", &"cultist_02")

	# Unattended Body: grace, then global +5 per interval per body; pause on support.
	var body = GAME_SESSION_SCRIPT.new()
	body.start_night(707)
	body.advance(100.0)
	body.add_unattended_body(&"body_a", &"hallway", Vector2(14.0, 6.0))
	body.add_unattended_body(&"body_b", &"main_hall", Vector2(0.0, 8.0))
	body.advance(3.0)
	var body_grace: float = body.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]
	body.advance(5.0)
	var body_first: float = body.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]
	var body_mara: float = body.snapshot()["debug_patron_views"][&"patron_mara"]["suspicion"]
	body.set_unattended_body_state(&"body_a", &"supported")
	body.advance(5.0)
	var body_supported: float = body.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]

	# Companion influence: drift up toward the pinned neighbour, settle at 100 → Escape.
	var companion = GAME_SESSION_SCRIPT.new()
	companion.start_night(707)
	companion.advance(100.0)
	companion.report_patron_stimulus(&"patron_june", &"drink_dosed_seen")
	companion.advance(10.0)
	var companion_first: float = companion.snapshot()["debug_patron_views"][&"patron_mara"]["suspicion"]
	companion.advance(200.0)
	var companion_debug: Dictionary = companion.snapshot()["debug_patron_views"][&"patron_mara"]

	# Debug trace: names source, recipient, resulting cause, and timing.
	var trace_session = GAME_SESSION_SCRIPT.new()
	trace_session.start_night(707)
	trace_session.advance(100.0)
	trace_session.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_02")
	var trace_debug: Dictionary = trace_session.snapshot()["debug_patron_views"][&"patron_june"]
	var trace_normal: Dictionary = trace_session.snapshot()["normal_patron_views"][&"patron_june"]
	var trace_entry: Dictionary = trace_debug["recent_perceptions"][-1] if not trace_debug["recent_perceptions"].is_empty() else {}

	var checks := {
		"visual_requires_facing_and_same_room": (&"patron_june" in seen) and behind.is_empty() and cross.is_empty(),
		"sound_uses_room_relationship": (&"patron_june" in heard) and unheard.is_empty(),
		"body_pressure_after_grace_is_global": body_grace == 0.0 and body_first == 10.0 and body_mara == 10.0,
		"body_pressure_pauses_when_supported": body_supported == 15.0,
		"companion_drifts_up_and_escapes": companion_first == 5.0 and companion_debug["suspicion"] == 100.0 and companion_debug["suspicion_maximum_response"] == &"escape",
		"debug_trace_is_complete": not trace_entry.is_empty()
			and trace_entry["source"] == &"cultist_02"
			and trace_entry["recipient"] == &"patron_june"
			and trace_entry["cause"] == &"general_danger"
			and trace_entry.has("at")
			and not trace_normal.has("recent_perceptions"),
	}
	return {
		"passed": not checks.values().has(false),
		"slice": "perception_danger",
		"checks": checks,
		"observed": {
			"body_pressure_stages": [body_grace, body_first, body_supported],
			"companion_first_step": companion_first,
			"companion_settled": companion_debug["suspicion"],
		},
	}
