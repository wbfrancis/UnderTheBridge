extends GutTest

func test_shock_stops_the_avatar_until_the_leave_action_starts() -> void:
	var scene = load("res://scenes/prototypes/main_test.tscn").instantiate()
	scene.review_stage = "drink_cycle"
	add_child_autofree(scene)
	await get_tree().process_frame
	scene.set_process(false)
	var patron := ScenarioActors.opening_patron()
	assert_true(scene._session.report_patron_stimulus(patron, &"knockout_witnessed"))
	scene._session.advance(0.1)
	var debug: Dictionary = scene._session.snapshot()["debug_patron_views"][patron]
	assert_eq(debug["activity"], &"shock")
	scene._sync_patron_navigation(patron, debug)
	assert_false(scene._patron_nodes[patron].is_navigating(),
		"A stationary planned action cannot start the next movement early.")
	scene._session.advance(2.1)
	debug = scene._session.snapshot()["debug_patron_views"][patron]
	assert_eq(debug["activity"], &"escaping")
	scene._sync_patron_navigation(patron, debug)
	assert_true(scene._patron_nodes[patron].is_navigating())
