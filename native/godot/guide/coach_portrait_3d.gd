extends TextureRect

const PrivateFiles = preload("res://donnees_privees.gd")
const MODEL_PATH := "res://guide/assets/gabi.glb"
## Gabi rigué par Mixamo, avec des gestes plus nombreux : fichier privé, hors dépôt public (licence
## Mixamo). CD_GABI_MIXAMO = chemin absolu de la scène .scn préparée par
## scripts/animations/convertir-gabi.gd ; à défaut, animations/gabi-mixamo.scn à côté de
## l'exécutable. Absent ou illisible : le Gabi d'origine, inchangé.
const MIXAMO_VARIABLE := "CD_GABI_MIXAMO"
const MIXAMO_FILE := "gabi-mixamo.scn"
const RENDER_SIZE := Vector2i(768, 768)
const IDLE := &"Repos"
const APPROVAL := &"Approbation"
const GREETING := &"Salut"
const EXPLANATION := &"Explication"
const MICROGESTURES := [&"Ecoute", &"RegardCarnet"]
const BLEND_TIME := 0.20
const PORTRAIT_SIZE := 1.10
const GREETING_SIZE := 1.30
const GREETING_OFFSET := -0.125
const MOUTH_SHAPES := [&"MouthOpen", &"MouthRound", &"MouthPress", &"MouthWide"]
## Rôle de chaque clip. Le Gabi Mixamo se reconnaît à son clip « repos ». Correspondances :
## Repos → repos, Approbation → approuve, Salut → salut, Explication → explique,
## Ecoute → reflechit, RegardCarnet → regarde_bas ; les autres clips ajoutent de la variété.
## Les microgestes se jouent dans l'ordre de la liste, à partir d'un point tiré au hasard :
## le bâillement n'y figure qu'une fois sur huit.
const CLIPS_ORIGINE := {
	"idle": [IDLE], "approval": [APPROVAL], "greeting": [GREETING],
	"explanation": [EXPLANATION], "microgestures": MICROGESTURES, "talk": [],
	"delay": Vector2(7.0, 13.0),
}
const CLIPS_MIXAMO := {
	"idle": [&"repos"], "approval": [&"approuve", &"approuve_fort"], "greeting": [&"salut"],
	"explanation": [&"explique", &"montre", &"insiste"],
	"microgestures": [&"regarde_bas", &"appui", &"reflechit", &"repos_respire",
		&"regarde_bas", &"appui", &"reflechit", &"baille"],
	"talk": [&"parle", &"parle_2", &"parle_3", &"parle_4"],
	# Demande de Léo : Gabi toujours en mouvement, d'où des pauses plus courtes entre les gestes.
	"delay": Vector2(3.0, 6.0),
}

var model: PackedScene
var reduced_motion := false
var _context := ""
var _approval_pending := false
var _viewport := SubViewport.new()
var _animations: AnimationPlayer
var _camera: Camera3D
var _camera_tween: Tween
var _gesture_random := RandomNumberGenerator.new()
var _microgestures: Array[StringName] = []
var _idle := IDLE
var _approvals: Array[StringName] = []
var _greetings: Array[StringName] = []
var _explanations: Array[StringName] = []
var _talks: Array[StringName] = []
var _microgesture_delay := Vector2(7.0, 13.0)
var _last_pick := {}
var _next_microgesture := 0
var _microgesture_wait := 0.0
var _greeted := false
var _speaking := false
var _mouth: MeshInstance3D
var _mouth_shapes := PackedInt32Array()
var _articulation := Vector4.ZERO

## Modèle à afficher : le Gabi Mixamo s'il est fourni et lisible, sinon celui du jeu (ou null).
static func load_model(game_dir := "") -> PackedScene:
	var mixamo := PrivateFiles.chemin(MIXAMO_VARIABLE, MIXAMO_FILE, game_dir)
	if not mixamo.is_empty():
		var scene := _load_mixamo(mixamo)
		if scene != null: return scene
		push_warning("%s : Gabi d'origine conservé (%s)" % [MIXAMO_VARIABLE, mixamo])
	return load(MODEL_PATH) as PackedScene if ResourceLoader.exists(MODEL_PATH, "PackedScene") else null

