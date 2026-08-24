extends GutTest

const MOOD_SCRIPT := preload("res://scripts/patrons/patron_mood.gd")


func test_bands_and_tip_multipliers_cover_the_full_range() -> void:
	var mood = MOOD_SCRIPT.new()
	assert_eq(mood.band(), "Content")
	assert_eq(mood.tip_multiplier(), 1.0)
	mood.change(5.0, &"prompt_service")
	assert_eq(mood.band(), "Happy")
	assert_eq(mood.tip_multiplier(), 1.5)
	mood.change(-40.0, &"failed_orders")
	assert_eq(mood.band(), "Unhappy")
	assert_eq(mood.tip_multiplier(), 0.5)
	mood.change(-50.0, &"collapse")
	assert_eq(mood.band(), "Miserable")
	assert_eq(mood.tip_multiplier(), 0.0)
	assert_eq(mood.value(), 0.0)


func test_each_cultist_can_award_the_first_talk_bonus_once() -> void:
	var mood = MOOD_SCRIPT.new()
	assert_true(mood.complete_talk(&"cultist_01"))
	assert_false(mood.complete_talk(&"cultist_01"))
	assert_true(mood.complete_talk(&"cultist_02"))
	assert_eq(mood.value(), 85.0)
