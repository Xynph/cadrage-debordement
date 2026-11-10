extends Node3D

const RoomIdentity = preload("res://ui/contextual/rooms/room_identity.gd")
var primary_color := Color("596368")
var contrast_color := Color("e8e5dc")

var mats := {}
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var club_name := ""
var crest_texture: Texture2D
var display_font = preload("res://fonts/BarlowCondensed-SemiBold.ttf")

func configure(identity: Dictionary, texture: Texture2D) -> void:
	club_name = str(identity.get("name", ""))
	primary_color = RoomIdentity.primary(identity)
	contrast_color = RoomIdentity.contrast(primary_color)
	crest_texture = texture
	set_meta("identity", identity.duplicate(true))
	set_meta("primary_color", primary_color)
	set_meta("contrast_color", contrast_color)
	set_meta("crest_texture", texture)

func _ready() -> void:
	rng.seed = 92
	make_materials()
	make_environment()
	make_ground()
	make_stand()
	make_landscape()
	make_equipment()
	make_players()
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(43, 6.5, 32)
	camera.look_at(Vector3(-6, -4.0, -24))
	camera.fov = 65
	camera.far = 600
	camera.current = true

func crest_quad(pos:Vector3, height:float, rotation_y:=0.0) -> void:
	if crest_texture == null:
		return
	var badge = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(height*crest_texture.get_width()/float(crest_texture.get_height()),height)
	badge.mesh = quad
	var material = StandardMaterial3D.new()
	material.albedo_texture = crest_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	badge.material_override = material
	badge.position = pos
	badge.rotation_degrees.y = rotation_y
	add_child(badge)

func mat(c: String, roughness:=0.85, metal:=0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = roughness
	m.metallic = metal
	return m

func make_materials():
	mats = {"white":mat("dadfcf"),"dark":mat("112b29"),"black":mat("17201f"),"wood":mat("746146"),"concrete":mat("7b7e74"),"orange":mat("ef7e41"),"gold":mat("d5bc7a"),"green":mat("1b4d3e"),"metal":mat("45534f",0.45,0.65),"bark":mat("403c2f"),"leaf":mat("243d32"),"ball":mat("ded5b8"),"blue":mat("417c8d")}
	mats["green"].albedo_color = primary_color
	mats["gold"].albedo_color = contrast_color
	var light = mat("fff2c9")
	light.emission_enabled = true
	light.emission = Color("fce3b5")
	light.emission_energy_multiplier = 3.0
	mats["lamp"] = light

func cube(pos:Vector3, size:Vector3, material:Material, parent:Node=self) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

func cylinder(pos:Vector3, radius:float, height:float, material:Material, parent:Node=self, top:float=-1) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

func line(a:Vector3,b:Vector3,width:float,material:Material):
	var mi = cylinder((a+b)/2,width,a.distance_to(b),material)
	if abs(a.normalized().dot(b.normalized())) < 0.999 or abs((b-a).normalized().dot(Vector3.UP)) < 0.999:
		mi.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return mi

func make_environment():
	var world = WorldEnvironment.new()
	var env = Environment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("07152b")
	sky_mat.sky_horizon_color = Color("213840")
	sky_mat.ground_bottom_color = Color("162524")
	sky_mat.ground_horizon_color = Color("213840")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("94b0b8")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	env.fog_light_color = Color("5c7476")
	env.fog_light_energy = 0.6
	env.fog_density = 0.0015
	world.environment = env
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-10,-130,0)
	sun.light_color = Color("ffe9d4")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	add_child(sun)

