extends GutTest


func test_catalog_has_twenty_traits_and_valid_reciprocal_exclusions() -> void:
	assert_eq(PatronTraitCatalog.DEFINITIONS.size(), 20)
	assert_true(PatronTraitCatalog.validate_catalog().is_empty())


func test_catalog_pins_every_approved_trait_effect() -> void:
	var expected := {
		&"weak": {"knockout_points": 15},
		&"strong": {"knockout_points": -15},
		&"hollow_leg": {"intoxication_gain": 4, "overdrink_limit": 2},
		&"lush": {"ideal_intoxication": 1, "order_rate": 1.35},
		&"lightweight": {"intoxication_gain": 9, "ideal_intoxication": -1, "overdrink_limit": -1},
		&"nurser": {"drink_duration_multiplier": 1.5},
		&"wine_drinker": {"drink_preference": &"wine"},
		&"beer_drinker": {"drink_preference": &"beer"},
		&"whiskey_drinker": {"drink_preference": &"liquor"},
		&"paranoid": {"suspicion_multiplier": 1.5, "knockout_notice_points": 20},
		&"trusting": {"suspicion_multiplier": 0.5, "friendship_multiplier": 1.5},
		&"nosy": {"missing_companion_seconds": 30.0, "knockout_notice_points": 15, "reason_with_points": -20},
		&"oblivious": {"knockout_notice_points": -25, "reason_with_points": 20},
		&"germaphobe": {"grime_threshold": 6.0, "grime_rate_multiplier": 2.0, "grime_floor": 0.0},
		&"slob": {"drink_grime_chance": 100.0, "drink_grime_multiplier": 1.5, "grime_immune": true},
		&"big_tipper": {"tip_band_points": 50},
		&"tightwad": {"tip_band_points": -50},
		&"sociable": {"starting_satisfaction": 15.0, "talk_multiplier": 1.5},
		&"grouch": {"starting_satisfaction": -15.0},
		&"non_smoker": {"cigarette_refusal_satisfaction": -5.0},
	}
	for trait_id: StringName in expected:
		assert_eq(PatronTraitCatalog.DEFINITIONS[trait_id]["effects"], expected[trait_id], trait_id)


func test_two_count_rolls_cover_the_exact_four_outcomes() -> void:
	assert_eq(PatronTraitCatalog.count_from_rolls(false, false), 1)
	assert_eq(PatronTraitCatalog.count_from_rolls(true, false), 2)
	assert_eq(PatronTraitCatalog.count_from_rolls(false, true), 2)
	assert_eq(PatronTraitCatalog.count_from_rolls(true, true), 3)


func test_every_valid_loadout_has_one_preference_and_no_conflict() -> void:
	for count in [1, 2, 3]:
		var loadouts := PatronTraitCatalog.valid_loadouts(count)
		assert_gt(loadouts.size(), 0)
		for loadout: Array in loadouts:
			assert_eq(loadout.size(), count)
			var preferences := loadout.filter(
				func(trait_id): return trait_id in PatronTraitCatalog.DRINK_PREFERENCES
			)
			assert_eq(preferences.size(), 1)
			for first in loadout:
				for second in loadout:
					if first != second:
						assert_false(second in PatronTraitCatalog.DEFINITIONS[first]["incompatible_with"])


func test_assignment_uses_seed_and_authored_key_only() -> void:
	assert_eq(
		PatronTraitCatalog.assign(707, &"patron_june"),
		PatronTraitCatalog.assign(707, &"patron_june")
	)


func test_compatible_additive_effects_stack() -> void:
	assert_eq(PatronTraitCatalog.summed_effect(
		[&"wine_drinker", &"paranoid", &"nosy"], &"knockout_notice_points"
	), 35.0)
	assert_ne(
		PatronTraitCatalog.assign(707, &"patron_june"),
		PatronTraitCatalog.assign(708, &"patron_june")
	)


func test_catalog_validator_reports_each_integrity_failure() -> void:
	var broken := PatronTraitCatalog.DEFINITIONS.duplicate(true)
	broken[&"weak"]["incompatible_with"] = [&"weak", &"missing", &"strong", &"strong"]
	broken[&"strong"]["incompatible_with"] = []
	var errors := PatronTraitCatalog.validate_catalog(broken)
	assert_true(errors.any(func(error): return "itself" in error))
	assert_true(errors.any(func(error): return "missing" in error))
	assert_true(errors.any(func(error): return "repeats" in error))
	assert_true(errors.any(func(error): return "asymmetric" in error))
