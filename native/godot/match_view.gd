class_name NativeMatchView
extends Node3D
## Projection de présentation du moteur historique. Aucune règle ni physique ici.
## Adapter source : x 0..100 / y 0..70 -> x -50..50 / z -35..35.

const ATHLETE := "res://assets/match3d/quaternius-rugby-athlete.glb"
const BLEND_SECONDS := 0.55
const STADIUM_FONT := "res://fonts/BarlowCondensed-SemiBold.ttf"
const Presentation = preload("res://match_presentation.gd")
const Motion = preload("res://match_motion.gd")
const Kit = preload("res://match_kit.gd")
const Athlete = preload("res://match_athlete.gd")
const Contact = preload("res://match_contact.gd")
const Cut = preload("res://match_cut.gd")
var _players: Node3D
var _ball: Node3D
var _camera: Camera3D
var _athlete_scene: PackedScene
var _actors: Dictionary = {}
var _team_colors: Array[Color] = [Color("d43e47"), Color("6f9ac9")]
var _kits: Array[Dictionary] = []
var _camera_focus := Vector3.ZERO
var _camera_framed := false
var _camera_cut := true
var _ball_from := Vector3.ZERO
var _ball_from_basis := Basis.IDENTITY
var _ball_target := Vector3.ZERO
var _camera_mode := "tv"
var _paused := false
var _pending: Dictionary = {}
var _has_pending := false
var _venue_batches: Dictionary = {}
var _carrier_id := ""
var _kind := ""
var _quality := "balanced"
var _sun: DirectionalLight3D
var _ball_marker: Node3D
var _ball_attached := false
var _ball_travel := 1.0
var _grass: ShaderMaterial
var _contact_plan: Dictionary = {}


func _ready() -> void:
	name = "NativeMatchView"
	_athlete_scene = load(ATHLETE) as PackedScene
	_kits = Kit.resolve(_team_colors)
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
	set_quality(_quality)
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
	var ball_data: Dictionary = scene.get("ball", {})
	var has_ball := ball_data.has("x") and ball_data.has("y")
	var previous_carrier := _carrier_id
	_carrier_id = Presentation.carrier_id(scene) if has_ball else ""
	_kind = str(scene.get("kind", ""))
	var teams: Array = live.get("teams", [])
	var colors_changed := false
	for side in mini(teams.size(), 2):
		var club: Dictionary = teams[side]
		var presentation: Dictionary = club.get("presentation", {})
		var color := Color.from_string(str(presentation.get("color", club.get("color", "#eeeeee"))), _team_colors[side])
		if color != _team_colors[side]:
			_team_colors[side] = color
			colors_changed = true
	if colors_changed:
		# A home-colour change can also change the away contrast decision.
		_kits = Kit.resolve(_team_colors)
		Athlete.clear_palette()
		for entry: Dictionary in _actors.values():
			_recolor(entry.model, entry.side)
	_paused = live.get("paused", false) or live.get("finished", false) or live.get("atBreak", false)
	_contact_plan = Contact.plan(scene) if not _paused and has_ball else {}
	var carry_cut := (not _paused and _kind == "carry" and has_ball and _ball_attached
		and _carrier_id == previous_carrier and _contact_plan.is_empty())
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
		entry.holding = id == _carrier_id
		var can_cut: bool = carry_cut and entry.holding
		if not can_cut:
			entry.cut_direction = 0
			entry.cut_plant.clear()
		# A UI refresh is not a new sporting movement. Keep its current curve.
		if not (entry.target as Vector3).is_equal_approx(target):
			var incoming: Vector3 = entry.velocity
			if can_cut and incoming.is_zero_approx() and entry.cut_idle <= 0.3:
				incoming = (entry.target - entry.from) / BLEND_SECONDS
			entry.cut_direction = Cut.direction(incoming, target - entry.node.position, BLEND_SECONDS) if can_cut else 0
			entry.cut_plant.clear()
			entry.cut_idle = 0.0
			entry.from = entry.node.position
			entry.target = target
			entry.tangent = Motion.tangent(entry.velocity, target - entry.node.position, BLEND_SECONDS)
			entry.elapsed = 0.0
		if _paused:
			entry.node.position = target
			entry.from = target
			entry.velocity = Vector3.ZERO
			entry.tangent = Vector3.ZERO
			entry.elapsed = BLEND_SECONDS
			entry.cut_idle = BLEND_SECONDS
			entry.feet.clear()
			entry.grip = 1.0 if entry.holding else 0.0
		if entry.side != side:
			entry.side = side
			_recolor(entry.model, side)
	for id: String in _actors.keys():
		if not present.has(id):
			var actor: Node3D = _actors[id].node
			_players.remove_child(actor)
			actor.queue_free()
			_actors.erase(id)
	if has_ball:
		var next_target := _world(ball_data, 0.23)
		var ball_changed := not _ball_target.is_equal_approx(next_target) or previous_carrier != _carrier_id
		if not _ball.visible:
			_camera_cut = true
		# The first snapshot is a pose, not an invented pass from ground level.
		_ball_attached = not _carrier_id.is_empty() and (not _ball.visible or _paused or (previous_carrier == _carrier_id and _ball_attached))
		var continuing_reception := not _carrier_id.is_empty() and previous_carrier == _carrier_id and not _ball_attached
		if (ball_changed and not continuing_reception) or not _ball.visible:
			_ball_from = _ball.position if _ball.visible else next_target
			_ball_from_basis = _ball.global_basis
			_ball_target = next_target
			_ball_travel = 1.0 if _paused else 0.0
		if _paused:
			_ball_travel = 1.0
		_ball.visible = true
	else:
		_ball.visible = false
		_ball_attached = false
		_camera_cut = true


