extends Control

# Headless-first evidence slice for Ticket #15: all four Capture routes in one Night, the
# success / failed-operation / defeat outcomes, the complete results metrics, and the
# evaluation-readable info exposure — all through the public GameSession API. --report writes a
# machine-checkable validation file, --capture a PNG.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const SCENARIOS := {
	"all_four_routes": "FOUR ROUTES",
	"success": "SUCCESS",
	"failed_operation": "FAILED OP",
	"defeat": "DEFEAT",
	"readable_info": "READABLE UI",
}

var _session = GAME_SESSION_SCRIPT.new()
var _scenario: String = "all_four_routes"
var _scenario_trace: String = ""
var _capture_mode: bool = false
var _scenario_buttons: Dictionary = {}
var _state_text: RichTextLabel
var _metrics_text: RichTextLabel
var _trace_text: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	_build_ui()
	_set_scenario(_command_line_value("--stage=", "all_four_routes"))
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
	subtitle.text = "COMPLETE OUTCOMES & EVALUATION-READABLE UI  /  TICKET #15"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8195a2"))
	title_box.add_child(subtitle)

	var rule := Label.new()
	rule.text = "FOUR ROUTES, ONE NIGHT  •  no autonomous Capture"
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
	column.add_child(_section_title("NIGHT STATE", "Phase, outcome, captures"))
	_state_text = RichTextLabel.new()
	_state_text.bbcode_enabled = true
	_state_text.scroll_active = false
	_state_text.custom_minimum_size.y = 150
	_state_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_state_text, Color("14242d"), 13))

	column.add_child(_section_title("RESULTS METRICS", "Everything the evaluation reads"))
	_metrics_text = RichTextLabel.new()
	_metrics_text.bbcode_enabled = true
	_metrics_text.scroll_active = false
	_metrics_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_metrics_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_metrics_text, Color("101b22"), 13))
	return column


func _build_trace_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.2
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("SCENARIO TRACE", "What the integrated Night did"))
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
	column.add_child(_section_title("ACCEPTANCE CRITERIA", "Ticket #15 — one source of truth"))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 13)
	rules.text = "[color=#8195a2]FOUR ROUTES[/color]\nTrapdoor, Drugged Drink / Helper, manual knockout, and Friendship all complete in one full Night, with no autonomous Capture Actions.\n\n[color=#8195a2]OUTCOMES[/color]\nThree or more Captures plus a safe Closing is success; fewer is a failed operation; a maximum-Suspicion exit is immediate defeat.\n\n[color=#8195a2]RESULTS[/color]\nCapture methods, revenue and tips, Order performance, peak Suspicion, interceptions, Unattended Body time, and outcome.\n\n[color=#8195a2]READABLE UI[/color]\nUrgent intentions, Escape alerts, Action Queue controls, and exact Rescue odds — without exposing hidden normal-play data."
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


# Drives one Night in which all four Capture routes complete, choosing victims so every
# captured group is fully removed and no fatal missing-Companion cascade begins.
static func drive_all_four_routes(session) -> void:
	session.start_night(707)
	session.advance(110.0)
	session.debug_force_bathroom(&"patron_june")
	session.activate_trapdoor()
	session.debug_force_bathroom(&"patron_mara")
	session.advance(2.1)
	session.begin_knockout(&"cultist_01", &"patron_mara")
	session.advance(2.05)
	session.pick_up_body(&"cultist_01", &"patron_mara")
	session.advance(15.2)
	session.advance(200.0 - float(session.snapshot()["simulated_seconds"]))
	for _i in range(8):
		session.offer_cigarette(&"cultist_01", &"patron_elias")
	session.begin_friendship_capture(&"cultist_01", &"patron_elias")
	session.advance(14.2)
	session.advance(421.0 - float(session.snapshot()["simulated_seconds"]))
	for _j in range(20):
		session.offer_cigarette(&"cultist_02", &"patron_clara")
	session.prepare_drugged_drink(&"patron_vincent", &"cultist_02")
	session.advance(8.2)
	session.advance(31.0)
	session.attempt_rescue_persuasion(&"cultist_02")
	session.advance(6.2)


