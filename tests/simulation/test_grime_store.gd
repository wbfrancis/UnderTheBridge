extends GutTest


func _slot(id: StringName = &"floor_01", blocking: bool = false) -> Dictionary:
	return {
		"slot_id": id, "room": &"main_hall", "center": Vector2(2.0, 3.0),
		"surface_id": &"main_floor", "surface_type": &"floor",
		"surface_bounds": Rect2(-5.0, -5.0, 10.0, 10.0),
		"approach_position": Vector2(2.0, 4.0), "blocking_bathroom": blocking,
	}


func test_creation_minimum_only_applies_when_the_patch_is_created() -> void:
	var store := GrimeStore.new()
	store.add_to_slot(_slot(), 1.0)
	assert_eq(store.patch(&"floor_01")["clean_seconds"], 2.0)
	store.add_to_slot(_slot(), 0.5)
	assert_eq(store.patch(&"floor_01")["clean_seconds"], 2.5)


func test_clean_preserves_a_sub_two_second_remainder_and_uses_its_real_time() -> void:
	var store := GrimeStore.new()
	store.add_to_slot(_slot(), 29.0)
	var snapshot := store.clean_snapshot(&"floor_01")
	store.add_to_slot(_slot(), 3.0)
	assert_eq(store.patch(&"floor_01")["clean_seconds"], 30.0)
	store.complete_clean(&"floor_01", snapshot)
	assert_eq(store.patch(&"floor_01")["clean_seconds"], 1.0)
	assert_eq(store.clean_snapshot(&"floor_01"), 1.0)
	store.complete_clean(&"floor_01", 1.0)
	assert_false(store.has(&"floor_01"))


func test_fresh_patches_have_stable_event_ids_and_fractional_growth() -> void:
	var store := GrimeStore.new()
	var first := store.add_fresh(_slot(), 4.5)
	var second := store.add_fresh(_slot(), 8.0)
	assert_eq(first, &"grime_event_0001")
	assert_eq(second, &"grime_event_0002")
	assert_eq(store.patch(first)["clean_seconds"], 4.5)


func test_reservation_is_exclusive_and_block_clears_with_patch() -> void:
	var store := GrimeStore.new()
	store.add_to_slot(_slot(&"ruined", true), 28.0)
	assert_true(store.bathroom_blocked())
	assert_true(store.reserve(&"ruined", ActorIds.CULTIST_IDS[0]))
	assert_false(store.reserve(&"ruined", ActorIds.CULTIST_IDS[1]))
	store.complete_clean(&"ruined", 28.0)
	assert_false(store.bathroom_blocked())
	assert_eq(store.owner(&"ruined"), ActorIds.NO_ACTOR)
