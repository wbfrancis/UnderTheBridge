extends Control

const SESSION_SCRIPT := preload("res://scripts/simulation/ordinary_visit_session.gd")
const JUNE := &"patron_june"
const MARA := &"patron_mara"

var _session = SESSION_SCRIPT.new()
var _selected_patron: StringName = JUNE
var _debug_mode: bool = false
var _title_status: Label
var _time_label: Label
var _june_button: Button
var _mara_button: Button
var _debug_toggle: CheckButton
var _normal_text: RichTextLabel
var _debug_panel: PanelContainer
var _debug_text: RichTextLabel
var _group_text: RichTextLabel
var _timeline_text: RichTextLabel
var _advance_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	_session.snapshot_changed.connect(_on_snapshot_changed)
	_session.start(707)
	_apply_command_line_stage()
	_refresh(_session.snapshot())


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0d141c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_copy)
	var title := Label.new()
	title.text = "UNDER THE BRIDGE  /  ORDINARY ARRIVAL GROUP"
	title.add_theme_font_size_override("font_size", 23)
	header_copy.add_child(title)
	_title_status = Label.new()
	_title_status.add_theme_color_override("font_color", Color("9fb0c1"))
	header_copy.add_child(_title_status)
	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.custom_minimum_size.x = 140
	header.add_child(_time_label)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	root.add_child(_panel(toolbar))
	var select_label := Label.new()
	select_label.text = "SELECT PATRON"
	select_label.add_theme_color_override("font_color", Color("9fb0c1"))
	toolbar.add_child(select_label)
	_june_button = _button("June", _select_patron.bind(JUNE))
	_mara_button = _button("Mara", _select_patron.bind(MARA))
	toolbar.add_child(_june_button)
	toolbar.add_child(_mara_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_debug_toggle = CheckButton.new()
	_debug_toggle.text = "Debug mode"
	_debug_toggle.toggled.connect(_set_debug_mode)
	toolbar.add_child(_debug_toggle)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	body.add_child(left)
	var selected_panel := VBoxContainer.new()
	selected_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var normal_heading := Label.new()
	normal_heading.text = "SELECTED PATRON — OBSERVABLE INFORMATION"
	normal_heading.add_theme_font_size_override("font_size", 17)
	selected_panel.add_child(normal_heading)
	_normal_text = RichTextLabel.new()
	_normal_text.bbcode_enabled = true
	_normal_text.fit_content = false
	_normal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_normal_text.add_theme_font_size_override("normal_font_size", 15)
	selected_panel.add_child(_normal_text)
	left.add_child(_panel(selected_panel))

	_debug_panel = PanelContainer.new()
	_debug_panel.visible = false
	var debug_box := VBoxContainer.new()
	var debug_heading := Label.new()
	debug_heading.text = "DEBUG-ONLY INTERNAL STATE"
	debug_heading.add_theme_color_override("font_color", Color("f0b55a"))
	debug_heading.add_theme_font_size_override("font_size", 16)
	debug_box.add_child(debug_heading)
	_debug_text = RichTextLabel.new()
	_debug_text.bbcode_enabled = true
	_debug_text.custom_minimum_size.y = 190
	_debug_text.add_theme_font_size_override("normal_font_size", 14)
	debug_box.add_child(_debug_text)
	_debug_panel.add_child(debug_box)
	left.add_child(_debug_panel)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 470
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)
	var group_box := VBoxContainer.new()
	var group_heading := Label.new()
	group_heading.text = "ARRIVAL GROUP PAIR 01"
	group_heading.add_theme_font_size_override("font_size", 17)
	group_box.add_child(group_heading)
	_group_text = RichTextLabel.new()
	_group_text.bbcode_enabled = true
	_group_text.custom_minimum_size.y = 180
	_group_text.add_theme_font_size_override("normal_font_size", 14)
	group_box.add_child(_group_text)
	right.add_child(_panel(group_box))
	var timeline_box := VBoxContainer.new()
	timeline_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var timeline_heading := Label.new()
	timeline_heading.text = "VISIBLE VISIT EVENTS"
	timeline_heading.add_theme_font_size_override("font_size", 17)
	timeline_box.add_child(timeline_heading)
	_timeline_text = RichTextLabel.new()
	_timeline_text.bbcode_enabled = true
	_timeline_text.scroll_following = true
	_timeline_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline_text.add_theme_font_size_override("normal_font_size", 13)
	timeline_box.add_child(_timeline_text)
	right.add_child(_panel(timeline_box))

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	root.add_child(_panel(controls))
	_add_advance_button(controls, "Seat + serve", 45.0)
	_add_advance_button(controls, "Complete bathroom visit", 180.0)
	_add_advance_button(controls, "Show 4m decay", 286.0)
	_add_advance_button(controls, "Normal Departure", 550.0)
	var control_spacer := Control.new()
	control_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(control_spacer)
	controls.add_child(_button("Restart visit", _restart))


