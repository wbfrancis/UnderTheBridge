extends GutTest


func test_main_scene_animates_bodies_without_moving_actor_roots_and_freezes_on_pause() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/prototypes/main_test.tscn")
	var scene = load("res://scenes/prototypes/main_test.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	scene._on_hud_intent(&"close_controls", {})
	scene._submit_playback(&"select_speed", {"value": 1.0})
	var actors: Array = scene.get("_cultist_nodes").values()
	actors.append_array(scene.get("_patron_nodes").values())
	assert_eq(actors.size(), 10)
	for actor in actors:
		var visual = actor.get_node("VisualPivot")
		assert_true(visual.has_node("Body"))
		assert_true(actor.has_node("Shadow"))
		assert_true(actor.has_node("Name"))
		var root_before: Transform3D = actor.transform
		var shadow_before: Transform3D = actor.get_node("Shadow").transform
		var body_before: Transform3D = visual.get_node("Body").transform
		visual.advance_motion(0.3, 0.0)
		assert_gt(visual.position.y, 0.0)
		assert_eq(actor.transform, root_before)
		assert_eq(actor.get_node("Shadow").transform, shadow_before)
		assert_eq(visual.get_node("Body").transform, body_before)
	scene._submit_playback(&"toggle_plain_pause", {})
	for actor in actors:
		var visual = actor.get_node("VisualPivot")
		var frozen: Dictionary = visual.snapshot()
		visual.advance_motion(1.0, 0.0)
		assert_eq(visual.snapshot(), frozen)
