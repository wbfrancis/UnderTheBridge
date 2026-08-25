class_name EmoteOverlay
extends CanvasLayer

## Draws the Emote Bubbles EmoteDirector chose.
##
## The overlay owns no gameplay rule and no priority rule. It projects each
## actor's head anchor through the active camera, solves placement, and renders
## the descriptions it is given at a fixed pixel size.
##
## The same projection answers a second question: an urgent actor who has left
## the camera view gets a clickable Offscreen Indicator on the screen edge. That
## reuses the anchors, the safe bounds, and the reserved HUD rectangles this
## module already owns, so nothing needs a second projection system.

## Pressed by the player to move the camera to that actor.
signal offscreen_indicator_pressed(actor_id: StringName)

const BASE_SIZE := Vector2(34.0, 34.0)
const LABEL_WIDTH := 86.0
const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.5

## Tried in this order. The higher-priority bubble keeps its preferred anchor.
const OFFSETS: Array[Vector2] = [
	Vector2(0.0, -8.0),
	Vector2(-40.0, -26.0),
	Vector2(40.0, -26.0),
	Vector2(0.0, -46.0),
	Vector2(-52.0, 0.0),
	Vector2(52.0, 0.0),
	Vector2(-46.0, -62.0),
	Vector2(46.0, -62.0),
	Vector2(0.0, -84.0),
]

const INDICATOR_SIZE := Vector2(48.0, 34.0)
## Only an urgent state earns an edge marker: a persistent Escape, a persistent
## Investigation, and the transient danger reaction. Everything else is ordinary
## and stays inside the scene.
const URGENT_EMOTES: Array[StringName] = [
	&"escaping", &"investigating", &"danger_reaction",
]

var _camera: Camera3D
var _safe_inset := 12.0
var _panel_rects: Array[Rect2] = []
var _accessible_labels := false
var _ui_scale := 1.0
var _slots: Array[Control] = []
var _indicator_slots: Array[Button] = []
var _indicators: Dictionary = {}
var _last_offsets: Dictionary = {}
var _placements: Dictionary = {}


func configure(camera: Camera3D) -> void:
	_camera = camera
	layer = 2


func set_accessible_labels(enabled: bool) -> void:
	_accessible_labels = enabled


func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(value, MIN_UI_SCALE, MAX_UI_SCALE)


## Screen rectangles the bubbles must not cover: top controls, Hover Summary,
## and the Patron Info Panel.
func set_reserved_rects(rects: Array[Rect2]) -> void:
	_panel_rects = rects.duplicate()


func reset() -> void:
	_last_offsets.clear()
	_placements.clear()
	_indicators.clear()
	for slot in _slots:
		slot.visible = false
	for indicator in _indicator_slots:
		indicator.visible = false


## Renders one frame. `anchors` maps actor id to the world-space head position.
func refresh(bubbles: Array[Dictionary], anchors: Dictionary) -> void:
	_placements.clear()
	if _camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var bounds := Rect2(
		Vector2(_safe_inset, _safe_inset),
		viewport_size - Vector2(_safe_inset, _safe_inset) * 2.0
	)
	var taken: Array[Rect2] = []
	var used := 0
	var offscreen: Array[Dictionary] = []
	for bubble: Dictionary in bubbles:
		var actor_id: StringName = bubble["actor_id"]
		if not anchors.has(actor_id):
			continue
		var world: Vector3 = anchors[actor_id]
		if _camera.is_position_behind(world) or not Rect2(
			Vector2.ZERO, viewport_size
		).has_point(_camera.unproject_position(world)):
			if _is_urgent(bubble):
				offscreen.append(bubble)
			continue
		var screen := _camera.unproject_position(world)
		var size := _bubble_size()
		var placement: Variant = _solve_placement(actor_id, screen, size, bounds, taken)
		if placement == null:
			continue
		var rect: Rect2 = placement
		taken.append(rect)
		_placements[actor_id] = rect
		_paint(used, bubble, rect)
		used += 1
	for index in range(used, _slots.size()):
		_slots[index].visible = false
	_refresh_indicators(offscreen, anchors, taken)


## The rectangle a bubble occupies, for the rendered review checks.
func placements() -> Dictionary:
	return _placements.duplicate(true)


## The Offscreen Indicators now on screen: actor id to rectangle and label.
func offscreen_indicators() -> Dictionary:
	return _indicators.duplicate(true)


## Presses one Offscreen Indicator. Returns false when that actor has none.
func press_offscreen_indicator(actor_id: StringName) -> bool:
	if not _indicators.has(actor_id):
		return false
	offscreen_indicator_pressed.emit(actor_id)
	return true


