extends GutTest

# Drives the real playable presentation scene headlessly through one complete
# drink Order, the way the mandatory interactive gate does by hand: two Cultists,
# a Plain Pause and resume, make the requested drink, then carry it to the Patron. It proves
# the command seam, navigation, and playback still cooperate end to end.

const SCENE := "res://scenes/prototypes/main_test.tscn"
const COMMAND_SYSTEM := preload("res://scripts/actions/cultist_command_system.gd")

var _presentation


func before_each() -> void:
	_presentation = load(SCENE).instantiate()
	_presentation.review_stage = "drink_cycle"
	add_child_autofree(_presentation)
	await get_tree().process_frame
	assert_true(await _await_navigation_ready(), "Navigation baked for the scene.")
	# The first-run Controls Card holds the Night; dismiss it before driving time.
	_presentation._on_hud_intent(&"close_controls", {})
	# Run the Night fast so a headless drive settles quickly; the seam is unchanged.
	_presentation._submit_playback(&"select_speed", {"value": 4.0})
	await _presentation._wait_for_patrons(2_400)


func test_two_cultists_pause_resume_and_a_full_prepare_then_serve_cycle() -> void:
	var session = _presentation.get("_session")
	var cultists: Dictionary = _presentation.get("_cultist_nodes")
	assert_eq(cultists.size(), 2, "Vera and Iris are playable Cultists.")
	assert_true(cultists.has(ActorIds.CULTIST_IDS[0]))
	assert_true(cultists.has(ActorIds.CULTIST_IDS[1]))
	_presentation._select_cultist(ActorIds.CULTIST_IDS[1])
	assert_eq(_presentation.get("_selected_cultist_id"), ActorIds.CULTIST_IDS[1])
	_presentation._select_cultist(ActorIds.CULTIST_IDS[0])

	# The explicit drink-cycle stage opens on one unserved Order.
	var patron_id := _open_order_patron(session)
	assert_ne(patron_id, ActorIds.NO_ACTOR, "The drink-cycle stage has an open Order to serve.")
	assert_eq(int(session.snapshot()["orders"]["served_count"]), 0)

	# Plain Pause then resume must cross the real playback seam.
	_presentation._submit_playback(&"toggle_plain_pause", {})
	assert_eq(float(session.snapshot()["time_scale"]), 0.0, "Plain Pause stops the Night.")
	_presentation._submit_playback(&"toggle_plain_pause", {})
	assert_gt(float(session.snapshot()["time_scale"]), 0.0, "Resume restarts the Night.")

	# Make the requested drink at the bar, then run pickup, travel, and handoff.
	var drink_type: StringName = session.patron_view(patron_id, ActorIds.CULTIST_IDS[0])["ordered_drink"]
	assert_true(await _issue_and_settle(
		StringName("make_%s" % drink_type), _presentation._smart_target(&"bar_work_position")
	))
	var drinks: Array = session.snapshot()["prepared_drinks"]["drinks"]
	assert_eq(drinks.size(), 1, "The completed drink waits on the bar.")
	var patron_target: Dictionary = _presentation._actor_target(patron_id)
	patron_target["bar_position"] = _presentation._smart_target(&"bar_work_position")["position"]
	var service: Dictionary = _presentation._commands.issue_drink_service(
		ActorIds.CULTIST_IDS[0], StringName(drinks[0]["id"]), patron_target, false
	)
	assert_true(bool(service["accepted"]))
	assert_true(await _settle_cultist())
	assert_gt(int(session.snapshot()["orders"]["served_count"]), 0, "The Order completes.")

	# No Cultist is left stranded mid-command and no reservation leaks.
	assert_true(_presentation._commands.active_request(ActorIds.CULTIST_IDS[0]).is_empty(),
		"Vera is idle after the cycle.")
	assert_false(_presentation._commands.snapshot()["reserved_slots"].has(ActorIds.CULTIST_IDS[0]),
		"The bar and Patron reservations released.")

	# A passed-out body has no collision and trails the Cultist instead of using
	# its former Patron navigation.
	assert_true(session.begin_knockout(ActorIds.CULTIST_IDS[0], patron_id))
	session.advance(2.05)
	var body = _presentation._actor_pivot(patron_id) as CharacterBody3D
	assert_eq(body.collision_layer, 0)
	assert_eq(body.collision_mask, 0)
	assert_true(session.pick_up_body(ActorIds.CULTIST_IDS[0], patron_id))
	session.advance(1.05)
	assert_eq(session.snapshot()["debug_patron_views"][patron_id]["activity"], &"being_dragged")
	var cultist = _presentation.get("_cultist_nodes")[ActorIds.CULTIST_IDS[0]] as CharacterBody3D
	var separation := Vector2(body.global_position.x, body.global_position.z).distance_to(
		Vector2(cultist.global_position.x, cultist.global_position.z)
	)
	assert_eq(session.snapshot()["debug_patron_views"][patron_id]["lifecycle"], &"unconscious", "A body cannot capture before its Cultist reaches the intake.")
	assert_almost_eq(separation, 0.75, 0.05, "The body trails its dragging Cultist.")


