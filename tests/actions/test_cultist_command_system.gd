extends GutTest

const GAME_SESSION_PATH := "res://scripts/simulation/game_session.gd"
const COMMAND_SYSTEM_PATH := "res://scripts/actions/cultist_command_system.gd"

const FLOOR_Y := 0.18
const BAR_APPROACH := Vector3(0.0, FLOOR_Y, 1.62)
const TRAPDOOR_APPROACH := Vector3(18.0, FLOOR_Y, 4.6)
const INTAKE_APPROACH := Vector3(15.0, FLOOR_Y, 6.0)


func _commands_for(session):
	var commands = load(COMMAND_SYSTEM_PATH).new()
	commands.reset(session)
	commands.register_smart_object(&"bar_work_position", "Bar Work Position", BAR_APPROACH)
	commands.register_smart_object(&"trapdoor_control", "Trapdoor Control", TRAPDOOR_APPROACH)
	commands.register_smart_object(&"tunnel_intake", "Tunnel Intake", INTAKE_APPROACH)
	return commands


# A Night with the first Arrival Group seated and waiting on their Orders.
func _seated_night(seed: int = 707) -> Array:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(seed)
	session.advance(95.0)
	return [session, _commands_for(session)]


func _floor_target(x: float, z: float) -> Dictionary:
	return {"kind": &"floor", "id": &"floor", "position": Vector3(x, FLOOR_Y, z)}


func _patron_target(patron_id: StringName) -> Dictionary:
	return {"kind": &"patron", "id": patron_id, "position": Vector3.ZERO}


func _object_target(object_id: StringName) -> Dictionary:
	return {"kind": &"smart_object", "id": object_id, "position": Vector3.ZERO}


# Issues a command and walks it to its Commitment Point.
func _run(commands, cultist_id: StringName, command: StringName, target: Dictionary) -> Dictionary:
	var issued: Dictionary = commands.issue(cultist_id, command, target, false)
	if not bool(issued["accepted"]):
		return {"accepted": false, "committed": false, "reason": issued["reason"]}
	var reached: Dictionary = commands.notify_reached(cultist_id, int(issued["action_id"]))
	reached["accepted"] = true
	return reached


func _option(commands, cultist_id: StringName, target: Dictionary, command: StringName) -> Dictionary:
	for option: Dictionary in commands.resolve_options(cultist_id, target):
		if option["command"] == command:
			return option
	return {}


func _queue(commands, cultist_id: StringName) -> Dictionary:
	return commands.snapshot()["cultists"][cultist_id]


# --- Queue order, replace, and append ----------------------------------------

func test_normal_command_replaces_and_shift_command_appends() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var first: Dictionary = commands.issue(&"cultist_01", &"move", _floor_target(-6.0, 4.0), false)
	var queued: Dictionary = commands.issue(&"cultist_01", &"move", _floor_target(-3.0, 4.0), true)
	var replacement: Dictionary = commands.issue(
		&"cultist_01", &"move", _floor_target(2.0, 4.0), false
	)
	assert_true(bool(first["accepted"]) and bool(queued["accepted"]))

	var queue := _queue(commands, &"cultist_01")
	assert_eq(int(queue["active"]["id"]), int(replacement["action_id"]),
		"A normal command replaces the active Action before its Commitment Point.")
	assert_true(queue["pending"].is_empty(), "A normal command clears every pending Action.")


func test_mixed_move_and_context_commands_keep_order_and_the_four_action_limit() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	commands.issue(&"cultist_01", &"move", _floor_target(-6.0, 4.0), false)
	commands.issue(&"cultist_01", &"talk", _patron_target(&"patron_june"), true)
	commands.issue(&"cultist_01", &"move", _floor_target(-2.0, 4.0), true)
	commands.issue(&"cultist_01", &"offer_cigarette", _patron_target(&"patron_mara"), true)
	var overflow: Dictionary = commands.issue(
		&"cultist_01", &"move", _floor_target(4.0, 4.0), true
	)

	assert_false(bool(overflow["accepted"]), "One active and three pending Actions is the limit.")
	assert_eq(overflow["reason"], &"queue_full")
	var queue := _queue(commands, &"cultist_01")
	assert_eq(int(queue["action_count"]), 4)
	var order: Array = [queue["active"]["command"]]
	for entry: Dictionary in queue["pending"]:
		order.append(entry["command"])
	assert_eq(order, [&"move", &"talk", &"move", &"offer_cigarette"],
		"Move and context Actions keep the order the player queued them in.")


