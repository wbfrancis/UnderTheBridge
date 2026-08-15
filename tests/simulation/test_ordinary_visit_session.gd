extends GutTest

const SESSION_SCRIPT := preload("res://scripts/simulation/ordinary_visit_session.gd")


func test_group_gets_exclusive_seats_and_completes_service() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(45.0)
	var state: Dictionary = session.snapshot()
	assert_eq(state["seat_owners"].size(), 2)
	assert_ne(state["seat_owners"][&"seat_01"], state["seat_owners"][&"seat_02"])
	assert_eq(state["orders"]["revenue"], 10)
	assert_eq(state["orders"]["tips"], 4)
	assert_eq(state["normal_views"][&"patron_june"]["order_state"], &"served")
	assert_eq(state["normal_views"][&"patron_mara"]["order_state"], &"served")


func test_seeded_bathroom_checks_are_five_seconds_apart_and_use_empties_bladder() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(180.0)
	var state: Dictionary = session.snapshot()
	var rolls: Array = state["debug_views"][&"patron_june"]["recent_bathroom_rolls"]
	assert_gt(rolls.size(), 0)
	for index in range(1, rolls.size()):
		assert_almost_eq(float(rolls[index]["at"]) - float(rolls[index - 1]["at"]), 5.0, 0.001)
	assert_eq(state["debug_views"][&"patron_june"]["bladder"], 0.0)
	assert_eq(state["bathroom_owner"], &"")
	assert_true(_has_event(state["events"], &"bathroom_visit_completed", &"patron_june"))


func test_intoxication_rises_then_decays_after_four_drink_free_minutes() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(45.0)
	assert_eq(session.debug_patron_view(&"patron_june")["intoxication_level"], 1)
	session.advance(234.0)
	assert_eq(session.debug_patron_view(&"patron_june")["intoxication_level"], 1)
	session.advance(2.0)
	assert_eq(session.debug_patron_view(&"patron_june")["intoxication_level"], 0)


func test_normal_view_excludes_hidden_values_and_debug_view_exposes_them() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(45.0)
	var normal: Dictionary = session.normal_patron_view(&"patron_june")
	var debug: Dictionary = session.debug_patron_view(&"patron_june")
	for hidden_key in ["bladder", "bathroom_probability", "next_bathroom_check_in", "intoxication_decay_in", "night_seed", "recent_bathroom_rolls"]:
		assert_false(normal.has(hidden_key), "Normal view leaked %s" % hidden_key)
		assert_true(debug.has(hidden_key), "Debug view omitted %s" % hidden_key)
	assert_true(normal.has("visible_activity"))
	assert_true(normal.has("intoxication"))
	assert_true(normal.has("companions"))
	assert_true(normal.has("order_state"))


func test_group_makes_normal_departure_and_releases_seats() -> void:
	var session = SESSION_SCRIPT.new()
	session.start(707)
	session.advance(550.0)
	var state: Dictionary = session.snapshot()
	assert_eq(state["normal_views"][&"patron_june"]["visible_activity"], "Normal Departure")
	assert_eq(state["normal_views"][&"patron_mara"]["visible_activity"], "Normal Departure")
	assert_eq(state["seat_owners"][&"seat_01"], &"")
	assert_eq(state["seat_owners"][&"seat_02"], &"")
	assert_eq(_count_events(state["events"], &"normal_departure"), 2)


func _has_event(events: Array, event_name: StringName, actor_id: StringName) -> bool:
	for event: Dictionary in events:
		if event["event"] == event_name and event["actor_id"] == actor_id:
			return true
	return false


func _count_events(events: Array, event_name: StringName) -> int:
	var count := 0
	for event: Dictionary in events:
		if event["event"] == event_name:
			count += 1
	return count
