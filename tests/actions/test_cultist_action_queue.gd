extends GutTest

const ACTION_QUEUE_PATH := "res://scripts/actions/cultist_action_queue.gd"


func test_queue_has_one_active_three_pending_and_removable_pending_actions() -> void:
	var queue_script := load(ACTION_QUEUE_PATH)
	assert_not_null(queue_script, "CultistActionQueue should be available through its public script.")
	if queue_script == null:
		return

	var queue = queue_script.new()
	var active_id: int = queue.append(&"serve", &"patron_a")
	var first_pending_id: int = queue.append(&"clean", &"table_a")
	var removable_id: int = queue.append(&"fetch", &"bottle_a")
	var third_pending_id: int = queue.append(&"talk", &"patron_b")

	assert_eq(queue.append(&"overflow", &"patron_c"), -1)
	var full_snapshot: Dictionary = queue.snapshot()
	assert_eq(full_snapshot["active"]["id"], active_id)
	assert_eq(full_snapshot["pending"].size(), 3)

	assert_true(queue.remove_pending(removable_id))
	var replacement_id: int = queue.append(&"replace", &"table_b")
	var pending_ids: Array = queue.snapshot()["pending"].map(
		func(action: Dictionary) -> int: return action["id"]
	)
	assert_eq(pending_ids, [first_pending_id, third_pending_id, replacement_id])


func test_do_now_interrupts_before_commitment_but_waits_after_commitment() -> void:
	var queue_script := load(ACTION_QUEUE_PATH)
	assert_not_null(queue_script)
	if queue_script == null:
		return

	var precommit_queue = queue_script.new()
	var interrupted_id: int = precommit_queue.append(&"serve", &"patron_a", 10.0, 3.0)
	precommit_queue.append(&"clean", &"table_a")
	var urgent_id: int = precommit_queue.do_now(&"hide_evidence", &"trapdoor")
	var precommit_snapshot: Dictionary = precommit_queue.snapshot()
	assert_eq(precommit_snapshot["active"]["id"], urgent_id)
	assert_true(precommit_snapshot["pending"].is_empty())
	assert_true(precommit_snapshot["recent_events"].any(
		func(event: Dictionary) -> bool:
			return event["id"] == interrupted_id and event["state"] == &"cancelled"
	))

	var committed_queue = queue_script.new()
	var committed_id: int = committed_queue.append(&"drug_drink", &"patron_b", 10.0, 1.0)
	committed_queue.advance(1.0)
	committed_queue.append(&"clean", &"table_b")
	var waiting_urgent_id: int = committed_queue.do_now(&"hide_evidence", &"trapdoor")
	var committed_snapshot: Dictionary = committed_queue.snapshot()
	assert_eq(committed_snapshot["active"]["id"], committed_id)
	assert_eq(committed_snapshot["active"]["state"], &"committed")
	assert_eq(committed_snapshot["pending"].size(), 1)
	assert_eq(committed_snapshot["pending"][0]["id"], waiting_urgent_id)


func test_active_cancellation_stops_at_commitment() -> void:
	var queue_script := load(ACTION_QUEUE_PATH)
	assert_not_null(queue_script)
	if queue_script == null:
		return

	var precommit_queue = queue_script.new()
	precommit_queue.append(&"serve", &"patron_a", 10.0, 2.0)
	var next_id: int = precommit_queue.append(&"clean", &"table_a")
	precommit_queue.advance(1.0)
	assert_true(precommit_queue.cancel_active())
	assert_eq(precommit_queue.snapshot()["active"]["id"], next_id)

	var committed_queue = queue_script.new()
	var committed_id: int = committed_queue.append(&"drug_drink", &"patron_b", 10.0, 2.0)
	committed_queue.advance(2.0)
	assert_false(committed_queue.cancel_active())
	assert_eq(committed_queue.snapshot()["active"]["id"], committed_id)


func test_invalid_target_fails_visibly_and_advances_to_next_action() -> void:
	var queue_script := load(ACTION_QUEUE_PATH)
	assert_not_null(queue_script)
	if queue_script == null:
		return

	var queue = queue_script.new()
	var invalid_id: int = queue.append(&"serve", &"departed_patron", 1.0, 0.5, false)
	var valid_id: int = queue.append(&"clean", &"table_a")
	queue.advance(0.0)

	var result: Dictionary = queue.snapshot()
	assert_eq(result["active"]["id"], valid_id)
	assert_true(result["recent_events"].any(
		func(event: Dictionary) -> bool:
			return (
				event["id"] == invalid_id
				and event["state"] == &"failed"
				and event["reason"] == &"invalid_target"
			)
	))
