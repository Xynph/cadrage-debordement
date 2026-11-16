extends Control
## Carte 2 : le stade de nuit. Illustration de l'accueil (art/immersive08/entry-ground.png) animée en 2,5D
## par canvas_intro_stade.gdshader : lent mouvement de caméra avec parallaxe (carte de profondeur dérivée,
## tools/intro-stade-calques.py), brume, halo et faisceaux du projecteur, poussière dans la lumière,
## étalonnage, vignette, grain et bandes cinéma. Une phrase d'ambiance d'intro.json s'inscrit en bas à gauche ;
## la nappe du stade monte, la clameur éclate avant l'écran titre. Mode calme : image fixe, sans poussière.
const C = preload("res://ui/immersive08/components.gd")
const Plan = preload("res://intro/plan.gd")
const SHADER := "res://intro/canvas_intro_stade.gdshader"
const BED := "res://audio/assets/stadium-bed.wav"
const CLAMEUR := "res://audio/assets/stadium-try.wav"

var automatic := true
## Phrase retenue (surtitre, texte) : tirée au hasard dans intro.json.
var phrase: Dictionary = {}
## Rectangle peint par le shader du stade (contrôle des tests).
var picture: ColorRect
var _sequence: Node
var _spec: Dictionary = {}
var _caption: Control
var _rule: ColorRect
var _bed: AudioStreamPlayer
var _clamour: AudioStreamPlayer
var _bed_gain := 0.0
var _time := 0.0
var _duration := 5.0
var _clamour_played := false
var _leaving := false
var _calm := false

func configure(sequence: Node, spec: Dictionary) -> void:
	_sequence = sequence
	_spec = spec
	_calm = sequence != null and sequence.reduced_motion
	_duration = maxf(1.0, float(spec.get("duree", 5.0)))
	picture = Plan.painted(self, SHADER)
	picture.name = "IntroStadeImage"
	apply_look(picture.material as ShaderMaterial, spec, _calm)
	var plan := Plan.layer(self)
	var phrases: Array = spec.get("phrases", [])
	if not phrases.is_empty(): phrase = phrases[randi() % phrases.size()]
	_caption = Control.new()
	_caption.name = "IntroPhrase"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.add_child(_caption)
	var left := 220.0
	_rule = Plan.painted(_caption, "res://intro/canvas_intro_filet.gdshader", Rect2(left - 4, 1076 - 12, 150, 24))
	_rule.material.set_shader_parameter("rect_size", Vector2(150, 24) * C.density)
	_rule.material.set_shader_parameter("from_left", 1.0)
	var over := Plan.spaced(_caption, str(phrase.get("surtitre", "")), left, 1130, 24, C.GOLD, C.BOLD, 9.0, 0.0)
	over.name = "IntroSurtitre"
	_align_left(over, left)
	var line := Plan.spaced(_caption, str(phrase.get("texte", "")), left, 1212, 56, C.IVORY, C.MEDIUM, 1.0, 0.0)
	line.name = "IntroTexte"
	_align_left(line, left)
	_caption.modulate.a = 0.0
	_bed = _player(BED, true)
	_clamour = _player(CLAMEUR, false)

## Les phrases s'alignent à gauche sur la marge du cadre, largeur ajustée au texte.
static func _align_left(label: Label, left: float) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var font: Font = label.get_theme_font("font")
	var pixels := label.get_theme_font_size("font_size")
	label.size.x = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + C.px(40)
	label.set_meta("center_x", left + label.size.x / C.density / 2.0)
	Plan.set_tracking(label, (label.get_meta("variation") as FontVariation).spacing_glyph / C.density)

## Réglages du plan (intro.json → cartes.stade.camera / lumiere / finition) appliqués au shader.
## Partagé avec l'écran titre, qui reprend le même stade flouté en fond.
static func apply_look(material: ShaderMaterial, spec: Dictionary, calm: bool) -> void:
	var image: Texture2D = C.texture("entry-ground")
	material.set_shader_parameter("image", image)
	material.set_shader_parameter("depth_map", load("res://intro/stade-profondeur.png"))
	material.set_shader_parameter("glow_map", load("res://intro/stade-lueur.png"))
	material.set_shader_parameter("blur_map", load("res://intro/stade-flou.png"))
	if image != null: material.set_shader_parameter("image_aspect", image.get_width() / float(image.get_height()))
	for group in ["camera", "lumiere", "finition"]:
		var values: Dictionary = spec.get(group, {})
		for key in values:
			var value: Variant = values[key]
			if value is Array and value.size() == 2: value = Vector2(float(value[0]), float(value[1]))
			material.set_shader_parameter(key, value)
	if calm:
		material.set_shader_parameter("parallax", 0.0)
		material.set_shader_parameter("dust", 0.0)

