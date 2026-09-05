extends GutTest

const REGISTRY_PATH := "res://scripts/interactions/interaction_registry.gd"


func test_exclusive_reservations_and_cleanup_use_one_authority() -> void:
	var registry_script := load(REGISTRY_PATH)
	assert_not_null(registry_script)
	if registry_script == null:
		return

	var registry = registry_script.new()
	assert_true(registry.register_slot(&"seat_01", &"seat"))
	assert_true(registry.register_slot(&"bar_01", &"bar_position"))

	assert_true(registry.request_slot(1001, &"seat_01"))
	assert_false(registry.request_slot(1002, &"seat_01"), "A slot cannot have two owners.")
	assert_false(registry.request_slot(1001, &"bar_01"), "An actor cannot reserve two destinations.")

	assert_eq(registry.release_actor(1001), &"seat_01")
	assert_true(registry.request_slot(1002, &"seat_01"))
	assert_eq(registry.release_actor(1002), &"seat_01", "Cancellation releases ownership.")

	assert_true(registry.request_slot(1, &"bar_01"))
	assert_eq(registry.release_actor(1), &"bar_01", "Terminal state changes release ownership.")
	assert_true(registry.snapshot()["invariant_violations"].is_empty())
