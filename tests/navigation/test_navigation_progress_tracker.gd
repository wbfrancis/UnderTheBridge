extends GutTest

const TRACKER_PATH := "res://scripts/navigation/navigation_progress_tracker.gd"
const ACTOR_PATH := "res://scripts/navigation/navigable_actor_3d.gd"


func test_repaths_after_four_seconds_and_fails_after_fifteen_total_seconds() -> void:
	var tracker = load(TRACKER_PATH).new()
	tracker.reset(Vector3.ZERO)

	assert_eq(tracker.observe(Vector3.ZERO, 3.9), &"waiting")
	assert_eq(tracker.observe(Vector3.ZERO, 0.1), &"repath")
	assert_eq(tracker.observe(Vector3.ZERO, 4.0), &"repath")
	assert_eq(tracker.observe(Vector3.ZERO, 4.0), &"repath")
	assert_eq(tracker.observe(Vector3.ZERO, 2.9), &"waiting")
	assert_eq(tracker.observe(Vector3.ZERO, 0.1), &"stuck")


func test_progress_resets_repath_and_stuck_timers() -> void:
	var tracker = load(TRACKER_PATH).new()
	tracker.reset(Vector3.ZERO)
	assert_eq(tracker.observe(Vector3.ZERO, 4.0), &"repath")
	assert_eq(tracker.observe(Vector3(0.1, 0.0, 0.0), 1.0), &"progress")
	assert_eq(tracker.observe(Vector3(0.1, 0.0, 0.0), 3.9), &"waiting")
	assert_eq(tracker.observe(Vector3(0.1, 0.0, 0.0), 0.1), &"repath")


func test_cultists_move_faster_than_patrons_and_fleeing_patrons() -> void:
	var cultist = load(ACTOR_PATH).new()
	var patron = load(ACTOR_PATH).new()
	cultist.configure(1002, true)
	patron.configure(1001, false)
	assert_almost_eq(cultist.base_speed, 2.25, 0.001)
	assert_almost_eq(patron.base_speed, 1.3, 0.001)
	assert_gt(cultist.base_speed, patron.base_speed * 1.4)
	cultist.free()
	patron.free()
