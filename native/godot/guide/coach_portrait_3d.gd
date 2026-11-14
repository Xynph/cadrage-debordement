extends TextureRect

const PrivateFiles = preload("res://donnees_privees.gd")
const Moments = preload("res://guide/gabi_moments.gd")
const Visage = preload("res://guide/gabi_visage.gd")
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
## Le Gabi Mixamo se reconnaît à son clip « repos ». Les gestes de chaque moment (accueil,
## consigne, bonne ou mauvaise nouvelle, question…) viennent de gabi_moments.gd : un geste correspond
## toujours au contexte ; le hasard ne choisit qu'entre gestes équivalents d'une même catégorie.
const CLIPS_ORIGINE := {
	"profile": "origine", "idle": [IDLE], "greeting": [GREETING], "talk": [],
	"microgestures": MICROGESTURES, "rare": [], "negative": MICROGESTURES,
	"delay": Vector2(7.0, 13.0),
}
const CLIPS_MIXAMO := {
	"profile": "mixamo", "idle": [&"repos"], "greeting": [&"salut"],
	"talk": [&"parle", &"parle_2", &"parle_3", &"parle_4", &"parle_5", &"parle_7", &"parle_8"],
	"microgestures": Moments.ATTENTE.mixamo, "rare": Moments.ATTENTE.mixamo_rares,
	"negative": Moments.ATTENTE.mixamo_negatif,
	# Demande de Léo : Gabi toujours en mouvement, d'où des pauses plus courtes entre les gestes.
	"delay": Vector2(3.0, 6.0),
}
## Un geste rare (tablette, bâillement) au plus une fois sur RARE_EVERY petits gestes d'attente.
const RARE_EVERY := 6
## Studio du portrait (demande de Léo : Gabi paraissait trop sombre et trop rouge). Ambiance et
## remplissage moins froids (blanc chaud au lieu de bleuté), lumière principale plus forte, et
## courbe de rendu AgX : sans elle, en éclaircissant, le canal rouge de la peau sature et le visage
## vire à l'orange. Les couleurs (textures, matériaux) du personnage ne changent pas.
## Avant : ambiance (0,83 ; 0,87 ; 0,89) × 0,81, principale (1 ; 0,95 ; 0,91) × 0,43, remplissage
## (0,71 ; 0,84 ; 1) × 0,26, contre-jour (1 ; 0,92 ; 0,77) × 0,32, rendu linéaire.
const AMBIENT := {"color": Color(0.95, 0.93, 0.90), "energy": 1.0}
const TONEMAP := {"mode": Environment.TONE_MAPPER_AGX, "exposure": 1.25}
const LIGHTS := [
	{"angle": Vector3(-34, -33, 0), "color": Color(1.0, 0.95, 0.88), "energy": 0.8},  # principale
	{"angle": Vector3(-22, 43, 0), "color": Color(0.94, 0.95, 1.0), "energy": 0.34},   # remplissage
	{"angle": Vector3(-30, 160, 0), "color": Color(1.0, 0.93, 0.80), "energy": 0.36},  # contre-jour
]