func test_pending_actions_can_be_removed_without_touching_the_active_action() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var active: Dictionary = commands.issue(&"cultist_01", &"move", _floor_target(-6.0, 4.0), false)
	var removable: Dictionary = commands.issue(
		&"cultist_01", &"talk", _patron_target(&"patron_june"), true
	)

	assert_true(commands.remove_pending(&"cultist_01", int(removable["action_id"])))
	var queue := _queue(commands, &"cultist_01")
	assert_eq(int(queue["active"]["id"]), int(active["action_id"]))
	assert_true(queue["pending"].is_empty())


# --- Commitment and cancellation ---------------------------------------------

func test_precommit_cancellation_releases_the_reservation_and_changes_nothing() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	commands.issue(&"cultist_01", &"talk", _patron_target(&"patron_june"), false)
	assert_eq(
		commands.snapshot()["reserved_slots"].get(&"cultist_01", &""),
		&"approach_patron_june",
		"An approach is reserved before movement starts."
	)

	commands.issue(&"cultist_01", &"move", _floor_target(-6.0, 4.0), false)
	assert_false(commands.snapshot()["reserved_slots"].has(&"cultist_01"),
		"Cancelling before commitment releases the approach reservation.")
	assert_true(session.snapshot()["conversations"].is_empty(),
		"An interrupted approach has no gameplay effect.")


func test_active_cancellation_before_commitment_releases_and_starts_the_next_action() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	commands.issue(&"cultist_01", &"talk", _patron_target(&"patron_june"), false)
	var queued: Dictionary = commands.issue(
		&"cultist_01", &"move", _floor_target(-6.0, 4.0), true
	)
	assert_eq(
		commands.snapshot()["reserved_slots"].get(&"cultist_01", &""),
		&"approach_patron_june",
		"The approach is reserved while the Talk is running."
	)

	var cancelled: Dictionary = commands.request_cancel_active(&"cultist_01")
	assert_true(bool(cancelled["cancelled"]), "A pre-commitment Action can be cancelled.")
	assert_false(commands.snapshot()["reserved_slots"].has(&"cultist_01"),
		"Cancelling releases the approach reservation.")
	assert_true(session.snapshot()["conversations"].is_empty(),
		"A cancelled approach leaves no gameplay effect.")

	var queue := _queue(commands, &"cultist_01")
	assert_eq(int(queue["active"]["id"]), int(queued["action_id"]),
		"The next pending Action becomes active at once.")
	assert_true(queue["pending"].is_empty())


func test_cancellation_cannot_undo_an_action_past_its_commitment_point() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		&"cultist_01", &"talk", _patron_target(&"patron_june"), false
	)
	commands.notify_reached(&"cultist_01", int(issued["action_id"]))
	assert_false(session.snapshot()["conversations"].is_empty(),
		"The Talk committed, so the conversation is running.")

	var refused: Dictionary = commands.request_cancel_active(&"cultist_01")
	assert_false(bool(refused["cancelled"]),
		"A committed Action has already left the queue, so nothing can cancel it.")
	assert_eq(refused["reason"], &"no_active_action")
	assert_false(String(refused["message"]).is_empty(),
		"A refusal always carries a visible reason.")
	assert_false(session.snapshot()["conversations"].is_empty(),
		"The committed gameplay effect survives the refused cancellation.")


func test_cancelling_the_last_action_leaves_an_idle_queue_and_no_reservation() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	commands.issue(&"cultist_01", &"talk", _patron_target(&"patron_june"), false)
	assert_true(bool(commands.request_cancel_active(&"cultist_01")["cancelled"]))

	var queue := _queue(commands, &"cultist_01")
	assert_true(queue["active"].is_empty(), "The Action Queue is idle again.")
	assert_eq(int(queue["action_count"]), 0)
	assert_false(commands.snapshot()["reserved_slots"].has(&"cultist_01"),
		"An idle Cultist holds no approach slot.")