func make_ground():
	cube(Vector3(0,-0.3,0),Vector3(280,0.5,290),mat("344636"))
	cube(Vector3(40,-0.03,0),Vector3(6,0.1,130),mat("63665a"))
	var shader = Shader.new()
	shader.code = "shader_type spatial; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float n=fract(sin(dot(floor(wp.xz*17.0),vec2(12.9898,78.233)))*43758.5453); float stripe=step(0.5,fract((wp.z+60.0)/12.0)); ALBEDO=mix(vec3(0.012,0.13,0.038),vec3(0.022,0.18,0.054),stripe)+n*0.009; ROUGHNESS=0.97;}"
	var grass = ShaderMaterial.new()
	grass.shader = shader
	cube(Vector3(0,0,0),Vector3(70,0.07,120),grass)
	# Rugby XV geometry: 100 m between goal lines, 10 m in-goal areas.
	for z in [-60.0,-50.0,-28.0,0.0,28.0,50.0,60.0]:
		cube(Vector3(0,0.05,z),Vector3(70,0.025,0.11),mats.white)
	for x in [-35.0,35.0]:
		cube(Vector3(x,0.05,0),Vector3(0.12,0.025,120),mats.white)
	for z in [-40.0,-10.0,10.0,40.0]:
		for x in range(-33,34,7):
			cube(Vector3(x,0.052,z),Vector3(3.2,0.025,0.10),mats.white)
	for x in [-30.0,30.0]:
		for z in range(-47,49,8):
			cube(Vector3(x,0.052,z),Vector3(0.1,0.025,2.8),mats.white)
	for z in [-50.0,50.0]:
		for x in [-2.8,2.8]:
			cylinder(Vector3(x,6.5,z),0.095,13,mats.white)
			cube(Vector3(x,0.8,z),Vector3(0.48,1.6,0.48),mats.green)
		cube(Vector3(0,3,z),Vector3(5.6,0.16,0.16),mats.white)
	for x in [-35.0,35.0]:
		for z in [-50.0,50.0]:
			cylinder(Vector3(x,0.75,z),0.025,1.5,mats.white)
			cube(Vector3(x+0.2,1.4,z),Vector3(0.4,0.28,0.025),mats.gold)
	# Low rails define a modest club ground.
	for x in [-39.0,47.0]:
		for z in range(-65,66,5): cylinder(Vector3(x,0.65,z),0.045,1.3,mats.metal)
		cube(Vector3(x,1.2,0),Vector3(0.08,0.08,130),mats.metal)
		cube(Vector3(x,0.65,0),Vector3(0.08,0.08,130),mats.metal)
	for z in [-63.0,63.0]:
		cube(Vector3(0,1.0,z),Vector3(80,0.08,0.08),mats.metal)
		for x in range(-40,41,5): cylinder(Vector3(x,0.6,z),0.045,1.2,mats.metal)
	for loc in [Vector3(-39,0,-47),Vector3(44,0,-46),Vector3(-39,0,40),Vector3(45,0,35)]: floodlight(loc)

func floodlight(pos:Vector3):
	cylinder(pos+Vector3(0,8,0),0.11,16,mats.metal)
	cube(pos+Vector3(0,15.8,0),Vector3(3.5,0.16,0.2),mats.metal)
	for x in [-1.2,-0.4,0.4,1.2]:
		cube(pos+Vector3(x,15.8,-0.05),Vector3(0.6,0.4,0.45),mats.black)
		cube(pos+Vector3(x,15.65,-0.3),Vector3(0.5,0.23,0.035),mats.lamp)
	var spot = SpotLight3D.new()
	spot.position = pos+Vector3(0,15.5,0)
	add_child(spot)
	spot.look_at(Vector3(0,0,pos.z*0.4))
	spot.spot_range = 85
	spot.spot_angle = 55
	spot.light_color = Color("d5e5e7")
	spot.light_energy = 5.0
	spot.shadow_enabled = false

