extends Control

const SERVICE_SESSION_SCRIPT := preload("res://scripts/simulation/service_slice_session.gd")
const CULTIST_LABELS := {
	&"cultist_01": "Silas",
	&"cultist_02": "Ruth",
	&"cultist_03": "Caleb",
}
const ACTION_LABELS := {
	&"prepare_drink": "Prepare June's drink",
	&"pickup_drink": "Pick up Prepared Drink",
	&"serve_order": "Deliver drink to June",
	&"reset_at_bar": "Return to bar position",
}
const BG := Color("0c1117")
const PANEL := Color("18212b")
const PANEL_ALT := Color("202c38")
const INK := Color("edf2f6")
const MUTED := Color("96a6b5")
const GREEN := Color("4ed48a")
const AMBER := Color("f2b457")
const RED := Color("ef7072")
const BLUE := Color("67a9ff")

var _session = SERVICE_SESSION_SCRIPT.new()
var _stage: StringName = &"queued"
var _capture_path: String = ""
var _report_path: String = ""

var _cultist_buttons: Dictionary = {}
var _title_status: Label
var _clock_label: Label
var _patron_label: Label
var _order_state_label: Label
var _money_label: Label
var _drink_label: Label
var _selected_label: Label
var _queue_rows: VBoxContainer
var _queue_hint: Label
var _event_log: RichTextLabel
var _queue_service_button: Button
var _advance_button: Button
var _complete_button: Button
var _patron_leaves_button: Button
var _restart_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_parse_arguments()
	_build_ui()
	_session.snapshot_changed.connect(_on_snapshot_changed)
	_session.start()
	_apply_stage(_stage)
	_on_snapshot_changed(_session.snapshot())
	if not _report_path.is_empty():
		_write_report(_report_path)
		if _capture_path.is_empty():
			get_tree().quit(0)
			return
	if not _capture_path.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(_capture_path.get_base_dir())
		var image := get_viewport().get_texture().get_image()
		var result := image.save_png(_capture_path)
		get_tree().quit(0 if result == OK else 1)


func _build_ui() -> void:
	theme = _make_theme()
	var background := ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		safe_margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(safe_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	safe_margin.add_child(page)

	page.add_child(_build_header())
	page.add_child(_build_cultist_selector())

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	page.add_child(content)
	content.add_child(_build_world_panel())
	content.add_child(_build_queue_panel())

	page.add_child(_build_command_bar())
	_queue_service_button.grab_focus()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "UNDER THE BRIDGE  /  SERVICE ACTION QUEUE"
	title.add_theme_font_size_override("font_size", 21)
	titles.add_child(title)
	_title_status = Label.new()
	_title_status.text = "Select a Cultist, queue service, and keep the Order moving."
	_title_status.add_theme_color_override("font_color", MUTED)
	titles.add_child(_title_status)
	header.add_child(titles)
	_clock_label = Label.new()
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.custom_minimum_size = Vector2(160, 0)
	header.add_child(_clock_label)
	return header


func _build_cultist_selector() -> Control:
	var panel := _panel_container(PANEL)
	var margin := _panel_margin()
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var label := Label.new()
	label.text = "SELECT CULTIST"
	label.add_theme_color_override("font_color", MUTED)
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)
	for cultist_id: StringName in CULTIST_LABELS:
		var button := Button.new()
		button.text = CULTIST_LABELS[cultist_id]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(130, 38)
		button.pressed.connect(_on_cultist_selected.bind(cultist_id))
		row.add_child(button)
		_cultist_buttons[cultist_id] = button
	return panel


