extends GutTest

const GAME_SESSION_PATH := "res://scripts/simulation/game_session.gd"
const COMMAND_SYSTEM_PATH := "res://scripts/actions/cultist_command_system.gd"

const FLOOR_Y := 0.18
const BAR_APPROACH := Vector3(0.0, FLOOR_Y, 1.62)
const TRAPDOOR_APPROACH := Vector3(7.2, FLOOR_Y, 1.62)
const INTAKE_APPROACH := Vector3(15.0, FLOOR_Y, 6.0)


func _commands_for(session):
	var commands = load(COMMAND_SYSTEM_PATH).new()
	commands.reset(session)
	commands.register_smart_object(&"bar_work_position", "Bar Work Position", BAR_APPROACH)
	commands.register_smart_object(&"front_entrance", "Front Entrance", Vector3(-17.5, FLOOR_Y, 5.0))
	commands.register_smart_object(&"trapdoor_control", "Trapdoor Control", TRAPDOOR_APPROACH)
	commands.register_smart_object(&"tunnel_intake", "Tunnel Intake", INTAKE_APPROACH)
	return commands


# Connects snapshot refresh without forming a session-to-command-system ownership
# cycle: the command system already owns the session.
func _connect_command_refresh(session, commands) -> void:
	var weak_commands: WeakRef = weakref(commands)
	session.snapshot_changed.connect(func(_state: Dictionary) -> void:
		var live_commands: Object = weak_commands.get_ref()
		if live_commands != null:
			live_commands.refresh()
	)


# A Night with the first Arrival Group seated and waiting on their Orders.
func _seated_night(seed: int = 707) -> Array:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(seed)
	session.advance(3.0)
	assert_true(session.begin_admit_group(1))
	session.advance(4.1)
	assert_eq(session.command_action_state(&"admit_group", 1, &"front_entrance"), &"completed")
	return [session, _commands_for(session)]


func _advance_with_admissions(session, target_seconds: float) -> void:
	for arrival: float in [3.0, 93.0, 213.0, 333.0]:
		if arrival > target_seconds:
			break
		if float(session.snapshot()["simulated_seconds"]) < arrival:
			session.advance(arrival - float(session.snapshot()["simulated_seconds"]))
		if session.begin_admit_group(3):
			session.advance(3.1)
			session.advance(1.1)
			session.command_action_state(&"admit_group", 3, &"front_entrance")
	if float(session.snapshot()["simulated_seconds"]) < target_seconds:
		session.advance(target_seconds - float(session.snapshot()["simulated_seconds"]))


func _floor_target(x: float, z: float) -> Dictionary:
	return {"kind": &"floor", "id": &"floor", "position": Vector3(x, FLOOR_Y, z)}


func _patron_target(patron_id: int) -> Dictionary:
	return {"kind": &"patron", "id": patron_id, "position": Vector3.ZERO}


func _cultist_target(cultist_id: int) -> Dictionary:
	return {"kind": &"cultist", "id": cultist_id, "position": Vector3.ZERO}


func _object_target(object_id: StringName) -> Dictionary:
	return {"kind": &"smart_object", "id": object_id, "position": Vector3.ZERO}


# Issues a command already adjacent to its target, then walks it to the
# Commitment Point. Passing is_adjacent skips the Generated Move so the requested
# Action is active at once, which keeps the catalog effect tests direct.
func _run(commands, cultist_id: int, command: StringName, target: Dictionary) -> Dictionary:
	var issued: Dictionary = commands.issue(cultist_id, command, target, false, {"is_adjacent": true})
	if not bool(issued["accepted"]):
		return {"accepted": false, "committed": false, "reason": issued["reason"]}
	var reached: Dictionary = commands.notify_reached(cultist_id, int(issued["action_id"]))
	reached["accepted"] = true
	return reached


func _option(commands, cultist_id: int, target: Dictionary, command: StringName) -> Dictionary:
	for option: Dictionary in commands.resolve_options(cultist_id, target):
		if option["command"] == command:
			return option
	return {}


func _queue(commands, cultist_id: int) -> Dictionary:
	return commands.snapshot()["cultists"][cultist_id]


# --- Queue order, replace, and append ----------------------------------------

func test_normal_command_replaces_and_shift_command_appends() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var first: Dictionary = commands.issue(1, &"move", _floor_target(-6.0, 4.0), false)
	var queued: Dictionary = commands.issue(1, &"move", _floor_target(-3.0, 4.0), true)
	var replacement: Dictionary = commands.issue(
		1, &"move", _floor_target(2.0, 4.0), false
	)
	assert_true(bool(first["accepted"]) and bool(queued["accepted"]))

	var queue := _queue(commands, 1)
	assert_eq(int(queue["active"]["id"]), int(replacement["action_id"]),
		"A normal command replaces the active Action before its Commitment Point.")
	assert_true(queue["pending"].is_empty(), "A normal command clears every pending Action.")