func make_stand():
	# Intimate covered club stand beyond the far right touchline.
	cube(Vector3(48,0.25,-23),Vector3(13,0.5,30),mats.concrete)
	for tier in range(4):
		cube(Vector3(45.0+tier*1.7,0.6+tier*0.5,-23),Vector3(1.7,1.0+tier,29),mats.concrete)
		for row in range(23):
			var z = -36.5+row*1.2
			cube(Vector3(45.1+tier*1.7,1.2+tier*0.5,z),Vector3(0.85,0.15,0.84),mats.green if row%5 else mats.white)
			cube(Vector3(45.45+tier*1.7,1.55+tier*0.5,z),Vector3(0.12,0.75,0.8),mats.green if row%5 else mats.white)
	for z in [-38.0,-8.0]:
		for x in [42.0,55.0]:
			cylinder(Vector3(x,3.4,z),0.12,6.8,mats.metal)
	var roof = cube(Vector3(49,6.8,-23),Vector3(16,0.25,33),mats.dark)
	roof.rotation_degrees.z = -5
	cube(Vector3(41.2,6.5,-23),Vector3(0.15,0.7,33),mats.green)
	var sign = Label3D.new()
	sign.text = club_name.to_upper()
	sign.font = display_font
	sign.font_size = 64
	sign.pixel_size = 0.012
	sign.position = Vector3(41.05,6.5,-23)
	sign.rotation_degrees.y = -90
	sign.modulate = Color("e6e2cc")
	add_child(sign)
	# Club pavilion on the opposite side, warm windows.
	cube(Vector3(-48,2,-14),Vector3(12,4,29),mats.dark)
	cube(Vector3(-48,4.2,-14),Vector3(15,0.35,32),mats.black)
	for z in range(-26,0,5):
		cube(Vector3(-41.93,2,z),Vector3(0.05,2.0,3.7),mat("bca47c"))
		cube(Vector3(-41.87,2,z),Vector3(0.08,2.0,0.08),mats.metal)
	cube(Vector3(-40,0.12,-14),Vector3(5,0.22,31),mats.wood)

func make_landscape():
	for i in range(200):
		var x = rng.randf_range(-120,115)
		var z = rng.randf_range(-140,80)
		if abs(x)<59 and z>-76: continue
		var h = rng.randf_range(6,15)
		cylinder(Vector3(x,h*0.28,z),0.24,h*0.56,mats.bark)
		var leaf = mat(Color.from_hsv(rng.randf_range(0.29,0.38),0.37,rng.randf_range(0.18,0.29)).to_html())
		for j in range(3):
			var sphere = MeshInstance3D.new()
			var mesh = SphereMesh.new()
			mesh.radial_segments = 10
			mesh.rings = 6
			mesh.radius = h*0.25-j*0.18
			mesh.height = h*0.57
			sphere.mesh = mesh
			sphere.material_override = leaf
			sphere.position = Vector3(x+rng.randf_range(-1,1),h*0.6+j*1.3,z+rng.randf_range(-1,1))
			add_child(sphere)
	for i in range(9):
		var hill = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		mesh.radius = rng.randf_range(33,65)
		mesh.height = mesh.radius*0.9
		hill.mesh = mesh
		hill.position = Vector3(-150+i*39,-10,-170-rng.randf_range(0,20))
		hill.material_override = mat("263e36")
		add_child(hill)

func ball(pos:Vector3, rot:=0.0):
	var n = Node3D.new()
	add_child(n)
	n.position = pos
	n.rotation.y = rot
	var mi = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 24
	mesh.rings = 12
	mi.mesh = mesh
	mi.scale = Vector3(1,1,1.65)
	mi.material_override = mats.ball
	n.add_child(mi)
	for z in [-0.13,0.13]:
		var band = TorusMesh.new()
		band.inner_radius = 0.124
		band.outer_radius = 0.141
		var b = MeshInstance3D.new()
		b.mesh = band
		b.rotation_degrees.x = 90
		b.position.z = z
		b.material_override = mats.green
		n.add_child(b)
	for z in [-0.05,-0.025,0.0,0.025,0.05]:
		cube(Vector3(0,0.157,z),Vector3(0.06,0.008,0.008),mats.black,n)

func cone(pos:Vector3):
	cylinder(pos+Vector3(0,0.035,0),0.22,0.07,mats.orange)
	cylinder(pos+Vector3(0,0.2,0),0.16,0.34,mats.orange,self,0.025)
	cylinder(pos+Vector3(0,0.21,0),0.09,0.08,mats.white,self,0.065)