func _build_world_panel() -> Control:
	var panel := _panel_container(PANEL_ALT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	var margin := _panel_margin(18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "ONE-PATRON SERVICE TRACER"
	heading.add_theme_font_size_override("font_size", 16)
	column.add_child(heading)

	var state_grid := GridContainer.new()
	state_grid.columns = 2
	state_grid.add_theme_constant_override("h_separation", 26)
	state_grid.add_theme_constant_override("v_separation", 13)
	column.add_child(state_grid)
	_add_state_row(state_grid, "PATRON", "", "patron")
	_add_state_row(state_grid, "ORDER", "", "order")
	_add_state_row(state_grid, "PAYMENT", "", "money")
	_add_state_row(state_grid, "PHYSICAL DRINK", "", "drink")
	_add_state_row(state_grid, "SELECTED CULTIST", "", "selected")

	var divider := HSeparator.new()
	column.add_child(divider)
	var event_title := Label.new()
	event_title.text = "VISIBLE FEEDBACK"
	event_title.add_theme_color_override("font_color", MUTED)
	column.add_child(event_title)
	_event_log = RichTextLabel.new()
	_event_log.bbcode_enabled = true
	_event_log.fit_content = false
	_event_log.scroll_active = true
	_event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_log.custom_minimum_size = Vector2(0, 150)
	column.add_child(_event_log)
	return panel


func _add_state_row(grid: GridContainer, heading: String, value: String, key: String) -> void:
	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_color_override("font_color", MUTED)
	grid.add_child(heading_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value_label)
	match key:
		"patron": _patron_label = value_label
		"order": _order_state_label = value_label
		"money": _money_label = value_label
		"drink": _drink_label = value_label
		"selected": _selected_label = value_label


func _build_queue_panel() -> Control:
	var panel := _panel_container(PANEL)
	panel.custom_minimum_size = Vector2(430, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := _panel_margin(18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "SELECTED CULTIST — ACTION QUEUE"
	heading.add_theme_font_size_override("font_size", 16)
	column.add_child(heading)
	_queue_hint = Label.new()
	_queue_hint.text = "One active Action + up to three pending."
	_queue_hint.add_theme_color_override("font_color", MUTED)
	column.add_child(_queue_hint)
	_queue_rows = VBoxContainer.new()
	_queue_rows.add_theme_constant_override("separation", 8)
	_queue_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_queue_rows)
	return panel


func _build_command_bar() -> Control:
	var panel := _panel_container(PANEL)
	var margin := _panel_margin(10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	_queue_service_button = _command_button("Queue full service")
	_queue_service_button.pressed.connect(_on_queue_service)
	row.add_child(_queue_service_button)
	_advance_button = _command_button("Advance 1s")
	_advance_button.pressed.connect(func() -> void: _session.advance(1.0))
	row.add_child(_advance_button)
	_complete_button = _command_button("Complete queued work")
	_complete_button.pressed.connect(func() -> void: _session.advance(12.0))
	row.add_child(_complete_button)
	_patron_leaves_button = _command_button("Patron leaves (stale target)")
	_patron_leaves_button.pressed.connect(_on_patron_leaves)
	row.add_child(_patron_leaves_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_restart_button = _command_button("Restart slice")
	_restart_button.pressed.connect(_session.restart)
	row.add_child(_restart_button)
	return panel


func _command_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(150, 38)
	button.focus_mode = Control.FOCUS_ALL
	return button


func _on_snapshot_changed(snapshot: Dictionary) -> void:
	_clock_label.text = "SIMULATED TIME\n%05.1fs" % float(snapshot["simulated_seconds"])
	var selected: StringName = snapshot["selected_cultist_id"]
	_selected_label.text = CULTIST_LABELS[selected]
	for cultist_id: StringName in _cultist_buttons:
		_cultist_buttons[cultist_id].button_pressed = cultist_id == selected

	var order: Dictionary = snapshot["order"]
	_patron_label.text = "June — %s" % ("at table" if snapshot["patron_available"] else "departed")
	_order_state_label.text = "%s  •  %s" % [order["id"], str(order["state"]).to_upper()]
	_money_label.text = "$%d payment  +  $%d tip" % [order["payment"], order["tip"]]
	_money_label.add_theme_color_override("font_color", GREEN if order["state"] == &"served" else INK)
	_drink_label.text = _prepared_drink_text(snapshot["prepared_drinks"])
	var selected_queue: Dictionary = snapshot["cultist_queues"][selected]
	_rebuild_queue(selected_queue)
	_rebuild_event_log(snapshot["service_events"])
	var selected_is_busy: bool = (
		not selected_queue["active"].is_empty()
		or not selected_queue["pending"].is_empty()
	)
	_queue_service_button.disabled = order["state"] != &"open" or selected_is_busy
	_patron_leaves_button.disabled = not snapshot["patron_available"] or order["state"] != &"open"
	if order["state"] == &"served":
		_title_status.text = "Service complete: physical delivery paid once and earned a fast tip."
		_title_status.add_theme_color_override("font_color", GREEN)
	elif order["state"] == &"cancelled":
		_title_status.text = "Service failed visibly: stale target, no payment, queue continued."
		_title_status.add_theme_color_override("font_color", RED)
	else:
		_title_status.text = "Select a Cultist, queue service, and keep the Order moving."
		_title_status.add_theme_color_override("font_color", MUTED)


func _rebuild_queue(queue_snapshot: Dictionary) -> void:
	for child in _queue_rows.get_children():
		child.queue_free()
	if queue_snapshot["active"].is_empty() and queue_snapshot["pending"].is_empty():
		var empty := Label.new()
		empty.text = "No Actions queued."
		empty.add_theme_color_override("font_color", MUTED)
		_queue_rows.add_child(empty)
		return
	if not queue_snapshot["active"].is_empty():
		_queue_rows.add_child(_queue_row(queue_snapshot["active"], true))
	for action: Dictionary in queue_snapshot["pending"]:
		_queue_rows.add_child(_queue_row(action, false))


func _queue_row(action: Dictionary, is_active: bool) -> Control:
	var panel := _panel_container(Color("25323f") if is_active else Color("1d2731"))
	panel.custom_minimum_size = Vector2(0, 60)
	var margin := _panel_margin(10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var state := Label.new()
	state.text = "ACTIVE" if is_active else "PENDING"
	state.custom_minimum_size = Vector2(72, 0)
	state.add_theme_color_override("font_color", GREEN if is_active else MUTED)
	row.add_child(state)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = ACTION_LABELS.get(action["name"], str(action["name"]))
	details.add_child(name_label)
	var progress := Label.new()
	progress.text = "%.1f / %.1fs  •  %s" % [action["elapsed_seconds"], action["duration_seconds"], str(action["state"]).replace("_", " ")]
	progress.add_theme_color_override("font_color", MUTED)
	details.add_child(progress)
	row.add_child(details)
	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = "Cancel active Action" if is_active else "Remove pending Action"
	remove_button.custom_minimum_size = Vector2(42, 38)
	remove_button.focus_mode = Control.FOCUS_ALL
	if is_active:
		var committed: bool = action["state"] == &"committed" or action["elapsed_seconds"] >= action["commitment_seconds"]
		remove_button.disabled = committed
		remove_button.pressed.connect(_session.cancel_active_action)
	else:
		remove_button.pressed.connect(_session.remove_pending_action.bind(action["id"]))
	row.add_child(remove_button)
	return panel


func _rebuild_event_log(events: Array) -> void:
	var lines: PackedStringArray = []
	var start_index := maxi(0, events.size() - 7)
	for index in range(start_index, events.size()):
		var event: Dictionary = events[index]
		var color := "#96a6b5"
		if event["event"] in [&"order_served", &"drink_prepared", &"drink_picked_up", &"queue_continued"]:
			color = "#4ed48a"
		elif event["event"] in [&"action_failed", &"patron_left", &"action_effect_failed"]:
			color = "#ef7072"
		lines.append("[color=%s]%05.1fs  %s[/color]" % [color, event["at"], _event_text(event)])
	_event_log.text = "\n".join(lines)
	_event_log.scroll_to_line(maxi(0, lines.size() - 1))


func _event_text(event: Dictionary) -> String:
	match event["event"]:
		&"slice_started": return "June placed an Order."
		&"cultist_selected": return "%s selected." % CULTIST_LABELS.get(event["actor_id"], event["actor_id"])
		&"service_queued": return "Service path added to %s's Action Queue." % CULTIST_LABELS.get(event["actor_id"], event["actor_id"])
		&"drink_prepared": return "Prepared Drink is waiting physically at the bar."
		&"drink_picked_up": return "%s is carrying the Prepared Drink." % CULTIST_LABELS.get(event["actor_id"], event["actor_id"])
		&"order_served": return "June paid $%d + $%d tip." % [event["details"]["payment"], event["details"]["tip"]]
		&"patron_left": return "June left; Order cancelled with no payment."
		&"action_failed": return "%s failed: stale target." % ACTION_LABELS.get(event["details"]["name"], event["details"]["name"])
		&"queue_continued": return "Queue continued after prior result."
		&"pending_action_removed": return "Pending Action removed."
		&"active_action_cancelled": return "Active Action cancellation accepted."
	return str(event["event"]).replace("_", " ")


func _prepared_drink_text(drinks: Dictionary) -> String:
	if drinks.is_empty():
		return "None"
	var drink: Dictionary = drinks.values()[0]
	match drink["state"]:
		&"at_bar": return "%s — waiting at bar" % drink["id"]
		&"carried": return "%s — carried by %s" % [drink["id"], CULTIST_LABELS.get(drink["carried_by"], drink["carried_by"])]
		&"served": return "%s — delivered to June" % drink["id"]
	return "%s — %s" % [drink["id"], drink["state"]]


func _on_cultist_selected(cultist_id: StringName) -> void:
	_session.select_cultist(cultist_id)


func _on_queue_service() -> void:
	_session.queue_full_service()


func _on_patron_leaves() -> void:
	_session.patron_leaves()


func _apply_stage(stage: StringName) -> void:
	match stage:
		&"queued":
			_session.select_cultist(&"cultist_02")
			_session.queue_full_service()
			_session.advance(2.0)
		&"carried":
			_session.select_cultist(&"cultist_02")
			_session.queue_full_service()
			_session.advance(6.25)
		&"served":
			_session.select_cultist(&"cultist_02")
			_session.queue_full_service()
			_session.advance(10.25)
		&"failed":
			_session.select_cultist(&"cultist_03")
			_session.queue_full_service()
			_session.patron_leaves()
			_session.advance(2.0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			_stage = StringName(argument.trim_prefix("--stage="))
		elif argument.begins_with("--capture="):
			_capture_path = ProjectSettings.globalize_path(argument.trim_prefix("--capture="))
		elif argument.begins_with("--report="):
			_report_path = ProjectSettings.globalize_path(argument.trim_prefix("--report="))


func _write_report(path: String) -> void:
	var happy = SERVICE_SESSION_SCRIPT.new()
	happy.start()
	happy.queue_full_service(&"cultist_02")
	happy.advance(10.25)
	var stale = SERVICE_SESSION_SCRIPT.new()
	stale.start()
	stale.queue_full_service(&"cultist_03")
	stale.patron_leaves()
	stale.advance(2.0)
	var report := {
		"slice": "service_action_queue",
		"passed": (
			happy.snapshot()["order"]["state"] == &"served"
			and stale.snapshot()["order"]["state"] == &"cancelled"
			and stale.snapshot()["order"]["payment"] == 0
		),
		"happy_path": happy.snapshot(),
		"stale_target_path": stale.snapshot(),
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))


func _panel_container(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _panel_margin(amount: int = 14) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, amount)
	return margin


func _make_theme() -> Theme:
	var result := Theme.new()
	result.set_default_font(ThemeDB.fallback_font)
	result.set_default_font_size(14)
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("66717c"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("263340")
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color("33475b")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("235f4a")
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = BLUE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	result.set_stylebox("normal", "Button", normal)
	result.set_stylebox("hover", "Button", hover)
	result.set_stylebox("pressed", "Button", pressed)
	result.set_stylebox("focus", "Button", focus)
	return result
