extends GutTest

class MenuProbe:
	extends "res://scripts/prototypes/perception_greybox.gd"
	var appended := false
	func _close_context_menu() -> void:
		pass
	func _issue_command(_command: StringName, _target: Dictionary, append: bool) -> void:
		appended = append

func test_shift_at_command_click_appends_after_menu_opened_without_shift() -> void:
	var menu := MenuProbe.new()
	menu._context_target = {"kind": &"object", "id": &"bar_work_position"}
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.pressed = true
	key.shift_pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	menu._on_context_option_pressed(&"prepare_beer")
	assert_true(menu.appended)
	var release := InputEventKey.new()
	release.keycode = KEY_SHIFT
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	menu.free()

func test_menu_append_choice_survives_modifier_release() -> void:
	var menu := MenuProbe.new()
	menu._context_target = {"kind": &"object", "id": &"bar_work_position"}
	menu._context_append = true
	menu._on_context_option_pressed(&"prepare_beer")
	assert_true(menu.appended)
	menu.free()

func test_plain_command_click_replaces() -> void:
	var menu := MenuProbe.new()
	menu._context_target = {"kind": &"object", "id": &"bar_work_position"}
	menu._on_context_option_pressed(&"prepare_beer")
	assert_false(menu.appended)
	menu.free()
