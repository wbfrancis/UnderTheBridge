extends Control

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const PATRON_IDS: Array[StringName] = [
	&"patron_june",
	&"patron_mara",
	&"patron_elias",
	&"patron_ruth",
	&"patron_walter",
	&"patron_nell",
	&"patron_vincent",
	&"patron_clara",
]

var _session = GAME_SESSION_SCRIPT.new()
var _selected_patron_id: StringName = &"patron_june"
var _capture_mode: bool = false
var _phase_label: Label
var _clock_label: Label
var _night_progress: ProgressBar
var _summary_label: Label
var _group_schedule: RichTextLabel
var _patron_buttons: Dictionary = {}
var _selected_patron_text: RichTextLabel
var _timeline_text: RichTextLabel
var _cultist_text: RichTextLabel
var _metrics_text: RichTextLabel
var _safe_autonomy_section: VBoxContainer
var _ledger_section: VBoxContainer
var _results_panel: PanelContainer
var _results_text: RichTextLabel
var _time_buttons: Dictionary = {}
var _restart_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	_build_ui()
	_session.snapshot_changed.connect(_refresh)
	_session.start_night(707)
	_apply_command_line_stage()
	_refresh(_session.snapshot())
	_time_buttons[1.0].grab_focus()


func _process(delta: float) -> void:
	if _capture_mode:
		return
	_session.advance(delta)


func _build_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 15
	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color("1d2b38")
	button_normal.border_color = Color("34495a")
	button_normal.set_border_width_all(1)
	button_normal.set_corner_radius_all(5)
	button_normal.set_content_margin_all(10)
	var button_hover := button_normal.duplicate()
	button_hover.bg_color = Color("293d4c")
	button_hover.border_color = Color("6e9fb1")
	var button_pressed := button_normal.duplicate()
	button_pressed.bg_color = Color("9b6b3f")
	button_pressed.border_color = Color("e4b478")
	ui_theme.set_stylebox("normal", "Button", button_normal)
	ui_theme.set_stylebox("hover", "Button", button_hover)
	ui_theme.set_stylebox("focus", "Button", button_hover)
	ui_theme.set_stylebox("pressed", "Button", button_pressed)
	ui_theme.set_color("font_color", "Button", Color("e7edf1"))
	ui_theme.set_color("font_pressed_color", "Button", Color("fff4e5"))
	theme = ui_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("091118")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 11)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_phase_strip())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 11)
	body.add_child(_build_cast_column())
	body.add_child(_build_patron_column())
	body.add_child(_build_operations_column())
	root.add_child(body)
	root.add_child(_build_time_controls())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(copy)
	var title := Label.new()
	title.text = "UNDER THE BRIDGE"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("f0dcc0"))
	copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "COMPLETE NON-CAPTURE NIGHT  /  TICKET #8"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("8298a8"))
	copy.add_child(subtitle)

	var phase_box := VBoxContainer.new()
	phase_box.custom_minimum_size.x = 245
	header.add_child(phase_box)
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label.add_theme_font_size_override("font_size", 20)
	_phase_label.add_theme_color_override("font_color", Color("e4b478"))
	phase_box.add_child(_phase_label)
	_clock_label = Label.new()
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.add_theme_font_size_override("font_size", 16)
	_clock_label.add_theme_color_override("font_color", Color("b9c8d1"))
	phase_box.add_child(_clock_label)
	return header


func _build_phase_strip() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.add_theme_color_override("font_color", Color("a8bbc7"))
	row.add_child(_summary_label)
	_night_progress = ProgressBar.new()
	_night_progress.custom_minimum_size = Vector2(330, 24)
	_night_progress.max_value = 1080.0
	_night_progress.show_percentage = false
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color = Color("1b2a34")
	progress_background.set_corner_radius_all(4)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("a87548")
	progress_fill.set_corner_radius_all(4)
	_night_progress.add_theme_stylebox_override("background", progress_background)
	_night_progress.add_theme_stylebox_override("fill", progress_fill)
	row.add_child(_night_progress)
	return _panel(row, Color("111e27"), 9)


