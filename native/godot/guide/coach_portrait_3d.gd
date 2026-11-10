extends TextureRect

const MODEL_PATH := "res://guide/assets/gabi.glb"
const IDLE := &"Repos"
const APPROVAL := &"Approbation"
const GREETING := &"Salut"
const EXPLANATION := &"Explication"
const MICROGESTURES := [&"Ecoute", &"RegardCarnet"]
const BLEND_TIME := 0.20

var model: PackedScene
var reduced_motion := false
var _context := ""
var _approval_pending := false
var _viewport := SubViewport.new()
var _animations: AnimationPlayer
var _gesture_random := RandomNumberGenerator.new()
var _microgestures: Array[StringName] = []
var _next_microgesture := 0
var _microgesture_wait := 0.0
var _greeted := false

func _ready() -> void:
	set_process(false)
	name = "GabiPortrait3D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewport.name = "GabiPortraitViewport"
	_viewport.size = Vector2i(320, 320)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	texture = _viewport.get_texture()

	var stage := Node3D.new()
	stage.name = "GabiStage"
	_viewport.add_child(stage)
	var character := model.instantiate() as Node3D
	if character == null:
		push_error("Le GLB du guide doit fournir une scène 3D.")
		return
	stage.add_child(character)
	_animations = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animations == null or not _animations.has_animation(IDLE) or not _animations.has_animation(APPROVAL):
		push_error("Le GLB du guide doit fournir les animations Repos et Approbation.")
		return
	_animations.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
	for clip: StringName in [APPROVAL, GREETING, EXPLANATION] + MICROGESTURES:
		if not _animations.has_animation(clip): continue
		_animations.get_animation(clip).loop_mode = Animation.LOOP_NONE
		if clip in MICROGESTURES: _microgestures.append(clip)
	_gesture_random.randomize()
	if not _microgestures.is_empty():
		_next_microgesture = _gesture_random.randi_range(0, _microgestures.size() - 1)
	_animations.animation_finished.connect(_animation_finished)

	var studio := WorldEnvironment.new()
	studio.environment = Environment.new()
	studio.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	studio.environment.ambient_light_color = Color(0.83, 0.87, 0.89)
	studio.environment.ambient_light_energy = 0.81
	stage.add_child(studio)
	_light(stage, Vector3(-34, -33, 0), Color(1, 0.95, 0.91), 0.43)
	_light(stage, Vector3(-22, 43, 0), Color(0.71, 0.84, 1), 0.26)
	_light(stage, Vector3(-30, 160, 0), Color(1, 0.92, 0.77), 0.32)

	var camera := Camera3D.new()
	camera.name = "GabiPortraitCamera"
	stage.add_child(camera)
	camera.set_orthogonal(1.10, 0.1, 12.0)
	var target := Vector3(0, 1.39, 0)
	camera.position = target + Vector3(-0.55, 0.04, 3.45)
	camera.look_at(target)
	camera.make_current()

	visibility_changed.connect(_sync_visibility)
	_sync_visibility()

func _light(stage: Node3D, angle: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angle
	light.light_color = color
	light.light_energy = energy
	stage.add_child(light)

func set_context(id: String) -> void:
	if id == _context: return
	_context = id
	_approval_pending = not reduced_motion and id in ["composition", "resultat"]
	if is_visible_in_tree(): _sync_visibility()

func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion: return
	reduced_motion = value
	if value: _approval_pending = false
	_sync_visibility()

func set_speaking(_value: bool) -> void:
	pass

func set_articulation(_value: float) -> void:
	pass

func request_gesture(opening: bool) -> void:
	if not _can_animate() or _animations.current_animation in [APPROVAL, GREETING]: return
	if opening and not _greeted and _play_gesture(GREETING):
		_greeted = true
		return
	_play_gesture(EXPLANATION)

func _process(delta: float) -> void:
	_microgesture_wait -= delta
	if _microgesture_wait > 0.0: return
	var clip := _microgestures[_next_microgesture]
	_next_microgesture = (_next_microgesture + 1) % _microgestures.size()
	_play_gesture(clip)

func _sync_visibility() -> void:
	if _animations == null: return
	set_process(false)
	if not is_visible_in_tree():
		_animations.pause()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if reduced_motion:
		_animations.play(IDLE, 0.0)
		_animations.seek(0.0, true)
		_animations.pause()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var approval := _approval_pending
	_approval_pending = false
	if approval:
		_play_gesture(APPROVAL)
	else:
		_play_idle()

func _can_animate() -> bool:
	return _animations != null and is_visible_in_tree() and not reduced_motion

func _play_gesture(clip: StringName) -> bool:
	if not _can_animate() or not _animations.has_animation(clip): return false
	set_process(false)
	_animations.play(clip, BLEND_TIME)
	return true

func _play_idle() -> void:
	_animations.play(IDLE, BLEND_TIME)
	if _microgestures.is_empty(): return
	_microgesture_wait = _gesture_random.randf_range(7.0, 13.0)
	set_process(true)

func _animation_finished(_clip: StringName) -> void:
	if _can_animate(): _play_idle()