func test_a_large_queue_is_never_rejected_for_its_length() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	commands.issue(1, &"move", _floor_target(-6.0, 4.0), false)
	# Well past the old four-Action limit: every append is still accepted.
	for index in range(40):
		var appended: Dictionary = commands.issue(
			1, &"move", _floor_target(float(index), 4.0), true
		)
		assert_true(bool(appended["accepted"]), "No command is rejected because the queue is large.")
		assert_ne(appended["reason"], &"queue_full", "The queue-full rejection no longer exists.")
	assert_eq(int(_queue(commands, 1)["action_count"]), 41)


func test_mixed_move_and_context_commands_keep_the_order_they_were_queued() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var adjacent := {"is_adjacent": true}
	commands.issue(1, &"move", _floor_target(-6.0, 4.0), false)
	commands.issue(1, &"talk", _patron_target(4), true, adjacent)
	commands.issue(1, &"move", _floor_target(-2.0, 4.0), true)
	commands.issue(1, &"offer_cigarette", _patron_target(5), true, adjacent)
	commands.issue(1, &"move", _floor_target(4.0, 4.0), true)

	var queue := _queue(commands, 1)
	assert_eq(int(queue["action_count"]), 5)
	var order: Array = [queue["active"]["command"]]
	for entry: Dictionary in queue["pending"]:
		order.append(entry["command"])
	assert_eq(order, [&"move", &"talk", &"move", &"offer_cigarette", &"move"],
		"Move and context Actions keep the order the player queued them in.")


func test_pending_actions_can_be_removed_without_touching_the_active_action() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var active: Dictionary = commands.issue(1, &"move", _floor_target(-6.0, 4.0), false)
	var removable: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), true
	)

	assert_true(commands.remove_pending(1, int(removable["action_id"])))
	var queue := _queue(commands, 1)
	assert_eq(int(queue["active"]["id"]), int(active["action_id"]))
	assert_true(queue["pending"].is_empty())


# --- Commitment and cancellation ---------------------------------------------

func test_precommit_cancellation_releases_the_reservation_and_changes_nothing() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	commands.issue(1, &"talk", _patron_target(4), false)
	assert_eq(
		commands.snapshot()["reserved_slots"].get(1, &""),
		StringName("approach_%d" % 4),
		"An approach is reserved before movement starts."
	)

	commands.issue(1, &"move", _floor_target(-6.0, 4.0), false)
	assert_false(commands.snapshot()["reserved_slots"].has(1),
		"Cancelling before commitment releases the approach reservation.")
	assert_true(session.snapshot()["conversations"].is_empty(),
		"An interrupted approach has no gameplay effect.")


func test_active_cancellation_before_commitment_releases_and_starts_the_next_action() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	commands.issue(1, &"talk", _patron_target(4), false)
	var queued: Dictionary = commands.issue(
		1, &"move", _floor_target(-6.0, 4.0), true
	)
	assert_eq(
		commands.snapshot()["reserved_slots"].get(1, &""),
		StringName("approach_%d" % 4),
		"The approach is reserved while the Talk is running."
	)

	var cancelled: Dictionary = commands.request_cancel_active(1)
	assert_true(bool(cancelled["cancelled"]), "A pre-commitment Action can be cancelled.")
	assert_false(commands.snapshot()["reserved_slots"].has(1),
		"Cancelling releases the approach reservation.")
	assert_true(session.snapshot()["conversations"].is_empty(),
		"A cancelled approach leaves no gameplay effect.")

	var queue := _queue(commands, 1)
	assert_eq(int(queue["active"]["id"]), int(queued["action_id"]),
		"The next pending Action becomes active at once.")
	assert_true(queue["pending"].is_empty())


func test_cancellation_cannot_undo_an_action_past_its_commitment_point() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false, {"is_adjacent": true}
	)
	commands.notify_reached(1, int(issued["action_id"]))
	assert_false(session.snapshot()["conversations"].is_empty(),
		"The Talk committed, so the conversation is running.")

	var refused: Dictionary = commands.request_cancel_active(1)
	assert_false(bool(refused["cancelled"]),
		"A committed held Action cannot be cancelled through its tile.")
	assert_eq(refused["reason"], &"already_committed")
	assert_false(String(refused["message"]).is_empty(),
		"A refusal always carries a visible reason.")
	assert_false(session.snapshot()["conversations"].is_empty(),
		"The committed gameplay effect survives the refused cancellation.")


func test_cancelling_the_last_action_leaves_an_idle_queue_and_no_reservation() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	commands.issue(1, &"talk", _patron_target(4), false)
	assert_true(bool(commands.request_cancel_active(1)["cancelled"]))

	var queue := _queue(commands, 1)
	assert_true(queue["active"].is_empty(), "The Action Queue is idle again.")
	assert_eq(int(queue["action_count"]), 0)
	assert_false(commands.snapshot()["reserved_slots"].has(1),
		"An idle Cultist holds no approach slot.")