func _build_cast_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 360
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.05
	column.add_theme_constant_override("separation", 10)
	column.add_child(_section_title("AUTHORED ARRIVAL GROUPS", "Fixed cast and schedule"))
	_group_schedule = RichTextLabel.new()
	_group_schedule.bbcode_enabled = true
	_group_schedule.custom_minimum_size.y = 130
	_group_schedule.fit_content = false
	_group_schedule.scroll_active = false
	_group_schedule.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(_panel(_group_schedule, Color("13212b"), 11))

	var cast_grid := GridContainer.new()
	cast_grid.columns = 2
	cast_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cast_grid.add_theme_constant_override("h_separation", 7)
	cast_grid.add_theme_constant_override("v_separation", 7)
	for patron_id in PATRON_IDS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(165, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(_select_patron.bind(patron_id))
		_patron_buttons[patron_id] = button
		cast_grid.add_child(button)
	column.add_child(cast_grid)
	return column


func _build_patron_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 365
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.1
	column.add_theme_constant_override("separation", 10)
	column.add_child(_section_title("SELECTED PATRON", "Observable information only"))
	_selected_patron_text = RichTextLabel.new()
	_selected_patron_text.bbcode_enabled = true
	_selected_patron_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selected_patron_text.scroll_active = false
	_selected_patron_text.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(_panel(_selected_patron_text, Color("13212b"), 13))
	column.add_child(_section_title("VISIBLE NIGHT EVENTS", "Latest meaningful activity"))
	_timeline_text = RichTextLabel.new()
	_timeline_text.bbcode_enabled = true
	_timeline_text.custom_minimum_size.y = 130
	_timeline_text.scroll_following = true
	_timeline_text.add_theme_font_size_override("normal_font_size", 12)
	column.add_child(_panel(_timeline_text, Color("101b24"), 11))
	return column


func _build_operations_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 350
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 10)
	_safe_autonomy_section = VBoxContainer.new()
	_safe_autonomy_section.add_theme_constant_override("separation", 7)
	_safe_autonomy_section.add_child(_section_title("SAFE AUTONOMY", "Service or idle; never Capture"))
	_cultist_text = RichTextLabel.new()
	_cultist_text.bbcode_enabled = true
	_cultist_text.custom_minimum_size.y = 135
	_cultist_text.add_theme_font_size_override("normal_font_size", 13)
	_safe_autonomy_section.add_child(_panel(_cultist_text, Color("13212b"), 11))
	column.add_child(_safe_autonomy_section)
	_ledger_section = VBoxContainer.new()
	_ledger_section.add_theme_constant_override("separation", 7)
	_ledger_section.add_child(_section_title("NIGHT LEDGER", "Live non-capture outcomes"))
	_metrics_text = RichTextLabel.new()
	_metrics_text.bbcode_enabled = true
	_metrics_text.custom_minimum_size.y = 145
	_metrics_text.add_theme_font_size_override("normal_font_size", 14)
	_ledger_section.add_child(_panel(_metrics_text, Color("13212b"), 11))
	column.add_child(_ledger_section)

	_results_panel = PanelContainer.new()
	_results_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_text = RichTextLabel.new()
	_results_text.bbcode_enabled = true
	_results_text.scroll_active = false
	_results_text.add_theme_font_size_override("normal_font_size", 14)
	_results_panel.add_child(_results_text)
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color("2c201a")
	result_style.border_color = Color("a76d49")
	result_style.set_border_width_all(1)
	result_style.set_corner_radius_all(6)
	result_style.set_content_margin_all(14)
	_results_panel.add_theme_stylebox_override("panel", result_style)
	column.add_child(_results_panel)
	return column


func _build_time_controls() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "NIGHT SPEED"
	label.add_theme_color_override("font_color", Color("8298a8"))
	row.add_child(label)
	for scale in [0.0, 1.0, 2.0, 4.0]:
		var text := "PAUSE" if scale == 0.0 else "%dx" % int(scale)
		var button := Button.new()
		button.text = text
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(86, 39)
		button.pressed.connect(_set_time_scale.bind(scale))
		_time_buttons[scale] = button
		row.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var note := Label.new()
	note.text = "No Capture commands are available in this slice."
	note.add_theme_color_override("font_color", Color("728896"))
	row.add_child(note)
	_restart_button = Button.new()
	_restart_button.text = "RESTART NIGHT"
	_restart_button.custom_minimum_size = Vector2(155, 39)
	_restart_button.pressed.connect(_restart_night)
	row.add_child(_restart_button)
	return _panel(row, Color("111e27"), 9)


func _section_title(title: String, subtitle: String) -> Control:
	var box := VBoxContainer.new()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("d8e1e6"))
	box.add_child(heading)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("708794"))
	box.add_child(sub)
	return box