var model: PackedScene
## Cadrage : « portrait » (bulle du mode grand), « medaillon » (buste serré), « visage » (tête et haut des
## épaules, pour le disque du bandeau) ou « pied » (Gabi debout en entier, zone de Gabi au Bureau).
## Hors « portrait », la caméra est fixe (pas de zoom pendant un salut) et le rendu suit la taille affichée
## (set_render_size) : net sans calculer plus de pixels que nécessaire.
var framing := "portrait"
const MEDAILLON := {"size": 0.70, "target": Vector3(0, 1.56, 0), "render": Vector2i(320, 320), "offset": 0.07, "side": -0.32}
const CADRAGES := {
	"medaillon": MEDAILLON,
	"visage": {"size": 0.44, "target": Vector3(0, 1.655, 0), "render": Vector2i(192, 192), "offset": 0.03, "side": -0.24},
	"pied": {"size": 1.96, "target": Vector3(0, 0.95, 0), "render": Vector2i(420, 640), "offset": 0.0, "side": -0.62},
}
var _render_size := Vector2i.ZERO
var reduced_motion := false
var _context := ""
var _profile := "origine"
var _moment := {"id": "", "categorie": "consigne", "ton": Moments.NEUTRE}
var _moment_pending := false
var _moment_clips: Array[StringName] = []
var visage: Node
var _viewport := SubViewport.new()
var _animations: AnimationPlayer
var _camera: Camera3D
var _camera_tween: Tween
var _gesture_random := RandomNumberGenerator.new()
var _microgestures: Array[StringName] = []
var _idle := IDLE
var _greetings: Array[StringName] = []
var _talks: Array[StringName] = []
var _rare: Array[StringName] = []
var _negative_waits: Array[StringName] = []
var _since_rare := 0
var _microgesture_delay := Vector2(7.0, 13.0)
var _last_pick := {}
var _last_played := &""
var _microgesture_wait := 0.0
var _greeted := false
var _speaking := false
var _mouth: MeshInstance3D
var _mouth_shapes := PackedInt32Array()
var _articulation := Vector4.ZERO
## Lèvres qui bougent sans voix (bulle affichée en mode texte ou muet) : durée restante, syllabe en cours.
var _mime_left := 0.0
var _mime_time := 0.0
var _mime_syllable := -1
var _mime_shape := Vector2.ZERO

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
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.find_blend_shape_by_name(MOUTH_SHAPES[0]) < 0: continue
		_mouth = mesh
		for shape: StringName in MOUTH_SHAPES:
			_mouth_shapes.append(mesh.find_blend_shape_by_name(shape))
		break
	# Regard, clignements et sourire : avant les matériaux (les yeux peuvent changer de maillage).
	visage = Visage.new()
	add_child(visage)
	visage.setup(character, _mouth)
	_apply_vertex_colors(character)
	_animations = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips: Dictionary = CLIPS_MIXAMO if _animations != null and _animations.has_animation(CLIPS_MIXAMO.idle[0]) else CLIPS_ORIGINE
	_idle = clips.idle[0]
	_profile = clips.profile
	if _animations == null or not _animations.has_animation(_idle) or not _animations.has_animation(Moments.gestures("approbation", _profile)[0]):
		push_error("Le GLB du guide doit fournir les animations Repos et Approbation.")
		_animations = null
		return
	_greetings = _available(clips.greeting)
	_microgestures = _available(clips.microgestures)
	_rare = _available(clips.rare)
	_negative_waits = _available(clips.negative)
	_talks = _available(clips.talk)
	_microgesture_delay = clips.delay
	for category: String in Moments.CATEGORIES:
		for clip: StringName in _available(Moments.gestures(category, _profile)):
			if clip not in _moment_clips: _moment_clips.append(clip)
	_animations.get_animation(_idle).loop_mode = Animation.LOOP_LINEAR
	for clip: StringName in _moment_clips + _greetings + _microgestures + _rare + _talks:
		_animations.get_animation(clip).loop_mode = Animation.LOOP_NONE
	_gesture_random.randomize()
	_animations.animation_finished.connect(_animation_finished)

	var studio := WorldEnvironment.new()
	studio.environment = Environment.new()
	studio.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	studio.environment.ambient_light_color = AMBIENT.color
	studio.environment.ambient_light_energy = AMBIENT.energy
	studio.environment.tonemap_mode = TONEMAP.mode
	studio.environment.tonemap_exposure = TONEMAP.exposure
	stage.add_child(studio)
	for light: Dictionary in LIGHTS:
		_light(stage, light.angle, light.color, light.energy)

	_camera = Camera3D.new()
	_camera.name = "GabiPortraitCamera"
	stage.add_child(_camera)
	_camera.set_orthogonal(PORTRAIT_SIZE, 0.1, 12.0)
	var target := Vector3(0, 1.39, 0)
	_camera.position = target + Vector3(-0.55, 0.04, 3.45)
	_camera.look_at(target)
	_camera.make_current()
	if framing != "portrait": _apply_framing()

	visibility_changed.connect(_sync_visibility)
	_sync_visibility()

func _available(names: Array) -> Array[StringName]:
	var found: Array[StringName] = []
	for clip: StringName in names:
		if _animations.has_animation(clip): found.append(clip)
	return found

## Tirage au hasard dans un groupe de gestes équivalents, sans rejouer le précédent du même groupe
## ni le dernier geste joué.
func _pick(pool: Array[StringName]) -> StringName:
	if pool.is_empty(): return &""
	var key := pool[0]
	var choices := pool.filter(func(clip: StringName) -> bool: return clip != _last_pick.get(key, &"") and clip != _last_played)
	if choices.is_empty(): choices = pool.filter(func(clip: StringName) -> bool: return clip != _last_played)
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

## Ancien appel (écran seul) : moment par défaut de la page.
func set_context(id: String) -> void:
	if id == _context: return
	_context = id
	set_moment(Moments.moment(id, ""))

