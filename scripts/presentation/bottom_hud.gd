class_name BottomHud
extends CanvasLayer

## The Green Folio Bottom HUD: the whole player interface for one Night.
##
## The module owns every piece of HUD presentation — zone layout, portraits,
## Action Tiles, the analog Night Clock, progress fills, pressed states, hover
## help, the anchored utility menus, the Pause Menu, and the Outcome Modal. The
## world adapter never reaches into a child control.
##
## Two calls make the whole interface:
##
##   render(view)                 draw one display-ready description
##   intent_submitted(kind, ...)  report one piece of player intent
##
## `view` carries display-ready, player-readable data only. No hidden Patron
## value, roll, or timer may cross this seam, and the HUD keeps no gameplay
## state of its own: what it shows is what it was last given.

signal intent_submitted(kind: StringName, payload: Dictionary)

const THEME: Theme = preload("res://resources/ui/green_folio_theme.tres")
const WOOD_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/wood_finished03.jpg"
)
const NIGHT_CLOCK_SCRIPT := preload("res://scripts/presentation/night_clock.gd")
const EMPTY_PATRON_TEXTURE: Texture2D = preload(
	"res://assets/ui/green_folio/empty_patron.svg"
)
const ICON_DIRECTORY := "res://assets/ui/green_folio/icons/"

# The approved Green Folio palette.
const GREEN := Color("367055")
const DARK_FOLIO := Color("153727")
const CREAM := Color("EAD8A8")
const PAPER_SHADE := Color("BFA775")
const WOOD := Color("744522")
const DARK_WOOD := Color("4D2D18")
const INK := Color("352416")
const BRASS := Color("A8793E")
const DANGER := Color("A14C3E")

const HUD_HEIGHT := 166.0
const TILE_COUNT := 4
const TILE_SIZE := 54.0
const TILE_GAP := 6.0
const TILES_LEFT := 26.0
const TILES_BOTTOM_GAP := 12.0
const PORTRAIT_SIZE := Vector2(54.0, 62.0)
const PORTRAIT_CAPTION_HEIGHT := 32.0
const CLOCK_SIZE := 92.0
const PLAYBACK_HEIGHT := 28.0
const UTILITY_WIDTH := 46.0
## The Patron empty-state caption already gives its portrait this visual gutter.
## Apply the same gutter to the denser Cultist and Night content.
const CULTIST_SIDE_GUTTER := 10
const NIGHT_SIDE_GUTTER := 13
const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.5
## How long one short feedback line stays on screen, in real seconds.
const FEEDBACK_SECONDS := 3.0

## One table maps a command to its Action Tile icon. An unlisted future command
## falls back to the neutral icon instead of breaking the tile strip.
const COMMAND_ICONS := {
	&"move": "move",
	&"drop_body": "drop_body",
	&"talk": "talk",
	&"serve_order": "serve_order",
	&"offer_drink": "offer_drink",
	&"offer_cigarette": "offer_cigarette",
	&"knock_out": "knock_out",
	&"pick_up_body": "pick_up_body",
	&"intercept": "intercept",
	&"lead_to_tunnel": "lead_to_tunnel",
	&"rescue_persuasion": "rescue_persuasion",
	&"prepare_drink": "prepare_drink",
	&"prepare_drugged_drink": "prepare_drugged_drink",
	&"activate_trapdoor": "activate_trapdoor",
}
const FALLBACK_ACTION_ICON := "action_fallback"

## Qualitative fills. A band label is what the player already reads, so the fill
## only reinforces it; no exact hidden value is ever shown.
const MOOD_BANDS := {"Miserable": 0.15, "Unhappy": 0.4, "Content": 0.7, "Happy": 1.0}
const SUSPICION_BANDS := {
	"Calm": 0.12, "Uneasy": 0.34, "Suspicious": 0.58, "Alarmed": 0.8, "Maximum": 1.0,
}
const INTOXICATION_BANDS := {"Sober": 0.1, "Buzzed": 0.4, "Drunk": 0.72, "Max Drunk": 1.0}

const SPEED_CONTROLS := {&"speed_1": 1.0, &"speed_2": 2.0, &"speed_4": 4.0}
const UI_SCALE_STEPS: Array[float] = [0.75, 1.0, 1.25, 1.5]

## Time control is dead while an Outcome Modal blocks the Night.
const TIME_INTENTS: Array[StringName] = [
	&"set_time_scale", &"toggle_pause", &"advance_debug_time", &"select_scenario",
	&"open_pause_menu",
]

var _view: Dictionary = empty_view()
var _ui_scale := 1.0
var _root: Control
var _tiles_row: HBoxContainer
var _tile_slots: Array[Dictionary] = []
var _cultist_portrait: TextureRect
var _cultist_name: Label
var _cultist_activity: Label
var _cultist_status: Label
var _cultist_zone: PanelContainer
var _clock: NightClock
var _clock_hover: Control
var _night_zone: PanelContainer
var _night_fill: ColorRect
var _night_track: Control
var _speed_buttons: Dictionary = {}
var _pause_button: Button
var _patron_portrait: TextureRect
var _patron_name: Label
var _patron_detail: VBoxContainer
var _patron_zone: PanelContainer
var _patron_activity: Label
var _patron_meters: Dictionary = {}
var _patron_close: Button
var _settings_button: Button
var _developer_button: Button
var _menu_scrim: Control
var _settings_panel: PanelContainer
var _developer_panel: PanelContainer
var _scenario_buttons: Dictionary = {}
var _debug_toggle: Button
var _emote_toggle: Button
var _reduced_motion_toggle: Button
var _ui_scale_buttons: Dictionary = {}
var _developer_built := false
var _pause_menu: Control
var _outcome_modal: Control
var _outcome_title: Label
var _outcome_cause: Label
var _outcome_quota: Label
var _outcome_fill: ColorRect
var _hover_panel: PanelContainer
var _hover_label: Label
var _hover_text := ""
var _feedback_panel: PanelContainer
var _feedback_label: Label
var _feedback_serial := -1
var _feedback_remaining := 0.0