func test_a_patron_walks_the_mirror_toilet_sink_exit_route_to_completion() -> void:
	var session = _presentation.get("_session")
	# Send Mara on a Bathroom Visit; the scene must walk her between distinct
	# stations and let each timed phase complete on a real navigation arrival.
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_companion()))
	var seen: Dictionary = {}
	var completed := false
	var frames := 0
	while frames < 6_000:
		var activity: StringName = session.snapshot()["debug_patron_views"][ScenarioActors.opening_companion()]["activity"]
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


func test_patrons_use_capsules_while_cultists_keep_their_character_sprites() -> void:
	var patrons: Dictionary = _presentation.get("_patron_nodes")
	var cultists: Dictionary = _presentation.get("_cultist_nodes")
	var patron = patrons[ScenarioActors.opening_patron()] as Node3D
	var cultist = cultists[ActorIds.CULTIST_IDS[0]] as Node3D

	assert_true(_has_capsule_mesh(patron), "A Patron uses a visible 3D capsule.")
	assert_true(patron.find_children("*", "Sprite3D", true, false).is_empty(),
		"A Patron no longer uses the Cultist sprite treatment.")
	assert_false(cultist.find_children("*", "Sprite3D", true, false).is_empty(),
		"A Cultist keeps the authored character sprite.")


func test_an_idle_cultist_yields_when_they_block_another_cultists_move_target() -> void:
	var cultists: Dictionary = _presentation.get("_cultist_nodes")
	var vera = cultists[ActorIds.CULTIST_IDS[0]] as CharacterBody3D
	var iris = cultists[ActorIds.CULTIST_IDS[1]] as CharacterBody3D
	var target: Vector3 = iris.global_position
	var iris_start: Vector3 = iris.global_position
	_presentation._select_cultist(ActorIds.CULTIST_IDS[0])
	_presentation._issue_command(&"move", {
		"kind": COMMAND_SYSTEM.TARGET_FLOOR,
		"id": &"floor",
		"position": target,
	}, false)

	assert_true(await _settle_cultist(), "Vera's Move reaches a terminal state.")
	assert_lt(vera.global_position.distance_to(target), 0.65,
		"Vera reaches the point that Iris blocked.")
	assert_gt(iris.global_position.distance_to(iris_start), 0.65,
		"Idle Iris moves aside instead of holding the path.")


# --- Drivers -------------------------------------------------------------------

func _has_event(events: Array, event_name: StringName, actor_id: int) -> bool:
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
	return await _settle_cultist()


func _settle_cultist() -> bool:
	var frames := 0
	var actor = _presentation.get("_cultist_nodes").get(ActorIds.CULTIST_IDS[0])
	while frames < 3_600:
		var idle: bool = _presentation._commands.snapshot()["cultists"][ActorIds.CULTIST_IDS[0]]["active"].is_empty()
		var still: bool = actor == null or not actor.is_navigating()
		if idle and still:
			return true
		await get_tree().physics_frame
		frames += 1
	return false


func _open_order_patron(session) -> int:
	var views: Dictionary = session.snapshot()["debug_patron_views"]
	for patron_id: int in views:
		if views[patron_id]["activity"] == &"awaiting_drink":
			return patron_id
	return ActorIds.NO_ACTOR


func _has_capsule_mesh(root: Node) -> bool:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		if child.mesh is CapsuleMesh:
			return true
	return false