func test_the_normal_snapshot_marks_each_action_cancellable_without_hidden_state() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false, {"is_adjacent": true}
	)
	commands.issue(1, &"move", _floor_target(-6.0, 4.0), true)
	var queue := _queue(commands, 1)
	assert_eq(int(queue["active"]["id"]), int(issued["action_id"]))
	assert_true(bool(queue["active"]["cancellable"]),
		"An Action still approaching can be cancelled.")
	assert_true(bool(queue["pending"][0]["cancellable"]),
		"A pending Action can always be removed.")
	assert_eq(queue["active"]["stage"], &"approaching",
		"An Action before its Commitment Point is still approaching.")

	# The view adds display and chain fields only; no internal payload leaks.
	var expected: Array[String] = [
		"id", "command", "icon", "label", "target_kind", "target_id", "target_label", "stage",
		"cancellable", "chain_id", "chain_index", "chain_size", "generated", "progress_ratio",
	]
	var keys: Array = queue["active"].keys()
	keys.sort()
	expected.sort()
	assert_eq(keys, expected as Array, "An Action view carries display and chain fields only.")


func test_the_effect_fires_once_at_commitment_and_a_later_command_cannot_reverse_it() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"make_wine", _object_target(&"bar_work_position"), false
	)
	commands.notify_reached(1, int(issued["action_id"]))
	commands.advance(5.0)
	var drink_count: int = session.snapshot()["prepared_drinks"]["drinks"].size()
	assert_eq(drink_count, 1)

	commands.issue(1, &"move", _floor_target(-6.0, 4.0), false)
	assert_eq(session.snapshot()["prepared_drinks"]["drinks"].size(), drink_count,
		"A command issued after the Commitment Point does not undo the effect.")
	assert_true(commands.snapshot()["cultists"][1]["active"]["command"] == &"move")


func test_a_stale_target_fails_visibly_and_advances_the_queue() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false, {"is_adjacent": true}
	)
	assert_true(bool(issued["accepted"]))
	commands.issue(1, &"move", _floor_target(-6.0, 4.0), true)

	# The Patron becomes unconscious, so the pending social target goes stale.
	session.debug_set_patron_drink_state(4, 3, 1, 0, 3)
	session.debug_force_finish_drink(4)
	session.advance(0.2)
	commands.refresh(1)

	var queue := _queue(commands, 1)
	assert_eq(queue["active"]["command"], &"move", "A stale Action fails and the queue advances.")
	assert_eq(queue["feedback"]["outcome"], &"failed")
	assert_false(String(queue["feedback"]["message"]).is_empty(),
		"A stale target fails with a visible reason.")
	assert_false(commands.snapshot()["reserved_slots"].has(1),
		"A failed Action releases its reservation.")


func test_navigation_failure_releases_the_reservation_and_reports_a_reason() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false, {"is_adjacent": true}
	)
	commands.notify_failed(1, int(issued["action_id"]), &"path_stuck")

	var queue := _queue(commands, 1)
	assert_true(queue["active"].is_empty())
	assert_eq(queue["feedback"]["reason"], &"path_stuck")
	assert_false(commands.snapshot()["reserved_slots"].has(1))


# --- Contention ---------------------------------------------------------------

func test_three_cultists_can_work_at_the_bar_at_the_same_time() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var first: Dictionary = commands.issue(
		1, &"make_wine", _object_target(&"bar_work_position"), false
	)
	var second: Dictionary = commands.issue(
		2, &"make_beer", _object_target(&"bar_work_position"), false
	)
	var third: Dictionary = commands.issue(
		3, &"make_liquor", _object_target(&"bar_work_position"), false
	)

	assert_true(bool(first["accepted"]))
	assert_true(bool(second["accepted"]))
	assert_true(bool(third["accepted"]))
	commands.notify_reached(1, int(first["action_id"]))
	commands.notify_reached(2, int(second["action_id"]))
	commands.notify_reached(3, int(third["action_id"]))
	commands.advance(5.0)
	assert_eq(session.snapshot()["prepared_drinks"]["drinks"].size(), 3,
		"Three simultaneous bar Actions complete without blocking one another.")


# --- Generated Move and Action Chains -----------------------------------------


func test_admission_survives_command_ticks_and_releases_after_group_entry() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	session.advance(3.1)
	var commands = _commands_for(session)
	_connect_command_refresh(session, commands)
	var issued: Dictionary = commands.issue(1, &"admit_group", _object_target(&"front_entrance"), false)
	assert_true(issued["accepted"])
	commands.notify_reached(1, int(issued["action_id"]))
	commands.advance(0.1)
	assert_false(_queue(commands, 1)["active"].is_empty(), "The active admission must not reject itself as Busy.")
	for step in range(50):
		session.advance(0.1)
		commands.advance(0.1)
	assert_eq(session.snapshot()["debug_patron_views"][4]["activity"], &"awaiting_drink")
	assert_true(_queue(commands, 1)["active"].is_empty(), "The committed door hold ends when the group enters.")

