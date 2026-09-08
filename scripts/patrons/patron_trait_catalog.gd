class_name PatronTraitCatalog
extends RefCounted

const DRINK_PREFERENCES: Array[StringName] = [&"wine_drinker", &"beer_drinker", &"whiskey_drinker"]

const DEFINITIONS := {
	&"weak": {"label": "Weak", "incompatible_with": [&"strong"], "effects": {"knockout_points": 15}},
	&"strong": {"label": "Strong", "incompatible_with": [&"weak"], "effects": {"knockout_points": -15}},
	&"hollow_leg": {"label": "Hollow Leg", "incompatible_with": [&"lightweight"], "effects": {"intoxication_gain": 4, "overdrink_limit": 2}},
	&"lush": {"label": "Lush", "incompatible_with": [&"lightweight"], "effects": {"ideal_intoxication": 1, "order_rate": 1.35}},
	&"lightweight": {"label": "Lightweight", "incompatible_with": [&"hollow_leg", &"lush"], "effects": {"intoxication_gain": 9, "ideal_intoxication": -1, "overdrink_limit": -1}},
	&"nurser": {"label": "Nurser", "incompatible_with": [], "effects": {"drink_duration_multiplier": 1.5}},
	&"wine_drinker": {"label": "Wine Drinker", "incompatible_with": [&"beer_drinker", &"whiskey_drinker"], "effects": {"drink_preference": &"wine"}},
	&"beer_drinker": {"label": "Beer Drinker", "incompatible_with": [&"wine_drinker", &"whiskey_drinker"], "effects": {"drink_preference": &"beer"}},
	&"whiskey_drinker": {"label": "Whiskey Drinker", "incompatible_with": [&"wine_drinker", &"beer_drinker"], "effects": {"drink_preference": &"liquor"}},
	&"paranoid": {"label": "Paranoid", "incompatible_with": [&"trusting"], "effects": {"suspicion_multiplier": 1.5, "knockout_notice_points": 20}},
	&"trusting": {"label": "Trusting", "incompatible_with": [&"paranoid"], "effects": {"suspicion_multiplier": 0.5, "friendship_multiplier": 1.5}},
	&"nosy": {"label": "Nosy", "incompatible_with": [&"oblivious"], "effects": {"missing_companion_seconds": 30.0, "knockout_notice_points": 15, "reason_with_points": -20}},
	&"oblivious": {"label": "Oblivious", "incompatible_with": [&"nosy"], "effects": {"knockout_notice_points": -25, "reason_with_points": 20}},
	&"germaphobe": {"label": "Germaphobe", "incompatible_with": [&"slob"], "effects": {"grime_threshold": 6.0, "grime_rate_multiplier": 2.0, "grime_floor": 0.0}},
	&"slob": {"label": "Slob", "incompatible_with": [&"germaphobe"], "effects": {"drink_grime_chance": 100.0, "drink_grime_multiplier": 1.5, "grime_immune": true}},
	&"big_tipper": {"label": "Big Tipper", "incompatible_with": [&"tightwad"], "effects": {"tip_band_points": 50}},
	&"tightwad": {"label": "Tightwad", "incompatible_with": [&"big_tipper"], "effects": {"tip_band_points": -50}},
	&"sociable": {"label": "Sociable", "incompatible_with": [&"grouch"], "effects": {"starting_satisfaction": 15.0, "talk_multiplier": 1.5}},
	&"grouch": {"label": "Grouch", "incompatible_with": [&"sociable"], "effects": {"starting_satisfaction": -15.0}},
	&"non_smoker": {"label": "Non-Smoker", "incompatible_with": [], "effects": {"cigarette_refusal_satisfaction": -5.0}},
}


static func validate_catalog(definitions: Dictionary = DEFINITIONS) -> Array[String]:
	var errors: Array[String] = []
	for trait_id: StringName in definitions:
		var seen := {}
		for other_id: StringName in definitions[trait_id].get("incompatible_with", []):
			if other_id == trait_id:
				errors.append("%s excludes itself" % trait_id)
			elif seen.has(other_id):
				errors.append("%s repeats %s" % [trait_id, other_id])
			elif not definitions.has(other_id):
				errors.append("%s references missing %s" % [trait_id, other_id])
			elif trait_id not in definitions[other_id].get("incompatible_with", []):
				errors.append("%s/%s is asymmetric" % [trait_id, other_id])
			seen[other_id] = true
	for preference: StringName in DRINK_PREFERENCES:
		if not definitions.has(preference):
			errors.append("missing drink preference %s" % preference)
	return errors


static func count_from_rolls(first: bool, second: bool) -> int:
	return 1 + int(first) + int(second)


static func assign(night_seed: int, seed_key: StringName) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:traits" % [night_seed, seed_key])
	var count := count_from_rolls(rng.randf() < 0.5, rng.randf() < 0.5)
	var loadouts := valid_loadouts(count)
	return loadouts[rng.randi_range(0, loadouts.size() - 1)].duplicate()


static func valid_loadouts(count: int) -> Array[Array]:
	var results: Array[Array] = []
	var extras: Array[StringName] = []
	for trait_id: StringName in DEFINITIONS:
		if trait_id not in DRINK_PREFERENCES:
			extras.append(trait_id)
	extras.sort()
	for preference: StringName in DRINK_PREFERENCES:
		if count == 1:
			results.append([preference])
			continue
		for first_index in extras.size():
			var first := extras[first_index]
			if not _compatible(preference, first):
				continue
			if count == 2:
				results.append([preference, first])
				continue
			for second_index in range(first_index + 1, extras.size()):
				var second := extras[second_index]
				if _compatible(preference, second) and _compatible(first, second):
					results.append([preference, first, second])
	return results


static func _compatible(first: StringName, second: StringName) -> bool:
	return second not in DEFINITIONS[first].get("incompatible_with", [])


static func has(traits: Array, trait_id: StringName) -> bool:
	return trait_id in traits


static func effect(traits: Array, effect_id: StringName, fallback: Variant = 0) -> Variant:
	for trait_id: StringName in traits:
		var effects: Dictionary = DEFINITIONS[trait_id].get("effects", {})
		if effects.has(effect_id):
			return effects[effect_id]
	return fallback


static func summed_effect(traits: Array, effect_id: StringName) -> float:
	var total := 0.0
	for trait_id: StringName in traits:
		var effects: Dictionary = DEFINITIONS[trait_id].get("effects", {})
		if effects.has(effect_id):
			total += float(effects[effect_id])
	return total


static func labels(trait_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for trait_id: StringName in trait_ids:
		if DEFINITIONS.has(trait_id):
			result.append(DEFINITIONS[trait_id]["label"])
	return result


static func drink_preference(traits: Array) -> StringName:
	return effect(traits, &"drink_preference", &"wine")