## The shape `render` accepts. It is also the empty Night: no Cultist selected,
## no Action, no Inspected Patron, no modal.
static func empty_view() -> Dictionary:
	return {
		"selected_cultist": {},
		"action_tiles": [],
		"night": {
			"clock_label": "8:00 PM",
			"clock_minutes": 20.0 * 60.0,
			"closing_label": "2:00 AM",
			"remaining_label": "18m 00s",
			"progress_ratio": 0.0,
			"time_scale": 0.0,
			"last_nonzero_scale": 1.0,
			"paused": true,
			"phase": &"preparation",
		},
		"inspected_patron": {},
		"outcome": {
			"visible": false, "kind": &"", "cause": "",
			"captures": 0, "capture_quota": 3, "progress_ratio": 0.0,
		},
		"feedback": {"text": "", "serial": 0},
		"developer": {"visible": false, "scenario_id": "", "scenarios": []},
		"settings": {"emote_labels": false, "ui_scale": 1.0, "reduced_motion": false},
		"pause_menu_open": false,
	}


## Which Simulation Speed the pause control asks for next. Space pauses at any
## running speed and resumes the last accepted nonzero one. The world adapter
## owns the remembered value; the rule lives beside the control that uses it.
static func resume_scale(current_scale: float, last_nonzero_scale: float) -> float:
	if current_scale > 0.0:
		return 0.0
	return last_nonzero_scale if last_nonzero_scale > 0.0 else 1.0


func _ready() -> void:
	layer = 3
	_build()
	render(_view)


# --- Interface ---------------------------------------------------------------

## Draws one frame of the HUD from a display-ready description.
func render(view: Dictionary) -> void:
	if _root == null:
		_view = view.duplicate(true)
		return
	_view = _merge_view(view)
	_apply_ui_scale(float(_view["settings"]["ui_scale"]))
	_render_cultist()
	_render_action_tiles()
	_render_night()
	_render_patron()
	_render_feedback()
	_render_menus()
	_render_pause_menu()
	_render_outcome()
	_bind_press_feedback()


## Opens the real clock Hover Summary for an automated approval frame.
func preview_clock_hover() -> void:
	var night: Dictionary = _view["night"]
	_show_hover(_clock_hover, "%s   Closing %s   %s left" % [
		night["clock_label"], night["closing_label"], night["remaining_label"],
	])


## One entry point for player intent, whether it came from a control, a keyboard
## shortcut, or a test. The HUD applies its own visibility rules here, then
## reports what the world adapter must act on.
func activate(control: StringName, payload: Dictionary = {}) -> void:
	match control:
		&"escape":
			_handle_escape()
		&"settings_menu":
			_toggle_menu(_settings_panel)
		&"developer_menu":
			_toggle_menu(_developer_panel)
		&"close_menus":
			_close_menus()
		&"speed_1", &"speed_2", &"speed_4":
			_emit(&"set_time_scale", {"value": SPEED_CONTROLS[control]})
		&"toggle_pause":
			_emit(&"toggle_pause", {})
		&"cancel_tile":
			_cancel_tile(int(payload.get("index", -1)))
		&"close_patron":
			_emit(&"close_inspected_patron", {})
		&"open_pause_menu":
			_emit(&"open_pause_menu", {})
		&"resume":
			_emit(&"resume_night", {})
		&"restart":
			_close_menus()
			_emit(&"restart_night", {})
		&"quit":
			_emit(&"quit_game", {})
		&"scenario":
			_close_menus()
			_emit(&"select_scenario", {"scenario_id": String(payload.get("scenario_id", ""))})
		&"debug_step":
			_emit(&"advance_debug_time", {"seconds": float(payload.get("seconds", 1.0))})
		&"set_debug_visible":
			_emit(&"set_debug_visible", {"enabled": bool(payload.get("enabled", false))})
		&"set_emote_labels":
			_emit(&"set_emote_labels", {"enabled": bool(payload.get("enabled", false))})
		&"set_ui_scale":
			_emit(&"set_ui_scale", {"scale": float(payload.get("scale", 1.0))})
		&"set_reduced_motion":
			_emit(&"set_reduced_motion", {"enabled": bool(payload.get("enabled", false))})
		&"restart_scenario":
			_close_menus()
			_emit(&"select_scenario", {
				"scenario_id": String(_view["developer"].get("scenario_id", "")),
			})


