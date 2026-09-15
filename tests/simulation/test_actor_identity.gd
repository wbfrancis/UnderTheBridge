extends GutTest

func test_roster_ids_are_positive_unique_and_all_relationships_resolve() -> void:
	var ids := {}
	var seeds := {}
	for cultist_id in ActorIds.CULTIST_IDS:
		assert_gt(cultist_id, ActorIds.NO_ACTOR)
		assert_false(ids.has(cultist_id))
		ids[cultist_id] = &"cultist"
	for definition in ActorRoster.FULL_NIGHT_PATRON_DEFINITIONS:
		var patron_id: int = definition["id"]
		assert_gt(patron_id, ActorIds.NO_ACTOR)
		assert_false(ids.has(patron_id))
		assert_false(seeds.has(definition["seed_key"]))
		assert_false(StringName(definition["seed_key"]).is_empty())
		ids[patron_id] = &"patron"
		seeds[definition["seed_key"]] = true
	for group in ActorRoster.FULL_NIGHT_GROUP_DEFINITIONS:
		for patron_id in group["patrons"]:
			assert_eq(ids.get(patron_id), &"patron")
	for definition in ActorRoster.FULL_NIGHT_PATRON_DEFINITIONS:
		var matching_groups := ActorRoster.FULL_NIGHT_GROUP_DEFINITIONS.filter(
			func(group): return group["id"] == definition["group_id"]
		)
		assert_eq(matching_groups.size(), 1)
		assert_has(matching_groups[0]["patrons"], definition["id"])
		for companion_id in definition["companions"]:
			assert_eq(ids.get(companion_id), &"patron")
			assert_ne(companion_id, definition["id"])
			assert_has(matching_groups[0]["patrons"], companion_id)

func test_renumbering_a_patron_preserves_rng_stream_and_seeded_initial_state() -> void:
	var session := OrdinaryVisitSession.new()
	for seed_value in [707, 19, 4301]:
		session.start(seed_value)
		for definition in ActorRoster.FULL_NIGHT_PATRON_DEFINITIONS:
			var first := _renumbered_patron(session, definition, 2001)
			var second := _renumbered_patron(session, definition, 9017)
			first.erase("id")
			second.erase("id")
			assert_eq(first, second)
			for draw in range(20):
				assert_eq(session._patron_rngs[2001].randi(), session._patron_rngs[9017].randi())

func _renumbered_patron(session, definition: Dictionary, actor_id: int) -> Dictionary:
	return session._new_patron(actor_id, definition["name"], definition["group_id"],
		definition["companions"], definition["bladder_gain"], definition["service_delay"],
		&"not_arrived", definition["victim_value"], definition["victim_risk"],
		definition.get("friendship_capturable", false), definition["seed_key"])

func test_no_actor_cannot_own_a_slot_queue_order_or_drink() -> void:
	var registry := InteractionRegistry.new()
	registry.register_slot(&"test_slot", &"seat")
	assert_false(registry.request_slot(ActorIds.NO_ACTOR, &"test_slot"))
	assert_eq(registry.slot_owner(&"test_slot"), ActorIds.NO_ACTOR)
	var actions := CharacterActionSystem.new()
	assert_false(actions.register_actor(ActorIds.NO_ACTOR, &"patron"))
	var orders := OrderSystem.new()
	assert_eq(orders.create_order(ActorIds.NO_ACTOR, 0.0), &"")
	var drinks := PreparedDrinkSystem.new()
	var drink: Dictionary = drinks.add_drink(&"wine")
	assert_false(drinks.reserve(drink["drink_id"], ActorIds.NO_ACTOR))

func test_emote_order_is_numeric_across_actor_kinds() -> void:
	const LOW_ACTOR_ID := 2
	const HIGH_ACTOR_ID := 10
	var director := EmoteDirector.new()
	var row := {"present": true, "state": &"ordering"}
	director.update({HIGH_ACTOR_ID: row, LOW_ACTOR_ID: row}, 0.0, false)
	var ids: Array = director.bubbles().map(func(bubble): return bubble["actor_id"])
	assert_eq(ids, [LOW_ACTOR_ID, HIGH_ACTOR_ID])

func test_danger_source_can_be_an_actor_or_an_authored_location() -> void:
	var session := OrdinaryVisitSession.new()
	session.start(707)
	session.advance(1.1)
	assert_gt(session.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", &"bar_work_position").size(), 0)
	assert_gt(session.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", ScenarioActors.opening_companion()).size(), 0)

func test_pre_feature_trace_keeps_unaffected_seeded_fields_stable() -> void:
	# Traits, typed drink choice, 1-3 overdrink limits, progress-based Intoxication,
	# Grime pressure, and their downstream activity are intentional replacements.
	# Keep the fixture unchanged and compare each field outside that changed rule set.
	const UNAFFECTED_PATRON_FIELDS: Array[String] = [
		"bathroom_probability", "bladder", "dosed_pending", "drug_countdown",
		"escape_after_bathroom", "escape_remaining", "excess_drinks",
		"next_bathroom_check_in", "recent_bathroom_rolls", "stay_rolled", "stayed_behind",
	]
	var expected: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/actor_seed_trace.json"))
	assert_eq(expected.size(), 15)
	var frame := 0
	for seed_value in [707, 19, 4301]:
		var session := OrdinaryVisitSession.new()
		session.start(seed_value)
		for patron_id: int in session.snapshot()["debug_views"]:
			assert_true(session.debug_set_patron_traits(patron_id, [&"wine_drinker"]))
		session.advance(1.1)
		var patrons := [ScenarioActors.opening_patron(), ScenarioActors.opening_companion()]
		for patron_id in patrons:
			assert_true(session.serve_patron_order(patron_id))
		for seconds in [10.0, 35.0, 90.0, 180.0, 300.0]:
			session.advance(seconds)
			var state := session.snapshot()
			var reference: Dictionary = expected[frame]
			assert_almost_eq(float(state["simulated_seconds"]), float(reference["at"]), 0.000001)
			for index in patrons.size():
				var view: Dictionary = state["debug_views"][patrons[index]]
				for key: String in UNAFFECTED_PATRON_FIELDS:
					_assert_trace_value(view[key], reference["patrons"][index][key], "%d/%d/%s" % [frame, index, key])
			_assert_trace_value(state["orders"]["revenue"], reference["orders"]["revenue"], "revenue")
			_assert_trace_value(state["captures"].size(), reference["captures"], "captures")
			frame += 1

func _assert_trace_value(actual: Variant, expected: Variant, label: String) -> void:
	if expected is float:
		assert_almost_eq(float(actual), expected, 0.000001, label)
	elif expected is Array:
		assert_eq(actual.size(), expected.size(), label)
		if actual.size() != expected.size(): return
		for index in expected.size():
			_assert_trace_value(actual[index], expected[index], label)
	elif expected is Dictionary:
		assert_eq(actual.size(), expected.size(), label)
		for key in expected:
			assert_true(actual.has(key), label)
			if actual.has(key): _assert_trace_value(actual[key], expected[key], label)
	else:
		assert_eq(actual, expected, label)