static func _load_mixamo(path: String) -> PackedScene:
	if not FileAccess.file_exists(path): return null
	# Scène Godot préparée hors jeu : pas de GLTFDocument à l'exécution (plantage Forward+ sous Windows).
	var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
	if scene == null: return null
	var probe := scene.instantiate()
	var player := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer if probe else null
	var usable := player != null and player.has_animation(CLIPS_MIXAMO.idle[0])
	if probe: probe.free()
	return scene if usable else null

func _ready() -> void:
	set_process(false)
	name = "GabiPortrait3D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_viewport.name = "GabiPortraitViewport"
	_viewport.size = RENDER_SIZE
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
	_apply_vertex_colors(character)
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.find_blend_shape_by_name(MOUTH_SHAPES[0]) < 0: continue
		_mouth = mesh
		for shape: StringName in MOUTH_SHAPES:
			_mouth_shapes.append(mesh.find_blend_shape_by_name(shape))
		break
	_animations = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips: Dictionary = CLIPS_MIXAMO if _animations != null and _animations.has_animation(CLIPS_MIXAMO.idle[0]) else CLIPS_ORIGINE
	_idle = clips.idle[0]
	_approvals = _available(clips.approval)
	if _animations == null or not _animations.has_animation(_idle) or _approvals.is_empty():
		push_error("Le GLB du guide doit fournir les animations Repos et Approbation.")
		_animations = null
		return
	_greetings = _available(clips.greeting)
	_explanations = _available(clips.explanation)
	_microgestures = _available(clips.microgestures)
	_talks = _available(clips.talk)
	_microgesture_delay = clips.delay
	_animations.get_animation(_idle).loop_mode = Animation.LOOP_LINEAR
	for clip: StringName in _approvals + _greetings + _explanations + _microgestures + _talks:
		_animations.get_animation(clip).loop_mode = Animation.LOOP_NONE
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

	_camera = Camera3D.new()
	_camera.name = "GabiPortraitCamera"
	stage.add_child(_camera)
	_camera.set_orthogonal(PORTRAIT_SIZE, 0.1, 12.0)
	var target := Vector3(0, 1.39, 0)
	_camera.position = target + Vector3(-0.55, 0.04, 3.45)
	_camera.look_at(target)
	_camera.make_current()

	visibility_changed.connect(_sync_visibility)
	_sync_visibility()

func _available(names: Array) -> Array[StringName]:
	var found: Array[StringName] = []
	for clip: StringName in names:
		if _animations.has_animation(clip): found.append(clip)
	return found

## Tirage au hasard dans un groupe de clips, sans rejouer le précédent du même groupe.
func _pick(pool: Array[StringName]) -> StringName:
	if pool.is_empty(): return &""
	var key := pool[0]
	var choices := pool.filter(func(clip: StringName) -> bool: return clip != _last_pick.get(key, &""))
	if choices.is_empty(): choices = pool
	var clip: StringName = choices[_gesture_random.randi_range(0, choices.size() - 1)]
	_last_pick[key] = clip
	return clip

func _apply_vertex_colors(character: Node3D) -> void:
	# Some imported materials ignore COLOR_0. In particular this turns the eyelids white.
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if mesh == null: continue
		for surface in mesh.get_surface_count():
			if (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) == 0: continue
			var material := instance.get_active_material(surface) as StandardMaterial3D
			if material == null or material.vertex_color_use_as_albedo: continue
			var colored := material.duplicate() as StandardMaterial3D
			colored.vertex_color_use_as_albedo = true
			instance.set_surface_override_material(surface, colored)

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

