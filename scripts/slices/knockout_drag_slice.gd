extends Control

# Headless-first evidence slice for Ticket #13: the manual knockout route — an interruptible
# wind-up whose impact is the Commitment Point, visual vs hearing-only witnessing, dragging that
# occupies the Cultist and can always be dropped, and Capture at the Tunnel Intake — all through
# the public GameSession API. --report writes a machine-checkable validation file, --capture a PNG.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const SCENARIOS := {
	"windup_commitment": "WIND-UP",
	"witness_split": "WITNESSES",
	"drag_occupies": "DRAG",
	"drop_restarts": "DROP",
	"intake_capture": "TUNNEL INTAKE",
}
const DRAG_TOTAL_SECONDS := 15.1  # 1 s pickup + 14 s drag to the intake + margin

var _session = GAME_SESSION_SCRIPT.new()
var _scenario: String = "windup_commitment"
var _victim_id: StringName = &"patron_elias"
var _gauge_id: StringName = &"patron_june"
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
	_set_scenario(_command_line_value("--stage=", "windup_commitment"))
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
	subtitle.text = "MANUAL KNOCKOUT, DRAGGING & TUNNEL INTAKE  /  TICKET #13"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8195a2"))
	title_box.add_child(subtitle)

	var rule := Label.new()
	rule.text = "NO AUTONOMOUS CAPTURE  •  the player commits every knockout"
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
	column.add_child(_section_title("NIGHT STATE", "Wind-up, drag, captures"))
	_state_text = RichTextLabel.new()
	_state_text.bbcode_enabled = true
	_state_text.scroll_active = false
	_state_text.custom_minimum_size.y = 150
	_state_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_state_text, Color("14242d"), 13))

	column.add_child(_section_title("VICTIM & WITNESS", "Body, drag, perceived Suspicion"))
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
	column.add_child(_section_title("SCENARIO TRACE", "What the knockout route did, step by step"))
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
	column.add_child(_section_title("ACCEPTANCE CRITERIA", "Ticket #13 — one source of truth"))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 13)
	rules.text = "[color=#8195a2]KNOCKOUT[/color]\nApproach, then a 2-second interruptible wind-up. Impact is the Commitment Point and leaves the victim Unconscious for the Night.\n\n[color=#8195a2]WITNESSES[/color]\nA visual witness receives Hard Evidence (permanent 100). A Patron who only hears it gains 25 soft Suspicion.\n\n[color=#8195a2]DRAGGING[/color]\nPicking up the body takes 1 s. Dragging occupies the Cultist, reduces movement to 50%, and can always be interrupted by dropping.\n\n[color=#8195a2]OUTCOME[/color]\nDropping restarts the Unattended Body grace. Crossing the [color=#e7a06c]Tunnel Intake[/color] completes the Capture once."
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
		scenario_id = "windup_commitment"
	_scenario = scenario_id
	_session.restart_night(707)
	match scenario_id:
		"windup_commitment":
			_victim_id = &"patron_elias"
			_gauge_id = &"patron_june"
			_session.advance(200.0)
			_session.begin_knockout(&"cultist_01", &"patron_elias")
			_session.advance(1.0)
			var cancelled := _session.cancel_knockout(&"cultist_01")
			var still_active: StringName = _debug_for(&"patron_elias")["lifecycle"]
			_session.begin_knockout(&"cultist_01", &"patron_elias")
			_session.advance(2.05)
			var after: StringName = _debug_for(&"patron_elias")["lifecycle"]
			_scenario_trace = "Began a 2 s wind-up on Elias.\nCancelled at 1 s (interruptible=%s); Elias stayed %s.\nRe-committed the wind-up: impact -> lifecycle %s." % [
				str(cancelled), _humanize(still_active), _humanize(after),
			]
		"witness_split":
			_victim_id = &"patron_mara"
			_gauge_id = &"patron_june"
			_session.advance(470.0)
			_session.begin_knockout(&"cultist_01", &"patron_mara")
			_session.advance(2.05)
			var seer: Dictionary = _debug_for(&"patron_june")
			var hearer: Dictionary = _debug_for(&"patron_clara")
			_scenario_trace = "Knocked out Mara in the crowded main hall.\nJune saw it -> %s (%.0f, permanent).\nClara only heard it -> %s (%.0f, soft)." % [
				_humanize(seer["suspicion_cause"]), seer["suspicion"],
				_humanize(hearer["suspicion_cause"]), hearer["suspicion"],
			]
		"drag_occupies":
			_victim_id = &"patron_elias"
			_gauge_id = &"patron_june"
			_session.advance(200.0)
			_session.begin_knockout(&"cultist_01", &"patron_elias")
			_session.advance(2.05)
			_session.pick_up_body(&"cultist_01", &"patron_elias")
			_session.advance(1.05)
			var busy := _session.is_cultist_busy(&"cultist_01")
			var refused := not _session.begin_knockout(&"cultist_01", &"patron_june")
			var scale: float = _session.snapshot()["drags"][&"patron_elias"]["movement_scale"]
			_scenario_trace = "Knocked out Elias, then picked up and began dragging.\nCultist 01 occupied=%s; a second Action refused=%s.\nMovement reduced to %.0f%% while dragging." % [
				str(busy), str(refused), scale * 100.0,
			]
		"drop_restarts":
			_victim_id = &"patron_elias"
			_gauge_id = &"patron_june"
			_session.advance(200.0)
			_session.debug_force_bathroom(&"patron_elias")
			_session.advance(2.1)
			_session.begin_knockout(&"cultist_01", &"patron_elias")
			_session.advance(2.05)
			_session.pick_up_body(&"cultist_01", &"patron_elias")
			_session.advance(11.0)
			var held_gauge: float = _debug_for(&"patron_june")["suspicion"]
			_session.drop_body(&"cultist_01")
			_session.advance(8.9)  # fresh grace (3 s) + one 5 s interval
			var resumed_gauge: float = _debug_for(&"patron_june")["suspicion"]
			_scenario_trace = "Elias knocked out and held: gauge June at %.0f (no pressure).\nDropped the body -> a fresh Unattended grace begins.\nAfter grace + interval, pressure resumes: June at %.0f." % [
				held_gauge, resumed_gauge,
			]
		"intake_capture":
			_victim_id = &"patron_elias"
			_gauge_id = &"patron_june"
			_session.advance(200.0)
			_session.debug_force_bathroom(&"patron_elias")
			_session.advance(2.1)
			_session.begin_knockout(&"cultist_01", &"patron_elias")
			_session.advance(2.05)
			_session.pick_up_body(&"cultist_01", &"patron_elias")
			_session.advance(DRAG_TOTAL_SECONDS)
			var captures_after: int = _session.snapshot()["captures"]
			_session.advance(10.0)
			var captures_final: int = _session.snapshot()["captures"]
			_scenario_trace = "Dragged Elias's body across the Tunnel Intake.\nCaptures on crossing: %d; lifecycle %s.\nAfter another 10 s the crossing still captures once: %d." % [
				captures_after, _humanize(_debug_for(&"patron_elias")["lifecycle"]), captures_final,
			]
	_refresh(_session.snapshot())


