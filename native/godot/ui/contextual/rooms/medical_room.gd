extends Node3D

const Identity = preload("res://ui/contextual/rooms/room_identity.gd")
var club: Dictionary = {}
var crest_texture: Texture2D
var primary := Color("596368")
var contrast := Color("e8e5dc")

func configure(identity: Dictionary, texture: Texture2D) -> void:
	club = identity.duplicate(true)
	primary = Identity.primary(identity)
	contrast = Identity.contrast(primary)
	crest_texture = texture

func _mat(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78 if metal == 0.0 else 0.35
	material.metallic = metal
	return material

func _box(label: String, at: Vector3, size_: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size_
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node

func _crest(at: Vector3, height: float, rotation_: Vector3 = Vector3.ZERO) -> void:
	if crest_texture == null: return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(height * float(crest_texture.get_width()) / maxf(1.0, crest_texture.get_height()), height)
	var node := MeshInstance3D.new()
	node.name = "ManagedClubCrest"
	node.mesh = mesh
	node.position = at
	node.rotation = rotation_
	var material := _mat(Color.WHITE)
	material.albedo_texture = crest_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _ready() -> void:
	var plaster := _mat(Color("d7ded7"))
	var tile := _mat(Color("929f98"))
	var oak := _mat(Color("a0825c"))
	var dark := _mat(Color("293a3d"))
	var steel := _mat(Color("7d9295"), 0.6)
	var club_material := _mat(primary)
	var linen := _mat(Color("e6e3d7"))
	_box("Room floor", Vector3(0,-0.12,0), Vector3(10.8,0.20,9.6), tile)
	for x in range(-5, 6):
		_box("Floor joint", Vector3(x,0,0), Vector3(0.012,0.008,9.5), _mat(Color("6e817c")))
	for z in range(-4, 5):
		_box("Floor joint", Vector3(0,0,z), Vector3(10.6,0.008,0.012), _mat(Color("6e817c")))
	_box("Back plaster", Vector3(0,1.8,-4.7), Vector3(10.8,3.6,0.18), plaster)
	_box("Left plaster", Vector3(-5.3,1.8,0), Vector3(0.18,3.6,9.5), plaster)
	_box("Right plaster", Vector3(5.3,1.8,0), Vector3(0.18,3.6,9.5), plaster)
	_box("Club wall protection", Vector3(0,0.6,-4.58), Vector3(10.6,1.2,0.06), club_material)
	_box("Oak dado", Vector3(0,1.22,-4.51), Vector3(10.6,0.055,0.08), oak)
	_box("Window frame", Vector3(-2.6,2.4,-4.55), Vector3(3.8,1.7,0.13), dark)
	var sky := _mat(Color("afc4c3"))
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box("Window daylight", Vector3(-2.6,2.4,-4.46), Vector3(3.55,1.48,0.025), sky)
	_box("Distant trees", Vector3(-2.6,1.83,-4.43), Vector3(3.55,0.33,0.03), _mat(Color("687e66")))
	for x in [-4.4, -2.6, -0.8]: _box("Window mullion", Vector3(x,2.4,-4.39), Vector3(0.055,1.65,0.13), linen)
	_box("Club wall panel", Vector3(2.7,2.35,-4.53), Vector3(2.15,1.85,0.07), club_material)
	_crest(Vector3(2.7,2.35,-4.47), 1.35)
	# Empty adjustable treatment couch: a setting, never a diagnosis or patient.
	_box("Treatment couch base", Vector3(0.4,0.48,-0.9), Vector3(1.45,0.16,2.65), steel)
	for x in [-0.1,0.9]:
		for z in [-1.75, -0.05]: _box("Couch legs", Vector3(x,0.33,z), Vector3(0.10,0.65,0.10), steel)
	_box("Treatment couch pad", Vector3(0.4,0.91,-0.55), Vector3(1.45,0.23,1.82), club_material)
	var head := _box("Raised couch head", Vector3(0.4,1.05,-1.82), Vector3(1.45,0.21,0.75), club_material)
	head.rotation_degrees.x = -16
	_box("Clean couch towel", Vector3(0.4,1.155,-1.73), Vector3(1.16,0.035,0.48), linen)
	# Storage, a small review desk, privacy curtain and rehabilitation equipment.
	_box("Medical cabinet", Vector3(3.8,0.76,-3.5), Vector3(2.1,1.45,0.75), linen)
	_box("Cabinet oak top", Vector3(3.8,1.52,-3.5), Vector3(2.18,0.09,0.82), oak)
	for x in [3.3,4.3]:
		_box("Cabinet door", Vector3(x,0.77,-3.10), Vector3(0.95,1.30,0.035), plaster)
		_box("Cabinet handle", Vector3(x+0.25,0.95,-3.06), Vector3(0.04,0.24,0.04), steel)
	_box("Review desk", Vector3(-2.8,1.04,-2.65), Vector3(2.1,0.12,0.95), oak)
	for x in [-3.65,-1.95]: _box("Desk legs", Vector3(x,0.50,-2.65), Vector3(0.09,1.0,0.78), dark)
	_box("Closed dossier", Vector3(-2.75,1.12,-2.57), Vector3(0.57,0.035,0.76), club_material)
	_crest(Vector3(-2.75,1.143,-2.57),0.32,Vector3(-PI/2,0,0))
	for z in range(9):
		_box("Privacy curtain fold", Vector3(2.35+sin(z*PI/2)*0.045,1.85,-2.5+z*0.38), Vector3(0.055,2.4,0.39), _mat(Color("c5d1c8")))
	_box("Curtain rail", Vector3(2.35,3.15,-1.05), Vector3(0.06,0.06,3.55), steel)
	_box("Rehabilitation step", Vector3(-2.0,0.13,1.4), Vector3(1.15,0.26,0.75), club_material)
	_box("Recovery mat", Vector3(-1.5,0.025,2.5), Vector3(2.5,0.04,1.15), dark)
	for x in [-0.3,0.3]:
		_box("Cart upright", Vector3(3.7+x,0.55,1.45), Vector3(0.045,1.0,0.045), steel)
	for y in [0.28,0.85]: _box("Equipment cart shelf", Vector3(3.7,y,1.45), Vector3(0.8,0.055,0.65), linen)
	_box("Folded clean towels", Vector3(3.7,0.94,1.45), Vector3(0.54,0.14,0.45), linen)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("273c3d")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("c5d2cd")
	world.ambient_light_energy = 0.63
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-25,0)
	sun.light_color = Color("f4e8ca")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5,3.0,1.0)
	fill.light_color = Color("e5eee7")
	fill.light_energy = 0.55
	fill.omni_range = 10
	add_child(fill)
	var camera := Camera3D.new()
	camera.position = Vector3(3.4,2.4,5.8)
	camera.fov = 65
	add_child(camera)
	camera.look_at(Vector3(-0.3,1.25,-1.45))
	camera.current = true