func _is_urgent(bubble: Dictionary) -> bool:
	return StringName(bubble.get("emote", &"")) in URGENT_EMOTES


# One indicator for one actor, clamped to the usable scene edge above the Bottom
# HUD and pushed clear of any reserved panel or open modal.
func _refresh_indicators(
		offscreen: Array[Dictionary],
		anchors: Dictionary,
		taken: Array[Rect2]
) -> void:
	_indicators.clear()
	var bounds := _usable_bounds()
	var used := 0
	for bubble: Dictionary in offscreen:
		var actor_id: StringName = bubble["actor_id"]
		if _indicators.has(actor_id) or bounds.size.x <= INDICATOR_SIZE.x:
			continue
		var direction := _screen_direction(anchors[actor_id])
		var rect := _edge_rect(direction, bounds)
		rect = _push_clear(rect, bounds, taken)
		taken.append(rect)
		var label := "Focus %s: %s" % [
			bubble.get("display_name", _humanize(actor_id)),
			String(bubble["emote"]).replace("_", " "),
		]
		_indicators[actor_id] = {"rect": rect, "label": label, "emote": bubble["emote"]}
		_paint_indicator(used, bubble, rect, label, actor_id)
		used += 1
	for index in range(used, _indicator_slots.size()):
		_indicator_slots[index].visible = false


# The scene area a marker may use: the safe rectangle, minus whatever the HUD
# reserves along the bottom edge.
func _usable_bounds() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var bounds := Rect2(
		Vector2(_safe_inset, _safe_inset),
		viewport_size - Vector2(_safe_inset, _safe_inset) * 2.0
	)
	var floor_y := bounds.end.y
	for reserved: Rect2 in _panel_rects:
		if reserved.end.y >= viewport_size.y - 1.0 and reserved.position.y < floor_y:
			floor_y = reserved.position.y
	bounds.size.y = maxf(INDICATOR_SIZE.y, floor_y - _safe_inset - bounds.position.y)
	return bounds


# Which way the actor lies from the screen centre, including behind the camera,
# where the projected point would otherwise read as mirrored.
func _screen_direction(world: Vector3) -> Vector2:
	var local := _camera.global_transform.affine_inverse() * world
	var direction := Vector2(local.x, -local.y)
	if local.z > 0.0:
		direction = -direction
	if direction.is_zero_approx():
		return Vector2(0.0, -1.0)
	return direction.normalized()


func _edge_rect(direction: Vector2, bounds: Rect2) -> Rect2:
	var center := bounds.get_center()
	var half := bounds.size * 0.5 - INDICATOR_SIZE * 0.5
	var travel := INF
	if not is_zero_approx(direction.x):
		travel = minf(travel, maxf(0.0, half.x) / absf(direction.x))
	if not is_zero_approx(direction.y):
		travel = minf(travel, maxf(0.0, half.y) / absf(direction.y))
	if is_inf(travel):
		travel = 0.0
	var point := center + direction * travel
	return Rect2(point - INDICATOR_SIZE * 0.5, INDICATOR_SIZE).abs()


# Slides the marker along the edge until it stops covering a reserved panel or
# another marker. It never leaves the usable bounds.
func _push_clear(rect: Rect2, bounds: Rect2, taken: Array[Rect2]) -> Rect2:
	var step := INDICATOR_SIZE.y + 6.0
	for attempt in range(8):
		var candidate := rect
		var shift := step * float((attempt + 1) / 2) * (1.0 if attempt % 2 == 0 else -1.0)
		if attempt > 0:
			candidate.position.y += shift
		candidate.position.x = clampf(
			candidate.position.x, bounds.position.x, bounds.end.x - candidate.size.x
		)
		candidate.position.y = clampf(
			candidate.position.y, bounds.position.y, bounds.end.y - candidate.size.y
		)
		if _is_legal(candidate, bounds, taken):
			return candidate
	return rect


func _paint_indicator(
		index: int,
		bubble: Dictionary,
		rect: Rect2,
		label: String,
		actor_id: StringName
) -> void:
	var button := _indicator(index)
	button.position = rect.position
	button.custom_minimum_size = rect.size
	button.size = rect.size
	button.visible = true
	button.text = "%s %s" % [_indicator_arrow(rect), bubble["icon"]]
	button.tooltip_text = label
	if "accessibility_name" in button:
		button.set("accessibility_name", label)
	var style := _bubble_style(Color(bubble["color"]), bubble["shape"])
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(bubble["color"]))
	button.set_meta("actor_id", actor_id)


