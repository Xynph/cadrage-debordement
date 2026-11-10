extends Node3D
# Procedural conference furniture plus the already bundled Kenney CC0 chairs.
# No people, sponsor identities or journalist portraits are invented by the room.
const Identity = preload("res://ui/contextual/rooms/room_identity.gd")
const CHAIR = preload("res://ui/contextual/rooms/assets/furniture/chairDesk.glb")
const PLANT = preload("res://ui/contextual/rooms/assets/furniture/plantSmall1.glb")
var club: Dictionary = {}
var crest_texture: Texture2D
var primary_color := Identity.NEUTRAL_PRIMARY
var contrast_color := Color("e8e5dc")
var _primary: StandardMaterial3D
var _dark: StandardMaterial3D
var _wood: StandardMaterial3D
var _metal: StandardMaterial3D

func configure(identity: Dictionary, crest: Texture2D) -> void:
	club = identity.duplicate(true)
	primary_color = Identity.primary(identity)
	contrast_color = Identity.contrast(primary_color)
	crest_texture = crest
	set_meta("identity", club)
	set_meta("primary_color", primary_color)
	set_meta("contrast_color", contrast_color)
	set_meta("crest_texture", crest_texture)

func _ready() -> void:
	name = "ContextualPressRoom"
	_primary = _material(primary_color)
	_dark = _material(Color("16251f"))
	_wood = _material(Color("aa8862"))
	_metal = _material(Color("18201e"), .45)
	_build_room()
	_build_stage()
	_build_seating()
	_setup_lighting()

func _material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = .68 if metal == 0.0 else .32
	return result