func test_the_normal_snapshot_marks_each_action_cancellable_without_hidden_state() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		&"cultist_01", &"talk", _patron_target(&"patron_june"), false
	)
	commands.issue(&"cultist_01", &"move", _floor_target(-6.0, 4.0), true)
	var queue := _queue(commands, &"cultist_01")
	assert_eq(int(queue["active"]["id"]), int(issued["action_id"]))
	assert_true(bool(queue["active"]["cancellable"]),
		"An Action still approaching can be cancelled.")
	assert_true(bool(queue["pending"][0]["cancellable"]),
		"A pending Action can always be removed.")
	assert_eq(queue["active"]["stage"], &"approaching",
		"An Action before its Commitment Point is still approaching.")

	# The flag adds one display field and drags no internal payload with it.
	var expected: Array[String] = [
		"id", "command", "label", "target_kind", "target_id", "target_label", "stage",
		"cancellable",
	]
	var keys: Array = queue["active"].keys()
	keys.sort()
	expected.sort()
	assert_eq(keys, expected as Array, "An Action view carries display fields only.")


func test_the_effect_fires_once_at_commitment_and_a_later_command_cannot_reverse_it() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var committed := _run(commands, &"cultist_01", &"serve_order", _patron_target(&"patron_june"))
	assert_true(bool(committed["committed"]), "Serve Order commits on arrival.")
	var served_orders: int = int(session.snapshot()["orders"]["served_count"])
	assert_eq(served_orders, 1)

	commands.issue(&"cultist_01", &"move", _floor_target(-6.0, 4.0), false)
	assert_eq(int(session.snapshot()["orders"]["served_count"]), served_orders,
		"A command issued after the Commitment Point does not undo the effect.")
	assert_true(commands.snapshot()["cultists"][&"cultist_01"]["active"]["command"] == &"move")


func test_a_stale_target_fails_visibly_and_advances_the_queue() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		&"cultist_01", &"serve_order", _patron_target(&"patron_june"), false
	)
	assert_true(bool(issued["accepted"]))
	commands.issue(&"cultist_01", &"move", _floor_target(-6.0, 4.0), true)

	# Another Cultist serves the same Order, so the approach target goes stale.
	assert_true(session.serve_patron_order(&"patron_june", &"cultist_02"))
	commands.refresh(&"cultist_01")

	var queue := _queue(commands, &"cultist_01")
	assert_eq(queue["active"]["command"], &"move", "A stale Action fails and the queue advances.")
	assert_eq(queue["feedback"]["outcome"], &"failed")
	assert_false(String(queue["feedback"]["message"]).is_empty(),
		"A stale target fails with a visible reason.")
	assert_false(commands.snapshot()["reserved_slots"].has(&"cultist_01"),
		"A failed Action releases its reservation.")


func test_navigation_failure_releases_the_reservation_and_reports_a_reason() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var issued: Dictionary = commands.issue(
		&"cultist_01", &"talk", _patron_target(&"patron_june"), false
	)
	commands.notify_failed(&"cultist_01", int(issued["action_id"]), &"path_stuck")

	var queue := _queue(commands, &"cultist_01")
	assert_true(queue["active"].is_empty())
	assert_eq(queue["feedback"]["reason"], &"path_stuck")
	assert_false(commands.snapshot()["reserved_slots"].has(&"cultist_01"))


# --- Contention ---------------------------------------------------------------

func test_two_cultists_requesting_one_approach_produce_one_owner_and_one_rejection() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var owner: Dictionary = commands.issue(
		&"cultist_01", &"prepare_drink", _object_target(&"bar_work_position"), false
	)
	var rival: Dictionary = commands.issue(
		&"cultist_02", &"prepare_drink", _object_target(&"bar_work_position"), false
	)

	assert_true(bool(owner["accepted"]))
	assert_false(bool(rival["accepted"]), "The bar work position has one owner at a time.")
	assert_eq(rival["reason"], &"approach_reserved")
	assert_false(String(rival["message"]).is_empty(), "The rejection is visible to the player.")
	var reserved: Dictionary = commands.snapshot()["reserved_slots"]
	assert_eq(reserved.get(&"cultist_01", &""), &"bar_work_position")
	assert_false(reserved.has(&"cultist_02"), "A rejected command creates no hidden wait queue.")


# --- Catalog: Patron targets ---------------------------------------------------