## What the HUD currently shows. The world adapter and the interface tests read
## this instead of walking the control tree.
func inspect() -> Dictionary:
	var tiles: Array[Dictionary] = []
	for index in range(_tile_slots.size()):
		var slot: Dictionary = _tile_slots[index]
		var data: Dictionary = slot["data"]
		tiles.append({
			"filled": not data.is_empty(),
			"active": bool(data.get("active", false)),
			"cancellable": bool(data.get("cancellable", false)),
			"action_id": int(data.get("id", -1)),
			"label": String(data.get("label", "")),
			"target_label": String(data.get("target_label", "")),
			"progress_ratio": data.get("progress_ratio", null),
			"cancel_visible": (slot["cancel"] as Button).visible,
			"rect": (slot["button"] as Control).get_rect(),
		})
	var night: Dictionary = _view["night"]
	return {
		"action_tiles": tiles,
		"action_tiles_visible": _tiles_row.visible,
		"cultist": {
			"name": _cultist_name.text,
			"activity": _cultist_activity.text,
			"status": _cultist_status.text,
			"portrait_rect": _cultist_portrait.get_rect(),
			"name_rect": _cultist_name.get_rect(),
			"name_below_portrait": _is_below(_cultist_name, _cultist_portrait),
			"content_left_inset": _left_inset(_cultist_zone, _cultist_portrait),
		},
		"patron": {
			"mode": "selected" if not _view["inspected_patron"].is_empty() else "empty",
			"name": _patron_name.text,
			"portrait_instance_id": _patron_portrait.get_instance_id(),
			"portrait_rect": _patron_portrait.get_rect(),
			"portrait_has_texture": _patron_portrait.texture != null,
			"name_rect": _patron_name.get_rect(),
			"name_below_portrait": _is_below(_patron_name, _patron_portrait),
			"content_left_inset": _left_inset(_patron_zone, _patron_portrait),
			"detail_visible": _patron_detail.visible,
			"close_visible": _patron_close.visible,
		},
		"night": {
			"clock_label": String(night["clock_label"]),
			"clock_minutes": _clock.clock_minutes(),
			"progress_ratio": float(night["progress_ratio"]),
			"time_scale": float(night["time_scale"]),
			"paused": bool(night["paused"]),
			"selected_speed": _selected_speed(),
			"pause_pressed": _pause_button.button_pressed,
			"content_left_inset": _left_inset(_night_zone, _clock_hover),
		},
		"settings_open": _settings_panel.visible,
		"developer_open": _developer_panel.visible,
		"pause_menu_open": _pause_menu.visible,
		"outcome_visible": _outcome_modal.visible,
		"outcome_title": _outcome_title.text,
		"outcome_actions": ["restart", "quit"] if _outcome_modal.visible else [],
		"hover_help": _hover_text,
		"feedback": _feedback_label.text if _feedback_panel.visible else "",
		"ui_scale": _ui_scale,
	}


## Screen rectangles nothing else may cover: the Bottom HUD, the Action Tile
## strip, an open menu, and an open modal.
func reserved_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append(_scaled_rect(_root.get_node("Frame") as Control))
	if _tiles_row.visible:
		rects.append(_scaled_rect(_tiles_row))
	for panel: Control in [_settings_panel, _developer_panel]:
		if panel.visible:
			rects.append(_scaled_rect(panel))
	if _pause_menu.visible or _outcome_modal.visible:
		rects.append(Rect2(Vector2.ZERO, _viewport_size()))
	return rects


## True while a modal blocks the Night. The world adapter stops advancing time
## and stops accepting world clicks while this holds.
func is_blocking() -> bool:
	return _outcome_modal.visible or _pause_menu.visible


# --- Intent rules ------------------------------------------------------------

func _emit(kind: StringName, payload: Dictionary) -> void:
	if (_outcome_modal.visible or _pause_menu.visible) and kind in TIME_INTENTS:
		return
	intent_submitted.emit(kind, payload)


# Escape closes the nearest transient interface first. Only when nothing
# transient is open does it reach the Pause Menu.
func _handle_escape() -> void:
	if _settings_panel.visible or _developer_panel.visible:
		_close_menus()
		return
	if _outcome_modal.visible:
		return
	if _pause_menu.visible:
		_emit(&"resume_night", {})
		return
	_emit(&"open_pause_menu", {})


func _cancel_tile(index: int) -> void:
	if index < 0 or index >= _tile_slots.size():
		return
	var data: Dictionary = _tile_slots[index]["data"]
	if data.is_empty() or not bool(data.get("cancellable", false)):
		return
	var action_id := int(data.get("id", -1))
	if bool(data.get("active", false)):
		_emit(&"cancel_active_action", {"action_id": action_id})
	else:
		_emit(&"remove_pending_action", {"action_id": action_id})


# Settings and Developer are mutually exclusive: opening one closes the other.
func _toggle_menu(panel: PanelContainer) -> void:
	var opening := not panel.visible
	_close_menus()
	if opening:
		panel.visible = true
		_menu_scrim.visible = true
		_root.move_child(_menu_scrim, -1)
		_root.move_child(panel, -1)
		_root.move_child(_hover_panel, -1)
		_anchor_menu(panel)
	_sync_utility_buttons()


func _close_menus() -> void:
	_settings_panel.visible = false
	_developer_panel.visible = false
	_menu_scrim.visible = false
	_sync_utility_buttons()


func _sync_utility_buttons() -> void:
	_settings_button.button_pressed = _settings_panel.visible
	_developer_button.button_pressed = _developer_panel.visible


# The popup keeps its own source button's edge, so it always reads as belonging
# to the control that opened it.
func _anchor_menu(panel: PanelContainer) -> void:
	var source: Control = (
		_settings_button if panel == _settings_panel else _developer_button
	)
	panel.reset_size()
	var anchor := Rect2(
		_to_root_local(source.get_global_position()), source.size
	)
	var view := _root.size
	var position := Vector2(
		clampf(anchor.end.x - panel.size.x, 8.0, maxf(8.0, view.x - panel.size.x - 8.0)),
		maxf(8.0, anchor.position.y - panel.size.y - 6.0)
	)
	panel.position = position


# --- Rendering ---------------------------------------------------------------

func _render_cultist() -> void:
	var cultist: Dictionary = _view["selected_cultist"]
	var has_cultist := not cultist.is_empty()
	_cultist_portrait.visible = has_cultist
	_cultist_name.text = String(cultist.get("name", "")) if has_cultist else "No Cultist"
	_cultist_activity.text = String(cultist.get("activity", "")) if has_cultist else ""
	_cultist_status.text = String(cultist.get("inspected_patron_status", ""))
	if has_cultist and cultist.get("portrait") != null:
		_cultist_portrait.texture = cultist["portrait"]
	_cultist_portrait.modulate = Color(cultist.get("tint", CREAM))


