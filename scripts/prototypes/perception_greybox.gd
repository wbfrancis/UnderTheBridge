extends Node3D

# A greybox 3-D view over the perception sim. It is a pure view: it drives
# GameSession exactly like the perception_danger slice, then reads snapshot()
# and draws each Patron's room, position, facing, and Suspicion band in space.
# The HUD keeps the slice's scenario buttons so the panel reading and the spatial
# reading reinforce each other. Nothing in the sim is modified.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const PATRON_PERCEPTION_SCRIPT := preload("res://scripts/patrons/patron_perception.gd")
const MAIN_ROOM_PRESENTATION_SCRIPT := preload("res://scripts/presentation/main_room_presentation_prototype.gd")
const NAVIGABLE_ACTOR_SCRIPT := preload("res://scripts/navigation/navigable_actor_3d.gd")
const COMMAND_SYSTEM_SCRIPT := preload("res://scripts/actions/cultist_command_system.gd")
const AVATAR_MOTION_SCRIPT := preload("res://scripts/presentation/avatar_motion_controller.gd")
const NIGHT_PLAYBACK_SCRIPT := preload("res://scripts/presentation/night_playback.gd")
const EMOTE_DIRECTOR_SCRIPT := preload("res://scripts/presentation/emote_director.gd")
const EMOTE_OVERLAY_SCRIPT := preload("res://scripts/presentation/emote_overlay.gd")
const REVIEW_HARNESS_SCRIPT := preload("res://scripts/review/production_review_harness.gd")
const BOTTOM_HUD_SCENE: PackedScene = preload("res://scenes/ui/bottom_hud.tscn")
const NAVIGATION_MESH: NavigationMesh = preload(
	"res://assets/navigation/speakeasy_navigation.tres"
)
const BARTENDER_TEXTURE: Texture2D = preload("res://assets/characters/prototype_visual/Bartender.png")
const VISUAL_SPIKE_SOURCE := "res://assets/environment/prototype_visual/Speakeasy_VisualSpike.blend"
const VISUAL_SPIKE_EXPECTED_SHA256 := "a03beb87ab04e88460a7c6787dd8cd2f1dde0129bb0c03d2d9beab51f81dcc80"
const PATRON_IDS: Array[int] = [4, 5]
const ALL_PATRON_IDS: Array[int] = [
	4, 5, 6, 7,
	8, 9, 10, 11,
]
const CULTIST_IDS: Array[int] = [1, 2, 3]
const PLAYABLE_CULTIST_IDS: Array[int] = [1, 2]
const CULTIST_NAMES = ActorRoster.CULTIST_NAMES
const SETTINGS_PATH := "user://settings.cfg"
const CAMERA_FOCUS_SECONDS := 0.4
const SCENARIOS := {
	"night_start": "NIGHT START",
	"drink_cycle": "DRINK CYCLE",
	"full_cast": "FULL CAST",
	"service_wing": "SERVICE WING",
	"front_exit": "FRONT EXIT",
	"cultist_states": "CULTIST STATES",
	"line_of_sight": "LINE OF SIGHT",
	"room_hearing": "ROOM HEARING",
	"unattended_body": "UNATTENDED BODY",
	"companion": "COMPANION INFLUENCE",
	"debug_trace": "DEBUG TRACE",
}

# The six approved causal capture methods, in the order the Outcome report shows
# them. The keys are the simulation cause names; the values are the public labels.
const CAPTURE_METHOD_LABELS: Array[Array] = [
	[&"trapdoor", "Trapdoor"],
	[&"drugged_drink", "Drugged Drink"],
	[&"knockout", "Knockout"],
	[&"overdrink", "Overdrink"],
	[&"friendship_capture", "Friendship Capture"],
	[&"rescue_persuasion", "Rescue Persuasion"],
]

# Camera emulates the visual spike: a long lens from the bar side looking down the
# room's depth axis, so sim +x reads screen-right and every room stays in frame.
const CAMERA_POSITION := Vector3(3.0, 33.0, 33.0)
const CAMERA_TARGET := Vector3(3.0, 0.0, 6.0)
const CAMERA_FOV := 50.0
const PRESENTATION_CAMERA_POSITION := Vector3(0.0, 8.2, 34.0)
const PRESENTATION_CAMERA_TARGET := Vector3(0.0, 0.0, 3.0)
const PRESENTATION_CAMERA_FOV := 25.0
# The Service Wing and Front Exit presets recentre the main presentation camera,
# so their positions keep its exact angle (its target-to-position offset height of
# 8.2) instead of 10.0, which had drifted the view direction off the main angle.
const SERVICE_CAMERA_POSITION := Vector3(17.0, 9.2, 37.0)
const SERVICE_CAMERA_TARGET := Vector3(17.0, 1.0, 6.0)
const FRONT_CAMERA_POSITION := Vector3(-17.5, 9.2, 36.0)
const FRONT_CAMERA_TARGET := Vector3(-17.5, 1.0, 5.0)
# A close view framing the bathroom for the Trapdoor and Bathroom Visit review.
const BATHROOM_CAMERA_POSITION := Vector3(19.0, 7.6, 19.5)
const BATHROOM_CAMERA_TARGET := Vector3(19.2, 1.2, 6.0)
const CAMERA_PAN_SPEED := 16.0
const CAMERA_PAN_ACCELERATION := 48.0
const CAMERA_PAN_DECELERATION := 64.0
const TRACKPAD_PAN_HOLD_SECONDS := 0.08
const TRACKPAD_ZOOM_SENSITIVITY := 2.0
const ZOOM_SMOOTHNESS := 9.0
const CULTIST_VISIBLE_HEIGHT_METRES := 1.75
const BARTENDER_OPAQUE_HEIGHT_PIXELS := 35.0
const BARTENDER_FEET_FROM_CANVAS_CENTER_PIXELS := 16.0
# The fixed speed a rendered capture or a validation report drives the actors
# at. Ordinary play follows the Simulation Speed GameSession accepted.
const AUTOMATED_RUN_SCALE := 4.0
const NAVIGATION_FLOOR_Y := 0.18
const MAX_DESTINATION_SNAP_METERS := 1.5
# A Cultist is adjacent to a Patron once it stands within this distance of the
# Patron's live Approach Position. It follows the Cultist navigation arrival
# radius (0.38) with a small settle margin, so "reached" and "adjacent" agree.
const CULTIST_ADJACENCY_TOLERANCE := 0.55
# Trapdoor presentation. The hatch is a bounded area of the bathroom floor whose
# two panels hinge open, and a captured Patron sinks a bounded depth into the dark
# pit below so they are occluded by the floor and never appear below the stage.
const TRAPDOOR_HATCH_CENTER := Vector3(19.2, NAVIGATION_FLOOR_Y, 6.0)
const TRAPDOOR_PANEL_OPEN_DEGREES := 104.0
const TRAPDOOR_FALL_DEPTH := 2.6
# Authored smart targets. "pick" is the clickable volume, "approach" the floor
# point the Cultist walks to before the command commits.
const SMART_OBJECTS := {
	&"bar_work_position": {
		"label": "Bar Work Position",
		"approach": Vector3(0.0, NAVIGATION_FLOOR_Y, 1.62),
		"pick_center": Vector3(0.0, 0.9, 0.15),
		"pick_size": Vector3(12.0, 1.5, 1.5),
	},
	&"front_entrance": {
		"label": "Front Entrance",
		"approach": Vector3(-15.0, NAVIGATION_FLOOR_Y, 5.0),
		"pick_center": Vector3(-15.2, 1.0, 5.0),
		"pick_size": Vector3(1.2, 2.0, 3.4),
	},
	&"trapdoor_control": {
		"label": "Trapdoor Control",
		"approach": Vector3(7.2, NAVIGATION_FLOOR_Y, 1.62),
		"pick_center": Vector3(7.2, 0.95, 0.15),
		"pick_size": Vector3(1.6, 1.5, 0.9),
	},
	&"tunnel_intake": {
		"label": "Tunnel Intake",
		"approach": Vector3(15.0, NAVIGATION_FLOOR_Y, 6.0),
		"pick_center": Vector3(15.0, 0.7, 6.0),
		"pick_size": Vector3(2.2, 1.4, 2.4),
	},
}
const SMART_OBJECT_COLOR := Color("c9a86a")
const PATRON_COLORS := {
	4: Color("e3a57a"), 5: Color("7fc7c4"),
	6: Color("b79ad8"), 7: Color("d9c56f"),
	8: Color("83a9d8"), 9: Color("d8849d"),
	10: Color("94c77c"), 11: Color("d69a63"),
}
const PATRON_HEIGHT_SCALE := {
	4: 0.94, 5: 1.02, 6: 1.08,
	7: 0.98, 8: 1.12, 9: 0.9,
	10: 1.04, 11: 0.96,
}
const CULTIST_COLORS := {
	1: Color("efe1ce"), 2: Color("b9a0db"),
	3: Color("8fc4af"),
}
const CULTIST_POSITIONS := {
	1: Vector3(-3.6, 0.0, 1.45),
	2: Vector3(3.6, 0.0, 1.45),
	3: Vector3(3.6, 0.0, 1.45),
}

# The real perception rule values, read straight from the module so the drawn cone
# and rings match what the sim actually tests.
const VIEW_CONE_HALF_ANGLE := PATRON_PERCEPTION_SCRIPT.VIEW_CONE_HALF_ANGLE_DEGREES
const VIEW_RANGE := PATRON_PERCEPTION_SCRIPT.VIEW_RANGE_METRES
const COMPANION_RANGE := PATRON_PERCEPTION_SCRIPT.COMPANION_RANGE_METRES

const SEEN_COLOR := Color("55d6e6")
const UNSEEN_COLOR := Color("606b78")
const RAY_COLOR := Color("eef3f6")
const SOUND_COLOR := Color("4f8ae0")
const CONE_COLOR := Color("8fb6cf")
const COMPANION_RING_COLOR := Color("74c98d")

# Display-only room rectangles [min_x, min_z, max_x, max_z] in sim metres. They
# mirror the adjacency chain front — main_hall — hallway — bathroom so the
# room-hearing relationship is visible on the floor.
const ROOM_RECTS := {
	&"main_hall": [-14.0, -2.0, 13.0, 10.0],
	&"front": [-21.0, -2.0, -14.0, 12.0],
	&"hallway": [13.0, 3.0, 17.0, 9.0],
	&"bathroom": [17.0, 3.0, 21.0, 9.0],
}
const ROOM_COLORS := {
	&"main_hall": Color(0.16, 0.22, 0.28, 0.5),
	&"front": Color(0.24, 0.20, 0.14, 0.5),
	&"hallway": Color(0.18, 0.16, 0.24, 0.5),
	&"bathroom": Color(0.14, 0.22, 0.22, 0.5),
}
const SEAT_POSITIONS := {
	&"seat_01": Vector2(-12.0, 6.0), &"seat_02": Vector2(-10.5, 6.0),
	&"seat_03": Vector2(-6.0, 6.0), &"seat_04": Vector2(-4.5, 6.0),
	&"seat_05": Vector2(4.5, 6.0), &"seat_06": Vector2(6.0, 6.0),
	&"seat_07": Vector2(10.5, 6.0), &"seat_08": Vector2(12.0, 6.0),
}
const BAND_COLORS := {
	"Calm": Color("8fbf9f"), "Uneasy": Color("d3be76"), "Suspicious": Color("df9d65"),
	"Alarmed": Color("df745f"), "Maximum": Color("e65c70"),
}
const AVOIDANCE_SCRIPT := preload("res://scripts/navigation/character_avoidance_system.gd")

var _session = GAME_SESSION_SCRIPT.new()
@export var review_presentation: bool = false
@export var review_closeup: bool = false
@export var review_stage: String = "line_of_sight"
@export var review_debug_visible: bool = true
var _scenario: String = "line_of_sight"
var _scenario_trace: String = ""
var _debug_visible: bool = true
var _capture_mode: bool = false
var _presentation_prototype: bool = false
var _presentation_closeup: bool = false
var _patron_nodes: Dictionary = {}
var _patron_visual_targets: Dictionary = {}
var _next_patron_move_id := 1
var _latest_state: Dictionary = {}
var _cultist_nodes: Dictionary = {}
var _commands = COMMAND_SYSTEM_SCRIPT.new()
var _character_avoidance = AVOIDANCE_SCRIPT.new()
var _review_harness = REVIEW_HARNESS_SCRIPT.new()
var _playback = NIGHT_PLAYBACK_SCRIPT.new()
var _smart_object_root: Node3D
var _smart_object_plates: Dictionary = {}
var _drink_root: Node3D
var _drink_nodes: Dictionary = {}
var _serve_target_drink_id: StringName = &""
var _serve_target_cultist_id: int = ActorIds.NO_ACTOR
var _serve_target_append := false
var _trapdoor_root: Node3D
var _trapdoor_left_hinge: Node3D
var _trapdoor_right_hinge: Node3D
var _trapdoor_open_amount: float = 0.0
var _context_menu: PanelContainer
var _context_menu_rows: VBoxContainer
var _context_menu_header: Label
var _entrance_indicator: Button
var _entrance_knock_player: AudioStreamPlayer
var _last_knock_group_id: StringName = &""
var _context_target: Dictionary = {}
var _context_append := false
var _refreshing := false
var _emotes = EMOTE_DIRECTOR_SCRIPT.new()
var _emote_overlay: EmoteOverlay
var _bottom_hud: BottomHud
var _debug_panel: PanelContainer
var _pause_menu_open := false
# The first-run Controls Card. `_controls_seen` persists once dismissed, so the
# blocking card appears once per installation; the Pause Menu can reopen it and
# the Developer menu can re-arm it.
var _controls_seen := false
var _controls_visible := false
var _controls_first_run := false
var _hud_preview_outcome: StringName = &""
var _hud_preview := ""
var _feedback_serial := 0
var _last_feedback := ""
var _accepted_time_scale := 0.0
var _focus_active := false
var _focus_from := Vector3.ZERO
var _focus_to := Vector3.ZERO
var _focus_elapsed := 0.0
var _emote_labels := false
var _emote_ui_scale := 1.0
var _emote_head_offset := 2.25
var _selected_cultist_id: int = 1
var _hovered_actor_id: int = ActorIds.NO_ACTOR
var _hovered_is_cultist := false
var _hovered_drink_id: StringName = &""
var _inspected_patron_id: int = ActorIds.NO_ACTOR
var _actor_root: Node3D
var _cultist_root: Node3D
var _move_marker_root: Node3D
var _navigation_region: NavigationRegion3D
var _navigation_ready := false
var _movement_feedback := "Select a Cultist, then right-click the floor to move. Hold Shift to queue."
var _command_report_path := ""
var _emote_report_path := ""
var _emote_play_scale := -1.0
var _context_menu_preview: StringName = &""
var _movement_report_path := ""
var _bathroom_report_path := ""
var _bathroom_review_mode := "capture"
var _movement_capture_path := ""
var _movement_validation_scale := 4.0
var _capture_navigation_enabled := false
var _body_root: Node3D
var _event_root: Node3D
var _camera: Camera3D
var _camera_target: Vector3 = PRESENTATION_CAMERA_TARGET
var _camera_fov_target: float = PRESENTATION_CAMERA_FOV
var _camera_pan_velocity := Vector3.ZERO
var _trackpad_pan_intent := Vector2.ZERO
var _trackpad_pan_hold_remaining := 0.0
var _staged_bodies: Array = []
var _events: Array = []
var _debug_label: RichTextLabel
var _hover_panel: PanelContainer
var _hover_label: RichTextLabel


func _ready() -> void:
	_presentation_closeup = review_closeup or _command_line_flag("--presentation-closeup")
	_presentation_prototype = review_presentation or _command_line_flag("--presentation-prototype") or _presentation_closeup
	_debug_visible = review_debug_visible
	_commands.reset(_session)
	_load_settings()
	_build_environment()
	_build_navigation_world()
	_build_hud()
	_session.snapshot_changed.connect(_refresh)
	_set_scenario(_command_line_value("--stage=", review_stage))
	var capture_path := _command_line_value("--capture=")
	var capture_frames := maxi(6, int(_command_line_value("--capture-frames=", "6")))
	_capture_navigation_enabled = not capture_path.is_empty() and capture_frames > 6
	var report_path := _command_line_value("--report=")
	_movement_report_path = _command_line_value("--movement-report=")
	_bathroom_report_path = _command_line_value("--bathroom-report=")
	_bathroom_review_mode = _command_line_value("--bathroom-mode=", "capture")
	_movement_capture_path = _command_line_value("--movement-capture=")
	_command_report_path = _command_line_value("--command-report=")
	_context_menu_preview = StringName(_command_line_value("--context-menu="))
	_emote_report_path = _command_line_value("--emote-report=")
	_emote_play_scale = float(_command_line_value("--emote-play=", "-1"))
	_set_emote_accessibility(
		_emote_labels or _command_line_flag("--emote-labels"),
		float(_command_line_value("--emote-scale=", str(_emote_ui_scale)))
	)
	_movement_validation_scale = clampf(
		float(_command_line_value("--movement-scale=", "4.0")), 1.0, 4.0
	)
	var identify_patron := int(_command_line_value("--identify-patron="))
	if identify_patron != ActorIds.NO_ACTOR:
		_session.begin_conversation(1, identify_patron)
		_session.end_conversation(1)
	var inspect_patron := int(_command_line_value("--inspect-patron="))
	if inspect_patron != ActorIds.NO_ACTOR:
		_inspected_patron_id = inspect_patron
		_refresh(_session.snapshot())
	_hud_preview = _command_line_value("--hud-preview=")
	var hover_actor := int(_command_line_value("--hover-actor="))
	if hover_actor != ActorIds.NO_ACTOR:
		_hovered_actor_id = hover_actor
		_hovered_is_cultist = hover_actor in CULTIST_IDS
		_hover_panel.position = Vector2(540.0, 210.0)
		_refresh_character_panels(_session.snapshot())
	if (
		not _movement_report_path.is_empty()
		or not _command_report_path.is_empty()
		or not _emote_report_path.is_empty()
		or not _bathroom_report_path.is_empty()
	):
		_capture_mode = true
	if not capture_path.is_empty():
		_capture_mode = true
		_capture_after_render.call_deferred(capture_path, capture_frames)
	elif not report_path.is_empty():
		_capture_mode = true
		_write_validation_report.call_deferred(report_path)
	if _presentation_prototype and not _capture_mode:
		_arm_first_run_controls()
	_bake_navigation_world.call_deferred()


func _process(delta: float) -> void:
	# GameSession applies the selected Simulation Speed itself, so the adapter
	# hands it plain real seconds. Pause is simply a 0x scale inside the session.
	if not _capture_mode:
		# The blocking Controls Card holds the Night until it is dismissed.
		if not _controls_visible:
			_commands.advance(delta * _session.current_time_scale())
			_session.advance(delta)
			_advance_step_aside(delta * _session.current_time_scale())
	elif not _command_report_path.is_empty():
		# Command validation uses the same scaled Action clock as interactive play.
		_commands.advance(delta * _session.current_time_scale())
		var active: Dictionary = _commands.snapshot()["cultists"][1]["active"]
		if not active.is_empty() and active["command"] in [
			&"knock_out", &"pick_up_body", &"intercept", &"lead_to_tunnel",
			&"rescue_persuasion", &"prepare_drugged_drink",
		]:
			_session.advance(delta)
	elif _capture_mode and _emote_play_scale > 0.0:
		# The rendered Emote review runs the Night at the requested speed so the
		# captured frame is a live one, not a frozen setup.
		_session.advance(delta * _emote_play_scale)
	_advance_emotes(delta)
	if _presentation_prototype and not _capture_mode:
		_advance_camera_focus(delta)
		_update_camera_pan(delta)
		if not is_equal_approx(_camera.fov, _camera_fov_target):
			var zoom_weight := 1.0 - exp(-ZOOM_SMOOTHNESS * delta)
			_camera.fov = lerpf(_camera.fov, _camera_fov_target, zoom_weight)