func test_every_patron_command_is_proximity_dependent() -> void:
	var catalog: Dictionary = CultistCommandSystem.CATALOG
	for command: StringName in CultistCommandSystem.PATRON_COMMANDS:
		assert_true(bool(catalog[command].get("requires_proximity", false)),
			"%s is a Patron command, so it needs a Generated Move when not adjacent." % command)
	for command: StringName in [&"move", &"drop_body", &"make_wine", &"make_beer", &"make_liquor", &"drug_drink", &"activate_trapdoor"]:
		assert_false(bool(catalog[command].get("requires_proximity", false)),
			"%s is not proximity-dependent." % command)


func test_nonadjacent_talk_creates_a_visible_move_then_talk_chain() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false
	)
	assert_true(bool(issued["accepted"]))
	assert_eq(issued["generated_action_ids"].size(), 1,
		"A nonadjacent Talk gains one Generated Move prerequisite.")
	assert_eq(int(issued["action_id"]), int(_queue(commands, 1)["pending"][0]["id"]),
		"The returned action_id is the requested Talk, not the Generated Move.")

	var queue := _queue(commands, 1)
	var active: Dictionary = queue["active"]
	assert_eq(active["command"], &"generated_move", "The Generated Move runs first.")
	assert_eq(active["label"], "Move", "The Generated Move renders as Move.")
	assert_eq(active["icon"], &"move")
	assert_true(bool(active["generated"]))
	assert_eq(queue["pending"][0]["command"], &"talk")
	assert_gt(int(active["chain_id"]), -1)
	assert_eq(int(active["chain_id"]), int(queue["pending"][0]["chain_id"]),
		"The Generated Move and the Talk share one Action Chain identity.")


func test_nonadjacent_offer_cigarette_creates_a_visible_move_chain() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	commands.issue(1, &"offer_cigarette", _patron_target(4), false)
	var queue := _queue(commands, 1)
	assert_eq(queue["active"]["command"], &"generated_move")
	assert_eq(queue["pending"][0]["command"], &"offer_cigarette",
		"Every Patron command follows the catalog-wide proximity rule.")


func test_adjacent_patron_command_creates_no_generated_move() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false, {"is_adjacent": true}
	)
	assert_true(issued["generated_action_ids"].is_empty(),
		"An adjacent Patron command needs no Generated Move.")
	var queue := _queue(commands, 1)
	assert_eq(queue["active"]["command"], &"talk")
	assert_true(queue["pending"].is_empty())


func test_shift_appends_a_full_chain_after_unrelated_work() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	commands.issue(1, &"move", _floor_target(-6.0, 4.0), false)
	commands.issue(1, &"talk", _patron_target(4), true)
	var queue := _queue(commands, 1)
	assert_eq(queue["active"]["command"], &"move", "The unrelated Move keeps running.")
	var order: Array = queue["pending"].map(func(a: Dictionary) -> StringName: return a["command"])
	assert_eq(order, [&"generated_move", &"talk"], "Shift appends the whole chain after it.")


func test_a_patron_that_moves_before_activation_inserts_a_generated_move() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false, {"is_adjacent": true}
	)
	# The Talk is at the head but the Patron drifted out of reach before it started.
	var outcome: Dictionary = commands.resolve_proximity(
		1, int(issued["action_id"]), false
	)
	assert_true(bool(outcome.get("inserted_move", false)))
	var queue := _queue(commands, 1)
	assert_eq(queue["active"]["command"], &"generated_move",
		"A Patron who moved gains a Generated Move at the head.")
	assert_eq(queue["pending"][0]["command"], &"talk")


func test_generated_move_and_dependent_action_share_one_reservation() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false
	)
	assert_eq(commands.snapshot()["reserved_slots"].get(1, &""),
		StringName("approach_%d" % 4), "The Generated Move reserves the Approach Position.")
	var move_id := int(commands.active_request(1)["action_id"])
	commands.notify_reached(1, move_id)
	assert_eq(commands.snapshot()["reserved_slots"].get(1, &""),
		StringName("approach_%d" % 4),
		"The reservation stays through the chain with no release gap.")
	var talk_id := int(issued["action_id"])
	assert_true(bool(commands.resolve_proximity(1, talk_id, true)["committed"]),
		"Adjacent at the head, the Talk commits.")


func test_cancelling_a_chain_tile_removes_all_links_and_releases_reservation() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false
	)
	# Cancelling the dependent Talk tile drops its Generated Move too.
	assert_true(commands.remove_pending(1, int(issued["action_id"])))
	var queue := _queue(commands, 1)
	assert_true(queue["active"].is_empty(), "The whole chain left the queue.")
	assert_false(commands.snapshot()["reserved_slots"].has(1),
		"Cancelling the chain releases its one reservation.")