func _render_action_tiles() -> void:
	var tiles: Array = _view["action_tiles"]
	_tiles_row.visible = not _view["selected_cultist"].is_empty()
	for index in range(TILE_COUNT):
		var slot: Dictionary = _tile_slots[index]
		var data: Dictionary = tiles[index] if index < tiles.size() else {}
		slot["data"] = data
		var button := slot["button"] as Button
		var icon := slot["icon"] as TextureRect
		var fill := slot["fill"] as ColorRect
		var cancel := slot["cancel"] as Button
		var filled := not data.is_empty()
		var active := filled and bool(data.get("active", false))
		var style := _tile_style(filled, active)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		button.disabled = not filled
		icon.visible = filled
		if filled:
			icon.texture = _action_icon(StringName(data.get("icon", "")))
			icon.modulate = Color("FFF2C9") if active else Color("C9B986")
		var ratio: Variant = data.get("progress_ratio", null) if active else null
		fill.visible = ratio != null
		if ratio != null:
			_set_fill_ratio_vertical(fill, float(ratio))
		cancel.visible = filled and bool(data.get("cancellable", false))
		button.tooltip_text = (
			"%s · %s" % [data.get("label", ""), data.get("target_label", "")]
			if filled
			else ""
		)


func _render_night() -> void:
	var night: Dictionary = _view["night"]
	_clock.set_clock_minutes(float(night["clock_minutes"]))
	_set_fill_ratio_horizontal(_night_fill, float(night["progress_ratio"]))
	_night_track.tooltip_text = "Night %d%%" % int(round(float(night["progress_ratio"]) * 100.0))
	var paused := bool(night["paused"])
	var scale := float(night["time_scale"])
	_pause_button.button_pressed = paused
	for control: StringName in _speed_buttons:
		var button := _speed_buttons[control] as Button
		button.button_pressed = not paused and is_equal_approx(scale, SPEED_CONTROLS[control])
	_clock_hover.tooltip_text = "%s · Closing %s · %s remaining" % [
		night["clock_label"], night["closing_label"], night["remaining_label"],
	]


func _render_patron() -> void:
	var patron: Dictionary = _view["inspected_patron"]
	var selected := not patron.is_empty()
	_patron_detail.visible = selected
	_patron_close.visible = selected
	_patron_name.text = String(patron.get("name", "")) if selected else "No patron selected"
	_patron_portrait.texture = (
		patron.get("portrait") as Texture2D
		if selected and patron.get("portrait") != null
		else EMPTY_PATRON_TEXTURE
	)
	_patron_portrait.modulate = (
		Color(patron.get("tint", CREAM)) if selected else Color(INK, 0.28)
	)
	if not selected:
		return
	_patron_activity.text = String(patron.get("visible_activity", ""))
	_render_meter(&"mood", MOOD_BANDS, String(patron.get("mood", "")), Color("4B986D"))
	_render_meter(
		&"suspicion", SUSPICION_BANDS, String(patron.get("suspicion_band", "")), DANGER
	)
	_render_meter(
		&"intoxication", INTOXICATION_BANDS, String(patron.get("intoxication", "")),
		Color("B78C4E")
	)


func _render_meter(key: StringName, bands: Dictionary, band: String, color: Color) -> void:
	var meter: Dictionary = _patron_meters[key]
	var fill := meter["fill"] as ColorRect
	fill.color = color
	_set_fill_ratio_horizontal(fill, float(bands.get(band, 0.0)))
	var label := meter["label"] as Label
	label.text = band
	(meter["track"] as Control).tooltip_text = "%s: %s" % [
		String(key).capitalize(), band if not band.is_empty() else "Unknown",
	]


# One short line, above the HUD, for something the player asked for that the
# Night refused. It is presentation only and fades out on its own.
func _render_feedback() -> void:
	var feedback: Dictionary = _view["feedback"]
	var serial := int(feedback.get("serial", 0))
	if serial == _feedback_serial:
		return
	_feedback_serial = serial
	var text := String(feedback.get("text", ""))
	if text.is_empty():
		_feedback_panel.visible = false
		return
	_feedback_label.text = text
	_feedback_panel.reset_size()
	_feedback_panel.position = Vector2(
		(_root.size.x - _feedback_panel.size.x) * 0.5,
		_root.size.y - HUD_HEIGHT - _feedback_panel.size.y - 10.0
	)
	_feedback_panel.visible = true
	_feedback_remaining = FEEDBACK_SECONDS
	set_process(true)


func _process(delta: float) -> void:
	if _feedback_remaining <= 0.0:
		set_process(false)
		return
	_feedback_remaining -= delta
	if _feedback_remaining <= 0.0:
		_feedback_panel.visible = false
		set_process(false)


func _render_menus() -> void:
	_build_developer_menu()
	var developer: Dictionary = _view["developer"]
	var settings: Dictionary = _view["settings"]
	if _developer_built:
		for scenario_id: String in _scenario_buttons:
			(_scenario_buttons[scenario_id] as Button).button_pressed = (
				scenario_id == String(developer["scenario_id"])
			)
		_debug_toggle.button_pressed = bool(developer["visible"])
	_emote_toggle.button_pressed = bool(settings["emote_labels"])
	_reduced_motion_toggle.button_pressed = bool(settings["reduced_motion"])
	for step: float in _ui_scale_buttons:
		(_ui_scale_buttons[step] as Button).button_pressed = is_equal_approx(
			step, float(settings["ui_scale"])
		)


func _render_pause_menu() -> void:
	_pause_menu.visible = bool(_view["pause_menu_open"]) and not _outcome_modal_wanted()


func _render_outcome() -> void:
	var outcome: Dictionary = _view["outcome"]
	var visible := bool(outcome["visible"])
	_outcome_modal.visible = visible
	if not visible:
		return
	_outcome_title.text = _outcome_title_for(StringName(outcome["kind"]))
	_outcome_cause.text = String(outcome.get("cause", ""))
	var captures := int(outcome["captures"])
	var quota := int(outcome["capture_quota"])
	_outcome_quota.text = "Captures %d / %d" % [captures, quota]
	_set_fill_ratio_horizontal(_outcome_fill, float(outcome["progress_ratio"]))
	_outcome_fill.get_parent().tooltip_text = "Capture quota: %d of %d" % [captures, quota]


