extends Node3D

const RoomIdentity = preload("res://ui/contextual/rooms/room_identity.gd")

var green: StandardMaterial3D
var deep_green: StandardMaterial3D
var wood: StandardMaterial3D
var wood_light: StandardMaterial3D
var gold: StandardMaterial3D
var ivory: StandardMaterial3D
var metal: StandardMaterial3D
var rubber: StandardMaterial3D
var primary_color := Color("596368")
var contrast_color := Color("e8e5dc")
var club_name := ""
var kit_material: StandardMaterial3D
var kit_trim: StandardMaterial3D
var crest_texture: Texture2D

func configure(identity: Dictionary, texture: Texture2D) -> void:
	club_name = str(identity.get("name", ""))
	primary_color = RoomIdentity.primary(identity)
	# Contrast is a neutral presentation accent, not an authentic second kit color.
	contrast_color = RoomIdentity.contrast(primary_color)
	crest_texture = texture
	set_meta("identity", identity.duplicate(true))
	set_meta("primary_color", primary_color)
	set_meta("contrast_color", contrast_color)
	set_meta("crest_texture", texture)

func _ready() -> void:
	green = mat(Color("484c44"))
	kit_material = mat(primary_color)
	kit_trim = mat(contrast_color)
	deep_green = mat(Color("242d29"))
	wood = mat(Color("594431"))
	wood_light = mat(Color("af875c"))
	gold = mat(Color("c8ab68"),0.36,0.6)
	ivory = mat(Color("bcb9a7"))
	metal = mat(Color("202726"),0.35,0.65)
	rubber = mat(Color("121b19"))
	setup_world()
	build_room()
	build_lockers()
	build_benches()
	build_board()
	build_props()
	build_kenney_props()
	build_immersive_room_details()

