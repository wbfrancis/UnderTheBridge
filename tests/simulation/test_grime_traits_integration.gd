extends GutTest

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const COMMAND_SYSTEM_SCRIPT := preload("res://scripts/actions/cultist_command_system.gd")


func test_seeded_traits_identification_grime_clean_reveals_reason_and_restart_flow() -> void:
	var session = GAME_SESSION_SCRIPT.new()
	session.start_night(707)
	var seeded_traits: Array = session.snapshot()["debug_patron_views"][ScenarioActors.opening_patron()]["traits"]
	assert_true(_valid_loadout(seeded_traits), "The seeded Night starts with a valid rolled loadout.")
	_admit_waiting_group(session)
	var commands = COMMAND_SYSTEM_SCRIPT.new()
	commands.reset(session)

	var knockout_subject := ScenarioActors.opening_patron()
	var non_smoker := ScenarioActors.opening_companion()
	assert_true(session.debug_set_patron_traits(knockout_subject, [&"wine_drinker", &"weak"]))
	assert_true(session.debug_set_patron_traits(non_smoker, [&"beer_drinker", &"non_smoker"]))
	assert_true(session.debug_set_patron_drink_state(knockout_subject, 0, 5, 0, 0))
	assert_true(session.debug_set_patron_drink_state(non_smoker, 0, 5, 0, 0))

	var hidden: Dictionary = _option(commands, knockout_subject, &"knock_out")
	assert_eq(hidden["chance"]["total"], 55)
	assert_eq(hidden["chance"]["public_total"], "???")
	assert_true(session.begin_conversation(ActorIds.CULTIST_IDS[0], knockout_subject))
	assert_true(session.end_conversation(ActorIds.CULTIST_IDS[0]))
	commands.refresh()
	assert_eq(_option(commands, knockout_subject, &"knock_out")["chance"]["public_total"], "55%")
	assert_eq(session.patron_view(non_smoker, ActorIds.CULTIST_IDS[0])["traits"], [],
		"Identifying the KO subject does not reveal a different Patron's Trait.")

	var subject_debug: Dictionary = session.snapshot()["debug_patron_views"][knockout_subject]
	var center: Vector2 = subject_debug["position"]
	var patch_id: StringName = session.debug_add_grime({
		"slot_id": &"integration_floor", "room": subject_debug["room"], "center": center,
		"surface_id": &"main_floor", "surface_type": &"floor",
		"surface_bounds": Rect2(center - Vector2.ONE, Vector2.ONE * 2.0),
		"approach_position": center + Vector2(0.0, 1.0),
	}, 15.0)
	var before_pressure := float(session.snapshot()["debug_patron_views"][knockout_subject]["satisfaction_value"])
	session.advance(2.0)
	var after_pressure := float(session.snapshot()["debug_patron_views"][knockout_subject]["satisfaction_value"])
	assert_almost_eq(
		after_pressure, before_pressure - 4.1, 0.01,
		"Grime applies four points while ordinary mood decay continues independently."
	)
	var clean: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"clean", session.grime_target(patch_id), false,
		{"is_adjacent": true}
	)
	assert_true(clean["accepted"])
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], clean["action_id"])["started"])
	commands.advance(15.0)
	assert_true(session.grime_target(patch_id).is_empty())
	session.advance(2.0)
	assert_almost_eq(
		float(session.snapshot()["debug_patron_views"][knockout_subject]["satisfaction_value"])
		- after_pressure,
		3.9, 0.01, "Cleaning repays the four-point source loss while ordinary decay continues."
	)

	var cigarette: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[1], &"offer_cigarette", _patron_target(non_smoker), false,
		{"is_adjacent": true}
	)
	assert_true(cigarette["accepted"])
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[1], cigarette["action_id"])["committed"])
	assert_eq(session.patron_view(non_smoker, ActorIds.CULTIST_IDS[0])["traits"], ["Non-Smoker"])
	assert_eq(session.patron_view(knockout_subject, ActorIds.CULTIST_IDS[0])["traits"], ["Wine Drinker", "Weak"])

	# The second arrival supplies a third Patron, so the two early-reveal cases
	# stay independent of the Patron identified above.
	if float(session.snapshot()["simulated_seconds"]) < 93.0:
		session.advance(93.0 - float(session.snapshot()["simulated_seconds"]))
	_admit_waiting_group(session)
	var oblivious := ScenarioActors.friendship_candidate()
	assert_true(session.debug_set_patron_traits(oblivious, [&"whiskey_drinker", &"oblivious"]))
	assert_true(session.report_patron_stimulus(oblivious, &"drink_dosed_seen"))
	assert_eq(session.patron_view(oblivious, ActorIds.CULTIST_IDS[0])["traits"], ["Oblivious"])
	session.advance(0.2)
	var intercept: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[0], &"intercept", _patron_target(oblivious), false,
		{"is_adjacent": true}
	)
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[0], intercept["action_id"])["committed"])
	var reason: Dictionary = commands.issue(
		ActorIds.CULTIST_IDS[1], &"reason_with", _patron_target(oblivious), false,
		{"is_adjacent": true}
	)
	assert_eq(reason["accepted"], true)
	assert_true(commands.notify_reached(ActorIds.CULTIST_IDS[1], reason["action_id"])["started"])
	session.advance(5.1)
	commands.refresh()
	assert_eq(session.snapshot()["debug_patron_views"][oblivious]["suspicion"], 50.0)
	assert_true(session.snapshot()["active_intercept"].is_empty())

	session.restart_night(707)
	commands.reset(session)
	assert_eq(
		session.snapshot()["debug_patron_views"][ScenarioActors.opening_patron()]["traits"],
		seeded_traits
	)
	assert_true(session.grime_patches_view().is_empty())
	assert_true(session.patron_view(
		ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0]
	)["traits"].is_empty())
	assert_false(session.snapshot()["debug_patron_views"][ScenarioActors.opening_patron()]["reason_with_attempted"])
	for cultist_id: int in ActorIds.CULTIST_IDS:
		assert_true(commands.snapshot()["cultists"][cultist_id]["active"].is_empty())