func _outcome_modal_wanted() -> bool:
	return bool(_view["outcome"]["visible"])


func _outcome_title_for(kind: StringName) -> String:
	match kind:
		&"victory":
			return "Success"
		&"exposed":
			return "Exposed"
	return "Operation Failed"


func _selected_speed() -> float:
	for control: StringName in _speed_buttons:
		if (_speed_buttons[control] as Button).button_pressed:
			return SPEED_CONTROLS[control]
	return 0.0


# --- Construction ------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = THEME
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = _viewport_size()
	add_child(_root)
	get_viewport().size_changed.connect(_on_viewport_resized)

	_build_action_tiles()
	_build_frame()
	_build_menus()
	_build_pause_menu()
	_build_outcome_modal()
	_build_hover_help()
	_build_feedback_line()
	_close_menus()
	set_process(false)


func _build_frame() -> void:
	var frame := Control.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	frame.offset_top = -HUD_HEIGHT
	frame.offset_bottom = 0.0
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(frame)

	var wood := TextureRect.new()
	wood.texture = WOOD_TEXTURE
	wood.stretch_mode = TextureRect.STRETCH_TILE
	wood.set_anchors_preset(Control.PRESET_FULL_RECT)
	wood.modulate = Color(0.88, 0.8, 0.72)
	wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(wood)

	var ridge := ColorRect.new()
	ridge.color = BRASS
	ridge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ridge.offset_bottom = 5.0
	ridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(ridge)

	var inset := MarginContainer.new()
	inset.set_anchors_preset(Control.PRESET_FULL_RECT)
	inset.add_theme_constant_override("margin_left", 14)
	inset.add_theme_constant_override("margin_right", 14)
	inset.add_theme_constant_override("margin_top", 10)
	inset.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(inset)

	var folio := PanelContainer.new()
	folio.add_theme_stylebox_override("panel", _folio_style())
	inset.add_child(folio)

	var zones := HBoxContainer.new()
	zones.add_theme_constant_override("separation", 12)
	folio.add_child(zones)

	zones.add_child(_build_cultist_zone())
	zones.add_child(_build_night_zone())
	zones.add_child(_build_patron_zone())
	zones.add_child(_build_utilities())


func _build_cultist_zone() -> Control:
	var panel := PanelContainer.new()
	_cultist_zone = panel
	panel.name = "CultistZone"
	panel.add_theme_stylebox_override("panel", _paper_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(_side_gutter(row, CULTIST_SIDE_GUTTER))

	_cultist_portrait = _portrait()
	_cultist_name = _portrait_caption("Vera")
	_cultist_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_cultist_name.custom_minimum_size = Vector2(0.0, PORTRAIT_CAPTION_HEIGHT)
	row.add_child(_portrait_stack(_cultist_portrait, _cultist_name))

	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	row.add_child(copy)
	_cultist_activity = _ink_label("", 14)
	_cultist_activity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_cultist_activity)
	_cultist_status = _ink_label("", 12)
	_cultist_status.add_theme_color_override("font_color", Color("60442A"))
	copy.add_child(_cultist_status)
	return panel


func _build_night_zone() -> Control:
	var panel := PanelContainer.new()
	_night_zone = panel
	panel.name = "NightZone"
	panel.add_theme_stylebox_override("panel", _time_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.35

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 5)
	panel.add_child(_side_gutter(column, NIGHT_SIDE_GUTTER))

	var clock_row := HBoxContainer.new()
	clock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_row.add_theme_constant_override("separation", 12)
	column.add_child(clock_row)

	_clock_hover = Control.new()
	_clock_hover.custom_minimum_size = Vector2(CLOCK_SIZE, CLOCK_SIZE)
	_clock_hover.mouse_filter = Control.MOUSE_FILTER_STOP
	clock_row.add_child(_clock_hover)
	_clock = NIGHT_CLOCK_SCRIPT.new() as NightClock
	_clock.name = "NightClock"
	_clock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_hover.add_child(_clock)
	_connect_hover(_clock_hover, func() -> String:
		var night: Dictionary = _view["night"]
		return "%s   Closing %s   %s left" % [
			night["clock_label"], night["closing_label"], night["remaining_label"],
		]
	)

	var night_column := VBoxContainer.new()
	night_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	night_column.add_theme_constant_override("separation", 4)
	clock_row.add_child(night_column)
	night_column.add_child(_cream_label("Night", 12))
	_night_track = _track(24.0)
	_night_fill = _track_fill(_night_track, Color("4D996F"))
	night_column.add_child(_night_track)

	var playback := HBoxContainer.new()
	playback.alignment = BoxContainer.ALIGNMENT_CENTER
	playback.add_theme_constant_override("separation", 5)
	column.add_child(playback)
	_pause_button = _icon_button("pause", "Pause the Night (Space)")
	_pause_button.custom_minimum_size = Vector2(36.0, PLAYBACK_HEIGHT)
	_pause_button.toggle_mode = true
	_pause_button.pressed.connect(func() -> void: activate(&"toggle_pause"))
	playback.add_child(_pause_button)
	var hints := {&"speed_1": "1", &"speed_2": "2", &"speed_4": "3"}
	var labels := {&"speed_1": "Normal speed (1)", &"speed_2": "Double speed (2)", &"speed_4": "Four times speed (3)"}
	for control: StringName in [&"speed_1", &"speed_2", &"speed_4"]:
		var button := Button.new()
		button.text = hints[control]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(32.0, PLAYBACK_HEIGHT)
		button.tooltip_text = labels[control]
		button.pressed.connect(func() -> void: activate(control))
		_connect_hover(button, func() -> String: return labels[control])
		_speed_buttons[control] = button
		playback.add_child(button)
	return panel


