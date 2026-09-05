extends GutTest

const PRESENTATION_SCENE := "res://scenes/prototypes/main_test.tscn"


func test_default_scene_opens_at_the_start_of_a_fresh_night() -> void:
	var settings := ConfigFile.new()
	settings.set_value("hud", "emote_labels", false)
	settings.set_value("hud", "ui_scale", 1.0)
	settings.set_value("hud", "controls_seen", false)
	assert_eq(settings.save("user://settings.cfg"), OK)
	var presentation = load(PRESENTATION_SCENE).instantiate()
	add_child_autofree(presentation)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(presentation.review_stage, "night_start")
	assert_eq(String(presentation.get("_scenario")), "night_start")
	var cultist_nodes: Dictionary = presentation.get("_cultist_nodes")
	assert_eq(cultist_nodes.size(), 2, "The playable scene exposes Vera and Iris.")
	assert_true(cultist_nodes.has(ActorIds.CULTIST_IDS[0]), "Vera (cultist_01) is playable.")
	assert_true(cultist_nodes.has(ActorIds.CULTIST_IDS[1]), "Iris (cultist_02) is playable.")
	assert_eq(int(presentation.get("_selected_cultist_id")), ActorIds.CULTIST_IDS[0],
		"Vera is the Selected Cultist by default.")

	var session = presentation.get("_session")
	assert_not_null(session)
	if session == null:
		return
	var state: Dictionary = session.snapshot()
	assert_eq(state["simulated_seconds"], 0.0, "The playable default starts at 0:00.")
	assert_true(bool(presentation.get("_controls_visible")),
		"The first-install Controls Card holds the fresh Night.")
	assert_eq(state["orders"]["all"].size(), 0,
		"No staged Order exists before the fresh Night begins.")


func test_drink_cycle_remains_an_explicit_staged_scenario() -> void:
	var presentation = load(PRESENTATION_SCENE).instantiate()
	presentation.review_stage = "drink_cycle"
	add_child_autofree(presentation)
	await get_tree().process_frame

	var state: Dictionary = presentation.get("_session").snapshot()
	assert_eq(String(presentation.get("_scenario")), "drink_cycle")
	assert_gt(float(state["simulated_seconds"]), 0.0)
	assert_gt(state["orders"]["all"].size(), 0, "The explicit checkpoint has an Order to serve.")
