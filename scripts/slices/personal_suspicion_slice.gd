extends Control

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const PATRON_IDS: Array[StringName] = [&"patron_june", &"patron_mara", &"patron_elias"]
const SCENARIOS := {
	"independent": "INDEPENDENT BANDS",
	"soft_recovery": "SOFT RECOVERY",
	"hard_evidence": "HARD EVIDENCE",
	"max_drunk": "MAX DRUNK DOWNGRADE",
	"maximum_selection": "MAXIMUM RESPONSE",
}

var _session = GAME_SESSION_SCRIPT.new()
var _selected_patron_id: StringName = &"patron_june"
var _scenario: String = "independent"
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
	_set_scenario(_command_line_value("--stage=", "independent"))
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
	root.add_child(_build_controls())


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
	subtitle.text = "PERSONAL SUSPICION  /  TICKET #9"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8195a2"))
	title_box.add_child(subtitle)

	var visible_rule := Label.new()
	visible_rule.text = "PLAYER VIEW  •  qualitative bands, visible causes"
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
	column.add_child(_section_title("PATRONS", "Each Patron owns an independent value"))
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
	note.text = "[color=#8195a2]NORMAL PLAY[/color]\nExact values stay hidden. A band and the latest visible cause are enough to read the room."
	column.add_child(_panel(note, Color("101b22"), 11))
	return column


func _build_selected_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.25
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("SELECTED PATRON", "Player-readable state and causal explanation"))
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
	_debug_text.custom_minimum_size.y = 90
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

	column.add_child(_section_title("CAUSE TRACE", "What changed, and why"))
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
	column.add_child(_section_title("APPROVED RULES", "One source of truth for observation and recovery"))
	var bands := RichTextLabel.new()
	bands.bbcode_enabled = true
	bands.custom_minimum_size.y = 145
	bands.scroll_active = false
	bands.add_theme_font_size_override("normal_font_size", 13)
	bands.text = "[color=#8fbf9f][b]CALM[/b][/color]  0–24\n[color=#d3be76][b]UNEASY[/b][/color]  25–49\n[color=#df9d65][b]SUSPICIOUS[/b][/color]  50–74\n[color=#df745f][b]ALARMED[/b][/color]  75–99\n[color=#e65c70][b]MAXIMUM[/b][/color]  100"
	column.add_child(_panel(bands, Color("121f27"), 11))

	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 13)
	rules.text = "[color=#8195a2]SOFT SUSPICION[/color]\n20 seconds quiet, then −5 every 10 seconds.\n\n[color=#8195a2]HARD EVIDENCE[/color]\nSets 100 permanently → [color=#e7a06c]Escape[/color].\n\n[color=#8195a2]MAX DRUNK OBSERVER[/color]\nEach Hard Evidence event becomes recoverable +25.\n\n[color=#8195a2]MISSING COMPANION AT 40s[/color]\nSets 100 → [color=#d3be76]Investigation[/color]."
	column.add_child(_panel(rules, Color("121f27"), 11))
	return column


