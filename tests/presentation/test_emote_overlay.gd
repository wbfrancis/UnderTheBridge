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


func _bubble(actor_id: int, emote: StringName, display_name: String = "") -> Dictionary:
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
		[_bubble(ScenarioActors.opening_patron(), &"escaping", "June")],
		{ScenarioActors.opening_patron(): ONSCREEN}
	)

	assert_true(_overlay.placements().has(ScenarioActors.opening_patron()),
		"An actor in view gets an ordinary Emote Bubble.")
	assert_true(_overlay.offscreen_indicators().is_empty(),
		"Nothing on screen needs an edge marker.")


func test_an_offscreen_urgent_actor_gets_one_edge_indicator() -> void:
	await _refresh(
		[_bubble(ScenarioActors.opening_patron(), &"escaping", "June")],
		{ScenarioActors.opening_patron(): OFFSCREEN_RIGHT}
	)

	var indicators: Dictionary = _overlay.offscreen_indicators()
	assert_eq(indicators.size(), 1, "One actor gets one indicator.")
	assert_true(indicators.has(ScenarioActors.opening_patron()))
	assert_false(_overlay.placements().has(ScenarioActors.opening_patron()),
		"An offscreen actor has no in-scene bubble to place.")

	var rect: Rect2 = indicators[ScenarioActors.opening_patron()]["rect"]
	var viewport := get_viewport().get_visible_rect().size
	assert_true(Rect2(Vector2.ZERO, viewport).encloses(rect),
		"The indicator stays inside the screen.")
	assert_gt(rect.get_center().x, viewport.x * 0.5,
		"An actor off the right side gets a marker on the right edge.")


func test_an_actor_behind_the_camera_still_gets_an_indicator() -> void:
	await _refresh(
		[_bubble(ScenarioActors.opening_companion(), &"investigating", "Mara")],
		{ScenarioActors.opening_companion(): BEHIND_CAMERA}
	)

	assert_true(_overlay.offscreen_indicators().has(ScenarioActors.opening_companion()),
		"Being behind the camera is still being out of view.")


func test_an_ordinary_offscreen_bubble_gets_no_indicator() -> void:
	await _refresh(
		[_bubble(ScenarioActors.friendship_candidate(), &"ordering", "Elias")],
		{ScenarioActors.friendship_candidate(): OFFSCREEN_RIGHT}
	)

	assert_true(_overlay.offscreen_indicators().is_empty(),
		"Only an urgent state earns an edge marker.")


func test_pressing_an_indicator_reports_its_actor() -> void:
	await _refresh(
		[_bubble(ScenarioActors.opening_patron(), &"danger_reaction", "June")],
		{ScenarioActors.opening_patron(): OFFSCREEN_LEFT}
	)
	watch_signals(_overlay)

	assert_true(_overlay.press_offscreen_indicator(ScenarioActors.opening_patron()))
	assert_signal_emitted_with_parameters(
		_overlay, "offscreen_indicator_pressed", [ScenarioActors.opening_patron()]
	)
	assert_false(_overlay.press_offscreen_indicator(ScenarioActors.group_member(&"arrival_group_trio_01", 2, 3)),
		"An actor with no indicator cannot be pressed.")


func test_an_indicator_names_the_actor_and_the_state() -> void:
	await _refresh(
		[_bubble(ScenarioActors.opening_patron(), &"escaping", "June")],
		{ScenarioActors.opening_patron(): OFFSCREEN_RIGHT}
	)

	assert_eq(
		String(_overlay.offscreen_indicators()[ScenarioActors.opening_patron()]["label"]),
		"Focus June: escaping",
		"The accessible label names the actor and their urgent state."
	)


func test_indicators_stay_clear_of_the_bottom_hud_and_reserved_panels() -> void:
	var panel := Rect2(Vector2(900.0, 200.0), Vector2(300.0, 220.0))
	_overlay.set_reserved_rects([_hud_rect(), panel] as Array[Rect2])

	await _refresh(
		[
			_bubble(ScenarioActors.opening_patron(), &"escaping", "June"),
			_bubble(ScenarioActors.opening_companion(), &"investigating", "Mara"),
		],
		{ScenarioActors.opening_patron(): OFFSCREEN_RIGHT, ScenarioActors.opening_companion(): OFFSCREEN_LEFT}
	)

	var indicators: Dictionary = _overlay.offscreen_indicators()
	assert_eq(indicators.size(), 2)
	var placed: Array[Rect2] = []
	for actor_id: int in indicators:
		var rect: Rect2 = indicators[actor_id]["rect"]
		assert_false(rect.intersects(_hud_rect()),
			"%s covers the Bottom HUD." % actor_id)
		assert_false(rect.intersects(panel), "%s covers a reserved panel." % actor_id)
		for other: Rect2 in placed:
			assert_false(rect.intersects(other), "Two indicators overlap.")
		placed.append(rect)


func test_a_returning_actor_drops_their_indicator() -> void:
	await _refresh(
		[_bubble(ScenarioActors.opening_patron(), &"escaping", "June")],
		{ScenarioActors.opening_patron(): OFFSCREEN_RIGHT}
	)
	assert_eq(_overlay.offscreen_indicators().size(), 1)

	await _refresh(
		[_bubble(ScenarioActors.opening_patron(), &"escaping", "June")],
		{ScenarioActors.opening_patron(): ONSCREEN}
	)
	assert_true(_overlay.offscreen_indicators().is_empty(),
		"Walking back into view removes the marker.")


func test_labels_preserve_icon_anchor_at_each_ui_scale() -> void:
	for scale in [0.75, 1.0, 1.5]:
		_overlay.set_ui_scale(scale)
		_overlay.set_accessible_labels(false)
		await _refresh([_bubble(ScenarioActors.opening_patron(), &"ordering")], {ScenarioActors.opening_patron(): ONSCREEN})
		var plain: Rect2 = _overlay.placements()[ScenarioActors.opening_patron()]
		_overlay.set_accessible_labels(true)
		await _refresh([_bubble(ScenarioActors.opening_patron(), &"ordering")], {ScenarioActors.opening_patron(): ONSCREEN})
		var labelled: Rect2 = _overlay.placements()[ScenarioActors.opening_patron()]
		assert_almost_eq(labelled.position.x, plain.position.x, 0.01,
			"The label extends right while the icon stays above the actor.")