func set_camera(mode: String) -> void:
	var selected := mode if mode in ["tactical", "action"] else "tv"
	var changed := selected != _camera_mode
	_camera_mode = selected
	if is_instance_valid(_camera) and (changed or not _camera_framed):
		_fit_camera(0.0, true)


func _process(delta: float) -> void:
	for entry: Dictionary in _actors.values():
		var actor: Node3D = entry.node
		if entry.rig:
			Presentation.restore_contact(entry.rig, entry.contact_base)
			Cut.restore(entry.rig, entry.cut_pose)
		var previous := actor.position
		if entry.elapsed >= BLEND_SECONDS:
			entry.cut_idle = minf(BLEND_SECONDS, entry.cut_idle + delta)
		entry.elapsed = minf(BLEND_SECONDS, float(entry.elapsed) + delta)
		var progress: float = entry.elapsed / BLEND_SECONDS
		actor.position = Motion.position_at(entry.from, entry.target, entry.tangent, progress)
		entry.velocity = Motion.velocity_at(entry.from, entry.target, entry.tangent, progress, BLEND_SECONDS)
		var movement := actor.position - previous
		var speed := movement.length() / maxf(delta, 0.001)
		var moving := speed > 0.035 and not _paused
		var previous_heading := actor.rotation.y
		if moving:
			var change := angle_difference(actor.rotation.y, atan2(movement.x, movement.z))
			actor.rotation.y += clampf(change, -7.2 * delta, 7.2 * delta)
		var animation: AnimationPlayer = entry.animation
		if animation:
			# Hysteresis avoids changing support on every small speed fluctuation.
			entry.running = speed > (2.5 if entry.running else 3.3) if moving else false
			var clip: StringName = (entry.run if entry.running else entry.walk) if moving else entry.idle
			if not clip.is_empty() and animation.current_animation != clip:
				animation.play(clip, 0.18)
			# Frame-owned animation prevents an AnimationPlayer update from overwriting
			# the hand contact after the pose solver has run.
			animation.speed_scale = 1.0
			# Advance by travelled distance; no minimum cadence while the root creeps.
			var pose_delta := movement.length() / (1.6 if clip == entry.walk else 4.0) if moving else delta
			animation.advance(0.0 if _paused else pose_delta)
		if entry.rig and not _paused:
			Presentation.support_feet(actor, entry.rig, entry.feet, speed, angle_difference(previous_heading, actor.rotation.y))
			if entry.cut_direction != 0 and progress < 1.0:
				Cut.apply(actor, entry.rig, entry.cut_direction, progress, entry.cut_pose, entry.cut_plant)
	_update_contact(delta)
	_update_ball(delta)
	# Resolve upper-body contact after every source-animation update and after the
	# ball's continuous trajectory. A new receiver never pulls it across the pitch.
	for entry: Dictionary in _actors.values():
		var actor: Node3D = entry.node
		var rig: Skeleton3D = entry.rig
		var center := Presentation.ball_anchor(actor, rig) if rig else Vector3.ZERO
		var approaching: bool = entry.holding and _ball.visible and center.distance_to(_ball.global_position) < 0.38
		var can_grip: bool = entry.holding and (_ball_attached or approaching)
		entry.grip = move_toward(float(entry.grip), 1.0 if can_grip else 0.0, delta * 6.0)
		if rig and entry.grip > 0.0:
			if approaching and not _ball_attached:
				center = _ball.global_position
			Presentation.hold_ball(actor, rig, center, entry.grip)
	if _ball.visible:
		_ball_marker.global_position = Vector3(_ball.global_position.x, 0.028, _ball.global_position.z)
		_ball_marker.global_basis = Basis.IDENTITY
	_fit_camera(delta, _camera_cut)
	_camera_cut = false