func test_talk_commits_and_is_unavailable_for_a_missing_patron() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(commands, &"cultist_01", &"talk", _patron_target(&"patron_june"))["committed"]))
	assert_eq(session.snapshot()["conversations"].get(&"cultist_01", &""), &"patron_june")

	assert_true(_option(commands, &"cultist_01", _patron_target(&"patron_clara"), &"talk").is_empty(),
		"A Patron who has not arrived offers no Talk.")


func test_serve_order_commits_and_disappears_once_the_order_closes() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(commands, &"cultist_01", &"serve_order", _patron_target(&"patron_june"))["committed"]))
	assert_eq(int(session.snapshot()["orders"]["served_count"]), 1)
	assert_true(
		_option(commands, &"cultist_01", _patron_target(&"patron_june"), &"serve_order").is_empty(),
		"Serve Order leaves the menu once no Order is open."
	)


func test_offer_drink_needs_a_carried_prepared_drink() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(
		_option(commands, &"cultist_01", _patron_target(&"patron_june"), &"offer_drink").is_empty(),
		"Offer Drink stays hidden while the Cultist carries nothing."
	)

	assert_true(bool(_run(commands, &"cultist_01", &"prepare_drink", _object_target(&"bar_work_position"))["committed"]))
	assert_true(session.carries_prepared_drink(&"cultist_01"))
	# June still has an open Order, so she cannot receive an offer yet.
	var blocked := _option(commands, &"cultist_01", _patron_target(&"patron_june"), &"offer_drink")
	assert_false(blocked.is_empty())
	assert_false(bool(blocked["available"]))
	assert_eq(blocked["reason"], &"not_receptive")

	session.serve_patron_order(&"patron_june", &"cultist_02")
	session.advance(31.0)  # June finishes the drink and goes back to socializing.
	assert_true(bool(_run(commands, &"cultist_01", &"offer_drink", _patron_target(&"patron_june"))["committed"]))
	assert_false(session.carries_prepared_drink(&"cultist_01"),
		"The offer spends the carried Prepared Drink.")


func test_offer_cigarette_commits_and_needs_a_conscious_patron() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var before: float = session.friendship_value(&"patron_june", &"cultist_01")
	assert_true(bool(_run(commands, &"cultist_01", &"offer_cigarette", _patron_target(&"patron_june"))["committed"]))
	assert_gt(session.friendship_value(&"patron_june", &"cultist_01"), before)
	assert_true(
		_option(commands, &"cultist_01", _patron_target(&"patron_nell"), &"offer_cigarette").is_empty(),
		"A Patron who has not arrived offers no cigarette."
	)


func test_knock_out_commits_and_is_disabled_while_another_windup_runs() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(commands, &"cultist_01", &"knock_out", _patron_target(&"patron_june"))["committed"]))
	assert_eq(session.snapshot()["windup"]["victim_id"], &"patron_june")

	var blocked := _option(commands, &"cultist_02", _patron_target(&"patron_mara"), &"knock_out")
	assert_false(blocked.is_empty())
	assert_false(bool(blocked["available"]), "One wind-up at a time.")
	assert_eq(blocked["reason"], &"cultist_busy")


func test_pick_up_body_commits_only_for_an_unconscious_patron() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(
		_option(commands, &"cultist_01", _patron_target(&"patron_june"), &"pick_up_body").is_empty(),
		"A conscious Patron offers no Pick Up Body."
	)

	session.debug_set_patron_drink_state(&"patron_june", 3, 1, 0, 3)
	session.debug_force_finish_drink(&"patron_june")
	session.advance(0.2)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["lifecycle"], &"unconscious")

	assert_true(bool(_run(commands, &"cultist_01", &"pick_up_body", _patron_target(&"patron_june"))["committed"]))
	assert_true(session.snapshot()["drags"].has(&"patron_june"))


func test_drop_body_appears_only_while_a_body_is_carried() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(_option(commands, &"cultist_01", _floor_target(-6.0, 4.0), &"drop_body").is_empty(),
		"Drop Body Here stays out of the floor menu when nothing is carried.")

	session.debug_set_patron_drink_state(&"patron_june", 3, 1, 0, 3)
	session.debug_force_finish_drink(&"patron_june")
	session.advance(0.2)
	_run(commands, &"cultist_01", &"pick_up_body", _patron_target(&"patron_june"))

	assert_false(_option(commands, &"cultist_01", _floor_target(-6.0, 4.0), &"drop_body").is_empty())
	assert_true(bool(_run(commands, &"cultist_01", &"drop_body", _floor_target(-6.0, 4.0))["committed"]))
	assert_false(session.snapshot()["drags"].has(&"patron_june"))


