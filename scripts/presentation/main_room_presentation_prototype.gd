extends Node3D

const FLOOR_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/floor.jpg"
)
const WALLPAPER_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/wall_stucco.jpg"
)
const WALL_BOARDS_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/wall_boards.jpg"
)
const WOOD_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/wood_finished03.jpg"
)
const WOOD_LIGHT_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/wood_finished01.jpg"
)
const BRASS_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/brass.jpg"
)
const CLOTH_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/cloth.jpg"
)
const METAL_TEXTURE: Texture2D = preload(
	"res://assets/environment/prototype_visual/Textures/ADS_base_metal.jpg"
)

const FLOOR_SIZE := Vector3(27.0, 0.08, 12.0)
const BAR_WIDTH := 12.0


func _ready() -> void:
	_build_room_shell()
	_build_full_scale_bar()
	_build_seating()
	_build_auxiliary_spaces()
	_build_lighting()


func _build_room_shell() -> void:
	add_child(_box(
		"MainRoomFloor",
		FLOOR_SIZE,
		Vector3(-0.5, 0.09, 4.0),
		_textured_material(FLOOR_TEXTURE, Color("8d8173"), 0.88, Vector3(9.0, 4.0, 1.0))
	))
	add_child(_box(
		"WallpaperBackWall",
		Vector3(27.0, 3.8, 0.22),
		Vector3(-0.5, 1.9, -1.82),
		_textured_material(WALLPAPER_TEXTURE, Color("7a6246"), 0.84, Vector3(8.0, 4.0, 8.0))
	))
	add_child(_box(
		"BoardedWainscot",
		Vector3(27.0, 1.05, 0.28),
		Vector3(-0.5, 0.57, -1.64),
		_textured_material(WALL_BOARDS_TEXTURE, Color("744235"), 0.66, Vector3(8.0, 2.0, 8.0))
	))
	add_child(_box(
		"WainscotRail",
		Vector3(27.0, 0.14, 0.38),
		Vector3(-0.5, 1.12, -1.54),
		_textured_material(WOOD_TEXTURE, Color("9a5a32"), 0.48, Vector3(9.0, 1.0, 1.0))
	))
	add_child(_box(
		"CrownMoulding",
		Vector3(27.0, 0.18, 0.4),
		Vector3(-0.5, 3.72, -1.54),
		_textured_material(WOOD_TEXTURE, Color("9a5a32"), 0.46, Vector3(9.0, 1.0, 1.0))
	))

	for x_position in [-12.5, -9.0, 8.0, 11.5]:
		add_child(_box(
			"WallColumn",
			Vector3(0.32, 3.5, 0.38),
			Vector3(x_position, 1.82, -1.48),
			_textured_material(WOOD_TEXTURE, Color("784024"), 0.5, Vector3(1.0, 3.0, 1.0))
		))
		add_child(_box(
			"AmberSconce",
			Vector3(0.22, 0.42, 0.18),
			Vector3(x_position, 2.35, -1.23),
			_emissive_material(Color("f2a250"), 1.7)
		))


