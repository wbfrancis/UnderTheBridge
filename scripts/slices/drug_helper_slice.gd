extends Control

# Headless-first evidence slice for Ticket #12: Drugged Drinks, drowsiness and collapse, the
# strongest conscious Companion becoming Helper, and one seeded Rescue Persuasion — all through
# the public GameSession API. --report writes a machine-checkable validation file, --capture a PNG.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const SCENARIOS := {
	"prepare_and_collapse": "PREPARE & COLLAPSE",
	"helper_carry": "HELPER CARRY",
	"rescue_chance": "RESCUE CHANCE",
	"rescue_success": "RESCUE SUCCESS",
	"rescue_failure": "RESCUE FAILURE",
}
const SUCCESS_SEED := 13
const FAILURE_SEED := 1

var _session = GAME_SESSION_SCRIPT.new()
var _scenario: String = "prepare_and_collapse"
var _victim_id: StringName = &"patron_mara"
var _helper_id: StringName = &"patron_june"
var _scenario_trace: String = ""
var _capture_mode: bool = false
var _scenario_buttons: Dictionary = {}
var _state_text: RichTextLabel
var _victim_text: RichTextLabel
var _trace_text: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	_build_ui()
	_set_scenario(_command_line_value("--stage=", "prepare_and_collapse"))
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
	subtitle.text = "DRUGGED DRINKS & HELPER RESCUE  /  TICKET #12"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8195a2"))
	title_box.add_child(subtitle)

	var rule := Label.new()
	rule.text = "NO AUTONOMOUS CAPTURE  •  the player prepares every dose"
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
	column.add_child(_section_title("NIGHT STATE", "Doses, collapse, Helper, Rescue"))
	_state_text = RichTextLabel.new()
	_state_text.bbcode_enabled = true
	_state_text.scroll_active = false
	_state_text.custom_minimum_size.y = 150
	_state_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_state_text, Color("14242d"), 13))

	column.add_child(_section_title("VICTIM & HELPER", "Countdown, roles, Suspicion"))
	_victim_text = RichTextLabel.new()
	_victim_text.bbcode_enabled = true
	_victim_text.scroll_active = false
	_victim_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_victim_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_victim_text, Color("101b22"), 13))
	return column


func _build_trace_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.2
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("SCENARIO TRACE", "What the drug route did, step by step"))
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
	column.add_child(_section_title("ACCEPTANCE CRITERIA", "Ticket #12 — one source of truth"))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 13)
	rules.text = "[color=#8195a2]DRUGGED DRINK[/color]\nTwo doses per Night. An 8-second preparation dooms the drink; the consumer-owned countdown starts at first sip, drowsy at 10 s, collapse at 20 s.\n\n[color=#8195a2]HELPER[/color]\nThe least-intoxicated conscious Companion reacts after 2 s, lifts for 4 s, then carries the victim toward the front at 60% speed.\n\n[color=#8195a2]RESCUE PERSUASION[/color]\nchance = clamp(25 + 0.7 x (Friendship - Suspicion), 5, 95). Displayed before commitment; one seeded roll at completion.\n\n[color=#8195a2]OUTCOME[/color]\nSuccess captures both at the [color=#e7a06c]Tunnel Intake[/color]. Failure adds 25 Suspicion to the Helper and resumes leaving; reaching the front leaves both."
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
		scenario_id = "prepare_and_collapse"
	_scenario = scenario_id
	_victim_id = &"patron_mara"
	_helper_id = &"patron_june"
	var night_seed := SUCCESS_SEED if scenario_id == "rescue_success" else FAILURE_SEED if scenario_id == "rescue_failure" else 707
	_session.restart_night(night_seed)
	_session.advance(95.0)
	match scenario_id:
		"prepare_and_collapse":
			var doses_before: int = _session.snapshot()["doses_remaining"]
			_session.prepare_drugged_drink(&"patron_mara", &"cultist_01")
			_session.advance(8.1)
			var doses_after: int = _session.snapshot()["doses_remaining"]
			_session.advance(22.0)
			var victim: Dictionary = _debug_for(&"patron_mara")
			_scenario_trace = "Prepared a dose for Mara (doses %d -> %d).\nFirst sip started her 20 s countdown.\nCountdown %.0f s -> lifecycle %s." % [
				doses_before, doses_after, victim["drug_countdown"], _humanize(victim["lifecycle"]),
			]
		"helper_carry":
			_session.prepare_drugged_drink(&"patron_mara", &"cultist_01")
			_session.advance(30.1)
			_session.advance(6.1)
			var helper: Dictionary = _debug_for(&"patron_june")
			_scenario_trace = "Mara collapses; June is the conscious Companion.\nAfter a 2 s reaction and 4 s lift, June carries her.\nJune lifecycle %s, activity %s." % [
				_humanize(helper["lifecycle"]), _humanize(helper["activity"]),
			]
		"rescue_chance":
			_session.report_patron_stimulus(&"patron_june", &"missing_companion_20")
			_session.prepare_drugged_drink(&"patron_mara", &"cultist_01")
			_session.advance(36.2)
			var chance: float = _session.rescue_persuasion_chance(&"cultist_01")
			var helper_suspicion: float = _debug_for(&"patron_june")["suspicion"]
			_scenario_trace = "June (Helper) carries with %0.0f Suspicion, Friendship 0.\nchance = clamp(25 + 0.7 x (0 - %0.0f), 5, 95).\nDisplayed Rescue Persuasion chance: %0.1f%%." % [
				helper_suspicion, helper_suspicion, chance,
			]
		"rescue_success":
			_session.prepare_drugged_drink(&"patron_mara", &"cultist_01")
			_session.advance(36.2)
			var win_chance: float = _session.rescue_persuasion_chance(&"cultist_01")
			_session.attempt_rescue_persuasion(&"cultist_01")
			_session.advance(6.1)
			var won: Dictionary = _session.snapshot()
			_scenario_trace = "Cultist 01 attempts Rescue Persuasion at %0.1f%%.\nThe seeded roll succeeds.\nCaptures now %d — both captured at the Tunnel Intake." % [
				win_chance, won["captures"],
			]
		"rescue_failure":
			_session.prepare_drugged_drink(&"patron_mara", &"cultist_01")
			_session.advance(36.2)
			var lose_chance: float = _session.rescue_persuasion_chance(&"cultist_01")
			_session.attempt_rescue_persuasion(&"cultist_01")
			_session.advance(6.1)
			var helper_after: Dictionary = _debug_for(&"patron_june")
			_scenario_trace = "Cultist 01 attempts Rescue Persuasion at %0.1f%%.\nThe seeded roll fails: June gains 25 Suspicion (now %0.0f).\nJune resumes carrying (%s); both will leave." % [
				lose_chance, helper_after["suspicion"], _humanize(helper_after["activity"]),
			]
	_refresh(_session.snapshot())