func test_navigation_failure_cancels_dependent_links_and_starts_the_next_action() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	commands.issue(1, &"talk", _patron_target(4), false)
	var unrelated: Dictionary = commands.issue(
		1, &"move", _floor_target(-6.0, 4.0), true
	)
	var move_id := int(commands.active_request(1)["action_id"])
	commands.notify_failed(1, move_id, &"path_stuck")

	var queue := _queue(commands, 1)
	assert_eq(int(queue["active"]["id"]), int(unrelated["action_id"]),
		"The next unrelated Action starts after the chain fails.")
	assert_false(commands.snapshot()["reserved_slots"].has(1))


func test_no_queue_full_reason_appears_in_normal_behavior() -> void:
	var pair := _seated_night()
	var commands = pair[1]
	for index in range(12):
		commands.issue(1, &"move", _floor_target(float(index), 4.0), true)
	var text := JSON.stringify(commands.snapshot())
	assert_false(text.contains("queue_full"), "The queue-full reason is gone from the snapshot.")


# --- Catalog: Patron targets ---------------------------------------------------

func test_talk_commits_and_is_unavailable_for_a_missing_patron() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(commands, 1, &"talk", _patron_target(4))["committed"]))
	assert_eq(session.snapshot()["conversations"].get(1, &""), 4)
	assert_eq(
		_queue(commands, 1)["active"]["command"],
		&"talk",
		"Talk remains the active Action while the conversation continues."
	)

	assert_true(_option(commands, 1, _patron_target(11), &"talk").is_empty(),
		"A Patron who has not arrived offers no Talk.")


func test_replacing_talk_ends_it_but_shift_appended_work_waits() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(
		commands, 1, &"talk", _patron_target(4)
	)["committed"]))
	var appended: Dictionary = commands.issue(
		1, &"move", _floor_target(-6.0, 4.0), true
	)
	var waiting := _queue(commands, 1)
	assert_eq(waiting["active"]["command"], &"talk")
	assert_eq(int(waiting["pending"][0]["id"]), int(appended["action_id"]))

	var replacement: Dictionary = commands.issue(
		1, &"move", _floor_target(2.0, 4.0), false
	)
	assert_true(session.snapshot()["conversations"].is_empty())
	var replaced := _queue(commands, 1)
	assert_eq(int(replaced["active"]["id"]), int(replacement["action_id"]))
	assert_true(replaced["pending"].is_empty())


func test_a_higher_priority_patron_behavior_completes_talk_and_starts_waiting_work() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(
		commands, 1, &"talk", _patron_target(4)
	)["committed"]))
	var appended: Dictionary = commands.issue(
		1, &"move", _floor_target(-6.0, 4.0), true
	)
	assert_true(session.end_conversation(1))
	commands.refresh(1)

	var queue := _queue(commands, 1)
	assert_eq(int(queue["active"]["id"]), int(appended["action_id"]))
	assert_true(queue["pending"].is_empty())


func test_service_uses_a_reserved_drink_pickup_move_and_handoff_chain() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(
		_option(commands, 1, _patron_target(4), &"serve_order").is_empty(),
		"Patrons no longer expose the direct Serve Order command."
	)
	var drink_type: StringName = session.patron_view(4, 1)["ordered_drink"]
	var make_command := StringName("make_%s" % drink_type)
	var make: Dictionary = commands.issue(
		1, make_command, _object_target(&"bar_work_position"), false
	)
	commands.notify_reached(1, int(make["action_id"]))
	commands.advance(5.0)
	var drink_id: StringName = session.snapshot()["prepared_drinks"]["drinks"][0]["id"]
	var service: Dictionary = commands.issue_drink_service(
		1, drink_id, _patron_target(4), false
	)
	assert_true(bool(service["accepted"]))
	assert_eq(_queue(commands, 1)["active"]["command"], &"pick_up_drink")
	commands.notify_reached(1, int(service["generated_action_ids"][0]))
	commands.advance(1.0)
	commands.notify_reached(1, int(service["generated_action_ids"][1]))
	commands.resolve_proximity(1, int(service["action_id"]), true)
	commands.advance(1.0)
	assert_eq(int(session.snapshot()["orders"]["served_count"]), 1)
	assert_true(session.prepared_drink(drink_id).is_empty())
	assert_false(session.is_cultist_busy(1),
		"A successful handoff releases the serving Cultist's busy state.")
	var talk: Dictionary = commands.issue(
		1, &"talk", _patron_target(4), false,
		{"is_adjacent": true}
	)
	assert_true(bool(talk["accepted"]),
		"The serving Cultist can start another context Action after handoff.")

	assert_true(session.make_drink(&"wine", 2))
	var next_drink_id: StringName = session.snapshot()["prepared_drinks"]["drinks"][0]["id"]
	var drug: Dictionary = commands.issue(
		2, &"drug_drink",
		{"kind": &"prepared_drink", "id": next_drink_id, "position": Vector3.ZERO}, false
	)
	assert_true(bool(drug["accepted"]),
		"The other Cultist can drug a drink after the first Cultist serves one.")


