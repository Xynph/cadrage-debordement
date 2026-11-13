extends Control
## Médaillon permanent de Gabi (coin bas droit, réservé par les écrans) : le buste 3D vivant de Gabi dans
## un cadre rond vert sombre cerclé d'or. Un point or et un petit carnet signalent qu'il a quelque chose à
## dire. Un clic ouvre sa bulle. Il ne contient que le portrait : il ne recouvre jamais le contenu.
signal pressed

const GOLD := Color("d7ad59")
const GREEN := Color("0f2a20")
const DEEP := Color("08130f")
const IVORY := Color("f2ecdc")
const MASK := preload("res://guide/gabi_medaillon_masque.gdshader")

var indice := false:
	set(value):
		if value == indice: return
		indice = value
		_pulse = 0.0
		queue_redraw()
var reduced_motion := false
var portrait: TextureRect
var _pulse := 0.0
var _hover := false
var _mask := ShaderMaterial.new()
## Repli sans buste 3D (GLB du guide absent) : le portrait 2D (coach_portrait.gd) est zoomé sur la tête et les
## épaules, découpé en disque (clip_children) ; le détourage du portrait est conservé et un souffle léger
## (respiration) l'anime en code. Le masque 3D, fait pour des UV de 0 à 1, ne convient pas à une planche de poses.
const FLAT_ZOOM := 1.5
const FLAT_CENTER := Vector2(0.52, 0.42)
const BREATH_PERIOD := 4.2
const BREATH_DEPTH := 0.014
var _disque: Control
var _souffle: Control
var _breath := 0.0

func _init() -> void:
	name = "GabiMedaillon"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Gabi · ton adjoint. Clic : sa bulle (avis, aide de l'écran, visite guidée)."
	_mask.shader = MASK
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())
	resized.connect(_fit_portrait)

## Accueille le portrait 3D (il est rendu par sa propre SubViewport) et le masque en disque.
func adopt(display: TextureRect) -> void:
	portrait = display
	if not display.has_method("set_framing"):
		_adopt_flat(display)
		return
	if display.get_parent() != self:
		if display.get_parent() != null: display.get_parent().remove_child(display)
		add_child(display)
	move_child(display, 0)
	display.material = _mask
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display.has_method("set_framing"): display.set_framing("medaillon")
	_fit_portrait()

## Rend le portrait (au mode grand) : le masque et le cadrage serré restent au médaillon.
func release() -> TextureRect:
	var display := portrait
	if display == null: return null
	if _disque != null:
		if display.get_parent() != null: display.get_parent().remove_child(display)
		_disque.queue_free()
		_disque = null
		_souffle = null
		portrait = null
		return display
	display.material = null
	if display.has_method("set_framing"): display.set_framing("portrait")
	if display.get_parent() == self: remove_child(display)
	portrait = null
	return display

func _adopt_flat(display: TextureRect) -> void:
	if display.get_parent() != null: display.get_parent().remove_child(display)
	_disque = Disque.new()
	add_child(_disque)
	move_child(_disque, 0)
	_souffle = Control.new()
	_souffle.name = "GabiSouffle"
	_souffle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disque.add_child(_souffle)
	_souffle.add_child(display)
	display.position = Vector2.ZERO
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_portrait()

func _fit_portrait() -> void:
	if portrait == null: return
	if _disque != null:
		var gap := maxf(3.0, size.x * 0.045)
		_disque.position = Vector2(gap, gap)
		_disque.size = size - Vector2(gap, gap) * 2.0
		var zoomed := _disque.size * FLAT_ZOOM
		_souffle.size = zoomed
		_souffle.position = _disque.size / 2.0 - FLAT_CENTER * zoomed
		_souffle.pivot_offset = Vector2(zoomed.x * 0.5, zoomed.y * 0.9)
		portrait.position = Vector2.ZERO
		portrait.size = zoomed
		queue_redraw()
		return
	var inset := maxf(3.0, size.x * 0.045)
	portrait.position = Vector2(inset, inset)
	portrait.size = size - Vector2(inset, inset) * 2.0
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion:
		if _souffle != null: _souffle.scale = Vector2.ONE
		return
	if _souffle != null:
		_breath = fmod(_breath + delta, BREATH_PERIOD)
		_souffle.scale = Vector2(1.0, 1.0 + BREATH_DEPTH * (sin(_breath / BREATH_PERIOD * TAU) + 1.0) * 0.5)
	if not indice: return
	_pulse = fmod(_pulse + delta, 2.4)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event(); pressed.emit()
	elif event.is_action_pressed("ui_accept"):
		accept_event(); pressed.emit()

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size / 2.0) <= size.x / 2.0 + 2.0

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	# Ombre portée douce, disque vert sombre (fond du buste), double filet or.
	draw_circle(center + Vector2(0, radius * 0.06), radius, Color(0, 0, 0, 0.35))
	draw_circle(center, radius, DEEP)
	draw_circle(center, radius - 2.0, GREEN)
	# Lumière chaude derrière la tête : le buste se détache du fond.
	for i in 6:
		draw_circle(center + Vector2(0, -radius * 0.18), radius * (0.78 - i * 0.1), Color(GOLD, 0.035))

## Disque qui découpe ses enfants (repli 2D) : seul son canal alpha compte.
class Disque extends Control:
	func _init() -> void:
		name = "GabiDisque"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	func _draw() -> void:
		draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, Color.WHITE)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: queue_redraw()

## Cadre et indice dessinés au-dessus du portrait (enfant ajouté après lui).
class Cadre extends Control:
	var owner_medaillon
	func _init() -> void:
		name = "GabiMedaillonCadre"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var m = owner_medaillon
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0
		var ring := maxf(2.0, radius * 0.06)
		var gold: Color = GOLD.lightened(0.18) if m._hover or m.has_focus() else GOLD
		draw_arc(center, radius - ring / 2.0, 0, TAU, 96, gold, ring, true)
		draw_arc(center, radius - ring * 1.9, 0, TAU, 96, Color(GOLD, 0.35), 1.0, true)
		if not m.indice: return
		# Indice : point or (léger battement) et petit carnet ivoire à côté, en haut à droite.
		var dot_r := maxf(5.0, radius * 0.15)
		var dot := center + Vector2(radius * 0.72, -radius * 0.72)
		var beat := 0.0 if m.reduced_motion else (sin(m._pulse / 2.4 * TAU) + 1.0) * 0.5
		draw_circle(dot, dot_r + 2.0 + beat * dot_r * 0.5, Color(GOLD, 0.25 * (1.0 - beat)))
		draw_circle(dot, dot_r + 1.5, DEEP)
		draw_circle(dot, dot_r, GOLD)
		# Carnet : couverture, reliure, deux lignes.
		var w := dot_r * 1.05
		var h := dot_r * 1.35
		var book := Rect2(dot - Vector2(w / 2.0, h / 2.0), Vector2(w, h))
		draw_rect(book, DEEP)
		draw_rect(Rect2(book.position, Vector2(maxf(1.0, w * 0.18), h)), Color(DEEP, 0.6))
		for k in 2:
			var y := book.position.y + h * (0.38 + k * 0.26)
			draw_line(Vector2(book.position.x + w * 0.3, y), Vector2(book.end.x - w * 0.15, y), GOLD, maxf(1.0, h * 0.08))

var _cadre := Cadre.new()

func _ready() -> void:
	_cadre.owner_medaillon = self
	add_child(_cadre)
	_cadre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	draw.connect(func(): _cadre.queue_redraw())