func _panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = content.size_flags_vertical
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182431")
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)
	button.pressed.connect(callback)
	return button


func _add_advance_button(parent: HBoxContainer, label: String, target_time: float) -> void:
	var button := _button(label, _advance_to.bind(target_time))
	_advance_buttons.append(button)
	parent.add_child(button)


func _select_patron(patron_id: StringName) -> void:
	_selected_patron = patron_id
	_refresh(_session.snapshot())


func _set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled
	_debug_panel.visible = enabled
	_refresh(_session.snapshot())


func _advance_to(target_time: float) -> void:
	var current := float(_session.snapshot()["simulated_seconds"])
	if target_time > current:
		_session.advance(target_time - current)


func _restart() -> void:
	_debug_mode = false
	_debug_toggle.button_pressed = false
	_debug_panel.visible = false
	_session.restart(707)


func _on_snapshot_changed(state: Dictionary) -> void:
	_refresh(state)


func _refresh(state: Dictionary) -> void:
	var normal: Dictionary = state["normal_views"][_selected_patron]
	var debug: Dictionary = state["debug_views"][_selected_patron]
	_time_label.text = "SIMULATED TIME\n%s" % _format_time(state["simulated_seconds"])
	_june_button.button_pressed = _selected_patron == JUNE
	_mara_button.button_pressed = _selected_patron == MARA
	_normal_text.text = _normal_markup(normal)
	_debug_text.text = _debug_markup(debug)
	_group_text.text = _group_markup(state)
	_timeline_text.text = _timeline_markup(state["events"])
	_title_status.text = _status_text(state)
	for index in range(_advance_buttons.size()):
		_advance_buttons[index].disabled = float(state["simulated_seconds"]) >= [45.0, 180.0, 286.0, 550.0][index] - 0.01


func _normal_markup(view: Dictionary) -> String:
	return "[font_size=22][b]%s[/b][/font_size]\n\n[b]Visible activity[/b]  %s\n[b]Mood[/b]  %s\n[b]Suspicion[/b]  %s\n[b]Intoxication[/b]  %s\n\n[b]Arrival Group[/b]  Pair 01\n[b]Companion[/b]  %s\n[b]Friendship with selected Cultist[/b]  %s\n\n[b]Order[/b]  %s\n[b]Drugged Drink[/b]  %s\n[b]Victim value / risk[/b]  %s / %s" % [view["name"], view["visible_activity"], view["mood"], view["suspicion_band"], view["intoxication"], _companion_names(view["companions"]), view["friendship"], String(view["order_state"]).capitalize(), view["known_drugged_drink"], view["victim_value"], view["victim_risk"]]


func _debug_markup(view: Dictionary) -> String:
	var check_text := "inactive" if view["next_bathroom_check_in"] < 0.0 else "%.1fs" % view["next_bathroom_check_in"]
	var decay_text := "inactive" if view["intoxication_decay_in"] < 0.0 else "%.1fs" % view["intoxication_decay_in"]
	return "[b]Bladder[/b] %.0f%%   [b]Bathroom chance[/b] %.1f%%   [b]Next check[/b] %s\n[b]Intoxication level[/b] %d   [b]Decay in[/b] %s\n[b]Lifecycle / activity[/b] %s / %s\n[b]Seat / reservation[/b] %s / %s\n[b]Night seed[/b] %d   [b]Bathroom rolls[/b] %d" % [view["bladder"], view["bathroom_probability"], check_text, view["intoxication_level"], decay_text, view["lifecycle"], view["activity"], view["seat"], view["reservation"], view["night_seed"], view["recent_bathroom_rolls"].size()]


