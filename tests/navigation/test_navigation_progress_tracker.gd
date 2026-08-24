extends GutTest

const TRACKER_PATH := "res://scripts/navigation/navigation_progress_tracker.gd"


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
