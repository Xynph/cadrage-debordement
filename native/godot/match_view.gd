class_name NativeMatchView
extends Node3D
## Projection de présentation du moteur historique. Aucune règle ni physique ici.
## Adapter source : x 0..100 / y 0..70 -> x -50..50 / z -35..35.

const ATHLETE := "res://assets/match3d/quaternius-rugby-athlete.glb"
const BLEND_SECONDS := 0.55
const STADIUM_FONT := "res://fonts/BarlowCondensed-SemiBold.ttf"
var _players: Node3D
var _ball: Node3D
var _camera: Camera3D
var _athlete_scene: PackedScene
var _actors: Dictionary = {}
var _team_colors: Array[Color] = [Color("d43e47"), Color("6f9ac9")]
var _materials: Dictionary = {}
var _ball_from := Vector3.ZERO
var _ball_target := Vector3.ZERO
var _blend := 1.0
var _camera_mode := "tv"
var _paused := false
var _pending: Dictionary = {}
var _has_pending := false
var _venue_batches: Dictionary = {}


func _ready() -> void:
	name = "NativeMatchView"
	_athlete_scene = load(ATHLETE) as PackedScene
	_build_environment()
	_build_ground()
	_build_stadium()
	_flush_venue_boxes()
	_players = Node3D.new()
	_players.name = "Players"
	add_child(_players)
	_build_ball()
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.5
	_camera.far = 500.0
	add_child(_camera)
	_camera.current = true
	set_camera(_camera_mode)
	if _has_pending:
		apply_frame(_pending)
		_pending = {}
		_has_pending = false


func apply_frame(live: Dictionary) -> void:
	if not is_node_ready():
		_pending = live.duplicate(true)
		_has_pending = true
		return
	var scene: Dictionary = live.get("scene", {})
	if scene.is_empty() or not scene.get("players", null) is Array:
		_clear_presence()
		return
	var teams: Array = live.get("teams", [])
	for side in mini(teams.size(), 2):
		var club: Dictionary = teams[side]
		var presentation: Dictionary = club.get("presentation", {})
		var color := Color.from_string(str(presentation.get("color", club.get("color", "#eeeeee"))), _team_colors[side])
		if color != _team_colors[side]:
			_team_colors[side] = color
			_materials.clear()
			for entry: Dictionary in _actors.values():
				if entry.side == side:
					_recolor(entry.model, side)
	_paused = live.get("paused", false) or live.get("finished", false) or live.get("atBreak", false)
	var present: Dictionary = {}
	for player: Dictionary in scene.players:
		var id := str(player.get("id", ""))
		var side := int(player.get("side", -1))
		if id.is_empty() or side not in [0, 1] or present.size() >= 30:
			continue
		present[id] = true
		var target := _world(player)
		if not _actors.has(id):
			_actors[id] = _make_actor(id, side, target)
		var entry: Dictionary = _actors[id]
		entry.from = entry.node.position
		entry.target = target
		if entry.side != side:
			entry.side = side
			_recolor(entry.model, side)
	for id: String in _actors.keys():
		if not present.has(id):
			var actor: Node3D = _actors[id].node
			_players.remove_child(actor)
			actor.queue_free()
			_actors.erase(id)
	var ball_data: Dictionary = scene.get("ball", {})
	if ball_data.has("x") and ball_data.has("y"):
		_ball_from = _ball.position if _ball.visible else _world(ball_data, 0.23)
		_ball_target = _world(ball_data, 0.23)
		_ball.position = _ball_from
		_ball.visible = true
	else:
		_ball.visible = false
	_blend = 0.0


func set_camera(mode: String) -> void:
	_camera_mode = "tactical" if mode == "tactical" else "tv"
	if not is_instance_valid(_camera):
		return
	_camera.position = Vector3(0, 150, 5) if _camera_mode == "tactical" else Vector3(0, 92, 125)
	# A little headroom reveals the far grandstand without hiding an in-goal.
	_camera.look_at(Vector3.ZERO if _camera_mode == "tactical" else Vector3(0, 3, -3))
	_fit_camera()


