class_name ScenarioActors
extends RefCounted

## Explicit authored fixtures for deterministic tests and review scenes.
## Select by relationship and service timing, never by display name or numeric ID.
## The opening pair has deliberately different seeded bathroom/Order behavior.
## Tests that assert those rolls use these fixtures rather than an arbitrary Patron.
static func opening_patron() -> int:
	return group_member(&"arrival_group_pair_01", 0, 2)

static func opening_companion() -> int:
	return group_member(&"arrival_group_pair_01", 1, 2)

static func friendship_candidate() -> int:
	var matches := ActorRoster.FULL_NIGHT_PATRON_DEFINITIONS.filter(
		func(definition): return definition.get("friendship_capturable", false)
	)
	assert(matches.size() == 1, "The friendship fixture needs exactly one eligible Patron.")
	return matches[0]["id"]

static func group_member(group_id: StringName, service_rank: int, expected_size: int) -> int:
	return ranked_group_member(ActorRoster.FULL_NIGHT_PATRON_DEFINITIONS, group_id, service_rank, expected_size)

static func ranked_group_member(definitions: Array, group_id: StringName, service_rank: int, expected_size: int) -> int:
	var members := definitions.filter(
		func(definition): return definition["group_id"] == group_id
	)
	assert(members.size() == expected_size, "The fixture's Arrival Group changed.")
	members.sort_custom(func(left, right): return left["service_delay"] < right["service_delay"])
	for index in range(1, members.size()):
		assert(members[index - 1]["service_delay"] != members[index]["service_delay"],
			"Service rank must select one unambiguous fixture.")
	assert(service_rank >= 0 and service_rank < members.size())
	return members[service_rank]["id"]

static func companion_of(session, patron_id: int) -> int:
	var state: Dictionary = session.snapshot()
	var groups: Dictionary = state.get("arrival_groups", state.get("groups", {}))
	for group: Dictionary in groups.values():
		var members: Array = group["patrons"]
		if patron_id in members:
			assert(members.size() == 2, "This fixture needs a single Companion.")
			return members[1] if members[0] == patron_id else members[0]
	assert(false, "The fixture Patron must belong to a session Arrival Group.")
	return ActorIds.NO_ACTOR

static func unique_patron_in_state(session, activity: StringName) -> int:
	var state: Dictionary = session.snapshot()
	var views: Dictionary = state.get("debug_patron_views", state.get("debug_views", {}))
	var matches: Array[int] = []
	for patron_id: int in views:
		if views[patron_id]["activity"] == activity:
			matches.append(patron_id)
	assert(matches.size() == 1, "The fixture needs exactly one Patron in the requested state.")
	return matches[0]
