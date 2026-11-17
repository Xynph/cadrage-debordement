extends Control
## Carte 1 : prologue d'ambiance, sans nom d'éditeur. Fond vert profond (canvas_intro_fond.gdshader) avec
## lumières floues, filet doré qui se trace depuis le centre, phrase en Barlow Condensed dont l'interlettrage
## se resserre en apparaissant, surtitre en or. Textes, durées et intensités dans intro.json.
const C = preload("res://ui/immersive08/components.gd")
const Plan = preload("res://intro/plan.gd")

## La séquence passe d'elle-même à la carte suivante au bout de sa durée.
var automatic := true
var _sequence: Node
var _spec: Dictionary = {}
var _ground: ColorRect
var _rule: ColorRect
var _words: Control
var _name: Control
var _mention: Label
var _time := 0.0
var _calm := false
var _leaving := false

func configure(sequence: Node, spec: Dictionary) -> void:
	_sequence = sequence
	_spec = spec
	_calm = sequence != null and sequence.reduced_motion
	_ground = Plan.painted(self, "res://intro/canvas_intro_fond.gdshader")
	_ground.name = "IntroPrologueFond"
	_ground.material.set_shader_parameter("bokeh", float(spec.get("lumieres_floues", 0.5)))
	_ground.material.set_shader_parameter("grain", float(spec.get("grain", 0.035)))
	var plan := Plan.layer(self)
	_rule = Plan.painted(plan, "res://intro/canvas_intro_filet.gdshader", Rect2(1280 - 560, 790 - 20, 1120, 40))
	_rule.name = "IntroFilet"
	_rule.material.set_shader_parameter("rect_size", Vector2(1120, 40) * C.density)
	_rule.material.set_shader_parameter("progress", 0.0)
	_words = Control.new()
	_words.name = "IntroPrologueTexte"
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.add_child(_words)
	# Interlettrage et montée animés : texte dessiné glyphe par glyphe (sans paliers d'un pixel).
	_name = Plan.fluid(_words, str(spec.get("texte", "")), 1280, 748, 62, C.IVORY, C.DISPLAY, float(spec.get("interlettrage_depart", 34)))
	_name.name = "IntroProloguePhrase"
	_mention = Plan.spaced(_words, str(spec.get("surtitre", "")), 1280, 648, 24, C.GOLD, C.BOLD, float(spec.get("interlettrage_mention", 14)))
	_mention.name = "IntroPrologueSurtitre"
	_name.modulate.a = 0.0
	_mention.modulate.a = 0.0

func begin() -> void:
	_time = 0.0
	_process(0.0)

func _process(delta: float) -> void:
	_time += delta
	_ground.material.set_shader_parameter("time", _time)
	_ground.material.set_shader_parameter("screen_aspect", size.x / maxf(size.y, 1.0))
	if _leaving: return
	var line_at := float(_spec.get("filet_a", 0.15))
	var line_for := float(_spec.get("filet_duree", 1.2))
	var name_at := float(_spec.get("texte_a", 0.3))
	var name_for := float(_spec.get("texte_duree", 1.1))
	var settle := float(_spec.get("interlettrage_duree", 2.6))
	var mention_at := float(_spec.get("mention_a", 0.95))
	if _calm:
		_rule.material.set_shader_parameter("progress", 1.0)
		_name.modulate.a = clampf((_time - 0.05) / 0.25, 0.0, 1.0)
		_mention.modulate.a = _name.modulate.a
		Plan.set_tracking(_name, float(_spec.get("interlettrage_final", 16)))
		return
	_rule.material.set_shader_parameter("progress", _out_cubic((_time - line_at) / line_for))
	_name.modulate.a = Plan.soft((_time - name_at) / name_for)
	var k := _out_cubic((_time - name_at) / settle)
	Plan.set_tracking(_name, lerpf(float(_spec.get("interlettrage_depart", 34)), float(_spec.get("interlettrage_final", 16)), k))
	_name.set_rise((1.0 - k) * 10.0 * C.density)
	_mention.modulate.a = Plan.soft((_time - mention_at) / 0.8)

static func _out_cubic(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

## Opacité visible des textes de la carte (contrôle des fondus : jamais deux cartes lisibles à la fois).
func text_alpha() -> float:
	return maxf(_name.modulate.a, _mention.modulate.a) * _words.modulate.a * modulate.a

## La séquence change de carte : textes et filet s'effacent avant que la carte suivante ne soit lisible.
func leave(duration: float = 0.3) -> void:
	_leaving = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_words, "modulate:a", 0.0, duration)
	tween.tween_property(_rule, "modulate:a", 0.0, duration * 1.6)
