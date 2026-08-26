extends GutTest

const PRESENTATION_SCENE := "res://scenes/prototypes/ticket16_presentation_review.tscn"


func test_default_scene_opens_on_an_unserved_drink_order() -> void:
	var presentation = load(PRESENTATION_SCENE).instantiate()
	add_child_autofree(presentation)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(presentation.review_stage, "drink_cycle")
	assert_eq(String(presentation.get("_scenario")), "drink_cycle")
	var cultist_nodes: Dictionary = presentation.get("_cultist_nodes")
	assert_eq(cultist_nodes.size(), 1, "The playable scene exposes Vera only.")
	assert_true(cultist_nodes.has(&"cultist_01"), "The one playable Cultist is Vera (cultist_01).")
	assert_eq(String(presentation.get("_selected_cultist_id")), "cultist_01",
		"Vera is the Selected Cultist by default.")

	var session = presentation.get("_session")
	assert_not_null(session)
	if session == null:
		return
	var state: Dictionary = session.snapshot()
	assert_gt(state["orders"]["all"].size(), 0, "The default scene has an Order to serve.")
	assert_eq(state["orders"]["served_count"], 0, "The default Order remains open for play.")
