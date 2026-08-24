extends GutTest

const MOVEMENT_PLAN_PATH := "res://scripts/actions/cultist_movement_plan.gd"


func test_normal_move_replaces_and_shift_move_appends() -> void:
	var plan_script := load(MOVEMENT_PLAN_PATH)
	assert_not_null(plan_script)
	if plan_script == null:
		return
	var plan = plan_script.new()

	var first_id: int = plan.issue_move(Vector3(1.0, 0.0, 2.0), false)
	var queued_id: int = plan.issue_move(Vector3(3.0, 0.0, 4.0), true)
	var replacement_id: int = plan.issue_move(Vector3(5.0, 0.0, 6.0), false)
	var state: Dictionary = plan.snapshot()

	assert_ne(first_id, replacement_id)
	assert_ne(queued_id, replacement_id)
	assert_eq(state["active"]["id"], replacement_id)
	assert_eq(state["active"]["destination"], Vector3(5.0, 0.0, 6.0))
	assert_true(state["pending"].is_empty())


func test_shift_moves_keep_order_and_stop_at_queue_limit() -> void:
	var plan = load(MOVEMENT_PLAN_PATH).new()
	plan.issue_move(Vector3.ZERO, false)
	assert_gt(plan.issue_move(Vector3(1.0, 0.0, 0.0), true), 0)
	assert_gt(plan.issue_move(Vector3(2.0, 0.0, 0.0), true), 0)
	assert_gt(plan.issue_move(Vector3(3.0, 0.0, 0.0), true), 0)
	assert_eq(plan.issue_move(Vector3(4.0, 0.0, 0.0), true), -1)
	assert_eq(plan.destination_markers(), [
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
		Vector3(3.0, 0.0, 0.0),
	])


func test_reach_and_stuck_advance_to_the_next_destination() -> void:
	var plan = load(MOVEMENT_PLAN_PATH).new()
	plan.issue_move(Vector3(1.0, 0.0, 0.0), false)
	plan.issue_move(Vector3(2.0, 0.0, 0.0), true)

	assert_true(plan.complete_active_move())
	assert_eq(plan.active_destination(), Vector3(2.0, 0.0, 0.0))
	assert_true(plan.fail_active_move(&"path_stuck"))
	assert_false(plan.has_active_move())
