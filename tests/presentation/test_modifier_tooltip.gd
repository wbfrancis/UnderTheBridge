extends GutTest

const TOOLTIP_SCRIPT := preload("res://scripts/presentation/modifier_tooltip.gd")


func test_known_breakdown_renders_base_modifiers_and_brass_total() -> void:
	var tooltip = TOOLTIP_SCRIPT.new()
	add_child_autoqfree(tooltip)
	tooltip.set_breakdown({
		"base": 60,
		"base_label": "Base",
		"modifiers": [
			{"label": "Oblivious", "points": 20, "known": true},
			{"label": "Nosy", "points": -20, "known": true},
		],
		"public_total": "60%",
		"unknown": false,
	})

	assert_eq(tooltip.display_rows(), [
		{"label": "Base", "value": "60%", "tone": &"base"},
		{"label": "Oblivious", "value": "+20%", "tone": &"increase"},
		{"label": "Nosy", "value": "−20%", "tone": &"decrease"},
		{"label": "Total", "value": "60%", "tone": &"total"},
	])
	assert_eq(tooltip.tooltip_text, "Base 60%. Oblivious +20%. Nosy minus 20%. Total 60%.")


func test_unknown_modifier_hides_direction_value_total_and_accessibility_text() -> void:
	var tooltip = TOOLTIP_SCRIPT.new()
	add_child_autoqfree(tooltip)
	tooltip.set_breakdown({
		"base": 40,
		"base_label": "Sober",
		"modifiers": [
			{"label": "Weak", "points": 15, "known": true},
			{"label": "???", "points": 0, "known": false},
		],
		"public_total": "???",
		"unknown": true,
	})

	assert_eq(tooltip.display_rows(), [
		{"label": "Sober", "value": "40%", "tone": &"base"},
		{"label": "Weak", "value": "+15%", "tone": &"increase"},
		{"label": "???", "value": "???", "tone": &"unknown"},
		{"label": "Total", "value": "???", "tone": &"total"},
	])
	assert_false(tooltip.tooltip_text.contains("unknown_modifier"))
	assert_false(tooltip.tooltip_text.contains("minus"))
	assert_false(tooltip.tooltip_text.contains("-"))
	assert_eq(tooltip.tooltip_text, "Sober 40%. Weak +15%. Unknown modifier. Total unknown.")


func test_popup_position_stays_inside_all_supported_review_widths() -> void:
	for width: float in [1024.0, 1280.0, 1920.0]:
		var viewport := Vector2(width, 720.0)
		var size := Vector2(248.0, 190.0)
		var position: Vector2 = TOOLTIP_SCRIPT.clamped_position(Vector2(width - 20.0, 690.0), size, viewport)
		assert_gte(position.x, 6.0)
		assert_lte(position.x + size.x, viewport.x - 6.0)
		assert_gte(position.y, 6.0)
		assert_lte(position.y + size.y, viewport.y - 6.0)