func _refresh(state: Dictionary) -> void:
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	_state_text.text = _state_markup(state)
	_victim_text.text = _victim_markup(state)
	_trace_text.text = "[color=#e2a56e][b]%s[/b][/color]\n%s" % [SCENARIOS[_scenario], _scenario_trace]


func _state_markup(state: Dictionary) -> String:
	var lines := "Phase  [b]%s[/b]     Clock  [b]%s[/b]\nCaptures  [b]%d[/b] / %d\nDefeat  [b]%s[/b]" % [
		_humanize(state["phase"]), state["clock_label"],
		state["captures"], state["results"]["capture_quota"], str(state["defeat"]),
	]
	if not state["windup"].is_empty():
		lines += "\nWind-up  [b]%.1f s[/b]  on  [b]%s[/b]" % [
			float(state["windup"]["remaining"]), _actor_name(state["windup"]["victim_id"]),
		]
	var drags: Dictionary = state["drags"]
	if drags.has(_victim_id):
		var drag: Dictionary = drags[_victim_id]
		lines += "\nDrag phase  [b]%s[/b]  ·  [b]%.1f s[/b]\nMovement scale  [b]%.0f%%[/b]" % [
			_humanize(drag["phase"]), float(drag["remaining"]), float(drag["movement_scale"]) * 100.0,
		]
	return lines