## Moment de la bulle affichée ({id, categorie, ton}, voir gabi_moments.gd). Une nouvelle bulle
## joue aussitôt un geste de sa catégorie (ou dès que Gabi redevient visible).
func set_moment(moment: Dictionary) -> void:
	var tone: String = moment.get("ton", Moments.NEUTRE)
	if is_instance_valid(visage):
		visage.set_tone(tone)
		visage.attentive = moment.get("categorie", "") == "question"
	if moment.get("id", "") == _moment.id:
		_moment.ton = tone
		return
	_moment = {"id": moment.get("id", ""), "categorie": moment.get("categorie", "consigne"), "ton": tone}
	_moment_pending = not reduced_motion
	if is_visible_in_tree(): _sync_visibility()

func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion: return
	reduced_motion = value
	if value: _moment_pending = false
	_sync_visibility()

func set_speaking(value: bool) -> void:
	if _mime_left > 0.0 and value and get_tree().process_frame.is_connected(_mime_step):
		# Une vraie voix prend le relais du mouvement de lèvres sans voix.
		get_tree().process_frame.disconnect(_mime_step)
		_mime_left = 0.0
	var changed := value != _speaking
	_speaking = value
	if not value: _articulation = Vector4.ZERO
	if is_instance_valid(visage): visage.set_speaking(value)
	_sync_mouth()
	if changed: _sync_talk()

## Gabi Mixamo : pendant qu'il parle, des gestes de parole tirés au hasard s'enchaînent ; un geste
## en cours (salut, geste du moment) se termine d'abord.
func _sync_talk() -> void:
	if _talks.is_empty() or not _can_animate(): return
	var current := StringName(_animations.current_animation)
	if _speaking and (current == _idle or current in _microgestures or current in _rare):
		_play_gesture(_pick(_talks))
	elif not _speaking and current in _talks:
		_play_idle()

## Bulle affichée sans voix : la bouche s'ouvre légèrement, au rythme de syllabes (environ 4,5 par
## seconde, amplitude variable), pendant 1,2 à 4 s selon la longueur du texte. Une vraie voix, un
## guide masqué ou le mouvement réduit l'arrêtent.
const MIME_RATE := 4.5
const MIME_OPEN := Vector2(0.16, 0.40)
func mime(text: String) -> void:
	if not _can_animate() or text.strip_edges().is_empty(): return
	if _speaking and not is_miming(): return  # une vraie voix parle déjà
	_mime_left = clampf(text.strip_edges().length() / 16.0, 1.2, 4.0)
	_mime_time = 0.0
	_mime_syllable = -1
	if not _speaking: set_speaking(true)
	if not get_tree().process_frame.is_connected(_mime_step): get_tree().process_frame.connect(_mime_step)

func is_miming() -> bool:
	return _mime_left > 0.0

func _mime_step() -> void:
	var delta := get_process_delta_time()
	_mime_left -= delta
	_mime_time += delta
	if _mime_left <= 0.0 or not _can_animate() or not _speaking:
		_stop_mime()
		return
	var phase := _mime_time * MIME_RATE
	if int(phase) != _mime_syllable:
		_mime_syllable = int(phase)
		_mime_shape = Vector2(_gesture_random.randf_range(MIME_OPEN.x, MIME_OPEN.y), _gesture_random.randf_range(0.0, 0.35) if _gesture_random.randf() < 0.3 else 0.0)
	var open := _mime_shape.x * pow(sin(PI * fposmod(phase, 1.0)), 2.0)
	# Fin de phrase : la bouche se referme en douceur.
	open *= clampf(_mime_left / 0.25, 0.0, 1.0)
	set_articulation(open, _mime_shape.y, 0.0, 0.0)

func _stop_mime() -> void:
	if get_tree() != null and get_tree().process_frame.is_connected(_mime_step): get_tree().process_frame.disconnect(_mime_step)
	_mime_left = 0.0
	if _speaking: set_speaking(false)

func set_articulation(value: float, rounding: float = 0.0, press: float = 0.0, wide: float = 0.0) -> void:
	_articulation = Vector4(value, rounding, press, wide).clamp(Vector4.ZERO, Vector4.ONE)
	_sync_mouth()

func _sync_mouth() -> void:
	if _mouth == null: return
	var weights := _articulation if _speaking and _can_animate() else Vector4.ZERO
	# Hors parole, le visage peut garder un léger sourire (MouthPress, MouthWide).
	if not _speaking and is_instance_valid(visage) and _can_animate():
		var rest: Vector2 = visage.mouth_rest()
		weights = Vector4(visage.lips_rest(), 0.0, rest.x, rest.y)
	for index in _mouth_shapes.size():
		if _mouth_shapes[index] >= 0:
			_mouth.set_blend_shape_value(_mouth_shapes[index], weights[index])

