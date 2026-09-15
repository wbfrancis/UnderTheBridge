extends GutTest

const VISIT_SCRIPT := preload("res://scripts/simulation/ordinary_visit_session.gd")
const DRINK_TYPES: Array[StringName] = [&"wine", &"beer", &"liquor"]


func _admitted_visit(seed: int = 707):
	var visit = VISIT_SCRIPT.new()
	visit.start(seed, true)
	visit.advance(3.0)
	assert_eq(visit.waiting_group_id(), &"arrival_group_pair_01")
	assert_true(visit.begin_admit_group(ActorIds.CULTIST_IDS[0], visit.waiting_group_id()))
	visit.advance(4.1)
	return visit


func test_first_group_waits_outside_at_three_seconds_and_can_be_missed() -> void:
	var visit = VISIT_SCRIPT.new()
	visit.start(707, true)
	visit.advance(2.9)
	assert_true(visit.waiting_group_id().is_empty())
	visit.advance(0.1)
	var state: Dictionary = visit.snapshot()
	assert_eq(visit.waiting_group_id(), &"arrival_group_pair_01")
	assert_eq(state["debug_views"][ScenarioActors.opening_patron()]["lifecycle"], &"waiting_at_entrance")
	visit.advance(30.0)
	state = visit.snapshot()
	assert_eq(int(state["groups_missed_at_door"]), 1)
	assert_eq(state["debug_views"][ScenarioActors.opening_patron()]["lifecycle"], &"exited")


func test_starting_admission_stops_the_wait_and_cancellation_resumes_it() -> void:
	var visit = VISIT_SCRIPT.new()
	visit.start(707, true)
	visit.advance(8.0)
	var remaining := float(visit.snapshot()["groups"][&"arrival_group_pair_01"]["wait_remaining"])
	assert_true(visit.begin_admit_group(ActorIds.CULTIST_IDS[0], &"arrival_group_pair_01"))
	visit.advance(2.0)
	assert_almost_eq(
		float(visit.snapshot()["groups"][&"arrival_group_pair_01"]["wait_remaining"]), remaining, 0.01
	)
	assert_true(visit.cancel_admit_group(ActorIds.CULTIST_IDS[0]))
	visit.advance(1.0)
	assert_almost_eq(
		float(visit.snapshot()["groups"][&"arrival_group_pair_01"]["wait_remaining"]), remaining - 1.0, 0.01
	)


func test_admission_opens_after_three_seconds_and_holds_until_the_group_enters() -> void:
	var visit = VISIT_SCRIPT.new()
	visit.start(707, true)
	visit.advance(3.0)
	visit.begin_admit_group(ActorIds.CULTIST_IDS[0], &"arrival_group_pair_01")
	visit.advance(2.9)
	assert_eq(visit.snapshot()["admission"]["phase"], &"opening")
	visit.advance(0.1)
	assert_eq(visit.snapshot()["admission"]["phase"], &"holding")
	assert_eq(visit.snapshot()["groups"][&"arrival_group_pair_01"]["arrived"], true)
	visit.advance(1.0)
	assert_true(visit.snapshot()["debug_views"][ScenarioActors.opening_patron()]["activity"] != &"entering")


func test_ask_to_leave_takes_ten_seconds_adds_five_suspicion_and_requests_group_departure() -> void:
	var visit = _admitted_visit()
	assert_true(visit.begin_ask_to_leave(ActorIds.CULTIST_IDS[0], ScenarioActors.opening_patron()))
	visit.advance(9.9)
	assert_eq(visit.snapshot()["ask_to_leave"]["state"], &"talking")
	visit.advance(0.1)
	var state: Dictionary = visit.snapshot()
	assert_eq(state["ask_to_leave"]["state"], &"completed")
	assert_almost_eq(float(state["debug_views"][ScenarioActors.opening_patron()]["suspicion"]), 5.0, 0.01)
	assert_almost_eq(float(state["debug_views"][ScenarioActors.opening_companion()]["suspicion"]), 5.0, 0.01)
	assert_true(bool(state["groups"][&"arrival_group_pair_01"]["asked_to_leave"]))


