extends GutTest

# Binds the Trapdoor panel animation and the captured Patron's fall to the
# authoritative simulation state in the live scene: a standing capture opens the
# panels, sinks the Patron a bounded depth into the pit (occluded, never below the
# stage), then removes them only after the panels finish closing. A seated misfire
# animates the panels but never moves the Patron.

const SCENE := "res://scenes/prototypes/ticket16_presentation_review.tscn"
const FLOOR_Y := 0.18
const FALL_DEPTH := 2.6


func _stage():
	var presentation = load(SCENE).instantiate()
	add_child_autofree(presentation)
	await get_tree().process_frame
	var frames := 0
	while frames < 1_200 and not bool(presentation.get("_navigation_ready")):
		await get_tree().physics_frame
		frames += 1
	presentation._submit_playback(&"select_speed", {"value": 4.0})
	await presentation._wait_for_patrons(2_400)
	return presentation


func _await_activity(presentation, patron_id: StringName, activity: StringName, budget: int) -> bool:
	var frames := 0
	while frames < budget:
		if presentation.get("_session").snapshot()["debug_patron_views"][patron_id]["activity"] == activity:
			return true
		await get_tree().physics_frame
		frames += 1
	return false


func test_standing_capture_opens_panels_sinks_occluded_then_removes_after_closure() -> void:
	var presentation = await _stage()
	var session = presentation.get("_session")
	assert_true(session.debug_force_bathroom(&"patron_mara"))
	assert_true(await _await_activity(presentation, &"patron_mara", &"mirror_check", 4_000),
		"Mara reaches a standing bathroom phase.")
	assert_true(session.activate_trapdoor())

	var node = presentation.get("_patron_nodes").get(&"patron_mara")
	var saw_falling_visible := false
	var saw_open_panels := false
	var saw_locked := false
	var max_sink := 0.0
	var frames := 0
	while frames < 1_200:
		var trap: Dictionary = session.snapshot()["trapdoor"]
		if trap["state"] == &"falling":
			saw_falling_visible = saw_falling_visible or node.visible
			saw_open_panels = saw_open_panels or float(presentation.get("_trapdoor_open_amount")) > 0.5
			saw_locked = saw_locked or bool(trap["locked"])
			max_sink = maxf(max_sink, FLOOR_Y - float(node.global_position.y))
		if int(session.snapshot()["captures"]) > 0:
			break
		await get_tree().physics_frame
		frames += 1

	assert_eq(int(session.snapshot()["captures"]), 1, "The standing occupant is captured.")
	assert_true(saw_falling_visible, "The Patron stays present during the fall.")
	assert_true(saw_open_panels, "The panels open while the Patron falls.")
	assert_true(saw_locked, "The bathroom reads as locked while the Trapdoor is open.")
	assert_gt(max_sink, 0.3, "The Patron sinks into the pit.")
	assert_lte(max_sink, FALL_DEPTH + 0.05,
		"The fall is bounded and never continues below the stage.")
	# Removed only after closure.
	await get_tree().physics_frame
	assert_false(node.visible, "The captured Patron is removed after the panels close.")
	# The panels return flat once the sequence ends.
	var settle := 0
	while settle < 600 and session.snapshot()["trapdoor"]["state"] != &"closed":
		await get_tree().physics_frame
		settle += 1
	assert_almost_eq(float(presentation.get("_trapdoor_open_amount")), 0.0, 0.01,
		"The panels read shut once the Trapdoor is closed again.")


func test_seated_misfire_animates_the_panels_but_never_moves_the_patron() -> void:
	var presentation = await _stage()
	var session = presentation.get("_session")
	assert_true(session.debug_force_bathroom(&"patron_mara"))
	assert_true(await _await_activity(presentation, &"patron_mara", &"seated_bathroom_use", 6_000),
		"Mara reaches the seated toilet phase.")
	var node = presentation.get("_patron_nodes").get(&"patron_mara")
	var y_before: float = node.global_position.y
	assert_true(session.activate_trapdoor())

	var saw_open_panels := false
	var frames := 0
	while frames < 400:
		if float(presentation.get("_trapdoor_open_amount")) > 0.5:
			saw_open_panels = true
		# The seated Patron never falls.
		assert_almost_eq(float(node.global_position.y), y_before, 0.01, "The seated Patron never sinks.")
		if session.snapshot()["trapdoor"]["state"] == &"cooldown":
			break
		await get_tree().physics_frame
		frames += 1
	assert_true(saw_open_panels, "The panels still animate on a seated misfire.")
	assert_eq(int(session.snapshot()["captures"]), 0, "A seated misfire never captures.")
	assert_true(node.visible, "The seated Patron stays present.")