func _update_contact(delta: float) -> void:
	var carrier: String = _contact_plan.get("carrier", "")
	var opponent: String = _contact_plan.get("opponent", "")
	var active := _ball_attached and _actors.has(carrier) and _actors.has(opponent)
	var strength := 0.0
	if active:
		strength = Contact.strength(_actors[carrier].node.position, _actors[opponent].node.position)
	for id: String in _actors:
		var entry: Dictionary = _actors[id]
		# Clear immediately on an excluded action/pause/removal; fade only within
		# the same eligible geometry. A stale pair must never keep an actor posed.
		if not active or id not in [carrier, opponent]:
			entry.contact_weight = 0.0
			continue
		entry.contact_weight = minf(strength, move_toward(float(entry.contact_weight), strength, delta * 5.0))
	if not active: return
	# Apply the carrier first so the opponent reads the same current chest pose,
	# irrespective of insertion order in the transmitted presence list.
	for id: String in [carrier, opponent]:
		var entry: Dictionary = _actors[id]
		var other: Dictionary = _actors[opponent if id == carrier else carrier]
		if entry.rig and other.rig:
			Presentation.brace_contact(entry.node, entry.rig, other.node, other.rig, entry.contact_weight, id == carrier, entry.contact_base)


func _update_ball(delta: float) -> void:
	if not _ball.visible:
		return
	_ball_travel = minf(1.0, _ball_travel + delta / BLEND_SECONDS)
	if not _carrier_id.is_empty() and _actors.has(_carrier_id) and _actors[_carrier_id].rig:
		var entry: Dictionary = _actors[_carrier_id]
		var anchor := Presentation.ball_anchor(entry.node, entry.rig)
		if _ball_travel >= 1.0:
			_ball_attached = true
		_ball.global_position = anchor if _ball_attached else _ball_from.lerp(anchor, _ball_travel)
		_ball.global_basis = entry.node.global_basis if _ball_attached else _ball_from_basis.slerp(entry.node.global_basis, _ball_travel)
	else:
		_ball_attached = false
		_ball.position = _ball_from.lerp(_ball_target, _ball_travel)
		# Only existing kick kinds receive an airborne arc; no inferred pass kind.
		if _kind in ["kick", "goal", "miss", "kickoff", "drop22", "goalLine"]:
			_ball.position.y += sin(_ball_travel * PI) * minf(6.0, _ball_from.distance_to(_ball_target) * 0.18)


func set_quality(profile: String) -> void:
	_quality = profile if profile in ["economy", "balanced", "detail"] else "balanced"
	if not is_node_ready():
		return
	# Godot's imported geometry LODs remain shared by the thirty actors.
	get_viewport().mesh_lod_threshold = {"economy": 4.0, "balanced": 2.0, "detail": 1.0}[_quality]
	if is_instance_valid(_sun):
		_sun.shadow_enabled = _quality != "economy"
	if _grass:
		_grass.set_shader_parameter("micro_detail", {"economy": 0.0, "balanced": 0.1, "detail": 0.16}[_quality])


func _fit_camera(delta: float = 0.0, cut: bool = false) -> void:
	if not is_instance_valid(_camera):
		return
	_camera_framed = true
	if _camera_mode != "tactical":
		var desired := _ball.global_position if _ball.visible else Vector3.ZERO
		if cut:
			_camera_focus = desired
		else:
			_camera_focus = _camera_focus.lerp(desired, 1.0 - exp(-5.0 * delta))
			# Bound the follow delay during a long authored pass; the ball must
			# stay in the comfortable middle area even at the in-goal corners.
			var lag := _camera_focus - desired
			_camera_focus = desired + lag.limit_length(3.0 if _camera_mode == "action" else 8.0)
		var offset := Vector3(5.0, 12.0, 18.0) if _camera_mode == "action" else Vector3(0, 55, 75)
		_camera.position = _camera_focus + offset
		_camera.look_at(_camera_focus)
		_camera.size = 16.0 if _camera_mode == "action" else 42.0
		return
	_camera_focus = Vector3.ZERO
	_camera.position = Vector3(0, 150, 5)
	_camera.look_at(Vector3.ZERO)
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_height := 0.0
	# Tactical retains the entire pitch and its five-metre presentation apron.
	for x in [-56.0, 56.0]:
		for z in [-41.0, 41.0]:
			var point := _camera.to_local(Vector3(x, 0, z))
			half_height = maxf(half_height, maxf(absf(point.y), absf(point.x) / aspect))
	_camera.size = maxf(half_height * 2.16, 88.0)


