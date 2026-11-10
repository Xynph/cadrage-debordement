extends Node3D
# Original procedural furniture and architecture; no external asset dependency.
const Identity = preload("res://ui/contextual/rooms/room_identity.gd")
var club: Dictionary = {}
var crest_texture: Texture2D = null
var primary := _material(Color("596368"))
var trim := _material(Color("e8e5dc"))
var oak := _material(Color("806347"))
var oak_dark := _material(Color("3f3730"))
var plaster := _material(Color("d8d7cc"))
var graphite := _material(Color("222e30"))
var paper := _material(Color("eee9db"))
var brass := _material(Color("b5a17b"),0.55)

func configure(identity: Dictionary, texture: Texture2D) -> void:
	club=identity.duplicate(true)
	primary.albedo_color=Identity.primary(identity)
	trim.albedo_color=Identity.contrast(primary.albedo_color)
	crest_texture=texture
	set_meta("identity",club.duplicate(true))
	set_meta("primary_color",primary.albedo_color)
	set_meta("contrast_color",trim.albedo_color)
	set_meta("crest_texture",texture)

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color;result.roughness=0.72;result.metallic=metallic
	return result

func _box(label: String, pos: Vector3, dimensions: Vector3, surface: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.name=label
	var mesh := BoxMesh.new();mesh.size=dimensions
	node.mesh=mesh;node.material_override=surface;node.position=pos;parent.add_child(node)
	return node

func _cylinder(label: String, pos: Vector3, radius: float, height: float, surface: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.name=label
	var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=24
	node.mesh=mesh;node.material_override=surface;node.position=pos;parent.add_child(node)
	return node

func _crest(label: String, pos: Vector3, width: float, rotation: Vector3 = Vector3.ZERO) -> void:
	if crest_texture==null:return
	var node := MeshInstance3D.new();node.name=label
	var mesh := QuadMesh.new();mesh.size=Vector2(width,width*float(crest_texture.get_height())/maxf(1.0,float(crest_texture.get_width())))
	var surface := _material(Color.WHITE)
	surface.albedo_texture=crest_texture;surface.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;surface.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.mesh=mesh;node.material_override=surface;node.position=pos;node.rotation=rotation
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)

func _ready() -> void:
	_architecture();_meeting_table();_storage();_lighting()

func _architecture() -> void:
	_box("Foundation",Vector3(0,-0.15,0),Vector3(10.8,0.3,10.2),oak_dark)
	for index in range(23):
		var color := Color("8b7863").lightened(float(index%4)*0.025)
		_box("Floor plank",Vector3(-5.1+index*0.46,0.015,0),Vector3(0.444,0.035,9.9),_material(color))
	_box("Conference rug",Vector3(0,0.043,0),Vector3(5.1,0.035,6.3),_material(Color("686f6b")))
	_box("Back wall",Vector3(0,2.25,-5),Vector3(10.7,4.5,0.2),plaster)
	_box("Back timber skirting",Vector3(0,0.22,-4.87),Vector3(10.5,0.38,0.06),oak_dark)
	_box("Right wall",Vector3(5.3,2.25,0),Vector3(0.18,4.5,10),plaster)
	for index in range(17):
		_box("Acoustic timber slat",Vector3(4.95,2.15,-4.7+index*0.27),Vector3(0.13,3.85,0.075),oak)
	# A glazed side opens onto a generic outdoor training landscape, not a named venue.
	_box("Distant landscape",Vector3(-8.2,1.9,-1),Vector3(0.1,4.3,10),_material(Color("aebfbb")))
	_box("Outdoor grass",Vector3(-7.0,0.1,-1),Vector3(3.5,0.08,11),_material(Color("536c4d")))
	for z in [-4.6,-1.5,1.6,4.7]:
		_box("Window mullion",Vector3(-5.2,2.15,z),Vector3(0.12,4.25,0.10),graphite)
	for height in [0.18,4.16]:
		_box("Window sill",Vector3(-5.2,height,0),Vector3(0.25,0.13,9.5),graphite)
	_box("Club wall panel",Vector3(1.7,2.66,-4.84),Vector3(2.75,2.67,0.08),primary)
	_crest("Actual club crest on boardroom wall",Vector3(1.7,2.93,-4.77),1.14)
	var title := Label3D.new();title.name="ActualClubName";title.text=str(club.get("name","")).to_upper()
	title.font=preload("res://fonts/BarlowCondensed-SemiBold.ttf");title.font_size=36;title.pixel_size=0.0023
	title.modulate=trim.albedo_color;title.position=Vector3(1.7,1.73,-4.75);title.outline_size=0
	add_child(title)
	_box("Unmarked presentation screen frame",Vector3(-1.85,2.85,-4.83),Vector3(3.1,1.82,0.1),graphite)
	_box("Unmarked presentation screen",Vector3(-1.85,2.85,-4.76),Vector3(2.93,1.65,0.02),_material(Color("34484a")))
	# Numbers and meeting claims belong exclusively to the real projected UI.
	_crest("Club crest on presentation screen",Vector3(-1.85,2.85,-4.73),0.78)

func _meeting_table() -> void:
	_box("Boardroom table edge",Vector3(0,1.02,-0.2),Vector3(2.46,0.17,5.9),oak_dark)
	_box("Boardroom oak tabletop",Vector3(0,1.12,-0.2),Vector3(2.43,0.075,5.86),oak)
	for x in [-0.8,0.8]:
		for z in [-2.3,1.9]:_box("Table support",Vector3(x,0.54,z),Vector3(0.12,1,0.13),graphite)
	_box("Table cable channel",Vector3(0,1.164,-0.2),Vector3(0.12,0.008,3.7),graphite)
	for side in [-1,1]:
		for z in [-2.05,-0.2,1.65]:
			_chair(Vector3(side*1.78,0,z),PI/2 if side==1 else -PI/2)
			var x: float=side*0.72
			_box("Blank meeting paper",Vector3(x,1.17,z),Vector3(0.49,0.012,0.64),paper)
			_box("Club document folder",Vector3(x,1.185,z+0.06),Vector3(0.48,0.019,0.54),primary)
			_crest("Actual crest on meeting folder",Vector3(x,1.20,z+0.06),0.19,Vector3(-PI/2,0,0))
			_box("Pen",Vector3(side*1.02,1.179,z),Vector3(0.025,0.022,0.31),brass)
			_cylinder("Water glass",Vector3(side*0.78,1.28,z-0.55),0.055,0.23,_material(Color("b8c7c4")))
	_chair(Vector3(0,0,-3.85),PI)
	_cylinder("Water carafe",Vector3(0.25,1.37,-1.1),0.095,0.43,_material(Color("b8c7c4")))
	_cylinder("Carafe lid",Vector3(0.25,1.6,-1.1),0.075,0.035,brass)

func _chair(pos: Vector3, rotation: float) -> void:
	var chair := Node3D.new();chair.name="BoardroomChair";chair.position=pos;chair.rotation.y=rotation;add_child(chair)
	_box("Upholstered seat",Vector3(0,0.59,0),Vector3(0.71,0.14,0.70),primary,chair)
	_box("Upholstered back",Vector3(0,1.05,0.31),Vector3(0.71,0.88,0.13),primary,chair)
	_cylinder("Chair pedestal",Vector3(0,0.29,0),0.055,0.55,graphite,chair)
	for angle in [0.0,PI/2]:
		var leg := _box("Chair base",Vector3(0,0.08,0),Vector3(0.69,0.07,0.08),graphite,chair);leg.rotation.y=angle
	for side in [-1,1]:_box("Armrest",Vector3(side*0.43,0.88,0.0),Vector3(0.065,0.10,0.60),oak_dark,chair)

func _storage() -> void:
	_box("Credenza cabinet",Vector3(4.45,0.57,2.4),Vector3(1.25,1.1,3.5),oak_dark)
	_box("Credenza top",Vector3(4.45,1.15,2.4),Vector3(1.35,0.09,3.6),oak)
	for z in [1.2,2.35,3.5]:
		_box("Cabinet door",Vector3(3.79,0.59,z),Vector3(0.035,0.94,1.06),oak)
		_box("Cabinet handle",Vector3(3.74,0.82,z),Vector3(0.05,0.03,0.23),brass)
	for index in range(5):_box("Unmarked archive binder",Vector3(4.45,1.44,1.1+index*0.17),Vector3(0.43,0.49,0.13),primary if index%2==0 else paper)
	_cylinder("Planter",Vector3(-4.35,0.46,-4.1),0.38,0.88,graphite)
	_cylinder("Plant stem",Vector3(-4.35,1.42,-4.1),0.035,1.52,oak_dark)
	for index in range(9):
		var angle := index*2.4
		var leaf := _box("Broad plant leaf",Vector3(-4.35+cos(angle)*0.3,1.55+index*0.075,-4.1+sin(angle)*0.3),Vector3(0.61,0.045,0.21),_material(Color("52734d")))
		leaf.rotation=Vector3(0.24,angle,-0.2)

func _lighting() -> void:
	var world := WorldEnvironment.new();var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("8a9d9e")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("d6dacf");environment.ambient_light_energy=0.68
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.environment=environment;add_child(world)
	var daylight := DirectionalLight3D.new();daylight.rotation_degrees=Vector3(-36,-52,0);daylight.light_color=Color("fff0d6");daylight.light_energy=1.05;daylight.shadow_enabled=true;add_child(daylight)
	for z in [-1.65,1.25]:
		_box("Pendant fitting",Vector3(0,3.35,z),Vector3(1.72,0.10,0.17),graphite)
		for x in [-0.65,0.65]:_cylinder("Pendant cable",Vector3(x,3.77,z),0.008,0.8,graphite)
		var light := OmniLight3D.new();light.position=Vector3(0,3.08,z);light.light_color=Color("ffe8bf");light.light_energy=0.58;light.omni_range=6.5;add_child(light)
	var camera := Camera3D.new();camera.name="BoardroomCamera";camera.position=Vector3(7.8,5.7,9.8)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11.7;add_child(camera);camera.look_at(Vector3(0,1.2,-0.9));camera.current=true