func test_intercept_appears_only_for_an_escaping_patron() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	session.advance(185.0)
	var commands = _commands_for(session)

	assert_true(_option(commands, &"cultist_01", _patron_target(&"patron_elias"), &"intercept").is_empty(),
		"A calm Patron offers no Intercept.")

	session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen")
	session.advance(2.2)
	assert_true(bool(_run(commands, &"cultist_01", &"intercept", _patron_target(&"patron_elias"))["committed"]))
	assert_eq(session.snapshot()["active_intercept"]["patron_id"], &"patron_elias")


func test_lead_to_tunnel_appears_only_at_trusted_friendship() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	session.advance(185.0)
	var commands = _commands_for(session)

	assert_true(
		_option(commands, &"cultist_01", _patron_target(&"patron_elias"), &"lead_to_tunnel").is_empty(),
		"Friendship Capture stays hidden below Trusted."
	)
	for _cigarette in range(8):
		session.offer_cigarette(&"cultist_01", &"patron_elias")

	assert_true(bool(_run(commands, &"cultist_01", &"lead_to_tunnel", _patron_target(&"patron_elias"))["committed"]))
	assert_true(session.snapshot()["follows"].has(&"patron_elias"))


func test_rescue_persuasion_targets_the_current_helper_only() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	session.advance(95.0)
	session.prepare_drugged_drink(&"patron_mara", &"cultist_01")
	session.advance(8.1)
	session.serve_patron_order(&"patron_mara", &"cultist_02")
	session.advance(28.1)  # collapse, reaction, and the lift into the carry
	var commands = _commands_for(session)

	assert_true(
		_option(commands, &"cultist_01", _patron_target(&"patron_mara"), &"rescue_persuasion").is_empty(),
		"The collapsed Patron is not the Rescue Persuasion target."
	)
	assert_true(bool(_run(commands, &"cultist_01", &"rescue_persuasion", _patron_target(&"patron_june"))["committed"]))
	assert_eq(session.snapshot()["collapses"][&"patron_mara"]["phase"], &"persuading")


# --- Catalog: smart-object and floor targets ----------------------------------

func test_bar_commands_prepare_a_drink_and_a_dose_for_the_waiting_order() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	var options: Array[Dictionary] = commands.resolve_options(
		&"cultist_01", _object_target(&"bar_work_position")
	)
	var listed: Array = options.map(func(option: Dictionary) -> StringName: return option["command"])
	assert_eq(listed, [&"prepare_drink", &"prepare_drugged_drink", &"move"],
		"The bar work position offers its own commands and a plain approach.")

	assert_true(bool(_run(commands, &"cultist_02", &"prepare_drugged_drink", _object_target(&"bar_work_position"))["committed"]))
	assert_false(session.snapshot()["drug_prep"].is_empty())
	var busy := _option(commands, &"cultist_01", _object_target(&"bar_work_position"), &"prepare_drugged_drink")
	assert_false(bool(busy["available"]))
	assert_eq(busy["reason"], &"drug_prep_running")


func test_activate_trapdoor_commits_and_reports_its_cooldown() -> void:
	var pair := _seated_night()
	var session = pair[0]
	var commands = pair[1]

	assert_true(bool(_run(commands, &"cultist_01", &"activate_trapdoor", _object_target(&"trapdoor_control"))["committed"]))
	assert_eq(session.snapshot()["trapdoor"]["state"], &"open")

	var blocked := _option(commands, &"cultist_02", _object_target(&"trapdoor_control"), &"activate_trapdoor")
	assert_false(bool(blocked["available"]))
	assert_eq(blocked["reason"], &"trapdoor_busy")


func test_the_tunnel_intake_offers_no_capture_command_of_its_own() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var listed: Array = commands.resolve_options(
		&"cultist_01", _object_target(&"tunnel_intake")
	).map(func(option: Dictionary) -> StringName: return option["command"])
	assert_eq(listed, [&"move"],
		"The Tunnel Intake is a destination, never a Capture command by itself.")