func _set_scenario(scenario_id: String) -> void:
	if not SCENARIOS.has(scenario_id):
		scenario_id = "all_four_routes"
	_scenario = scenario_id
	_session = GAME_SESSION_SCRIPT.new()
	match scenario_id:
		"all_four_routes":
			drive_all_four_routes(_session)
			_scenario_trace = "One Night, four routes: Trapdoor + knockout on June & Mara,\nFriendship Capture on Elias, Drugged Drink + Helper Rescue on\nVincent & Clara. Methods: %s. Autonomous Captures: %d." % [
				_method_summary(_session.snapshot()["results"]["capture_methods"]),
				_session.snapshot()["safe_autonomy"]["capture_actions_started"],
			]
		"success":
			drive_all_four_routes(_session)
			_session.advance(1080.0)
			_scenario_trace = "The quota is met and the Night reaches a safe Closing.\nCaptures %d of %d.\nOutcome: %s." % [
				_session.snapshot()["captures"], _session.snapshot()["results"]["capture_quota"],
				_humanize(_session.snapshot()["outcome"]),
			]
		"failed_operation":
			_session.start_night(707)
			_session.set_time_scale(4.0)
			_session.advance(300.0)
			_scenario_trace = "A clean Night: every Patron leaves normally, no Captures.\nCaptures %d of %d.\nOutcome: %s." % [
				_session.snapshot()["captures"], _session.snapshot()["results"]["capture_quota"],
				_humanize(_session.snapshot()["outcome"]),
			]
		"defeat":
			_session.start_night(707)
			_session.advance(200.0)
			_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
			_session.advance(10.2)
			_scenario_trace = "A maximum-Suspicion Patron reaches the front exit.\nThe Night ends immediately.\nOutcome: %s." % [
				_humanize(_session.snapshot()["outcome"]),
			]
		"readable_info":
			_session.start_night(707)
			_session.advance(200.0)
			_session.debug_force_bathroom(&"patron_june")
			_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
			_session.advance(0.2)
			var june: Dictionary = _session.snapshot()["normal_patron_views"][&"patron_june"]
			var elias: Dictionary = _session.snapshot()["normal_patron_views"][&"patron_elias"]
			_scenario_trace = "Observable only: June's urgent intention is '%s', Elias's is '%s'.\nEscape alerts: %s.\nHidden data (Bladder, exact Suspicion) never appears in normal views." % [
				_humanize(june["urgent_intention"]), _humanize(elias["urgent_intention"]),
				str(_session.snapshot()["escape_alerts"]),
			]
	_refresh(_session.snapshot())


func _method_summary(methods: Dictionary) -> String:
	var parts: Array[String] = []
	for cause: StringName in methods:
		parts.append("%s x%d" % [_humanize(cause), int(methods[cause])])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _refresh(state: Dictionary) -> void:
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	_state_text.text = _state_markup(state)
	_metrics_text.text = _metrics_markup(state)
	_trace_text.text = "[color=#e2a56e][b]%s[/b][/color]\n%s" % [SCENARIOS[_scenario], _scenario_trace]


func _state_markup(state: Dictionary) -> String:
	return "Phase  [b]%s[/b]     Clock  [b]%s[/b]\nOutcome  [b]%s[/b]\nCaptures  [b]%d[/b] / %d\nDefeat  [b]%s[/b]\nEscape alerts  [b]%s[/b]\nRescue odds  [b]%s[/b]" % [
		_humanize(state["phase"]), state["clock_label"], _humanize(state["outcome"]),
		state["captures"], state["results"]["capture_quota"], str(state["defeat"]),
		str(state["escape_alerts"].size()),
		("%.1f%%" % float(state["rescue_odds"])) if float(state["rescue_odds"]) >= 0.0 else "n/a",
	]


func _metrics_markup(state: Dictionary) -> String:
	var results: Dictionary = state["results"]
	return "Capture methods  [b]%s[/b]\nRevenue  [b]%d[/b]   Tips  [b]%d[/b]\nOrders  served [b]%d[/b] · cancelled [b]%d[/b]\nPeak Suspicion  [b]%.0f[/b] / 100\nInterceptions  [b]%d[/b]\nUnattended Body time  [b]%.1f s[/b]\nNormal departures  [b]%d[/b]" % [
		_method_summary(results["capture_methods"]),
		int(results["revenue"]), int(results["tips"]),
		int(results["orders_served"]), int(results["orders_cancelled"]),
		float(results["peak_suspicion"]), int(results["interceptions"]),
		float(results["unattended_body_seconds"]), int(results["normal_departures"]),
	]


