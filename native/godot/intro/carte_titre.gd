extends Control
## Carte 3 : écran titre. Le stade de la carte précédente reste en fond et passe dans le flou (même shader,
## même cadre), les bandes cinéma s'ouvrent ; le logo provisoire (branding/) est révélé par un reflet doré
## qui balaie (canvas_intro_logo.gdshader), sur un halo doré. Jauge fine tant que le moteur démarre, puis
## « Appuie sur une touche » qui respire. Textes, durées et intensités dans intro.json.
const C = preload("res://ui/immersive08/components.gd")
const Plan = preload("res://intro/plan.gd")
const Stade = preload("res://intro/carte_stade.gd")
const LOGO := "res://branding/rugby-legacy-27-logo.png"

## L'écran titre attend le joueur : il ne se termine pas seul.
var automatic := false
var ready_shown := false
var _sequence: Node
var _spec: Dictionary = {}
var _back: ColorRect
var _halo: ColorRect
var _logo: TextureRect
var _loading: Control
var _gauge: ColorRect
var _gauge_value := 0.0
var _prompt: Label
var _time := 0.0
var _since_ready := 0.0
var _calm := false
var _after_stadium := false
var _start_progress := 1.0
var _start_bars := 0.0
var _start_vignette := 0.6

func configure(sequence: Node, spec: Dictionary) -> void:
	_sequence = sequence
	_spec = spec
	_calm = sequence != null and sequence.reduced_motion
	var stadium: Dictionary = sequence.card_data("stade") if sequence != null and sequence.has_method("card_data") else {}
	_after_stadium = sequence != null and sequence.has_meta("camera_progress")
	_start_progress = float(sequence.get_meta("camera_progress", 1.0)) if sequence != null else 1.0
	_start_bars = float(stadium.get("finition", {}).get("letterbox", 0.0)) if _after_stadium else 0.0
	_back = Plan.painted(self, Stade.SHADER)
	_back.name = "IntroTitreFond"
	Stade.apply_look(_back.material as ShaderMaterial, stadium, _calm)
	(_back.material as ShaderMaterial).set_shader_parameter("dust", 0.0)
	_start_vignette = float(stadium.get("finition", {}).get("vignette", 0.6))
	var plan := Plan.layer(self)
	_halo = Plan.painted(plan, "res://intro/canvas_intro_halo.gdshader", Rect2(280, 0, 2000, 1180))
	_halo.name = "IntroHalo"
	_halo.material.set_shader_parameter("strength", 0.0)
	_logo = TextureRect.new()
	_logo.name = "IntroLogo"
	_logo.texture = load(LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var composite := ShaderMaterial.new()
	composite.shader = load("res://intro/canvas_intro_logo.gdshader")
	composite.set_shader_parameter("reveal", 0.0)
	composite.set_shader_parameter("glow", float(spec.get("halo_logo", 0.35)))
	_logo.material = composite
	plan.add_child(_logo)
	_logo.position = Vector2(560, 190) * C.density
	_logo.size = Vector2(1440, 720) * C.density
	_logo.pivot_offset = _logo.size / 2.0
	_loading = Control.new()
	_loading.name = "IntroChargement"
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.add_child(_loading)
	_gauge = Plan.painted(_loading, "res://intro/canvas_intro_filet.gdshader", Rect2(1280 - 200, 1102 - 12, 400, 24))
	_gauge.name = "IntroJauge"
	_gauge.material.set_shader_parameter("rect_size", Vector2(400, 24) * C.density)
	_gauge.material.set_shader_parameter("from_left", 1.0)
	_gauge.material.set_shader_parameter("intensity", 0.8)
	Plan.spaced(_loading, str(spec.get("chargement", "")), 1280, 1166, 22, C.MUTED, C.BOLD, 8.0).name = "IntroChargementTexte"
	_prompt = Plan.spaced(plan, str(spec.get("invite", "")), 1280, 1150, 30, C.IVORY, C.BOLD, 11.0)
	_prompt.name = "IntroInvite"
	_prompt.visible = false

func begin() -> void:
	_logo.modulate.a = 1.0
	_loading.modulate.a = 0.0
	_process(0.0)

## Le moteur a répondu : la jauge s'efface, l'invitation à continuer apparaît.
func engine_ready() -> void:
	if ready_shown: return
	ready_shown = true
	_gauge_value = 1.0
	_prompt.visible = true
	_prompt.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_loading, "modulate:a", 0.0, 0.3)

