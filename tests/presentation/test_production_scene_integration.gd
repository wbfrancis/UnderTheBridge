extends GutTest

# Drives the real playable presentation scene headlessly through one complete
# drink Order, the way the mandatory interactive gate does by hand: one Cultist,
# a Plain Pause and resume, Prepare Drink at the bar, then Serve Order. It proves
# the command seam, navigation, and playback still cooperate end to end.

const SCENE := "res://scenes/prototypes/ticket16_presentation_review.tscn"
const COMMAND_SYSTEM := preload("res://scripts/actions/cultist_command_system.gd")

var _presentation


func before_each() -> void:
	_presentation = load(SCENE).instantiate()
	add_child_autofree(_presentation)
	await get_tree().process_frame
	assert_true(await _await_navigation_ready(), "Navigation baked for the scene.")
	# Run the Night fast so a headless drive settles quickly; the seam is unchanged.
	_presentation._submit_playback(&"select_speed", {"value": 4.0})
	await _presentation._wait_for_patrons(2_400)


func test_one_cultist_pause_resume_and_a_full_prepare_then_serve_cycle() -> void:
	var session = _presentation.get("_session")
	assert_eq(_presentation.get("_cultist_nodes").size(), 1, "Vera is the only playable Cultist.")

	# The default stage opens on one unserved Order.
	var patron_id := _open_order_patron(session)
	assert_ne(patron_id, &"", "The drink-cycle stage has an open Order to serve.")
	assert_eq(int(session.snapshot()["orders"]["served_count"]), 0)

	# Plain Pause then resume must cross the real playback seam.
	_presentation._submit_playback(&"toggle_plain_pause", {})
	assert_eq(float(session.snapshot()["time_scale"]), 0.0, "Plain Pause stops the Night.")
	_presentation._submit_playback(&"toggle_plain_pause", {})
	assert_gt(float(session.snapshot()["time_scale"]), 0.0, "Resume restarts the Night.")

	# Prepare a Drink at the bar, then serve the waiting Patron.
	assert_true(await _issue_and_settle(&"prepare_drink", _presentation._smart_target(&"bar_work_position")))
	assert_true(session.carries_prepared_drink(&"cultist_01"), "Vera carries the Prepared Drink.")

	assert_true(await _issue_and_settle(&"serve_order", _presentation._actor_target(patron_id)))
	assert_gt(int(session.snapshot()["orders"]["served_count"]), 0, "The Order completes.")

	# No Cultist is left stranded mid-command and no reservation leaks.
	assert_true(_presentation._commands.active_request(&"cultist_01").is_empty(),
		"Vera is idle after the cycle.")
	assert_false(_presentation._commands.snapshot()["reserved_slots"].has(&"cultist_01"),
		"The bar and Patron reservations released.")


func test_a_patron_walks_the_mirror_toilet_sink_exit_route_to_completion() -> void:
	var session = _presentation.get("_session")
	# Send Mara on a Bathroom Visit; the scene must walk her between distinct
	# stations and let each timed phase complete on a real navigation arrival.
	assert_true(session.debug_force_bathroom(&"patron_mara"))
	var seen: Dictionary = {}
	var completed := false
	var frames := 0
	while frames < 6_000:
		var activity: StringName = session.snapshot()["debug_patron_views"][&"patron_mara"]["activity"]
		seen[activity] = true
		# The visit is over once Mara has passed every phase and left the bathroom.
		if seen.has(&"handwashing") and activity in [&"socializing", &"awaiting_drink", &"normal_departure"]:
			completed = true
			break
		await get_tree().physics_frame
		frames += 1
	assert_true(completed, "The Bathroom Visit runs to completion in the live scene.")
	for phase: StringName in [
		&"entering_bathroom", &"mirror_check", &"moving_to_toilet",
		&"seated_bathroom_use", &"moving_to_sink", &"handwashing", &"standing_bathroom_exit",
	]:
		assert_true(seen.has(phase), "The visit visibly passed through %s." % phase)


# --- Drivers -------------------------------------------------------------------

func _has_event(events: Array, event_name: StringName, actor_id: StringName) -> bool:
	for event: Dictionary in events:
		if event["event"] == event_name and event["actor_id"] == actor_id:
			return true
	return false

func _await_navigation_ready() -> bool:
	var frames := 0
	while frames < 1_200:
		if bool(_presentation.get("_navigation_ready")):
			return true
		await get_tree().physics_frame
		frames += 1
	return false


func _issue_and_settle(command: StringName, target: Dictionary) -> bool:
	_presentation._issue_command(command, target, false)
	var frames := 0
	var actor = _presentation.get("_cultist_nodes").get(&"cultist_01")
	while frames < 3_600:
		var idle: bool = _presentation._commands.active_request(&"cultist_01").is_empty()
		var still: bool = actor == null or not actor.is_navigating()
		if idle and still:
			return true
		await get_tree().physics_frame
		frames += 1
	return false


func _open_order_patron(session) -> StringName:
	var views: Dictionary = session.snapshot()["debug_patron_views"]
	for patron_id: StringName in views:
		if views[patron_id]["activity"] == &"awaiting_drink":
			return patron_id
	return &""
