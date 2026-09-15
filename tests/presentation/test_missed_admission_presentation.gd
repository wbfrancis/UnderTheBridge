extends GutTest

const PRESENTATION_SCENE := "res://scenes/prototypes/main_test.tscn"


func test_admit_group_command_from_night_start_brings_waiting_patrons_inside() -> void:
	var presentation = load(PRESENTATION_SCENE).instantiate()
	presentation.review_stage = "night_start"
	add_child_autofree(presentation)
	await get_tree().process_frame
	presentation._on_hud_intent(&"close_controls", {})
	for frame in range(300):
		if presentation.get("_navigation_ready"):
			break
		await get_tree().physics_frame
	assert_true(presentation.get("_navigation_ready"))
	var session = presentation.get("_session")
	session.advance(3.1)
	presentation._issue_command(&"admit_group", presentation._smart_target(&"front_entrance"), false)
	presentation._submit_playback(&"select_speed", {"value": 4.0})
	for frame in range(1200):
		var patrons: Dictionary = session.snapshot()["debug_patron_views"]
		if patrons[ScenarioActors.opening_patron()]["activity"] == &"awaiting_drink" and patrons[ScenarioActors.opening_companion()]["activity"] == &"awaiting_drink":
			break
		await get_tree().physics_frame
	var views: Dictionary = session.snapshot()["debug_patron_views"]
	assert_eq(views[ScenarioActors.opening_patron()]["activity"], &"awaiting_drink", "June enters and orders through the real admission command.")
	assert_eq(views[ScenarioActors.opening_companion()]["activity"], &"awaiting_drink", "Mara enters and orders through the real admission command.")
	assert_true(presentation._commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[0]]["active"].is_empty(), "Admission releases the Cultist after the group enters.")


func test_a_group_that_times_out_at_the_door_leaves_the_visible_scene() -> void:
	var settings := ConfigFile.new()
	settings.set_value("hud", "emote_labels", false)
	settings.set_value("hud", "ui_scale", 1.0)
	settings.set_value("hud", "controls_seen", true)
	assert_eq(settings.save("user://settings.cfg"), OK)
	var presentation = load(PRESENTATION_SCENE).instantiate()
	presentation.review_stage = "night_start"
	add_child_autofree(presentation)
	await get_tree().process_frame
	await get_tree().process_frame

	var session = presentation.get("_session")
	session.advance(33.1)
	await get_tree().process_frame
	var patrons: Dictionary = presentation.get("_patron_nodes")
	for patron_id: int in [ScenarioActors.opening_patron(), ScenarioActors.opening_companion()]:
		assert_eq(session.snapshot()["debug_patron_views"][patron_id]["lifecycle"], &"leaving")
		assert_eq((patrons[patron_id] as CharacterBody3D).collision_layer, 0,
			"Missed admission disables interaction while the Patron walks away.")
		assert_almost_eq((patrons[patron_id] as NavigableActor3D).target_position().x, -20.2, 0.001)
	session.advance(15.1)
	await get_tree().process_frame
	for patron_id: int in [ScenarioActors.opening_patron(), ScenarioActors.opening_companion()]:
		assert_eq(session.snapshot()["debug_patron_views"][patron_id]["lifecycle"], &"exited")
		assert_false((patrons[patron_id] as Node3D).visible,
			"A missed Patron is removed instead of standing at the front door.")