func test_drink_menu_exposes_service_drugging_and_disposal() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var preparation: Dictionary = commands.issue(
		1, &"make_wine", _object_target(&"bar_work_position"), false
	)
	commands.notify_reached(1, int(preparation["action_id"]))
	commands.advance(5.0)
	var drink_id: StringName = session.snapshot()["prepared_drinks"]["drinks"][0]["id"]
	var options: Array[Dictionary] = commands.resolve_drink_options(drink_id, 1)
	assert_eq(options.map(func(option: Dictionary) -> StringName: return option["command"]), [
		&"serve_drink_to", &"drug_drink", &"dispose_drink",
	])


func test_offer_cigarette_commits_and_needs_a_conscious_patron() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var before: float = session.friendship_value(4, 1)
	assert_true(bool(_run(commands, 1, &"offer_cigarette", _patron_target(4))["committed"]))
	assert_gt(session.friendship_value(4, 1), before)
	assert_true(
		_option(commands, 1, _patron_target(9), &"offer_cigarette").is_empty(),
		"A Patron who has not arrived offers no cigarette."
	)


func test_knock_out_commits_and_is_disabled_while_another_windup_runs() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]
	_connect_command_refresh(session, commands)

	var issued: Dictionary = commands.issue(
		1, &"knock_out", _patron_target(4), false,
		{"is_adjacent": true}
	)
	var started: Dictionary = commands.notify_reached(1, int(issued["action_id"]))
	assert_false(bool(started["committed"]), "The two-second wind-up starts before impact.")
	assert_eq(session.snapshot()["windup"]["victim_id"], 4)
	assert_eq(_queue(commands, 1)["active"]["stage"], &"executing")

	var blocked := _option(commands, 2, _patron_target(5), &"knock_out")
	assert_false(blocked.is_empty())
	assert_false(bool(blocked["available"]), "One wind-up at a time.")
	assert_eq(blocked["reason"], &"cultist_busy")

	assert_true(bool(commands.request_cancel_active(1)["cancelled"]))
	assert_true(session.snapshot()["windup"].is_empty())
	assert_eq(session.snapshot()["debug_patron_views"][4]["lifecycle"], &"active")

	var second: Dictionary = commands.issue(
		1, &"knock_out", _patron_target(4), false,
		{"is_adjacent": true}
	)
	commands.notify_reached(1, int(second["action_id"]))
	session.advance(2.1)
	commands.refresh(1)
	assert_eq(session.snapshot()["debug_patron_views"][4]["lifecycle"], &"unconscious")
	assert_true(_queue(commands, 1)["active"].is_empty())


func test_failed_knockout_replaces_the_queue_with_a_locked_tile_until_stirred() -> void:
	var session = null
	var commands = null
	for seed in range(1, 101):
		var pair := _seated_night(seed)
		session = pair[0]
		commands = pair[1]
		_connect_command_refresh(session, commands)
		session.debug_set_patron_drink_state(4, 0, 5)
		var attempt: Dictionary = commands.issue(
			1, &"knock_out", _patron_target(4), false,
			{"is_adjacent": true}
		)
		commands.notify_reached(1, int(attempt["action_id"]))
		session.advance(2.1)
		commands.refresh()
		if session.cultist_is_incapacitated(1):
			break
	assert_true(session.cultist_is_incapacitated(1))
	var locked: Dictionary = _queue(commands, 1)["active"]
	assert_eq(locked["command"], &"knocked_out")
	assert_false(bool(locked["cancellable"]))
	assert_almost_eq(float(locked["progress_ratio"]), 1.0, 0.01)
	var rejected: Dictionary = commands.issue(
		1, &"move", _floor_target(1.0, 1.0), false
	)
	assert_false(bool(rejected["accepted"]))
	assert_eq(rejected["reason"], &"cultist_incapacitated")

	var stir: Dictionary = commands.issue(
		2, &"stir", _cultist_target(1), false,
		{"is_adjacent": true}
	)
	assert_true(bool(stir["accepted"]))
	commands.notify_reached(2, int(stir["action_id"]))
	var duplicate: Dictionary = _option(commands, 3, _cultist_target(1), &"stir")
	assert_false(bool(duplicate["available"]))
	assert_eq(duplicate["reason"], &"already_helping")
	session.advance(3.1)
	commands.refresh()
	assert_false(session.cultist_is_incapacitated(1))
	assert_true(_queue(commands, 1)["active"].is_empty())
	assert_true(_queue(commands, 2)["active"].is_empty())


func test_pick_up_body_commits_only_for_an_unconscious_patron() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(
		_option(commands, 1, _patron_target(4), &"pick_up_body").is_empty(),
		"A conscious Patron offers no Pick Up Body."
	)

	session.debug_set_patron_drink_state(4, 3, 1, 0, 3)
	session.debug_force_finish_drink(4)
	session.advance(0.2)
	assert_eq(session.snapshot()["debug_patron_views"][4]["lifecycle"], &"unconscious")

	assert_true(bool(_run(commands, 1, &"pick_up_body", _patron_target(4))["committed"]))
	assert_true(session.snapshot()["drags"].has(4))
	assert_eq(_queue(commands, 1)["active"]["command"], &"pick_up_body")
	session.advance(1.1)
	commands.refresh(1)
	assert_true(_queue(commands, 1)["active"].is_empty(),
		"Pick Up Body completes when the body enters the dragging phase.")


