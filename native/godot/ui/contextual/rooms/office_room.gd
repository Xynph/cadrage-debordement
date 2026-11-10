extends Node3D

const RoomIdentity = preload("res://ui/contextual/rooms/room_identity.gd")

var oak := material("#a77847")
var oak_dark := material("#513d2b")
var club_primary := material("#596368")
var club_tint := material("#727a7e")
var presentation_accent := material("#e8e5dc")
var club_name := ""
var crest_texture: Texture2D = null
var foliage := material("#536b43")
var ivory := material("#e8e1cb")
var brass := material("#bd9857", 0.65)
var black := material("#18231f", 0.45)
var paper := material("#f3ead3")
var glass := material("#9dbdb4", 0.25)
var rng := RandomNumberGenerator.new()

func configure(identity: Dictionary, texture: Texture2D) -> void:
	club_name = str(identity.get("name", ""))
	club_primary.albedo_color = RoomIdentity.primary(identity)
	club_tint.albedo_color = club_primary.albedo_color.lightened(0.17)
	# A neutral contrast accent is derived for presentation, not a club secondary color.
	presentation_accent.albedo_color = RoomIdentity.contrast(club_primary.albedo_color)
	crest_texture = texture
	set_meta("identity", identity.duplicate(true))
	set_meta("primary_color", club_primary.albedo_color)
	set_meta("contrast_color", presentation_accent.albedo_color)
	set_meta("crest_texture", texture)

func _ready() -> void:
	rng.seed = 22
	build_room()
	build_window_view()
	build_board()
	build_desk()
	build_shelves()
	build_details()
	asset("kitchenCoffeeMachine", Vector3(1.35,1.38,-2.93),0.63,0.0)
	asset("plantSmall1", Vector3(3.7,1.38,-2.91),0.58,0.0)
	asset("coatRackStanding", Vector3(-3.85,0.08,-2.65),2.6,0.0)
	asset("books", Vector3(-1.35,1.47,0.48),0.22,0.1)
	setup_camera()