## Valeur de la jauge (0..1), lue par les tests.
func gauge_value() -> float:
	return _gauge_value

func _process(delta: float) -> void:
	_time += delta
	var material := _back.material as ShaderMaterial
	var focus_for := float(_spec.get("mise_au_point", 1.4))
	var k := Plan.soft(_time / focus_for)
	material.set_shader_parameter("time", _time + 8.0)
	material.set_shader_parameter("screen_aspect", size.x / maxf(size.y, 1.0))
	# Le cadre continue de dériver très lentement depuis la position atteinte par le stade.
	material.set_shader_parameter("progress", _start_progress + (0.0 if _calm else _time * float(_spec.get("derive_fond", 0.012))))
	material.set_shader_parameter("blur", k if _after_stadium else 1.0)
	var dim := float(_spec.get("exposition_fond", 0.6))
	material.set_shader_parameter("exposure", lerpf(1.0, dim, k) if _after_stadium else lerpf(0.3, dim, Plan.soft(_time / 0.8)))
	material.set_shader_parameter("letterbox", lerpf(_start_bars, 0.0, Plan.soft(_time / 1.2)))
	material.set_shader_parameter("haze", float(_spec.get("brume_fond", 0.25)))
	material.set_shader_parameter("vignette", lerpf(_start_vignette, float(_spec.get("vignette_fond", 0.85)), k))
	# Logo : reflet doré qui révèle, léger recul, puis reflets de passage espacés.
	var at := float(_spec.get("apparition_logo", 0.6))
	var reveal_for := float(_spec.get("duree_revelation", 1.6))
	var reveal := 1.0 if _calm else Plan.soft((_time - at) / reveal_for)
	(_logo.material as ShaderMaterial).set_shader_parameter("reveal", reveal)
	if not _calm: _logo.scale = Vector2.ONE * lerpf(1.035, 1.0, 1.0 - pow(1.0 - clampf((_time - at) / (reveal_for * 1.8), 0.0, 1.0), 3.0))
	var every := float(_spec.get("reflet_toutes_les", 6.5))
	var cycle := fmod(maxf(_time - at - reveal_for - 2.0, 0.0), every)
	var passing := not _calm and _time >= at + reveal_for + 2.0 and cycle < 1.4
	(_logo.material as ShaderMaterial).set_shader_parameter("shine", cycle / 1.4 * 1.4 - 0.2 if passing else -1.0)
	var halo := float(_spec.get("halo", 0.2)) * Plan.soft((_time - at - 0.3) / 1.6)
	_halo.material.set_shader_parameter("strength", halo * (1.0 if _calm else 0.92 + 0.08 * sin(_time * 1.3)))
	_halo.material.set_shader_parameter("time", _time)
	var after_logo := at + reveal_for * 0.8
	if not ready_shown:
		_loading.modulate.a = Plan.soft((_time - after_logo) / 0.6)
		# Progression estimée depuis le lancement du jeu (durée d'ouverture mesurée), jamais pleine avant le moteur.
		var expected := maxf(1.0, float(_spec.get("duree_estimee_chargement", 7.7)))
		var uptime := Time.get_ticks_msec() / 1000.0
		_gauge_value = 0.95 * (1.0 - exp(-uptime / (expected * 0.45)))
		_gauge.material.set_shader_parameter("progress", _gauge_value)
		return
	_since_ready += delta
	# L'invitation n'arrive qu'une fois le logo révélé, puis respire doucement.
	var visible_from := maxf(after_logo, _time - _since_ready + 0.2)
	var fade_in := Plan.soft((_time - visible_from) / 0.7)
	var breath := 1.0 if _calm else 0.78 + 0.22 * cos(maxf(_time - visible_from - 0.7, 0.0) * 2.2)
	_prompt.modulate.a = fade_in * breath

## Opacité visible des textes de l'écran titre (logo compris) : contrôle des fondus entre cartes.
func text_alpha() -> float:
	var reveal: float = (_logo.material as ShaderMaterial).get_shader_parameter("reveal")
	var words := maxf(_loading.modulate.a, _prompt.modulate.a if _prompt.visible else 0.0)
	return maxf(reveal * _logo.modulate.a, words) * modulate.a

func leave(duration: float = 0.3) -> void:
	pass
