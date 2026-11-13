extends Control
## Visage rond de Gabi, dans le bandeau du haut (shell.gd, zone « GabiBandeau ») : le buste 3D vivant de
## Gabi dans un disque vert sombre cerclé d'or. Un point or et un petit carnet signalent qu'il a quelque
## chose à dire. Le disque n'affiche que la texture du portrait (rendu par la SubViewport du portrait, qui
## reste au guide) : rien n'est déplacé d'un nœud à l'autre quand le bandeau est reconstruit.
## Le médaillon du coin bas droit (#684) est retiré : ce disque vit dans le bandeau, qui existait déjà.
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
## Portrait affiché (portrait 3D ou repli 2D du guide) : sa texture est partagée, le nœud reste au guide.
var portrait: TextureRect
var _image: TextureRect
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.shader = MASK
	resized.connect(_fit_portrait)

## Montre le portrait du guide dans le disque, par sa texture (3D : masque rond ; 2D : disque et souffle).
func afficher(display: TextureRect) -> void:
	liberer()
	portrait = display
	if display == null: return
	_image = TextureRect.new()
	_image.name = "GabiVisageImage"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.texture = display.texture
	if display.has_method("set_framing"):
		_image.material = _mask
		add_child(_image)
		move_child(_image, 0)
	else:
		_disque = Disque.new()
		add_child(_disque)
		move_child(_disque, 0)
		_souffle = Control.new()
		_souffle.name = "GabiSouffle"
		_souffle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disque.add_child(_souffle)
		_image.material = display.material
		_souffle.add_child(_image)
	_fit_portrait()

## Vide le disque (le portrait du guide n'est jamais déplacé ni libéré ici).
func liberer() -> void:
	if _disque != null:
		_disque.queue_free()
		_disque = null
		_souffle = null
	elif _image != null:
		_image.queue_free()
	_image = null
	portrait = null

func _fit_portrait() -> void:
	if _image == null: return
	if _disque != null:
		var gap := maxf(2.0, size.x * 0.045)
		_disque.position = Vector2(gap, gap)
		_disque.size = size - Vector2(gap, gap) * 2.0
		var zoomed := _disque.size * FLAT_ZOOM
		_souffle.size = zoomed
		_souffle.position = _disque.size / 2.0 - FLAT_CENTER * zoomed
		_souffle.pivot_offset = Vector2(zoomed.x * 0.5, zoomed.y * 0.9)
		_image.position = Vector2.ZERO
		_image.size = zoomed
		queue_redraw()
		return
	var inset := maxf(2.0, size.x * 0.045)
	_image.position = Vector2(inset, inset)
	_image.size = size - Vector2(inset, inset) * 2.0
	queue_redraw()

func set_hover(value: bool) -> void:
	_hover = value
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

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	# Ombre portée douce, disque vert sombre (fond du buste), lumière chaude derrière la tête.
	draw_circle(center + Vector2(0, radius * 0.06), radius, Color(0, 0, 0, 0.35))
	draw_circle(center, radius, DEEP)
	draw_circle(center, radius - 2.0, GREEN)
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
		var ring := maxf(1.5, radius * 0.07)
		var gold: Color = GOLD.lightened(0.2) if m._hover else GOLD
		draw_arc(center, radius - ring / 2.0, 0, TAU, 96, gold, ring, true)
		draw_arc(center, radius - ring * 1.9, 0, TAU, 96, Color(GOLD, 0.35), 1.0, true)
		if not m.indice: return
		# Indice : point or (léger battement) et petit carnet sombre dessus, en haut à droite.
		var dot_r := maxf(4.5, radius * 0.2)
		var dot := center + Vector2(radius * 0.74, -radius * 0.70)
		var beat := 0.0 if m.reduced_motion else (sin(m._pulse / 2.4 * TAU) + 1.0) * 0.5
		draw_circle(dot, dot_r + 2.0 + beat * dot_r * 0.6, Color(GOLD, 0.28 * (1.0 - beat)))
		draw_circle(dot, dot_r + 1.5, DEEP)
		draw_circle(dot, dot_r, GOLD)
		var w := dot_r * 1.0
		var h := dot_r * 1.3
		var book := Rect2(dot - Vector2(w / 2.0, h / 2.0), Vector2(w, h))
		draw_rect(book, DEEP)
		for k in 2:
			var y := book.position.y + h * (0.38 + k * 0.26)
			draw_line(Vector2(book.position.x + w * 0.28, y), Vector2(book.end.x - w * 0.15, y), GOLD, maxf(1.0, h * 0.09))

var _cadre := Cadre.new()

func _ready() -> void:
	_cadre.owner_medaillon = self
	add_child(_cadre)
	_cadre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	draw.connect(func(): _cadre.queue_redraw())
