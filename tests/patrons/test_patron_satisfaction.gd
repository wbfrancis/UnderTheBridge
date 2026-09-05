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
	assert_true(satisfaction.complete_talk(1))
	assert_false(satisfaction.complete_talk(1))
	assert_true(satisfaction.complete_talk(2))
	assert_eq(satisfaction.value(), 85.0)


func test_standing_pressure_offsets_the_meter_until_it_is_removed() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	satisfaction.add_modifier(&"sighted_grime", -20.0)
	assert_eq(satisfaction.value(), 55.0, "Pressure offsets the meter while it stands.")
	assert_eq(satisfaction.base_value(), 75.0, "Pressure never moves the base.")
	# A modifier with no envelope outlasts any amount of time. The base drifts
	# on its own underneath it, so assert the weight rather than the total.
	satisfaction.advance(600.0)
	assert_true(
		satisfaction.has_modifier(&"sighted_grime"), "Standing pressure does not expire on its own."
	)
	assert_eq(
		satisfaction.modifier_contribution(&"sighted_grime"), -20.0, "It keeps its full weight."
	)
	var drifted := satisfaction.base_value()
	assert_true(satisfaction.remove_modifier(&"sighted_grime"))
	assert_eq(satisfaction.value(), drifted, "Cleaning it lifts the whole weight back off.")


func test_a_growing_cluster_scales_one_modifier_instead_of_stacking() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	satisfaction.add_modifier(&"sighted_grime", -5.0)
	satisfaction.add_modifier(&"sighted_grime", -12.0)
	assert_eq(satisfaction.modifier_total(), -12.0, "The repeat takes the new magnitude.")
	assert_eq(satisfaction.value(), 63.0, "One weight, not two.")
	assert_true(satisfaction.remove_modifier(&"sighted_grime"))
	assert_eq(satisfaction.value(), 75.0, "Removing the source clears the whole cluster.")


func test_the_smoking_envelope_fades_in_holds_then_fades_out_and_expires() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	satisfaction.add_modifier(&"smoking", 10.0, 10.0, 40.0, 10.0)
	assert_eq(satisfaction.modifier_contribution(&"smoking"), 0.0, "It starts at nothing.")
	satisfaction.advance(5.0)
	assert_almost_eq(satisfaction.modifier_contribution(&"smoking"), 5.0, 0.01, "Half faded in.")
	satisfaction.advance(5.0)
	assert_almost_eq(satisfaction.modifier_contribution(&"smoking"), 10.0, 0.01, "Full at hold.")
	satisfaction.advance(40.0)
	assert_almost_eq(satisfaction.modifier_contribution(&"smoking"), 10.0, 0.01, "Held throughout.")
	satisfaction.advance(5.0)
	assert_almost_eq(satisfaction.modifier_contribution(&"smoking"), 5.0, 0.01, "Half faded out.")
	satisfaction.advance(5.0)
	assert_false(satisfaction.has_modifier(&"smoking"), "It expires at the end of the envelope.")
	assert_eq(satisfaction.value(), 75.0, "The meter returns to where it was.")


func test_a_repeat_refreshes_the_envelope_rather_than_adding_a_second_copy() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	satisfaction.add_modifier(&"smoking", 10.0, 0.0, 10.0, 0.0)
	satisfaction.advance(9.0)
	satisfaction.add_modifier(&"smoking", 10.0, 0.0, 10.0, 0.0)
	assert_eq(satisfaction.modifier_total(), 10.0, "One copy, not two.")
	# The refreshed envelope runs its full length again from the repeat.
	satisfaction.advance(9.0)
	assert_true(satisfaction.has_modifier(&"smoking"), "The repeat restarted the envelope.")
	satisfaction.advance(2.0)
	assert_false(satisfaction.has_modifier(&"smoking"), "Then it expires on the new clock.")


func test_decay_drifts_down_and_stops_at_the_unhappy_floor() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	# About one band across a nine-minute visit.
	satisfaction.advance(540.0)
	assert_almost_eq(satisfaction.value(), 48.0, 0.01, "An unattended Patron drifts one band.")
	assert_eq(satisfaction.band(), "Unhappy")
	satisfaction.advance(6000.0)
	assert_eq(satisfaction.value(), 25.0, "Decay alone stops at the floor.")
	assert_eq(satisfaction.band(), "Unhappy", "Neglect never reaches Miserable on its own.")


func test_only_a_service_failure_carries_a_patron_below_the_decay_floor() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	satisfaction.advance(6000.0)
	assert_eq(satisfaction.value(), 25.0)
	satisfaction.change(-20.0, &"failed_order")
	assert_eq(satisfaction.value(), 5.0, "A failure pushes through the floor.")
	assert_eq(satisfaction.band(), "Miserable")
	# The floor never pulls a Patron back up once a failure took them below it.
	satisfaction.advance(600.0)
	assert_eq(satisfaction.value(), 5.0, "Decay leaves them where the failure left them.")


func test_decay_pauses_while_a_positive_modifier_is_active() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	satisfaction.add_modifier(&"smoking", 10.0, 0.0, 60.0, 0.0)
	satisfaction.advance(60.0)
	assert_eq(satisfaction.base_value(), 75.0, "A cigarette is respite, not a headwind.")
	assert_false(satisfaction.has_modifier(&"smoking"), "That tick also ended the envelope.")
	# Once it expires the meter resumes drifting.
	satisfaction.advance(100.0)
	assert_lt(satisfaction.base_value(), 75.0, "Decay resumes when the respite ends.")


func test_standing_pressure_does_not_hold_decay_off() -> void:
	var satisfaction = SATISFACTION_SCRIPT.new()
	satisfaction.add_modifier(&"sighted_grime", -20.0)
	satisfaction.advance(100.0)
	assert_lt(satisfaction.base_value(), 75.0, "A negative modifier is not respite.")
