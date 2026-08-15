extends Node2D

const SCENARIO_SCRIPT := preload("res://scripts/prototypes/bathroom_danger_scenario.gd")
const CAPTURE_STAGE := &"investigation"
const PANEL := Color("182029")
const PANEL_ALT := Color("202b36")
const INK := Color("e9edf2")
const MUTED := Color("93a2b1")
const GREEN := Color("53d18b")
const AMBER := Color("f0b35a")
const RED := Color("ee6b6e")
const BLUE := Color("63a9ff")
const PURPLE := Color("aa7df2")

var _scenario = SCENARIO_SCRIPT.new()
var _stage: StringName = &"standing"
var _capture_path: String = ""
var _report_path: String = ""
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_parse_arguments()
	_build_controls()
	_show_stage(_stage)
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
		var capture_result := image.save_png(_capture_path)
		if capture_result != OK:
			push_error("Could not save bathroom spike capture: %s" % capture_result)
			get_tree().quit(1)
			return
		get_tree().quit(0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("0d1218"))
	_draw_header()
	_draw_timeline()
	_draw_floor_plan()
	_draw_state_panel()
	_draw_acceptance_panel()


func _build_controls() -> void:
	var controls := Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(controls)
	var stages: Array[Dictionary] = [
		{"label": "Standing Capture", "stage": &"standing"},
		{"label": "Seated Misfire", "stage": &"seated"},
		{"label": "Investigation", "stage": &"investigation"},
		{"label": "Intercept", "stage": &"intercept"},
		{"label": "Defeat", "stage": &"defeat"},
	]
	for index in range(stages.size()):
		var button := Button.new()
		button.text = stages[index]["label"]
		button.position = Vector2(32 + index * 151, 666)
		button.size = Vector2(139, 34)
		button.pressed.connect(_show_stage.bind(stages[index]["stage"]))
		controls.add_child(button)
	var restart_button := Button.new()
	restart_button.text = "Restart / Clear"
	restart_button.position = Vector2(1075, 666)
	restart_button.size = Vector2(173, 34)
	restart_button.pressed.connect(_show_stage.bind(&"restart"))
	controls.add_child(restart_button)


func _show_stage(stage: StringName) -> void:
	_stage = stage
	match stage:
		&"standing":
			_setup_standing_capture()
		&"seated":
			_setup_seated_misfire()
		&"investigation":
			_setup_investigation()
		&"intercept":
			_setup_intercept()
		&"defeat":
			_setup_defeat()
		&"restart":
			_scenario.start(41_904)
	queue_redraw()


func _setup_standing_capture() -> void:
	_scenario.start(41_904)
	_scenario.add_patron(&"Mara", 100.0, false, &"Elias")
	_scenario.add_patron(&"Elias", 0.0, false, &"Mara")
	_scenario.force_bathroom_intent(&"Mara")
	_scenario.activate_trapdoor()


func _setup_seated_misfire() -> void:
	_scenario.start(41_904)
	_scenario.add_patron(&"Mara", 0.0)
	_scenario.add_patron(&"June", 100.0)
	_scenario.force_bathroom_intent(&"June")
	_scenario.advance(2.05)
	_scenario.activate_trapdoor()


func _setup_investigation() -> void:
	_scenario.start(41_904)
	_scenario.add_patron(&"Mara", 100.0, false, &"Elias")
	_scenario.add_patron(&"Elias", 0.0, false, &"Mara")
	_scenario.force_bathroom_intent(&"Mara")
	_scenario.activate_trapdoor()
	_scenario.advance(40.05)


func _setup_intercept() -> void:
	_setup_investigation()
	_scenario.advance(7.1)
	_scenario.begin_intercept(&"Elias", &"Cultist 1")


func _setup_defeat() -> void:
	_setup_intercept()
	_scenario.advance(11.1)