func test_drop_body_appears_only_while_a_body_is_carried() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(_option(commands, 1, _floor_target(-6.0, 4.0), &"drop_body").is_empty(),
		"Drop Body Here stays out of the floor menu when nothing is carried.")

	session.debug_set_patron_drink_state(4, 3, 1, 0, 3)
	session.debug_force_finish_drink(4)
	session.advance(0.2)
	_run(commands, 1, &"pick_up_body", _patron_target(4))
	session.advance(1.1)
	commands.refresh(1)

	assert_false(_option(commands, 1, _floor_target(-6.0, 4.0), &"drop_body").is_empty())
	assert_true(bool(_run(commands, 1, &"drop_body", _floor_target(-6.0, 4.0))["committed"]))
	assert_false(session.snapshot()["drags"].has(4))


func test_intercept_appears_only_for_an_escaping_patron() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	_advance_with_admissions(session, 100.0)
	var commands = _commands_for(session)

	assert_true(_option(commands, 1, _patron_target(6), &"intercept").is_empty(),
		"A calm Patron offers no Intercept.")

	session.report_patron_stimulus(6, &"drink_dosed_seen")
	session.advance(2.2)
	assert_true(bool(_run(commands, 1, &"intercept", _patron_target(6))["committed"]))
	assert_eq(session.snapshot()["active_intercept"]["patron_id"], 6)
	assert_eq(_queue(commands, 1)["active"]["command"], &"intercept")
	session.advance(5.1)
	commands.refresh(1)
	assert_true(_queue(commands, 1)["active"].is_empty())


func test_lead_to_tunnel_appears_only_at_trusted_friendship() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	_advance_with_admissions(session, 100.0)
	var commands = _commands_for(session)

	assert_true(
		_option(commands, 1, _patron_target(6), &"lead_to_tunnel").is_empty(),
		"Friendship Capture stays hidden below Trusted."
	)
	for _cigarette in range(8):
		session.offer_cigarette(1, 6)

	assert_true(bool(_run(commands, 1, &"lead_to_tunnel", _patron_target(6))["committed"]))
	assert_true(session.snapshot()["follows"].has(6))
	assert_eq(_queue(commands, 1)["active"]["command"], &"lead_to_tunnel")
	session.advance(14.1)
	commands.refresh(1)
	assert_true(_queue(commands, 1)["active"].is_empty())


func test_rescue_persuasion_targets_the_current_helper_only() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	_advance_with_admissions(session, 10.0)
	session.prepare_drugged_drink(5, 1)
	session.advance(8.1)
	session.serve_patron_order(5, 2)
	session.advance(28.1)  # collapse, reaction, and the lift into the carry
	var commands = _commands_for(session)

	assert_true(
		_option(commands, 1, _patron_target(5), &"rescue_persuasion").is_empty(),
		"The collapsed Patron is not the Rescue Persuasion target."
	)
	assert_true(bool(_run(commands, 1, &"rescue_persuasion", _patron_target(4))["committed"]))
	assert_eq(session.snapshot()["collapses"][5]["phase"], &"persuading")
	assert_eq(_queue(commands, 1)["active"]["command"], &"rescue_persuasion")
	session.advance(6.1)
	commands.refresh(1)
	assert_true(_queue(commands, 1)["active"].is_empty())


# --- Catalog: smart-object and floor targets ----------------------------------

func test_bar_commands_make_each_drink_type() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var options: Array[Dictionary] = commands.resolve_options(
		1, _object_target(&"bar_work_position")
	)
	var listed: Array = options.map(func(option: Dictionary) -> StringName: return option["command"])
	assert_eq(listed, [&"make_wine", &"make_beer", &"make_liquor", &"move"],
		"The bar work position offers its own commands and a plain approach.")

	var issued: Dictionary = commands.issue(
		2, &"make_liquor", _object_target(&"bar_work_position"), false
	)
	commands.notify_reached(2, int(issued["action_id"]))
	commands.advance(5.0)
	assert_eq(session.snapshot()["prepared_drinks"]["drinks"][0]["type"], &"liquor")


func test_make_drink_uses_its_five_second_action_duration() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]
	_connect_command_refresh(session, commands)

	var issued: Dictionary = commands.issue(
		1, &"make_beer", _object_target(&"bar_work_position"), false
	)
	var reached: Dictionary = commands.notify_reached(1, int(issued["action_id"]))
	assert_false(bool(reached["committed"]), "Arrival starts preparation before commitment.")
	assert_true(session.snapshot()["prepared_drinks"]["drinks"].is_empty())
	assert_eq(_queue(commands, 1)["active"]["stage"], &"executing")

	commands.advance(4.9)
	assert_true(session.snapshot()["prepared_drinks"]["drinks"].is_empty())
	assert_false(_queue(commands, 1)["active"].is_empty())

	commands.advance(0.1)
	assert_eq(session.snapshot()["prepared_drinks"]["drinks"][0]["type"], &"beer")
	assert_true(_queue(commands, 1)["active"].is_empty())


