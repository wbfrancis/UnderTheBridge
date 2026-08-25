extends GutTest

## Presentation checks for the Emote Overlay, including the Offscreen Indicators
## it draws for an urgent actor who has left the camera view.

const EMOTE_OVERLAY_PATH := "res://scripts/presentation/emote_overlay.gd"

const ONSCREEN := Vector3(0.0, 0.0, 0.0)
const OFFSCREEN_RIGHT := Vector3(120.0, 0.0, 0.0)
const OFFSCREEN_LEFT := Vector3(-120.0, 0.0, 0.0)
const BEHIND_CAMERA := Vector3(0.0, 0.0, 40.0)

var _overlay
var _camera: Camera3D


func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 0.0, 10.0)
	_camera.current = true
	world.add_child(_camera)
	_overlay = load(EMOTE_OVERLAY_PATH).new()
	add_child_autofree(_overlay)
	_overlay.configure(_camera)
	await get_tree().process_frame


func _bubble(actor_id: StringName, emote: StringName, display_name: String = "") -> Dictionary:
	var urgent := emote in [&"escaping", &"investigating", &"danger_reaction"]
	return {
		"actor_id": actor_id,
		"emote": emote,
		"category": &"persistent",
		"priority": 100 if urgent else 50,
		"icon": "!" if urgent else "U",
		"shape": &"burst" if urgent else &"circle",
		"color": "e65c70" if urgent else "d9c56f",
		"label": "Running" if urgent else "Wants a drink",
		"display_name": display_name,
	}


func _refresh(bubbles: Array[Dictionary], anchors: Dictionary) -> void:
	_overlay.refresh(bubbles, anchors)
	await get_tree().process_frame


# The Bottom HUD strip the scene must stay clear of.
func _hud_rect() -> Rect2:
	var viewport := get_viewport().get_visible_rect().size
	return Rect2(Vector2(0.0, viewport.y - 138.0), Vector2(viewport.x, 138.0))


func test_an_onscreen_urgent_actor_gets_a_bubble_and_no_indicator() -> void:
	await _refresh(
		[_bubble(&"patron_june", &"escaping", "June")],
		{&"patron_june": ONSCREEN}
	)

	assert_true(_overlay.placements().has(&"patron_june"),
		"An actor in view gets an ordinary Emote Bubble.")
	assert_true(_overlay.offscreen_indicators().is_empty(),
		"Nothing on screen needs an edge marker.")


func test_an_offscreen_urgent_actor_gets_one_edge_indicator() -> void:
	await _refresh(
		[_bubble(&"patron_june", &"escaping", "June")],
		{&"patron_june": OFFSCREEN_RIGHT}
	)

	var indicators: Dictionary = _overlay.offscreen_indicators()
	assert_eq(indicators.size(), 1, "One actor gets one indicator.")
	assert_true(indicators.has(&"patron_june"))
	assert_false(_overlay.placements().has(&"patron_june"),
		"An offscreen actor has no in-scene bubble to place.")

	var rect: Rect2 = indicators[&"patron_june"]["rect"]
	var viewport := get_viewport().get_visible_rect().size
	assert_true(Rect2(Vector2.ZERO, viewport).encloses(rect),
		"The indicator stays inside the screen.")
	assert_gt(rect.get_center().x, viewport.x * 0.5,
		"An actor off the right side gets a marker on the right edge.")


func test_an_actor_behind_the_camera_still_gets_an_indicator() -> void:
	await _refresh(
		[_bubble(&"patron_mara", &"investigating", "Mara")],
		{&"patron_mara": BEHIND_CAMERA}
	)

	assert_true(_overlay.offscreen_indicators().has(&"patron_mara"),
		"Being behind the camera is still being out of view.")


func test_an_ordinary_offscreen_bubble_gets_no_indicator() -> void:
	await _refresh(
		[_bubble(&"patron_elias", &"ordering", "Elias")],
		{&"patron_elias": OFFSCREEN_RIGHT}
	)

	assert_true(_overlay.offscreen_indicators().is_empty(),
		"Only an urgent state earns an edge marker.")


func test_pressing_an_indicator_reports_its_actor() -> void:
	await _refresh(
		[_bubble(&"patron_june", &"danger_reaction", "June")],
		{&"patron_june": OFFSCREEN_LEFT}
	)
	watch_signals(_overlay)

	assert_true(_overlay.press_offscreen_indicator(&"patron_june"))
	assert_signal_emitted_with_parameters(
		_overlay, "offscreen_indicator_pressed", [&"patron_june"]
	)
	assert_false(_overlay.press_offscreen_indicator(&"patron_nell"),
		"An actor with no indicator cannot be pressed.")


func test_an_indicator_names_the_actor_and_the_state() -> void:
	await _refresh(
		[_bubble(&"patron_june", &"escaping", "June")],
		{&"patron_june": OFFSCREEN_RIGHT}
	)

	assert_eq(
		String(_overlay.offscreen_indicators()[&"patron_june"]["label"]),
		"Focus June: escaping",
		"The accessible label names the actor and their urgent state."
	)


func test_indicators_stay_clear_of_the_bottom_hud_and_reserved_panels() -> void:
	var panel := Rect2(Vector2(900.0, 200.0), Vector2(300.0, 220.0))
	_overlay.set_reserved_rects([_hud_rect(), panel] as Array[Rect2])

	await _refresh(
		[
			_bubble(&"patron_june", &"escaping", "June"),
			_bubble(&"patron_mara", &"investigating", "Mara"),
		],
		{&"patron_june": OFFSCREEN_RIGHT, &"patron_mara": OFFSCREEN_LEFT}
	)

	var indicators: Dictionary = _overlay.offscreen_indicators()
	assert_eq(indicators.size(), 2)
	var placed: Array[Rect2] = []
	for actor_id: StringName in indicators:
		var rect: Rect2 = indicators[actor_id]["rect"]
		assert_false(rect.intersects(_hud_rect()),
			"%s covers the Bottom HUD." % actor_id)
		assert_false(rect.intersects(panel), "%s covers a reserved panel." % actor_id)
		for other: Rect2 in placed:
			assert_false(rect.intersects(other), "Two indicators overlap.")
		placed.append(rect)


func test_a_returning_actor_drops_their_indicator() -> void:
	await _refresh(
		[_bubble(&"patron_june", &"escaping", "June")],
		{&"patron_june": OFFSCREEN_RIGHT}
	)
	assert_eq(_overlay.offscreen_indicators().size(), 1)

	await _refresh(
		[_bubble(&"patron_june", &"escaping", "June")],
		{&"patron_june": ONSCREEN}
	)
	assert_true(_overlay.offscreen_indicators().is_empty(),
		"Walking back into view removes the marker.")