func _build_full_scale_bar() -> void:
	var wood := _textured_material(WOOD_TEXTURE, Color("8a4e2d"), 0.5, Vector3(4.0, 2.0, 2.0))
	var dark_wood := _textured_material(WALL_BOARDS_TEXTURE, Color("562b25"), 0.62, Vector3(4.0, 2.0, 2.0))
	add_child(_box(
		"BarFront",
		Vector3(BAR_WIDTH, 1.12, 1.35),
		Vector3(0.0, 0.68, 0.15),
		dark_wood
	))
	add_child(_box(
		"BarTop",
		Vector3(BAR_WIDTH + 0.45, 0.16, 1.65),
		Vector3(0.0, 1.28, 0.15),
		wood
	))
	add_child(_box(
		"BackbarCabinet",
		Vector3(10.5, 2.45, 0.62),
		Vector3(0.0, 1.46, -1.28),
		dark_wood
	))
	add_child(_box(
		"BackbarMirror",
		Vector3(8.7, 1.55, 0.08),
		Vector3(0.0, 1.85, -0.92),
		_mirror_material()
	))
	for x_position in [-5.25, 5.25]:
		add_child(_box(
			"BackbarColumn",
			Vector3(0.42, 3.15, 0.55),
			Vector3(x_position, 1.66, -0.93),
			wood
		))
	for shelf_height in [1.25, 1.85, 2.45]:
		add_child(_box(
			"BottleShelf",
			Vector3(8.9, 0.1, 0.48),
			Vector3(0.0, shelf_height, -0.78),
			wood
		))
		for bottle_index in range(13):
			var bottle_color := Color("7f3138") if bottle_index % 3 == 0 else Color("b58342")
			add_child(_box(
				"Bottle",
				Vector3(0.16, 0.34, 0.14),
				Vector3(-4.15 + float(bottle_index) * 0.69, shelf_height + 0.22, -0.7),
				_material(bottle_color, 0.28)
			))
	add_child(_box(
		"BarArch",
		Vector3(10.9, 0.24, 0.68),
		Vector3(0.0, 3.17, -0.93),
		wood
	))


func _build_seating() -> void:
	var tabletop_material := _textured_material(WOOD_TEXTURE, Color("704027"), 0.56, Vector3(2.0, 2.0, 2.0))
	var metal_material := _material(Color("25242b"), 0.32)
	for x_position in [-11.2, -5.2, 5.2, 11.2]:
		var tabletop := MeshInstance3D.new()
		tabletop.name = "CocktailTable"
		var tabletop_mesh := CylinderMesh.new()
		tabletop_mesh.top_radius = 0.78
		tabletop_mesh.bottom_radius = 0.78
		tabletop_mesh.height = 0.1
		tabletop_mesh.radial_segments = 24
		tabletop.mesh = tabletop_mesh
		tabletop.position = Vector3(x_position, 0.82, 6.0)
		tabletop.material_override = tabletop_material
		add_child(tabletop)
		add_child(_box("TableStem", Vector3(0.15, 0.76, 0.15), Vector3(x_position, 0.43, 6.0), metal_material))

	add_child(_box(
		"CentralRug",
		Vector3(7.8, 0.035, 4.7),
		Vector3(0.0, 0.16, 5.2),
		_material(Color("27151f"), 0.93)
	))
	add_child(_box(
		"RugBorder",
		Vector3(7.15, 0.02, 4.05),
		Vector3(0.0, 0.185, 5.2),
		_material(Color("442b34"), 0.88)
	))


