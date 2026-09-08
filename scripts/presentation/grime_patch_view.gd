class_name GrimePatchView
extends Area3D

const BRASS := Color("C79A52")
const SEVERITY_SCALE := {&"light": 0.42, &"moderate": 0.58, &"heavy": 0.74}
const SEVERITY_ALPHA := {&"light": 0.42, &"moderate": 0.58, &"heavy": 0.74}
const SEVERITY_DENSITY := {&"light": 2, &"moderate": 5, &"heavy": 9}
const SURFACE_HEIGHT := {&"floor": 0.205, &"table": 0.91, &"bar": 1.37}

var _stain := MeshInstance3D.new()
var _residue := MeshInstance3D.new()
var _highlights := MeshInstance3D.new()
var _outline := MeshInstance3D.new()
var _points: PackedVector3Array = []
var _outline_material := StandardMaterial3D.new()
var _pulse_time := 0.0
var _residue_count := 0


func _init() -> void:
	collision_layer = 2
	collision_mask = 0
	add_child(_stain)
	add_child(_residue)
	add_child(_highlights)
	add_child(_outline)
	_outline.visible = false
	_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outline_material.albedo_color = Color(BRASS, 0.68)
	_outline_material.emission_enabled = true
	_outline_material.emission = BRASS * 0.35
	_outline.material_override = _outline_material


func configure(patch: Dictionary) -> void:
	var patch_id := StringName(patch.get("id", &""))
	var variant := int(patch.get("variant", 0))
	var severity := StringName(patch.get("severity", &"light"))
	var surface := StringName(patch.get("surface_type", &"floor"))
	var center: Vector2 = patch.get("center", Vector2.ZERO)
	var bounds: Rect2 = patch.get("surface_bounds", Rect2(center - Vector2.ONE, Vector2.ONE * 2.0))
	set_meta("grime_id", patch_id)
	set_meta("surface_id", StringName(patch.get("surface_id", &"floor")))
	position = Vector3(center.x, float(SURFACE_HEIGHT.get(surface, 0.205)), center.y)
	_points = _make_points(variant, severity, center, bounds)
	_stain.mesh = _polygon_mesh(_points, false)
	var stain_material := StandardMaterial3D.new()
	stain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var darkness := float(SEVERITY_ALPHA.get(severity, 0.42))
	stain_material.albedo_color = Color(0.20, 0.18, 0.15, darkness)
	stain_material.roughness = 0.72
	_stain.material_override = stain_material
	_residue_count = int(SEVERITY_DENSITY.get(severity, 2))
	_residue.mesh = _speck_mesh(variant, _residue_count, 0.045, 0.004, center, bounds)
	var residue_material := stain_material.duplicate() as StandardMaterial3D
	residue_material.albedo_color = Color(0.13, 0.12, 0.105, minf(0.86, darkness + 0.16))
	_residue.material_override = residue_material
	_highlights.mesh = _speck_mesh(
		variant + 17, 1 if severity == &"light" else 2, 0.025, 0.007, center, bounds
	)
	var highlight_material := StandardMaterial3D.new()
	highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.albedo_color = Color(0.63, 0.56, 0.42, 0.20)
	_highlights.material_override = highlight_material
	_outline.mesh = _polygon_mesh(_points, true)
	_update_collision(_points)


func footprint_points() -> PackedVector3Array:
	return _points.duplicate()


func set_inspected(active: bool) -> void:
	_outline.visible = active
	if active:
		_pulse_time = 0.0
		_set_outline_alpha(0.68)


func advance_pulse(real_seconds: float) -> void:
	if not _outline.visible:
		return
	_pulse_time += maxf(0.0, real_seconds)
	_set_outline_alpha(0.62 + sin(_pulse_time * 1.8) * 0.10)


func outline_visible() -> bool:
	return _outline.visible


func outline_alpha() -> float:
	return _outline_material.albedo_color.a


func residue_count() -> int:
	return _residue_count


func _set_outline_alpha(alpha: float) -> void:
	_outline_material.albedo_color.a = alpha


func _make_points(variant: int, severity: StringName, center: Vector2, bounds: Rect2) -> PackedVector3Array:
	var points := PackedVector3Array()
	var scale := float(SEVERITY_SCALE.get(severity, 0.42))
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var ripple := 0.78 + 0.16 * sin(float(index * 5 + variant * 3))
		var world := center + Vector2(cos(angle), sin(angle)) * scale * ripple
		world.x = clampf(world.x, bounds.position.x + 0.03, bounds.end.x - 0.03)
		world.y = clampf(world.y, bounds.position.y + 0.03, bounds.end.y - 0.03)
		points.append(Vector3(world.x - center.x, 0.0, world.y - center.y))
	return points


func _polygon_mesh(points: PackedVector3Array, outline: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	if outline:
		for point: Vector3 in points:
			vertices.append(point + Vector3.UP * 0.006)
		vertices.append(points[0] + Vector3.UP * 0.006)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
		return mesh
	for index in points.size():
		vertices.append(Vector3.ZERO)
		vertices.append(points[index])
		vertices.append(points[(index + 1) % points.size()])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _speck_mesh(
		variant: int, count: int, radius: float, height: float,
		world_center: Vector2, bounds: Rect2
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	for index in count:
		var angle := fmod(float(variant * 2 + index * 5), 17.0) / 17.0 * TAU
		var distance := 0.12 + 0.045 * float((variant + index * 3) % 7)
		var center := Vector3(cos(angle) * distance, height, sin(angle) * distance)
		center.x = clampf(center.x, bounds.position.x - world_center.x + radius, bounds.end.x - world_center.x - radius)
		center.z = clampf(center.z, bounds.position.y - world_center.y + radius, bounds.end.y - world_center.y - radius)
		for corner in 6:
			var first := TAU * float(corner) / 6.0
			var second := TAU * float(corner + 1) / 6.0
			vertices.append(center)
			vertices.append(center + Vector3(cos(first), 0.0, sin(first)) * radius)
			vertices.append(center + Vector3(cos(second), 0.0, sin(second)) * radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _update_collision(points: PackedVector3Array) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var maximum := 0.25
	for point: Vector3 in points:
		maximum = maxf(maximum, Vector2(point.x, point.z).length())
	var shape := CylinderShape3D.new()
	shape.radius = maximum
	shape.height = 0.08
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
