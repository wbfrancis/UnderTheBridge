extends GutTest

const SYSTEM := preload("res://scripts/actions/character_action_system.gd")


func test_shared_owner_keeps_character_queues_independent() -> void:
	var system = SYSTEM.new()
	assert_true(system.register_actor(1, &"cultist"))
	assert_true(system.register_actor(4, &"patron"))
	assert_false(system.register_actor(4, &"cultist"))
	system.queue_for_coordinator(1).append(&"make_wine", &"bar")
	system.queue_for_coordinator(4).append(&"drinking", &"wine")
	assert_eq(system.active_request(1)["name"], &"make_wine")
	assert_eq(system.active_request(4)["name"], &"drinking")


func test_interruption_preserves_identity_time_and_resumes_before_pending() -> void:
	var system = SYSTEM.new()
	system.register_actor(4, &"patron")
	var queue = system.queue_for_coordinator(4)
	var original: int = queue.append(&"socializing", &"seat", 20.0)
	queue.advance_clock(4.0)
	queue.append(&"leave", &"exit")
	queue.interrupt_with({"name": &"step_aside", "target_id": &"incident"})
	queue.complete_active()
	assert_eq(queue.active_snapshot()["id"], original)
	assert_eq(queue.active_snapshot()["elapsed_seconds"], 4.0)
	assert_eq(queue.snapshot()["pending"].size(), 1)


func test_atomic_clear_cannot_revive_paused_action() -> void:
	var system = SYSTEM.new()
	system.register_actor(4, &"patron")
	var queue = system.queue_for_coordinator(4)
	queue.append(&"socializing", &"seat")
	queue.interrupt_with({"name": &"step_aside", "target_id": &"incident"})
	assert_eq(system.clear(4, true).size(), 2)
	queue.append(&"captured", &"exit")
	assert_eq(queue.active_snapshot()["name"], &"captured")
	assert_true(queue.snapshot()["paused"].is_empty())
	assert_true(queue.snapshot()["pending"].is_empty())


func test_debug_can_remove_paused_action_without_cancelling_current_action() -> void:
	var system = SYSTEM.new()
	system.register_actor(4, &"patron")
	var queue = system.queue_for_coordinator(4)
	var original: int = queue.append(&"socializing", &"seat")
	queue.interrupt_with({"name": &"step_aside", "target_id": &"incident"})
	assert_true(system.cancel(4, original, true)["cancelled"])
	assert_eq(queue.active_snapshot()["name"], &"step_aside")
	queue.complete_active()
	assert_true(queue.active_snapshot().is_empty())
