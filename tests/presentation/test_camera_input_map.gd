extends GutTest


func test_camera_pan_actions_include_arrow_keys_and_physical_wasd_keys() -> void:
	assert_true(_action_has_keys(&"camera_pan_left", KEY_LEFT, KEY_A))
	assert_true(_action_has_keys(&"camera_pan_right", KEY_RIGHT, KEY_D))
	assert_true(_action_has_keys(&"camera_pan_up", KEY_UP, KEY_W))
	assert_true(_action_has_keys(&"camera_pan_down", KEY_DOWN, KEY_S))


func _action_has_keys(action: StringName, arrow_key: Key, letter_key: Key) -> bool:
	var has_arrow := false
	var has_letter := false
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		has_arrow = has_arrow or key_event.keycode == arrow_key
		has_letter = has_letter or key_event.physical_keycode == letter_key
	return has_arrow and has_letter
