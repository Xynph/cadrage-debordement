class_name NativeMatchView
extends Node3D
## Projection de présentation du moteur historique. Aucune règle ni physique ici.
## Adapter source : x 0..100 / y 0..70 -> x -50..50 / z -35..35.

const ATHLETE := "res://assets/match3d/quaternius-rugby-athlete.glb"
const BLEND_SECONDS := 0.55
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


func _ready() -> void:
	name = "NativeMatchView"
	_athlete_scene = load(ATHLETE) as PackedScene
	_build_environment()
	_build_ground()
	_build_stadium()
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
	_paused = live.get("paused", false) or live.get("finished", false) or live.get("halftime", false)
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
	_camera.position = Vector3(0, 150, 5) if _camera_mode == "tactical" else Vector3(0, 85, 105)
	_camera.look_at(Vector3.ZERO)
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
	_camera.size = maxf(half_height * 2.16, 76.0 if _camera_mode == "tv" else 88.0)


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
	sky_material.sky_top_color = Color("718b9b")
	sky_material.sky_horizon_color = Color("d1d8d5")
	sky_material.ground_bottom_color = Color("29383a")
	sky_material.ground_horizon_color = Color("c5cfca")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bbcbd1")
	settings.ambient_light_energy = 0.45
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.95
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
	var dark := _material(Color("263b32"))
	_box(Vector3(200, 0.4, 160), Vector3(0, -0.45, 0), dark).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(128, 0.2, 94), Vector3(0, -0.2, 0), _material(Color("56635b"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var grass_a := _material(Color("3c7347"))
	var grass_b := _material(Color("427c4c"))
	for stripe in 11:
		_box(Vector3(10, 0.12, 80), Vector3(-50 + stripe * 10, -0.07, 0), grass_a if stripe % 2 == 0 else grass_b).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := _material(Color("e9ecdb"))
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
	var concrete := _material(Color("3b4549"))
	var step := _material(Color("55616a"))
	var seat := _material(Color("243b47"))
	var trim := _material(Color("b1b9b4"))
	for sign_ in [-1.0, 1.0]:
		# Low continuous terraces: deliberately generic, no claim of a real venue.
		for row in 8:
			var z: float = sign_ * (46.0 + row * 1.5)
			var height := 0.8 + row * 0.85
			_box(Vector3(124, height, 1.5), Vector3(0, height * 0.5, z), concrete)
			_box(Vector3(124, 0.13, 0.5), Vector3(0, height + 0.08, z), step)
			for block in 12:
				_box(Vector3(8.4, 0.65, 0.55), Vector3(-55 + block * 10, height + 0.4, z + sign_ * 0.4), seat)
		_box(Vector3(128, 0.3, 0.25), Vector3(0, 8.1, sign_ * 57.2), trim)
		_box(Vector3(128, 1.5, 0.4), Vector3(0, 7.4, sign_ * 58), concrete)
		# Rear canopy kept behind terraces so fullfield cameras retain touchlines.
		_box(Vector3(129, 0.45, 5), Vector3(0, 10.8, sign_ * 59), seat)
		for x in [-60.0, -30.0, 0.0, 30.0, 60.0]:
			_box(Vector3(0.3, 10.5, 0.3), Vector3(x, 5.3, sign_ * 60), concrete)
		for x in range(-54, 55, 9):
			_box(Vector3(8.6, 1.1, 0.2), Vector3(x, 0.65, sign_ * 41), concrete)
			_box(Vector3(5.5, 0.065, 0.03), Vector3(x, 0.7, sign_ * 40.88), trim)
	for sign_ in [-1.0, 1.0]:
		for row in 5:
			var height := 0.8 + row * 0.8
			_box(Vector3(1.4, height, 82), Vector3(sign_ * (64 + row * 1.4), height / 2, 0), concrete)
			_box(Vector3(0.5, 0.55, 78), Vector3(sign_ * (64 + row * 1.4), height + 0.3, 0), seat)
	for x in [-64.0, 64.0]:
		for z in [-44.0, 44.0]:
			_box(Vector3(0.45, 20, 0.45), Vector3(x, 10, z), trim)
			_box(Vector3(5.5, 1.7, 0.5), Vector3(x, 20, z), concrete)
			_box(Vector3(4.9, 1.1, 0.1), Vector3(x, 20, z - signf(z) * 0.3), _material(Color("f2e5bf"), true))


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
