extends GutTest
const SEARCH = preload("res://scripts/patrons/goap_planner.gd")
const GOALS = preload("res://scripts/patrons/patron_goal_planner.gd")

func test_search_composes_cheapest_plan_without_mutating_world() -> void:
	var facts := {"key": false, "outside": false}
	var actions := [
		{"name": &"break_door", "preconditions": {}, "effects": {"outside": true}, "cost": 10},
		{"name": &"get_key", "preconditions": {}, "effects": {"key": true}, "cost": 1},
		{"name": &"unlock_door", "preconditions": {"key": true}, "effects": {"outside": true}, "cost": 2}]
	var result := SEARCH.plan(facts, {"outside": true}, actions)
	assert_eq(result["steps"].map(func(a): return a["name"]), [&"get_key", &"unlock_door"])
	assert_eq(result["cost"], 3.0)
	assert_false(facts["outside"])
	assert_false(facts["key"])

func test_search_reports_no_plan_and_budget_exhaustion() -> void:
	assert_eq(SEARCH.plan({}, {"outside": true}, [])["status"], &"no_plan")
	assert_eq(SEARCH.plan({}, {"outside": true}, [], 0)["status"], &"search_limit")

func test_equal_cost_plans_are_stable_under_input_reordering() -> void:
	var actions := [
		{"name": &"b", "preconditions": {}, "effects": {"done": true}},
		{"name": &"a", "preconditions": {}, "effects": {"done": true}}]
	var first := SEARCH.plan({}, {"done": true}, actions)
	actions.reverse()
	assert_eq(first, SEARCH.plan({}, {"done": true}, actions))
	assert_eq(first["steps"][0]["name"], &"a")

func test_danger_replaces_investigation_without_applying_search_effects() -> void:
	var goals := GOALS.new()
	goals.observe(true, false)
	assert_eq(goals.next_action(0, "free")["name"], &"approach_bathroom")
	goals.started(10)
	assert_false(goals.complete(9))
	assert_true(goals.complete(10))
	assert_eq(goals.next_action(1, "free")["name"], &"search_bathroom")
	goals.started(11)
	goals.observe(true, true)
	assert_eq(goals.next_action(2, "free")["name"], &"recover_shock")
	assert_false(goals.complete(11))
	assert_false(goals.snapshot()["facts"]["searched"])

func test_running_plan_is_stable_and_failures_have_bounded_retries() -> void:
	var goals := GOALS.new()
	goals.observe(false, true)
	goals.next_action(0, "open")
	goals.started(10)
	for tick in range(100):
		goals.observe(false, true)
		goals.next_action(tick * 0.1, "open")
	assert_eq(goals.snapshot()["planning_count"], 1)
	for failure in range(3):
		goals.fail(-1, &"blocked_exit", failure * 3.0)
		assert_true(goals.next_action(failure * 3.0 + 1, "open").is_empty())
		if failure < 2:
			assert_false(goals.next_action(failure * 3.0 + 2, "open").is_empty())
	assert_true(goals.next_action(1000, "open").is_empty())
	assert_false(goals.next_action(1001, "route_changed").is_empty())