func _build_patron_zone() -> Control:
	var panel := PanelContainer.new()
	_patron_zone = panel
	panel.name = "PatronZone"
	panel.add_theme_stylebox_override("panel", _paper_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.15

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	# One portrait control serves both states, so the empty portrait and a real
	# Patron portrait always occupy the same rectangle.
	_patron_portrait = _portrait()
	_patron_name = _portrait_caption("No patron selected")
	_patron_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_patron_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_patron_name.custom_minimum_size = Vector2(
		PORTRAIT_SIZE.x + 24.0, PORTRAIT_CAPTION_HEIGHT
	)
	row.add_child(_portrait_stack(_patron_portrait, _patron_name))

	_patron_detail = VBoxContainer.new()
	_patron_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_patron_detail.alignment = BoxContainer.ALIGNMENT_CENTER
	_patron_detail.add_theme_constant_override("separation", 3)
	row.add_child(_patron_detail)

	var header := HBoxContainer.new()
	_patron_detail.add_child(header)
	_patron_activity = _ink_label("", 13)
	_patron_activity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_patron_activity)
	_patron_close = _icon_button("close", "Clear the Inspected Patron")
	_patron_close.custom_minimum_size = Vector2(44.0, 36.0)
	_patron_close.expand_icon = false
	_patron_close.pressed.connect(func() -> void: activate(&"close_patron"))
	header.add_child(_patron_close)

	for key: StringName in [&"mood", &"suspicion", &"intoxication"]:
		_patron_detail.add_child(_build_meter(key))
	return panel


func _build_meter(key: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = _icon(String(key))
	icon.custom_minimum_size = Vector2(16.0, 16.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = INK
	icon.tooltip_text = String(key).capitalize()
	row.add_child(icon)
	var track := _track(18.0)
	var fill := _track_fill(track, GREEN)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(label)
	row.add_child(track)
	_patron_meters[key] = {"track": track, "fill": fill, "label": label}
	return row


func _build_utilities() -> Control:
	var column := VBoxContainer.new()
	column.name = "Utilities"
	column.custom_minimum_size = Vector2(UTILITY_WIDTH, 0.0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 6)
	_settings_button = _icon_button("settings", "Settings")
	_settings_button.toggle_mode = true
	_settings_button.custom_minimum_size = Vector2(UTILITY_WIDTH - 8.0, 30.0)
	_settings_button.pressed.connect(func() -> void: activate(&"settings_menu"))
	column.add_child(_settings_button)
	_developer_button = _icon_button("developer", "Developer tools")
	_developer_button.toggle_mode = true
	_developer_button.custom_minimum_size = Vector2(UTILITY_WIDTH - 8.0, 30.0)
	_developer_button.pressed.connect(func() -> void: activate(&"developer_menu"))
	column.add_child(_developer_button)
	return column


func _build_action_tiles() -> void:
	_tiles_row = HBoxContainer.new()
	_tiles_row.name = "ActionTiles"
	_tiles_row.add_theme_constant_override("separation", int(TILE_GAP))
	_tiles_row.position = Vector2(
		TILES_LEFT, _root.size.y - HUD_HEIGHT - TILE_SIZE - TILES_BOTTOM_GAP
	)
	_root.add_child(_tiles_row)
	for index in range(TILE_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		button.focus_mode = Control.FOCUS_NONE
		_tiles_row.add_child(button)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 12.0
		icon.offset_top = 12.0
		icon.offset_right = -12.0
		icon.offset_bottom = -12.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = Color(0.212, 0.439, 0.333, 0.72)
		fill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(fill)
		button.add_child(icon)
		var cancel := _icon_button("close", "Cancel this Action")
		cancel.custom_minimum_size = Vector2(20.0, 20.0)
		cancel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cancel.offset_left = -20.0
		cancel.offset_top = 0.0
		cancel.offset_right = 0.0
		cancel.offset_bottom = 20.0
		# The corner affordance drops the theme's button padding so the mark itself
		# stays large enough to read and to hit.
		for state: String in ["normal", "hover", "pressed"]:
			cancel.add_theme_stylebox_override(state, _corner_style(state == "hover"))
		cancel.pressed.connect(func() -> void: activate(&"cancel_tile", {"index": index}))
		button.add_child(cancel)
		_connect_hover(button, func() -> String:
			var data: Dictionary = _tile_slots[index]["data"]
			if data.is_empty():
				return ""
			return "%s · %s" % [data.get("label", ""), data.get("target_label", "")]
		)
		_tile_slots.append({
			"button": button, "icon": icon, "fill": fill, "cancel": cancel, "data": {},
		})


func _build_menus() -> void:
	_menu_scrim = Control.new()
	_menu_scrim.name = "MenuScrim"
	_menu_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_menus()
	)
	_root.add_child(_menu_scrim)

	_settings_panel = _menu_panel("Settings")
	_developer_panel = _menu_panel("Developer tools")
	_build_settings_menu()


func _menu_panel(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _menu_style())
	panel.visible = false
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	column.add_child(_cream_label(title, 13))
	return panel


func _menu_column(panel: PanelContainer) -> VBoxContainer:
	return panel.get_node("Column") as VBoxContainer


func _build_settings_menu() -> void:
	var column := _menu_column(_settings_panel)
	_emote_toggle = _menu_toggle("Emote text labels", func(pressed: bool) -> void:
		activate(&"set_emote_labels", {"enabled": pressed})
	)
	column.add_child(_emote_toggle)
	column.add_child(_cream_label("UI scale", 12))
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 4)
	column.add_child(scale_row)
	for step: float in UI_SCALE_STEPS:
		var button := Button.new()
		button.text = "%d%%" % int(round(step * 100.0))
		button.toggle_mode = true
		button.pressed.connect(func() -> void: activate(&"set_ui_scale", {"scale": step}))
		_ui_scale_buttons[step] = button
		scale_row.add_child(button)
	_reduced_motion_toggle = _menu_toggle("Reduced motion", func(pressed: bool) -> void:
		activate(&"set_reduced_motion", {"enabled": pressed})
	)
	column.add_child(_reduced_motion_toggle)


# The developer menu is built once, from the scenario list the first render
# carries, so a scenario set defined by the world adapter needs no HUD change.
func _build_developer_menu() -> void:
	if _developer_built:
		return
	var scenarios: Array = _view["developer"]["scenarios"]
	if scenarios.is_empty():
		return
	_developer_built = true
	var column := _menu_column(_developer_panel)
	var scenarios_grid := GridContainer.new()
	scenarios_grid.columns = 2
	scenarios_grid.add_theme_constant_override("h_separation", 5)
	scenarios_grid.add_theme_constant_override("v_separation", 5)
	column.add_child(scenarios_grid)
	for entry: Dictionary in scenarios:
		var scenario_id := String(entry["id"])
		var button := Button.new()
		button.text = String(entry["label"])
		button.toggle_mode = true
		button.pressed.connect(func() -> void:
			activate(&"scenario", {"scenario_id": scenario_id})
		)
		_scenario_buttons[scenario_id] = button
		button.custom_minimum_size = Vector2(132.0, 30.0)
		scenarios_grid.add_child(button)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 4)
	column.add_child(steps)
	for seconds: float in [1.0, 5.0]:
		var button := Button.new()
		button.text = "+%ds" % int(seconds)
		button.pressed.connect(func() -> void:
			activate(&"debug_step", {"seconds": seconds})
		)
		steps.add_child(button)
	_debug_toggle = _menu_toggle("Debug overlay", func(pressed: bool) -> void:
		activate(&"set_debug_visible", {"enabled": pressed})
	)
	column.add_child(_debug_toggle)
	var restart := Button.new()
	restart.text = "Restart scenario"
	restart.pressed.connect(func() -> void: activate(&"restart_scenario"))
	column.add_child(restart)