func _box(id: String, position_: Vector3, size_: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = id
	var mesh := BoxMesh.new()
	mesh.size = size_
	result.mesh = mesh
	result.material_override = material
	result.position = position_
	add_child(result)
	return result

func _cylinder(id: String, position_: Vector3, radius: float, height_: float, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height_
	mesh.radial_segments = 16
	result.mesh = mesh
	result.material_override = material
	result.position = position_
	add_child(result)
	return result

func _build_room() -> void:
	_box("Floor", Vector3(0, -.12, 0), Vector3(12, .24, 15), _material(Color("777b71")))
	_box("BackWall", Vector3(0, 2.7, -5.5), Vector3(12, 5.4, .25), _material(Color("d5d1bf")))
	_box("LeftWall", Vector3(-6, 2.7, 0), Vector3(.2, 5.4, 11), _material(Color("b6b9ab")))
	_box("RightWall", Vector3(6, 2.7, 0), Vector3(.2, 5.4, 11), _material(Color("b6b9ab")))
	_box("Ceiling", Vector3(0, 5.5, -.6), Vector3(12, .18, 12), _material(Color("333d36")))
	var light_material := _material(Color("eee9cb"))
	light_material.emission_enabled = true
	light_material.emission = Color("e5dfb9")
	light_material.emission_energy_multiplier = .65
	for x in [-4.1, 0.0, 4.1]:
		_box("CeilingLight", Vector3(x, 5.37, -.8), Vector3(2.4, .06, .12), light_material)
	for z in [-4.3, -2.7, -1.1, .5, 2.1, 3.7]:
		_box("FloorJoint", Vector3(0, .005, z), Vector3(12, .008, .018), _material(Color("626a60")))
	_asset(PLANT, "PlantLeft", Vector3(-5.1, 0, -4.6), 1.65, 0)
	_asset(PLANT, "PlantRight", Vector3(5.1, 0, -4.6), 1.65, 0)

func _build_stage() -> void:
	_box("Dais", Vector3(0, .15, -3.45), Vector3(9, .3, 3.5), _dark)
	_box("DaisEdge", Vector3(0, .32, -1.7), Vector3(9, .06, .06), _primary)
	_box("MediaBackdrop", Vector3(0, 2.7, -5.24), Vector3(9.3, 4.2, .16), _dark)
	for row in 3:
		for col in 7:
			var x := -3.95 + col * 1.32
			var y := 1.25 + row * 1.18
			_box("ClubBackdropTile", Vector3(x, y, -5.13), Vector3(1.26, 1.1, .06), _primary if (row + col) % 2 == 0 else _dark)
			_crest(Vector3(x, y, -5.087), .68)
	_box("ConferenceTable", Vector3(0, 1.24, -3.35), Vector3(7.1, .16, 1.24), _wood)
	_box("TableFront", Vector3(0, .85, -2.73), Vector3(7.1, .82, .08), _primary)
	_box("TableTrim", Vector3(0, 1.3, -2.67), Vector3(7.1, .05, .05), _material(contrast_color))
	_crest(Vector3(0, .88, -2.676), .57)
	for x in [-2.7, 2.7]:
		_box("TableLeg", Vector3(x, .73, -3.35), Vector3(.12, .9, .85), _metal)
	for x in [-2.4, 0.0, 2.4]:
		_asset(CHAIR, "DaisChair", Vector3(x, .3, -4.4), 1.38, 0)
		_cylinder("MicrophoneBase", Vector3(x, 1.36, -3.0), .11, .05, _metal)
		var stem := _cylinder("MicrophoneStem", Vector3(x, 1.56, -3.0), .018, .4, _metal)
		stem.rotation_degrees.x = -17
		var head := _box("Microphone", Vector3(x, 1.78, -3.06), Vector3(.09, .11, .19), _material(Color("303b33")))
		head.rotation_degrees.x = -17
		_cylinder("WaterGlass", Vector3(x + .45, 1.44, -3.35), .065, .23, _material(Color("a5b8b1"), .25))
	var club_name := Label3D.new()
	club_name.name = "ActiveClubName"
	club_name.text = str(club.get("name", ""))
	club_name.font = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
	club_name.font_size = 45
	club_name.pixel_size = .006
	club_name.modulate = contrast_color
	club_name.position = Vector3(0, 4.78, -5.1)
	club_name.outline_size = 0
	add_child(club_name)

func _crest(position_: Vector3, width: float) -> void:
	if crest_texture == null: return
	var panel := MeshInstance3D.new()
	panel.name = "ActiveClubCrest"
	var quad := QuadMesh.new()
	var ratio := float(crest_texture.get_height()) / maxf(1, crest_texture.get_width())
	quad.size = Vector2(width / maxf(1, ratio), width * minf(1, ratio))
	panel.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = crest_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel.material_override = material
	panel.position = position_
	add_child(panel)

func _build_seating() -> void:
	for row in 3:
		for col in 5:
			_asset(CHAIR, "AudienceChair", Vector3(-3.4 + col * 1.65, 0, -.2 + row * 1.65), 1.15, PI)
	# Generic equipment, without labels or implied real press identities.
	for x in [-4.8, 4.8]:
		var camera := _box("PressCamera", Vector3(x, 1.75, 2.25), Vector3(.35, .26, .55), _metal)
		camera.rotation_degrees.y = -8 if x > 0 else 8
		_cylinder("CameraStand", Vector3(x, .92, 2.25), .035, 1.6, _metal)
		for offset in [Vector3(.34, 0, .2), Vector3(-.34, 0, .2), Vector3(0, 0, -.35)]:
			var foot := _cylinder("TripodLeg", Vector3(x, .22, 2.25) + offset * .5, .025, .65, _metal)
			foot.look_at(Vector3(x, .55, 2.25), Vector3.FORWARD)

func _asset(scene: PackedScene, id: String, position_: Vector3, height_: float, rotation_: float) -> void:
	var holder := Node3D.new()
	holder.name = id
	add_child(holder)
	var node := scene.instantiate() as Node3D
	holder.add_child(node)
	var bounds := _bounds(node)
	var factor := height_ / maxf(bounds.size.y, .01)
	node.scale *= factor
	node.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	holder.position = position_
	holder.rotation.y = rotation_

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	if node is MeshInstance3D:
		result = node.global_transform * node.get_aabb()
		found = true
	for child in node.get_children():
		if child is Node3D:
			var bounds := _bounds(child)
			if bounds.size != Vector3.ZERO:
				result = result.merge(bounds) if found else bounds
				found = true
	return result

func _setup_lighting() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("17231d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9c2b3")
	settings.ambient_light_energy = .65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -23, 0)
	light.light_color = Color("f6e8c5")
	light.light_energy = 1.05
	light.shadow_enabled = true
	add_child(light)
	var key := OmniLight3D.new()
	key.position = Vector3(-1, 4.4, -2.4)
	key.omni_range = 10
	key.light_energy = 1.2
	key.light_color = Color("f6dfb1")
	add_child(key)
	var camera := Camera3D.new()
	camera.name = "PressRoomCamera"
	camera.position = Vector3(-4.2, 2.5, 5.8)
	camera.fov = 59
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(-.8, 1.9, -3.8))