func _refresh(state: Dictionary) -> void:
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	_state_text.text = _state_markup(state)
	_victim_text.text = _victim_markup(state)
	_trace_text.text = "[color=#e2a56e][b]%s[/b][/color]\n%s" % [SCENARIOS[_scenario], _scenario_trace]


func _state_markup(state: Dictionary) -> String:
	var collapses: Dictionary = state["collapses"]
	var lines := "Phase  [b]%s[/b]     Clock  [b]%s[/b]\nDoses left  [b]%d[/b] / 2\nCaptures  [b]%d[/b] / %d\nDefeat  [b]%s[/b]" % [
		_humanize(state["phase"]), state["clock_label"], state["doses_remaining"],
		state["captures"], state["results"]["capture_quota"], str(state["defeat"]),
	]
	if not state["drug_prep"].is_empty():
		lines += "\nPreparing dose  [b]%.1f s[/b]" % float(state["drug_prep"]["remaining"])
	if collapses.has(_victim_id):
		var collapse: Dictionary = collapses[_victim_id]
		lines += "\nCollapse phase  [b]%s[/b]  ·  [b]%.1f s[/b]" % [
			_humanize(collapse["phase"]), float(collapse["remaining"]),
		]
		if float(collapse["last_roll"]) >= 0.0:
			lines += "\nRoll  [b]%.1f[/b]  vs  chance  [b]%.1f%%[/b]" % [
				float(collapse["last_roll"]), float(collapse["last_chance"]),
			]
	return lines