func _humanize(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()


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
	# AC1: all four routes complete in one Night with no autonomous Captures.
	var integrated = GAME_SESSION_SCRIPT.new()
	drive_all_four_routes(integrated)
	var integrated_state: Dictionary = integrated.snapshot()
	var methods: Dictionary = integrated_state["results"]["capture_methods"]
	var all_four: bool = methods.has(&"trapdoor") and methods.has(&"knockout") \
		and methods.has(&"friendship_capture") and methods.has(&"rescue_persuasion")
	var no_autonomy: bool = integrated_state["safe_autonomy"]["capture_actions_started"] == 0

	# AC2: success, failed operation, and immediate defeat.
	var win = GAME_SESSION_SCRIPT.new()
	drive_all_four_routes(win)
	win.advance(1080.0)
	var success_ok: bool = win.snapshot()["outcome"] == &"success"

	var clean = GAME_SESSION_SCRIPT.new()
	clean.start_night(707)
	clean.set_time_scale(4.0)
	clean.advance(300.0)
	var failed_ok: bool = clean.snapshot()["outcome"] == &"failed_operation"

	var loss = GAME_SESSION_SCRIPT.new()
	loss.start_night(707)
	loss.advance(200.0)
	loss.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
	loss.advance(10.2)
	var defeat_ok: bool = loss.snapshot()["outcome"] == &"defeat"

	# AC3: the results report every required metric.
	var metrics = GAME_SESSION_SCRIPT.new()
	metrics.start_night(707)
	metrics.advance(200.0)
	metrics.debug_force_bathroom(&"patron_elias")
	metrics.advance(2.1)
	metrics.begin_knockout(&"cultist_01", &"patron_elias")
	metrics.advance(2.05)
	metrics.advance(10.0)
	metrics.pick_up_body(&"cultist_01", &"patron_elias")
	metrics.advance(15.2)
	metrics.report_patron_stimulus(&"patron_june", &"drink_dosed_seen")
	metrics.advance(2.5)
	metrics.begin_intercept(&"patron_june", &"cultist_02")
	metrics.advance(1200.0)
	var m: Dictionary = metrics.snapshot()["results"]
	var metrics_ok: bool = int(m["capture_methods"].get(&"knockout", 0)) == 1 \
		and is_equal_approx(float(m["peak_suspicion"]), 100.0) \
		and int(m["interceptions"]) >= 1 \
		and float(m["unattended_body_seconds"]) > 0.0 \
		and m.has("revenue") and m.has("tips") and m.has("orders_served")

	# AC4: readable info exposed, hidden normal-play data withheld.
	var ui = GAME_SESSION_SCRIPT.new()
	ui.start_night(707)
	ui.advance(200.0)
	var view: Dictionary = ui.snapshot()["normal_patron_views"][&"patron_june"]
	var hidden_withheld: bool = view.has("urgent_intention") \
		and not view.has("bladder") and not view.has("suspicion") and not view.has("bathroom_probability")
	ui.debug_force_bathroom(&"patron_june")
	var bathroom_intention: bool = ui.snapshot()["normal_patron_views"][&"patron_june"]["urgent_intention"] == &"bathroom"
	ui.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
	ui.advance(0.2)
	var escape_alert: bool = ui.snapshot()["escape_alerts"].has(&"patron_elias")

	var carry = GAME_SESSION_SCRIPT.new()
	carry.start_night(707)
	carry.advance(95.0)
	carry.prepare_drugged_drink(&"patron_mara", &"cultist_01")
	carry.advance(36.2)
	var odds: float = carry.snapshot()["rescue_odds"]
	var rescue_odds_readable: bool = odds >= 0.0 and is_equal_approx(odds, carry.rescue_persuasion_chance(&"cultist_01"))

	var checks := {
		"all_four_routes_complete": all_four,
		"no_autonomous_captures": no_autonomy,
		"outcome_success_on_quota_and_safe_closing": success_ok,
		"outcome_failed_operation_below_quota": failed_ok,
		"outcome_immediate_defeat_on_max_exit": defeat_ok,
		"results_report_all_metrics": metrics_ok,
		"readable_info_exposed_and_hidden_withheld": hidden_withheld and bathroom_intention and escape_alert,
		"exact_rescue_odds_readable": rescue_odds_readable,
	}
	return {
		"passed": not checks.values().has(false),
		"slice": "full_integration",
		"checks": checks,
		"observed": {
			"capture_methods": _method_summary(methods),
			"success_outcome": win.snapshot()["outcome"],
			"failed_outcome": clean.snapshot()["outcome"],
			"defeat_outcome": loss.snapshot()["outcome"],
			"peak_suspicion": m["peak_suspicion"],
			"interceptions": m["interceptions"],
			"unattended_body_seconds": m["unattended_body_seconds"],
			"rescue_odds": odds,
		},
	}