func make_equipment():
	var bench_scene = load("res://ui/contextual/rooms/assets/furniture/bench.glb") as PackedScene
	if bench_scene:
		for z in [10.0,15.0,20.0]:
			var bench = bench_scene.instantiate()
			add_child(bench)
			bench.position=Vector3(39.2,0.06,z)
			bench.scale=Vector3(3.8,2.1,3.8)
			bench.rotation_degrees.y=90
	for z in [12.0,18.0,24.0]:
		cube(Vector3(40.5,0.65,z),Vector3(0.75,0.12,4.5),mats.wood)
		cube(Vector3(40.85,1.07,z),Vector3(0.12,0.75,4.5),mats.wood)
		for off in [-1.6,1.6]:
			cube(Vector3(40.5,0.3,z+off),Vector3(0.65,0.6,0.12),mats.metal)
	# Training tackle bags on the near sideline.
	for z in [10.5,12.0,13.5]:
		var pad = cylinder(Vector3(34.0,0.7,z),0.34,1.4,mats.green)
		pad.rotation_degrees.z = -12
		crest_quad(Vector3(34.05,0.83,z+0.355),0.38)
	for p in [Vector3(29,0,16),Vector3(31,0,12),Vector3(29,0,8),Vector3(31,0,4),Vector3(27,0,0)]: cone(p)
	for i in range(7): cone(Vector3(15,0,-4-i*3.5))
	for p in [Vector3(35.5,0.18,17),Vector3(36,0.18,16.5),Vector3(35.8,0.18,17.5),Vector3(31,0.18,9)]: ball(p,rng.randf()*TAU)
	# Ball trolley and bottles.
	cube(Vector3(38,0.45,18),Vector3(0.9,0.8,1.5),mats.dark)
	crest_quad(Vector3(38,0.48,18.76),0.42)
	for x in [37.6,38.4]:
		for z in [17.4,18.6]:
			var wheel = cylinder(Vector3(x,0.18,z),0.16,0.1,mats.black)
			wheel.rotation_degrees.z = 90
	for i in range(5): ball(Vector3(38+rng.randf_range(-0.22,0.22),0.92,17.5+i*0.22),0.4)
	cube(Vector3(40.3,0.85,21),Vector3(0.5,0.35,0.9),mats.white)
	for i in range(5): cylinder(Vector3(40.3,1.1,20.7+i*0.15),0.045,0.24,mats.orange)
	# Flat agility ladder on the pitch.
	for x in [24.0,25.0]: cube(Vector3(x,0.075,-3),Vector3(0.05,0.035,7),mats.gold)
	for z in range(-6,1): cube(Vector3(24.5,0.08,z),Vector3(1.0,0.035,0.08),mats.gold)

func find_animation(node:Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for c in node.get_children():
		var found = find_animation(c)
		if found: return found
	return null

func make_players():
	var scene = load("res://ui/contextual/rooms/assets/athlete/athlete.glb") as PackedScene
	if not scene: return
	for i in range(9):
		var player = scene.instantiate()
		add_child(player)
		player.position = Vector3(17+i%3*4.2,0.1,-4-floor(i/3.0)*7)
		player.rotation.y = -0.8+i*0.15
		if i < 3:
			var staff_positions = [Vector3(29.2,0.1,0.4),Vector3(30.5,0.1,-0.2),Vector3(29.4,0.1,-1.2)]
			player.position = staff_positions[i]
			player.rotation.y = [0.5,-1.4,2.6][i]
		var bounds = AABB()
		var found = false
		for child in player.find_children("*", "MeshInstance3D", true, false):
			var relative = player.global_transform.affine_inverse()*child.global_transform
			var part = relative*child.get_aabb()
			bounds = bounds.merge(part) if found else part
			found = true
		if found and bounds.size.y>0.001:
			var calibration = 1.9/bounds.size.y
			player.scale = Vector3.ONE*calibration
			player.position.y = -bounds.position.y*calibration+0.06
		var anim = find_animation(player)
		if anim:
			var names = anim.get_animation_list()
			for n in names:
				if "idle" in n.to_lower():
					anim.play(n)
					anim.seek(i*0.4,true)
					break
		# Keep native CC0 geometry and its original materials.