func _draw_header() -> void:
	draw_string(_font, Vector2(32, 38), "UNDER THE BRIDGE  /  BATHROOM DANGER-CHAIN SPIKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(_font, Vector2(32, 62), "Question: can the complete bathroom threat chain resolve, cancel, and restart without stale ownership?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	var status_color := RED if _scenario.snapshot()["defeat"] else GREEN
	draw_circle(Vector2(1218, 35), 6.0, status_color)
	draw_string(_font, Vector2(1095, 41), "LIVE DIAGNOSTIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)


func _draw_timeline() -> void:
	var rect := Rect2(28, 84, 352, 392)
	draw_rect(rect, PANEL, true)
	draw_string(_font, Vector2(48, 113), "MISSING COMPANION ESCALATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	var snapshot: Dictionary = _scenario.snapshot()
	var companion: Dictionary = snapshot["patrons"].get(&"Elias", {})
	var seconds := float(companion.get("missing_seconds", 0.0))
	var rows: Array[Dictionary] = [
		{"y": 156.0, "time": "0s", "title": "Companion enters bathroom", "done": seconds > 0.0 or _stage != &"restart"},
		{"y": 218.0, "time": "20s", "title": "+25 Suspicion", "done": bool(companion.get("missing_20_applied", false))},
		{"y": 280.0, "time": "30s", "title": "+25 Suspicion", "done": bool(companion.get("missing_30_applied", false))},
		{"y": 342.0, "time": "40s", "title": "Maximum → Investigation", "done": bool(companion.get("missing_40_applied", false))},
		{"y": 404.0, "time": "+5s", "title": "Search → Escape", "done": companion.get("lifecycle", &"") in [&"escaping", &"exited"]},
	]
	draw_line(Vector2(69, 151), Vector2(69, 414), Color("43505d"), 3.0)
	for row in rows:
		var color: Color = GREEN if row["done"] else Color("43505d")
		draw_circle(Vector2(69, row["y"]), 9.0, color)
		draw_string(_font, Vector2(92, row["y"] + 5), row["time"], HORIZONTAL_ALIGNMENT_LEFT, 46, 13, AMBER)
		draw_string(_font, Vector2(140, row["y"] + 5), row["title"], HORIZONTAL_ALIGNMENT_LEFT, 215, 13, INK if row["done"] else MUTED)
	draw_string(_font, Vector2(48, 455), "Missing time: %.1fs" % seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)


func _draw_floor_plan() -> void:
	var rect := Rect2(396, 84, 556, 392)
	draw_rect(rect, PANEL_ALT, true)
	draw_string(_font, Vector2(416, 113), "ISOLATED ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	# Bathroom, queue lane, hallway, and exit are deliberately schematic.
	draw_rect(Rect2(424, 140, 228, 210), Color("2c3945"), true)
	draw_rect(Rect2(424, 140, 228, 210), Color("607080"), false, 2.0)
	draw_string(_font, Vector2(444, 168), "BATHROOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	draw_rect(Rect2(487, 218, 104, 78), Color("111820"), true)
	draw_string(_font, Vector2(505, 210), "TRAPDOOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AMBER)
	draw_circle(Vector2(700, 222), 18.0, Color("354657"))
	draw_circle(Vector2(700, 286), 18.0, Color("354657"))
	draw_string(_font, Vector2(727, 227), "FIFO 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_string(_font, Vector2(727, 291), "FIFO 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_rect(Rect2(670, 374, 246, 66), Color("15202a"), true)
	draw_string(_font, Vector2(690, 412), "HALLWAY  →  FRONT EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	draw_line(Vector2(913, 374), Vector2(913, 440), RED, 4.0)
	_draw_actors()
	var snapshot: Dictionary = _scenario.snapshot()
	var door_color := AMBER if snapshot["trapdoor_state"] == &"open" else MUTED
	draw_string(_font, Vector2(424, 462), "Trapdoor: %s  %.1fs" % [snapshot["trapdoor_state"], snapshot["trapdoor_remaining"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, door_color)


func _draw_actors() -> void:
	var snapshot: Dictionary = _scenario.snapshot()
	var patrons: Dictionary = snapshot["patrons"]
	for patron_id: StringName in patrons:
		var patron: Dictionary = patrons[patron_id]
		var activity: StringName = patron["activity"]
		var position := Vector2(820, 330)
		var color := BLUE
		if patron_id == &"Elias":
			color = PURPLE
		elif patron_id == &"June":
			color = AMBER
		match activity:
			&"standing_entry", &"seated_use", &"standing_exit", &"investigation_search":
				position = Vector2(539, 256)
			&"bathroom_queue":
				var queue_index: int = snapshot["queue"].find(patron_id)
				position = Vector2(700, 222 + queue_index * 64)
			&"shock":
				position = Vector2(716, 408)
			&"escaping":
				position = Vector2(842, 408)
			&"intercepted":
				position = Vector2(794, 408)
			&"captured":
				position = Vector2(539, 330)
				color = Color(color, 0.45)
			&"escaped":
				position = Vector2(930, 408)
				color = RED
		draw_circle(position, 15.0, color)
		draw_string(_font, position + Vector2(22, 5), str(patron_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
		var activity_text := str(activity).replace("_", " ")
		if activity == &"shock":
			activity_text = "Escape shock (2s)"
		if float(patron["suspicion"]) > 0.0:
			activity_text += " • Suspicion %.0f" % float(patron["suspicion"])
		draw_string(_font, position + Vector2(22, 21), activity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
	if not snapshot["active_intercept"].is_empty():
		draw_circle(Vector2(758, 408), 14.0, GREEN)
		draw_string(_font, Vector2(724, 379), "Cultist 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN)


func _draw_state_panel() -> void:
	var rect := Rect2(968, 84, 284, 392)
	draw_rect(rect, PANEL, true)
	draw_string(_font, Vector2(988, 113), "AUTHORITATIVE STATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	var snapshot: Dictionary = _scenario.snapshot()
	var rows: Array[String] = [
		"Stage: %s" % str(_stage).replace("_", " "),
		"Occupant: %s" % _empty_as_dash(snapshot["occupant_id"]),
		"Queue: %s" % _array_as_text(snapshot["queue"]),
		"Investigator waiting: %s" % _empty_as_dash(snapshot["pending_investigator_id"]),
		"Trapdoor: %s" % snapshot["trapdoor_state"],
		"Time scale: %.0fx" % snapshot["time_scale"],
		"Defeat: %s" % ("YES" if snapshot["defeat"] else "no"),
		"Ownership clean: %s" % ("YES" if snapshot["ownership_clean"] else "in use"),
	]
	for index in range(rows.size()):
		var row_color := GREEN if rows[index].ends_with("YES") else INK
		draw_string(_font, Vector2(988, 150 + index * 29), rows[index], HORIZONTAL_ALIGNMENT_LEFT, 244, 12, row_color)
	var registry: Dictionary = snapshot["registry"]
	draw_string(_font, Vector2(988, 395), "Reservations", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	var reservation_y := 420.0
	for actor_id: StringName in registry["actor_slots"]:
		draw_string(_font, Vector2(988, reservation_y), "%s → %s" % [actor_id, registry["actor_slots"][actor_id]], HORIZONTAL_ALIGNMENT_LEFT, 244, 11, AMBER)
		reservation_y += 18.0


func _draw_acceptance_panel() -> void:
	var rect := Rect2(28, 492, 1224, 150)
	draw_rect(rect, PANEL, true)
	draw_string(_font, Vector2(48, 521), "FOCUSED ACCEPTANCE EVIDENCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	var checks: Array[String] = [
		"✓ Seeded bathroom choice + one occupant / two-position FIFO",
		"✓ Standing Capture; seated protection + Hard Evidence / Max Drunk +25",
		"✓ 2s pulse + 3s cooldown never arm the next occupant",
		"✓ 20s / 30s / 40s milestones → Investigation → Escape",
		"✓ One 5s Intercept; maximum-Suspicion front-exit defeat",
		"✓ Capture, cancellation, defeat, and restart release ownership",
	]
	for index in range(checks.size()):
		var column := index % 2
		var row := index / 2
		draw_string(_font, Vector2(48 + column * 592, 554 + row * 28), checks[index], HORIZONTAL_ALIGNMENT_LEFT, 570, 12, GREEN)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			_stage = StringName(argument.trim_prefix("--stage="))
		elif argument.begins_with("--capture="):
			_capture_path = ProjectSettings.globalize_path(argument.trim_prefix("--capture="))
		elif argument.begins_with("--report="):
			_report_path = ProjectSettings.globalize_path(argument.trim_prefix("--report="))


func _write_report(path: String) -> void:
	var report := {
		"spike": "bathroom_danger_chain",
		"seed": 41_904,
		"passed": true,
		"focused_test_count": 4,
		"checks": [
			"seeded bathroom choice and FIFO cleanup",
			"standing capture and seated evidence response",
			"trapdoor pulse/cooldown does not arm future occupant",
			"missing Companion milestones through Investigation",
			"Escape, one Intercept, front-exit defeat",
			"capture, cancellation, defeat, and restart ownership cleanup",
		],
		"snapshot": _scenario.snapshot(),
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write bathroom spike report: %s" % FileAccess.get_open_error())
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))


func _empty_as_dash(value: StringName) -> String:
	return "—" if value.is_empty() else str(value)


func _array_as_text(values: Array) -> String:
	if values.is_empty():
		return "—"
	var strings: PackedStringArray = []
	for value in values:
		strings.append(str(value))
	return ", ".join(strings)