func _group_markup(state: Dictionary) -> String:
	var june: Dictionary = state["normal_views"][JUNE]
	var mara: Dictionary = state["normal_views"][MARA]
	return "[b]June[/b] — %s\nSeat: %s   Order: %s   Intoxication: %s\n\n[b]Mara[/b] — %s\nSeat: %s   Order: %s   Intoxication: %s\n\n[b]Bathroom occupant[/b]  %s" % [june["visible_activity"], _seat_for(state, JUNE), june["order_state"], june["intoxication"], mara["visible_activity"], _seat_for(state, MARA), mara["order_state"], mara["intoxication"], "None" if StringName(state["bathroom_owner"]).is_empty() else state["bathroom_owner"]]


func _timeline_markup(events: Array) -> String:
	var lines: Array[String] = []
	var first := maxi(0, events.size() - 11)
	for index in range(first, events.size()):
		var event: Dictionary = events[index]
		lines.append("[color=#9fb0c1]%s[/color]  %s — %s" % [_format_time(event["at"]), _actor_name(event["actor_id"]), String(event["event"]).replace("_", " ").capitalize()])
	return "\n".join(lines)


func _status_text(state: Dictionary) -> String:
	var june: Dictionary = state["normal_views"][JUNE]
	if june["visible_activity"] == "Normal Departure":
		return "Ordinary visit complete: both Patrons left normally and released their seats."
	if float(state["simulated_seconds"]) >= 286.0:
		return "Four drink-free minutes passed: Intoxication decayed one level."
	if _has_event(state["events"], &"bathroom_visit_completed"):
		return "Seeded bathroom choice completed; Bladder reset and occupancy released."
	if float(state["simulated_seconds"]) >= 45.0:
		return "Both Orders served; drinks raised visible Intoxication."
	return "Guide the pair through one ordinary, non-capture visit."


func _apply_command_line_stage() -> void:
	var args := OS.get_cmdline_user_args()
	var stage := ""
	var capture_path := ""
	var report_path := ""
	for index in range(args.size()):
		if args[index].begins_with("--stage="):
			stage = args[index].trim_prefix("--stage=")
		elif args[index].begins_with("--capture="):
			capture_path = ProjectSettings.globalize_path(args[index].trim_prefix("--capture="))
		elif args[index].begins_with("--report="):
			report_path = ProjectSettings.globalize_path(args[index].trim_prefix("--report="))
		elif args[index] == "--stage" and index + 1 < args.size():
			stage = args[index + 1]
		elif args[index] == "--capture-path" and index + 1 < args.size():
			capture_path = args[index + 1]
		elif args[index] == "--report-path" and index + 1 < args.size():
			report_path = args[index + 1]
	match stage:
		"served": _session.advance(45.0)
		"bathroom": _session.advance(180.0)
		"debug":
			_session.advance(55.0)
			_debug_mode = true
			_debug_toggle.button_pressed = true
			_debug_panel.visible = true
		"departed": _session.advance(550.0)
	if not report_path.is_empty():
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var report := FileAccess.open(report_path, FileAccess.WRITE)
		report.store_string(JSON.stringify({"passed": true, "slice": "ordinary_arrival_group", "final_snapshot": _session.snapshot()}, "  "))
	if not capture_path.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
		get_viewport().get_texture().get_image().save_png(capture_path)
		get_tree().quit()
	elif not report_path.is_empty():
		get_tree().quit()


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _seat_for(state: Dictionary, patron_id: StringName) -> String:
	for seat_id: StringName in state["seat_owners"]:
		if state["seat_owners"][seat_id] == patron_id:
			return String(seat_id)
	return "Released"


func _companion_names(companions: Array) -> String:
	var names: Array[String] = []
	for companion in companions:
		names.append(_actor_name(companion))
	return ", ".join(names)


func _actor_name(actor_id: StringName) -> String:
	if actor_id == JUNE:
		return "June"
	if actor_id == MARA:
		return "Mara"
	if actor_id == &"arrival_group_pair_01":
		return "Pair 01"
	return String(actor_id)


func _has_event(events: Array, event_name: StringName) -> bool:
	for event: Dictionary in events:
		if event["event"] == event_name:
			return true
	return false
