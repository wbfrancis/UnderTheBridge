extends GutTest


func test_grime_sight_uses_inclusive_center_range_cone_and_room_boundaries() -> void:
	var perception := PatronPerception.new()
	var perceivers := [{
		"id": 1, "room": &"main_hall", "position": Vector2.ZERO, "facing": Vector2.RIGHT,
	}]
	var cone_edge := Vector2.RIGHT.rotated(deg_to_rad(60.0)) * 5.0
	assert_eq(perception.grime_recipients(&"main_hall", cone_edge, perceivers), [1])
	assert_eq(perception.grime_recipients(
		&"main_hall", Vector2.RIGHT.rotated(deg_to_rad(60.2)) * 5.0, perceivers
	), [])
	assert_eq(perception.grime_recipients(&"main_hall", Vector2(5.01, 0.0), perceivers), [])
	assert_eq(perception.grime_recipients(&"hallway", Vector2.ZERO, perceivers), [])
	assert_eq(perception.grime_recipients(&"main_hall", Vector2.ZERO, perceivers), [1])