func _unhandled_input(event: InputEvent) -> void:
	if not _presentation_prototype or _capture_mode:
		return
	if _handle_hud_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if _bottom_hud != null and _bottom_hud.is_blocking():
		return
	if event is InputEventMouseMotion:
		_update_character_hover(event.position)
	elif event is InputEventPanGesture:
		if event.meta_pressed:
			_zoom_camera_smooth(event.delta.y * TRACKPAD_ZOOM_SENSITIVITY)
		else:
			_queue_trackpad_pan(event.delta)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_close_context_menu()
			_handle_character_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not _serve_target_drink_id.is_empty():
				_cancel_drink_targeting()
				get_viewport().set_input_as_handled()
				return
			_handle_right_click(event.position, event.shift_pressed)
		else:
			var wheel_pan := _wheel_pan_delta(event)
			if not wheel_pan.is_zero_approx():
				if event.meta_pressed:
					_zoom_camera_smooth(wheel_pan.y * TRACKPAD_ZOOM_SENSITIVITY)
				else:
					_queue_trackpad_pan(wheel_pan)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not _serve_target_drink_id.is_empty():
			_cancel_drink_targeting()
		elif event.keycode == KEY_EQUAL:
			_zoom_camera_smooth(-2.0)
		elif event.keycode == KEY_MINUS:
			_zoom_camera_smooth(2.0)


func _zoom_camera_smooth(fov_delta: float) -> void:
	_cancel_camera_focus()
	_camera_fov_target = clampf(_camera_fov_target + fov_delta, 20.0, 55.0)


func _queue_trackpad_pan(pan_delta: Vector2) -> void:
	_cancel_camera_focus()
	_trackpad_pan_intent = pan_delta.limit_length(1.0)
	_trackpad_pan_hold_remaining = TRACKPAD_PAN_HOLD_SECONDS


func _wheel_pan_delta(event: InputEventMouseButton) -> Vector2:
	var factor := maxf(event.factor, 1.0)
	match event.button_index:
		MOUSE_BUTTON_WHEEL_LEFT: return Vector2(-factor, 0.0)
		MOUSE_BUTTON_WHEEL_RIGHT: return Vector2(factor, 0.0)
		MOUSE_BUTTON_WHEEL_UP: return Vector2(0.0, -factor)
		MOUSE_BUTTON_WHEEL_DOWN: return Vector2(0.0, factor)
	return Vector2.ZERO


func _update_camera_pan(delta: float) -> void:
	var pan := Input.get_vector(
		"camera_pan_left", "camera_pan_right", "camera_pan_up", "camera_pan_down"
	)
	if pan.is_zero_approx() and _trackpad_pan_hold_remaining > 0.0:
		pan = _trackpad_pan_intent
	_trackpad_pan_hold_remaining = maxf(0.0, _trackpad_pan_hold_remaining - delta)
	if _trackpad_pan_hold_remaining <= 0.0:
		_trackpad_pan_intent = Vector2.ZERO
	if not pan.is_zero_approx():
		_cancel_camera_focus()
	var desired_velocity := Vector3(pan.x, 0.0, pan.y) * CAMERA_PAN_SPEED
	var acceleration := CAMERA_PAN_ACCELERATION if not pan.is_zero_approx() else CAMERA_PAN_DECELERATION
	_camera_pan_velocity = _camera_pan_velocity.move_toward(desired_velocity, acceleration * delta)
	if not _camera_pan_velocity.is_zero_approx():
		_pan_camera(_camera_pan_velocity * delta)


func _pan_camera(shift: Vector3) -> void:
	_camera.position += shift
	_camera_target += shift
	_camera.look_at(_camera_target, Vector3.UP)


# One pick for actors and authored smart objects. Anything on the pick layer wins
# over the floor plane behind it, so target clicks stay predictable.
func _pick_at(screen_position: Vector2) -> Dictionary:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + _camera.project_ray_normal(screen_position) * 250.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Object = hit["collider"]
	if collider.has_meta("smart_object_id"):
		var object_id := StringName(collider.get_meta("smart_object_id"))
		return {
			"kind": COMMAND_SYSTEM_SCRIPT.TARGET_OBJECT,
			"id": object_id,
			"is_cultist": false,
			"position": SMART_OBJECTS[object_id]["approach"],
		}
	if collider.has_meta("drink_id"):
		return {
			"kind": COMMAND_SYSTEM_SCRIPT.TARGET_DRINK,
			"id": StringName(collider.get_meta("drink_id")),
			"is_cultist": false,
			"position": (collider as Node3D).global_position,
		}
	if not collider.has_meta("actor_id") or not collider.has_meta("is_cultist"):
		return {}
	var actor_id := int(collider.get_meta("actor_id"))
	return {
		"kind": COMMAND_SYSTEM_SCRIPT.TARGET_CULTIST if bool(collider.get_meta("is_cultist")) else COMMAND_SYSTEM_SCRIPT.TARGET_PATRON,
		"id": actor_id,
		"is_cultist": bool(collider.get_meta("is_cultist")),
		"position": (collider as Node3D).global_position,
	}


func _character_at(screen_position: Vector2) -> Dictionary:
	var hit := _pick_at(screen_position)
	if hit.is_empty() or hit["kind"] not in [COMMAND_SYSTEM_SCRIPT.TARGET_PATRON, COMMAND_SYSTEM_SCRIPT.TARGET_CULTIST]:
		return {}
	return hit


func _handle_character_left_click(screen_position: Vector2) -> void:
	var character := _character_at(screen_position)
	if not _serve_target_drink_id.is_empty():
		if character.is_empty() or bool(character["is_cultist"]):
			return
		_issue_drink_service(character)
		return
	if character.is_empty():
		return
	if character["is_cultist"]:
		_select_cultist(character["id"])
	else:
		# Inspecting a Patron never changes the Selected Cultist.
		_inspected_patron_id = character["id"]
		_refresh_hud(_session.snapshot())


func _update_character_hover(screen_position: Vector2) -> void:
	var hit := _pick_at(screen_position)
	if not hit.is_empty() and StringName(hit.get("kind", &"")) == COMMAND_SYSTEM_SCRIPT.TARGET_DRINK:
		_hovered_actor_id = ActorIds.NO_ACTOR
		_hovered_drink_id = StringName(hit["id"])
		if _hover_panel != null:
			_hover_panel.position = screen_position + Vector2(16.0, 18.0)
		_refresh_character_panels(_session.snapshot())
		return
	_hovered_drink_id = &""
	var character := hit if not hit.is_empty() and hit.get("kind", &"") in [COMMAND_SYSTEM_SCRIPT.TARGET_PATRON, COMMAND_SYSTEM_SCRIPT.TARGET_CULTIST] else {}
	if character.is_empty():
		_hovered_actor_id = ActorIds.NO_ACTOR
		if _hover_panel != null:
			_hover_panel.visible = false
		return
	_hovered_actor_id = character["id"]
	_hovered_is_cultist = character["is_cultist"]
	if _hover_panel != null:
		_hover_panel.position = screen_position + Vector2(16.0, 18.0)
	_refresh_character_panels(_session.snapshot())