func material(hex: String, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.65 if metal == 0.0 else 0.28
	m.metallic = metal
	return m

func box(n: String, pos: Vector3, size: Vector3, mat: Material, rot: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot
	add_child(mi)
	return mi

func cyl(n: String, pos: Vector3, r: float, h: float, mat: Material, top_r: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := CylinderMesh.new()
	mesh.top_radius = r if top_r < 0 else top_r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 32
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func sphere(n: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mi.mesh = mesh
	mi.scale = size
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func text3(s: String, p: Vector3, font_size: int, color: Color, rotation_x: float = 0) -> Label3D:
	var l := Label3D.new()
	l.font = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
	l.text = s
	l.font_size = font_size
	l.pixel_size = 0.003
	l.modulate = color
	l.position = p
	l.rotation.x = rotation_x
	l.no_depth_test = false
	l.outline_size = 0
	add_child(l)
	return l

func crest_plane(label: String, pos: Vector3, width: float, rotation: Vector3) -> void:
	if crest_texture == null:
		return
	var surface := MeshInstance3D.new()
	surface.name = label
	var quad := QuadMesh.new()
	quad.size = Vector2(width,width*float(crest_texture.get_height())/float(crest_texture.get_width()))
	surface.mesh = quad
	var logo_material := StandardMaterial3D.new()
	logo_material.albedo_texture = crest_texture
	logo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	logo_material.alpha_scissor_threshold = 0.1
	logo_material.roughness = 0.95
	logo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = logo_material
	surface.position = pos
	surface.rotation = rotation
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

func build_room() -> void:
	box("Foundation", Vector3(0,-0.22,0), Vector3(10.5,0.36,8.5), oak_dark)
	for x in range(21):
		for z in range(5):
			var shade := material(Color(0.42+rng.randf()*0.11,0.29+rng.randf()*0.06,0.18+rng.randf()*0.04).to_html())
			box("Oak parquet", Vector3(-5+x*0.5,0.0,-3.3+z*1.65), Vector3(0.48,0.08,1.63), shade)
	box("Back plaster", Vector3(0,2.2,-4.1), Vector3(10.5,4.4,0.18), ivory)
	box("Side plaster", Vector3(-5.15,2.2,0), Vector3(0.18,4.4,8.3), ivory)
	box("Back panel", Vector3(0,0.85,-3.97), Vector3(10.2,1.65,0.08), club_primary)
	box("Side panel", Vector3(-5.02,0.85,0), Vector3(0.08,1.65,8.2), club_primary)
	for x in range(13):
		box("Wall panelling", Vector3(-4.85+x*0.81,0.85,-3.9), Vector3(0.025,1.48,0.04), presentation_accent)
	for z in range(10):
		box("Wall panelling", Vector3(-4.96,0.85,-3.8+z*0.8), Vector3(0.04,1.48,0.025), presentation_accent)
	box("Back dado", Vector3(0,1.7,-3.87), Vector3(10.2,0.08,0.16), oak_dark)
	box("Side dado", Vector3(-4.9,1.7,0), Vector3(0.16,0.08,8.2), oak_dark)
	box("Back cornice", Vector3(0,4.35,-3.91), Vector3(10.3,0.14,0.25), paper)
	box("Side cornice", Vector3(-4.96,4.35,0), Vector3(0.25,0.14,8.2), paper)
	# Large inset window with dark oak frame, opening onto the training grounds.
	box("Window outer frame", Vector3(2.3,2.9,-3.87), Vector3(4.65,2.3,0.16), oak_dark)
	var sky := material("#a9c6bc")
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box("Window sky", Vector3(2.3,2.9,-3.77), Vector3(4.38,2.02,0.025), sky)
	box("Distant hill", Vector3(2.3,2.24,-3.73), Vector3(4.38,0.65,0.04), material("#718a6a"))
	box("Training pitch through window", Vector3(2.3,2.0,-3.69), Vector3(4.38,0.35,0.04), material("#456a43"))
	for xx in [0.18,1.6,3.0,4.42]:
		box("Window mullion", Vector3(xx,2.9,-3.61), Vector3(0.065,2.1,0.15), oak_dark)
	box("Window horizontal", Vector3(2.3,2.86,-3.6), Vector3(4.5,0.06,0.15), oak_dark)
	box("Window sill", Vector3(2.3,1.8,-3.54), Vector3(4.8,0.13,0.55), oak)
	# Sunlit rug defines the meeting area.
	box("Woven rug", Vector3(0.6,0.065,0.25), Vector3(6.25,0.018,4.7), material("#b8b49a"))
	crest_plane("Club crest woven into rug",Vector3(2.15,0.094,1.45),1.1,Vector3(-PI/2,0,0))
	for zz in [-2.0,2.5]:
		box("Rug edge", Vector3(0.6,0.077,zz), Vector3(6.18,0.005,0.07), club_primary)
	for xx in [-2.35,3.55]:
		box("Rug border", Vector3(xx,0.078,0.25), Vector3(0.07,0.005,4.5), club_primary)

func build_window_view() -> void:
	for x in range(13):
		var p := Vector3(0.35+x*0.32,2.23+rng.randf()*0.04,-3.67)
		sphere("Trees beyond glass",p,Vector3(0.4,0.38+rng.randf()*0.2,0.06),material("#526e55"))
	for xx in [2.9,3.55]:
		box("Goal post beyond glass",Vector3(xx,2.25,-3.63),Vector3(0.025,0.55,0.02),paper)
	box("Goal crossbar beyond glass",Vector3(3.225,2.19,-3.63),Vector3(0.67,0.025,0.02),paper)
	for z in [1.96,2.03,2.1]:
		box("Pitch stripe beyond glass",Vector3(2.3,z,-3.64),Vector3(4.3,0.012,0.015),material("#93a786"))

func board_line(a: Vector2, b: Vector2, mat: Material, width: float = 0.014) -> void:
	var line := box("Chalk diagram", Vector3((a.x+b.x)/2, (a.y+b.y)/2,-3.62), Vector3(a.distance_to(b),width,0.01),mat)
	line.rotation.z = atan2(b.y-a.y,b.x-a.x)

func board_arrow(a: Vector2, b: Vector2, mat: Material) -> void:
	board_line(a,b,mat,0.018)
	var direction := (b-a).normalized()
	var perpendicular := Vector2(-direction.y,direction.x)
	board_line(b,b-direction*0.1+perpendicular*0.055,mat,0.018)
	board_line(b,b-direction*0.1-perpendicular*0.055,mat,0.018)

func board_token(number: int, point: Vector2, mat: Material, ink: Color) -> void:
	if mat == club_primary:
		var rim := cyl("Club attack rim",Vector3(point.x,point.y,-3.605),0.059,0.018,presentation_accent)
		rim.rotation.x = PI/2
	var token := cyl("Rugby XV magnet "+str(number),Vector3(point.x,point.y,-3.59),0.047,0.025,mat)
	token.rotation.x = PI/2
	text3(str(number),Vector3(point.x,point.y,-3.565),15,ink)

func build_board() -> void:
	box("Tactics frame",Vector3(-2.45,2.95,-3.78),Vector3(3.65,2.25,0.14),oak_dark)
	box("Club rim",Vector3(-2.45,2.95,-3.69),Vector3(3.48,2.06,0.025),presentation_accent)
	box("Neutral chalkboard",Vector3(-2.45,2.95,-3.67),Vector3(3.4,1.98,0.02),material("#263b37"))
	text3("SORTIE DE RUCK · ATTAQUE VERS LE HAUT ↑",Vector3(-2.45,3.77,-3.61),21,Color("#e9dfc3"))
	for xx in [-3.94,-0.96]:
		board_line(Vector2(xx,2.28),Vector2(xx,3.53),paper,0.01)
	for yy in [2.28,3.53]:
		board_line(Vector2(-3.94,yy),Vector2(-0.96,yy),paper,0.01)
	# Local phase: ball under the ruck, two bound attackers and two defenders;
	# remaining forwards support behind the hindmost foot, backs take depth.
	box("Ruck zone",Vector3(-3.38,3.0,-3.625),Vector3(0.38,0.25,0.008),oak_dark)
	sphere("Ball at ruck",Vector3(-3.38,2.99,-3.56),Vector3(0.09,0.045,0.025),paper)
	var attack := {
		1:Vector2(-3.46,2.96),2:Vector2(-3.30,2.96),3:Vector2(-3.64,2.78),
		4:Vector2(-3.46,2.73),5:Vector2(-3.28,2.76),6:Vector2(-3.08,2.84),
		7:Vector2(-2.98,2.66),8:Vector2(-3.54,2.56),9:Vector2(-3.12,2.58),
		10:Vector2(-2.70,2.57),12:Vector2(-2.28,2.49),13:Vector2(-1.86,2.41),
		11:Vector2(-1.16,2.38),14:Vector2(-3.80,2.48),15:Vector2(-2.30,2.35)}
	for number in attack:
		board_token(number,attack[number],club_primary,presentation_accent.albedo_color)
	# Guards flank the ruck, a connected line faces the attackers, three cover behind.
	var defence := [Vector2(-3.46,3.09),Vector2(-3.30,3.09),Vector2(-3.77,3.20),
		Vector2(-3.08,3.20),Vector2(-2.83,3.20),Vector2(-2.57,3.20),
		Vector2(-2.31,3.20),Vector2(-2.05,3.20),Vector2(-1.79,3.20),
		Vector2(-1.53,3.20),Vector2(-1.25,3.20),Vector2(-1.03,3.20),
		Vector2(-3.13,3.42),Vector2(-2.30,3.43),Vector2(-1.43,3.42)]
	for i in range(defence.size()):
		board_token(i+1,defence[i],paper,Color("#263b37"))
	# Distribution goes laterally and backwards, then the carrier advances upfield.
	board_arrow(Vector2(-3.04,2.57),Vector2(-2.80,2.57),presentation_accent)
	board_arrow(Vector2(-2.62,2.55),Vector2(-2.38,2.50),presentation_accent)
	board_arrow(Vector2(-2.20,2.48),Vector2(-1.96,2.42),presentation_accent)
	board_arrow(Vector2(-1.86,2.50),Vector2(-1.86,3.02),presentation_accent)
	text3("XV · SCHÉMA PÉDAGOGIQUE SIMPLIFIÉ · PAS UNE FORMATION OFFICIELLE",Vector3(-2.45,2.12,-3.61),14,Color("#d4dacb"))

func build_desk() -> void:
	box("Executive oak desktop",Vector3(0,1.38,0.15),Vector3(3.6,0.16,1.65),oak)
	box("Desk under edge",Vector3(0,1.27,0.15),Vector3(3.48,0.08,1.52),oak_dark)
	box("Left desk pedestal",Vector3(-1.26,0.65,0.15),Vector3(0.78,1.23,1.34),club_primary)
	box("Right desk pedestal",Vector3(1.26,0.65,0.15),Vector3(0.78,1.23,1.34),club_primary)
	for xx in [-1.26,1.26]:
		for yy in [0.35,0.72,1.09]:
			box("Drawer seam",Vector3(xx,yy-0.15,0.833),Vector3(0.68,0.012,0.008),oak_dark)
			box("Brass drawer pull",Vector3(xx,yy,0.86),Vector3(0.22,0.025,0.04),brass)
	box("Leather desk blotter",Vector3(-0.1,1.471,0.19),Vector3(1.9,0.022,1.05),club_primary)
	var notes := box("Match report",Vector3(-0.33,1.49,0.3),Vector3(0.59,0.012,0.78),paper,0.1)
	for i in range(5):
		box("Notes ink",Vector3(-0.35,1.5,0.1+i*0.09),Vector3(0.34 if i%2==0 else 0.43,0.003,0.008),club_primary,0.1)
	box("Pen",Vector3(0.16,1.51,0.32),Vector3(0.025,0.025,0.44),brass,-0.25)
	# Hinge on visitor side (+Z), keyboard and active screen face the coach at -Z.
	box("Laptop base",Vector3(0.5,1.5,-0.15),Vector3(0.88,0.045,0.61),black)
	var screen := box("Laptop display",Vector3(0.5,1.8,0.12),Vector3(0.88,0.58,0.045),black)
	screen.rotation.x = 0.14
	box("Laptop back crest",Vector3(0.5,1.79,0.15),Vector3(0.11,0.11,0.01),brass)
	var screen_content := box("Active display faces coach",Vector3(0.5,1.8,0.092),Vector3(0.78,0.46,0.006),material("#7496a9"))
	screen_content.rotation.x = 0.14
	for row in range(3):
		for column in range(8):
			box("Laptop keyboard toward coach",Vector3(0.19+column*0.087,1.527,-0.23-row*0.062),Vector3(0.065,0.008,0.04),ivory)
	cyl("Coffee cup",Vector3(-1.22,1.6,-0.29),0.12,0.24,paper)
	cyl("Coffee",Vector3(-1.22,1.725,-0.29),0.10,0.006,oak_dark)
	cyl("Desk lamp base",Vector3(1.4,1.49,-0.39),0.22,0.04,brass)
	cyl("Desk lamp stem",Vector3(1.4,1.84,-0.39),0.023,0.7,brass)
	cyl("Desk lamp shade",Vector3(1.4,2.18,-0.39),0.33,0.26,club_primary,0.18)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1.4,1.95,-0.39)
	lamp.light_color = Color("#ffdc91")
	lamp.light_energy = 0.65
	lamp.omni_range = 2.7
	add_child(lamp)
	asset("chairDesk", Vector3(0,0.09,-1.5),1.75,0.0)
	chair(Vector3(0,0,2.05),PI,false)

func chair(p: Vector3, angle: float, executive: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = p
	root.rotation.y = angle
	var before := get_children()
	box("Leather seat",Vector3(0,0.68,0),Vector3(0.94,0.17,0.89),club_primary)
	box("Upholstered back",Vector3(0,1.23,-0.37),Vector3(0.94,1.0 if executive else 0.76,0.18),club_primary)
	for xx in [-0.47,0.47]:
		box("Chair arm",Vector3(xx,1.0,0),Vector3(0.09,0.08,0.74),oak)
		for zz in [-0.3,0.3]:
			box("Chair leg",Vector3(xx,0.36,zz),Vector3(0.055,0.65,0.055),black)
	for child in get_children():
		if child != root and child not in before:
			child.reparent(root, false)

func build_shelves() -> void:
	# Full library on left wall; open oak construction with club_primary recessed backing.
	box("Bookcase backing",Vector3(-4.73,1.58,0.3),Vector3(0.25,3.0,2.9),club_primary)
	for zz in [-1.2,0.3,1.8]:
		box("Bookcase upright",Vector3(-4.46,1.6,zz),Vector3(0.7,3.1,0.09),oak_dark)
	for yy in [0.12,0.95,1.8,2.65,3.15]:
		box("Bookcase shelf",Vector3(-4.45,yy,0.3),Vector3(0.75,0.07,3.12),oak)
	for i in range(21):
		var zz := -1.02+float(i%7)*0.17
		var yy: float = [0.99,1.84,2.69][i/7]
		var color: Material = [club_tint,ivory,oak_dark,material("#ad6946")][i%4]
		box("Club archive volumes",Vector3(-4.27,yy+0.19,zz),Vector3(0.4,0.34+rng.randf()*0.16,0.13),color)
		box("Book spine gold",Vector3(-4.055,yy+0.12,zz),Vector3(0.005,0.018,0.1),brass)
	# Sideboard beneath the window.
	box("Window credenza",Vector3(2.6,0.68,-2.93),Vector3(3.55,1.2,0.83),club_primary)
	box("Credenza top",Vector3(2.6,1.31,-2.93),Vector3(3.67,0.12,0.93),oak)
	for xx in [1.72,2.6,3.48]:
		box("Credenza door",Vector3(xx,0.7,-2.49),Vector3(0.84,1.05,0.025),club_tint)
		cyl("Door knob",Vector3(xx+0.28,0.78,-2.45),0.035,0.04,brass).rotation.x=PI/2
	# Rugby ball displayed on a plinth.
	box("Rugby ball stand",Vector3(2.65,1.42,-2.88),Vector3(0.7,0.1,0.32),oak_dark)
	var ball := sphere("Leather rugby ball",Vector3(2.65,1.67,-2.88),Vector3(0.77,0.39,0.39),material("#8b5030"))
	ball.rotation.z = -0.15
	for i in range(6):
		box("Ball laces",Vector3(2.48+i*0.06,1.835,-2.8),Vector3(0.018,0.01,0.09),paper)
	# Trophy made from solid brass pieces, displayed in the library.
	cyl("Trophy base",Vector3(-4.3,1.91,1.05),0.23,0.16,oak_dark)
	cyl("Trophy stem",Vector3(-4.3,2.09,1.05),0.055,0.24,brass)
	cyl("Trophy bowl",Vector3(-4.3,2.31,1.05),0.10,0.25,brass,0.23)
	for zz in [0.77,1.33]:
		var ring := TorusMesh.new()
		ring.inner_radius=0.10
		ring.outer_radius=0.14
		var mi:=MeshInstance3D.new()
		mi.mesh=ring
		mi.material_override=brass
		mi.position=Vector3(-4.3,2.31,zz)
		mi.rotation.z=PI/2
		add_child(mi)

func build_details() -> void:
	# Potted olive tree in the window corner.
	cyl("Terracotta planter",Vector3(4.2,0.37,-1.25),0.38,0.68,material("#a96f4d"),0.46)
	cyl("Planter soil",Vector3(4.2,0.72,-1.25),0.4,0.02,oak_dark)
	cyl("Tree trunk",Vector3(4.2,1.48,-1.25),0.05,1.55,oak_dark)
	for i in range(18):
		var a:=rng.randf()*TAU
		var y:=1.65+rng.randf()*1.15
		var radius:=0.2+rng.randf()*0.48
		sphere("Olive foliage",Vector3(4.2+cos(a)*radius,y,-1.25+sin(a)*radius),Vector3(0.48,0.39,0.43),material("#536b43"))
	# Framed shirt, portrait and club heritage on the side wall.
	box("Shirt frame",Vector3(-4.96,2.98,2.85),Vector3(0.13,1.95,1.63),oak_dark)
	box("Shirt ivory mount",Vector3(-4.88,2.98,2.85),Vector3(0.015,1.78,1.45),paper)
	box("Heritage jersey body",Vector3(-4.85,2.98,2.85),Vector3(0.03,0.96,0.66),club_primary)
	box("Heritage jersey sleeve",Vector3(-4.85,3.28,2.36),Vector3(0.03,0.39,0.39),club_primary)
	box("Heritage jersey sleeve",Vector3(-4.85,3.28,3.34),Vector3(0.03,0.39,0.39),club_primary)
	crest_plane("Club crest on heritage jersey",Vector3(-4.80,3.23,2.85),0.19,Vector3(0,PI/2,0))
	var number:=text3("10",Vector3(-4.8,2.89,2.85),54,presentation_accent.albedo_color)
	number.rotation.y=PI/2
	var cap:=text3(club_name.to_upper(),Vector3(-4.79,2.22,2.85),22,Color("#3f4140"))
	cap.rotation.y=PI/2
	# A small meeting table near foreground corner.
	cyl("Occasional table",Vector3(3.8,0.86,1.7),0.64,0.11,oak)
	cyl("Occasional table base",Vector3(3.8,0.43,1.7),0.06,0.8,black)
	cyl("Occasional table foot",Vector3(3.8,0.1,1.7),0.43,0.06,black)
	box("Club journal",Vector3(3.8,0.94,1.7),Vector3(0.55,0.04,0.69),club_primary,0.16)
	crest_plane("Club crest on journal",Vector3(3.8,0.968,1.7),0.32,Vector3(-PI/2,0.16,0))

func setup_camera() -> void:
	var env:=WorldEnvironment.new()
	var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("#1c252a")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("#b8bcbe")
	e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=e
	add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-38,-42,0)
	sun.light_color=Color("#ffe0ac")
	sun.light_energy=0.95
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=40
	add_child(sun)
	var key:=OmniLight3D.new()
	key.position=Vector3(2.5,3.8,-2.9)
	key.light_color=Color("#ffdfae")
	key.light_energy=0.9
	key.omni_range=8
	key.shadow_enabled=true
	add_child(key)
	var fill:=OmniLight3D.new()
	fill.position=Vector3(1,4,4)
	fill.light_color=Color("#adc5c2")
	fill.light_energy=0.7
	fill.omni_range=13
	add_child(fill)
	var camera:=Camera3D.new()
	camera.position=Vector3(12,9.5,14.5)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=13.1
	add_child(camera)
	camera.look_at(Vector3(0,1.1,-0.2))
	camera.current=true

func asset(filename: String, pos: Vector3, height: float, rot: float) -> void:
	var packed := load("res://ui/contextual/rooms/assets/furniture/"+filename+".glb") as PackedScene
	if packed == null:
		return
	var root := Node3D.new()
	add_child(root)
	var model := packed.instantiate() as Node3D
	root.add_child(model)
	var bounds: AABB = collect_bounds(model, AABB(), true)
	var factor: float = height / maxf(bounds.size.y, 0.01)
	model.scale *= factor
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)*factor
	root.position = pos
	root.rotation.y = rot
	recolor_model(model)

func collect_bounds(node: Node3D, result: AABB, first: bool) -> AABB:
	if node is MeshInstance3D:
		var bounds: AABB = node.global_transform * node.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	for child in node.get_children():
		if child is Node3D:
			var bound := collect_bounds(child, AABB(), true)
			if bound.size != Vector3.ZERO:
				result = bound if first else result.merge(bound)
				first = false
	return result

func recolor_model(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var original: Material = node.mesh.surface_get_material(i)
			if original == null:
				continue
			var n: String = original.resource_name.to_lower()
			if "carpet" in n and "white" not in n:
				node.set_surface_override_material(i, club_primary)
			elif "plant" in n:
				node.set_surface_override_material(i, foliage)
			elif "wood" in n:
				node.set_surface_override_material(i, oak_dark if "dark" in n else oak)
	for child in node.get_children():
		recolor_model(child)