func _build_controls() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var actions := [
		["CANCEL ORDER  +15", Callable(self, "_apply_stimulus").bind(&"cancelled_order", false)],
		["HEAR KNOCKOUT  +25", Callable(self, "_apply_stimulus").bind(&"knockout_heard", false)],
		["SEE HARD EVIDENCE", Callable(self, "_apply_stimulus").bind(&"drink_dosed_seen", false)],
		["MAX DRUNK SEES IT  +25", Callable(self, "_apply_stimulus").bind(&"knockout_witnessed", true)],
		["QUIET +10s", Callable(self, "_advance_quiet").bind(10.0)],
	]
	for action in actions:
		var button := Button.new()
		button.text = action[0]
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(action[1])
		row.add_child(button)
	_debug_button = Button.new()
	_debug_button.text = "SHOW DEBUG"
	_debug_button.toggle_mode = true
	_debug_button.custom_minimum_size = Vector2(122, 38)
	_debug_button.pressed.connect(_toggle_debug)
	row.add_child(_debug_button)
	return _panel(row, Color("101d25"), 7)


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
		scenario_id = "independent"
	_scenario = scenario_id
	_session.restart_night(707)
	_session.advance(190.0)
	_selected_patron_id = &"patron_june"
	_debug_visible = scenario_id != "independent"
	match scenario_id:
		"independent":
			_session.report_patron_stimulus(&"patron_june", &"cancelled_order")
			_session.report_patron_stimulus(&"patron_june", &"cancelled_order")
			_scenario_trace = "June: 0 + 15 + 15 = Uneasy\nMara: no observation = Calm\nElias: no observation = Calm"
		"soft_recovery":
			_session.report_patron_stimulus(&"patron_june", &"cancelled_order")
			_session.report_patron_stimulus(&"patron_june", &"cancelled_order")
			_session.advance(29.9)
			var before_tick: float = _debug_for(&"patron_june")["suspicion"]
			_session.advance(0.1)
			var first_tick: float = _debug_for(&"patron_june")["suspicion"]
			_session.advance(10.0)
			var second_tick: float = _debug_for(&"patron_june")["suspicion"]
			_scenario_trace = "Quiet 29.9s: %.0f (no early recovery)\nQuiet 30.0s: %.0f (first −5)\nQuiet 40.0s: %.0f (next −5)" % [before_tick, first_tick, second_tick]
		"hard_evidence":
			_selected_patron_id = &"patron_mara"
			_session.report_patron_stimulus(&"patron_mara", &"drink_dosed_seen")
			_session.advance(120.0)
			_scenario_trace = "Mara sees a dosed drink → Hard Evidence\nSuspicion sets to Maximum immediately\n120 quiet seconds later: still 100 → Escape"
		"max_drunk":
			_session.report_patron_stimulus(&"patron_june", &"knockout_witnessed", true)
			_session.advance(30.0)
			_session.report_patron_stimulus(&"patron_june", &"trapdoor_capture_witnessed", true)
			_scenario_trace = "Max Drunk sees Hard Evidence: +25\n30 quiet seconds: −5\nSees different Hard Evidence: +25\nTwo downgrades total → recoverable 45"
		"maximum_selection":
			_session.report_patron_stimulus(&"patron_june", &"drink_dosed_seen")
			_session.report_patron_stimulus(&"patron_mara", &"missing_companion_40")
			_scenario_trace = "June: Hard Evidence → Maximum → Escape\nMara: Missing Companion at 40s → Maximum → Investigation\nMaximum response follows the classified cause"
	_refresh(_session.snapshot())


func _select_patron(patron_id: StringName) -> void:
	_selected_patron_id = patron_id
	_refresh(_session.snapshot())


func _apply_stimulus(stimulus: StringName, max_drunk_observation: bool) -> void:
	if _session.report_patron_stimulus(_selected_patron_id, stimulus, max_drunk_observation):
		_scenario_trace = "%s\n%s → %s%s" % [
			_scenario_trace,
			_actor_name(_selected_patron_id),
			String(stimulus).replace("_", " ").capitalize(),
			" (Max Drunk observation)" if max_drunk_observation else "",
		]


func _advance_quiet(seconds: float) -> void:
	_session.advance(seconds)
	_scenario_trace = "%s\nAll Patrons: %.0f quiet seconds advanced" % [_scenario_trace, seconds]


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
	_selected_cue.text = "VISIBLE CAUSE  •  %s" % normal["suspicion_cue"]
	_selected_detail.text = "Mood  [b]%s[/b]     Friendship  [b]%s[/b]     Companion  [b]%s[/b]" % [
		normal["mood"], normal["friendship"], _companion_names(normal["companions"])
	]
	_debug_panel.visible = _debug_visible
	_debug_button.button_pressed = _debug_visible
	_debug_button.text = "HIDE DEBUG" if _debug_visible else "SHOW DEBUG"
	_debug_text.text = _debug_markup(debug)
	_timeline_text.text = "[color=#e2a56e][b]%s[/b][/color]\n%s" % [SCENARIOS[_scenario], _scenario_trace]


