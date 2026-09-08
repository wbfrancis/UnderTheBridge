extends GutTest

const PATCH_VIEW_SCRIPT := preload("res://scripts/presentation/grime_patch_view.gd")


func test_patch_geometry_is_stable_and_pickable_for_each_surface() -> void:
	for surface: StringName in [&"floor", &"table", &"bar"]:
		var first = PATCH_VIEW_SCRIPT.new()
		var second = PATCH_VIEW_SCRIPT.new()
		add_child_autoqfree(first)
		add_child_autoqfree(second)
		var patch := {
			"id": StringName("patch_%s" % surface), "variant": 2,
			"severity": &"moderate", "surface_type": surface,
			"center": Vector2(1.0, 2.0), "surface_bounds": Rect2(0.0, 1.0, 2.0, 2.0),
		}
		first.configure(patch)
		second.configure(patch)
		assert_eq(first.footprint_points(), second.footprint_points())
		assert_eq(first.get_meta("grime_id"), patch["id"])
		assert_eq(first.collision_layer, 2)


func test_inspection_outline_pulses_without_changing_the_stain() -> void:
	var patch = PATCH_VIEW_SCRIPT.new()
	add_child_autoqfree(patch)
	patch.configure({
		"id": &"patch", "variant": 1, "severity": &"heavy", "surface_type": &"floor",
		"center": Vector2.ZERO, "surface_bounds": Rect2(-1.0, -1.0, 2.0, 2.0),
	})
	var footprint := patch.footprint_points()
	patch.set_inspected(true)
	var first_alpha := patch.outline_alpha()
	patch.advance_pulse(0.7)
	assert_ne(patch.outline_alpha(), first_alpha)
	assert_eq(patch.footprint_points(), footprint)
	patch.set_inspected(false)
	assert_false(patch.outline_visible())


func test_severity_increases_residue_density_more_than_footprint() -> void:
	var counts: Array[int] = []
	var radii: Array[float] = []
	for severity: StringName in [&"light", &"moderate", &"heavy"]:
		var patch = PATCH_VIEW_SCRIPT.new()
		add_child_autoqfree(patch)
		patch.configure({
			"id": severity, "variant": 4, "severity": severity, "surface_type": &"floor",
			"center": Vector2.ZERO, "surface_bounds": Rect2(-1.0, -1.0, 2.0, 2.0),
		})
		counts.append(patch.residue_count())
		var radius := 0.0
		for point: Vector3 in patch.footprint_points():
			radius = maxf(radius, Vector2(point.x, point.z).length())
		radii.append(radius)
	assert_eq(counts, [2, 5, 9])
	assert_gt(radii[2], radii[0])
	assert_lt(radii[2] / radii[0], float(counts[2]) / float(counts[0]))