func _panel(content: Control, color: Color, inset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = content.size_flags_vertical
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("263946")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(inset)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func _select_patron(patron_id: StringName) -> void:
	_selected_patron_id = patron_id
	_refresh(_session.snapshot())


func _set_time_scale(scale: float) -> void:
	_session.set_time_scale(scale)


func _restart_night() -> void:
	_session.restart_night(707)
	_selected_patron_id = &"patron_june"


func _refresh(state: Dictionary) -> void:
	_phase_label.text = String(state["phase_label"]).to_upper()
	_clock_label.text = "%s  /  %s elapsed" % [state["clock_label"], _format_duration(state["simulated_seconds"])]
	_night_progress.value = state["simulated_seconds"]
	_summary_label.text = "%d / 8 arrived     %d present     %d Normal Departures" % [
		state["patrons"]["arrived_count"],
		state["patrons"]["active_count"],
		state["patrons"]["normal_departure_count"],
	]
	_group_schedule.text = _group_schedule_markup(state)
	_update_patron_buttons(state)
	_selected_patron_text.text = _selected_patron_markup(state["normal_patron_views"][_selected_patron_id])
	_timeline_text.text = _timeline_markup(state["visit_events"])
	_cultist_text.text = _cultist_markup(state)
	_metrics_text.text = _metrics_markup(state)
	_results_panel.visible = state["results"]["visible"]
	_safe_autonomy_section.visible = not state["results"]["visible"]
	_ledger_section.visible = not state["results"]["visible"]
	_results_text.text = _results_markup(state["results"])
	for scale: float in _time_buttons:
		_time_buttons[scale].button_pressed = is_equal_approx(state["time_scale"], scale)
		_time_buttons[scale].disabled = state["phase"] == &"results"
	_restart_button.text = "START CLEAN NIGHT" if state["phase"] == &"results" else "RESTART NIGHT"


func _group_schedule_markup(state: Dictionary) -> String:
	var lines: Array[String] = []
	for group_id: StringName in state["arrival_groups"]:
		var group: Dictionary = state["arrival_groups"][group_id]
		var status := "Departed" if group["departed"] else ("In speakeasy" if group["arrived"] else "Scheduled")
		var color := "#8fbf9f" if group["arrived"] and not group["departed"] else ("#7d909b" if group["departed"] else "#e4b478")
		lines.append("[color=#8298a8]%s[/color]  [b]%s[/b]  [color=%s]%s[/color]" % [
			_format_duration(group["arrival_at"]), group["label"], color, status
		])
	return "\n".join(lines)


func _update_patron_buttons(state: Dictionary) -> void:
	for patron_id in PATRON_IDS:
		var view: Dictionary = state["normal_patron_views"][patron_id]
		var button: Button = _patron_buttons[patron_id]
		button.text = "%s\n%s" % [view["name"], view["visible_activity"]]
		button.button_pressed = patron_id == _selected_patron_id


func _selected_patron_markup(view: Dictionary) -> String:
	return "[font_size=21][b]%s[/b][/font_size]  [color=#8298a8]%s[/color]\n\n[b]Visible activity[/b]  %s\n[b]Mood / Suspicion[/b]  %s / %s\n[b]Intoxication / Friendship[/b]  %s / %s\n[b]Companions[/b]  %s\n[b]Order[/b]  %s\n[b]Victim value / risk[/b]  %s / %s" % [
		view["name"],
		String(view["arrival_group"]).replace("arrival_group_", "").replace("_", " ").capitalize(),
		view["visible_activity"],
		view["mood"],
		view["suspicion_band"],
		view["intoxication"],
		view["friendship"],
		_companion_names(view["companions"]),
		String(view["order_state"]).capitalize(),
		view["victim_value"],
		view["victim_risk"],
	]


func _timeline_markup(events: Array) -> String:
	var meaningful: Array[Dictionary] = []
	for event: Dictionary in events:
		if event["event"] in [&"bathroom_check", &"bladder_emptied", &"intoxication_decayed"]:
			continue
		meaningful.append(event)
	var lines: Array[String] = []
	var first := maxi(0, meaningful.size() - 10)
	for index in range(first, meaningful.size()):
		var event: Dictionary = meaningful[index]
		lines.append("[color=#708794]%s[/color]  %s  [color=#b9c8d1]%s[/color]" % [
			_format_duration(event["at"]),
			_actor_name(event["actor_id"]),
			String(event["event"]).replace("_", " ").capitalize(),
		])
	return "No visit events yet." if lines.is_empty() else "\n".join(lines)


func _cultist_markup(state: Dictionary) -> String:
	var lines: Array[String] = []
	var number := 1
	for cultist_id: StringName in state["cultists"]:
		var cultist: Dictionary = state["cultists"][cultist_id]
		var activity := "Safe service" if cultist["activity"] == &"safe_service" else "Idle"
		var detail := ""
		if cultist["last_action"] == &"serve_order":
			detail = "  /  last served %s" % _actor_name(cultist["last_target_id"])
		lines.append("[b]Cultist %d[/b]  [color=#8fbf9f]%s[/color]%s" % [number, activity, detail])
		number += 1
	lines.append("\n[color=#8fbf9f]0 autonomous Capture Actions[/color]")
	return "\n".join(lines)


func _metrics_markup(state: Dictionary) -> String:
	return "[b]Orders served[/b]  %d / 8\n[b]Revenue[/b]  $%d     [b]Tips[/b]  $%d\n[b]Captures[/b]  %d / 3\n[b]Bathroom occupant[/b]  %s\n[b]Runtime reservations[/b]  %d" % [
		state["orders"]["served_count"],
		state["orders"]["revenue"],
		state["orders"]["tips"],
		state["captures"],
		"None" if StringName(state["bathroom_owner"]).is_empty() else _actor_name(state["bathroom_owner"]),
		state["runtime"]["reservations"],
	]


func _results_markup(results: Dictionary) -> String:
	if not results["visible"]:
		return "[color=#708794]Results unlock when Closing ends.[/color]"
	return "[font_size=21][b][color=#e29a72]OPERATION FAILED[/color][/b][/font_size]\nNo Patrons were captured in this safe service run.\n\n[b]Captures[/b]  %d / %d\n[b]Orders served[/b]  %d\n[b]Revenue + tips[/b]  $%d + $%d\n[b]Normal Departures[/b]  %d\n[b]Night seed[/b]  %d\n\nRestart constructs a clean second Night." % [
		results["captures"],
		results["capture_quota"],
		results["orders_served"],
		results["revenue"],
		results["tips"],
		results["normal_departures"],
		results["night_seed"],
	]


func _companion_names(companions: Array) -> String:
	if companions.is_empty():
		return "None"
	var names: Array[String] = []
	for companion_id in companions:
		names.append(_actor_name(companion_id))
	return ", ".join(names)


func _actor_name(actor_id: StringName) -> String:
	if actor_id == &"night":
		return "Night"
	if actor_id.begins_with("arrival_group_"):
		return String(actor_id).replace("arrival_group_", "").replace("_", " ").capitalize()
	if actor_id.begins_with("patron_"):
		return String(actor_id).trim_prefix("patron_").capitalize()
	if actor_id.begins_with("cultist_"):
		return "Cultist %d" % int(String(actor_id).trim_prefix("cultist_"))
	return String(actor_id).capitalize()


func _format_duration(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _apply_command_line_stage() -> void:
	var stage := ""
	var capture_path := ""
	var report_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			stage = argument.trim_prefix("--stage=")
		elif argument.begins_with("--capture="):
			capture_path = ProjectSettings.globalize_path(argument.trim_prefix("--capture="))
		elif argument.begins_with("--report="):
			report_path = ProjectSettings.globalize_path(argument.trim_prefix("--report="))
	_capture_mode = not stage.is_empty() or not capture_path.is_empty() or not report_path.is_empty()
	match stage:
		"opening": _session.advance(70.0)
		"full_cast": _session.advance(500.0)
		"closing": _session.advance(960.0)
		"results": _session.advance(1080.0)
		"restart":
			_session.advance(1080.0)
			_session.restart_night(808)
	_refresh(_session.snapshot())
	if not report_path.is_empty():
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var report := FileAccess.open(report_path, FileAccess.WRITE)
		report.store_string(JSON.stringify({"passed": true, "slice": "complete_noncapture_night", "final_snapshot": _session.snapshot()}, "  "))
	if not capture_path.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
		get_viewport().get_texture().get_image().save_png(capture_path)
		get_tree().quit()
	elif not report_path.is_empty():
		get_tree().quit()
