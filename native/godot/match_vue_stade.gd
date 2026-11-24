extends RefCounted
## Construction du décor de la vue 3D du match : ciel et lumière, terrain, tribunes, public, écusson
## du club et ballon.
## Fonctions statiques sur la vue (`v`, NativeMatchView de match_view.gd), qui garde tout l'état ;
## découpées de match_view.gd le 24/11/2026 sans changement de comportement.

const Tactique = preload("res://match_tactique.gd")

const STADIUM_FONT := "res://fonts/BarlowCondensed-SemiBold.ttf"


static func _build_environment(v: NativeMatchView) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6b7d89")
	sky_material.sky_horizon_color = Color("d7dcd8")
	sky_material.ground_bottom_color = Color("29383a")
	sky_material.ground_horizon_color = Color("c5cfca")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c6cfd1")
	settings.ambient_light_energy = 0.43
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	v.add_child(environment)
	var sun := DirectionalLight3D.new()
	v._sun = sun
	# Neutral art lighting, not an assertion about the match's time or weather.
	sun.rotation_degrees = Vector3(-57, -24, 0)
	sun.light_color = Color("fff6e9")
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.14
	v.add_child(sun)


static func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## Sans parent : posé sur la vue (seul usage, terrain).
static func _box(v: NativeMatchView, size: Vector3, position_: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position_
	if size.y < 0.1:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(mesh)
	return mesh


static func _build_ground(v: NativeMatchView) -> void:
	var first_child := v.get_child_count()
	var dark := _material(Color("202b2c"))
	_box(v, Vector3(220, 0.4, 180), Vector3(0, -0.45, 0), dark).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(v, Vector3(135, 0.2, 96), Vector3(0, -0.2, 0), _material(Color("464c49"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(v, Vector3(118, 0.1, 80), Vector3(0, -0.09, 0), _material(Color("284c31"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Pelouse fixe (aucun bruit animé) : shader d'origine et textures de art/matieres/.
	var grass := ShaderMaterial.new()
	v._grass = grass
	grass.shader = load("res://shaders/stadium_surface.gdshader") as Shader
	# Textures de la pelouse : touffes, taches de teinte, relief des brins.
	preload("res://match_matieres.gd").pelouse(grass)
	_box(v, Vector3(110, 0.12, 70), Vector3(0, -0.07, 0), grass).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := _material(Color("efefdf"))
	for z in [-35.0, 35.0]:
		_box(v, Vector3(110, 0.018, 0.16), Vector3(0, 0.008, z), paint)
	for x in [-55.0, -50.0, -28.0, 0.0, 28.0, 50.0, 55.0]:
		_box(v, Vector3(0.16, 0.018, 70), Vector3(x, 0.008, 0), paint)
	for x in [-45.0, -10.0, 10.0, 45.0]:
		for z in range(-32, 33, 8):
			_box(v, Vector3(0.13, 0.018, 3), Vector3(x, 0.009, z), paint)
	for z in [-30.0, -20.0, 20.0, 30.0]:
		for x in range(-45, 46, 10):
			_box(v, Vector3(3, 0.018, 0.13), Vector3(x, 0.009, z), paint)
	for x in [-50.0, 50.0]:
		for z in [-2.8, 2.8]:
			_box(v, Vector3(0.17, 12, 0.17), Vector3(x, 6, z), paint)
			_box(v, Vector3(0.42, 1.6, 0.42), Vector3(x, 0.8, z), _material(Color("263b49")))
		_box(v, Vector3(0.17, 0.17, 5.6), Vector3(x, 3, 0), paint)
	for x in [-50.0, 50.0]:
		for z in [-35.0, 35.0]:
			_box(v, Vector3(0.07, 1.4, 0.07), Vector3(x, 0.7, z), paint)
			_box(v, Vector3(0.48, 0.3, 0.025), Vector3(x + 0.2, 1.3, z), _material(Color("e1ba66")))
	# Le rendu moderne projette les ombres de contact sur ces seuls éléments.
	for index in range(first_child, v.get_child_count()):
		if v.get_child(index) is MeshInstance3D:
			v._ground_meshes.append(v.get_child(index))


static func _build_stadium(v: NativeMatchView) -> void:
	# Generic architecture, deliberately unrelated to a named real-world stadium.
	var concrete := _material(Color("545c5d"))
	var anthracite := _material(Color("202c33"))
	var ivory := _material(Color("a9b1a9"))
	var roof := _material(Color("4d6067"))
	var steel := _material(Color("7f9195"))
	var seat := _material(Color("374e57"))
	var aisle := _material(Color("a99e7c"))
	var lamp := _material(Color("e8dec2"), true)
	var spectator_positions: Array[Vector3] = []
	var spectator_rotations: Array[float] = []
	var seat_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 271828 # Local visual randomness must never consume engine RNG.
	for side in [-1.0, 1.0]:
		# Eight separated bays, readable aisles and recessed entrances.
		for bay in 8:
			var center := -56.0 + bay * 16.0
			for row in 10:
				var height := 0.65 + row * 0.74
				var z: float = side * (46.0 + row * 1.24)
				_venue_box(v, Vector3(14.1, height, 1.24), Vector3(center, height * 0.5, z), concrete)
				_venue_box(v, Vector3(14.1, 0.08, 0.17), Vector3(center, height + 0.05, z - side * 0.55), ivory)
				for place in 20:
					var x := center - 6.65 + place * 0.7
					var sitting := Vector3(x, height + 0.43, z)
					seat_transforms.append(Transform3D(Basis().rotated(Vector3.UP, PI if side > 0 else 0), sitting))
					if rng.randf() > 0.22:
						spectator_positions.append(sitting + Vector3(rng.randf_range(-0.06, 0.06), 0.05, 0.08 * side))
						spectator_rotations.append(PI if side > 0 else 0.0)
			# Recesses remain behind seating, no spurious actors in the technical area.
			_venue_box(v, Vector3(2.1, 2.6, 1.4), Vector3(center + 8, 1.2, side * 45.6), anthracite)
			for stair in 20:
				var height := 0.32 + stair * 0.37
				_venue_box(v, Vector3(1.6, height, 0.62), Vector3(center + 8, height * 0.5, side * (45.7 + stair * 0.62)), concrete)
				_venue_box(v, Vector3(1.6, 0.025, 0.1), Vector3(center + 8, height + 0.02, side * (45.42 + stair * 0.62)), aisle)
			_venue_beam(v, Vector3(center + 8, 2.4, side * 47), Vector3(center + 8, 8.2, side * 56.8), 0.07, steel)
		# Continuous rear concourse and a restrained floating canopy.
		_venue_box(v, Vector3(132, 8.8, 1.0), Vector3(0, 4.2, side * 60.4), anthracite)
		_venue_box(v, Vector3(132, 0.28, 5.5), Vector3(0, 8.7, side * 59), concrete)
		_venue_box(v, Vector3(133, 0.38, 8.5), Vector3(0, 12.4, side * 59.1), roof)
		_venue_box(v, Vector3(133, 0.65, 0.22), Vector3(0, 12.3, side * 54.8), anthracite)
		_venue_box(v, Vector3(132, 0.09, 0.11), Vector3(0, 11.99, side * 54.67), lamp)
		for x in range(-64, 65, 16):
			_venue_box(v, Vector3(0.22, 12.4, 0.22), Vector3(x, 6.1, side * 61), steel)
			_venue_beam(v, Vector3(x, 9.5, side * 61), Vector3(x, 12.1, side * 54.8), 0.15, steel)
			_venue_box(v, Vector3(0.1, 0.18, 8.4), Vector3(x, 12.7, side * 59.1), steel)
		# Original perimeter boards, not real sponsors or fictional attendance.
		for board in 8:
			var x := -56.0 + board * 16.0
			_venue_box(v, Vector3(15.5, 1.05, 0.22), Vector3(x, 0.58, side * 41.2), anthracite)
			_venue_box(v, Vector3(15.5, 0.06, 0.24), Vector3(x, 1.13, side * 41.2), ivory)
			_stadium_advert(v, Vector3(x, 0.65, side * 41.04), PI if side > 0 else 0.0)
		# Modest end terraces leave both in-goals unobstructed.
		for row in 7:
			var height := 0.65 + row * 0.72
			var x: float = side * (65.2 + row * 1.25)
			_venue_box(v, Vector3(1.25, height, 85), Vector3(x, height * 0.5, 0), concrete)
			_venue_box(v, Vector3(0.15, 0.07, 85), Vector3(x - side * 0.54, height + 0.04, 0), ivory)
			for place in 112:
				var z := -41.6 + place * 0.75
				if place % 28 < 3:
					continue
				var sitting := Vector3(x, height + 0.43, z)
				seat_transforms.append(Transform3D(Basis().rotated(Vector3.UP, -side * PI * 0.5), sitting))
				if rng.randf() > 0.3:
					spectator_positions.append(sitting)
					spectator_rotations.append(-side * PI * 0.5)
		_venue_box(v, Vector3(0.4, 1.1, 87), Vector3(side * 74, 5.3, 0), anthracite)
		_venue_box(v, Vector3(0.14, 0.12, 87), Vector3(side * 73.8, 5.9, 0), steel)
		for z in [-22.0, 22.0]:
			_venue_box(v, Vector3(0.22, 1.05, 21), Vector3(side * 60.1, 0.58, z), anthracite)
		# Empty technical shelters are architecture, not invented staff/substitutes.
		_venue_box(v, Vector3(11.5, 0.14, 2.2), Vector3(side * 18, 2.2, 43.1), ivory)
		_venue_box(v, Vector3(11.5, 2.2, 0.18), Vector3(side * 18, 1.1, 44.1), anthracite)
		for x in [-5.6, 5.6]:
			_venue_box(v, Vector3(0.12, 2.2, 2.2), Vector3(side * 18 + x, 1.1, 43.1), steel)
	# Four compact light heads. No expensive spotlights, GI or volumetric effects.
	for x in [-62.0, 62.0]:
		for z in [-43.5, 43.5]:
			_venue_box(v, Vector3(0.24, 18, 0.24), Vector3(x, 9, z), steel)
			_venue_box(v, Vector3(3.7, 1.1, 0.38), Vector3(x, 18, z), anthracite)
			for bulb in 5:
				_venue_box(v, Vector3(0.49, 0.58, 0.06), Vector3(x - 1.4 + bulb * 0.7, 18.03, z - signf(z) * 0.22), lamp)
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.52, 0.55, 0.43)
	_instance_batch(v, "VenueSeats", seat_mesh, seat, seat_transforms)
	_build_spectators(v, spectator_positions, spectator_rotations, rng)
	_venue_box(v, Vector3(43, 3.8, 0.24), Vector3(0, 10.6, -54.8), anthracite)
	_build_club_branding(v)


static func _build_club_branding(v: NativeMatchView) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = quad
	batch.instance_count = 1 # The stadium fascia carries the managed club crest.
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.1
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	v._club_branding = MultiMeshInstance3D.new()
	v._club_branding.name = "ManagedClubCrests"
	v._club_branding.multimesh = batch
	v._club_branding.material_override = material
	v._club_branding.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(v._club_branding)
	_update_club_branding(v)


static func _update_club_branding(v: NativeMatchView) -> void:
	v._club_branding.visible = v._club_crest != null
	var material := v._club_branding.material_override as StandardMaterial3D
	material.albedo_texture = v._club_crest
	if v._club_crest == null:
		return
	var aspect := float(v._club_crest.get_width()) / maxf(1.0, v._club_crest.get_height())
	var height := minf(3.5, 16.0 / maxf(aspect, 0.01))
	v._club_branding.multimesh.set_instance_transform(0,
		Transform3D(Basis.from_scale(Vector3(height * aspect, height, 1.0)), Vector3(0, 10.6, -54.6)))


static func _stadium_advert(v: NativeMatchView, position_: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = "RUGBY LEGACY 27"
	label.font = load(STADIUM_FONT) as Font
	label.font_size = 48
	label.pixel_size = 0.017
	label.position = position_
	label.rotation.y = yaw
	label.modulate = Color("e5e3d5")
	label.outline_size = 0
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(label)


static func _venue_box(v: NativeMatchView, size: Vector3, position_: Vector3, material: Material, basis: Basis = Basis.IDENTITY) -> void:
	var key := material.get_instance_id()
	if not v._venue_batches.has(key):
		v._venue_batches[key] = {"material": material, "transforms": []}
	v._venue_batches[key].transforms.append(Transform3D(basis * Basis.from_scale(size), position_))


static func _venue_beam(v: NativeMatchView, from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var delta := to - from
	_venue_box(v, Vector3(width, delta.length(), width), (from + to) * 0.5, material, Basis(Quaternion(Vector3.UP, delta.normalized())))


static func _flush_venue_boxes(v: NativeMatchView) -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var index := 0
	for batch: Dictionary in v._venue_batches.values():
		_instance_batch(v, "VenueStructure%d" % index, cube, batch.material, batch.transforms)
		index += 1
	v._venue_batches.clear()


static func _instance_batch(v: NativeMatchView, label: String, mesh: Mesh, material: Material, transforms: Array, colors: Array[Color] = [], customs: Array[Color] = []) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = not colors.is_empty()
	# Public animé : phase, tribu, rang et tenue de chaque spectateur (shaders/foule.gdshader).
	batch.use_custom_data = not customs.is_empty()
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
		if batch.use_colors:
			batch.set_instance_color(i, colors[i])
		if batch.use_custom_data:
			batch.set_instance_custom_data(i, customs[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = material
	# Crowd and seats are subpixel details; avoid their thousands of shadow casters.
	if label == "VenueSeats" or label.begins_with("Spectators"):
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if label.begins_with("Spectators"):
		# Spectateurs levés et bras en l'air : au-dessus de la boîte calculée sur les places assises.
		instance.extra_cull_margin = 1.0
	v.add_child(instance)


static func _build_spectators(v: NativeMatchView, positions: Array[Vector3], rotations: Array[float], rng: RandomNumberGenerator) -> void:
	# Seated silhouettes with heads/shoulders, kept outside sporting presence.
	# Four bounded MultiMeshes animated by one shader (shaders/foule.gdshader): no per-spectator
	# nodes, physics or scripts. Supporters of each club (home majority, away block in one end
	# terrace) wear its shirt or wave its scarf; the crowd state comes from `foule` (match_foule.gd).
	var torsos: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var legs: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	var clothes: Array[Color] = []
	var skins: Array[Color] = []
	var trousers: Array[Color] = []
	var customs: Array[Color] = []
	var palette := [Color("243238"), Color("567078"), Color("92968c"), Color("b4b2a4"), Color("735252"), Color("46584f"), Color("38464f")]
	var skin_palette := [Color("c09a7b"), Color("986c50"), Color("d3b398"), Color("77533f")]
	var tribus := [0, 0, 0]
	# Tableau compact (copié à l'accès par la vue) : rempli ici, puis rendu à la vue.
	var tetes := v.foule_tetes
	for i in positions.size():
		var height := rng.randf_range(0.88, 1.12)
		var basis := Basis().rotated(Vector3.UP, rotations[i])
		var p := positions[i]
		torsos.append(Transform3D(basis * Basis.from_scale(Vector3(0.42, 0.62 * height, 0.31)), p + Vector3(0, 0.27 * height, 0)))
		heads.append(Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.92, 1.08)), p + Vector3(0, 0.73 * height, 0)))
		tetes.append(heads[-1].origin)
		legs.append(Transform3D(basis * Basis.from_scale(Vector3(0.35, 0.18, 0.58)), p + basis * Vector3(0, -0.12, 0.22)))
		clothes.append(palette[rng.randi_range(0, palette.size() - 1)])
		var skin: Color = skin_palette[rng.randi_range(0, skin_palette.size() - 1)]
		skins.append(skin)
		trousers.append(Color("293136"))
		# Tribu : bloc des visiteurs dans la tribune d'en-but côté x > 0, ailleurs le club qui reçoit.
		var tirage := rng.randf()
		var tribu := 2
		if p.x > 60.0:
			tribu = 1 if tirage < FOULE_VISITEURS_BLOC else (0 if tirage < FOULE_VISITEURS_BLOC + 0.2 else 2)
		else:
			tribu = 0 if tirage < FOULE_DOMICILE else (1 if tirage < FOULE_DOMICILE + 0.04 else 2)
		tribus[tribu] += 1
		var tenue := 0
		var habit := rng.randf()
		if tribu < 2:
			tenue = 1 if habit < FOULE_MAILLOTS else (2 if habit < FOULE_MAILLOTS + FOULE_ECHARPES else 0)
		if tenue > 0:
			v.foule_compte.tenues += 1
		var echarpe := tenue == 2
		# Bras levés (deux mains au-dessus de la tête) ou écharpe tendue, repliés au repos par le shader.
		arms.append(Transform3D(basis * Basis.from_scale(Vector3(0.78, 0.13, 0.04) if echarpe else Vector3(0.5, 0.3, 0.09)),
			p + Vector3(0, (0.73 + (0.36 if echarpe else 0.3)) * height, 0)))
		customs.append(Color(rng.randf(), float(tribu), rng.randf(), float(tenue)))
	v.foule_tetes = tetes
	var torso := BoxMesh.new()
	torso.size = Vector3.ONE
	var head := SphereMesh.new()
	head.radius = 0.145
	head.height = 0.32
	head.radial_segments = 6
	head.rings = 3
	v._foule_matieres.clear()
	for partie in 4:
		var matiere := ShaderMaterial.new()
		matiere.shader = load(NativeMatchView.FOULE_SHADER) as Shader
		matiere.set_shader_parameter("partie", partie)
		v._foule_matieres.append(matiere)
	_instance_batch(v, "SpectatorsTorso", torso, v._foule_matieres[0], torsos, clothes, customs)
	_instance_batch(v, "SpectatorsHead", head, v._foule_matieres[1], heads, skins, customs)
	_instance_batch(v, "SpectatorsSeatedLegs", torso, v._foule_matieres[2], legs, trousers, customs)
	_instance_batch(v, "SpectatorsArms", torso, v._foule_matieres[3], arms, skins, customs)
	var total := maxf(1.0, float(positions.size()))
	var repartition: Array[float] = [tribus[0] / total, tribus[1] / total, tribus[2] / total]
	v.foule.repartition = repartition
	v.foule_compte.total = positions.size()
	v.foule_compte.domicile = tribus[0]
	v.foule_compte.visiteurs = tribus[1]
	v.foule_compte.neutres = tribus[2]
	v._animer_foule(0.0)


const FOULE_DOMICILE := 0.62
const FOULE_VISITEURS_BLOC := 0.6
const FOULE_MAILLOTS := 0.32
const FOULE_ECHARPES := 0.22


## Lisibilité du ballon à la distance de la caméra TV (lot 5, 16 novembre 2026) : un peu plus
## grand que nature, crème lumineux et souligné d'un contour sombre de deux pixels environ.
## Ni halo ni cercle au sol dans les vues de retransmission (choix de Léo) ; le ballon reste
## dans les mains du porteur (les mains le tiennent par ses flancs, voir match_presentation.gd).
const BALLON_LISIBLE := 1.25
const BALLON_CONTOUR := "res://shaders/ballon_contour.gdshader"

static func _build_ball(v: NativeMatchView) -> void:
	v._ball = Node3D.new()
	v._ball.name = "Ball"
	v.add_child(v._ball)
	var corps := Node3D.new()
	corps.name = "BallBody"
	corps.scale = Vector3.ONE * BALLON_LISIBLE
	v._ball.add_child(corps)
	var ball := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.23
	shape.height = 0.46
	shape.radial_segments = 20
	shape.rings = 12
	ball.mesh = shape
	ball.scale = Vector3(0.87, 0.53, 0.53)
	var cuir := _material(Color("f8efcf"))
	# Légère émission : le ballon ne s'éteint pas dans l'ombre des joueurs.
	cuir.emission_enabled = true
	cuir.emission = Color("f8efcf")
	cuir.emission_energy_multiplier = 0.22
	var contour := ShaderMaterial.new()
	contour.shader = load(BALLON_CONTOUR)
	cuir.next_pass = contour
	ball.material_override = cuir
	corps.add_child(ball)
	# Original dark seams give rotation and hand contact a readable reference.
	for offset in [-0.095, 0.095]:
		var seam := MeshInstance3D.new()
		var stripe := TorusMesh.new()
		stripe.inner_radius = 0.101
		stripe.outer_radius = 0.108
		stripe.rings = 16
		stripe.ring_segments = 4
		seam.mesh = stripe
		seam.rotation.z = PI * 0.5
		seam.position.x = offset
		seam.material_override = _material(Color("263c43"))
		corps.add_child(seam)
	# A flat presentation halo keeps the small oval legible at fullfield scale.
	var halo := MeshInstance3D.new()
	v._ball_marker = halo
	var ring := TorusMesh.new()
	ring.inner_radius = 0.61
	ring.outer_radius = 0.66
	ring.rings = 20
	ring.ring_segments = 6
	halo.mesh = ring
	halo.material_override = _material(Color("e9bf5a"), true)
	v._ball.add_child(halo)
	v._ball_beacon = Tactique.construire_balise(v._ball)
	v._ball.visible = false
