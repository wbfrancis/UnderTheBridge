extends GutTest

const SYSTEM := preload("res://scripts/navigation/character_avoidance_system.gd")


func _actors() -> Array[Dictionary]:
	return [
		{"id": &"mover", "action_id": 1, "position": Vector3.ZERO,
		"segment_end": Vector3(3, 0, 0), "moving": true, "can_yield": false,
		"priority": SYSTEM.PRIORITY_PLAYER},
		{"id": &"blocker", "action_id": -1, "position": Vector3(1, 0, 0),
		"moving": false, "can_yield": true, "priority": SYSTEM.PRIORITY_IDLE},
	]


func test_yield_requires_one_second_and_does_not_repeat_for_same_action() -> void:
	var system = SYSTEM.new()
	var actors := _actors()
	assert_true(system.advance(0.9, actors).is_empty())
	var requests: Array = system.advance(0.1, actors)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0]["actor_id"], &"blocker")
	assert_almost_eq(requests[0]["position"].distance_to(actors[1]["position"]), 1.4, 0.001)
	assert_true(system.advance(5.0, actors).is_empty())
	actors[0]["action_id"] = 2
	assert_eq(system.advance(1.0, actors).size(), 1)


func test_clear_path_resets_timer_and_busy_characters_never_yield() -> void:
	var system = SYSTEM.new()
	var actors := _actors()
	system.advance(0.9, actors)
	actors[1]["position"] = Vector3(1, 0, 3)
	assert_true(system.advance(1.0, actors).is_empty())
	actors[1]["position"] = Vector3(1, 0, 0)
	assert_true(system.advance(0.2, actors).is_empty())
	actors[1]["can_yield"] = false
	assert_true(system.advance(2.0, actors).is_empty())


func test_escape_claims_blocker_before_player_movement() -> void:
	var system = SYSTEM.new()
	var actors := _actors()
	var urgent: Dictionary = actors[0].duplicate()
	urgent["id"] = &"escape"
	urgent["priority"] = SYSTEM.PRIORITY_DANGER
	actors.append(urgent)
	var requests: Array = system.advance(1.0, actors)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0]["incident_id"], &"escape:1:blocker")