func set_speaking(value: bool) -> void:
	var changed := value != _speaking
	_speaking = value
	if not value: _articulation = Vector4.ZERO
	_sync_mouth()
	if changed: _sync_talk()

## Gabi Mixamo : pendant qu'il parle, des gestes de parole tirés au hasard s'enchaînent ; un geste
## en cours (salut, approbation, explication) se termine d'abord.
func _sync_talk() -> void:
	if _talks.is_empty() or not _can_animate(): return
	var current := StringName(_animations.current_animation)
	if _speaking and (current == _idle or current in _microgestures):
		_play_gesture(_pick(_talks))
	elif not _speaking and current in _talks:
		_play_idle()

func set_articulation(value: float, rounding: float = 0.0, press: float = 0.0, wide: float = 0.0) -> void:
	_articulation = Vector4(value, rounding, press, wide).clamp(Vector4.ZERO, Vector4.ONE)
	_sync_mouth()

func _sync_mouth() -> void:
	if _mouth == null: return
	var weights := _articulation if _speaking and _can_animate() else Vector4.ZERO
	for index in _mouth_shapes.size():
		if _mouth_shapes[index] >= 0:
			_mouth.set_blend_shape_value(_mouth_shapes[index], weights[index])

func request_gesture(opening: bool) -> void:
	if not _can_animate(): return
	var current := StringName(_animations.current_animation)
	if current in _approvals or current in _greetings: return
	if opening and not _greeted and _play_gesture(_pick(_greetings)):
		_greeted = true
		return
	_play_gesture(_pick(_explanations))

func _process(delta: float) -> void:
	_microgesture_wait -= delta
	if _microgesture_wait > 0.0: return
	var clip := _microgestures[_next_microgesture]
	_next_microgesture = (_next_microgesture + 1) % _microgestures.size()
	_play_gesture(clip)

func _sync_visibility() -> void:
	if _animations == null: return
	_sync_mouth()
	set_process(false)
	if not is_visible_in_tree():
		if _camera_tween != null: _camera_tween.kill()
		_animations.pause()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if reduced_motion:
		_frame_clip(_idle, false)
		_animations.play(_idle, 0.0)
		_animations.seek(0.0, true)
		_animations.pause()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var approval := _approval_pending
	_approval_pending = false
	if approval:
		_play_gesture(_pick(_approvals))
	elif _speaking and not _talks.is_empty():
		_play_gesture(_pick(_talks))
	else:
		_play_idle()

func _can_animate() -> bool:
	return _animations != null and is_visible_in_tree() and not reduced_motion

func _play_gesture(clip: StringName) -> bool:
	if not _can_animate() or clip.is_empty() or not _animations.has_animation(clip): return false
	set_process(false)
	_frame_clip(clip)
	_animations.play(clip, BLEND_TIME)
	return true

func _play_idle() -> void:
	_frame_clip(_idle)
	_animations.play(_idle, BLEND_TIME)
	if _microgestures.is_empty(): return
	_microgesture_wait = _gesture_random.randf_range(_microgesture_delay.x, _microgesture_delay.y)
	set_process(true)

func _frame_clip(clip: StringName, transition := true) -> void:
	var target_size := GREETING_SIZE if clip in _greetings else PORTRAIT_SIZE
	var target_offset := GREETING_OFFSET if clip in _greetings else 0.0
	if _camera_tween != null: _camera_tween.kill()
	if not transition:
		_camera.size = target_size
		_camera.h_offset = target_offset
		return
	if is_equal_approx(_camera.size, target_size) and is_equal_approx(_camera.h_offset, target_offset): return
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "size", target_size, BLEND_TIME)
	_camera_tween.tween_property(_camera, "h_offset", target_offset, BLEND_TIME)

func _animation_finished(_clip: StringName) -> void:
	if not _can_animate(): return
	if _speaking and not _talks.is_empty():
		_play_gesture(_pick(_talks))
	else:
		_play_idle()