func _menu_toggle(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.pressed.connect(func() -> void: handler.call(button.button_pressed))
	return button


func _build_pause_menu() -> void:
	_pause_menu = _modal_root("PauseMenu")
	var column := _pause_menu.get_node("Panel/Column") as VBoxContainer
	column.add_child(_cream_label("Night paused", 22))
	for entry: Array in [
		["Resume", &"resume", "play"],
		["Restart", &"restart", "restart"],
		["Settings", &"settings_menu", "settings"],
		["Quit", &"quit", "quit"],
	]:
		var control: StringName = entry[1]
		var button := Button.new()
		button.text = entry[0]
		button.icon = _icon(entry[2])
		button.custom_minimum_size = Vector2(180.0, 34.0)
		button.pressed.connect(func() -> void: activate(control))
		column.add_child(button)


func _build_outcome_modal() -> void:
	_outcome_modal = _modal_root("OutcomeModal")
	var column := _outcome_modal.get_node("Panel/Column") as VBoxContainer
	_outcome_title = _cream_label("Operation Failed", 26)
	column.add_child(_outcome_title)
	_outcome_cause = _cream_label("", 14)
	_outcome_cause.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome_cause.custom_minimum_size = Vector2(320.0, 0.0)
	column.add_child(_outcome_cause)
	_outcome_quota = _cream_label("Captures 0 / 3", 13)
	column.add_child(_outcome_quota)
	var track := _track(26.0)
	_outcome_fill = _track_fill(track, Color("4D996F"))
	column.add_child(track)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for entry: Array in [["Restart", &"restart", "restart"], ["Quit", &"quit", "quit"]]:
		var control: StringName = entry[1]
		var button := Button.new()
		button.text = entry[0]
		button.icon = _icon(entry[2])
		button.custom_minimum_size = Vector2(140.0, 34.0)
		button.pressed.connect(func() -> void: activate(control))
		row.add_child(button)


func _modal_root(node_name: String) -> Control:
	var root := Control.new()
	root.name = node_name
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	_root.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _menu_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return root


func _build_hover_help() -> void:
	_hover_panel = PanelContainer.new()
	_hover_panel.name = "HoverHelp"
	_hover_panel.visible = false
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_theme_stylebox_override("panel", _menu_style())
	_root.add_child(_hover_panel)
	_hover_label = _cream_label("", 12)
	_hover_panel.add_child(_hover_label)


func _build_feedback_line() -> void:
	_feedback_panel = PanelContainer.new()
	_feedback_panel.name = "Feedback"
	_feedback_panel.visible = false
	_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_panel.add_theme_stylebox_override("panel", _menu_style())
	_root.add_child(_feedback_panel)
	_feedback_label = _cream_label("", 13)
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_panel.add_child(_feedback_label)


# --- Small builders ----------------------------------------------------------

func _portrait() -> TextureRect:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait


func _side_gutter(content: Control, size: int) -> MarginContainer:
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_left", size)
	gutter.add_theme_constant_override("margin_right", size)
	gutter.add_child(content)
	return gutter


func _portrait_stack(portrait: TextureRect, caption: Label) -> Control:
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 3)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _portrait_style())
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_child(portrait)
	stack.add_child(frame)
	stack.add_child(caption)
	return stack


func _portrait_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK)
	return label


func _ink_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label


func _cream_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CREAM)
	return label


func _icon_button(icon_name: String, help: String) -> Button:
	var button := Button.new()
	button.icon = _icon(icon_name)
	button.tooltip_text = help
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	_connect_hover(button, func() -> String: return help)
	return button


# A thick progress track. The fill is a child anchored inside it, so its width
# follows the track at every HUD scale without a resize handler.
func _track(height: float) -> Control:
	var track := Control.new()
	track.custom_minimum_size = Vector2(0.0, height)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := PanelContainer.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", _track_style())
	track.add_child(background)
	return track


