extends GutTest

const CONTROLLER_PATH := "res://scripts/presentation/avatar_motion_controller.gd"

var _controller


func _make_controller() -> void:
	_controller = load(CONTROLLER_PATH).new()
	add_child_autofree(_controller)
	_controller.configure(&"patron_june")
	_controller.set_simulation_scale(1.0)


func test_state_priority_keeps_prone_motion_out_of_upright_gaits() -> void:
	var script = load(CONTROLLER_PATH)
	assert_eq(script.select_state(true, true, &"run", true), &"passive_body")
	assert_eq(script.select_state(true, false, &"run", true), &"still_body")
	assert_eq(script.select_state(false, true, &"run", true), &"running")
	assert_eq(script.select_state(false, true, &"walk", true), &"walking")
	assert_eq(script.select_state(false, false, &"walk", true), &"doing")
	assert_eq(script.select_state(false, false, &"walk", false), &"idle")


func test_stationary_activity_selects_doing() -> void:
	_make_controller()
	_controller.set_context(&"walk", false, true, false)
	_controller.advance_motion(0.2, 0.0)

	assert_eq(_controller.current_state(), &"doing")
	assert_gt(float(_controller.snapshot()["position"].y), 0.0)


func test_run_intent_is_independent_from_simulation_speed() -> void:
	_make_controller()
	_controller.set_context(&"walk", true, false, false)
	_controller.set_simulation_scale(4.0)
	_controller.advance_motion(0.1, 0.2)
	assert_eq(_controller.current_state(), &"walking")

	_controller.set_context(&"run", true, false, false)
	_controller.advance_motion(0.1, 0.2)
	assert_eq(_controller.current_state(), &"running")


func test_blocked_actor_settles_after_a_short_delay() -> void:
	_make_controller()
	_controller.set_context(&"walk", true, false, false)
	_controller.advance_motion(0.05, 0.05)
	assert_eq(_controller.current_state(), &"walking")

	_controller.advance_motion(0.1, 0.0)
	assert_eq(_controller.current_state(), &"walking")
	_controller.advance_motion(0.13, 0.0)
	assert_eq(_controller.current_state(), &"idle")


func test_pause_freezes_phase_and_transform() -> void:
	_make_controller()
	_controller.set_context(&"walk", false, true, false)
	_controller.advance_motion(0.2, 0.0)
	var before: Dictionary = _controller.snapshot()

	_controller.set_simulation_scale(0.0)
	_controller.advance_motion(2.0, 4.0)
	var after: Dictionary = _controller.snapshot()

	assert_eq(after["phase"], before["phase"])
	assert_eq(after["position"], before["position"])
	assert_eq(after["rotation_z"], before["rotation_z"])
	assert_eq(after["scale"], before["scale"])


func test_moved_prone_body_bounces_without_squash() -> void:
	_make_controller()
	_controller.set_context(&"walk", true, false, true)
	_controller.advance_motion(0.2, 0.25)
	var moving: Dictionary = _controller.snapshot()
	assert_eq(moving["state"], &"passive_body")
	assert_gt(float(moving["position"].y), 0.0)
	assert_ne(float(moving["rotation_z"]), 0.0)
	assert_eq(moving["scale"], Vector3.ONE)

	_controller.set_context(&"walk", false, false, true)
	_controller.advance_motion(0.3, 0.0)
	_controller.advance_motion(0.2, 0.0)
	var still: Dictionary = _controller.snapshot()
	assert_eq(still["state"], &"still_body")
	assert_almost_eq(float(still["position"].y), 0.0, 0.0001)
	assert_almost_eq(float(still["rotation_z"]), 0.0, 0.0001)