func _select_cultist(cultist_id: int) -> void:
	if not _cultist_nodes.has(cultist_id):
		return
	_selected_cultist_id = cultist_id
	_close_context_menu()
	for id: int in _cultist_nodes:
		var actor := _cultist_nodes[id] as NavigableActor3D
		actor.set_selected(id == cultist_id)
	_movement_feedback = "%s selected." % _cultist_display_name(cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


# Right-click precedence: an actor or authored object opens the context menu,
# empty reachable floor stays a direct Move unless a body is being dragged.
func _handle_right_click(screen_position: Vector2, append_to_queue: bool) -> void:
	if not _ready_for_commands():
		return
	var hit := _pick_at(screen_position)
	if not hit.is_empty() and (not bool(hit["is_cultist"]) or hit["id"] != _selected_cultist_id):
		_open_context_menu(screen_position, hit, append_to_queue)
		return
	if not hit.is_empty():
		# Clicking a Cultist selects them; it never issues a command to another.
		_close_context_menu()
		return
	var destination: Variant = _floor_destination(screen_position)
	if destination == null:
		_movement_feedback = "That floor destination is not reachable."
		_close_context_menu()
		_refresh_hud(_session.snapshot())
		return
	var floor_target := {
		"kind": COMMAND_SYSTEM_SCRIPT.TARGET_FLOOR,
		"id": &"floor",
		"position": destination,
	}
	if _session.command_availability(&"drop_body", _selected_cultist_id, &"floor")["available"]:
		_open_context_menu(screen_position, floor_target, append_to_queue)
		return
	_issue_command(&"move", floor_target, append_to_queue)


func _ready_for_commands() -> bool:
	if not _navigation_ready:
		_movement_feedback = "Navigation is not ready."
		return false
	if not _cultist_nodes.has(_selected_cultist_id):
		_movement_feedback = "Select a Cultist first."
		return false
	return true


func _issue_command(command: StringName, target: Dictionary, append_to_queue: bool) -> void:
	_close_context_menu()
	# The adapter contributes one geometry fact: is the Selected Cultist already
	# adjacent to a Patron target? The command seam decides what that means.
	var context: Dictionary = {}
	if StringName(target.get("kind", &"")) in [COMMAND_SYSTEM_SCRIPT.TARGET_PATRON, COMMAND_SYSTEM_SCRIPT.TARGET_CULTIST]:
		context["is_adjacent"] = _cultist_adjacent_to_actor(
			_selected_cultist_id, target["id"]
		)
	var outcome: Dictionary = _commands.issue(
		_selected_cultist_id, command, target, append_to_queue, context
	)
	_movement_feedback = outcome["message"]
	_sync_cultist_navigation(_selected_cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


# The live geometry fact the command seam asks for: whether the Cultist already
# stands at the Patron's valid Approach Position within the arrival tolerance.
func _cultist_adjacent_to_actor(cultist_id: int, target_id: Variant) -> bool:
	if not _cultist_nodes.has(cultist_id):
		return false
	var actor := _cultist_nodes[cultist_id] as NavigableActor3D
	var target_actor: NavigableActor3D = _patron_nodes.get(target_id, _cultist_nodes.get(target_id))
	if target_actor == null:
		return false
	var target_position := target_actor.global_position
	target_position.y = NAVIGATION_FLOOR_Y
	var approach := _patron_approach_point(target_position, actor.global_position)
	return actor.global_position.distance_to(approach) <= CULTIST_ADJACENCY_TOLERANCE


func _floor_destination(screen_position: Vector2) -> Variant:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	var floor_plane := Plane(Vector3.UP, NAVIGATION_FLOOR_Y)
	var intersection: Variant = floor_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null
	var raw_destination: Vector3 = intersection
	var navigation_map := get_world_3d().navigation_map
	var reachable := NavigationServer3D.map_get_closest_point(navigation_map, raw_destination)
	if raw_destination.distance_to(reachable) > MAX_DESTINATION_SNAP_METERS:
		return null
	return reachable


func _floor_target(destination: Vector3) -> Dictionary:
	return {
		"kind": COMMAND_SYSTEM_SCRIPT.TARGET_FLOOR,
		"id": &"floor",
		"position": destination,
	}


# --- Context menu ------------------------------------------------------------

func _open_context_menu(screen_position: Vector2, target: Dictionary, append_to_queue: bool) -> void:
	var is_drink := StringName(target.get("kind", &"")) == COMMAND_SYSTEM_SCRIPT.TARGET_DRINK
	var options: Array[Dictionary] = (
		_commands.resolve_drink_options(target["id"], _selected_cultist_id)
		if is_drink else _commands.resolve_options(_selected_cultist_id, target)
	)
	if options.is_empty():
		_close_context_menu()
		_movement_feedback = "No command applies to that target."
		_refresh_hud(_session.snapshot())
		return
	_context_target = target
	_context_append = append_to_queue
	for child in _context_menu_rows.get_children():
		child.queue_free()
	_context_menu_header.text = (
		"PREPARED DRINK"
		if is_drink else "%s  ·  %s" % [options[0]["target_label"], "APPEND" if append_to_queue else "REPLACE"]
	)
	for option: Dictionary in options:
		var button := Button.new()
		button.text = option["label"] if bool(option["available"]) else "%s  (%s)" % [
			option["label"], option["reason_label"],
		]
		button.disabled = not bool(option["available"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(228.0, 28.0)
		button.pressed.connect(_on_context_option_pressed.bind(StringName(option["command"])))
		_context_menu_rows.add_child(button)
	_context_menu.position = screen_position + Vector2(8.0, 8.0)
	_context_menu.visible = true


func _on_context_option_pressed(command: StringName) -> void:
	var target := _context_target
	var append := _context_append
	_close_context_menu()
	if target.is_empty():
		return
	if command == &"serve_drink_to":
		var cultist_id := _selected_cultist_id
		if cultist_id == ActorIds.NO_ACTOR:
			cultist_id = _nearest_available_cultist_to_bar()
		if cultist_id == ActorIds.NO_ACTOR:
			_movement_feedback = "No Cultist is available."
			_refresh_hud(_session.snapshot())
			return
		var drink_id: StringName = target["id"]
		if not _session.reserve_prepared_drink(drink_id, cultist_id):
			_movement_feedback = "That drink is no longer available."
			_refresh_hud(_session.snapshot())
			return
		_serve_target_drink_id = drink_id
		_serve_target_cultist_id = cultist_id
		_serve_target_append = Input.is_key_pressed(KEY_SHIFT)
		_movement_feedback = "Choose a Patron. Right-click or press Escape to cancel."
		_refresh_hud(_session.snapshot())
		return
	if command == &"dispose_drink":
		_commands.cancel_drink_service(target["id"])
		_session.dispose_prepared_drink(target["id"])
		_movement_feedback = "Drink disposed."
		_refresh_hud(_session.snapshot())
		return
	_issue_command(command, target, append)


func _issue_drink_service(patron_target: Dictionary) -> void:
	var cultist_id := _serve_target_cultist_id
	if cultist_id == ActorIds.NO_ACTOR:
		_movement_feedback = "No Cultist is available."
		_cancel_drink_targeting(false)
		return
	patron_target["bar_position"] = SMART_OBJECTS[&"bar_work_position"]["approach"]
	var result: Dictionary = _commands.issue_drink_service(
		cultist_id, _serve_target_drink_id, patron_target, _serve_target_append
	)
	_movement_feedback = result["message"]
	if not bool(result["accepted"]):
		_session.release_prepared_drink(_serve_target_drink_id, cultist_id)
	_clear_drink_targeting()
	_sync_cultist_navigation(cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


func _cancel_drink_targeting(show_message: bool = true) -> void:
	if show_message:
		_movement_feedback = "Drink service cancelled."
	if not _serve_target_drink_id.is_empty() and not _serve_target_cultist_id == ActorIds.NO_ACTOR:
		_session.release_prepared_drink(_serve_target_drink_id, _serve_target_cultist_id)
	_clear_drink_targeting()
	_refresh_hud(_session.snapshot())


func _clear_drink_targeting() -> void:
	_serve_target_drink_id = &""
	_serve_target_cultist_id = ActorIds.NO_ACTOR
	_serve_target_append = false


func _nearest_available_cultist_to_bar() -> int:
	var bar: Vector3 = SMART_OBJECTS[&"bar_work_position"]["approach"]
	var best := ActorIds.NO_ACTOR
	var best_distance := INF
	for cultist_id: int in PLAYABLE_CULTIST_IDS:
		if _session.cultist_is_incapacitated(cultist_id):
			continue
		if not _commands.active_request(cultist_id).is_empty() or _session.carries_prepared_drink(cultist_id):
			continue
		var distance := (_cultist_nodes[cultist_id] as Node3D).global_position.distance_to(bar)
		if distance < best_distance:
			best = cultist_id
			best_distance = distance
	return best


# Opens one context menu for the rendered review pass so the captured frame
# shows the real option list, mode header, and disabled reasons.
func _open_preview_context_menu() -> void:
	var target: Dictionary
	if SMART_OBJECTS.has(_context_menu_preview):
		target = _smart_target(_context_menu_preview)
	else:
		target = _actor_target(int(_context_menu_preview))
	_open_context_menu(Vector2(520.0, 300.0), target, false)


func _close_context_menu() -> void:
	if _context_menu == null:
		return
	_context_menu.visible = false
	_context_target = {}


# --- Navigation plumbing -----------------------------------------------------

func _advance_step_aside(simulated_delta: float) -> void:
	if simulated_delta <= 0.0 or not _navigation_ready:
		return
	var actors: Array[Dictionary] = []
	var queues: Dictionary = _commands.snapshot()["cultists"]
	for cultist_id: int in PLAYABLE_CULTIST_IDS:
		var actor := _cultist_nodes.get(cultist_id) as NavigableActor3D
		if actor == null:
			continue
		var active: Dictionary = queues[cultist_id]["active"]
		var priority := AVOIDANCE_SCRIPT.PRIORITY_IDLE if active.is_empty() else AVOIDANCE_SCRIPT.PRIORITY_PLAYER
		if _latest_state["cultists"][cultist_id]["activity"] == &"dragging":
			priority = AVOIDANCE_SCRIPT.PRIORITY_BODY
		actors.append({
			"id": cultist_id, "position": actor.global_position,
			"segment_end": actor.next_path_segment_end(),
			"action_id": actor.active_action_id(),
			"moving": actor.is_navigating() and active.get("command", &"") != &"step_aside",
			"can_yield": active.is_empty() and not _session.is_cultist_busy(cultist_id),
			"priority": priority,
		})
	for patron_id: int in _patron_nodes:
		var actor := _patron_nodes[patron_id] as NavigableActor3D
		var view: Dictionary = _latest_state["debug_patron_views"][patron_id]
		if not actor.visible:
			continue
		var activity := StringName(view["activity"])
		var priority := AVOIDANCE_SCRIPT.PRIORITY_IDLE
		if actor.is_navigating():
			priority = AVOIDANCE_SCRIPT.PRIORITY_PATRON
		if activity in [&"escaping", &"investigation_search", &"shock"]:
			priority = AVOIDANCE_SCRIPT.PRIORITY_DANGER
		elif activity in [&"helper_carrying", &"being_dragged"]:
			priority = AVOIDANCE_SCRIPT.PRIORITY_BODY
		actors.append({
			"id": patron_id, "position": actor.global_position,
			"segment_end": actor.next_path_segment_end(),
			"action_id": actor.active_action_id(),
			"moving": actor.is_navigating() and view["navigation_destination"] != &"step_aside",
			"can_yield": not actor.is_navigating() and view["lifecycle"] == &"active"
				and activity in [&"socializing", &"awaiting_drink", &"waiting_at_entrance"],
			"priority": priority,
		})
	for request: Dictionary in _character_avoidance.advance(simulated_delta, actors):
		var actor_id := int(request["actor_id"])
		var destination: Vector3 = request["position"]
		var navigation_map := get_world_3d().navigation_map
		var snapped := NavigationServer3D.map_get_closest_point(navigation_map, destination)
		if snapped.distance_to(destination) > 0.35:
			destination = request["alternate"]
			snapped = NavigationServer3D.map_get_closest_point(navigation_map, destination)
		if snapped.distance_to(destination) > 0.35:
			continue
		if _cultist_nodes.has(actor_id):
			if bool(_commands.issue_step_aside(actor_id, snapped, request["incident_id"])["accepted"]):
				_sync_cultist_navigation(actor_id)
		elif _session.request_patron_step_aside(actor_id, snapped, request["incident_id"]):
			_sync_patron_navigation(actor_id, _session.snapshot()["debug_patron_views"][actor_id])

func _sync_cultist_navigation(cultist_id: int) -> void:
	var actor := _cultist_nodes[cultist_id] as NavigableActor3D
	var request: Dictionary = _commands.active_request(cultist_id)
	if request.is_empty():
		actor.cancel_navigation()
		return
	# A Patron Action whose prerequisites finished asks for a proximity check, not
	# navigation: the Generated Move does the walking. The command seam either
	# commits the Action or inserts a Generated Move; the adapter never edits a chain.
	if StringName(request["mode"]) == &"check_proximity":
		_resolve_active_proximity(cultist_id, request)
		return
	var action_id: int = request["action_id"]
	var approach := _approach_position(request, actor.global_position)
	if actor.active_action_id() == action_id:
		# A Patron target moves, so re-aim once their approach point drifts away.
		if request["target_kind"] not in [COMMAND_SYSTEM_SCRIPT.TARGET_PATRON, COMMAND_SYSTEM_SCRIPT.TARGET_CULTIST]:
			return
		if actor.target_position().distance_to(approach) <= 0.6:
			return
	actor.navigate(action_id, approach)


# Reports the live proximity result for the active Patron Action and re-syncs
# once the command seam responds, so a commit advances to the next Action and an
# inserted Generated Move starts navigating in the same step.
func _resolve_active_proximity(cultist_id: int, request: Dictionary) -> void:
	var actor := _cultist_nodes[cultist_id] as NavigableActor3D
	actor.cancel_navigation()
	var approach := _approach_position(request, actor.global_position)
	var is_adjacent := actor.global_position.distance_to(approach) <= CULTIST_ADJACENCY_TOLERANCE
	var outcome: Dictionary = _commands.resolve_proximity(
		cultist_id, int(request["action_id"]), is_adjacent
	)
	if bool(outcome.get("changed", false)):
		_sync_cultist_navigation(cultist_id)


# A Patron target moves, so the approach point tracks their live position.
# Floor and object targets use the authored point they were issued with.
func _approach_position(request: Dictionary, from_position: Vector3) -> Vector3:
	var position: Vector3 = request["position"]
	position.y = NAVIGATION_FLOOR_Y
	var navigation_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return position
	if request["target_kind"] not in [COMMAND_SYSTEM_SCRIPT.TARGET_PATRON, COMMAND_SYSTEM_SCRIPT.TARGET_CULTIST]:
		return NavigationServer3D.map_get_closest_point(navigation_map, position)
	var target_id := int(request["target_id"])
	var target_actor: NavigableActor3D = _patron_nodes.get(target_id, _cultist_nodes.get(target_id))
	if target_actor != null:
		position = target_actor.global_position
		position.y = NAVIGATION_FLOOR_Y
	return _patron_approach_point(position, from_position)


# A seated Patron stands on a seat pad that navigation treats as an obstacle, and
# the strip behind a pad can be walled off. The Cultist takes the nearest spot
# beside the Patron that a real path can actually reach.
func _patron_approach_point(patron_position: Vector3, from_position: Vector3) -> Vector3:
	var navigation_map := get_world_3d().navigation_map
	var best := NavigationServer3D.map_get_closest_point(navigation_map, patron_position)
	var best_error := patron_position.distance_to(best)
	# Never the Patron's own spot: two actor radii keep the Cultist 0.68 m away,
	# so an approach point on top of the Patron can never be reached.
	var candidates: Array[Vector3] = []
	for radius in [1.1, 1.8]:
		for degrees in [270, 90, 180, 0, 225, 315, 135, 45]:
			var radians := deg_to_rad(float(degrees))
			candidates.append(
				patron_position + Vector3(cos(radians), 0.0, sin(radians)) * radius
			)
	for candidate: Vector3 in candidates:
		var snapped := NavigationServer3D.map_get_closest_point(navigation_map, candidate)
		var error := candidate.distance_to(snapped)
		if error < best_error:
			best = snapped
			best_error = error
		if error > 0.35:
			continue
		var path := NavigationServer3D.map_get_path(navigation_map, from_position, snapped, true)
		if path.size() > 0 and path[path.size() - 1].distance_to(snapped) <= 0.35:
			return snapped
	return best


func _on_cultist_destination_reached(cultist_id: int, action_id: int) -> void:
	var outcome: Dictionary = _commands.notify_reached(cultist_id, action_id)
	if not outcome.is_empty():
		_apply_command_feedback(cultist_id)
	_sync_cultist_navigation(cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


func _on_cultist_navigation_stuck(cultist_id: int, action_id: int) -> void:
	_commands.notify_failed(cultist_id, action_id, &"path_stuck")
	_apply_command_feedback(cultist_id)
	_sync_cultist_navigation(cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


func _apply_command_feedback(cultist_id: int) -> void:
	if cultist_id != _selected_cultist_id:
		return
	var cultists: Dictionary = _commands.snapshot()["cultists"]
	if cultists.has(cultist_id):
		_movement_feedback = cultists[cultist_id]["feedback"]["message"]


func _refresh_move_markers() -> void:
	if _move_marker_root == null:
		return
	for child in _move_marker_root.get_children():
		child.queue_free()
	var cultists: Dictionary = _commands.snapshot()["cultists"]
	if not cultists.has(_selected_cultist_id):
		return
	for entry: Dictionary in cultists[_selected_cultist_id]["markers"]:
		var marker := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.25
		cylinder.bottom_radius = 0.25
		cylinder.height = 0.04
		cylinder.material = _flat_material(CULTIST_COLORS[_selected_cultist_id], 0.85)
		marker.mesh = cylinder
		marker.position = (entry["position"] as Vector3) + Vector3(0.0, 0.04, 0.0)
		var label := Label3D.new()
		label.text = "%d %s" % [int(entry["index"]), entry["label"]]
		label.position.y = 0.12
		label.font_size = 28
		label.pixel_size = 0.006
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		marker.add_child(label)
		_move_marker_root.add_child(marker)


# --- Emote Bubbles -----------------------------------------------------------

# Presentation only. The director reads the sanitized emote_view, never the
# debug views, and transients use real seconds so 4x play stays readable.
func _advance_emotes(real_delta: float) -> void:
	if _emote_overlay == null:
		return
	_emotes.update(
		_session.emote_view(_commands.snapshot()["cultists"]),
		real_delta,
		is_zero_approx(_accepted_time_scale)
	)
	_emote_overlay.set_reserved_rects(_reserved_hud_rects())
	var bubbles: Array[Dictionary] = _emotes.bubbles()
	# The overlay names the actor in an Offscreen Indicator's accessible label,
	# so it needs the same player-readable name the HUD uses.
	for bubble: Dictionary in bubbles:
		bubble["display_name"] = _actor_display_name(bubble["actor_id"])
	_emote_overlay.refresh(bubbles, _emote_anchors())


func _emote_anchors() -> Dictionary:
	var anchors: Dictionary = {}
	for patron_id: int in _patron_nodes:
		var patron_pivot: Node3D = _patron_nodes[patron_id]
		if patron_pivot.visible:
			anchors[patron_id] = (
				patron_pivot.global_position + Vector3(0.0, _emote_head_offset, 0.0)
			)
	for cultist_id: int in _cultist_nodes:
		var cultist_pivot: Node3D = _cultist_nodes[cultist_id]
		anchors[cultist_id] = cultist_pivot.global_position + Vector3(0.0, _emote_head_offset, 0.0)
	return anchors


func _reserved_hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if _bottom_hud != null:
		rects.append_array(_bottom_hud.reserved_rects())
	for panel: Variant in [_hover_panel, _context_menu, _debug_panel]:
		var control: Control = panel as Control
		if control != null and control.visible:
			rects.append(Rect2(control.global_position, control.size))
	return rects


func _set_emote_accessibility(labels: bool, ui_scale: float) -> void:
	_emote_labels = labels
	_emote_ui_scale = clampf(ui_scale, 0.75, 1.5)
	if _emote_overlay != null:
		_emote_overlay.set_accessible_labels(_emote_labels)
		_emote_overlay.set_ui_scale(_emote_ui_scale)
		_advance_emotes(0.0)


func _cultist_display_name(cultist_id: int) -> String:
	return CULTIST_NAMES.get(cultist_id, str(cultist_id).replace("cultist_", "Cultist "))


func _actor_display_name(actor_id: int) -> String:
	if _cultist_nodes.has(actor_id):
		return _cultist_display_name(actor_id)
	var view: Dictionary = _session.patron_view(actor_id, _selected_cultist_id)
	return String(view["name"]) if not view.is_empty() else _humanize(actor_id)


# --- Camera focus ------------------------------------------------------------

# Pressing an Offscreen Indicator moves the camera to that actor. Manual pan,
# zoom, or another press replaces the move at once; it never bounces or
# overshoots.
func _focus_camera_on(actor_id: int) -> void:
	var node: Node3D = _cultist_nodes.get(actor_id, _patron_nodes.get(actor_id))
	if node == null:
		return
	var destination := Vector3(
		node.global_position.x, _camera_target.y, node.global_position.z
	)
	_cancel_camera_focus()
	_focus_from = _camera_target
	_focus_to = destination
	_focus_elapsed = 0.0
	_focus_active = true


func _focus_camera_on_entrance() -> void:
	_cancel_camera_focus()
	_focus_from = _camera_target
	var entrance: Vector3 = SMART_OBJECTS[&"front_entrance"]["approach"]
	_focus_to = Vector3(entrance.x, _camera_target.y, entrance.z)
	_focus_elapsed = 0.0
	_focus_active = true


func _advance_camera_focus(delta: float) -> void:
	if not _focus_active:
		return
	_focus_elapsed += delta
	var weight := clampf(_focus_elapsed / CAMERA_FOCUS_SECONDS, 0.0, 1.0)
	var eased := weight * weight * (3.0 - 2.0 * weight)
	_pan_camera(_focus_from.lerp(_focus_to, eased) - _camera_target)
	if weight >= 1.0:
		_focus_active = false


func _cancel_camera_focus() -> void:
	_focus_active = false


# --- World -------------------------------------------------------------------

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1016")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aeb7c5")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-62.0, -34.0, 0.0)
	key_light.light_color = Color("fff2df")
	key_light.light_energy = 0.9
	key_light.shadow_enabled = true
	add_child(key_light)

	var floor_instance := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 24.0)
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(3.0, 0.0, 7.0)
	floor_instance.material_override = _flat_material(Color("11161d"), 1.0)
	add_child(floor_instance)

	for room_id: StringName in ROOM_RECTS:
		add_child(_build_room_zone(room_id))

	# Bar counter box at the origin, and the eight seat pads.
	if _presentation_prototype:
		_add_presentation_prototype()
	else:
		add_child(_build_box(Vector2(0.0, 0.0), Vector3(6.0, 1.1, 1.4), 0.55, Color("3a2c22")))
	for seat_id: StringName in SEAT_POSITIONS:
		add_child(_build_box(SEAT_POSITIONS[seat_id], Vector3(0.9, 0.5, 0.9), 0.25, Color("223743")))

	_actor_root = Node3D.new()
	_actor_root.name = "Actors"
	add_child(_actor_root)
	_cultist_root = Node3D.new()
	_cultist_root.name = "Cultists"
	add_child(_cultist_root)
	_move_marker_root = Node3D.new()
	_move_marker_root.name = "MoveMarkers"
	add_child(_move_marker_root)
	_smart_object_root = Node3D.new()
	_smart_object_root.name = "SmartObjects"
	add_child(_smart_object_root)
	_build_smart_objects()
	_drink_root = Node3D.new()
	_drink_root.name = "PreparedDrinks"
	add_child(_drink_root)
	if _presentation_prototype:
		_build_trapdoor()
	_body_root = Node3D.new()
	_body_root.name = "Bodies"
	add_child(_body_root)
	_event_root = Node3D.new()
	_event_root.name = "DangerEvents"
	add_child(_event_root)

	_camera = Camera3D.new()
	_camera.position = PRESENTATION_CAMERA_POSITION if _presentation_prototype else CAMERA_POSITION
	_camera_target = PRESENTATION_CAMERA_TARGET if _presentation_prototype else CAMERA_TARGET
	_camera.fov = PRESENTATION_CAMERA_FOV if _presentation_prototype else CAMERA_FOV
	_camera_fov_target = _camera.fov
	_camera.near = 0.1
	_camera.far = 200.0
	add_child(_camera)
	_camera.look_at(_camera_target, Vector3.UP)
	_camera.current = true


# Authored smart targets: an Area3D on the pick layer so a click finds them,
# plus a floor plate marking the approach point. Areas never block navigation.
func _build_smart_objects() -> void:
	for object_id: StringName in SMART_OBJECTS:
		var definition: Dictionary = SMART_OBJECTS[object_id]
		_commands.register_smart_object(
			object_id, definition["label"], definition["approach"]
		)
		var area := Area3D.new()
		area.name = String(object_id)
		area.position = definition["pick_center"]
		area.collision_layer = 2
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("smart_object_id", object_id)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = definition["pick_size"]
		collision.shape = shape
		area.add_child(collision)
		_smart_object_root.add_child(area)
		if object_id == &"trapdoor_control":
			var button := MeshInstance3D.new()
			button.name = "TrapdoorControlButton"
			var button_mesh := BoxMesh.new()
			button_mesh.size = Vector3(0.52, 0.52, 0.16)
			button.mesh = button_mesh
			button.material_override = _flat_material(Color("b33b36"), 1.0)
			button.position = definition["pick_center"]
			_smart_object_root.add_child(button)

		var plate := MeshInstance3D.new()
		plate.name = "%sMarker" % object_id
		var plate_mesh := CylinderMesh.new()
		plate_mesh.top_radius = 0.42
		plate_mesh.bottom_radius = 0.42
		plate_mesh.height = 0.03
		plate_mesh.material = _flat_material(SMART_OBJECT_COLOR, 0.45)
		plate.mesh = plate_mesh
		plate.position = (definition["approach"] as Vector3) + Vector3(0.0, 0.02, 0.0)
		var label := Label3D.new()
		label.name = "Name"
		label.text = definition["label"]
		label.position.y = 0.5
		label.font_size = 24
		label.pixel_size = 0.006
		label.outline_size = 8
		label.modulate = SMART_OBJECT_COLOR
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		plate.add_child(label)
		_smart_object_root.add_child(plate)
		_smart_object_plates[object_id] = plate


func _refresh_prepared_drinks(state: Dictionary) -> void:
	if _drink_root == null:
		return
	var live: Dictionary = {}
	var drinks: Array = state.get("prepared_drinks", {}).get("drinks", [])
	for index in range(drinks.size()):
		var drink: Dictionary = drinks[index]
		var drink_id: StringName = drink["id"]
		live[drink_id] = true
		var node: Area3D = _drink_nodes.get(drink_id)
		if node == null:
			node = _build_prepared_drink_node(drink)
			_drink_root.add_child(node)
			_drink_nodes[drink_id] = node
		node.position = Vector3(-1.15 + float(index) * 1.15, 1.22, 0.05)
		var label := node.get_node("Label") as Label3D
		label.text = "%s%s" % [
			String(drink["type"]).capitalize(), "  ·  Drugged" if bool(drink["drugged"]) else "",
		]
		(node.get_node("DrugMarker") as Label3D).visible = bool(drink["drugged"])
	for drink_id: StringName in _drink_nodes.keys():
		if live.has(drink_id):
			continue
		(_drink_nodes[drink_id] as Node).queue_free()
		_drink_nodes.erase(drink_id)


func _build_prepared_drink_node(drink: Dictionary) -> Area3D:
	var area := Area3D.new()
	area.name = String(drink["id"])
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("drink_id", drink["id"])
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.4, 0.8)
	collision.shape = shape
	collision.position.y = 0.35
	area.add_child(collision)
	var vessel := MeshInstance3D.new()
	match StringName(drink["type"]):
		&"wine":
			var glass := CylinderMesh.new()
			glass.top_radius = 0.25
			glass.bottom_radius = 0.08
			glass.height = 0.48
			vessel.mesh = glass
			vessel.position.y = 0.48
		&"beer":
			var mug := BoxMesh.new()
			mug.size = Vector3(0.45, 0.68, 0.4)
			vessel.mesh = mug
			vessel.position.y = 0.35
		&"liquor":
			var tumbler := CylinderMesh.new()
			tumbler.top_radius = 0.28
			tumbler.bottom_radius = 0.24
			tumbler.height = 0.38
			vessel.mesh = tumbler
			vessel.position.y = 0.2
	vessel.material_override = _flat_material(Color("d9c56f"), 0.95)
	area.add_child(vessel)
	var label := Label3D.new()
	label.name = "Label"
	label.position = Vector3(0.0, 1.15, 0.0)
	label.font_size = 28
	label.pixel_size = 0.0045
	label.outline_size = 10
	label.modulate = Color("e6d7b8")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	area.add_child(label)
	var marker := Label3D.new()
	marker.name = "DrugMarker"
	marker.text = "|"
	marker.position = Vector3(0.18, 0.86, 0.0)
	marker.rotation.z = -0.35
	marker.font_size = 42
	marker.pixel_size = 0.005
	marker.modulate = Color("a77be8")
	marker.outline_size = 8
	marker.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	area.add_child(marker)
	return area


# Two floor panels over a dark pit. The panels hinge open on the outer edges so a
# captured Patron can sink into the pit; the simulation owns when and how far.
func _build_trapdoor() -> void:
	_trapdoor_root = Node3D.new()
	_trapdoor_root.name = "TrapdoorPanels"
	add_child(_trapdoor_root)
	var pit := _build_box(
		Vector2(TRAPDOOR_HATCH_CENTER.x, TRAPDOOR_HATCH_CENTER.z),
		Vector3(1.72, 1.6, 2.82), -0.72, Color("06080b")
	)
	_trapdoor_root.add_child(pit)
	_trapdoor_left_hinge = _build_trapdoor_panel(4.6, 1.0)
	_trapdoor_right_hinge = _build_trapdoor_panel(7.4, -1.0)
	_trapdoor_root.add_child(_trapdoor_left_hinge)
	_trapdoor_root.add_child(_trapdoor_right_hinge)


# One hinged half of the hatch. The hinge sits on the outer edge; the panel mesh
# extends toward the centre so a rotation about the hinge swings it into the pit.
func _build_trapdoor_panel(hinge_z: float, inner_sign: float) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = Vector3(TRAPDOOR_HATCH_CENTER.x, NAVIGATION_FLOOR_Y + 0.06, hinge_z)
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.68, 0.07, 1.36)
	panel.mesh = mesh
	panel.material_override = _flat_material(Color("2c3038"), 1.0)
	panel.position = Vector3(0.0, 0.0, inner_sign * 0.7)
	hinge.add_child(panel)
	return hinge


# Maps the authoritative Trapdoor state to panel openness. Open and falling hold
# the panels fully open; closing interpolates them shut; every other state is flat.
func _refresh_trapdoor(state: Dictionary) -> void:
	if _trapdoor_root == null:
		return
	var trap: Dictionary = state.get("trapdoor", {})
	var open_amount := 0.0
	match StringName(trap.get("state", &"closed")):
		&"open", &"falling":
			open_amount = 1.0
		&"closing":
			open_amount = clampf(1.0 - float(trap.get("close_ratio", 0.0)), 0.0, 1.0)
	_trapdoor_open_amount = open_amount
	var angle := deg_to_rad(TRAPDOOR_PANEL_OPEN_DEGREES * open_amount)
	_trapdoor_left_hinge.rotation = Vector3(angle, 0.0, 0.0)
	_trapdoor_right_hinge.rotation = Vector3(-angle, 0.0, 0.0)


func _add_presentation_prototype() -> void:
	var main_room := MAIN_ROOM_PRESENTATION_SCRIPT.new() as Node3D
	main_room.name = "FullScaleSpeakeasyPresentation"
	add_child(main_room)


func _build_navigation_world() -> void:
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "ProductionNavigationRegion"
	_navigation_region.navigation_mesh = NAVIGATION_MESH.duplicate(true)
	add_child(_navigation_region)

	_add_navigation_box(Vector3(-0.5, 0.09, 4.0), Vector3(27.0, 0.18, 12.0))
	_add_navigation_box(Vector3(-17.5, 0.09, 5.0), Vector3(7.0, 0.18, 14.0))
	_add_navigation_box(Vector3(15.0, 0.09, 6.0), Vector3(4.0, 0.18, 6.0))
	_add_navigation_box(Vector3(19.0, 0.09, 6.0), Vector3(4.0, 0.18, 6.0))
	_add_navigation_box(Vector3(0.0, 0.68, 0.15), Vector3(12.45, 1.36, 1.65))
	for x_position in [-11.2, -5.2, 5.2, 11.2]:
		_add_navigation_box(Vector3(x_position, 0.43, 6.0), Vector3(1.56, 0.86, 1.56))
	_add_navigation_box(Vector3(19.55, 0.48, 5.8), Vector3(0.9, 0.96, 1.1))
	_add_navigation_box(Vector3(19.55, 0.5, 7.75), Vector3(1.1, 1.0, 0.75))


func _add_navigation_box(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_navigation_region.add_child(body)


func _bake_navigation_world() -> void:
	var navigation_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(navigation_map, 0.2)
	NavigationServer3D.map_set_cell_height(navigation_map, 0.1)
	var wait_frames := 0
	var sample_point := Vector3(-3.0, NAVIGATION_FLOOR_Y, 2.0)
	while (
		NavigationServer3D.map_get_iteration_id(navigation_map) == 0
		or NavigationServer3D.map_get_closest_point(navigation_map, sample_point).distance_to(sample_point) > 1.0
	) and wait_frames < 180:
		await get_tree().physics_frame
		wait_frames += 1
	_navigation_ready = (
		NavigationServer3D.map_get_iteration_id(navigation_map) > 0
		and NavigationServer3D.map_get_closest_point(navigation_map, sample_point).distance_to(sample_point) <= 1.0
	)
	_movement_feedback = (
		"Navigation ready. Left-click a Cultist; right-click the floor to move."
		if _navigation_ready
		else "Navigation failed to initialize."
	)
	_select_cultist(_selected_cultist_id)
	# The review capture wants seated Patrons, so let them walk once navigation
	# is ready. Selection closes any open menu, so the preview opens after it.
	if _capture_navigation_enabled:
		_refresh(_session.snapshot())
	if not _context_menu_preview.is_empty():
		_open_preview_context_menu()
	_preview_hud_state(_hud_preview)
	if _emote_play_scale >= 0.0:
		_accepted_time_scale = 1.0 if _emote_play_scale > 0.0 else 0.0
		for actor_id: int in _cultist_nodes:
			(_cultist_nodes[actor_id] as NavigableActor3D).set_simulation_scale(AUTOMATED_RUN_SCALE)
	_refresh_hud(_session.snapshot())
	if not _movement_report_path.is_empty():
		_run_movement_validation.call_deferred(_movement_report_path)
	elif not _command_report_path.is_empty():
		_run_command_validation.call_deferred(_command_report_path)
	elif not _emote_report_path.is_empty():
		_run_emote_validation.call_deferred(_emote_report_path)
	elif not _bathroom_report_path.is_empty():
		_run_bathroom_review.call_deferred(_bathroom_report_path)


# Production-scene check for the Emote Bubble overlay. It stages every authored
# actor, forces the readable states, then proves placement, HUD avoidance, and
# clean teardown at both supported resolutions and in both accessibility modes.
# Captures the Bathroom Visit and Trapdoor evidence: a Patron at each station with
# its Emote Progress fill, then a standing capture through the open panels, the
# close, and the empty room after removal. Frames land at three resolutions.
# Runs one review sequence per invocation from a fresh Night, so the two
# Companions never contaminate each other: capturing one, or a long visit by one,
# would otherwise max the other's missing-Companion Suspicion within 40 seconds.
func _run_bathroom_review(report_path: String) -> void:
	var artifact_dir := report_path.get_base_dir()
	_set_emote_accessibility(true, 1.0)
	_set_camera_view(BATHROOM_CAMERA_POSITION, BATHROOM_CAMERA_TARGET)
	get_window().size = Vector2i(1_280, 720)
	await get_tree().process_frame
	for actor_id: int in _patron_nodes:
		(_patron_nodes[actor_id] as NavigableActor3D).set_simulation_scale(AUTOMATED_RUN_SCALE)
	await _play_until(func() -> bool: return true, 30)

	var checks: Array[Dictionary]
	if _bathroom_review_mode == "visit":
		checks = await _review_full_visit(artifact_dir)
	else:
		checks = await _review_standing_capture(artifact_dir)

	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check["passed"])
	var report := {"passed": passed, "mode": _bathroom_review_mode, "check_count": checks.size(), "checks": checks}
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	get_tree().quit(0 if passed else 1)


# A full visit: each station captured with its distinct Emote Progress fill.
func _review_full_visit(artifact_dir: String) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	_session.debug_force_bathroom(5)
	checks.append(await _bathroom_phase_frame(artifact_dir, "mirror", 5, &"mirror_check"))
	checks.append(await _bathroom_phase_frame(artifact_dir, "toilet", 5, &"seated_bathroom_use"))
	await _save_frame(artifact_dir, "toilet_1024", Vector2i(1_024, 576))
	await _save_frame(artifact_dir, "toilet_1920", Vector2i(1_920, 1_080))
	get_window().size = Vector2i(1_280, 720)
	checks.append(await _bathroom_phase_frame(artifact_dir, "handwashing", 5, &"handwashing"))
	return checks


# A standing capture: the panels open, the avatar sinks occluded, then removal.
func _review_standing_capture(artifact_dir: String) -> Array[Dictionary]:
	_session.debug_force_bathroom(4)
	var standing_phases: Array[StringName] = [
		&"mirror_check", &"moving_to_toilet", &"moving_to_sink", &"handwashing",
	]
	var reached_standing := await _play_until(func() -> bool:
		return _session.snapshot()["debug_patron_views"][4]["activity"] in standing_phases, 3_000)
	await _save_frame(artifact_dir, "before_activation", Vector2i(1_280, 720))
	_session.activate_trapdoor()
	var saw_falling := await _play_until(func() -> bool:
		return _session.snapshot()["trapdoor"]["state"] == &"falling", 120)
	await _play_until(func() -> bool:
		return float(_session.snapshot()["trapdoor"]["fall_ratio"]) > 0.5, 60)
	await _save_frame(artifact_dir, "falling", Vector2i(1_280, 720))
	var june_node := _patron_nodes[4] as NavigableActor3D
	var sank := june_node.global_position.y < NAVIGATION_FLOOR_Y - 0.2
	var saw_closing := await _play_until(func() -> bool:
		return _session.snapshot()["trapdoor"]["state"] == &"closing", 120)
	await _save_frame(artifact_dir, "closing", Vector2i(1_280, 720))
	var removed := await _play_until(func() -> bool:
		return int(_session.snapshot()["captures"]) > 0, 240)
	await get_tree().process_frame
	await _save_frame(artifact_dir, "after_removal", Vector2i(1_280, 720))
	return [
		{"check": &"standing_capture_reached", "passed": reached_standing},
		{"check": &"panels_opened_falling", "passed": saw_falling},
		{"check": &"avatar_sank_below_floor", "passed": sank},
		{"check": &"panels_closed", "passed": saw_closing},
		{"check": &"patron_removed_after_close", "passed": removed and not june_node.visible},
	]


# Advances the simulated Night while the actor nodes physically walk, so timed
# phases and navigation arrivals both progress until the condition holds.
func _play_until(condition: Callable, budget: int) -> bool:
	var frames := 0
	while frames < budget:
		if bool(condition.call()):
			return true
		_session.advance(AUTOMATED_RUN_SCALE / 60.0)
		await get_tree().physics_frame
		frames += 1
	return bool(condition.call())


func _bathroom_phase_frame(dir: String, name: String, patron_id: int, phase: StringName) -> Dictionary:
	var reached := await _play_until(func() -> bool:
		return _session.snapshot()["debug_patron_views"][patron_id]["activity"] == phase, 3_000)
	# Let the fill build a little so the captured frame reads as in-progress.
	await _play_until(func() -> bool: return false, 12)
	await _save_frame(dir, name, Vector2i(1_280, 720))
	return {"check": StringName("reached_%s" % name), "passed": reached}


func _save_frame(dir: String, name: String, size: Vector2i) -> void:
	if get_window().size != size:
		get_window().size = size
		await get_tree().process_frame
	await get_tree().process_frame
	_advance_emotes(0.0)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("%s/%s.png" % [dir, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	get_viewport().get_texture().get_image().save_png(path)


func _run_emote_validation(report_path: String) -> void:
	var checks: Array[Dictionary] = []
	for cultist_id: int in PLAYABLE_CULTIST_IDS:
		(_cultist_nodes[cultist_id] as NavigableActor3D).set_simulation_scale(4.0)
	_stage_emote_states()
	# The authored cast must be spread across the room, not stacked at one point,
	# or the placement solver has nothing real to solve.
	await _wait_for_patrons(2_400)

	for resolution: Vector2i in [Vector2i(1_280, 720), Vector2i(1_920, 1_080)]:
		get_window().size = resolution
		await get_tree().process_frame
		for labels: bool in [false, true]:
			_set_emote_accessibility(labels, 1.0)
			await get_tree().process_frame
			checks.append(_check_emote_frame(
				StringName("%dx%d_%s" % [
					resolution.x, resolution.y, "labels" if labels else "icons",
				])
			))
	for ui_scale: float in [0.75, 1.5]:
		_set_emote_accessibility(true, ui_scale)
		await get_tree().process_frame
		checks.append(_check_emote_frame(StringName("ui_scale_%d" % int(ui_scale * 100.0))))
	_set_emote_accessibility(false, 1.0)

	# Camera movement must not orphan a bubble or strand a stale anchor.
	_pan_camera(Vector3(3.0, 0.0, 2.0))
	_zoom_camera_smooth(4.0)
	_camera.fov = _camera_fov_target
	await get_tree().process_frame
	checks.append(_check_emote_frame(&"after_pan_and_zoom"))
	_pan_camera(Vector3(-3.0, 0.0, -2.0))

	# Departure, Capture, and Closing remove the actor and their bubble with it.
	var escaping_id := 10
	var before_close := false
	for bubble: Dictionary in _emotes.bubbles():
		before_close = before_close or bubble["actor_id"] == escaping_id
	_session.advance(1_080.0 - float(_session.snapshot()["simulated_seconds"]))
	await get_tree().process_frame
	_advance_emotes(0.0)
	var still_shown := false
	for bubble: Dictionary in _emotes.bubbles():
		still_shown = still_shown or bubble["actor_id"] == escaping_id
	checks.append({
		"check": &"closing_clears_departed_actors",
		"passed": before_close and not still_shown,
		"detail": "%d bubbles remain at Results" % _emotes.bubbles().size(),
	})

	var restart_clean := true
	for _restart in range(10):
		_session.restart_night(707)
		_commands.reset(_session)
		_emotes.reset()
		_emote_overlay.reset()
		_advance_emotes(0.0)
		restart_clean = restart_clean and _emote_overlay.placements().is_empty()
	checks.append({
		"check": &"ten_restarts_leave_no_orphan_bubble",
		"passed": restart_clean,
		"detail": "",
	})

	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check["passed"])
	var report := {
		"passed": passed,
		"check_count": checks.size(),
		"checks": checks,
	}
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	get_tree().quit(0 if passed else 1)


# Forces one readable example of each urgent state so the frame under test
# carries eleven actors and every catalog category at once.
func _stage_emote_states() -> void:
	_session.report_patron_stimulus(10, &"drink_dosed_seen")
	_session.debug_set_patron_drink_state(8, 3, 1, 0, 3)
	_session.debug_force_finish_drink(8)
	_session.debug_force_bathroom(9)
	_session.debug_set_patron_drink_state(4, 0, 5, 0, 3)
	_session.begin_conversation(2, 5)
	_session.advance(45.0)
	_advance_emotes(0.0)


func _check_emote_frame(label: StringName) -> Dictionary:
	_advance_emotes(0.0)
	var bubbles: Array[Dictionary] = _emotes.bubbles()
	var placements: Dictionary = _emote_overlay.placements()
	var viewport_size := get_viewport().get_visible_rect().size
	var reserved := _reserved_hud_rects()
	var failures: Array[String] = []

	var seen: Dictionary = {}
	for bubble: Dictionary in bubbles:
		var actor_id: int = bubble["actor_id"]
		if seen.has(actor_id):
			failures.append("%s has more than one bubble" % actor_id)
		seen[actor_id] = true

	var rects: Array[Rect2] = []
	for actor_id: int in placements:
		var rect: Rect2 = placements[actor_id]
		if not Rect2(Vector2.ZERO, viewport_size).encloses(rect):
			failures.append("%s sits outside the viewport" % actor_id)
		for panel: Rect2 in reserved:
			if panel.intersects(rect):
				failures.append("%s covers a critical HUD panel" % actor_id)
		for other: Rect2 in rects:
			if other.intersects(rect):
				failures.append("%s overlaps another bubble" % actor_id)
		rects.append(rect)

	if placements.is_empty() and not bubbles.is_empty():
		failures.append("no bubble found a legal position")
	# Determinism: the same frame solved twice must place the same rectangles.
	_advance_emotes(0.0)
	var repeated: Dictionary = _emote_overlay.placements()
	if repeated.size() != placements.size():
		failures.append("placement is not deterministic")
	else:
		for actor_id: int in placements:
			if not repeated.has(actor_id) or repeated[actor_id] != placements[actor_id]:
				failures.append("%s moved between identical frames" % actor_id)
	return {
		"check": label,
		"passed": failures.is_empty() and not bubbles.is_empty(),
		"detail": "%d bubbles, %d placed, %d hidden for space%s" % [
			bubbles.size(), placements.size(), bubbles.size() - placements.size(),
			"" if failures.is_empty() else ": " + ", ".join(failures),
		],
	}


# Production-scene check for the unified command seam. It drives real picking
# targets, real navigation, and the real GameSession, then writes one report.
func _run_command_validation(report_path: String) -> void:
	var steps: Array[Dictionary] = []
	var passed := _navigation_ready
	if _navigation_ready:
		# Cross the same playback seam as the HUD. The production adapter must
		# propagate the accepted Simulation Speed to every visible actor.
		_playback.submit(&"select_speed", {"value": _movement_validation_scale})
		_refresh(_session.snapshot())
		# The staged full cast has every Order served, so give one Patron a fresh
		# Order to make the bar and service commands meaningful.
		_session.debug_set_patron_drink_state(4, 0, 5, 0, 3)
		_session.advance(45.0)
		await _wait_for_patrons(1_800)

		# Keep this deterministic validation serial through Vera rather than racing
		# Iris. The route is ordered center-right first so
		# the Trapdoor gets a clean run-up into the bathroom before she crosses to
		# the far-left Patrons; reservation still transfers and releases per command,
		# which the trailing reserved_slots check verifies.
		steps.append(await _validate_step(
			&"floor_move", 1, &"move", _floor_target(Vector3(8.0, NAVIGATION_FLOOR_Y, 4.0)),
			func() -> bool: return true
		))

		steps.append(await _validate_step(
			&"trapdoor", 1, &"activate_trapdoor", _smart_target(&"trapdoor_control"),
			func() -> bool: return _session.snapshot()["trapdoor"]["state"] != &"closed"
		))

		steps.append(await _validate_step(
			&"bar_command", 1, &"make_wine", _smart_target(&"bar_work_position"),
			func() -> bool: return not _session.snapshot()["prepared_drinks"]["drinks"].is_empty()
		))

		steps.append(await _validate_patron_chain(
			1, 4,
			func() -> bool: return _session.snapshot()["conversations"].has(1)
		))

		_session.debug_set_patron_drink_state(5, 3, 1, 0, 3)
		_session.debug_force_finish_drink(5)
		_session.advance(0.2)
		await _wait_for_patrons(900)
		steps.append(await _validate_step(
			&"body_pickup", 1, &"pick_up_body", _actor_target(5),
			func() -> bool: return _session.snapshot()["drags"].has(5)
		))
		steps.append(await _validate_step(
			&"body_drop", 1, &"drop_body", _floor_target(Vector3(-2.0, NAVIGATION_FLOOR_Y, 3.0)),
			func() -> bool: return not _session.snapshot()["drags"].has(5)
		))

	var stuck_actors: Array[String] = []
	for cultist_id: int in PLAYABLE_CULTIST_IDS:
		var actor := _cultist_nodes[cultist_id] as NavigableActor3D
		if actor.is_navigating() or not _commands.active_request(cultist_id).is_empty():
			stuck_actors.append(str(cultist_id))
	var reserved: Dictionary = _commands.snapshot()["reserved_slots"]
	for step: Dictionary in steps:
		passed = passed and bool(step["passed"])
	passed = passed and stuck_actors.is_empty() and reserved.is_empty()

	var report := {
		"passed": passed,
		"navigation_ready": _navigation_ready,
		"simulation_scale": _movement_validation_scale,
		"step_count": steps.size(),
		"steps": steps,
		"stuck_actors": stuck_actors,
		"reserved_slots": reserved.keys().map(func(id: StringName) -> String: return String(id)),
	}
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	get_tree().quit(0 if passed else 1)


func _validate_step(
		step: StringName,
		cultist_id: int,
		command: StringName,
		target: Dictionary,
		verify: Callable
) -> Dictionary:
	var issued: Dictionary = _commands.issue(cultist_id, command, target, false)
	if not bool(issued["accepted"]):
		return {"step": step, "passed": false, "detail": String(issued["message"])}
	_sync_cultist_navigation(cultist_id)
	var settled := await _wait_for_command(cultist_id, 2_400, true)
	var effect: bool = verify.call()
	var actor := _cultist_nodes[cultist_id] as NavigableActor3D
	return {
		"step": step,
		"passed": settled and effect,
		"detail": String(_commands.snapshot()["cultists"][cultist_id]["feedback"]["message"]),
		"actor_position": [actor.global_position.x, actor.global_position.z],
	}


# Crosses the production command and navigation seams for one nonadjacent Talk.
# The check moves the live Patron node after navigation starts, so the Generated
# Move must update its destination before the requested Action can complete.
func _validate_patron_chain(
		cultist_id: int, patron_id: int, verify: Callable
) -> Dictionary:
	var issued: Dictionary = _commands.issue(
		cultist_id, &"talk", _actor_target(patron_id), false, {"is_adjacent": false}
	)
	if not bool(issued["accepted"]):
		return {"step": &"patron_action_chain", "passed": false, "detail": String(issued["message"])}
	var generated_ids: Array = issued["generated_action_ids"]
	var queue: Dictionary = _commands.snapshot()["cultists"][cultist_id]
	var active: Dictionary = queue["active"]
	var pending: Array = queue["pending"]
	var chain_visible: bool = bool(
		generated_ids.size() == 1
		and active["command"] == COMMAND_SYSTEM_SCRIPT.GENERATED_MOVE
		and pending.size() == 1
		and pending[0]["command"] == &"talk"
		and int(active["chain_id"]) == int(pending[0]["chain_id"])
	)
	var reservation_held: bool = bool(_commands.snapshot()["reserved_slots"].get(cultist_id, &"") == (
		&"approach_patron_june"
	))

	_sync_cultist_navigation(cultist_id)
	var cultist := _cultist_nodes[cultist_id] as NavigableActor3D
	var first_destination := cultist.target_position()
	var patron := _patron_nodes[patron_id] as NavigableActor3D
	patron.global_position += Vector3(1.2, 0.0, 0.0)
	_sync_cultist_navigation(cultist_id)
	var moved_destination := cultist.target_position()
	var tracked_live_position: bool = first_destination.distance_to(moved_destination) > 0.5

	var settled := await _wait_for_command(cultist_id, 2_400, false)
	var effect: bool = verify.call()
	if effect:
		var current := cultist.global_position
		_commands.issue(
			cultist_id, &"move",
			_floor_target(Vector3(current.x, NAVIGATION_FLOOR_Y, current.z)), false
		)
		_sync_cultist_navigation(cultist_id)
		var replacement_settled := await _wait_for_command(cultist_id, 300, true)
		settled = settled and replacement_settled
	var reservation_released: bool = not _commands.snapshot()["reserved_slots"].has(cultist_id)
	return {
		"step": &"patron_action_chain",
		"passed": chain_visible and reservation_held and tracked_live_position
			and settled and effect and reservation_released,
		"detail": "Generated Move -> Talk completed after a live target move",
		"chain_id": int(issued["chain_id"]),
		"generated_action_id": int(generated_ids[0]) if not generated_ids.is_empty() else -1,
		"requested_action_id": int(issued["action_id"]),
		"tracked_live_position": tracked_live_position,
		"reservation_held": reservation_held,
		"reservation_released": reservation_released,
		"chain_visible": chain_visible,
		"settled": settled,
		"effect": effect,
	}


func _wait_for_command(
		cultist_id: int, frame_budget: int, require_queue_empty: bool = true
) -> bool:
	# Wait until the command clears AND the Cultist node has physically settled.
	# Running every validation command serially through one Cultist otherwise lets
	# the next step read a transient position while the node finishes its last leg,
	# which turned the 4x pass flaky.
	var actor := _cultist_nodes.get(cultist_id) as NavigableActor3D
	var frames := 0
	while frames < frame_budget:
		var command_idle: bool = (
			_commands.snapshot()["cultists"][cultist_id]["active"].is_empty()
			if require_queue_empty
			else _commands.active_request(cultist_id).is_empty()
		)
		var node_still := actor == null or not actor.is_navigating()
		if command_idle and node_still:
			return true
		await get_tree().physics_frame
		frames += 1
	return false


func _wait_for_patrons(frame_budget: int) -> bool:
	var frames := 0
	while frames < frame_budget:
		var settled := true
		for patron_id: int in _patron_nodes:
			if (_patron_nodes[patron_id] as NavigableActor3D).is_navigating():
				settled = false
				break
		if settled:
			return true
		await get_tree().physics_frame
		frames += 1
	return false


func _smart_target(object_id: StringName) -> Dictionary:
	return {
		"kind": COMMAND_SYSTEM_SCRIPT.TARGET_OBJECT,
		"id": object_id,
		"position": SMART_OBJECTS[object_id]["approach"],
	}


func _actor_target(patron_id: int) -> Dictionary:
	var position := Vector3.ZERO
	if _patron_nodes.has(patron_id):
		position = (_patron_nodes[patron_id] as NavigableActor3D).global_position
	return {
		"kind": COMMAND_SYSTEM_SCRIPT.TARGET_PATRON,
		"id": patron_id,
		"position": position,
	}


func _run_movement_validation(report_path: String) -> void:
	# Movement validation drives Vera through a two-leg queue while Iris stays idle,
	# so the report measures one route without cross-traffic.
	var targets := {
		1: [Vector3(-8.0, NAVIGATION_FLOOR_Y, 4.0), Vector3(-3.0, NAVIGATION_FLOOR_Y, 2.0)],
	}
	var patron_targets := {
		4: Vector3(-12.0, NAVIGATION_FLOOR_Y, 6.0),
		5: Vector3(-10.5, NAVIGATION_FLOOR_Y, 6.0),
		6: Vector3(-6.0, NAVIGATION_FLOOR_Y, 6.0),
		7: Vector3(-4.5, NAVIGATION_FLOOR_Y, 6.0),
		8: Vector3(4.5, NAVIGATION_FLOOR_Y, 6.0),
		9: Vector3(6.0, NAVIGATION_FLOOR_Y, 6.0),
		10: Vector3(10.5, NAVIGATION_FLOOR_Y, 6.0),
		11: Vector3(12.0, NAVIGATION_FLOOR_Y, 6.0),
	}
	if _navigation_ready:
		for cultist_id: int in PLAYABLE_CULTIST_IDS:
			var actor := _cultist_nodes[cultist_id] as NavigableActor3D
			actor.set_simulation_scale(_movement_validation_scale)
			var destinations: Array = targets[cultist_id]
			for index in range(destinations.size()):
				_commands.issue(
					cultist_id, &"move", _floor_target(destinations[index]), index > 0
				)
			_sync_cultist_navigation(cultist_id)
		for patron_id: int in ALL_PATRON_IDS:
			(_patron_nodes[patron_id] as NavigableActor3D).set_simulation_scale(
				_movement_validation_scale
			)
		# Patrons arrive as authored pairs, so validate the same waves instead of
		# forcing all eight through one seat approach in the same physics frame.
		for group_start in range(0, ALL_PATRON_IDS.size(), 2):
			var wave: Array[int] = [
				ALL_PATRON_IDS[group_start], ALL_PATRON_IDS[group_start + 1],
			]
			for patron_id: int in wave:
				var actor := _patron_nodes[patron_id] as NavigableActor3D
				var target: Vector3 = patron_targets[patron_id]
				_patron_visual_targets[patron_id] = target
				actor.navigate_path(_next_patron_move_id, _seat_approach_route(target))
				_next_patron_move_id += 1
			var wave_frames := 0
			while wave_frames < 900:
				var wave_complete := true
				for patron_id: int in wave:
					if (_patron_nodes[patron_id] as NavigableActor3D).is_navigating():
						wave_complete = false
						break
				if wave_complete:
					break
				await get_tree().physics_frame
				wave_frames += 1

	var frame_count := 0
	while _navigation_ready and frame_count < 900:
		var all_complete := true
		for cultist_id: int in PLAYABLE_CULTIST_IDS:
			if not _commands.active_request(cultist_id).is_empty():
				all_complete = false
				break
		if all_complete:
			for patron_id: int in _patron_nodes:
				if (_patron_nodes[patron_id] as NavigableActor3D).is_navigating():
					all_complete = false
					break
		if all_complete:
			break
		await get_tree().physics_frame
		frame_count += 1

	var final_positions := {}
	var patron_positions := {}
	var passed := _navigation_ready
	for cultist_id: int in PLAYABLE_CULTIST_IDS:
		var actor := _cultist_nodes[cultist_id] as NavigableActor3D
		var destinations: Array = targets[cultist_id]
		var expected: Vector3 = destinations[-1]
		var distance := actor.global_position.distance_to(expected)
		final_positions[cultist_id] = {
			"position": [actor.global_position.x, actor.global_position.y, actor.global_position.z],
			"distance_to_target": distance,
			"repaths": actor.repath_count,
		}
		passed = passed and distance <= 0.55 and _commands.active_request(cultist_id).is_empty()
	for patron_id: int in _patron_nodes:
		var actor := _patron_nodes[patron_id] as NavigableActor3D
		var expected: Vector3 = _patron_visual_targets.get(patron_id, actor.global_position)
		var distance := actor.global_position.distance_to(expected)
		patron_positions[patron_id] = {
			"position": [actor.global_position.x, actor.global_position.y, actor.global_position.z],
			"distance_to_target": distance,
			"repaths": actor.repath_count,
		}
		passed = passed and distance <= 0.82 and not actor.is_navigating()

	var report := {
		"passed": passed,
		"navigation_ready": _navigation_ready,
		"frames": frame_count,
		"simulation_scale": _movement_validation_scale,
		"actor_count": final_positions.size() + patron_positions.size(),
		"selected_cultist": str(_selected_cultist_id),
		"cultists": final_positions,
		"patrons": patron_positions,
	}
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	if not _movement_capture_path.is_empty():
		var capture_path := ProjectSettings.globalize_path(_movement_capture_path)
		DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
		get_viewport().get_texture().get_image().save_png(capture_path)
	get_tree().quit(0 if passed else 1)


func _build_room_zone(room_id: StringName) -> Node3D:
	var rect: Array = ROOM_RECTS[room_id]
	var center := Vector2((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5)
	var pad := _build_box(center, Vector3(rect[2] - rect[0], 0.06, rect[3] - rect[1]), 0.03, ROOM_COLORS[room_id], true)
	if _presentation_prototype and room_id in [&"hallway", &"bathroom"]:
		return pad
	var label := Label3D.new()
	label.text = String(room_id).to_upper().replace("_", " ")
	label.position = Vector3(center.x, 1.4, center.y)
	label.font_size = 60
	label.modulate = Color("93a6b4")
	label.outline_size = 18
	label.outline_modulate = Color("0b1016")
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	if _presentation_prototype and room_id == &"main_hall":
		label.font_size = 36
		label.pixel_size = 0.006
		label.position.y = 0.45
		label.modulate = Color("c8a878")
	pad.add_child(label)
	return pad


func _build_box(sim_position: Vector2, size: Vector3, y_center: float, color: Color, translucent := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = Vector3(sim_position.x, y_center, sim_position.y)
	instance.material_override = _flat_material(color, color.a if translucent else 1.0)
	return instance


func _flat_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# A flat FOV cone on the XZ plane, apex at the origin, opening along -Z (the pivot's
# facing after look_at). Drawn as the two straight edges to the full view range plus
# a short angle arc near the apex, so it reads as one Patron's cone without a giant
# sweep curving across the room.
func _sector_mesh(radius: float, half_angle_degrees: float) -> ArrayMesh:
	var half := deg_to_rad(half_angle_degrees)
	var edge_left := Vector3(sin(-half), 0.0, -cos(-half)) * radius
	var edge_right := Vector3(sin(half), 0.0, -cos(half)) * radius
	var vertices := PackedVector3Array()
	_append_stroke(vertices, PackedVector3Array([Vector3.ZERO, edge_left]), 0.12)
	_append_stroke(vertices, PackedVector3Array([Vector3.ZERO, edge_right]), 0.12)
	var arc_radius := minf(radius, 3.0)
	var arc := PackedVector3Array()
	for index in range(17):
		var a := lerpf(-half, half, float(index) / 16.0)
		arc.append(Vector3(sin(a), 0.0, -cos(a)) * arc_radius)
	_append_stroke(vertices, arc, 0.1)
	return _mesh_from_vertices(vertices)


# Appends thin flat quads tracing a polyline on the XZ plane.
func _append_stroke(vertices: PackedVector3Array, path: PackedVector3Array, thickness: float) -> void:
	for index in range(path.size() - 1):
		var a := path[index]
		var b := path[index + 1]
		var direction := b - a
		if direction.length() < 0.0001:
			continue
		direction = direction.normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * thickness * 0.5
		vertices.append_array([a + side, b + side, b - side, a + side, b - side, a - side])


func _mesh_from_vertices(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# A flat ring outline on the XZ plane at the given radius.
func _ring_mesh(radius: float, thickness: float) -> ArrayMesh:
	var segments := 48
	var inner := radius - thickness
	var vertices := PackedVector3Array()
	for index in range(segments):
		var a0 := TAU * float(index) / segments
		var a1 := TAU * float(index + 1) / segments
		var outer0 := Vector3(cos(a0), 0.0, sin(a0)) * radius
		var outer1 := Vector3(cos(a1), 0.0, sin(a1)) * radius
		var inner0 := Vector3(cos(a0), 0.0, sin(a0)) * inner
		var inner1 := Vector3(cos(a1), 0.0, sin(a1)) * inner
		vertices.append_array([inner0, outer0, outer1, inner0, outer1, inner1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Actors, bodies, events --------------------------------------------------

func _actor_pivot(patron_id: int) -> Node3D:
	if _patron_nodes.has(patron_id):
		return _patron_nodes[patron_id]
	var pivot := NAVIGABLE_ACTOR_SCRIPT.new() as NavigableActor3D
	pivot.configure(patron_id, false)
	var entrance_index := maxi(0, ALL_PATRON_IDS.find(patron_id))
	pivot.position = Vector3(
		-20.2,
		NAVIGATION_FLOOR_Y,
		1.1 + float(entrance_index) * 1.1
	)
	pivot.set_simulation_scale(_world_simulation_scale())
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.7 * float(PATRON_HEIGHT_SCALE.get(patron_id, 1.0))
	body.mesh = capsule
	body.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	body.name = "Body"
	body.material_override = _flat_material(PATRON_COLORS.get(patron_id, Color.WHITE), 1.0)
	_add_avatar_visual(pivot, patron_id, body)
	pivot.add_child(_actor_shadow())
	# The vision cone (its radius is the view range) and the Companion ring make
	# the perception geometry judgeable by eye instead of implied by an arrow.
	var cone := MeshInstance3D.new()
	cone.name = "VisionCone"
	cone.mesh = _sector_mesh(VIEW_RANGE, VIEW_CONE_HALF_ANGLE)
	cone.position = Vector3(0.0, 0.03, 0.0)
	cone.material_override = _flat_material(CONE_COLOR, 0.6)
	pivot.add_child(cone)
	var ring := MeshInstance3D.new()
	ring.name = "CompanionRing"
	ring.mesh = _ring_mesh(COMPANION_RANGE, 0.09)
	ring.position = Vector3(0.0, 0.05, 0.0)
	ring.material_override = _flat_material(COMPANION_RING_COLOR, 0.55)
	pivot.add_child(ring)
	var label := Label3D.new()
	label.name = "Name"
	# Stagger label height by seat order so neighbouring Patrons' labels don't overlap.
	var order := maxi(0, ALL_PATRON_IDS.find(patron_id))
	label.position = Vector3(0.0, 2.0 + float(order % 2) * 0.32, 0.0)
	label.font_size = 36 if _presentation_prototype else 44
	label.pixel_size = 0.0055 if _presentation_prototype else 0.006
	label.outline_size = 14
	label.outline_modulate = Color("0b1016")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pivot.add_child(label)
	_actor_root.add_child(pivot)
	pivot.destination_reached.connect(_on_patron_destination_reached)
	pivot.navigation_stuck.connect(_on_patron_navigation_stuck)
	_patron_nodes[patron_id] = pivot
	return pivot


func _pixel_actor_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = BARTENDER_TEXTURE
	sprite.pixel_size = CULTIST_VISIBLE_HEIGHT_METRES / BARTENDER_OPAQUE_HEIGHT_PIXELS
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.render_priority = 2
	return sprite


func _actor_shadow() -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.43
	mesh.bottom_radius = 0.43
	mesh.height = 0.018
	mesh.radial_segments = 24
	shadow.mesh = mesh
	shadow.position.y = 0.03
	shadow.scale.z = 0.52
	shadow.material_override = _flat_material(Color("09080b"), 0.7)
	return shadow


func _add_avatar_visual(actor: Node3D, actor_id: int, body: Node3D) -> void:
	var visual := AVATAR_MOTION_SCRIPT.new() as AvatarMotionController
	visual.configure(actor_id)
	visual.set_simulation_scale(_world_simulation_scale())
	actor.add_child(visual)
	visual.add_child(body)


func _cultist_pivot(cultist_id: int) -> Node3D:
	if _cultist_nodes.has(cultist_id):
		return _cultist_nodes[cultist_id]
	var pivot := NAVIGABLE_ACTOR_SCRIPT.new() as NavigableActor3D
	pivot.configure(cultist_id, true)
	pivot.position = CULTIST_POSITIONS[cultist_id] + Vector3(0.0, NAVIGATION_FLOOR_Y, 0.0)
	pivot.set_simulation_scale(_world_simulation_scale())
	var sprite := _pixel_actor_sprite()
	sprite.name = "Body"
	sprite.position.y = BARTENDER_FEET_FROM_CANVAS_CENTER_PIXELS * sprite.pixel_size
	sprite.modulate = CULTIST_COLORS[cultist_id]
	_add_avatar_visual(pivot, cultist_id, sprite)
	pivot.add_child(_actor_shadow())
	var label := Label3D.new()
	label.name = "Name"
	label.position = Vector3(0.0, 2.05, 0.0)
	label.font_size = 36
	label.pixel_size = 0.0055
	label.modulate = CULTIST_COLORS[cultist_id]
	label.outline_size = 14
	label.outline_modulate = Color("0b1016")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pivot.add_child(label)
	pivot.add_selection_ring(CULTIST_COLORS[cultist_id])
	pivot.destination_reached.connect(_on_cultist_destination_reached)
	pivot.navigation_stuck.connect(_on_cultist_navigation_stuck)
	_cultist_root.add_child(pivot)
	_cultist_nodes[cultist_id] = pivot
	pivot.set_selected(cultist_id == _selected_cultist_id)
	return pivot


func _refresh(state: Dictionary) -> void:
	if _refreshing:
		return
	_refreshing = true
	_refresh_scene(state)
	_refreshing = false


func _refresh_scene(state: Dictionary) -> void:
	_latest_state = state
	# Apply the authority's accepted Simulation Speed before any actor is created
	# or navigation is synchronized. Interactive play and validation cross this
	# same adapter path, so neither can leave Cultists at their construction-time
	# 0x scale.
	_accepted_time_scale = float(state["time_scale"])
	_synchronize_actor_playback()
	# Revalidation on every session change: a stale target fails and releases.
	_commands.refresh()
	var visible_patron_ids: Array[int] = ALL_PATRON_IDS if _presentation_prototype else PATRON_IDS
	for patron_id: int in visible_patron_ids:
		var pivot := _actor_pivot(patron_id)
		var debug: Dictionary = state["debug_patron_views"][patron_id]
		var normal: Dictionary = state["normal_patron_views"][patron_id]
		# A captured Patron is gone; a falling one is still present but sinking.
		var active: bool = debug["lifecycle"] not in [&"not_arrived", &"captured", &"exited"]
		pivot.visible = active
		if not active:
			(pivot as NavigableActor3D).cancel_navigation()
			_set_body_collision(pivot as NavigableActor3D, false)
			continue
		var is_unconscious: bool = debug["lifecycle"] == &"unconscious"
		var is_falling: bool = debug["activity"] == &"trapdoor_falling"
		if is_falling:
			# The Patron sinks a bounded depth into the pit and is occluded by the
			# floor; the simulation owns the ratio, so the fall never runs away.
			(pivot as NavigableActor3D).cancel_navigation()
			var fall_ratio: float = clampf(float(state["trapdoor"]["fall_ratio"]), 0.0, 1.0)
			pivot.position.y = NAVIGATION_FLOOR_Y - fall_ratio * TRAPDOOR_FALL_DEPTH
		elif debug["activity"] == &"being_dragged":
			_sync_dragged_body(patron_id, state)
		else:
			_set_body_collision(pivot as NavigableActor3D, not is_unconscious and bool(normal.get("interactive", true)))
			pivot.position.y = NAVIGATION_FLOOR_Y
			var facing: Vector2 = debug["facing"]
			var held_by_knockout: bool = (
				not state["windup"].is_empty()
				and state["windup"]["victim_id"] == patron_id
			)
			if held_by_knockout:
				(pivot as NavigableActor3D).cancel_navigation()
			else:
				_sync_patron_navigation(patron_id, debug)
			if not (pivot as NavigableActor3D).is_navigating():
				pivot.look_at(pivot.position + Vector3(facing.x, 0.0, facing.y), Vector3.UP)
		var band_color: Color = BAND_COLORS.get(normal["suspicion_band"], Color.WHITE)
		var body := pivot.get_node("VisualPivot/Body")
		var patron_body := body as MeshInstance3D
		var palette: Color = PATRON_COLORS.get(patron_id, Color.WHITE)
		patron_body.material_override = _flat_material(palette.lerp(band_color, 0.2), 1.0)
		var is_seated: bool = debug["activity"] == &"seated_bathroom_use"
		if is_unconscious:
			patron_body.rotation.z = -PI * 0.5
			patron_body.position.y = 0.42
			patron_body.scale = Vector3(1.0, 0.85, 1.0)
		elif is_seated:
			patron_body.rotation.z = 0.0
			patron_body.position.y = 0.62
			patron_body.scale = Vector3(1.0, 0.72, 1.0)
		else:
			patron_body.rotation.z = 0.0
			patron_body.position.y = 0.85
			patron_body.scale = Vector3.ONE
		var cone := pivot.get_node("VisionCone") as MeshInstance3D
		cone.material_override = _flat_material(band_color, 0.6)
		cone.visible = _debug_visible
		(pivot.get_node("CompanionRing") as MeshInstance3D).visible = _debug_visible
		var label := pivot.get_node("Name") as Label3D
		label.text = String(normal["name"])
		label.visible = label.text != "???"
		label.modulate = band_color
		var visual := pivot.get_node("VisualPivot") as AvatarMotionController
		var activity := StringName(debug["activity"])
		var moving := (pivot as NavigableActor3D).is_navigating() or activity == &"being_dragged"
		var resting := activity in [
			&"awaiting_drink", &"bathroom_queued", &"waiting_investigation",
			&"waiting_admission", &"step_aside_hold",
		]
		visual.set_context(
			AvatarMotionController.GAIT_RUN if activity in [&"shock", &"escaping"] else AvatarMotionController.GAIT_WALK,
			moving, not moving and not resting and not is_falling, is_unconscious or is_falling
		)

	for cultist_id: int in _cultist_nodes:
		_sync_cultist_navigation(cultist_id)
	_advance_emotes(0.0)
	_refresh_trapdoor(state)
	_refresh_entrance(state)
	_refresh_prepared_drinks(state)
	_refresh_bodies()
	_refresh_events(state)
	_refresh_cultists(state)
	_refresh_move_markers()
	_refresh_hud(state)
	_refresh_character_panels(state)


func _sync_dragged_body(patron_id: int, state: Dictionary) -> void:
	var body := _patron_nodes[patron_id] as NavigableActor3D
	body.cancel_navigation()
	_set_body_collision(body, false)
	var drag: Dictionary = state["drags"].get(patron_id, {})
	var cultist_id := int(drag.get("cultist_id", ActorIds.NO_ACTOR))
	if not _cultist_nodes.has(cultist_id):
		return
	var cultist := _cultist_nodes[cultist_id] as NavigableActor3D
	var behind := cultist.global_transform.basis.z
	behind.y = 0.0
	if behind.length_squared() < 0.001:
		behind = Vector3(0.0, 0.0, 1.0)
	var anchor := cultist.global_position + behind.normalized() * 0.75
	anchor.y = NAVIGATION_FLOOR_Y
	body.global_position = anchor
	body.look_at(cultist.global_position, Vector3.UP)
	body.rotation.z = 0.0
	var intake: Vector3 = SMART_OBJECTS[&"tunnel_intake"]["approach"]
	if cultist.global_position.distance_to(intake) <= 0.85:
		_session.patron_destination_reached(patron_id)


func _set_body_collision(actor: NavigableActor3D, enabled: bool) -> void:
	actor.collision_layer = 2 if enabled else 0
	actor.collision_mask = (3 if bool(actor.get_meta("is_cultist", false)) else 1) if enabled else 0
	actor.navigation_agent.avoidance_enabled = enabled


func _refresh_entrance(state: Dictionary) -> void:
	if not _smart_object_plates.has(&"front_entrance"):
		return
	var plate := _smart_object_plates[&"front_entrance"] as MeshInstance3D
	var waiting_group: Dictionary = {}
	for group: Dictionary in state.get("arrival_groups", {}).values():
		if bool(group.get("waiting", false)) and not bool(group.get("missed", false)):
			waiting_group = group
			break
	var admission: Dictionary = state.get("admission", {})
	var door_open: bool = not admission.is_empty() and admission.get("phase", &"") == &"holding"
	var needs_attention: bool = not waiting_group.is_empty() and admission.is_empty()
	var wait_remaining := float(waiting_group.get("wait_remaining", 30.0))
	var pulse_speed := 7.0 if wait_remaining <= 10.0 else 3.0
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed)
	plate.visible = needs_attention or not admission.is_empty()
	plate.scale = Vector3.ONE * (1.0 + (0.10 if needs_attention else 0.04) * pulse)
	var label := plate.get_node("Name") as Label3D
	label.text = "KNOCK · ADMIT GROUP" if needs_attention else ("DOOR OPEN" if door_open else "OPENING")
	label.modulate = Color("f0c96b") if needs_attention else SMART_OBJECT_COLOR
	var mesh := plate.mesh as CylinderMesh
	mesh.material = _flat_material(
		Color("d2a43c") if needs_attention else SMART_OBJECT_COLOR,
		0.48 + (0.30 * pulse if needs_attention else 0.0)
	)
	if needs_attention:
		var group_id: StringName = waiting_group.get("id", &"")
		if group_id != _last_knock_group_id:
			_last_knock_group_id = group_id
			_entrance_knock_player.play()
	else:
		_last_knock_group_id = &""
	if _entrance_indicator != null:
		var world_position: Vector3 = SMART_OBJECTS[&"front_entrance"]["approach"]
		var screen := _camera.unproject_position(world_position)
		var viewport_size := get_viewport().get_visible_rect().size
		var offscreen: bool = (
			_camera.is_position_behind(world_position)
			or screen.x < 0.0 or screen.y < 0.0
			or screen.x > viewport_size.x or screen.y > viewport_size.y
		)
		_entrance_indicator.visible = needs_attention and offscreen
		if _entrance_indicator.visible:
			_entrance_indicator.position = Vector2(
				8.0 if screen.x < viewport_size.x * 0.5 else viewport_size.x - 160.0,
				clampf(screen.y, 40.0, viewport_size.y - 190.0)
			)


func _entrance_knock_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := int(stream.mix_rate * 0.34)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / float(stream.mix_rate)
		var value := 0.0
		for start: float in [0.0, 0.17]:
			var local := time - start
			if local >= 0.0 and local < 0.075:
				value += sin(local * TAU * 92.0) * exp(-local * 48.0)
		samples.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 12000.0))
	stream.data = samples
	return stream


func _sync_patron_navigation(patron_id: int, debug: Dictionary) -> void:
	var actor := _patron_nodes[patron_id] as NavigableActor3D
	var action: Dictionary = debug.get("behavior", {}).get("action_queue", {}).get("active", {})
	if action.is_empty():
		actor.cancel_navigation()
		_patron_visual_targets.erase(patron_id)
		return
	var action_id := int(action["id"])
	actor.set_speed_multiplier(_patron_speed_multiplier(debug["activity"]))
	var target := _patron_target(debug)
	var previous: Vector3 = _patron_visual_targets.get(patron_id, Vector3.INF)
	if previous.is_equal_approx(target) and (
		actor.active_action_id() == action_id or bool(action["payload"].get("navigation_arrived", true))
	):
		return
	_patron_visual_targets[patron_id] = target
	if debug["navigation_destination"] in [&"seat", &"drink"]:
		actor.navigate_path(action_id, _seat_approach_route(target))
	else:
		actor.navigate(action_id, target)


func _seat_approach_route(target: Vector3) -> Array[Vector3]:
	# The south aisle keeps paired Patrons from blocking each other on opposite
	# sides of a table. Only the last waypoint completes the simulation phase.
	return [Vector3(target.x, NAVIGATION_FLOOR_Y, 3.8), target]


func _patron_target(debug: Dictionary) -> Vector3:
	var destination: StringName = debug["navigation_destination"]
	if destination == &"step_aside":
		return debug["behavior"]["action_queue"]["active"]["payload"]["target"]["position"]
	if destination == &"step_aside_hold":
		return debug["behavior"]["hold_position"]
	if destination in [&"seat", &"drink"] and SEAT_POSITIONS.has(debug["seat"]):
		var seat: Vector2 = SEAT_POSITIONS[debug["seat"]]
		return Vector3(seat.x, NAVIGATION_FLOOR_Y, seat.y)
	match destination:
		&"entrance":
			var entrance_index := maxi(0, ALL_PATRON_IDS.find(int(debug.get("id", ActorIds.NO_ACTOR))))
			return Vector3(
				-16.8 - float(entrance_index % 2) * 0.7,
				NAVIGATION_FLOOR_Y,
				4.45 + float(entrance_index % 2) * 1.1
			)
		&"front_exit": return Vector3(-20.2, NAVIGATION_FLOOR_Y, 5.0)
		&"bathroom_line": return Vector3(15.5, NAVIGATION_FLOOR_Y, 6.0)
		# Distinct bathroom stations, west of the toilet and sink fixtures so the
		# walk stays on the navmesh: mirror at the visible back wall, toilet at the
		# fixture, sink toward the open foreground wall, exit back at the door.
		&"mirror": return Vector3(18.3, NAVIGATION_FLOOR_Y, 4.0)
		&"toilet": return Vector3(18.9, NAVIGATION_FLOOR_Y, 5.8)
		&"sink": return Vector3(18.7, NAVIGATION_FLOOR_Y, 7.5)
		&"bathroom_exit": return Vector3(16.8, NAVIGATION_FLOOR_Y, 6.0)
		&"bathroom": return Vector3(18.2, NAVIGATION_FLOOR_Y, 6.0)
		&"tunnel": return Vector3(15.0, NAVIGATION_FLOOR_Y, 3.65)
		&"collapsed":
			var at: Vector2 = debug["position"]
			return Vector3(at.x, NAVIGATION_FLOOR_Y, at.y)
	var fallback: Vector2 = debug["position"]
	return Vector3(fallback.x, NAVIGATION_FLOOR_Y, fallback.y)


func _patron_speed_multiplier(activity: StringName) -> float:
	if activity in [&"shock", &"escaping"]:
		return 1.4
	if activity in [&"helper_reacting", &"helper_lifting", &"helper_carrying"]:
		return 0.6
	if activity == &"being_dragged":
		return 0.58
	return 1.0


func _on_patron_destination_reached(patron_id: int, action_id: int) -> void:
	if not _movement_report_path.is_empty():
		return
	_session.patron_destination_reached(patron_id, action_id)
	if _latest_state.is_empty() or not _latest_state["debug_patron_views"].has(patron_id):
		return
	var debug: Dictionary = _latest_state["debug_patron_views"][patron_id]
	if debug["lifecycle"] in [&"captured", &"exited"]:
		(_patron_nodes[patron_id] as Node3D).visible = false


func _on_patron_navigation_stuck(patron_id: int, action_id: int) -> void:
	if not _patron_visual_targets.has(patron_id):
		return
	var actor := _patron_nodes[patron_id] as NavigableActor3D
	var target: Vector3 = _patron_visual_targets[patron_id]
	var navigation_map := get_world_3d().navigation_map
	var retry_target := NavigationServer3D.map_get_closest_point(navigation_map, target)
	actor.navigate(action_id, retry_target)


func _refresh_cultists(_state: Dictionary) -> void:
	if not _presentation_prototype:
		return
	for cultist_id: int in PLAYABLE_CULTIST_IDS:
		var pivot := _cultist_pivot(cultist_id)
		var knocked_out: bool = _state["incapacitated_cultists"].has(cultist_id)
		var actor := pivot as NavigableActor3D
		if knocked_out:
			actor.cancel_navigation()
		_set_body_collision(actor, not knocked_out)
		var sprite := pivot.get_node("VisualPivot/Body") as Sprite3D
		sprite.rotation.z = -PI * 0.5 if knocked_out else 0.0
		sprite.position.y = 0.42 if knocked_out else BARTENDER_FEET_FROM_CANVAS_CENTER_PIXELS * sprite.pixel_size
		var label := pivot.get_node("Name") as Label3D
		label.text = _cultist_display_name(cultist_id)
		var visual := pivot.get_node("VisualPivot") as AvatarMotionController
		var activity := StringName(_state["cultists"][cultist_id]["activity"])
		visual.set_context(
			AvatarMotionController.GAIT_WALK, actor.is_navigating(),
			not actor.is_navigating() and activity != &"idle", knocked_out
		)


func _refresh_bodies() -> void:
	for child in _body_root.get_children():
		child.queue_free()
	for body: Dictionary in _staged_bodies:
		var marker := _build_box(body["position"], Vector3(1.4, 0.35, 0.65), 0.18, Color("c8434f"))
		_body_root.add_child(marker)
		var label := Label3D.new()
		label.text = "BODY"
		label.position = Vector3(body["position"].x, 0.8, body["position"].y)
		label.font_size = 44
		label.pixel_size = 0.007
		label.modulate = Color("f0a0a8")
		label.outline_size = 14
		label.outline_modulate = Color("0b1016")
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_body_root.add_child(label)


func _refresh_events(state: Dictionary) -> void:
	for child in _event_root.get_children():
		child.queue_free()
	for event: Dictionary in _events:
		if event["channel"] == &"auditory":
			_render_auditory(event, state)
		else:
			_render_visual(event, state)


# Vision reads as a point source with a sightline to each Patron that has a clear
# view. An event nobody sees keeps its marker but greys out and draws no line, so
# the facing-cone miss is visible rather than hidden.
func _render_visual(event: Dictionary, state: Dictionary) -> void:
	var recipients: Array = event["recipients"]
	var seen := not recipients.is_empty()
	var color: Color = SEEN_COLOR if seen else UNSEEN_COLOR
	var source: Vector2 = event["position"]
	_event_root.add_child(_build_box(source, Vector3(0.5, 1.7, 0.5), 0.85, color))
	_event_root.add_child(_marker_label(source, 2.1, "SEEN" if seen else "UNSEEN", color))
	for patron_id: int in recipients:
		if not state["debug_patron_views"].has(patron_id):
			continue
		var target: Vector2 = state["debug_patron_views"][patron_id]["position"]
		_event_root.add_child(_build_ray(source, target))


# Sound fills the room it happens in and faintly washes the rooms it carries to,
# with a ring under each Patron that hears it. A room the sound never reaches is
# simply not filled, so an unheard event reads as a fill that stops short.
func _render_auditory(event: Dictionary, state: Dictionary) -> void:
	var source_room: StringName = event["room"]
	_event_root.add_child(_room_overlay(source_room, SOUND_COLOR, 0.34, 0.16))
	_event_root.add_child(_marker_label(_room_center(source_room), 1.9, "SOUND", SOUND_COLOR))
	var adjacency: Dictionary = PATRON_PERCEPTION_SCRIPT.ROOM_ADJACENCY
	for reached_room: StringName in adjacency.get(source_room, []):
		_event_root.add_child(_room_overlay(reached_room, SOUND_COLOR, 0.14, 0.14))
	for patron_id: int in event["recipients"]:
		if not state["debug_patron_views"].has(patron_id):
			continue
		var at: Vector2 = state["debug_patron_views"][patron_id]["position"]
		_event_root.add_child(_feet_ring(at, SOUND_COLOR, 0.9))


func _build_ray(from_sim: Vector2, to_sim: Vector2) -> MeshInstance3D:
	var from := Vector3(from_sim.x, 0.9, from_sim.y)
	var to := Vector3(to_sim.x, 0.9, to_sim.y)
	var instance := MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(0.08, 0.08, from.distance_to(to))
	instance.mesh = beam
	instance.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	instance.material_override = _flat_material(RAY_COLOR, 1.0)
	return instance


func _room_overlay(room_id: StringName, color: Color, alpha: float, y: float) -> MeshInstance3D:
	var rect: Array = ROOM_RECTS[room_id]
	var center := _room_center(room_id)
	return _build_box(center, Vector3(rect[2] - rect[0], 0.04, rect[3] - rect[1]), y, Color(color.r, color.g, color.b, alpha), true)


func _feet_ring(sim_position: Vector2, color: Color, radius: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _ring_mesh(radius, 0.14)
	instance.position = Vector3(sim_position.x, 0.08, sim_position.y)
	instance.material_override = _flat_material(color, 0.95)
	return instance


func _marker_label(sim_position: Vector2, height: float, text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(sim_position.x, height, sim_position.y)
	label.font_size = 40
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 14
	label.outline_modulate = Color("0b1016")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return label


func _room_center(room_id: StringName) -> Vector2:
	var rect: Array = ROOM_RECTS[room_id]
	return Vector2((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5)


# --- Scenario staging (mirrors the perception_danger slice) -------------------

func _set_scenario(scenario_id: String) -> void:
	if not SCENARIOS.has(scenario_id):
		scenario_id = "full_cast" if _presentation_prototype else "line_of_sight"
	_scenario = scenario_id
	_pause_menu_open = false
	_cancel_camera_focus()
	_staged_bodies.clear()
	_events.clear()
	_session.restart_night(707)
	if scenario_id == "night_start":
		pass
	elif scenario_id == "full_cast":
		_stage_full_cast()
	elif scenario_id == "drink_cycle":
		# This explicit checkpoint admits the first group so it opens with a real
		# Order, while the normal Night still requires the player to answer every knock.
		_session.advance(3.1)
		_session.begin_admit_group(1)
		_session.advance(15.0)
	elif scenario_id == "front_exit":
		_stage_full_cast()
		_session.advance(421.0 - float(_session.snapshot()["simulated_seconds"]))
	elif scenario_id == "service_wing":
		_stage_first_group(92.0)
	elif scenario_id == "cultist_states":
		_stage_first_group(95.0)
	else:
		_session.advance(100.0)
	match scenario_id:
		"night_start":
			_scenario_trace = "A fresh 18-minute Night begins at 8:00 PM with no staged progress."
		"drink_cycle":
			_scenario_trace = "The first group is inside with an open Order. Prepare a Drink at the bar, then serve it to complete the core service cycle."
		"full_cast":
			_scenario_trace = "Both playable Cultists and all eight authored Patrons share the full-scale room. Distinct palettes, names, visible activities, and Suspicion bands come from one GameSession snapshot."
		"service_wing":
			_session.debug_force_bathroom(4)
			_session.advance(2.1)
			_scenario_trace = "The hallway preserves the proven east-side route. The bathroom shows its standing zone, seated fixture, and Trapdoor; the curtained Tunnel Intake remains a separate threshold."
		"front_exit":
			_session.report_patron_stimulus(10, &"drink_dosed_seen")
			_session.advance(2.2)
			_scenario_trace = "The seven-metre front approach ends at the street doors. Vincent's visible Escape intention occupies the same front-exit coordinates used by GameSession."
		"cultist_states":
			_session.begin_knockout(1, 4)
			_session.begin_conversation(2, 5)
			_session.prepare_drugged_drink(5, 3)
			_scenario_trace = "The public snapshot labels three simultaneous observable states: knockout wind-up, conversation, and Drugged Drink preparation."
		"line_of_sight":
			_record_event(&"body_drag_seen_first", &"visual", &"main_hall", 1, Vector2(0.0, 0.0))
			_record_event(&"unexplained_collapse_seen", &"visual", &"main_hall", 1, Vector2(-18.0, 6.0))
			_scenario_trace = "Drag at the bar is inside the facing cone: SEEN (+50). A collapse behind the pair falls outside the cone: UNSEEN, no line."
		"room_hearing":
			_record_event(&"knockout_heard", &"auditory", &"main_hall", 2, Vector2(0.0, 0.0))
			_record_event(&"knockout_heard", &"auditory", &"bathroom", 2, Vector2(18.0, 6.0))
			_scenario_trace = "Main-hall knockout fills the hall and reaches the pair (+25). The bathroom knockout fills only bathroom + hallway and never reaches them."
		"unattended_body":
			_stage_body(1001, &"hallway", Vector2(14.0, 6.0))
			_stage_body(1002, &"main_hall", Vector2(0.0, 8.0))
			_session.advance(8.0)
			_scenario_trace = "Two bodies past their grace add +5 each every 5 s to every active Patron. Press play to watch it climb."
		"companion":
			_session.report_patron_stimulus(4, &"drink_dosed_seen")
			_session.advance(10.0)
			_scenario_trace = "June is pinned at Maximum. Press play: Mara drifts up to +5 every 10 s and settles at 100 → Escape."
		"debug_trace":
			_record_event(&"knockout_heard", &"auditory", &"main_hall", 2, Vector2(0.0, 0.0))
			_stage_body(1001, &"main_hall", Vector2(0.0, 8.0))
			_session.advance(8.0)
			_scenario_trace = "Every perception is named in the debug panel: source, recipient, resulting cause, and timing."
	_session.set_physical_patron_navigation_enabled(true)
	# The interactive Night starts running at 1x. A rendered capture or a
	# validation report drives the Night at its own requested speed; resetting the
	# playback to 1x keeps the session scale nonzero so those advances still run.
	_playback.reset(_session, 1.0)
	_update_camera_for_scenario()
	_refresh(_session.snapshot())


# Opens one HUD state for an approval capture. It touches presentation only: no
# gameplay rule, outcome, or Night state changes because of it.
func _preview_hud_state(state_id: String) -> void:
	if state_id.is_empty() or _bottom_hud == null:
		return
	_hud_preview = ""
	_movement_feedback = ""
	_feedback_serial += 1
	match state_id:
		"quiet", "running_1", "empty_queue":
			_refresh_hud(_session.snapshot())
		"plain_pause_2":
			_submit_playback(&"select_speed", {"value": 2.0})
			_submit_playback(&"toggle_plain_pause", {})
		"escape_lock":
			_submit_playback(&"select_speed", {"value": 4.0})
			_session.report_patron_stimulus(11, &"drink_dosed_seen")
			_session.advance(0.2)
			_playback.synchronize()
			_refresh_hud(_session.snapshot())
		"settings":
			_bottom_hud.activate(&"settings_menu")
		"developer":
			_bottom_hud.activate(&"developer_menu")
		"clock_hover":
			_bottom_hud.preview_clock_hover()
		"speed_2":
			_submit_playback(&"select_speed", {"value": 2.0})
		"speed_4":
			_submit_playback(&"select_speed", {"value": 4.0})
		"offscreen":
			_stage_emote_states()
			_set_camera_view(SERVICE_CAMERA_POSITION, SERVICE_CAMERA_TARGET)
			_advance_emotes(0.0)
		"controls":
			_open_controls(true)
		"pause":
			_open_pause_menu()
		"pause_from_plain":
			_submit_playback(&"select_speed", {"value": 2.0})
			_submit_playback(&"toggle_plain_pause", {})
			_open_pause_menu()
		"queue":
			_issue_command(&"talk", _actor_target(4), false)
			_issue_command(
				&"move", _floor_target(Vector3(-6.0, NAVIGATION_FLOOR_Y, 4.0)), true
			)
			_issue_command(&"make_wine", _smart_target(&"bar_work_position"), true)
		"long_queue":
			for index in range(10):
				_issue_command(
					&"move",
					_floor_target(Vector3(-8.0 + float(index), NAVIGATION_FLOOR_Y, 4.0)),
					index > 0
				)
		"move_talk_chain":
			_issue_command(&"talk", _actor_target(4), false)
		"chain_unrelated":
			_issue_command(&"talk", _actor_target(4), false)
			_issue_command(
				&"move", _floor_target(Vector3(-6.0, NAVIGATION_FLOOR_Y, 4.0)), true
			)
		_:
			_hud_preview_outcome = StringName(state_id.trim_prefix("outcome_"))
			_refresh_hud(_session.snapshot())


# True while a rendered capture or a validation report drives the Night.
func _is_automated_run() -> bool:
	if _capture_mode:
		return true
	for flag: String in [
		"--capture=", "--report=", "--movement-report=", "--command-report=",
		"--emote-report=",
	]:
		if not _command_line_value(flag).is_empty():
			return true
	return false


func _stage_full_cast() -> void:
	var configured: Dictionary = {}
	for arrival: float in [3.0, 93.0, 213.0, 333.0]:
		_session.advance(arrival - float(_session.snapshot()["simulated_seconds"]))
		_session.begin_admit_group(1)
		_session.advance(4.2)
		_session.command_action_state(&"admit_group", 1, &"front_entrance")
		for patron_id: int in _session.snapshot()["debug_patron_views"]:
			var patron: Dictionary = _session.snapshot()["debug_patron_views"][patron_id]
			if patron["lifecycle"] != &"active" or configured.has(patron_id):
				continue
			_session.debug_set_patron_drink_state(patron_id, 0, 5, 0, 0)
			configured[patron_id] = true


func _stage_first_group(target_seconds: float) -> void:
	_session.advance(3.1)
	_session.begin_admit_group(1)
	_session.advance(4.2)
	_session.command_action_state(&"admit_group", 1, &"front_entrance")
	if float(_session.snapshot()["simulated_seconds"]) < target_seconds:
		_session.advance(target_seconds - float(_session.snapshot()["simulated_seconds"]))


func _update_camera_for_scenario() -> void:
	if not _presentation_prototype:
		return
	match _scenario:
		"service_wing":
			_set_camera_view(SERVICE_CAMERA_POSITION, SERVICE_CAMERA_TARGET)
		"front_exit":
			_set_camera_view(FRONT_CAMERA_POSITION, FRONT_CAMERA_TARGET)
		_:
			_set_camera_view(PRESENTATION_CAMERA_POSITION, PRESENTATION_CAMERA_TARGET)


func _set_camera_view(position: Vector3, target: Vector3) -> void:
	_camera.position = position
	_camera_target = target
	_camera.fov = PRESENTATION_CAMERA_FOV
	_camera_fov_target = PRESENTATION_CAMERA_FOV
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)


func _record_event(stimulus: StringName, channel: StringName, room: StringName, source_id: Variant, position: Vector2) -> void:
	var recipients: Array = _session.report_danger_event(stimulus, channel, room, source_id, position)
	_events.append({"channel": channel, "room": room, "position": position, "recipients": recipients})


func _stage_body(body_id: int, room: StringName, position: Vector2) -> void:
	_session.add_unattended_body(body_id, room, position)
	_staged_bodies.append({"id": body_id, "position": position})


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_entrance_indicator = Button.new()
	_entrance_indicator.text = "KNOCK · FRONT DOOR"
	_entrance_indicator.visible = false
	_entrance_indicator.custom_minimum_size = Vector2(152.0, 32.0)
	_entrance_indicator.pressed.connect(_focus_camera_on_entrance)
	canvas.add_child(_entrance_indicator)
	_entrance_knock_player = AudioStreamPlayer.new()
	_entrance_knock_player.stream = _entrance_knock_stream()
	add_child(_entrance_knock_player)

	_hover_panel = PanelContainer.new()
	_hover_panel.visible = false
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.custom_minimum_size = Vector2(235.0, 112.0)
	_hover_panel.add_theme_stylebox_override("panel", _inspection_panel_style(0.94))
	canvas.add_child(_hover_panel)
	_hover_label = RichTextLabel.new()
	_hover_label.bbcode_enabled = true
	_hover_label.fit_content = true
	_hover_label.scroll_active = false
	_hover_label.custom_minimum_size = Vector2(213.0, 90.0)
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_child(_hover_label)

	_context_menu = PanelContainer.new()
	_context_menu.visible = false
	_context_menu.custom_minimum_size = Vector2(248.0, 40.0)
	_context_menu.add_theme_stylebox_override("panel", _inspection_panel_style(0.98))
	canvas.add_child(_context_menu)
	var menu_column := VBoxContainer.new()
	menu_column.add_theme_constant_override("separation", 3)
	_context_menu.add_child(menu_column)
	_context_menu_header = Label.new()
	_context_menu_header.add_theme_color_override("font_color", Color("e2a56e"))
	_context_menu_header.add_theme_font_size_override("font_size", 13)
	menu_column.add_child(_context_menu_header)
	_context_menu_rows = VBoxContainer.new()
	_context_menu_rows.add_theme_constant_override("separation", 2)
	menu_column.add_child(_context_menu_rows)

	# The debug trace is a developer overlay now, not a permanent panel. It is
	# hidden until the Developer menu asks for it.
	_debug_panel = PanelContainer.new()
	_debug_panel.visible = false
	_debug_panel.position = Vector2(18.0, 16.0)
	_debug_panel.custom_minimum_size = Vector2(430.0, 150.0)
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var debug_style := StyleBoxFlat.new()
	debug_style.bg_color = Color(0.03, 0.04, 0.06, 0.86)
	debug_style.set_corner_radius_all(6)
	debug_style.set_content_margin_all(11)
	_debug_panel.add_theme_stylebox_override("panel", debug_style)
	canvas.add_child(_debug_panel)
	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = true
	_debug_label.scroll_active = false
	_debug_label.custom_minimum_size = Vector2(408.0, 130.0)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.add_child(_debug_label)

	_bottom_hud = BOTTOM_HUD_SCENE.instantiate() as BottomHud
	add_child(_bottom_hud)
	_bottom_hud.intent_submitted.connect(_on_hud_intent)

	_emote_overlay = EMOTE_OVERLAY_SCRIPT.new() as EmoteOverlay
	_emote_overlay.name = "EmoteOverlay"
	add_child(_emote_overlay)
	_emote_overlay.configure(_camera)
	_emote_overlay.set_accessible_labels(_emote_labels)
	_emote_overlay.set_ui_scale(_emote_ui_scale)
	_emote_overlay.offscreen_indicator_pressed.connect(_focus_camera_on)


func _inspection_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, alpha)
	style.border_color = Color("8b6a48")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	return style


# The scale the visible actors move at. A rendered review or validation run
# drives the world itself; ordinary play follows the accepted Simulation Speed.
func _world_simulation_scale() -> float:
	if _capture_navigation_enabled:
		return AUTOMATED_RUN_SCALE
	return _accepted_time_scale


func _synchronize_actor_playback() -> void:
	var scale := _world_simulation_scale()
	for cultist_id: int in _cultist_nodes:
		(_cultist_nodes[cultist_id] as NavigableActor3D).set_simulation_scale(scale)
		(_cultist_nodes[cultist_id].get_node("VisualPivot") as AvatarMotionController).set_simulation_scale(scale)
	for patron_id: int in _patron_nodes:
		(_patron_nodes[patron_id] as NavigableActor3D).set_simulation_scale(scale)
		(_patron_nodes[patron_id].get_node("VisualPivot") as AvatarMotionController).set_simulation_scale(scale)


func _refresh_hud(state: Dictionary) -> void:
	# The simulation may have changed the scale on its own (an Escape forcing 1x),
	# so re-read the authority before drawing the playback controls.
	_playback.synchronize()
	_pause_menu_open = bool(_playback.snapshot()["pause_menu_open"])
	if _movement_feedback != _last_feedback:
		_last_feedback = _movement_feedback
		_feedback_serial += 1
	if _debug_panel != null:
		_debug_panel.visible = _debug_visible
		if _debug_visible:
			_debug_label.text = _debug_trace_text(state)
	if _bottom_hud != null:
		_bottom_hud.render(_hud_view(state))


# --- The HUD view ------------------------------------------------------------

# One place builds everything the Bottom HUD draws. It reads sanitized session
# state only: patron_view() and the Emote view, never the debug views.
func _hud_view(state: Dictionary) -> Dictionary:
	var elapsed: float = state["simulated_seconds"]
	var night_length: float = GAME_SESSION_SCRIPT.NIGHT_END_SECONDS
	var remaining := int(maxf(0.0, night_length - elapsed))
	var results: Dictionary = state["results"]
	var quota := maxi(1, int(results["capture_quota"]))
	var displayed_captures := int(results["captures"])
	if _hud_preview_outcome == &"victory":
		displayed_captures = quota
	var displayed_cause := _displayed_outcome_cause(results)
	var displayed_methods := _capture_method_rows(results)
	if _hud_preview_outcome == &"victory":
		displayed_methods = _maximum_capture_method_rows()
	return {
		"selected_cultist": _selected_cultist_view(state),
		"action_tiles": _action_tile_views(),
		"night": _night_view(state, remaining, elapsed, night_length),
		"inspected_patron": _inspected_patron_view(state),
		"outcome": {
			"visible": bool(results["visible"]) or not _hud_preview_outcome.is_empty(),
			"kind": _outcome_kind(state, results),
			"cause": _outcome_cause(displayed_cause),
			"outcome_cause": displayed_cause,
			"captures": displayed_captures,
			"capture_quota": quota,
			"progress_ratio": clampf(float(displayed_captures) / float(quota), 0.0, 1.0),
			"capture_methods": displayed_methods,
			"revenue": int(results["revenue"]),
			"tips": int(results["tips"]),
			"orders_served": int(results["orders_served"]),
			"orders_cancelled": int(results["orders_cancelled"]),
			"orders_missed": int(results["orders_missed"]),
			"groups_missed_at_door": int(results.get("groups_missed_at_door", 0)),
			"suspicion_band": String(results["peak_suspicion_band"]),
			"interceptions": int(results["interceptions"]),
			"unattended_body_seconds": float(results["unattended_body_seconds"]),
		},
		"developer": {
			"visible": _debug_visible,
			"scenario_id": _scenario,
			"scenarios": _scenario_entries(),
		},
		"settings": {
			"emote_labels": _emote_labels,
			"ui_scale": _emote_ui_scale,
		},
		"controls": {
			"visible": _controls_visible,
			"dismiss_label": "Begin the Night" if _controls_first_run else "Close",
		},
		"feedback": {"text": _movement_feedback, "serial": _feedback_serial},
		"pause_menu_open": bool(_playback.snapshot()["pause_menu_open"]),
	}


# The playback half of the Night view comes from NightPlayback; the clock and
# progress half comes from the session snapshot. NightPlayback owns every
# selected-speed, Plain Pause, and Escape-lock decision.
func _night_view(
		state: Dictionary, remaining: int, elapsed: float, night_length: float
) -> Dictionary:
	var playback: Dictionary = _playback.snapshot()
	return {
		"clock_label": state["clock_label"],
		"clock_minutes": state["clock_minutes"],
		"closing_label": state["closing_label"],
		"remaining_label": "%dm %02ds" % [remaining / 60, remaining % 60],
		"progress_ratio": clampf(elapsed / night_length, 0.0, 1.0),
		"time_scale": playback["time_scale"],
		"selected_speed": playback["selected_speed"],
		"plain_paused": playback["plain_paused"],
		"speed_enabled": playback["speed_enabled"],
		"speed_lock_reason": playback["speed_lock_reason"],
		"phase": state["phase"],
	}


func _selected_cultist_view(state: Dictionary) -> Dictionary:
	if not state["cultists"].has(_selected_cultist_id):
		return {}
	var cultist: Dictionary = state["cultists"][_selected_cultist_id]
	var status := ""
	if _inspected_patron_id != ActorIds.NO_ACTOR:
		var patron: Dictionary = _session.patron_view(
			_inspected_patron_id, _selected_cultist_id
		)
		if not patron.is_empty():
			status = "%s selected" % patron["name"]
	return {
		"id": _selected_cultist_id,
		"name": _cultist_display_name(_selected_cultist_id),
		"portrait": BARTENDER_TEXTURE,
		"tint": CULTIST_COLORS.get(_selected_cultist_id, Color.WHITE),
		"activity": _humanize(cultist["activity"]),
		"inspected_patron_status": status,
	}


func _action_tile_views() -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	var cultists: Dictionary = _commands.snapshot()["cultists"]
	if not cultists.has(_selected_cultist_id):
		return tiles
	var queue: Dictionary = cultists[_selected_cultist_id]
	var active: Dictionary = queue["active"]
	if not active.is_empty():
		tiles.append(_action_tile_view(active, true))
	for entry: Dictionary in queue["pending"]:
		tiles.append(_action_tile_view(entry, false))
	return tiles


func _action_tile_view(action: Dictionary, is_active: bool) -> Dictionary:
	var action_progress: Variant = action.get("progress_ratio", null)
	if action_progress == null and is_active:
		action_progress = _active_navigation_ratio(int(action["id"]))
	return {
		"id": int(action["id"]),
		"icon": action.get("icon", action["command"]),
		"label": action["label"],
		"target_label": action["target_label"],
		"active": is_active,
		"cancellable": bool(action["cancellable"]),
		"progress_ratio": action_progress if is_active else null,
		"chain_id": int(action.get("chain_id", -1)),
		"chain_index": int(action.get("chain_index", 0)),
		"chain_size": int(action.get("chain_size", 1)),
		"generated": bool(action.get("generated", false)),
	}


# A fill appears only for a real, stable ratio: the Selected Cultist must be
# navigating for this very Action. Otherwise the tile reads as active with no
# invented percentage.
func _active_navigation_ratio(action_id: int) -> Variant:
	if not _cultist_nodes.has(_selected_cultist_id):
		return null
	var actor := _cultist_nodes[_selected_cultist_id] as NavigableActor3D
	if actor.active_action_id() != action_id:
		return null
	return actor.navigation_progress_ratio()


func _inspected_patron_view(state: Dictionary) -> Dictionary:
	if _inspected_patron_id == ActorIds.NO_ACTOR:
		return {}
	if not _patron_is_present(state, _inspected_patron_id):
		_inspected_patron_id = ActorIds.NO_ACTOR
		return {}
	var view: Dictionary = _session.patron_view(_inspected_patron_id, _selected_cultist_id)
	if view.is_empty():
		return {}
	var result := {
		"id": _inspected_patron_id,
		"name": view["name"],
		"portrait": BARTENDER_TEXTURE,
		"tint": PATRON_COLORS.get(_inspected_patron_id, Color.WHITE),
		"visible_activity": view["visible_activity"],
		"mood": view["mood"],
		"suspicion_band": view["suspicion_band"],
		"intoxication": view["intoxication"],
		"order_state": _humanize(view["order_state"]),
		"ordered_drink": String(view["ordered_drink"]).capitalize(),
	}
	if _debug_visible:
		var debug: Dictionary = state["debug_patron_views"][_inspected_patron_id]
		result["debug_action_queue"] = debug["behavior"]["action_queue"]
		result["debug_planner_paused"] = debug["behavior"]["planner_paused"]
	return result


# Presence comes from the sanitized Emote view, so no player-facing decision
# reads the debug views.
func _patron_is_present(state: Dictionary, patron_id: int) -> bool:
	var emotes: Dictionary = state["emote_view"]
	return emotes.has(patron_id) and bool(emotes[patron_id]["present"]) and bool(
		state["normal_patron_views"].get(patron_id, {}).get("interactive", true)
	)


func _scenario_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for scenario_id: String in SCENARIOS:
		entries.append({"id": scenario_id, "label": SCENARIOS[scenario_id]})
	return entries


func _outcome_kind(_state: Dictionary, results: Dictionary) -> StringName:
	if not _hud_preview_outcome.is_empty():
		return _hud_preview_outcome
	match StringName(results.get("outcome", &"running")):
		&"success":
			return &"victory"
		&"defeat":
			return &"exposed"
		_:
			return &"failed"


func _displayed_outcome_cause(results: Dictionary) -> StringName:
	match _hud_preview_outcome:
		&"victory":
			return &"quota_met"
		&"failed":
			return &"quota_shortfall"
		&"exposed":
			return &"maximum_suspicion_escape"
	return StringName(results.get("outcome_cause", &""))


func _outcome_cause(cause: StringName) -> String:
	match cause:
		&"quota_met":
			return "The Night closed with the Capture quota met and no alarm raised."
		&"maximum_suspicion_escape":
			return "A Patron reached the street while at Maximum Suspicion. The speakeasy is exposed."
		&"quota_shortfall":
			return "The Night closed short of the Capture quota."
	return ""


# Captures grouped by their causal method, in the canonical order, with the
# zero-total methods dropped so the Outcome report shows only what happened.
func _capture_method_rows(results: Dictionary) -> Array:
	var counts: Dictionary = results.get("capture_methods", {})
	var rows: Array = []
	for entry: Array in CAPTURE_METHOD_LABELS:
		var count := int(counts.get(entry[0], 0))
		if count > 0:
			rows.append({"label": entry[1], "count": count})
	return rows


func _maximum_capture_method_rows() -> Array:
	var rows: Array = []
	for entry: Array in CAPTURE_METHOD_LABELS:
		rows.append({"label": entry[1], "count": 1})
	return rows


# --- Player intent -----------------------------------------------------------

# Every piece of HUD intent lands here, in one match. Nothing else in the scene
# reads a HUD control.
func _on_hud_intent(kind: StringName, payload: Dictionary) -> void:
	match kind:
		&"set_time_scale":
			_submit_playback(&"select_speed", {"value": float(payload["value"])})
		&"toggle_pause":
			_submit_playback(&"toggle_plain_pause", {})
		&"cancel_active_action":
			_cancel_active_action(int(payload.get("action_id", -1)))
		&"remove_pending_action":
			_on_pending_removed(int(payload["action_id"]))
		&"close_inspected_patron":
			_inspected_patron_id = ActorIds.NO_ACTOR
			_refresh_hud(_session.snapshot())
		&"open_pause_menu":
			_close_context_menu()
			_submit_playback(&"open_pause_menu", {})
		&"open_controls":
			_open_controls(false)
		&"close_controls":
			_close_controls()
		&"reset_controls_card":
			_reset_controls_card()
			_refresh_hud(_session.snapshot())
		&"dismiss_pause_menu":
			_submit_playback(&"dismiss_pause_menu", {})
		&"resume_night":
			_submit_playback(&"resume_from_pause_menu", {})
		&"restart_night":
			get_tree().reload_current_scene()
		&"quit_game":
			get_tree().quit()
		&"select_scenario":
			_set_scenario(String(payload["scenario_id"]))
		&"advance_debug_time":
			_advance_debug_time(float(payload["seconds"]))
		&"set_debug_visible":
			_debug_visible = bool(payload["enabled"])
			_refresh(_session.snapshot())
		&"debug_cancel_patron_action":
			_session.debug_cancel_patron_action(
				int(payload["patron_id"]), int(payload["action_id"]),
				(_patron_nodes[int(payload["patron_id"])] as Node3D).global_position
			)
			_refresh(_session.snapshot())
		&"debug_force_patron_action":
			_session.debug_force_complete_patron_action(int(payload["patron_id"]))
			_refresh(_session.snapshot())
		&"debug_clear_patron_queue":
			_session.debug_clear_patron_queue(int(payload["patron_id"]))
			_refresh(_session.snapshot())
		&"debug_pause_patron_planner":
			_session.debug_set_patron_planner_paused(
				int(payload["patron_id"]), bool(payload["paused"])
			)
			_refresh_hud(_session.snapshot())
		&"set_emote_labels":
			_set_emote_accessibility(bool(payload["enabled"]), _emote_ui_scale)
			_save_settings()
			_refresh_hud(_session.snapshot())
		&"set_ui_scale":
			_set_emote_accessibility(_emote_labels, float(payload["scale"]))
			_save_settings()
			_refresh_hud(_session.snapshot())


# Keyboard shortcuts go through the HUD, so an open modal blocks them in one
# place instead of in two.
func _handle_hud_shortcut(event: InputEvent) -> bool:
	if _bottom_hud == null or not (event is InputEventKey) or event.is_echo():
		return false
	if event.is_action_pressed("open_pause_menu"):
		if _context_menu != null and _context_menu.visible:
			_close_context_menu()
		else:
			_bottom_hud.activate(&"escape")
		return true
	for action: String in ["simulation_speed_1", "simulation_speed_2", "simulation_speed_4"]:
		if event.is_action_pressed(action):
			_bottom_hud.activate(StringName(action.replace("simulation_", "")))
			return true
	if event.is_action_pressed("simulation_toggle_pause"):
		_bottom_hud.activate(&"toggle_pause")
		return true
	return false


# One route for playback intent. NightPlayback owns the transitions; GameSession
# stays the authority that accepts or rejects a time scale. A refusal carries a
# display-ready line, which the HUD's feedback area shows.
func _submit_playback(kind: StringName, payload: Dictionary) -> void:
	var result: Dictionary = _playback.submit(kind, payload)
	var feedback := String(result.get("feedback", ""))
	if not feedback.is_empty():
		_movement_feedback = feedback
		# A repeated refusal must show again, even with the same words.
		_feedback_serial += 1
	_refresh_hud(_session.snapshot())


func _advance_debug_time(seconds: float) -> void:
	var restore := _session.current_time_scale()
	_session.set_time_scale(1.0)
	_session.advance(seconds)
	_session.set_time_scale(restore)
	_playback.synchronize()
	_refresh_hud(_session.snapshot())


func _open_pause_menu() -> void:
	_close_context_menu()
	_submit_playback(&"open_pause_menu", {})


# Shows the first-run Controls Card before any Night time advances. It stays
# armed until the player dismisses it, once per installation.
func _arm_first_run_controls() -> void:
	if _controls_seen:
		return
	_open_controls(true)


func _open_controls(first_run: bool) -> void:
	_controls_first_run = first_run
	_controls_visible = true
	_refresh_hud(_session.snapshot())


# Closing the first-run card starts the held Night and records that the guide was
# seen; reopening it from the Pause Menu leaves that record and the Night alone.
func _close_controls() -> void:
	if _controls_first_run and not _controls_seen:
		_controls_seen = true
		_save_settings()
	_controls_visible = false
	_controls_first_run = false
	_refresh_hud(_session.snapshot())


# Developer reset: re-arm the blocking card for the next Night start.
func _reset_controls_card() -> void:
	_controls_seen = false
	_save_settings()
	_movement_feedback = "Controls Card reset. It appears on the next Night start."


# Cancelling the active tile cascades through its whole Action Chain, so a
# Generated Move and its dependent Patron Action leave together.
func _cancel_active_action(_action_id: int = -1) -> void:
	var outcome: Dictionary = _commands.request_cancel_active(_selected_cultist_id)
	_movement_feedback = outcome["message"]
	_sync_cultist_navigation(_selected_cultist_id)
	_refresh_move_markers()
	_refresh_hud(_session.snapshot())


# Removing a pending tile removes every unfinished link of its Action Chain.
func _on_pending_removed(action_id: int) -> void:
	if _commands.remove_pending(_selected_cultist_id, action_id):
		_sync_cultist_navigation(_selected_cultist_id)
		_refresh_move_markers()
		_refresh_hud(_session.snapshot())


# --- Settings ----------------------------------------------------------------

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_emote_labels = bool(config.get_value("hud", "emote_labels", _emote_labels))
	_emote_ui_scale = clampf(
		float(config.get_value("hud", "ui_scale", _emote_ui_scale)), 0.75, 1.5
	)
	_controls_seen = bool(config.get_value("hud", "controls_seen", _controls_seen))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("hud", "emote_labels", _emote_labels)
	config.set_value("hud", "ui_scale", _emote_ui_scale)
	config.set_value("hud", "controls_seen", _controls_seen)
	config.save(SETTINGS_PATH)


# --- Hover Summary and debug trace -------------------------------------------

func _refresh_character_panels(state: Dictionary) -> void:
	if _hover_panel == null:
		return
	if not _hovered_drink_id.is_empty():
		var drink: Dictionary = _session.prepared_drink(_hovered_drink_id)
		if drink.is_empty():
			_hover_panel.visible = false
			return
		_hover_label.text = _drink_summary_text(drink)
		_hover_panel.visible = true
		return
	if _hovered_actor_id == ActorIds.NO_ACTOR:
		_hover_panel.visible = false
		return
	if _hovered_is_cultist and state["cultists"].has(_hovered_actor_id):
		_hover_label.text = _cultist_summary_text(_hovered_actor_id, state)
		_hover_panel.visible = true
		return
	if _patron_is_present(state, _hovered_actor_id):
		_hover_label.text = _patron_summary_text(_hovered_actor_id, state)
		_hover_panel.visible = true
	else:
		_hover_panel.visible = false


func _cultist_summary_text(cultist_id: int, state: Dictionary) -> String:
	var cultist: Dictionary = state["cultists"][cultist_id]
	var queues: Dictionary = _commands.snapshot()["cultists"]
	var queue_count: int = int(queues[cultist_id]["action_count"]) if queues.has(cultist_id) else 0
	return "[color=#8fc4af][b]%s[/b][/color]\nStatus  %s\nAction Queue  %d" % [
		_cultist_display_name(cultist_id), _humanize(cultist["activity"]), queue_count,
	]


func _patron_summary_text(patron_id: int, state: Dictionary) -> String:
	var view: Dictionary = _session.patron_view(patron_id, _selected_cultist_id)
	var order_text := _humanize(view["order_state"])
	if not String(view["ordered_drink"]).is_empty():
		order_text += " · %s" % String(view["ordered_drink"]).capitalize()
	return "[color=#e2a56e][b]%s[/b][/color]\n%s · %s\nMood  %s\nIntoxication  %s\nOrder  %s" % [
		view["name"], view["visible_activity"], view["suspicion_band"],
		_humanize(view["mood"]), view["intoxication"], order_text,
	]


func _drink_summary_text(drink: Dictionary) -> String:
	return "[color=#d9c56f][b]%s[/b][/color]\nStatus  %s" % [
		String(drink["type"]).capitalize(), "Drugged" if bool(drink["drugged"]) else "Prepared",
	]


func _debug_trace_text(state: Dictionary) -> String:
	var seconds: float = state["simulated_seconds"]
	var text := "[color=#e2a56e][b]%s[/b][/color]   [color=#8195a2]t=%.1fs[/color]\n%s\n" % [
		SCENARIOS[_scenario], seconds, _scenario_trace,
	]
	text += "\n[color=#8fc4af][b]%s[/b][/color]  %s" % [
		_cultist_display_name(_selected_cultist_id), _movement_feedback,
	]
	for patron_id: int in PATRON_IDS:
		var debug: Dictionary = state["debug_patron_views"][patron_id]
		var name := str(patron_id).trim_prefix("patron_").capitalize()
		text += "\n[color=#c9b6da]%s[/color]  %s  ·  %.0f/100  ·  %s" % [
			name, _humanize(debug["room"]), debug["suspicion"], _humanize(debug["suspicion_cause"]),
		]
		var trace: Array = debug["recent_perceptions"]
		for index in range(maxi(0, trace.size() - 3), trace.size()):
			var entry: Dictionary = trace[index]
			text += "\n   [color=#8195a2]%.1fs %s > %s = %s[/color]" % [
				entry["at"], _humanize(entry["source"]), _humanize(entry["recipient"]),
				_humanize(entry["cause"]),
			]
	return text


# --- Helpers -----------------------------------------------------------------

func _humanize(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()


func _command_line_value(prefix: String, fallback: String = "") -> String:
	return _review_harness.value(prefix, fallback)


func _command_line_flag(flag: String) -> bool:
	return _review_harness.flag(flag)


func _capture_after_render(capture_path: String, wait_frames: int = 6) -> void:
	await _review_harness.capture_after_render(
		self, capture_path, wait_frames, _emote_play_scale
	)


func _write_validation_report(report_path: String) -> void:
	await _review_harness.write_validation_report(self, report_path, {
		"visual_spike_source": VISUAL_SPIKE_SOURCE,
		"visual_spike_expected_sha256": VISUAL_SPIKE_EXPECTED_SHA256,
		"patron_palette_count": PATRON_COLORS.size(),
		"cultist_visible_height_metres": CULTIST_VISIBLE_HEIGHT_METRES,
		"camera_pan_speed": CAMERA_PAN_SPEED,
		"camera_pan_acceleration": CAMERA_PAN_ACCELERATION,
		"camera_pan_deceleration": CAMERA_PAN_DECELERATION,
	})


func _floor_is_left_of(left_floor: MeshInstance3D, right_floor: MeshInstance3D) -> bool:
	if left_floor == null or right_floor == null:
		return false
	var left_mesh := left_floor.mesh as BoxMesh
	var right_mesh := right_floor.mesh as BoxMesh
	return (
		left_floor.position.x + left_mesh.size.x * 0.5
		<= right_floor.position.x - right_mesh.size.x * 0.5 + 0.001
	)


func _floor_tile_metres(floor: MeshInstance3D) -> Vector2:
	if floor == null:
		return Vector2.ZERO
	var mesh := floor.mesh as BoxMesh
	var material := floor.material_override as StandardMaterial3D
	if mesh == null or material == null:
		return Vector2.ZERO
	return Vector2(mesh.size.x / material.uv1_scale.x, mesh.size.z / material.uv1_scale.y)


func _floor_tiles_are_square(floor: MeshInstance3D) -> bool:
	var tile_metres := _floor_tile_metres(floor)
	return tile_metres.x > 0.0 and is_equal_approx(tile_metres.x, tile_metres.y)


func _keyboard_zoom_keys_work() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_fov := _camera.fov
	var zoom_in := InputEventKey.new()
	zoom_in.keycode = KEY_EQUAL
	zoom_in.pressed = true
	_unhandled_input(zoom_in)
	for _frame in 30:
		_process(1.0 / 60.0)
	var zoomed_in_fov := _camera.fov
	var equals_zooms_in := zoomed_in_fov < original_fov
	var zoom_out := InputEventKey.new()
	zoom_out.keycode = KEY_MINUS
	zoom_out.pressed = true
	_unhandled_input(zoom_out)
	for _frame in 30:
		_process(1.0 / 60.0)
	var minus_zooms_out := _camera.fov > zoomed_in_fov
	_camera.fov = original_fov
	_camera_fov_target = original_fov
	_capture_mode = was_capture_mode
	return equals_zooms_in and minus_zooms_out


func _trackpad_pans_in_all_directions() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_position := _camera.position
	var original_target := _camera_target
	var gestures := [
		[Vector2(-1.0, 0.0), Vector3(-1.0, 0.0, 0.0)],
		[Vector2(1.0, 0.0), Vector3(1.0, 0.0, 0.0)],
		[Vector2(0.0, -1.0), Vector3(0.0, 0.0, -1.0)],
		[Vector2(0.0, 1.0), Vector3(0.0, 0.0, 1.0)],
	]
	var all_directions_work := true
	for gesture_case: Array in gestures:
		_camera.position = original_position
		_camera_target = original_target
		_camera_pan_velocity = Vector3.ZERO
		_trackpad_pan_intent = Vector2.ZERO
		_trackpad_pan_hold_remaining = 0.0
		var gesture := InputEventPanGesture.new()
		gesture.delta = gesture_case[0]
		_unhandled_input(gesture)
		_process(1.0 / 60.0)
		var shift: Vector3 = _camera.position - original_position
		var expected: Vector3 = gesture_case[1]
		all_directions_work = all_directions_work and shift.dot(expected) > 0.0
	_camera.position = original_position
	_camera_target = original_target
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)
	_capture_mode = was_capture_mode
	return all_directions_work


func _command_trackpad_zoom_is_smooth() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_position := _camera.position
	var original_target := _camera_target
	var original_fov := _camera.fov
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	var gesture := InputEventPanGesture.new()
	gesture.delta = Vector2(0.0, -2.0)
	gesture.meta_pressed = true
	_unhandled_input(gesture)
	var waits_for_frame := is_equal_approx(_camera.fov, original_fov)
	_process(1.0 / 60.0)
	var first_frame_fov := _camera.fov
	var starts_smoothly := first_frame_fov < original_fov and first_frame_fov > original_fov - 2.0
	for _frame in 30:
		_process(1.0 / 60.0)
	var continues_toward_target := _camera.fov < first_frame_fov
	var does_not_pan := _camera.position.is_equal_approx(original_position)
	_camera.position = original_position
	_camera_target = original_target
	_camera.fov = original_fov
	_camera_fov_target = original_fov
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)
	_capture_mode = was_capture_mode
	return waits_for_frame and starts_smoothly and continues_toward_target and does_not_pan


func _camera_pan_is_fast_and_eased() -> bool:
	var was_capture_mode := _capture_mode
	_capture_mode = false
	var original_position := _camera.position
	var original_target := _camera_target
	var delta := 1.0 / 60.0
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	var gesture := InputEventPanGesture.new()
	gesture.delta = Vector2(1.0, 0.0)
	_unhandled_input(gesture)
	var waits_for_frame := _camera.position.is_equal_approx(original_position)
	_process(delta)
	var first_step := (_camera.position - original_position).length()
	var previous_position := _camera.position
	var steady_step := first_step
	for _frame in 30:
		_unhandled_input(gesture)
		_process(delta)
		steady_step = (_camera.position - previous_position).length()
		previous_position = _camera.position
	var accelerates := steady_step > first_step * 2.0
	var faster_than_old_pan := steady_step / delta > 8.0
	_process(delta)
	var coast_step := (_camera.position - previous_position).length()
	var coasts_after_release := coast_step > 0.0
	for _frame in 45:
		_process(delta)
	var settled_position := _camera.position
	_process(delta)
	var settles_smoothly := _camera.position.is_equal_approx(settled_position)
	_camera.position = original_position
	_camera_target = original_target
	_camera_pan_velocity = Vector3.ZERO
	_trackpad_pan_intent = Vector2.ZERO
	_trackpad_pan_hold_remaining = 0.0
	_camera.look_at(_camera_target, Vector3.UP)
	_capture_mode = was_capture_mode
	return (
		waits_for_frame
		and first_step > 0.0
		and accelerates
		and faster_than_old_pan
		and coasts_after_release
		and settles_smoothly
	)


func _service_area_labels() -> Array[String]:
	var labels: Array[String] = []
	for node: Node in find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if label.text == "HALLWAY" or label.text.begins_with("BATHROOM"):
			labels.append(label.text)
	return labels


func _service_area_labels_are_correct() -> bool:
	var labels := _service_area_labels()
	return (
		labels.count("HALLWAY") == 1
		and labels.count("BATHROOM") == 0
		and labels.count("BATHROOM / TRAPDOOR") == 1
	)


func _service_and_front_buttons_use_consistent_camera() -> bool:
	var original_scenario := _scenario
	var original_position := _camera.position
	var original_target := _camera_target
	var original_fov := _camera.fov
	var normal_direction := (PRESENTATION_CAMERA_TARGET - PRESENTATION_CAMERA_POSITION).normalized()
	var scenarios := {
		"service_wing": Vector3(17.0, 1.0, 6.0),
		"front_exit": Vector3(-17.5, 1.0, 5.0),
	}
	var buttons_use_consistent_camera := true
	for scenario_id: String in scenarios:
		_set_scenario(scenario_id)
		var direction := (_camera_target - _camera.position).normalized()
		buttons_use_consistent_camera = buttons_use_consistent_camera and (
			_camera_target.is_equal_approx(scenarios[scenario_id])
			and direction.is_equal_approx(normal_direction)
			and is_equal_approx(_camera.fov, PRESENTATION_CAMERA_FOV)
		)
	_set_scenario(original_scenario)
	_camera.position = original_position
	_camera_target = original_target
	_camera.fov = original_fov
	_camera_fov_target = original_fov
	_camera.look_at(_camera_target, Vector3.UP)
	return buttons_use_consistent_camera