func _debug_markup(debug: Dictionary) -> String:
	var recovery := "permanent / not recoverable"
	if debug["suspicion_recoverable"]:
		recovery = "next −5 in %.1fs" % debug["suspicion_next_recovery_in"]
	return "[color=#ad8dc0][b]DEBUG — EXACT VALUE %.0f / 100[/b][/color]\nCause  [b]%s[/b]     Latest stimulus  [b]%s[/b]\nQuiet  [b]%.1fs[/b]     Recovery  [b]%s[/b]\nHard Evidence downgrades  [b]%d[/b]     Maximum response  [b]%s[/b]" % [
		debug["suspicion"], _humanize(debug["suspicion_cause"]), _humanize(debug["latest_suspicion_stimulus"]),
		debug["suspicion_quiet_seconds"], recovery, debug["hard_evidence_downgrade_count"],
		_humanize(debug["suspicion_maximum_response"]),
	]


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
	var independent = GAME_SESSION_SCRIPT.new()
	independent.start_night(707)
	independent.advance(190.0)
	independent.report_patron_stimulus(&"patron_june", &"cancelled_order")
	independent.report_patron_stimulus(&"patron_june", &"cancelled_order")
	var independent_state: Dictionary = independent.snapshot()

	var recovery = GAME_SESSION_SCRIPT.new()
	recovery.start_night(707)
	recovery.advance(190.0)
	recovery.report_patron_stimulus(&"patron_june", &"cancelled_order")
	recovery.report_patron_stimulus(&"patron_june", &"cancelled_order")
	recovery.advance(29.9)
	var recovery_before: float = recovery.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]
	recovery.advance(0.1)
	var recovery_first: float = recovery.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]
	recovery.advance(10.0)
	var recovery_second: float = recovery.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]

	var hard = GAME_SESSION_SCRIPT.new()
	hard.start_night(707)
	hard.advance(190.0)
	hard.report_patron_stimulus(&"patron_mara", &"drink_dosed_seen")
	hard.advance(120.0)
	var hard_debug: Dictionary = hard.snapshot()["debug_patron_views"][&"patron_mara"]

	var drunk = GAME_SESSION_SCRIPT.new()
	drunk.start_night(707)
	drunk.advance(190.0)
	drunk.report_patron_stimulus(&"patron_june", &"knockout_witnessed", true)
	drunk.advance(30.0)
	drunk.report_patron_stimulus(&"patron_june", &"trapdoor_capture_witnessed", true)
	var drunk_debug: Dictionary = drunk.snapshot()["debug_patron_views"][&"patron_june"]

	var selection = GAME_SESSION_SCRIPT.new()
	selection.start_night(707)
	selection.advance(190.0)
	selection.report_patron_stimulus(&"patron_june", &"drink_dosed_seen")
	selection.report_patron_stimulus(&"patron_mara", &"missing_companion_40")
	var selection_debug: Dictionary = selection.snapshot()["debug_patron_views"]
	var checks := {
		"independent_bands": independent_state["normal_patron_views"][&"patron_june"]["suspicion_band"] == "Uneasy" and independent_state["normal_patron_views"][&"patron_mara"]["suspicion_band"] == "Calm",
		"normal_hides_exact_value": not independent_state["normal_patron_views"][&"patron_june"].has("suspicion"),
		"approved_soft_recovery": recovery_before == 30.0 and recovery_first == 25.0 and recovery_second == 20.0,
		"hard_evidence_permanent": hard_debug["suspicion"] == 100.0 and not hard_debug["suspicion_recoverable"],
		"max_drunk_downgrades_each_event": drunk_debug["suspicion"] == 45.0 and drunk_debug["hard_evidence_downgrade_count"] == 2,
		"maximum_response_selection": selection_debug[&"patron_june"]["suspicion_maximum_response"] == &"escape" and selection_debug[&"patron_mara"]["suspicion_maximum_response"] == &"investigation",
	}
	return {
		"passed": not checks.values().has(false),
		"slice": "personal_suspicion",
		"checks": checks,
		"observed": {
			"soft_recovery": [recovery_before, recovery_first, recovery_second],
			"hard_evidence_after_120_quiet_seconds": hard_debug["suspicion"],
			"max_drunk_final_suspicion": drunk_debug["suspicion"],
		},
	}