func _player(path: String, loop: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else load(path) as AudioStreamWAV
	if stream == null: return player
	if loop:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
	player.stream = stream
	player.bus = "Master"
	player.volume_db = -80.0
	add_child(player)
	return player

func begin() -> void:
	if _bed.stream != null: _bed.play()
	_process(0.0)

## Avancement de la caméra (0..1) : démarrage doux puis dérive continue, jamais arrêtée au moment du fondu.
func camera_progress() -> float:
	if _calm: return 0.5
	var travel := maxf(_duration, float(_spec.get("duree_camera", _duration + 2.0)))
	var t := clampf(_time / travel, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t) * 0.55 + t * 0.45

## Gain final tenant compte du volume global déjà appliqué au bus principal.
func _gain(level: float) -> float:
	var master := AudioServer.get_bus_volume_linear(0)
	var wanted: float = level * (_sequence.stadium_gain if _sequence != null else 0.2)
	return clampf(wanted / maxf(master, 0.01), 0.0, 1.0)

func _process(delta: float) -> void:
	_time += delta
	var material := picture.material as ShaderMaterial
	material.set_shader_parameter("time", _time)
	material.set_shader_parameter("screen_aspect", size.x / maxf(size.y, 1.0))
	material.set_shader_parameter("progress", camera_progress())
	# Les lumières se lèvent sur le stade.
	var rise := float(_spec.get("lever_lumiere", 1.4))
	material.set_shader_parameter("exposure", lerpf(float(_spec.get("exposition_depart", 0.35)), 1.0, Plan.soft(_time / rise)))
	if not _leaving:
		var appear := float(_spec.get("apparition_texte", 1.3))
		var vanish := _duration - float(_spec.get("retrait_texte", 0.9))
		var shown := Plan.soft((_time - appear) / (0.3 if _calm else 0.9)) * (1.0 - Plan.soft((_time - vanish) / 0.6))
		_caption.modulate.a = shown
		_caption.position.y = 0.0 if _calm else (1.0 - Plan.soft((_time - appear) / 1.4)) * 16.0 * C.density
		_rule.material.set_shader_parameter("progress", 1.0 if _calm else 1.0 - pow(1.0 - clampf((_time - appear) / 1.0, 0.0, 1.0), 3.0))
	if not _clamour_played and _time >= float(_spec.get("clameur_a", 2.0)) and _clamour.stream != null:
		_clamour_played = true
		_clamour.volume_db = linear_to_db(maxf(_gain(float(_spec.get("volume_clameur", 0.55))), 0.0001))
		_clamour.play()
	# La nappe monte pendant la carte, puis retombe quand la carte s'efface.
	var target := 0.0 if _leaving else float(_spec.get("volume_ambiance", 1.0)) * smoothstep(0.0, 1.0, _time / maxf(_duration * 0.7, 0.5))
	_bed_gain = move_toward(_bed_gain, target, delta / (1.2 if _leaving else 0.4))
	if _bed.stream != null: _bed.volume_db = linear_to_db(_gain(_bed_gain)) if _bed_gain > 0.0 else -80.0

## Opacité visible de la phrase (contrôle des fondus : jamais deux cartes lisibles à la fois).
func text_alpha() -> float:
	return _caption.modulate.a * modulate.a

## Temps pendant lequel la carte doit survivre sous la suivante : la nappe s'éteint en fondu.
func linger() -> float:
	return 1.3

## La séquence passe à la carte suivante : la phrase s'efface, le son retombe, l'image reste jusqu'au fondu
## enchaîné. L'avancement de la caméra est transmis à l'écran titre, qui reprend le même cadre.
func leave(duration: float = 0.3) -> void:
	_leaving = true
	if _sequence != null: _sequence.set_meta("camera_progress", camera_progress())
	create_tween().tween_property(_caption, "modulate:a", 0.0, duration)
	if _clamour.playing: create_tween().tween_property(_clamour, "volume_db", _clamour.volume_db - 6.0, 1.2)
