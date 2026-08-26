extends GutTest

const ACTION_QUEUE_PATH := "res://scripts/actions/cultist_action_queue.gd"


func _queue():
	return load(ACTION_QUEUE_PATH).new()


func _chain(names: Array) -> Array:
	var specs: Array = []
	for entry in names:
		specs.append({"name": StringName(entry), "target_id": &"patron_a"})
	return specs


func test_the_queue_never_rejects_an_action_for_its_length() -> void:
	var queue = _queue()
	var ids: Array[int] = []
	for index in range(120):
		var id: int = queue.append(&"move", &"floor")
		assert_gt(id, 0, "Every appended Action is accepted, no matter the queue length.")
		ids.append(id)
	var snapshot: Dictionary = queue.snapshot()
	assert_eq(snapshot["pending"].size(), 119, "One Action is active; the rest wait in order.")
	assert_eq(int(snapshot["active"]["id"]), ids[0])


func test_the_full_queue_keeps_fifo_order() -> void:
	var queue = _queue()
	var ids: Array[int] = []
	for index in range(10):
		ids.append(queue.append(&"move", &"floor"))
	var order: Array[int] = [int(queue.snapshot()["active"]["id"])]
	for entry: Dictionary in queue.snapshot()["pending"]:
		order.append(int(entry["id"]))
	assert_eq(order, ids, "The active and pending Actions keep the order they were queued.")


func test_replace_with_chain_clears_an_uncommitted_active_action() -> void:
	var queue = _queue()
	var interrupted: int = queue.append(&"talk", &"patron_a", 10.0, 3.0)
	queue.append(&"serve", &"patron_b")
	var result: Dictionary = queue.replace_with_chain(_chain([&"move"]))

	var state: Dictionary = queue.snapshot()
	assert_eq(int(state["active"]["id"]), int(result["action_ids"][0]))
	assert_true(state["pending"].is_empty(), "A normal replacement clears every pending Action.")
	assert_true(state["recent_events"].any(
		func(event: Dictionary) -> bool:
			return event["id"] == interrupted and event["reason"] == &"replace"
	))


func test_replace_with_chain_waits_behind_a_committed_active_action() -> void:
	var queue = _queue()
	var committed: int = queue.append(&"drug_drink", &"patron_b", 10.0, 1.0)
	queue.advance(1.0)
	queue.append(&"clean", &"table_b")
	var result: Dictionary = queue.replace_with_chain(_chain([&"move", &"talk"]))

	var state: Dictionary = queue.snapshot()
	assert_eq(int(state["active"]["id"]), committed,
		"A committed active Action finishes before the replacement chain starts.")
	var pending_ids: Array = state["pending"].map(func(a: Dictionary) -> int: return int(a["id"]))
	assert_eq(pending_ids, result["action_ids"], "The replacement chain becomes the pending tail.")


func test_shift_append_adds_a_chain_after_a_committed_action() -> void:
	var queue = _queue()
	queue.append(&"drug_drink", &"patron_b", 10.0, 1.0)
	queue.advance(1.0)
	var result: Dictionary = queue.append_chain(_chain([&"generated_move", &"talk"]))
	var pending_ids: Array = queue.snapshot()["pending"].map(
		func(a: Dictionary) -> int: return int(a["id"])
	)
	assert_eq(pending_ids, result["action_ids"], "A Shift append lands the whole chain at the tail.")


func test_a_chain_carries_a_stable_shared_identity() -> void:
	var queue = _queue()
	var result: Dictionary = queue.append_chain(_chain([&"generated_move", &"talk"]))
	var chain_id: int = int(result["chain_id"])
	assert_gt(chain_id, -1, "A multi-link chain gets a real chain id.")
	var state: Dictionary = queue.snapshot()
	assert_eq(int(state["active"]["chain_id"]), chain_id)
	assert_eq(int(state["pending"][0]["chain_id"]), chain_id)
	assert_eq(int(state["active"]["chain_index"]), 0)
	assert_eq(int(state["pending"][0]["chain_index"]), 1)
	assert_eq(int(state["active"]["chain_size"]), 2)

	var standalone: int = queue.append(&"move", &"floor")
	assert_eq(int(queue.snapshot()["pending"][-1]["chain_id"]), -1,
		"A standalone Action carries no chain identity.")
	assert_gt(standalone, chain_id, "Action ids stay unique and monotonic.")


func test_cancelling_any_chain_member_removes_every_unfinished_member() -> void:
	var queue = _queue()
	var chain: Dictionary = queue.append_chain(_chain([&"generated_move", &"talk"]))
	var unrelated: int = queue.append(&"move", &"floor")
	var dependent_id: int = int(chain["action_ids"][1])

	var removed: Dictionary = queue.cancel_chain(dependent_id)
	assert_eq(removed["removed"].size(), 2, "Cancelling one link removes the whole chain.")
	var state: Dictionary = queue.snapshot()
	assert_eq(int(state["active"]["id"]), unrelated, "The next unrelated Action becomes active.")
	assert_true(state["pending"].is_empty())


func test_a_standalone_cancel_removes_only_that_action() -> void:
	var queue = _queue()
	queue.append(&"move", &"floor")
	var first: int = queue.append(&"move", &"floor")
	var second: int = queue.append(&"move", &"floor")

	queue.cancel_chain(first)
	var pending_ids: Array = queue.snapshot()["pending"].map(
		func(a: Dictionary) -> int: return int(a["id"])
	)
	assert_eq(pending_ids, [second], "Two standalone Actions share id -1 but stay independent.")