func test_grime_threshold_rate_and_slob_immunity_apply_while_traits_are_hidden() -> void:
	var cases := [
		{"traits": [&"wine_drinker"], "amount": 6.0, "loss": 0.05},
		{"traits": [&"wine_drinker"], "amount": 15.0, "loss": 2.05},
		{"traits": [&"wine_drinker", &"germaphobe"], "amount": 6.0, "loss": 4.05},
		{"traits": [&"wine_drinker", &"slob"], "amount": 30.0, "loss": 0.05},
	]
	for index in cases.size():
		var session = GAME_SESSION_SCRIPT.new()
		session.start_night(810 + index)
		_admit_waiting_group(session)
		var patron_id := ScenarioActors.opening_patron()
		var item: Dictionary = cases[index]
		assert_true(session.debug_set_patron_traits(patron_id, item["traits"]))
		var debug: Dictionary = session.snapshot()["debug_patron_views"][patron_id]
		var center: Vector2 = debug["position"]
		session.debug_add_grime({
			"slot_id": StringName("threshold_%d" % index), "room": debug["room"],
			"center": center, "surface_id": &"main_floor", "surface_type": &"floor",
			"surface_bounds": Rect2(center - Vector2.ONE, Vector2.ONE * 2.0),
			"approach_position": center + Vector2(0.0, 1.0),
		}, item["amount"])
		var before := float(session.snapshot()["debug_patron_views"][patron_id]["satisfaction_value"])
		session.advance(1.0)
		var after := float(session.snapshot()["debug_patron_views"][patron_id]["satisfaction_value"])
		assert_almost_eq(before - after, item["loss"], 0.01, "case %d" % index)
		assert_true(session.patron_view(patron_id, ActorIds.CULTIST_IDS[0])["traits"].is_empty())


func _admit_waiting_group(session) -> void:
	if float(session.snapshot()["simulated_seconds"]) < 3.0:
		session.advance(3.0 - float(session.snapshot()["simulated_seconds"]))
	assert_true(session.begin_admit_group(ActorIds.CULTIST_IDS[2]))
	session.advance(4.1)
	session.command_action_state(&"admit_group", ActorIds.CULTIST_IDS[2], &"front_entrance")


func _patron_target(patron_id: int) -> Dictionary:
	return {"kind": &"patron", "id": patron_id, "position": Vector3.ZERO}


func _option(commands, patron_id: int, command: StringName) -> Dictionary:
	for option: Dictionary in commands.resolve_options(ActorIds.CULTIST_IDS[0], _patron_target(patron_id)):
		if option["command"] == command:
			return option
	return {}


func _valid_loadout(traits: Array) -> bool:
	if traits.size() < 1 or traits.size() > 3:
		return false
	var preference_count := 0
	for trait_id: StringName in traits:
		if trait_id in PatronTraitCatalog.DRINK_PREFERENCES:
			preference_count += 1
		for other_id: StringName in traits:
			if other_id in PatronTraitCatalog.DEFINITIONS[trait_id]["incompatible_with"]:
				return false
	return preference_count == 1