## Ouverture du guide ou nouvelle bulle demandée par le joueur. Première ouverture : salut (accueil).
## Sinon, un geste du moment affiché, sauf si un geste du moment est déjà en cours.
func request_gesture(opening: bool) -> void:
	if not _can_animate(): return
	var current := StringName(_animations.current_animation)
	if current in _greetings: return
	if opening and not _greeted and _play_gesture(_pick(_greetings)):
		_greeted = true
		_moment_pending = false
		return
	if current in _moment_clips and current != _idle: return
	_play_moment()

func _play_moment() -> bool:
	_moment_pending = false
	var category: String = _moment.categorie
	if category == "accueil" and _greeted:
		category = "consigne"
	var clip := _pick(_available(Moments.gestures(category, _profile)))
	if clip.is_empty(): clip = _pick(_available(Moments.gestures("consigne", _profile)))
	if not _play_gesture(clip): return false
	if category == "accueil": _greeted = true
	if is_instance_valid(visage) and category in ["bonne_nouvelle", "approbation", "accueil"]:
		visage.smile_now(1.0 if category == "bonne_nouvelle" else 0.7)
	return true

## Petit geste d'attente suivant, selon le ton : jamais tablette ni bâillement pendant une mauvaise
## nouvelle, et au plus un geste rare sur RARE_EVERY.
func _next_wait() -> StringName:
	var negative: bool = _moment.ton == Moments.NEGATIF
	if not negative and not _rare.is_empty() and _since_rare >= RARE_EVERY - 1 and _gesture_random.randf() < 0.5:
		_since_rare = 0
		return _pick(_rare)
	_since_rare += 1
	return _pick(_negative_waits if negative else _microgestures)

func _process(delta: float) -> void:
	_microgesture_wait -= delta
	if _microgesture_wait > 0.0: return
	_play_gesture(_next_wait())

func _sync_visibility() -> void:
	if _animations == null: return
	set_process(false)
	if not is_visible_in_tree():
		if _camera_tween != null: _camera_tween.kill()
		_animations.pause()
		if is_instance_valid(visage): visage.set_static(true)
		_sync_mouth()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if reduced_motion:
		if is_instance_valid(visage): visage.set_static(true)
		_sync_mouth()
		_frame_clip(_idle, false)
		_animations.play(_idle, 0.0)
		_animations.seek(0.0, true)
		_animations.pause()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	if is_instance_valid(visage): visage.set_static(false)
	_sync_mouth()
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if _moment_pending and _play_moment():
		return
	_moment_pending = false
	if _speaking and not _talks.is_empty():
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
	_last_played = clip
	if is_instance_valid(visage): visage.follow_gesture(clip, Moments.REGARD_CARNET, Moments.REGARD_PENSIF)
	return true

func _play_idle() -> void:
	_frame_clip(_idle)
	_animations.play(_idle, BLEND_TIME)
	if is_instance_valid(visage): visage.follow_gesture(_idle, Moments.REGARD_CARNET, Moments.REGARD_PENSIF)
	if _microgestures.is_empty(): return
	_microgesture_wait = _gesture_random.randf_range(_microgesture_delay.x, _microgesture_delay.y)
	set_process(true)

## Cadrage (voir CADRAGES) : caméra fixe hors mode grand ; mode grand : portrait.
func set_framing(value: String) -> void:
	if value == framing: return
	framing = value
	if _camera != null: _apply_framing()

## Taille de rendu demandée (pixels physiques affichés × suréchantillonnage), hors mode grand.
func set_render_size(value: Vector2i) -> void:
	value = value.clamp(Vector2i(64, 64), Vector2i(1024, 1400))
	if value == _render_size: return
	_render_size = value
	if framing != "portrait": _viewport.size = value

func _apply_framing() -> void:
	var fixe: Dictionary = CADRAGES.get(framing, {})
	_viewport.size = (_render_size if _render_size != Vector2i.ZERO else fixe.render) if not fixe.is_empty() else RENDER_SIZE
	var target: Vector3 = fixe.target if not fixe.is_empty() else Vector3(0, 1.39, 0)
	_camera.position = target + Vector3(fixe.side if not fixe.is_empty() else -0.55, 0.02 if not fixe.is_empty() else 0.04, 3.45)
	_camera.look_at(target)
	_frame_clip(StringName(_animations.current_animation) if _animations != null and _animations.is_playing() else _idle, false)

func _frame_clip(clip: StringName, transition := true) -> void:
	var target_size := GREETING_SIZE if clip in _greetings else PORTRAIT_SIZE
	var target_offset := GREETING_OFFSET if clip in _greetings else 0.0
	if CADRAGES.has(framing):
		# Le cadrage reste fixe même pendant un salut : le disque du bandeau et le Bureau ne zooment pas.
		target_size = CADRAGES[framing].size
		target_offset = CADRAGES[framing].offset
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