func _victim_markup(state: Dictionary) -> String:
	var victim: Dictionary = state["debug_patron_views"][_victim_id]
	var gauge: Dictionary = state["debug_patron_views"][_gauge_id]
	var dragged: String = "Yes" if state["drags"].has(_victim_id) else "No"
	return "[color=#e9edf0][b]Victim — %s[/b][/color]\nLifecycle  [b]%s[/b]     Room  [b]%s[/b]\nBeing dragged  [b]%s[/b]\n\n[color=#e9edf0][b]Witness / gauge — %s[/b][/color]\nSuspicion  [b]%.0f[/b] / 100  ·  %s\nCause  [b]%s[/b]  ·  Recoverable  [b]%s[/b]" % [
		_actor_name(_victim_id), _humanize(victim["lifecycle"]), _humanize(victim["room"]), dragged,
		_actor_name(_gauge_id), gauge["suspicion"], state["normal_patron_views"][_gauge_id]["suspicion_band"],
		_humanize(gauge["suspicion_cause"]), str(gauge["suspicion_recoverable"]),
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
	# AC1: an interruptible wind-up whose impact is the Commitment Point.
	var windup = GAME_SESSION_SCRIPT.new()
	windup.start_night(707)
	windup.advance(200.0)
	windup.begin_knockout(&"cultist_01", &"patron_elias")
	windup.advance(1.0)
	var cancelled := windup.cancel_knockout(&"cultist_01")
	var stayed_active: StringName = windup.snapshot()["debug_patron_views"][&"patron_elias"]["lifecycle"]
	windup.begin_knockout(&"cultist_01", &"patron_elias")
	windup.advance(2.05)
	var committed: StringName = windup.snapshot()["debug_patron_views"][&"patron_elias"]["lifecycle"]

	# AC2: visual witnesses get Hard Evidence; hearing-only witnesses get the +25 soft increase.
	var witness = GAME_SESSION_SCRIPT.new()
	witness.start_night(707)
	witness.advance(470.0)
	witness.begin_knockout(&"cultist_01", &"patron_mara")
	witness.advance(2.05)
	var seer: Dictionary = witness.snapshot()["debug_patron_views"][&"patron_june"]
	var hearer: Dictionary = witness.snapshot()["debug_patron_views"][&"patron_clara"]

	# AC3: dragging occupies the Cultist, reduces movement, and can always be interrupted.
	var drag = GAME_SESSION_SCRIPT.new()
	drag.start_night(707)
	drag.advance(200.0)
	drag.begin_knockout(&"cultist_01", &"patron_elias")
	drag.advance(2.05)
	drag.pick_up_body(&"cultist_01", &"patron_elias")
	drag.advance(1.05)
	var busy := drag.is_cultist_busy(&"cultist_01")
	var scale: float = drag.snapshot()["drags"][&"patron_elias"]["movement_scale"]
	var second_refused := not drag.begin_knockout(&"cultist_01", &"patron_june")
	var dropped := drag.drop_body(&"cultist_01")
	var after_drop: Dictionary = drag.snapshot()
	var freed := not drag.is_cultist_busy(&"cultist_01")

	# AC4: dropping restarts Unattended Body pressure; the intake crossing captures once.
	var body = GAME_SESSION_SCRIPT.new()
	body.start_night(707)
	body.advance(200.0)
	body.debug_force_bathroom(&"patron_elias")
	body.advance(2.1)
	body.begin_knockout(&"cultist_01", &"patron_elias")
	body.advance(2.05)
	body.pick_up_body(&"cultist_01", &"patron_elias")
	body.advance(11.0)
	var held_gauge: float = body.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]
	body.drop_body(&"cultist_01")
	body.advance(2.9)
	var grace_gauge: float = body.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]
	body.advance(6.0)
	var resumed_gauge: float = body.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"]
	body.pick_up_body(&"cultist_01", &"patron_elias")
	body.advance(DRAG_TOTAL_SECONDS)
	var captured: Dictionary = body.snapshot()
	body.advance(10.0)
	var captures_final: int = body.snapshot()["captures"]

	var checks := {
		"windup_is_interruptible": cancelled and stayed_active == &"active",
		"impact_commits_unconscious": committed == &"unconscious",
		"visual_witness_gets_hard_evidence": is_equal_approx(float(seer["suspicion"]), 100.0)
			and seer["suspicion_cause"] == &"hard_evidence" and not seer["suspicion_recoverable"],
		"hearing_only_witness_gets_soft": is_equal_approx(float(hearer["suspicion"]), 25.0)
			and hearer["suspicion_cause"] == &"general_danger" and hearer["suspicion_recoverable"],
		"dragging_occupies_and_reduces_movement": busy and is_equal_approx(scale, 0.5) and second_refused,
		"dropping_always_interrupts": dropped and freed
			and not after_drop["drags"].has(&"patron_elias")
			and after_drop["debug_patron_views"][&"patron_elias"]["lifecycle"] == &"unconscious",
		"dropping_restarts_unattended_pressure": is_equal_approx(held_gauge, 0.0)
			and is_equal_approx(grace_gauge, 0.0) and is_equal_approx(resumed_gauge, 5.0),
		"intake_crossing_captures_once": captured["captures"] == 1
			and captured["debug_patron_views"][&"patron_elias"]["lifecycle"] == &"captured"
			and captures_final == 1,
	}
	return {
		"passed": not checks.values().has(false),
		"slice": "knockout_drag",
		"checks": checks,
		"observed": {
			"windup_lifecycles": [stayed_active, committed],
			"seer_suspicion": seer["suspicion"],
			"hearer_suspicion": hearer["suspicion"],
			"drag_movement_scale": scale,
			"gauge_held_then_resumed": [held_gauge, grace_gauge, resumed_gauge],
			"captures_final": captures_final,
		},
	}