func test_activate_trapdoor_commits_and_reports_its_cooldown() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(commands, 1, &"activate_trapdoor", _object_target(&"trapdoor_control"))["committed"]))
	assert_eq(session.snapshot()["trapdoor"]["state"], &"open")

	var blocked := _option(commands, 2, _object_target(&"trapdoor_control"), &"activate_trapdoor")
	assert_false(bool(blocked["available"]))
	assert_eq(blocked["reason"], &"trapdoor_busy")


func test_the_tunnel_intake_offers_no_capture_command_of_its_own() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var listed: Array = commands.resolve_options(
		1, _object_target(&"tunnel_intake")
	).map(func(option: Dictionary) -> StringName: return option["command"])
	assert_eq(listed, [&"move"],
		"The Tunnel Intake is a destination, never a Capture command by itself.")


func test_move_stays_the_plain_floor_command() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var listed: Array = commands.resolve_options(1, _floor_target(-6.0, 4.0)).map(
		func(option: Dictionary) -> StringName: return option["command"]
	)
	assert_eq(listed, [&"move"], "Empty floor offers Move alone.")
	var reached := _run(commands, 1, &"move", _floor_target(-6.0, 4.0))
	assert_true(bool(reached["committed"]))
	assert_true(_queue(commands, 1)["active"].is_empty())


# --- Information safety and lifecycle -----------------------------------------

func test_normal_snapshots_and_menu_labels_hide_simulation_values() -> void:
	var pair := _seated_night()
	var commands = pair[1]
	commands.issue(1, &"talk", _patron_target(4), false)

	var forbidden: Array[String] = [
		"suspicion", "bladder", "satisfaction_value", "overdrink_limit", "excess_drinks",
		"ideal_intoxication_level", "roll", "remaining", "elapsed_seconds",
		"bathroom_probability", "drug_countdown",
	]
	var text := JSON.stringify(commands.snapshot())
	for key: String in forbidden:
		assert_false(text.contains(key), "The normal command snapshot must not carry %s." % key)

	for option: Dictionary in commands.resolve_options(1, _patron_target(4)):
		assert_eq(option["target_label"], "???",
			"An Unidentified Patron keeps their name hidden in the menu.")


func test_ten_restarts_leave_no_command_or_reservation_state() -> void:
	var session = load(GAME_SESSION_PATH).new()
	var commands = null
	for _restart in range(10):
		session.start_night(4_242)
		commands = _commands_for(session)
		session.advance(95.0)
		commands.issue(1, &"talk", _patron_target(4), false)
		commands.issue(2, &"prepare_drink", _object_target(&"bar_work_position"), false)
		commands.reset(session)
		var state: Dictionary = commands.snapshot()
		assert_eq(int(state["action_count"]), 0, "A restart leaves no Action behind.")
		assert_true(state["reserved_slots"].is_empty(), "A restart leaves no reservation behind.")
		assert_true(state["recent_events"].is_empty())


func test_a_captured_patron_drops_the_command_queued_against_them() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	_advance_with_admissions(session, 100.0)
	var commands = _commands_for(session)
	for _cigarette in range(8):
		session.offer_cigarette(1, 6)

	# Cultist 02 lines up a Talk behind a Move, so it holds no reservation yet.
	var move: Dictionary = commands.issue(
		2, &"move", _floor_target(-6.0, 4.0), false
	)
	assert_true(bool(commands.issue(2, &"talk", _patron_target(6), true)["accepted"]))
	_run(commands, 1, &"lead_to_tunnel", _patron_target(6))

	session.advance(15.0)  # the follow reaches the Tunnel Intake and Captures
	assert_eq(int(session.snapshot()["captures"]), 1)
	commands.refresh()
	commands.notify_reached(2, int(move["action_id"]))

	var queue := _queue(commands, 2)
	assert_true(queue["active"].is_empty(), "A Captured Patron leaves no Action behind.")
	assert_eq(queue["feedback"]["reason"], &"patron_unavailable")
	assert_true(commands.snapshot()["reserved_slots"].is_empty(),
		"A Captured Patron leaves no approach reservation behind.")


func test_the_night_ending_closes_every_command() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	_advance_with_admissions(session, 95.0)
	var commands = _commands_for(session)
	commands.issue(1, &"talk", _patron_target(4), false)

	session.advance(1_080.0)
	assert_eq(session.snapshot()["phase"], &"results")
	commands.refresh()

	assert_true(_queue(commands, 1)["active"].is_empty(),
		"Reaching Results clears the Action Queue.")
	assert_true(commands.snapshot()["reserved_slots"].is_empty(),
		"Reaching Results releases every approach reservation.")
	assert_true(commands.resolve_options(1, _patron_target(4)).is_empty(),
		"No command applies after the Night ends.")