func _victim_markup(state: Dictionary) -> String:
	var victim: Dictionary = state["debug_patron_views"][_victim_id]
	var helper: Dictionary = state["debug_patron_views"][_helper_id]
	return "[color=#e9edf0][b]Victim — %s[/b][/color]\nLifecycle  [b]%s[/b]     Room  [b]%s[/b]\nDrug countdown  [b]%.1f[/b] / 20\nHelper  [b]%s[/b]\n\n[color=#e9edf0][b]Helper — %s[/b][/color]\nLifecycle  [b]%s[/b]     Activity  [b]%s[/b]\nSuspicion  [b]%.0f[/b] / 100  ·  %s" % [
		_actor_name(_victim_id), _humanize(victim["lifecycle"]), _humanize(victim["room"]),
		victim["drug_countdown"], _actor_name(victim["helper_id"]) if not StringName(victim["helper_id"]).is_empty() else "None",
		_actor_name(_helper_id), _humanize(helper["lifecycle"]), _humanize(helper["activity"]),
		helper["suspicion"], state["normal_patron_views"][_helper_id]["suspicion_band"],
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


func _carry_session(night_seed: int, helper_suspicion_stimulus: StringName):
	var session = GAME_SESSION_SCRIPT.new()
	session.start_night(night_seed)
	session.advance(95.0)
	if not helper_suspicion_stimulus.is_empty():
		session.report_patron_stimulus(&"patron_june", helper_suspicion_stimulus)
	session.prepare_drugged_drink(&"patron_mara", &"cultist_01")
	session.advance(36.2)  # collapse + reaction + lift => carrying
	return session


func _validation_report() -> Dictionary:
	# AC1: two doses; 8s preparation spends one; consumer-owned countdown; drowsy@10, collapse@20.
	var drug = GAME_SESSION_SCRIPT.new()
	drug.start_night(707)
	var doses_start: int = drug.snapshot()["doses_remaining"]
	drug.advance(95.0)
	drug.prepare_drugged_drink(&"patron_mara", &"cultist_01")
	drug.advance(8.1)
	var doses_after: int = drug.snapshot()["doses_remaining"]
	drug.advance(1.5)
	var sip_countdown: float = drug.snapshot()["debug_patron_views"][&"patron_mara"]["drug_countdown"]
	drug.advance(21.0)
	var collapsed: StringName = drug.snapshot()["debug_patron_views"][&"patron_mara"]["lifecycle"]

	# AC2: least-intoxicated conscious Companion becomes Helper and carries.
	var carry = _carry_session(707, &"")
	var helper: Dictionary = carry.snapshot()["debug_patron_views"][&"patron_june"]
	var victim: Dictionary = carry.snapshot()["debug_patron_views"][&"patron_mara"]

	# AC3: displayed chance uses Friendship and Suspicion.
	var calm = _carry_session(707, &"")
	var calm_chance: float = calm.rescue_persuasion_chance(&"cultist_01")
	var wary = _carry_session(707, &"missing_companion_20")
	var wary_chance: float = wary.rescue_persuasion_chance(&"cultist_01")

	# AC4: success captures both; failure raises Suspicion and resumes leaving.
	var win = _carry_session(SUCCESS_SEED, &"")
	win.attempt_rescue_persuasion(&"cultist_01")
	win.advance(6.1)
	var won: Dictionary = win.snapshot()

	var lose = _carry_session(FAILURE_SEED, &"")
	lose.attempt_rescue_persuasion(&"cultist_01")
	lose.advance(6.1)
	var failed_helper: Dictionary = lose.snapshot()["debug_patron_views"][&"patron_june"]
	lose.advance(15.0)
	var left: Dictionary = lose.snapshot()

	var checks := {
		"night_starts_with_two_doses": doses_start == 2,
		"preparation_spends_one_dose": doses_after == 1,
		"countdown_is_consumer_owned": sip_countdown > 0.0,
		"collapse_after_twenty_seconds": collapsed == &"unconscious",
		"conscious_companion_carries_victim": helper["lifecycle"] == &"helping"
			and helper["activity"] == &"helper_carrying"
			and victim["helper_id"] == &"patron_june",
		"chance_uses_friendship_and_suspicion": is_equal_approx(calm_chance, 25.0)
			and is_equal_approx(wary_chance, 7.5),
		"success_captures_both_at_tunnel": won["captures"] == 2
			and won["debug_patron_views"][&"patron_mara"]["lifecycle"] == &"captured"
			and won["debug_patron_views"][&"patron_june"]["lifecycle"] == &"captured",
		"failure_raises_suspicion_and_resumes": lose_failed_suspicion(failed_helper)
			and left["captures"] == 0
			and left["debug_patron_views"][&"patron_mara"]["lifecycle"] == &"exited"
			and not left["defeat"],
	}
	return {
		"passed": not checks.values().has(false),
		"slice": "drug_helper",
		"checks": checks,
		"observed": {
			"doses": [doses_start, doses_after],
			"sip_countdown": sip_countdown,
			"calm_chance": calm_chance,
			"wary_chance": wary_chance,
			"success_captures": won["captures"],
			"failed_helper_suspicion": failed_helper["suspicion"],
		},
	}


func lose_failed_suspicion(failed_helper: Dictionary) -> bool:
	return is_equal_approx(float(failed_helper["suspicion"]), 25.0) \
		and failed_helper["activity"] == &"helper_carrying"