func _world(point: Dictionary, height: float = 0.0) -> Vector3:
	return Vector3(float(point.get("x", 50)) - 50.0, height, float(point.get("y", 35)) - 35.0)


func _clear_presence() -> void:
	for entry: Dictionary in _actors.values():
		_players.remove_child(entry.node)
		entry.node.queue_free()
	_actors.clear()
	_ball.visible = false
	_carrier_id = ""
	_contact_plan = {}
	_ball_attached = false
	_camera_cut = true
	_fit_camera(0.0, true)


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
	model.set_meta("athlete_id", id)
	# Imported source contains a 100x mesh transform; calibrate its real rest bounds.
	var bounds := _model_bounds(model, model)
	if bounds.size.y > 0.001:
		var calibration := 1.9 / bounds.size.y
		model.scale = Vector3.ONE * calibration
		model.position.y = -bounds.position.y * calibration
	Athlete.prepare(model)
	_recolor(model, side)
	var animation := _find_animation(model)
	var idle := StringName()
	var run := StringName()
	var walk := StringName()
	if animation:
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: StringName in animation.get_animation_list():
			if str(clip).ends_with("Man_Idle"):
				idle = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if str(clip).ends_with("Man_Run"):
				run = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if str(clip).ends_with("Man_Walk"):
				walk = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if not idle.is_empty():
			animation.play(idle)
	return {"node": actor, "model": model, "side": side, "from": target, "target": target,
		"elapsed": BLEND_SECONDS, "velocity": Vector3.ZERO, "tangent": Vector3.ZERO, "running": false,
		"feet": {}, "cut_direction": 0, "cut_idle": BLEND_SECONDS, "cut_pose": {}, "cut_plant": {},
		"contact_base": {}, "contact_weight": 0.0,
		"animation": animation, "idle": idle, "run": run, "walk": walk, "rig": Presentation.rig_for(model), "holding": false, "grip": 0.0}


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
		marker.material_override = _material(_kits[side].marker, true)
	Athlete.dress(model, _kits[side], str(model.get_meta("athlete_id", "")))

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
	settings.ambient_light_color = Color("c6cfd1")
	settings.ambient_light_energy = 0.43
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	_sun = sun
	# Neutral art lighting, not an assertion about the match's time or weather.
	sun.rotation_degrees = Vector3(-57, -24, 0)
	sun.light_color = Color("fff6e9")
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.14
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
	# One original shader, no external texture or time-dependent grass noise.
	var grass := ShaderMaterial.new()
	_grass = grass
	grass.shader = load("res://shaders/stadium_surface.gdshader") as Shader
	_box(Vector3(110, 0.12, 70), Vector3(0, -0.07, 0), grass).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
			_stadium_label("OVAL LEGACY 27" if board % 2 == 0 else "RUGBY MANAGER", Vector3(x, 0.65, side * 41.04), 0.017, PI if side > 0 else 0.0)
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
	_stadium_label("OVAL LEGACY 27", Vector3(0, 11.35, -54.6), 0.052)
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
	ball.scale = Vector3(0.87, 0.53, 0.53)
	ball.material_override = _material(Color("f6ebc6"))
	_ball.add_child(ball)
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
		_ball.add_child(seam)
	# A flat presentation halo keeps the small oval legible at fullfield scale.
	var halo := MeshInstance3D.new()
	_ball_marker = halo
	var ring := TorusMesh.new()
	ring.inner_radius = 0.61
	ring.outer_radius = 0.66
	ring.rings = 20
	ring.ring_segments = 6
	halo.mesh = ring
	halo.material_override = _material(Color("e9bf5a"), true)
	_ball.add_child(halo)
	_ball.visible = false