func mat(color: Color, roughness := 0.65, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func box(name_: String, pos: Vector3, size_: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name_
	var b := BoxMesh.new()
	b.size = size_
	mesh.mesh = b
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func cylinder(name_: String, pos: Vector3, radius: float, height_: float, material: Material, parent: Node = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height_
	c.radial_segments = 24
	node.mesh = c
	node.material_override = material
	parent.add_child(node)
	node.position = pos
	return node

func line3(a: Vector3, b: Vector3, radius: float, material: Material, parent: Node = self) -> void:
	var line := cylinder("detail", (a+b)*0.5, radius, a.distance_to(b), material, parent)
	line.quaternion = Quaternion(Vector3.UP, (b-a).normalized())

func label3(text_: String, pos: Vector3, size_: int, color_: Color, parent: Node = self) -> Label3D:
	var l := Label3D.new()
	l.font = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
	l.text = text_
	l.font_size = size_
	l.pixel_size = 0.0038
	l.modulate = color_
	l.outline_size = 0
	l.no_depth_test = false
	parent.add_child(l)
	l.position = pos
	return l

func setup_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("17221f")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9fb1a6")
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(3.6,1.9,4.4)
	camera.look_at(Vector3(-1.7,1.6,-8.0))
	camera.fov = 58.0
	camera.current = true
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-50,-35,0)
	sun.light_color = Color("ffe6bd")
	sun.light_energy = 0.28
	sun.shadow_enabled = false
	for x in [-5.5,0.0,5.5]:
		var light := OmniLight3D.new()
		add_child(light)
		light.position = Vector3(x,3.3,-4.9)
		light.omni_range = 7.0
		light.light_color = Color("ffe0aa")
		light.light_energy = 0.45
		light.shadow_enabled = true

func build_room() -> void:
	box("Foundation",Vector3(0,-0.22,0),Vector3(18.8,0.4,18.8),deep_green)
	var floor_mat := mat(Color("626358"),0.95)
	for x in range(19):
		for z in range(19):
			box("Stone tile",Vector3(-9.0+x,0.002,-9.0+z),Vector3(0.986,0.035,0.986),floor_mat)
	box("Back wall",Vector3(0,1.9,-9.3),Vector3(18.8,3.8,0.2),deep_green)
	box("Side wall",Vector3(-9.3,1.9,0),Vector3(0.2,3.8,18.8),deep_green)
	for x in range(47):
		box("Wall timber bead",Vector3(-9.0+x*0.4,1.8,-9.16),Vector3(0.025,3.5,0.04),wood)
	for z in range(47):
		box("Wall timber bead",Vector3(-9.15,1.8,-9.0+z*0.4),Vector3(0.04,3.5,0.025),wood)
	box("Back brass rail",Vector3(0,3.50,-9.11),Vector3(18.3,0.027,0.025),gold)
	box("Upper timber beam",Vector3(0,3.79,-9.0),Vector3(18.8,0.20,0.65),wood)
	box("Side upper beam",Vector3(-9.1,3.79,0),Vector3(0.4,0.2,18.8),wood)
	var emissive := mat(Color("c2ad86"))
	emissive.emission_enabled = true
	emissive.emission = Color("d1b993")
	emissive.emission_energy_multiplier = 0.5
	box("Continuous warm strip",Vector3(0,3.55,-8.70),Vector3(18.2,0.035,0.035),emissive)
	box("Side warm strip",Vector3(-8.85,3.55,0),Vector3(0.035,0.035,18.1),emissive)
	# A generous empty center can gather the entire 23-player match group.
	box("Team briefing mat",Vector3(0,0.034,0.2),Vector3(6.8,0.035,6.3),mat(primary_color.darkened(0.23)))
	box("Mat border",Vector3(0,0.055,0.2),Vector3(6.6,0.01,6.1),kit_trim)
	box("Mat center",Vector3(0,0.064,0.2),Vector3(6.52,0.01,6.02),kit_material)
	var crest := crest_badge(Vector3(0,0.082,-1.0),Vector2(2.6,3.05))
	if crest:
		crest.rotation_degrees.x = -90
	var motto := label3(club_name.to_upper(),Vector3(0,0.083,2.10),40,contrast_color)
	motto.rotation_degrees.x = -90

func jersey(parent: Node3D, number: int, color_: Material) -> void:
	# Tailored shirt silhouette, with short sleeves and layered collar.
	var mesh := MeshInstance3D.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var v := PackedVector3Array()
	var indexes := PackedInt32Array()
	var points := [Vector2(-0.29,0.0),Vector2(0.29,0),Vector2(0.27,0.63),Vector2(0.48,0.48),Vector2(0.60,0.70),Vector2(0.28,0.93),Vector2(0.12,0.97),Vector2(-0.12,0.97),Vector2(-0.28,0.93),Vector2(-0.60,0.70),Vector2(-0.48,0.48),Vector2(-0.27,0.63)]
	for p in points:
		v.append(Vector3(p.x,p.y,0.0))
	var triangles := Geometry2D.triangulate_polygon(PackedVector2Array(points))
	for i in triangles:
		indexes.append(i)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = indexes
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	mesh.mesh = am
	var shirt_mat: StandardMaterial3D = color_.duplicate()
	shirt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = shirt_mat
	parent.add_child(mesh)
	box("Shirt side thickness",Vector3(0,0.37,-0.025),Vector3(0.53,0.7,0.055),color_,parent)
	box("Shoulder stripe",Vector3(0,0.85,0.012),Vector3(0.62,0.05,0.018),kit_trim,parent)
	box("Jersey hem",Vector3(0,0.035,0.015),Vector3(0.57,0.04,0.02),kit_trim,parent)
	label3(str(number),Vector3(0,0.48,0.025),104,contrast_color,parent)
	crest_badge(Vector3(-0.14,0.74,0.032),Vector2(0.16,0.188),parent)
	line3(Vector3(-0.14,1.02,-0.02),Vector3(0,1.10,-0.02),0.012,metal,parent)
	line3(Vector3(0,1.10,-0.02),Vector3(0.14,1.02,-0.02),0.012,metal,parent)

func build_lockers() -> void:
	for i in range(23):
		var bay := Node3D.new()
		bay.name = "Locker%02d" % (i+1)
		add_child(bay)
		if i < 11:
			bay.position = Vector3(-7.1+i*1.21,0,-8.68)
		else:
			bay.position = Vector3(-8.68,0,-7.1+(i-11)*1.21)
			bay.rotation_degrees.y = 90
		box("Locker wood back",Vector3(0,1.72,-0.22),Vector3(1.15,3.04,0.15),wood,bay)
		for side in [-0.59,0.59]:
			box("Locker frame",Vector3(side,1.7,0.1),Vector3(0.07,3.18,0.75),green,bay)
		box("Locker top",Vector3(0,3.25,0.12),Vector3(1.25,0.12,0.80),green,bay)
		box("Locker upper shelf",Vector3(0,2.75,0.12),Vector3(1.15,0.07,0.75),wood_light,bay)
		box("Locker boot shelf",Vector3(0,0.58,0.12),Vector3(1.15,0.09,0.75),wood_light,bay)
		box("Locker kickplate",Vector3(0,0.26,0.31),Vector3(1.15,0.45,0.3),green,bay)
		box("Locker numberplate",Vector3(0,3.10,0.535),Vector3(1.04,0.22,0.035),kit_material,bay)
		label3("%02d" % (i+1),Vector3(0,3.10,0.56),30,contrast_color,bay)
		line3(Vector3(-0.51,2.59,0.05),Vector3(0.51,2.59,0.05),0.018,metal,bay)
		var shirt := Node3D.new()
		bay.add_child(shirt)
		shirt.position = Vector3(0,1.35,0.16)
		shirt.scale = Vector3(0.9,0.9,0.9)
		jersey(shirt,i+1,kit_material)
		box("Folded towel",Vector3(-0.16,2.84,0.16),Vector3(0.6,0.11,0.43),ivory,bay)
		box("Folded towel",Vector3(-0.16,2.94,0.16),Vector3(0.57,0.08,0.4),ivory,bay)
		for boot_x in [-0.18,0.15]:
			box("Boot",Vector3(boot_x,0.71,0.23),Vector3(0.21,0.19,0.48),rubber,bay)
			box("Boot sole",Vector3(boot_x,0.63,0.27),Vector3(0.23,0.035,0.52),ivory,bay)

func bench(pos: Vector3, length_: float, angle: float = 0.0) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation_degrees.y = angle
	for z in [-0.23,0.0,0.23]:
		box("Bench oak slat",Vector3(0,0.51,z),Vector3(length_,0.12,0.20),wood_light,root)
	for x in [-length_*0.38,length_*0.38]:
		for z in [-0.19,0.19]:
			box("Bench metal legs",Vector3(x,0.25,z),Vector3(0.08,0.5,0.08),metal,root)
		box("Bench brace",Vector3(x,0.28,0),Vector3(0.08,0.06,0.55),metal,root)
	return root

func build_benches() -> void:
	bench(Vector3(-1.0,0,-7.18),13.2)
	bench(Vector3(-7.18,0,-0.5),14.4,90)
	bench(Vector3(1.6,0,6.8),7.0)
	box("Bench towel",Vector3(2.9,0.60,6.82),Vector3(0.64,0.035,0.75),ivory)
	box("Towel drape",Vector3(2.9,0.40,7.19),Vector3(0.64,0.39,0.025),ivory)
	for x in [2.66,3.14]:
		box("Towel stripe",Vector3(x,0.425,7.21),Vector3(0.025,0.34,0.012),kit_material)

func build_board() -> void:
	var board := Node3D.new()
	add_child(board)
	board.position = Vector3(6.9,2.0,-8.94)
	box("Tactics timber frame",Vector3.ZERO,Vector3(3.2,2.3,0.13),wood_light,board)
	box("Tactics board",Vector3(0,0,0.08),Vector3(3.02,2.12,0.04),mat(Color("283c34")),board)
	label3("SORTIE DE RUCK",Vector3(0,0.88,0.12),39,Color("d0c5a7"),board)
	var chalk := mat(Color("aeb9a3"))
	var red := mat(Color("aa6657"))
	# Cropped zone of a rugby pitch. Attack moves upward; passes stay backward.
	for x in [-1.32,1.32]:
		line3(Vector3(x,-0.76,0.12),Vector3(x,0.62,0.12),0.007,chalk,board)
	for x in [-0.93,0.93]:
		for y in [-0.68,-0.38,-0.08,0.22,0.52]:
			line3(Vector3(x,y,0.12),Vector3(x,y+0.12,0.12),0.005,chalk,board)
	# 22-metre reference and defending offside line at the hindmost foot.
	line3(Vector3(-1.32,0.55,0.12),Vector3(1.32,0.55,0.12),0.007,chalk,board)
	label3("22",Vector3(1.15,0.66,0.13),17,Color("b9c4ad"),board)
	for x in [-1.15,-0.82,-0.4,0.0,0.42,0.85,1.15]:
		line3(Vector3(x,0.27,0.13),Vector3(x+0.14,0.27,0.13),0.006,red,board)
	label3("HORS-JEU",Vector3(0.79,0.18,0.13),15,Color("c28e7e"),board)
	# Ruck: opposing bound forwards above a grounded ball, schematic contact.
	for pos in [Vector3(-0.73,-0.02,0.15),Vector3(-0.55,-0.02,0.15)]:
		box("Ruck attacking support",pos,Vector3(0.14,0.22,0.035),kit_material,board)
	for pos in [Vector3(-0.73,0.17,0.15),Vector3(-0.55,0.17,0.15)]:
		box("Ruck defender",pos,Vector3(0.14,0.18,0.035),red,board)
	var ball_marker := cylinder("Ball on ground",Vector3(-0.64,-0.11,0.18),0.035,0.025,ivory,board)
	ball_marker.rotation_degrees.x = 90
	# 9 waits behind the attacking hindmost foot; 10 and 12 lie deeper.
	var attack := [[9,Vector2(-0.58,-0.27)],[10,Vector2(0.03,-0.43)],[12,Vector2(0.69,-0.60)],[13,Vector2(1.15,-0.71)]]
	for item in attack:
		var p: Vector2 = item[1]
		var token := cylinder("Attacker "+str(item[0]),Vector3(p.x,p.y,0.15),0.09,0.025,kit_trim,board)
		token.rotation_degrees.x = 90
		label3(str(item[0]),Vector3(p.x,p.y,0.18),20,primary_color,board)
	for pos in [Vector2(-1.12,0.42),Vector2(-0.18,0.42),Vector2(0.38,0.43),Vector2(0.96,0.44)]:
		var token := cylinder("Defender",Vector3(pos.x,pos.y,0.15),0.067,0.025,red,board)
		token.rotation_degrees.x = 90
	for pair in [[Vector2(-0.46,-0.29),Vector2(-0.1,-0.4)],[Vector2(0.15,-0.45),Vector2(0.55,-0.57)]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		line3(Vector3(a.x,a.y,0.18),Vector3(b.x,b.y,0.18),0.011,chalk,board)
		line3(Vector3(b.x,b.y,0.18),Vector3(b.x-0.10,b.y+0.08,0.18),0.010,chalk,board)
	label3("9 → 10 → 12  ·  PASSES VERS L'ARRIÈRE",Vector3(0,-0.96,0.13),19,Color("c8b882"),board)
	box("Tactics low cabinet",Vector3(6.9,0.47,-8.7),Vector3(3.1,0.88,0.85),green)
	for x in [6.13,7.67]:
		box("Cabinet door",Vector3(x,0.49,-8.26),Vector3(1.40,0.73,0.04),deep_green)

func rugby_ball(pos: Vector3, scale_: float = 1.0) -> void:
	var ball := Node3D.new()
	add_child(ball)
	ball.position = pos
	ball.rotation_degrees = Vector3(0,-25,15)
	ball.scale *= scale_
	var sphere := SphereMesh.new()
	sphere.radius = 0.23
	sphere.height = 0.46
	var m := MeshInstance3D.new()
	ball.add_child(m)
	m.mesh = sphere
	m.scale = Vector3(1.65,1,1)
	m.material_override = ivory
	# Painted longitudinal panels following the oval.
	for side in [-1,1]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.175
		ring.outer_radius = 0.207
		var panel := MeshInstance3D.new()
		ball.add_child(panel)
		panel.mesh = ring
		panel.material_override = green
		panel.position.x = side*0.21
		panel.rotation_degrees.z = 90
		panel.scale.y = 0.6
	for i in range(6):
		line3(Vector3(-0.10+i*0.04,0.217,-0.045),Vector3(-0.10+i*0.04,0.217,0.045),0.008,metal,ball)

func bag(pos: Vector3, rot := 0.0) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation_degrees.y = rot
	box("Kit bag body",Vector3(0,0.25,0),Vector3(0.95,0.44,0.48),kit_material,root)
	box("Kit bag top",Vector3(0,0.49,0),Vector3(0.85,0.10,0.43),kit_material,root)
	for x in [-0.28,0.28]:
		box("Bag webbing",Vector3(x,0.27,0.247),Vector3(0.055,0.4,0.025),gold,root)
		line3(Vector3(x,0.51,-0.1),Vector3(x,0.70,0),0.018,metal,root)
		line3(Vector3(x,0.70,0),Vector3(x,0.51,0.1),0.018,metal,root)
	crest_badge(Vector3(0,0.27,0.266),Vector2(0.28,0.328),root)

func build_props() -> void:
	rugby_ball(Vector3(0.3,0.83,6.8))
	rugby_ball(Vector3(7.3,1.15,-8.6),0.9)
	bag(Vector3(-3.7,0.03,-6.6),-12)
	bag(Vector3(4.5,0.02,6.4),-20)
	bag(Vector3(-6.6,0.02,4.1),25)
	# Water bottle carrier on the back bench.
	box("Bottle carrier",Vector3(-1.5,0.70,-7.18),Vector3(0.85,0.24,0.5),rubber)
	for x in [-1.75,-1.48,-1.21]:
		for z in [-7.3,-7.05]:
			cylinder("Sports bottle",Vector3(x,0.94,z),0.075,0.35,green)
			cylinder("Bottle cap",Vector3(x,1.13,z),0.045,0.055,gold)
	line3(Vector3(-1.9,0.74,-7.18),Vector3(-1.9,1.20,-7.18),0.02,metal)
	line3(Vector3(-1.9,1.20,-7.18),Vector3(-1.0,1.20,-7.18),0.02,metal)
	line3(Vector3(-1.0,1.20,-7.18),Vector3(-1.0,0.74,-7.18),0.02,metal)
	# Recovery roller and team laundry basket.
	var roller := cylinder("Recovery roller",Vector3(-6.5,0.18,5.7),0.18,0.8,rubber)
	roller.rotation_degrees.z = 90
	box("Laundry basket",Vector3(8.3,0.42,-5.7),Vector3(0.75,0.84,0.65),wood)
	for h in range(6):
		box("Basket horizontal weave",Vector3(8.3,0.10+h*0.13,-5.36),Vector3(0.76,0.04,0.03),wood_light)
	for x in range(7):
		box("Basket vertical weave",Vector3(7.98+x*0.11,0.43,-5.35),Vector3(0.025,0.77,0.025),wood_light)
	box("Laundry towels",Vector3(8.3,0.88,-5.7),Vector3(0.69,0.14,0.58),ivory)

func build_kenney_props() -> void:
	var placements := [
		["coatRackStanding",Vector3(-8.6,0.03,8.0),Vector3(1.65,1.65,1.65),0.0],
		["trashcan",Vector3(8.4,0.03,-6.6),Vector3(1.15,1.15,1.15),0.0],
		["cardboardBoxClosed",Vector3(8.1,0.03,-3.7),Vector3(1.2,1.2,1.2),-12.0],
		["cardboardBoxClosed",Vector3(8.1,0.58,-3.7),Vector3(0.85,0.85,0.85),10.0]]
	for item in placements:
		var source := load("res://ui/contextual/rooms/assets/furniture/"+item[0]+".glb") as PackedScene
		if source:
			var model := source.instantiate() as Node3D
			add_child(model)
			model.position = item[1]
			model.scale = item[2]
			model.rotation_degrees.y = item[3]

func build_immersive_room_details() -> void:
	# Interior enclosure belongs only to the eye-level background composition.
	var ceiling_mat := mat(Color("454841"),0.92)
	var ceiling := box("Interior ceiling",Vector3(0,4.04,0),Vector3(18.8,0.16,18.8),ceiling_mat)
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box("Interior right wall",Vector3(9.3,1.95,0),Vector3(0.20,3.9,18.8),deep_green)
	for z in [-6.4,-1.3,3.8]:
		box("Ceiling timber beam",Vector3(0,3.88,z),Vector3(18.5,0.18,0.18),wood)
	var warm := mat(Color("baaf8f"))
	warm.emission_enabled = true
	warm.emission = Color("c4b58f")
	warm.emission_energy_multiplier = 0.65
	for x in [-5.0,1.0,6.1]:
		for z in [-5.0,1.6]:
			box("Ceiling luminaire body",Vector3(x,3.86,z),Vector3(0.18,0.15,2.8),metal)
			box("Ceiling luminaire diffuser",Vector3(x,3.77,z),Vector3(0.14,0.025,2.7),warm)
			var fill := OmniLight3D.new()
			add_child(fill)
			fill.position = Vector3(x,3.45,z)
			fill.omni_range = 7.0
			fill.light_color = Color("ddcfac")
			fill.light_energy = 0.28
	# Club-color wall panel anchors the right edge around future UI overlays.
	box("Club wall panel",Vector3(9.17,2.1,-3.7),Vector3(0.04,2.1,3.7),kit_material)
	var sign := label3(club_name.to_upper(),Vector3(9.13,2.15,-3.7),50,contrast_color)
	sign.rotation_degrees.y = -90

func crest_badge(pos: Vector3, size_: Vector2, parent: Node = self) -> MeshInstance3D:
	if not crest_texture:
		return null
	var node := MeshInstance3D.new()
	node.name = "Managed club crest"
	var quad := QuadMesh.new()
	quad.size = size_
	node.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = crest_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	node.material_override = material
	parent.add_child(node)
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
