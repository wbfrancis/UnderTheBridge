extends GutTest

# Proves the production adapter projects the full result report into the Outcome
# view: every GDD field is carried, captures are grouped by their public method
# label with zero totals dropped, and the public Suspicion band comes from the
# exact peak. The card is left up so the adapter's own clock stays frozen and the
# session advances only where the test drives it.

const SCENE := "res://scenes/prototypes/main_test.tscn"


func _scene():
	var presentation = load(SCENE).instantiate()
	add_child_autofree(presentation)
	await get_tree().process_frame
	# Hold the Controls Card up on purpose: its frozen clock stops the adapter's
	# own _process advance, so the session moves only where this test drives it.
	presentation.set("_controls_visible", true)
	var frames := 0
	while frames < 1_200 and not bool(presentation.get("_navigation_ready")):
		await get_tree().physics_frame
		frames += 1
	return presentation


func test_capture_method_rows_use_public_labels_and_drop_zero_totals() -> void:
	var presentation = await _scene()
	var rows: Array = presentation._capture_method_rows({
		"capture_methods": {
			&"trapdoor": 2,
			&"drugged_drink": 3,
			&"knockout": 4,
			&"overdrink": 5,
			&"friendship_capture": 1,
			&"rescue_persuasion": 6,
		},
	})
	# Canonical order and exact public labels for all six causal methods.
	assert_eq(rows, [
		{"label": "Trapdoor", "count": 2},
		{"label": "Drugged Drink", "count": 3},
		{"label": "Knockout", "count": 4},
		{"label": "Overdrink", "count": 5},
		{"label": "Friendship Capture", "count": 1},
		{"label": "Rescue Persuasion", "count": 6},
	])


func test_the_outcome_view_mirrors_every_result_field() -> void:
	var presentation = await _scene()
	var session = presentation.get("_session")
	session.advance(120.0)  # let the Night open and orders form

	var state: Dictionary = session.snapshot()
	var results: Dictionary = state["results"]
	var outcome: Dictionary = presentation._hud_view(state)["outcome"]

	# Every projected GDD field is carried straight from the result projection.
	assert_eq(int(outcome["captures"]), int(results["captures"]))
	assert_eq(int(outcome["capture_quota"]), int(results["capture_quota"]))
	assert_eq(int(outcome["revenue"]), int(results["revenue"]))
	assert_eq(int(outcome["tips"]), int(results["tips"]))
	assert_eq(int(outcome["orders_served"]), int(results["orders_served"]))
	assert_eq(int(outcome["orders_cancelled"]), int(results["orders_cancelled"]))
	assert_eq(int(outcome["orders_missed"]), int(results["orders_missed"]))
	assert_eq(int(outcome["groups_missed_at_door"]), int(results["groups_missed_at_door"]))
	assert_eq(outcome["outcome_cause"], results["outcome_cause"])
	assert_eq(int(outcome["interceptions"]), int(results["interceptions"]))
	assert_almost_eq(
		float(outcome["unattended_body_seconds"]), float(results["unattended_body_seconds"]), 0.001
	)
	assert_eq(outcome["capture_methods"], presentation._capture_method_rows(results),
		"The method rows are the labeled, zero-dropped projection of the result methods.")
	assert_eq(String(outcome["suspicion_band"]),
		PatronSuspicion.band_for_score(float(results["peak_suspicion"])),
		"The public band is the peak Suspicion summarized, not the exact value.")


func test_success_preview_exercises_the_maximum_six_method_layout() -> void:
	var presentation = await _scene()
	presentation.set("_hud_preview_outcome", &"victory")
	var outcome: Dictionary = presentation._hud_view(
		presentation.get("_session").snapshot()
	)["outcome"]
	assert_eq(outcome["capture_methods"].size(), 6)