func _build_auxiliary_spaces() -> void:
	var front_floor_material := _textured_material(FLOOR_TEXTURE, Color("85796c"), 0.9, Vector3(3.5, 7.0, 1.0))
	var hallway_floor_material := _textured_material(FLOOR_TEXTURE, Color("85796c"), 0.9, Vector3(2.0, 3.0, 1.0))
	var wallpaper := _textured_material(WALLPAPER_TEXTURE, Color("715c45"), 0.86, Vector3(4.0, 3.0, 4.0))
	var boards := _textured_material(WALL_BOARDS_TEXTURE, Color("63392e"), 0.68, Vector3(4.0, 2.0, 4.0))
	var wood := _textured_material(WOOD_LIGHT_TEXTURE, Color("815033"), 0.55, Vector3(3.0, 2.0, 2.0))
	var brass := _textured_material(BRASS_TEXTURE, Color("a3773f"), 0.38, Vector3(2.0, 2.0, 2.0))
	var dark_metal := _textured_material(METAL_TEXTURE, Color("343038"), 0.46, Vector3(2.0, 2.0, 2.0))

	# Front room: rotate the same 14×7-metre footprint onto the map's left edge.
	add_child(_box("FrontFloor", Vector3(7.0, 0.08, 14.0), Vector3(-17.5, 0.09, 5.0), front_floor_material))
	for z_position in [-1.9, 11.9]:
		add_child(_box("FrontSideWall", Vector3(7.0, 0.9, 0.22), Vector3(-17.5, 0.45, z_position), wallpaper))
		add_child(_box("FrontWainscot", Vector3(7.0, 0.62, 0.28), Vector3(-17.5, 0.32, z_position), boards))
	add_child(_box("StreetWallNorth", Vector3(0.24, 0.9, 5.2), Vector3(-20.88, 0.45, 0.6), wallpaper))
	add_child(_box("StreetWallSouth", Vector3(0.24, 0.9, 5.2), Vector3(-20.88, 0.45, 9.4), wallpaper))
	add_child(_box("ExitHeader", Vector3(0.32, 0.18, 3.6), Vector3(-20.82, 0.88, 5.0), wood))
	for z_position in [4.1, 5.9]:
		add_child(_box("FrontExitDoor", Vector3(0.18, 0.7, 1.7), Vector3(-20.72, 0.36, z_position), wood))
		add_child(_box("ExitDoorGlass", Vector3(0.05, 0.32, 1.0), Vector3(-20.59, 0.48, z_position), _mirror_material()))
		add_child(_box("ExitDoorHandle", Vector3(0.12, 0.18, 0.08), Vector3(-20.45, 0.38, 5.0 + (z_position - 5.0) * 0.22), brass))
	add_child(_box("FrontRunner", Vector3(5.4, 0.035, 3.8), Vector3(-17.7, 0.16, 5.0), _textured_material(CLOTH_TEXTURE, Color("572b38"), 0.92, Vector3(4.0, 2.0, 1.0))))
	add_child(_space_label("FRONT EXIT", Vector3(-20.55, 1.22, 5.0), Color("edc685")))

	# Hallway: the narrow east route between the main room, bathroom, and intake.
	add_child(_box("HallwayFloor", Vector3(4.0, 0.08, 6.0), Vector3(15.0, 0.09, 6.0), hallway_floor_material))
	add_child(_box("HallwaySouthWall", Vector3(4.0, 2.4, 0.22), Vector3(15.0, 1.2, 3.1), wallpaper))
	for z_position in [3.1, 8.9]:
		add_child(_box("HallwayRail", Vector3(4.0, 0.15, 0.34), Vector3(15.0, 1.04, z_position), wood))
	add_child(_space_label("HALLWAY", Vector3(15.0, 2.7, 7.7), Color("d8b77d")))

	# Bathroom: a cutaway room with a visible standing zone, seated fixture, and Trapdoor.
	add_child(_box("BathroomFloor", Vector3(4.0, 0.08, 6.0), Vector3(19.0, 0.09, 6.0), _material(Color("4b5558"), 0.88)))
	add_child(_box("BathroomOuterWall", Vector3(0.22, 2.7, 6.0), Vector3(20.9, 1.35, 6.0), wallpaper))
	add_child(_box("BathroomBackWall", Vector3(4.0, 2.7, 0.22), Vector3(19.0, 1.35, 3.1), wallpaper))
	add_child(_box("BathroomWainscot", Vector3(0.28, 1.0, 6.0), Vector3(20.75, 0.52, 6.0), boards))
	add_child(_box("BathroomDivider", Vector3(0.16, 0.82, 2.5), Vector3(18.0, 0.41, 5.25), dark_metal))
	add_child(_box("ToiletBase", Vector3(0.72, 0.48, 0.9), Vector3(19.55, 0.3, 5.8), _material(Color("c6c0ad"), 0.72)))
	add_child(_box("ToiletTank", Vector3(0.8, 0.72, 0.35), Vector3(19.55, 0.7, 5.42), _material(Color("d8d1bc"), 0.7)))
	add_child(_box("Sink", Vector3(0.95, 0.18, 0.6), Vector3(19.55, 0.92, 7.75), _material(Color("c9c4b6"), 0.68)))
	add_child(_box("SinkStand", Vector3(0.28, 0.82, 0.28), Vector3(19.55, 0.45, 7.75), brass))
	add_child(_box("BathroomMirror", Vector3(1.3, 1.05, 0.08), Vector3(20.72, 1.75, 7.75), _mirror_material()))
	add_child(_box("Trapdoor", Vector3(1.35, 0.045, 1.35), Vector3(18.8, 0.16, 6.1), dark_metal))
	add_child(_box("TrapdoorInset", Vector3(1.05, 0.025, 1.05), Vector3(18.8, 0.19, 6.1), _material(Color("17171b"), 0.35)))
	add_child(_space_label("BATHROOM / TRAPDOOR", Vector3(19.0, 3.05, 4.0), Color("d7b77d")))

	# Tunnel Intake: a clear threshold in the hallway, separate from the bathroom Trapdoor.
	add_child(_box("IntakeThreshold", Vector3(2.35, 0.09, 1.0), Vector3(15.0, 0.16, 3.65), dark_metal))
	for x_position in [14.0, 16.0]:
		add_child(_box("IntakePost", Vector3(0.22, 2.25, 0.28), Vector3(x_position, 1.14, 3.65), wood))
	add_child(_box("IntakeHeader", Vector3(2.25, 0.28, 0.35), Vector3(15.0, 2.22, 3.65), wood))
	add_child(_box("IntakeCurtain", Vector3(1.65, 1.82, 0.08), Vector3(15.0, 1.05, 3.58), _textured_material(CLOTH_TEXTURE, Color("4a1f2d"), 0.9, Vector3(2.0, 3.0, 2.0))))
	add_child(_space_label("TUNNEL INTAKE", Vector3(15.0, 2.7, 3.65), Color("ef9e6c")))


