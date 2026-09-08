class_name ModifierTooltip
extends PanelContainer

const INK := Color("DDD0B2")
const MUTED := Color("99938A")
const BRASS := Color("D5A95A")
const INCREASE := Color("69B77C")
const DECREASE := Color("C96B62")
const BACKGROUND := Color("101A16F5")

var _grid: GridContainer
var _rows: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(218.0, 0.0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = BACKGROUND
	frame.border_color = Color("A47A3D")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(3)
	frame.set_content_margin_all(10.0)
	add_theme_stylebox_override("panel", frame)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 5)
	add_child(_grid)


func set_breakdown(breakdown: Dictionary) -> void:
	_rows.clear()
	_rows.append({
		"label": String(breakdown.get("base_label", "Base")),
		"value": "%d%%" % int(breakdown.get("base", 0)),
		"tone": &"base",
	})
	for modifier: Dictionary in breakdown.get("modifiers", []):
		if not bool(modifier.get("known", false)):
			_rows.append({"label": "???", "value": "???", "tone": &"unknown"})
			continue
		var points := int(modifier.get("points", 0))
		_rows.append({
			"label": String(modifier.get("label", "")),
			"value": "+%d%%" % points if points >= 0 else "−%d%%" % absi(points),
			"tone": &"increase" if points >= 0 else &"decrease",
		})
	_rows.append({
		"label": "Total",
		"value": String(breakdown.get("public_total", "???")),
		"tone": &"total",
	})
	_render()
	tooltip_text = _accessible_text()


func display_rows() -> Array[Dictionary]:
	return _rows.duplicate(true)


static func clamped_position(
		desired: Vector2, popup_size: Vector2, viewport_size: Vector2
) -> Vector2:
	return Vector2(
		clampf(desired.x, 6.0, maxf(6.0, viewport_size.x - popup_size.x - 6.0)),
		clampf(desired.y, 6.0, maxf(6.0, viewport_size.y - popup_size.y - 6.0))
	)


func _render() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for row: Dictionary in _rows:
		var label := Label.new()
		label.text = row["label"]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", _tone_color(row["tone"]))
		_grid.add_child(label)
		var value := Label.new()
		value.text = row["value"]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", _tone_color(row["tone"]))
		_grid.add_child(value)


func _tone_color(tone: StringName) -> Color:
	match tone:
		&"increase": return INCREASE
		&"decrease": return DECREASE
		&"unknown": return MUTED
		&"total": return BRASS
	return INK


func _accessible_text() -> String:
	var parts: Array[String] = []
	for row: Dictionary in _rows:
		match StringName(row["tone"]):
			&"unknown": parts.append("Unknown modifier.")
			&"decrease": parts.append("%s minus %s." % [row["label"], String(row["value"]).trim_prefix("−")])
			&"total" when row["value"] == "???": parts.append("Total unknown.")
			_: parts.append("%s %s." % [row["label"], row["value"]])
	return " ".join(parts)