func _process(delta: float) -> void:
	_fit_camera()
	_blend = minf(1.0, _blend + delta / BLEND_SECONDS)
	for entry: Dictionary in _actors.values():
		var actor: Node3D = entry.node
		var previous := actor.position
		actor.position = (entry.from as Vector3).lerp(entry.target, _blend)
		var movement := actor.position - previous
		var moving := movement.length_squared() > 0.00001 and not _paused
		if moving:
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(movement.x, movement.z), minf(delta * 9.0, 1.0))
		var animation: AnimationPlayer = entry.animation
		if animation:
			var clip: StringName = entry.run if moving else entry.idle
			if not clip.is_empty() and animation.current_animation != clip:
				animation.play(clip, 0.18)
			animation.speed_scale = 1.0
	if _ball.visible:
		_ball.position = _ball_from.lerp(_ball_target, _blend)


func _fit_camera() -> void:
	if not is_instance_valid(_camera):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_height := 0.0
	# Fit all four edges, including the five-metre presentation apron, at any UI ratio.
	for x in [-56.0, 56.0]:
		for z in [-41.0, 41.0]:
			var point := _camera.to_local(Vector3(x, 0, z))
			half_height = maxf(half_height, maxf(absf(point.y), absf(point.x) / aspect))
	_camera.size = maxf(half_height * 2.16, 86.0 if _camera_mode == "tv" else 88.0)


func _world(point: Dictionary, height: float = 0.0) -> Vector3:
	return Vector3(float(point.get("x", 50)) - 50.0, height, float(point.get("y", 35)) - 35.0)


func _clear_presence() -> void:
	for entry: Dictionary in _actors.values():
		_players.remove_child(entry.node)
		entry.node.queue_free()
	_actors.clear()
	_ball.visible = false


func _make_actor(id: String, side: int, target: Vector3) -> Dictionary:
	var actor := Node3D.new()
	actor.name = "Athlete_" + id.validate_node_name()
	_players.add_child(actor)
	actor.position = target
	actor.rotation.y = PI * 0.5 if side == 0 else -PI * 0.5
	# Discreet team-colour footprint remains readable in the fullfield UI viewport.
	var marker := MeshInstance3D.new()
	marker.name = "TeamMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.36
	ring.outer_radius = 0.5
	ring.rings = 16
	ring.ring_segments = 6
	marker.mesh = ring
	marker.position.y = 0.025
	marker.scale.y = 0.12
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor.add_child(marker)
	var model := _athlete_scene.instantiate() as Node3D
	actor.add_child(model)
	# Imported source contains a 100x mesh transform; calibrate its real rest bounds.
	var bounds := _model_bounds(model, model)
	if bounds.size.y > 0.001:
		var calibration := 1.9 / bounds.size.y
		model.scale = Vector3.ONE * calibration
		model.position.y = -bounds.position.y * calibration
	_recolor(model, side)
	var animation := _find_animation(model)
	var idle := StringName()
	var run := StringName()
	if animation:
		for clip: StringName in animation.get_animation_list():
			if str(clip).ends_with("Man_Idle"):
				idle = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if str(clip).ends_with("Man_Run"):
				run = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if not idle.is_empty():
			animation.play(idle)
	return {"node": actor, "model": model, "side": side, "from": target, "target": target,
		"animation": animation, "idle": idle, "run": run}