func test_failing_the_active_chain_removes_dependents_and_starts_the_next_action() -> void:
	var queue = _queue()
	queue.append_chain(_chain([&"generated_move", &"talk"]))
	var unrelated: int = queue.append(&"move", &"floor")

	var result: Dictionary = queue.fail_active_chain(&"path_stuck")
	assert_eq(result["removed"].size(), 2, "The failed link and its dependent leave together.")
	assert_eq(int(queue.snapshot()["active"]["id"]), unrelated,
		"The next unrelated Action starts after the chain fails.")


func test_a_completed_link_never_returns_to_the_queue() -> void:
	var queue = _queue()
	var chain: Dictionary = queue.append_chain(_chain([&"generated_move", &"talk"]))
	assert_true(queue.complete_active(), "The Generated Move completes.")
	var dependent_id: int = int(chain["action_ids"][1])
	assert_eq(int(queue.snapshot()["active"]["id"]), dependent_id)

	# Cancelling the dependent must not resurrect the completed Generated Move.
	queue.cancel_chain(dependent_id)
	assert_true(queue.snapshot()["active"].is_empty())
	var completed: Array = queue.snapshot()["recent_events"].filter(
		func(event: Dictionary) -> bool:
			return int(event["id"]) == int(chain["action_ids"][0]) and event["state"] == &"completed"
	)
	assert_eq(completed.size(), 1, "The completed link stays completed exactly once.")


func test_inserting_a_prerequisite_keeps_one_chain_identity() -> void:
	var queue = _queue()
	var standalone: int = queue.append(&"talk", &"patron_a")
	assert_eq(int(queue.snapshot()["active"]["chain_id"]), -1)

	var inserted: Dictionary = queue.insert_prerequisite_for_active({
		"name": &"generated_move", "target_id": &"patron_a", "generated": true,
	})
	var state: Dictionary = queue.snapshot()
	assert_eq(int(state["active"]["id"]), int(inserted["action_id"]),
		"The prerequisite becomes active.")
	assert_true(bool(state["active"]["generated"]))
	assert_eq(int(state["pending"][0]["id"]), standalone,
		"The displaced Patron Action waits behind the prerequisite.")
	assert_eq(int(state["active"]["chain_id"]), int(state["pending"][0]["chain_id"]),
		"Both links now share one chain identity.")
	assert_eq(int(state["active"]["chain_size"]), 2)


func test_a_new_queue_carries_no_chain_or_id_state() -> void:
	var used = _queue()
	used.append_chain(_chain([&"generated_move", &"talk"]))
	used.cancel_chain(int(used.snapshot()["active"]["id"]))

	var fresh = _queue()
	var id: int = fresh.append(&"move", &"floor")
	assert_eq(id, 1, "A fresh queue starts its ids from one.")
	assert_true(fresh.snapshot()["pending"].is_empty())
	assert_true(fresh.snapshot()["recent_events"].is_empty())


func test_precommit_do_now_interrupts_but_a_committed_action_waits() -> void:
	var precommit = _queue()
	var interrupted: int = precommit.append(&"serve", &"patron_a", 10.0, 3.0)
	precommit.append(&"clean", &"table_a")
	var urgent: int = precommit.do_now(&"hide_evidence", &"trapdoor")
	assert_eq(int(precommit.snapshot()["active"]["id"]), urgent)
	assert_true(precommit.snapshot()["pending"].is_empty())
	assert_true(precommit.snapshot()["recent_events"].any(
		func(event: Dictionary) -> bool:
			return event["id"] == interrupted and event["state"] == &"cancelled"
	))

	var committed = _queue()
	var committed_id: int = committed.append(&"drug_drink", &"patron_b", 10.0, 1.0)
	committed.advance(1.0)
	committed.append(&"clean", &"table_b")
	var waiting: int = committed.do_now(&"hide_evidence", &"trapdoor")
	assert_eq(int(committed.snapshot()["active"]["id"]), committed_id)
	assert_eq(committed.snapshot()["pending"][0]["id"], waiting)


func test_external_completion_and_failure_advance_the_queue() -> void:
	var queue = _queue()
	var first: int = queue.append(&"move", &"floor", INF, INF)
	var second: int = queue.append(&"move", &"floor", INF, INF)

	assert_true(queue.complete_active())
	assert_eq(int(queue.snapshot()["active"]["id"]), second)
	assert_true(queue.fail_active(&"path_stuck"))
	assert_true(queue.snapshot()["active"].is_empty())
	assert_true(queue.snapshot()["recent_events"].any(
		func(event: Dictionary) -> bool:
			return event["id"] == first and event["state"] == &"completed"
	))


func test_invalid_target_fails_visibly_and_advances_to_next_action() -> void:
	var queue = _queue()
	var invalid: int = queue.append(&"serve", &"departed_patron", 1.0, 0.5, false)
	var valid: int = queue.append(&"clean", &"table_a")
	queue.advance(0.0)

	var result: Dictionary = queue.snapshot()
	assert_eq(int(result["active"]["id"]), valid)
	assert_true(result["recent_events"].any(
		func(event: Dictionary) -> bool:
			return (
				event["id"] == invalid
				and event["state"] == &"failed"
				and event["reason"] == &"invalid_target"
			)
	))
