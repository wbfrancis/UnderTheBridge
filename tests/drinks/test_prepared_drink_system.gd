extends GutTest

const PREPARED_DRINK_SYSTEM_SCRIPT := preload("res://scripts/drinks/prepared_drink_system.gd")


func test_fourth_drink_evicts_the_oldest_unreserved_drink() -> void:
	var drinks = PREPARED_DRINK_SYSTEM_SCRIPT.new()
	var wine: Dictionary = drinks.add_drink(&"wine")
	var beer: Dictionary = drinks.add_drink(&"beer")
	var liquor: Dictionary = drinks.add_drink(&"liquor")
	assert_true(drinks.reserve(StringName(wine["drink_id"]), ActorIds.CULTIST_IDS[0]))

	var next: Dictionary = drinks.add_drink(&"wine")
	assert_true(bool(next["added"]))
	assert_eq(next["evicted_id"], beer["drink_id"])
	assert_true(drinks.has(StringName(wine["drink_id"])))
	assert_true(drinks.has(StringName(liquor["drink_id"])))


func test_full_bar_rejects_preparation_when_all_drinks_are_reserved() -> void:
	var drinks = PREPARED_DRINK_SYSTEM_SCRIPT.new()
	for index in range(3):
		var result: Dictionary = drinks.add_drink(PREPARED_DRINK_SYSTEM_SCRIPT.DRINK_TYPES[index])
		assert_true(drinks.reserve(StringName(result["drink_id"]), ActorIds.CULTIST_IDS[index]))
	assert_false(drinks.can_add())
	assert_eq(drinks.add_drink(&"wine")["reason"], &"bar_full")


func test_drugging_reserves_the_drink_and_makes_it_newest() -> void:
	var drinks = PREPARED_DRINK_SYSTEM_SCRIPT.new()
	var wine_id: StringName = drinks.add_drink(&"wine")["drink_id"]
	drinks.add_drink(&"beer")
	assert_true(drinks.drug(wine_id, ActorIds.CULTIST_IDS[0]))
	var ordered: Array = drinks.snapshot()["drinks"]
	assert_eq(ordered[-1]["id"], wine_id)
	assert_true(bool(ordered[-1]["drugged"]))
	assert_eq(ordered[-1]["reserved_by"], ActorIds.CULTIST_IDS[0])


func test_dispose_reports_the_assigned_cultist_and_removes_the_drink() -> void:
	var drinks = PREPARED_DRINK_SYSTEM_SCRIPT.new()
	var drink_id: StringName = drinks.add_drink(&"liquor")["drink_id"]
	drinks.reserve(drink_id, ActorIds.CULTIST_IDS[1])
	var result: Dictionary = drinks.dispose(drink_id)
	assert_true(bool(result["disposed"]))
	assert_eq(result["cultist_id"], ActorIds.CULTIST_IDS[1])
	assert_false(drinks.has(drink_id))