func test_move_stays_the_plain_floor_command() -> void:
	var pair := _seated_night()
	var commands = pair[1]

	var listed: Array = commands.resolve_options(&"cultist_01", _floor_target(-6.0, 4.0)).map(
		func(option: Dictionary) -> StringName: return option["command"]
	)
	assert_eq(listed, [&"move"], "Empty floor offers Move alone.")
	var reached := _run(commands, &"cultist_01", &"move", _floor_target(-6.0, 4.0))
	assert_true(bool(reached["committed"]))
	assert_true(_queue(commands, &"cultist_01")["active"].is_empty())


# --- Information safety and lifecycle -----------------------------------------

func test_normal_snapshots_and_menu_labels_hide_simulation_values() -> void:
	var pair := _seated_night()
	var commands = pair[1]
	commands.issue(&"cultist_01", &"talk", _patron_target(&"patron_june"), false)

	var forbidden: Array[String] = [
		"suspicion", "bladder", "mood_value", "overdrink_limit", "excess_drinks",
		"ideal_intoxication_level", "roll", "remaining", "elapsed_seconds",
		"bathroom_probability", "drug_countdown",
	]
	var text := JSON.stringify(commands.snapshot())
	for key: String in forbidden:
		assert_false(text.contains(key), "The normal command snapshot must not carry %s." % key)

	for option: Dictionary in commands.resolve_options(&"cultist_01", _patron_target(&"patron_june")):
		assert_eq(option["target_label"], "???",
			"An Unidentified Patron keeps their name hidden in the menu.")


func test_ten_restarts_leave_no_command_or_reservation_state() -> void:
	var session = load(GAME_SESSION_PATH).new()
	var commands = null
	for _restart in range(10):
		session.start_night(4_242)
		commands = _commands_for(session)
		session.advance(95.0)
		commands.issue(&"cultist_01", &"talk", _patron_target(&"patron_june"), false)
		commands.issue(&"cultist_02", &"prepare_drink", _object_target(&"bar_work_position"), false)
		commands.reset(session)
		var state: Dictionary = commands.snapshot()
		assert_eq(int(state["action_count"]), 0, "A restart leaves no Action behind.")
		assert_true(state["reserved_slots"].is_empty(), "A restart leaves no reservation behind.")
		assert_true(state["recent_events"].is_empty())


func test_a_captured_patron_drops_the_command_queued_against_them() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	session.advance(185.0)
	var commands = _commands_for(session)
	for _cigarette in range(8):
		session.offer_cigarette(&"cultist_01", &"patron_elias")

	# Cultist 02 lines up a Talk behind a Move, so it holds no reservation yet.
	var move: Dictionary = commands.issue(
		&"cultist_02", &"move", _floor_target(-6.0, 4.0), false
	)
	assert_true(bool(commands.issue(&"cultist_02", &"talk", _patron_target(&"patron_elias"), true)["accepted"]))
	_run(commands, &"cultist_01", &"lead_to_tunnel", _patron_target(&"patron_elias"))

	session.advance(15.0)  # the follow reaches the Tunnel Intake and Captures
	assert_eq(int(session.snapshot()["captures"]), 1)
	commands.notify_reached(&"cultist_02", int(move["action_id"]))

	var queue := _queue(commands, &"cultist_02")
	assert_true(queue["active"].is_empty(), "A Captured Patron leaves no Action behind.")
	assert_eq(queue["feedback"]["reason"], &"patron_unavailable")
	assert_true(commands.snapshot()["reserved_slots"].is_empty(),
		"A Captured Patron leaves no approach reservation behind.")


func test_the_night_ending_closes_every_command() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	session.advance(95.0)
	var commands = _commands_for(session)
	commands.issue(&"cultist_01", &"talk", _patron_target(&"patron_june"), false)

	session.advance(1_080.0)
	assert_eq(session.snapshot()["phase"], &"results")
	commands.refresh()

	assert_true(_queue(commands, &"cultist_01")["active"].is_empty(),
		"Reaching Results clears the Action Queue.")
	assert_true(commands.snapshot()["reserved_slots"].is_empty(),
		"Reaching Results releases every approach reservation.")
	assert_true(commands.resolve_options(&"cultist_01", _patron_target(&"patron_june")).is_empty(),
		"No command applies after the Night ends.")