func _track_fill(track: Control, color: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 3.0
	fill.offset_top = 3.0
	fill.offset_right = 3.0
	fill.offset_bottom = -3.0
	track.add_child(fill)
	return fill


func _connect_hover(control: Control, text_source: Callable) -> void:
	control.mouse_entered.connect(func() -> void: _show_hover(control, text_source.call()))
	control.mouse_exited.connect(_hide_hover)


func _show_hover(control: Control, text: String) -> void:
	_hover_text = text
	if text.is_empty():
		_hover_panel.visible = false
		return
	_hover_label.text = text
	_hover_panel.reset_size()
	var anchor := Rect2(_to_root_local(control.get_global_position()), control.size)
	_hover_panel.position = Vector2(
		clampf(anchor.get_center().x - _hover_panel.size.x * 0.5, 8.0,
			maxf(8.0, _root.size.x - _hover_panel.size.x - 8.0)),
		maxf(8.0, anchor.position.y - _hover_panel.size.y - 6.0)
	)
	_hover_panel.visible = true


func _hide_hover() -> void:
	_hover_text = ""
	_hover_panel.visible = false


func _bind_press_feedback() -> void:
	for node: Node in _root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.has_meta("folio_press_feedback"):
			continue
		button.set_meta("folio_press_feedback", true)
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))


func _on_button_down(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	if not bool(_view["settings"]["reduced_motion"]):
		button.scale = Vector2(0.97, 0.97)


func _on_button_up(button: Button) -> void:
	button.scale = Vector2.ONE


# --- Styles ------------------------------------------------------------------

func _folio_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GREEN
	style.border_color = DARK_FOLIO
	style.set_border_width_all(3)
	style.set_content_margin_all(6)
	return style


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = WOOD
	style.set_border_width_all(3)
	style.set_content_margin_all(7)
	return style


func _time_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("24150C")
	style.border_color = BRASS
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 1
	style.border_width_right = 1
	style.set_content_margin_all(6)
	return style


func _menu_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1B3F2D")
	style.border_color = BRASS
	style.set_border_width_all(3)
	style.set_content_margin_all(10)
	return style


func _portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("D8C58F")
	style.border_color = WOOD
	style.set_border_width_all(4)
	style.set_content_margin_all(2)
	return style


func _track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102B1E")
	style.border_color = WOOD
	style.set_border_width_all(3)
	return style


func _corner_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DANGER if highlighted else Color(0.21, 0.14, 0.09, 0.9)
	style.border_color = BRASS
	style.set_border_width_all(1)
	style.set_content_margin_all(2)
	return style


# Action Tiles are square and carry no horizontal drop shadow: only the border
# and the fill separate an active tile from a pending or empty one.
func _tile_style(filled: bool, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2E190E") if filled else Color(0.16, 0.10, 0.06, 0.34)
	style.border_color = Color("BC8546") if active else (WOOD if filled else Color(0.42, 0.29, 0.16, 0.5))
	style.set_border_width_all(4 if filled else 2)
	style.set_content_margin_all(0)
	return style


# --- Layout helpers ----------------------------------------------------------

func _set_fill_ratio_horizontal(fill: ColorRect, ratio: float) -> void:
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_right = -3.0 if ratio > 0.0 else 3.0
	fill.visible = ratio > 0.0


func _set_fill_ratio_vertical(fill: ColorRect, ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	fill.anchor_left = 0.0
	fill.anchor_right = 1.0
	fill.anchor_top = 1.0 - clamped
	fill.anchor_bottom = 1.0
	fill.offset_left = 4.0
	fill.offset_top = 0.0
	fill.offset_right = -4.0
	fill.offset_bottom = -4.0


# UI scale keeps the HUD rooted to the bottom edge: the root shrinks by the same
# factor it is scaled up by, so anchored children still land on the screen edge.
func _apply_ui_scale(value: float) -> void:
	var scale := clampf(value, MIN_UI_SCALE, MAX_UI_SCALE)
	_ui_scale = scale
	_root.scale = Vector2(scale, scale)
	_root.position = Vector2.ZERO
	_root.size = _viewport_size() / scale
	_tiles_row.position = Vector2(
		TILES_LEFT, _root.size.y - HUD_HEIGHT - TILE_SIZE - TILES_BOTTOM_GAP
	)


func _on_viewport_resized() -> void:
	_apply_ui_scale(_ui_scale)


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(1280.0, 720.0)
	return viewport.get_visible_rect().size


func _scaled_rect(control: Control) -> Rect2:
	return Rect2(control.get_global_position(), control.size * _ui_scale)


# A global position is in screen pixels; a child of the scaled root needs the
# same point in the root's own coordinates.
func _to_root_local(point: Vector2) -> Vector2:
	return point / maxf(_ui_scale, 0.01)


func _is_below(label: Control, portrait: Control) -> bool:
	return label.get_global_rect().position.y >= portrait.get_global_rect().position.y


func _left_inset(panel: Control, content: Control) -> float:
	return content.get_global_rect().position.x - panel.get_global_rect().position.x


func _action_icon(icon_id: StringName) -> Texture2D:
	var name: String = COMMAND_ICONS.get(icon_id, FALLBACK_ACTION_ICON)
	var texture := _icon(name)
	return texture if texture != null else _icon(FALLBACK_ACTION_ICON)


func _icon(icon_name: String) -> Texture2D:
	var path := "%s%s.svg" % [ICON_DIRECTORY, icon_name]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# Fills in whatever the caller left out, so a partial view still renders.
func _merge_view(view: Dictionary) -> Dictionary:
	var merged := empty_view()
	for key: String in merged:
		if not view.has(key):
			continue
		var incoming: Variant = view[key]
		if merged[key] is Dictionary and incoming is Dictionary:
			var section: Dictionary = merged[key]
			for inner: String in incoming:
				section[inner] = incoming[inner]
			# A caller that means "nothing selected" passes an empty dictionary.
			if (incoming as Dictionary).is_empty():
				merged[key] = {}
		else:
			merged[key] = incoming
	return merged