func _indicator_arrow(rect: Rect2) -> String:
	var bounds := _usable_bounds()
	var gaps := {
		"left": absf(rect.position.x - bounds.position.x),
		"right": absf(rect.end.x - bounds.end.x),
		"top": absf(rect.position.y - bounds.position.y),
		"bottom": absf(rect.end.y - bounds.end.y),
	}
	var edge := "left"
	for candidate: String in gaps:
		if float(gaps[candidate]) < float(gaps[edge]):
			edge = candidate
	return {"left": "←", "right": "→", "top": "↑", "bottom": "↓"}[edge]


func _indicator(index: int) -> Button:
	while _indicator_slots.size() <= index:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.pressed.connect(func() -> void:
			offscreen_indicator_pressed.emit(StringName(button.get_meta("actor_id", &"")))
		)
		_indicator_slots.append(button)
		add_child(button)
	return _indicator_slots[index]


func _humanize(actor_id: StringName) -> String:
	return String(actor_id).split("_")[-1].capitalize()


func _bubble_size() -> Vector2:
	var size := BASE_SIZE
	if _accessible_labels:
		size.x += LABEL_WIDTH
	return size * _ui_scale


# Keeps the previous legal offset while conditions stay equivalent, so a bubble
# does not jitter between two valid positions from frame to frame.
func _solve_placement(
		actor_id: StringName,
		screen: Vector2,
		size: Vector2,
		bounds: Rect2,
		taken: Array[Rect2]
) -> Variant:
	var order: Array[int] = []
	if _last_offsets.has(actor_id):
		order.append(int(_last_offsets[actor_id]))
	for index in range(OFFSETS.size()):
		if not order.has(index):
			order.append(index)
	for index: int in order:
		var offset := OFFSETS[index] * _ui_scale
		var rect := Rect2(screen + offset - Vector2(size.x * 0.5, size.y), size)
		if not _is_legal(rect, bounds, taken):
			continue
		_last_offsets[actor_id] = index
		return rect
	_last_offsets.erase(actor_id)
	return null


func _is_legal(rect: Rect2, bounds: Rect2, taken: Array[Rect2]) -> bool:
	if not bounds.encloses(rect):
		return false
	for reserved: Rect2 in _panel_rects:
		if reserved.intersects(rect):
			return false
	for other: Rect2 in taken:
		if other.intersects(rect):
			return false
	return true


func _paint(index: int, bubble: Dictionary, rect: Rect2) -> void:
	var slot := _slot(index)
	slot.position = rect.position
	slot.custom_minimum_size = rect.size
	slot.size = rect.size
	slot.visible = true
	var color := Color(bubble["color"])
	var panel := slot.get_node("Panel") as Panel
	panel.add_theme_stylebox_override("panel", _bubble_style(color, bubble["shape"]))
	var icon := slot.get_node("Panel/Row/Icon") as Label
	icon.text = String(bubble["icon"])
	icon.add_theme_font_size_override("font_size", int(18.0 * _ui_scale))
	var text := slot.get_node("Panel/Row/Text") as Label
	text.visible = _accessible_labels
	text.text = String(bubble["label"]) if _accessible_labels else ""
	text.add_theme_font_size_override("font_size", int(12.0 * _ui_scale))


# Silhouette, not colour, separates the categories: a burst reads as urgent, a
# diamond as attention, a square as work, a circle as an ordinary state.
func _bubble_style(color: Color, shape: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	style.border_color = color
	style.set_border_width_all(int(maxf(2.0, 2.0 * _ui_scale)))
	match shape:
		&"circle":
			style.set_corner_radius_all(int(BASE_SIZE.y * 0.5 * _ui_scale))
		&"diamond":
			style.set_corner_radius_all(int(4.0 * _ui_scale))
			style.skew = Vector2(0.18, 0.0)
		&"burst":
			style.set_corner_radius_all(int(2.0 * _ui_scale))
			style.border_color = color
			style.set_border_width_all(int(maxf(3.0, 3.0 * _ui_scale)))
		_:
			style.set_corner_radius_all(int(3.0 * _ui_scale))
	style.set_content_margin_all(int(3.0 * _ui_scale))
	return style


func _slot(index: int) -> Control:
	while _slots.size() <= index:
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var panel := Panel.new()
		panel.name = "Panel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(panel)
		var row := HBoxContainer.new()
		row.name = "Row"
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var icon := Label.new()
		icon.name = "Icon"
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.custom_minimum_size = Vector2(BASE_SIZE.x - 8.0, 0.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var text := Label.new()
		text.name = "Text"
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)
		_slots.append(slot)
		add_child(slot)
	return _slots[index]
