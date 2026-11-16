extends Control
## Disquette discrète en bas de l'écran (coin droit) pendant que le moteur sauvegarde en arrière-plan, après sa
## réponse (jour suivant, Continuer). Elle ne bloque jamais le joueur : ni clic ni touche ne passent par elle
## (MOUSE_FILTER_IGNORE) ; l'info-bulle est un petit libellé affiché quand la souris survole le coin.
##
## Règles : la disquette n'apparaît qu'après SHOW_DELAY (une écriture rapide ne montre rien), reste au moins
## MIN_SHOWN une fois visible (pas de clignotement), puis s'efface. En cas d'échec elle devient rouge et reste jusqu'à
## la prochaine sauvegarde ; l'erreur elle-même reste annoncée par le moteur à la commande suivante (messages d'erreur).
## Mouvements réduits : disquette fixe, sans pulsation. Couleurs de la carte Continuer et du panneau d'attente.

const IVORY := Color("f2ecdc")
const GOLD := Color("e0b35a")
const INK := Color("0b1012")
const PANEL := Color("121a1c")
const LINE := Color("2c3a37")
const RED := Color("d43e47")
const BODY_FONT = preload("res://fonts/DMSans.ttf")
const ICON_SIZE := 26.0
const MARGIN := 16.0
const TEXT_SAVING := "Sauvegarde en cours…"
const TEXT_DONE := "Carrière sauvegardée"
const TEXT_FAILED := "La sauvegarde a échoué : ta dernière action est annulée."

## Réglables (tests) : délai avant apparition, durée minimale d'affichage, fondu, secondes.
var show_delay := 0.35
var min_shown := 1.0
var fade := 0.18

## Phase : "idle" (cachée), "waiting" (début reçu, pas encore affichée), "shown" (visible, sauvegarde en cours),
## "ending" (fin reçue, affichée jusqu'à MIN_SHOWN), "failed" (rouge, jusqu'à la prochaine sauvegarde).
var phase := "idle"
var _motion := true
var _started_ms := 0
var _shown_ms := 0
var _pulse := 0.0
var _tip := Label.new()
var _tween: Tween


func _ready() -> void:
	name = "SaveIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	offset_left = -(ICON_SIZE + MARGIN)
	offset_top = -(ICON_SIZE + MARGIN)
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	z_index = 40
	visible = false
	modulate.a = 0.0
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_font_override("font", BODY_FONT)
	_tip.add_theme_font_size_override("font_size", 13)
	_tip.add_theme_color_override("font_color", IVORY)
	_tip.add_theme_stylebox_override("normal", _tip_box())
	_tip.visible = false
	add_child(_tip)
	set_process(false)


func _tip_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 9.0
	box.content_margin_right = 9.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


## Événement du moteur : "started", "done" ou "failed".
func apply_state(state: String, motion: bool = true) -> void:
	_motion = motion
	match state:
		"started":
			_started_ms = Time.get_ticks_msec()
			if phase in ["shown", "ending", "failed"]:
				# Nouvelle sauvegarde pendant l'affichage : la disquette reste (et redevient normale après un échec).
				phase = "shown"
				tooltip_text = TEXT_SAVING
				_refresh_tip()
				queue_redraw()
			else: phase = "waiting"
			set_process(true)
		"done":
			if phase == "waiting":
				phase = "idle"
				set_process(false)
			elif phase in ["shown", "failed"]:
				phase = "ending"
				tooltip_text = TEXT_DONE
				_refresh_tip()
				queue_redraw()
		"failed":
			_show_now()
			phase = "failed"
			tooltip_text = TEXT_FAILED
			_refresh_tip()
			_kill_tween()
			modulate.a = 1.0
			queue_redraw()
			set_process(true)


## Vrai tant que la disquette est affichée (même en fondu).
func shown() -> bool:
	return visible and phase != "idle"


func _show_now() -> void:
	if visible and modulate.a >= 0.99: return
	visible = true
	_shown_ms = Time.get_ticks_msec()
	_kill_tween()
	if fade > 0.0 and _motion:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, fade)
	else: modulate.a = 1.0
	tooltip_text = TEXT_SAVING
	_refresh_tip()
	queue_redraw()


func _hide_now() -> void:
	phase = "idle"
	_tip.visible = false
	_kill_tween()
	if fade > 0.0 and _motion:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, fade)
		_tween.tween_callback(_finish_fade)
	else:
		modulate.a = 0.0
		visible = false
	set_process(false)


func _finish_fade() -> void:
	if phase == "idle": visible = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if phase == "waiting" and now - _started_ms >= int(show_delay * 1000.0):
		phase = "shown"
		_show_now()
	elif phase == "ending" and now - _shown_ms >= int(min_shown * 1000.0):
		_hide_now()
		return
	if visible and _motion and phase == "shown":
		_pulse += delta
		queue_redraw()
	_place_tip()


## Libellé au survol (sans que la disquette reçoive la souris : position lue, rien n'est capté).
func _place_tip() -> void:
	if not visible: return
	var over := Rect2(global_position - Vector2(6, 6), size + Vector2(12, 12)).has_point(get_global_mouse_position())
	if over != _tip.visible:
		_tip.visible = over
		if over: _refresh_tip()
	if _tip.visible:
		_tip.position = Vector2(size.x - _tip.size.x, -_tip.size.y - 8.0)


func _refresh_tip() -> void:
	_tip.text = tooltip_text
	_tip.reset_size()


func _draw() -> void:
	var failed := phase == "failed"
	var body := RED if failed else IVORY
	var pulse := 1.0 if not _motion or phase != "shown" else 0.78 + 0.22 * sin(_pulse * 4.2)
	body.a = pulse
	var w := ICON_SIZE
	var cut := w * 0.22
	# Corps de la disquette, coin supérieur droit coupé.
	draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(w - cut - 1, 1), Vector2(w - 1, cut + 1), Vector2(w - 1, w - 1), Vector2(1, w - 1)]), body)
	# Volet métallique (haut) et étiquette (bas).
	draw_rect(Rect2(w * 0.24, 1, w * 0.46, w * 0.3), INK)
	draw_rect(Rect2(w * 0.56, w * 0.07, w * 0.08, w * 0.17), body)
	draw_rect(Rect2(w * 0.17, w * 0.55, w * 0.66, w * 0.4), INK)
	draw_rect(Rect2(w * 0.22, w * 0.62, w * 0.56, w * 0.05), GOLD if not failed else body)
	draw_rect(Rect2(w * 0.22, w * 0.74, w * 0.4, w * 0.05), GOLD if not failed else body)
