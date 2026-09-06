extends GutTest

func test_cultist_at_door_work_position_remains_selectable() -> void:
	var scene = load("res://scenes/prototypes/main_test.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	scene.set_process(false)
	var actor = scene._cultist_nodes[ActorIds.CULTIST_IDS[0]]
	actor.set_physics_process(false)
	actor.position = scene.SMART_OBJECTS[&"front_entrance"]["approach"]
	await get_tree().physics_frame
	await get_tree().physics_frame
	for height in [0.4, 0.8, 1.2]:
		var screen: Vector2 = scene._camera.unproject_position(actor.global_position + Vector3(0, height, 0))
		var target: Dictionary = scene._pick_at(screen)
		assert_eq(target.get("id"), ActorIds.CULTIST_IDS[0])
		assert_true(target.get("is_cultist", false))
	actor.position += Vector3(4, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var door_screen: Vector2 = scene._camera.unproject_position(scene.SMART_OBJECTS[&"front_entrance"]["pick_center"])
	assert_eq(scene._pick_at(door_screen).get("id"), &"front_entrance",
		"The door remains a command target when no character covers it.")