func _space_label(text: String, at: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 28
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 14
	label.outline_modulate = Color("171017")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return label


func _build_lighting() -> void:
	var bar_light := OmniLight3D.new()
	bar_light.name = "BarLight"
	bar_light.position = Vector3(0.0, 3.1, 0.7)
	bar_light.light_color = Color("ffd0a0")
	bar_light.light_energy = 1.8
	bar_light.omni_range = 11.0
	bar_light.shadow_enabled = true
	add_child(bar_light)
	for x_position in [-10.5, 10.5]:
		var side_light := OmniLight3D.new()
		side_light.name = "SideLight"
		side_light.position = Vector3(x_position, 2.5, 1.0)
		side_light.light_color = Color("ef9358")
		side_light.light_energy = 0.78
		side_light.omni_range = 6.0
		add_child(side_light)
	var service_light := OmniLight3D.new()
	service_light.name = "ServiceWingLight"
	service_light.position = Vector3(16.5, 2.8, 6.0)
	service_light.light_color = Color("ffd29c")
	service_light.light_energy = 1.2
	service_light.omni_range = 8.0
	add_child(service_light)
	var front_light := OmniLight3D.new()
	front_light.name = "FrontRoomLight"
	front_light.position = Vector3(-17.5, 2.8, 5.0)
	front_light.light_color = Color("e6a873")
	front_light.light_energy = 0.9
	front_light.omni_range = 7.0
	add_child(front_light)


func _box(node_name: String, size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	return instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _textured_material(texture: Texture2D, tint: Color, roughness: float, uv_scale: Vector3) -> StandardMaterial3D:
	var material := _material(tint, roughness)
	material.albedo_texture = texture
	material.uv1_scale = uv_scale
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.35)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _mirror_material() -> StandardMaterial3D:
	var material := _material(Color("596473"), 0.2)
	material.metallic = 0.65
	material.emission_enabled = true
	material.emission = Color("303844")
	material.emission_energy_multiplier = 0.22
	return material
