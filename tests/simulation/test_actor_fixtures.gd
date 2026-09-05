extends GutTest

func test_fixture_selection_ignores_roster_order_names_and_ids() -> void:
	var definitions := ActorRoster.FULL_NIGHT_PATRON_DEFINITIONS.duplicate(true)
	var expected := ActorIds.NO_ACTOR
	for definition in definitions:
		definition["id"] += 700
		definition["name"] = "Renamed"
		if definition["id"] == ScenarioActors.opening_patron() + 700:
			expected = definition["id"]
	definitions.reverse()
	assert_eq(ScenarioActors.ranked_group_member(definitions, &"arrival_group_pair_01", 0, 2), expected)

func test_opening_pair_are_companions_and_friendship_fixture_is_eligible() -> void:
	var session := OrdinaryVisitSession.new()
	session.start(707, true)
	assert_eq(ScenarioActors.companion_of(session, ScenarioActors.opening_patron()), ScenarioActors.opening_companion())
	assert_true(session.debug_patron_view(ScenarioActors.friendship_candidate())["friendship_capturable"])

func test_state_selector_returns_the_patron_in_the_requested_activity() -> void:
	var session := OrdinaryVisitSession.new()
	session.start(707)
	session.advance(1.1)
	assert_true(session.debug_force_bathroom(ScenarioActors.opening_patron()))
	assert_eq(ScenarioActors.unique_patron_in_state(session, &"entering_bathroom"), ScenarioActors.opening_patron())
