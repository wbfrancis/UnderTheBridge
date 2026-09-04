extends GutTest

const SATISFACTION_SCRIPT := preload("res://scripts/patrons/patron_satisfaction.gd")


func test_bands_and_tip_multipliers_cover_the_full_range() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	assert_eq(satisfaction.band(), "Content")
	assert_eq(satisfaction.tip_multiplier(), 1.0)
	satisfaction.change(5.0, &"prompt_service")
	assert_eq(satisfaction.band(), "Happy")
	assert_eq(satisfaction.tip_multiplier(), 1.5)
	satisfaction.change(-40.0, &"failed_orders")
	assert_eq(satisfaction.band(), "Unhappy")
	assert_eq(satisfaction.tip_multiplier(), 0.5)
	satisfaction.change(-50.0, &"collapse")
	assert_eq(satisfaction.band(), "Miserable")
	assert_eq(satisfaction.tip_multiplier(), 0.0)
	assert_eq(satisfaction.value(), 0.0)


func test_each_cultist_can_award_the_first_talk_bonus_once() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	assert_true(satisfaction.complete_talk(&"cultist_01"))
	assert_false(satisfaction.complete_talk(&"cultist_01"))
	assert_true(satisfaction.complete_talk(&"cultist_02"))
	assert_eq(satisfaction.value(), 85.0)