func _model_bounds(node: Node3D, origin: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var relative := origin.global_transform.affine_inverse() * mesh.global_transform
		var part: AABB = relative * mesh.get_aabb()
		result = result.merge(part) if found else part
		found = true
	return result


func _find_animation(node: Node) -> AnimationPlayer:
	for child: Node in node.get_children():
		if child is AnimationPlayer:
			return child
		var nested := _find_animation(child)
		if nested:
			return nested
	return null


func _recolor(model: Node3D, side: int) -> void:
	var marker := model.get_parent().get_node_or_null("TeamMarker") as MeshInstance3D
	if marker:
		marker.material_override = _material(_team_colors[side], true)
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if not source:
				continue
			var key := str(side) + ":" + source.resource_name
			if not _materials.has(key):
				var material := source.duplicate() as StandardMaterial3D
				material.metallic = 0.0
				material.roughness = 0.9
				match source.resource_name:
					"Shirt": material.albedo_color = _team_colors[side]
					"Shirt2": material.albedo_color = _team_colors[side].lightened(0.4)
					"Pants": material.albedo_color = Color("202b35") if side == 0 else Color("ede9dc")
					"Socks": material.albedo_color = _team_colors[side]
				_materials[key] = material
			mesh.set_surface_override_material(surface, _materials[key])


func _build_environment() -> void:
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
	settings.ambient_light_color = Color("c4cdd0")
	settings.ambient_light_energy = 0.52
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	# Neutral art lighting, not an assertion about the match's time or weather.
	sun.rotation_degrees = Vector3(-57, -24, 0)
	sun.light_color = Color("fff4e2")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.65
	add_child(sun)


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _box(size: Vector3, position_: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position_
	if size.y < 0.1:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _build_ground() -> void:
	var dark := _material(Color("202b2c"))
	_box(Vector3(220, 0.4, 180), Vector3(0, -0.45, 0), dark).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(135, 0.2, 96), Vector3(0, -0.2, 0), _material(Color("464c49"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(118, 0.1, 80), Vector3(0, -0.09, 0), _material(Color("284c31"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# One deterministic, mipmapped texture shared by both mowing directions.
	var grain := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var turf_rng := RandomNumberGenerator.new()
	turf_rng.seed = 80731
	for y in 128:
		for x in 128:
			var shade := turf_rng.randf_range(0.84, 1.0)
			grain.set_pixel(x, y, Color(shade, shade, shade))
	grain.generate_mipmaps()
	var turf_texture := ImageTexture.create_from_image(grain)
	var grass_a := _material(Color("32633d"))
	var grass_b := _material(Color("386c43"))
	for grass: StandardMaterial3D in [grass_a, grass_b]:
		grass.albedo_texture = turf_texture
		grass.uv1_scale = Vector3(10, 60, 1)
		grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for stripe in 11:
		_box(Vector3(10, 0.12, 70), Vector3(-50 + stripe * 10, -0.07, 0), grass_a if stripe % 2 == 0 else grass_b).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := _material(Color("efefdf"))
	for z in [-35.0, 35.0]:
		_box(Vector3(110, 0.018, 0.16), Vector3(0, 0.008, z), paint)
	for x in [-55.0, -50.0, -28.0, 0.0, 28.0, 50.0, 55.0]:
		_box(Vector3(0.16, 0.018, 70), Vector3(x, 0.008, 0), paint)
	for x in [-45.0, -10.0, 10.0, 45.0]:
		for z in range(-32, 33, 8):
			_box(Vector3(0.13, 0.018, 3), Vector3(x, 0.009, z), paint)
	for z in [-30.0, -20.0, 20.0, 30.0]:
		for x in range(-45, 46, 10):
			_box(Vector3(3, 0.018, 0.13), Vector3(x, 0.009, z), paint)
	for x in [-50.0, 50.0]:
		for z in [-2.8, 2.8]:
			_box(Vector3(0.17, 12, 0.17), Vector3(x, 6, z), paint)
			_box(Vector3(0.42, 1.6, 0.42), Vector3(x, 0.8, z), _material(Color("263b49")))
		_box(Vector3(0.17, 0.17, 5.6), Vector3(x, 3, 0), paint)
	for x in [-50.0, 50.0]:
		for z in [-35.0, 35.0]:
			_box(Vector3(0.07, 1.4, 0.07), Vector3(x, 0.7, z), paint)
			_box(Vector3(0.48, 0.3, 0.025), Vector3(x + 0.2, 1.3, z), _material(Color("e1ba66")))


func _build_stadium() -> void:
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
				_venue_box(Vector3(14.1, height, 1.24), Vector3(center, height * 0.5, z), concrete)
				_venue_box(Vector3(14.1, 0.08, 0.17), Vector3(center, height + 0.05, z - side * 0.55), ivory)
				for place in 20:
					var x := center - 6.65 + place * 0.7
					var sitting := Vector3(x, height + 0.43, z)
					seat_transforms.append(Transform3D(Basis().rotated(Vector3.UP, PI if side > 0 else 0), sitting))
					if rng.randf() > 0.22:
						spectator_positions.append(sitting + Vector3(rng.randf_range(-0.06, 0.06), 0.05, 0.08 * side))
						spectator_rotations.append(PI if side > 0 else 0.0)
			# Recesses remain behind seating, no spurious actors in the technical area.
			_venue_box(Vector3(2.1, 2.6, 1.4), Vector3(center + 8, 1.2, side * 45.6), anthracite)
			for stair in 20:
				var height := 0.32 + stair * 0.37
				_venue_box(Vector3(1.6, height, 0.62), Vector3(center + 8, height * 0.5, side * (45.7 + stair * 0.62)), concrete)
				_venue_box(Vector3(1.6, 0.025, 0.1), Vector3(center + 8, height + 0.02, side * (45.42 + stair * 0.62)), aisle)
			_venue_beam(Vector3(center + 8, 2.4, side * 47), Vector3(center + 8, 8.2, side * 56.8), 0.07, steel)
		# Continuous rear concourse and a restrained floating canopy.
		_venue_box(Vector3(132, 8.8, 1.0), Vector3(0, 4.2, side * 60.4), anthracite)
		_venue_box(Vector3(132, 0.28, 5.5), Vector3(0, 8.7, side * 59), concrete)
		_venue_box(Vector3(133, 0.38, 8.5), Vector3(0, 12.4, side * 59.1), roof)
		_venue_box(Vector3(133, 0.65, 0.22), Vector3(0, 12.3, side * 54.8), anthracite)
		_venue_box(Vector3(132, 0.09, 0.11), Vector3(0, 11.99, side * 54.67), lamp)
		for x in range(-64, 65, 16):
			_venue_box(Vector3(0.22, 12.4, 0.22), Vector3(x, 6.1, side * 61), steel)
			_venue_beam(Vector3(x, 9.5, side * 61), Vector3(x, 12.1, side * 54.8), 0.15, steel)
			_venue_box(Vector3(0.1, 0.18, 8.4), Vector3(x, 12.7, side * 59.1), steel)
		# Original perimeter boards, not real sponsors or fictional attendance.
		for board in 8:
			var x := -56.0 + board * 16.0
			_venue_box(Vector3(15.5, 1.05, 0.22), Vector3(x, 0.58, side * 41.2), anthracite)
			_venue_box(Vector3(15.5, 0.06, 0.24), Vector3(x, 1.13, side * 41.2), ivory)
			_stadium_label("OVAL LEGACY" if board % 2 == 0 else "RUGBY MANAGER", Vector3(x, 0.65, side * 41.04), 0.017, PI if side > 0 else 0.0)
		# Modest end terraces leave both in-goals unobstructed.
		for row in 7:
			var height := 0.65 + row * 0.72
			var x: float = side * (65.2 + row * 1.25)
			_venue_box(Vector3(1.25, height, 85), Vector3(x, height * 0.5, 0), concrete)
			_venue_box(Vector3(0.15, 0.07, 85), Vector3(x - side * 0.54, height + 0.04, 0), ivory)
			for place in 112:
				var z := -41.6 + place * 0.75
				if place % 28 < 3:
					continue
				var sitting := Vector3(x, height + 0.43, z)
				seat_transforms.append(Transform3D(Basis().rotated(Vector3.UP, -side * PI * 0.5), sitting))
				if rng.randf() > 0.3:
					spectator_positions.append(sitting)
					spectator_rotations.append(-side * PI * 0.5)
		_venue_box(Vector3(0.4, 1.1, 87), Vector3(side * 74, 5.3, 0), anthracite)
		_venue_box(Vector3(0.14, 0.12, 87), Vector3(side * 73.8, 5.9, 0), steel)
		for z in [-22.0, 22.0]:
			_venue_box(Vector3(0.22, 1.05, 21), Vector3(side * 60.1, 0.58, z), anthracite)
		# Empty technical shelters are architecture, not invented staff/substitutes.
		_venue_box(Vector3(11.5, 0.14, 2.2), Vector3(side * 18, 2.2, 43.1), ivory)
		_venue_box(Vector3(11.5, 2.2, 0.18), Vector3(side * 18, 1.1, 44.1), anthracite)
		for x in [-5.6, 5.6]:
			_venue_box(Vector3(0.12, 2.2, 2.2), Vector3(side * 18 + x, 1.1, 43.1), steel)
	# Four compact light heads. No expensive spotlights, GI or volumetric effects.
	for x in [-62.0, 62.0]:
		for z in [-43.5, 43.5]:
			_venue_box(Vector3(0.24, 18, 0.24), Vector3(x, 9, z), steel)
			_venue_box(Vector3(3.7, 1.1, 0.38), Vector3(x, 18, z), anthracite)
			for bulb in 5:
				_venue_box(Vector3(0.49, 0.58, 0.06), Vector3(x - 1.4 + bulb * 0.7, 18.03, z - signf(z) * 0.22), lamp)
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.52, 0.55, 0.43)
	_instance_batch("VenueSeats", seat_mesh, seat, seat_transforms)
	_build_spectators(spectator_positions, spectator_rotations, rng)
	_venue_box(Vector3(43, 3.8, 0.24), Vector3(0, 10.6, -54.8), anthracite)
	_stadium_label("OVAL LEGACY  /  RUGBY MANAGER", Vector3(0, 11.35, -54.6), 0.052)
	_stadium_label("LE RUGBY SE JOUE ENSEMBLE", Vector3(0, 9.4, -54.6), 0.018)


func _stadium_label(text: String, position_: Vector3, pixel_size: float, yaw: float = 0.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load(STADIUM_FONT) as Font
	label.font_size = 48
	label.pixel_size = pixel_size
	label.position = position_
	label.rotation.y = yaw
	label.modulate = Color("e5e3d5")
	label.outline_size = 0
	label.no_depth_test = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


func _venue_box(size: Vector3, position_: Vector3, material: Material, basis: Basis = Basis.IDENTITY) -> void:
	var key := material.get_instance_id()
	if not _venue_batches.has(key):
		_venue_batches[key] = {"material": material, "transforms": []}
	_venue_batches[key].transforms.append(Transform3D(basis * Basis.from_scale(size), position_))


func _venue_beam(from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var delta := to - from
	_venue_box(Vector3(width, delta.length(), width), (from + to) * 0.5, material, Basis(Quaternion(Vector3.UP, delta.normalized())))


func _flush_venue_boxes() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var index := 0
	for batch: Dictionary in _venue_batches.values():
		_instance_batch("VenueStructure%d" % index, cube, batch.material, batch.transforms)
		index += 1
	_venue_batches.clear()


func _instance_batch(label: String, mesh: Mesh, material: Material, transforms: Array, colors: Array[Color] = []) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = not colors.is_empty()
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
		if batch.use_colors:
			batch.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = material
	# Crowd and seats are subpixel details; avoid their thousands of shadow casters.
	if label == "VenueSeats" or label.begins_with("Spectators"):
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_spectators(positions: Array[Vector3], rotations: Array[float], rng: RandomNumberGenerator) -> void:
	# Static seated silhouettes with heads/shoulders, kept outside sporting presence.
	# Three bounded MultiMeshes; no per-spectator nodes, physics or animation.
	var torsos: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var legs: Array[Transform3D] = []
	var clothes: Array[Color] = []
	var skins: Array[Color] = []
	var trousers: Array[Color] = []
	var palette := [Color("243238"), Color("567078"), Color("92968c"), Color("b4b2a4"), Color("735252"), Color("46584f"), Color("38464f")]
	var skin_palette := [Color("c09a7b"), Color("986c50"), Color("d3b398"), Color("77533f")]
	for i in positions.size():
		var height := rng.randf_range(0.88, 1.12)
		var basis := Basis().rotated(Vector3.UP, rotations[i])
		var p := positions[i]
		torsos.append(Transform3D(basis * Basis.from_scale(Vector3(0.42, 0.62 * height, 0.31)), p + Vector3(0, 0.27 * height, 0)))
		heads.append(Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.92, 1.08)), p + Vector3(0, 0.73 * height, 0)))
		legs.append(Transform3D(basis * Basis.from_scale(Vector3(0.35, 0.18, 0.58)), p + basis * Vector3(0, -0.12, 0.22)))
		clothes.append(palette[rng.randi_range(0, palette.size() - 1)])
		skins.append(skin_palette[rng.randi_range(0, skin_palette.size() - 1)])
		trousers.append(Color("293136"))
	var coloured := _material(Color.WHITE)
	coloured.vertex_color_use_as_albedo = true
	var torso := BoxMesh.new()
	torso.size = Vector3.ONE
	var head := SphereMesh.new()
	head.radius = 0.145
	head.height = 0.32
	head.radial_segments = 6
	head.rings = 3
	_instance_batch("SpectatorsTorso", torso, coloured, torsos, clothes)
	_instance_batch("SpectatorsHead", head, coloured, heads, skins)
	_instance_batch("SpectatorsSeatedLegs", torso, coloured, legs, trousers)


func _build_ball() -> void:
	_ball = Node3D.new()
	_ball.name = "Ball"
	add_child(_ball)
	var ball := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.23
	shape.height = 0.46
	shape.radial_segments = 20
	shape.rings = 12
	ball.mesh = shape
	ball.scale = Vector3(1.7, 0.85, 0.85)
	ball.material_override = _material(Color("f6ebc6"))
	_ball.add_child(ball)
	# A flat presentation halo keeps the small oval legible at fullfield scale.
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.66
	ring.rings = 20
	ring.ring_segments = 6
	halo.mesh = ring
	halo.position.y = -0.19
	halo.material_override = _material(Color("e9bf5a"), true)
	_ball.add_child(halo)
	_ball.visible = false