func test_ask_to_leave_is_disabled_for_a_suspicious_or_unconscious_group() -> void:
	var suspicious = _admitted_visit()
	for _event in range(3):
		suspicious.apply_suspicion_stimulus(ScenarioActors.opening_companion(), &"knockout_heard")
	var blocked: Dictionary = suspicious.ask_to_leave_availability(ScenarioActors.opening_patron())
	assert_true(bool(blocked["visible"]))
	assert_false(bool(blocked["available"]))
	assert_eq(blocked["reason"], &"too_suspicious_to_leave")

	var unconscious = _admitted_visit()
	unconscious.debug_set_patron_drink_state(ScenarioActors.opening_companion(), 3, 1, 0, 3)
	unconscious.debug_force_finish_drink(ScenarioActors.opening_companion())
	var body_block: Dictionary = unconscious.ask_to_leave_availability(ScenarioActors.opening_patron())
	assert_false(bool(body_block["available"]))
	assert_eq(body_block["reason"], &"unconscious_group_member")


func test_orders_name_one_of_the_three_drink_types() -> void:
	var visit = _admitted_visit()
	for patron_id: int in [ScenarioActors.opening_patron(), ScenarioActors.opening_companion()]:
		assert_true(visit.normal_patron_view(patron_id)["ordered_drink"] in DRINK_TYPES)


func test_correct_prepared_drink_completes_the_order_and_starts_drinking() -> void:
	var visit = _admitted_visit()
	var requested: StringName = visit.normal_patron_view(ScenarioActors.opening_patron())["ordered_drink"]
	assert_true(visit.make_drink(requested, ActorIds.CULTIST_IDS[0]))
	var drink_id: StringName = visit.snapshot()["prepared_drinks"]["drinks"][0]["id"]
	assert_true(visit.reserve_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0]))
	assert_true(visit.pick_up_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0]))
	var result: Dictionary = visit.serve_prepared_drink(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0], drink_id)
	assert_true(bool(result["served"]))
	assert_true(bool(result["correct"]))
	assert_eq(result["expression"], &"smile")
	assert_eq(visit.snapshot()["debug_views"][ScenarioActors.opening_patron()]["activity"], &"drinking")


func test_wrong_prepared_drink_always_costs_ten_mood_and_uses_a_frown() -> void:
	var visit = _admitted_visit()
	var requested: StringName = visit.normal_patron_view(ScenarioActors.opening_patron())["ordered_drink"]
	var wrong: StringName = DRINK_TYPES[(DRINK_TYPES.find(requested) + 1) % DRINK_TYPES.size()]
	var mood_before := float(visit.debug_patron_view(ScenarioActors.opening_patron())["satisfaction_value"])
	visit.make_drink(wrong, ActorIds.CULTIST_IDS[0])
	var drink_id: StringName = visit.snapshot()["prepared_drinks"]["drinks"][0]["id"]
	visit.reserve_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0])
	visit.pick_up_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0])
	var result: Dictionary = visit.serve_prepared_drink(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0], drink_id)
	assert_false(bool(result["correct"]))
	assert_eq(result["expression"], &"frown")
	assert_almost_eq(float(visit.debug_patron_view(ScenarioActors.opening_patron())["satisfaction_value"]), mood_before - 10.0, 0.01)
	if bool(result["accepted"]):
		assert_eq(int(visit.snapshot()["orders"]["revenue"]), 5)
	else:
		assert_eq(visit.normal_patron_view(ScenarioActors.opening_patron())["order_state"], &"open")


func test_an_accepted_wrong_drink_halves_the_mood_based_tip() -> void:
	for seed in range(1, 100):
		var visit = _admitted_visit(seed)
		var requested: StringName = visit.normal_patron_view(ScenarioActors.opening_patron())["ordered_drink"]
		var wrong: StringName = DRINK_TYPES[(DRINK_TYPES.find(requested) + 1) % DRINK_TYPES.size()]
		visit.make_drink(wrong, ActorIds.CULTIST_IDS[0])
		var drink_id: StringName = visit.snapshot()["prepared_drinks"]["drinks"][0]["id"]
		visit.reserve_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0])
		visit.pick_up_prepared_drink(drink_id, ActorIds.CULTIST_IDS[0])
		var result: Dictionary = visit.serve_prepared_drink(
			ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0], drink_id
		)
		if bool(result["accepted"]):
			assert_eq(int(visit.snapshot()["orders"]["tips"]), 1)
			return
	fail_test("The seeded sample did not include an accepted wrong drink.")
