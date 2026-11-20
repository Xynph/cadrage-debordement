extends Control
## Écran d'attente, direction artistique « selon la durée » (choix de Léo, 20/11/2026), deux présentations :
## - « Panneau sur le bureau » (chargements courts : passage de jour, sauvegarde…) : panneau carré ≈ 40 % de la
##   largeur, l'écran derrière légèrement assombri, filet de tête, cartes de date jour → lendemain, titre, barre,
##   conseil de Gabi ; au-delà de 20 s, « Plus long que prévu (N s)… » et « Arrêter → » (actif seulement si l'arrêt
##   est réel, sinon grisé avec sa raison) ;
## - « Le stade, puis le terrain » (longs chargements hors semaine : ouverture, création, nouvelle saison, import,
##   restauration, coup d'envoi ; `photo` dans le contexte) : photo plein écran de la banque d'images, logo, lieu,
##   bandeau bas (surtitre, titre, club · division · saison, barre en segments, « En coulisses » et son lien
##   « Anecdote suivante → »). Aucun or : l'or est réservé à Continuer.
## N'apparaît qu'après un court délai : une réponse rapide ne montre rien. Le contrôleur appelant reste propriétaire
## de la commande. Barre indéterminée tant que le moteur ne donne aucun pourcentage (jamais inventé). Mouvements
## réduits : image fixe. Couleurs, polices et formes : ui/charte.gd uniquement.

## Demande d'arrêt (bouton « Arrêter → » actif seulement quand le contexte porte `cancellable`).
signal stop_requested

const Charte = preload("res://ui/charte.gd")
const SCRIM := Color(Charte.NUIT, 0.42)
const FADE_IN := 0.18
const FADE_OUT := 0.14
const TIP_SECONDS := 4.6
const STAGE_NOTE_SECONDS := 9.0
## Au-delà : « Plus long que prévu » et la sortie (ou la raison de son absence).
const LONG_SECONDS := 20.0
const SEGMENTS := 12
const MONTHS := ["JANV.", "FÉVR.", "MARS", "AVRIL", "MAI", "JUIN", "JUIL.", "AOÛT", "SEPT.", "OCT.", "NOV.", "DÉC."]
const WEEKDAYS := ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]
const NO_STOP_REASON := "Arrêt impossible : le jeu termine cette opération avant de rendre la main."

var _frame := Control.new()
var _status := Label.new()
var _kicker := Label.new()
var _detail := Label.new()
var _tip := Label.new()
var _tip_title := Label.new()
var _progress_text := Label.new()
var _percent := Label.new()
var _long := Label.new()
var _club_line := Label.new()
var _legend := Label.new()
var _next_note := LinkButton.new()
var _enter_hint := Label.new()
var _stop := LinkButton.new()
var _stop_reason := Label.new()
var _logo := TextureRect.new()
var _reveal := Timer.new()
# Échéance réelle de l'apparition (horloge murale) : une image longue juste avant l'envoi ne doit pas avancer
# le minuteur et montrer le panneau trop tôt.
var _reveal_at_ms := 0
var _since_ms := 0
var _timing := false
var _scale := 1.0
var _elapsed := 0.0
var _shown_for := 0.0
var _motion := true
var _alpha := 0.0
var _closing := false
var _tween: Tween
var _context: Dictionary = {}
var _notes: Array[Dictionary] = []
var _note_index := 0
var _note_clock := 0.0
var _progress := -1.0
## Photo plein écran (banque d'images, « chargement-0N ») des longs chargements.
var _photo: Texture2D
var _cancellable := false
var _geo: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	focus_mode = Control.FOCUS_NONE
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_frame.name = "CommandWaitFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_logo.name = "CommandWaitLogo"
	_logo.texture = load("res://branding/rugby-legacy-27-logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var composite := ShaderMaterial.new()
	composite.shader = load("res://branding/black_key.gdshader")
	_logo.material = composite
	_frame.add_child(_logo)
	_status.name = "CommandWaitStatus"
	_status.max_lines_visible = 1
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.accessibility_live = AccessibilityServer.LIVE_POLITE
	_configure(_status, Charte.IVOIRE, Charte.TITRE_GRAS)
	_kicker.name = "CommandWaitKicker"
	_kicker.uppercase = true
	_kicker.max_lines_visible = 1
	_kicker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_configure(_kicker, Charte.IVOIRE_2, Charte.TITRE_GRAS)
	_detail.name = "CommandWaitDetail"
	_detail.max_lines_visible = 2
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_configure(_detail, Charte.IVOIRE_2, Charte.TEXTE)
	_tip.name = "CommandWaitNote"
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_configure(_tip, Charte.IVOIRE, Charte.TEXTE)
	_tip_title.name = "CommandWaitNoteTitle"
	_tip_title.uppercase = true
	_tip_title.max_lines_visible = 1
	_tip_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_configure(_tip_title, Charte.IVOIRE_2, Charte.TITRE_GRAS)
	_progress_text.name = "CommandWaitProgressLabel"
	_configure(_progress_text, Charte.IVOIRE_2, Charte.TEXTE)
	_percent.name = "CommandWaitPercent"
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_configure(_percent, Charte.IVOIRE, Charte.TITRE_EXTRA_ITALIQUE)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_long.name = "CommandWaitLong"
	_long.max_lines_visible = 1
	_long.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_configure(_long, Charte.IVOIRE, Charte.TEXTE)
	_club_line.name = "CommandWaitClubLine"
	_club_line.max_lines_visible = 1
	_club_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_configure(_club_line, Charte.IVOIRE_2, Charte.TEXTE)
	_legend.name = "CommandWaitLegend"
	_legend.max_lines_visible = 1
	_legend.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_configure(_legend, Charte.IVOIRE, Charte.TEXTE)
	_stop_reason.name = "CommandWaitStopReason"
	_stop_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stop_reason.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_configure(_stop_reason, Charte.IVOIRE_3, Charte.TEXTE)
	_enter_hint.name = "CommandWaitEnterHint"
	_enter_hint.text = "Entrée"
	_configure(_enter_hint, Charte.IVOIRE_3, Charte.TEXTE)
	_link(_next_note, "CommandWaitNextNote", "Anecdote suivante →", "Une autre anecdote ou un autre conseil (Entrée)")
	_next_note.pressed.connect(next_note)
	_link(_stop, "CommandWaitStop", "Arrêter →", "")
	_stop.pressed.connect(func() -> void: stop_requested.emit())

	_reveal.one_shot = true
	add_child(_reveal)
	_reveal.timeout.connect(_on_reveal)
	resized.connect(_layout)
	_layout()
	dismiss()


## Contexte visuel facultatif : kicker, date (AAAA-MM-JJ), flip (passage de jour), accent (couleur du club),
## notes [{title, text}] (conseils et faits réels), photo (longs chargements), club_name / division / season /
## stadium (lus dans le modèle ; vide = ligne omise), progress (0 à 1, jamais inventé ; absent = indéterminée),
## progress_label, cancellable (arrêt réel).
func set_context(context: Dictionary) -> void:
	_context = context.duplicate(true)
	_notes.clear()
	for note: Variant in context.get("notes", []):
		if note is Dictionary and not str(note.get("text", "")).is_empty(): _notes.append(note)
	_note_index = int(context.get("note_seed", 0)) % maxi(1, _notes.size())
	_photo = null
	if context.get("photo", false):
		var B = load("res://ui/banque_images.gd")
		var id: String = B.choisir("chargement", {}, int(context.get("note_seed", 0)))
		if not id.is_empty(): _photo = B.texture(id)
	_progress = float(context.progress) if context.get("progress") is float or context.get("progress") is int else -1.0
	_cancellable = bool(context.get("cancellable", false))
	_note_clock = 0.0
	_apply_note()
	_layout()
	queue_redraw()


## Pourcentage réel fourni par le moteur (0 à 1) et son libellé ; -1 : indéterminée.
func set_progress(value: float, label: String = "") -> void:
	_progress = value if value >= 0.0 else -1.0
	_context["progress_label"] = label
	_layout()
	queue_redraw()


## Passe à la note suivante (lien « Anecdote suivante → » et touche Entrée).
func next_note() -> void:
	if _notes.size() < 2: return
	_note_index = (_note_index + 1) % _notes.size()
	_note_clock = 0.0
	_apply_note()
	queue_redraw()


## Touche reçue pendant l'attente : Entrée change d'anecdote (écran de chargement long). Vrai si elle est prise.
func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo): return false
	if not stage_mode() or not _next_note.visible: return false
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		next_note()
		return true
	return false


## Vrai pour « Le stade, puis le terrain » (photo plein écran).
func stage_mode() -> bool:
	return _photo != null


## L'interface absorbe les clics dès l'appel. Le panneau peut apparaître plus tard.
func present(message: String, animate: bool = true, delay_seconds: float = 0.0) -> void:
	var text := message.strip_edges()
	if text.is_empty():
		text = "Un instant…"
	_status.text = text
	_status.accessibility_name = text
	_motion = animate
	if visible and not _closing:
		if _frame.visible:
			set_process(true)
			queue_redraw()
		return
	_closing = false
	_kill_tween()
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	_frame.hide()
	_alpha = 0.0
	modulate.a = 1.0
	_since_ms = Time.get_ticks_msec()
	_timing = true
	queue_redraw()
	_elapsed = 0.0
	_shown_for = 0.0
	if delay_seconds > 0.0:
		_reveal_at_ms = Time.get_ticks_msec() + roundi(delay_seconds * 1000.0)
		_reveal.start(delay_seconds)
	else:
		_show_frame()


## Écran posé tout de suite, opaque et sans fondu : juste avant un travail lourd du fil principal
## (scène 3D du coup d'envoi), l'image doit être à l'écran avant le gel, jamais un écran figé sans message.
func reveal_now(message: String = "") -> void:
	var text := message.strip_edges()
	if not text.is_empty():
		_status.text = text
		_status.accessibility_name = text
	# Au-dessus des scènes contextuelles (vestiaire), ajoutées après lui au même plan.
	if get_parent() != null: get_parent().move_child(self, -1)
	if not visible or _closing:
		_closing = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		show()
		_elapsed = 0.0
		_since_ms = Time.get_ticks_msec()
		_timing = true
	_reveal.stop()
	_kill_tween()
	_frame.show()
	_shown_for = 0.0
	_set_alpha(1.0)
	modulate.a = 1.0
	set_process(true)
	queue_redraw()


func dismiss() -> void:
	_reveal.stop()
	if not visible or not _frame.visible or not is_inside_tree():
		_finish_dismiss()
		return
	# Jamais de flash : un panneau apparu se retire en fondu, sans retenir les clics.
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_set_alpha, _alpha, 0.0, FADE_OUT if _motion else 0.06)
	_tween.tween_callback(_finish_dismiss)


## Vrai lorsque le panneau est affiché (et non pendant le seul délai d'attente).
func panel_visible() -> bool:
	return visible and _frame.visible and not _closing


## Vrai tant que le voile retient clics et clavier (attente ou panneau affiché).
## Pendant le fondu de sortie, la réponse est déjà reçue : rien n'est retenu.
func blocks_input() -> bool:
	return visible and not _closing


func _finish_dismiss() -> void:
	_kill_tween()
	_closing = false
	_timing = false
	_frame.hide()
	hide()
	_alpha = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null


func _set_alpha(value: float) -> void:
	_alpha = value
	_frame.modulate.a = value
	queue_redraw()


func _on_reveal() -> void:
	var remaining := _reveal_at_ms - Time.get_ticks_msec()
	if remaining > 0:
		_reveal.start(remaining / 1000.0)
		return
	_show_frame()


func _show_frame() -> void:
	_frame.show()
	_shown_for = 0.0
	_kill_tween()
	_frame.modulate.a = 0.0
	_alpha = 0.0
	if _motion and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_alpha, 0.0, 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_alpha(1.0)
	set_process(true)
	queue_redraw()


func _configure(label: Label, color: Color, font: Font) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", font)
	_frame.add_child(label)


## Lien de la charte : texte ivoire + flèche, souligné au survol ; aucun cadre.
func _link(button: LinkButton, node_name: String, text: String, tip: String) -> void:
	button.name = node_name
	button.text = text
	button.tooltip_text = tip
	button.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Charte.TITRE_GRAS)
	button.add_theme_color_override("font_color", Charte.IVOIRE)
	button.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	button.add_theme_color_override("font_pressed_color", Charte.IVOIRE_2)
	button.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	_frame.add_child(button)


## Taille réelle d'un texte : jamais sous `floor_px` (12 px pour le texte, 13 pour le conseil).
func _px(design: float, scale: float, floor_px: int) -> int:
	return maxi(floor_px, roundi(design * scale))


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position.floor()
	control.size = rect.size.floor()


func _set_font(control: Control, px: int) -> void:
	control.add_theme_font_size_override("font_size", px)


func _layout() -> void:
	if not is_node_ready(): return
	if stage_mode(): _layout_stage()
	else: _layout_panel()
	queue_redraw()


## Panneau sur le bureau : largeur ≈ 40 % de l'écran (420 à 860 px), hauteur selon le contenu, centré.
func _layout_panel() -> void:
	var width := clampf(size.x * 0.40, 420.0, 860.0)
	width = minf(width, size.x - 32.0)
	var s := clampf(width / 640.0, 0.6, 1.4)
	_scale = s
	var pad := roundf(30.0 * s)
	var inner := width - pad * 2.0
	var dates := _dates()
	var has_dates := not dates.is_empty()
	var card_w := roundf(78.0 * s)
	var card_h := roundf(92.0 * s)
	var x_text := pad + ((card_w * 2.0 + roundf(34.0 * s) + roundf(18.0 * s)) if has_dates else 0.0)
	var text_w := width - pad - x_text
	var y := roundf(26.0 * s)
	var k_px := _px(13.0, s, 12)
	var t_px := _px(26.0, s, 20)
	var d_px := _px(14.0, s, 12)
	var head_h := maxf(card_h, float(k_px + t_px + d_px * 2) * 1.55) if has_dates else float(k_px + t_px + d_px) * 1.5
	_set_font(_kicker, k_px)
	_set_font(_status, t_px)
	_set_font(_detail, d_px)
	_kicker.uppercase = true
	_status.uppercase = false
	_status.add_theme_font_override("font", Charte.TITRE_GRAS)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	var line_k := roundf(k_px * 1.4)
	var line_t := roundf(t_px * 1.3)
	var line_d := roundf(d_px * 1.45)
	var block := line_k + line_t + line_d * 2.0
	var y0 := y + maxf(0.0, (head_h - block) * 0.5)
	_place(_kicker, Rect2(x_text, y0, text_w, line_k))
	_place(_status, Rect2(x_text, y0 + line_k, text_w, line_t))
	_place(_detail, Rect2(x_text, y0 + line_k + line_t, text_w, line_d * 2.0))
	y += head_h + roundf(20.0 * s)
	# Barre de progression.
	var bar_h := maxf(8.0, roundf(14.0 * s))
	var bar_y := y
	y += bar_h + roundf(8.0 * s)
	var p_px := _px(12.0, s, 12)
	_set_font(_progress_text, p_px)
	_set_font(_percent, _px(22.0, s, 18))
	var has_row := not str(_context.get("progress_label", "")).is_empty() or _progress >= 0.0
	var row_h := roundf(maxi(p_px, _px(22.0, s, 18)) * 1.35) if has_row else 0.0
	_place(_progress_text, Rect2(pad, y, inner * 0.7, row_h))
	_place(_percent, Rect2(pad + inner * 0.7, y, inner * 0.3, row_h))
	_progress_text.text = str(_context.get("progress_label", ""))
	_percent.text = "%d %%" % roundi(_progress * 100.0) if _progress >= 0.0 else ""
	y += row_h + roundf(14.0 * s)
	var rule_y := y
	y += roundf(14.0 * s)
	# Conseil de Gabi / fait du club.
	var n_px := _px(13.5, s, 13)
	var nt_px := _px(12.0, s, 12)
	_set_font(_tip_title, nt_px)
	_set_font(_tip, n_px)
	var tip_x := pad + roundf(14.0 * s)
	var tip_line := roundf(n_px * 1.45)
	var tl_h := roundf(nt_px * 1.5)
	var has_note := not _notes.is_empty()
	if has_note:
		_place(_tip_title, Rect2(tip_x, y, inner - 14.0 * s, tl_h))
		_place(_tip, Rect2(tip_x, y + tl_h, inner - 14.0 * s, tip_line * 2.0))
		_tip.max_lines_visible = 2
	var tip_top := y
	if has_note: y += tl_h + tip_line * 2.0
	# Long : message et sortie.
	var long_h := 0.0
	var long_y := y + roundf(10.0 * s)
	var l_px := _px(13.0, s, 13)
	_set_font(_long, l_px)
	_set_font(_stop, _px(16.0, s, 14))
	_set_font(_stop_reason, _px(12.0, s, 12))
	var stop_w := roundf(110.0 * s)
	var stop_h := roundf(maxi(l_px, _px(16.0, s, 14)) * 1.6)
	_place(_long, Rect2(pad, long_y, inner - stop_w - 12.0 * s, stop_h))
	_place(_stop, Rect2(pad + inner - stop_w, long_y, stop_w, stop_h))
	_stop.size = Vector2(stop_w, stop_h)
	var reason_h := roundf(_px(12.0, s, 12) * 1.45) * 2.0
	_place(_stop_reason, Rect2(pad, long_y + stop_h, inner, reason_h))
	long_h = stop_h + reason_h + roundf(10.0 * s)
	_geo = {"mode": "panel", "pad": pad, "bar_y": bar_y, "bar_h": bar_h, "rule_y": rule_y, "tip_top": tip_top, "has_note": has_note,
		"card_w": card_w, "card_h": card_h, "head_y": roundf(26.0 * s), "has_dates": has_dates, "long_y": long_y, "long_h": long_h, "inner": inner}
	_update_long()
	var long_shown := _long_visible()
	var height := y + (long_h if long_shown else 0.0) + roundf(26.0 * s)
	_frame.size = Vector2(width, roundf(height))
	_frame.position = ((size - _frame.size) * 0.5).floor()
	for link: LinkButton in [_next_note, _stop]: link.hide()
	_enter_hint.hide()
	_legend.hide()
	_club_line.hide()
	_logo.hide()
	_next_note.visible = false
	_stop.visible = long_shown
	_stop_reason.visible = long_shown and not _cancellable
	_long.visible = long_shown
	_tip_title.visible = has_note
	_tip.visible = has_note
	_progress_text.visible = true
	_percent.visible = _progress >= 0.0
	_kicker.text = str(_context.get("kicker", ""))
	_kicker.visible = not _kicker.text.is_empty()
	_detail.text = str(_context.get("detail", ""))
	_detail.visible = not _detail.text.is_empty()
	_stop.visible = long_shown
	_stop.disabled = not _cancellable
	_stop.tooltip_text = "Arrêter l'opération en cours" if _cancellable else NO_STOP_REASON
	_stop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _cancellable else Control.CURSOR_ARROW


## Le stade, puis le terrain : photo en haut (72 % de la hauteur), bandeau noir en bas.
func _layout_stage() -> void:
	var k := clampf(size.x / 1920.0, 0.6, 1.5)
	_scale = k
	_frame.position = Vector2.ZERO
	_frame.size = size
	var margin := roundf(64.0 * k)
	var band_top := roundf(size.y * 0.72)
	var logo_h := roundf(150.0 * k)
	_place(_logo, Rect2(roundf(70.0 * k), roundf(18.0 * k), roundf(logo_h * 2.28), logo_h))
	# Lieu : à droite, au-dessus de la photo.
	var lg_px := _px(14.0, k, 13)
	_set_font(_legend, lg_px)
	var stadium := str(_context.get("stadium", "")).strip_edges()
	_legend.text = stadium
	var lg_w := minf(roundf(Charte.TEXTE.get_string_size(stadium, HORIZONTAL_ALIGNMENT_LEFT, -1, lg_px).x) + 20.0, size.x * 0.4)
	var lg_h := roundf(lg_px * 1.9)
	_place(_legend, Rect2(size.x - margin - lg_w + 10.0, roundf(58.0 * k), lg_w - 20.0, lg_h))
	_geo = {"mode": "stage", "band_top": band_top, "margin": margin, "legend": Rect2(size.x - margin - lg_w, roundf(58.0 * k) - 4.0, lg_w, lg_h + 8.0), "has_legend": not stadium.is_empty()}
	# Bandeau : surtitre, titre, club · division · saison.
	var s_px := _px(13.0, k, 12)
	var t_px := _px(56.0, k, 30)
	var c_px := _px(16.0, k, 13)
	_set_font(_kicker, s_px)
	_set_font(_status, t_px)
	_set_font(_club_line, c_px)
	_status.uppercase = true
	_status.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	var left_w := size.x * 0.6 - margin
	var y := band_top + roundf(36.0 * k)
	var s_h := roundf(s_px * 1.5)
	var t_h := roundf(t_px * 1.15)
	var c_h := roundf(c_px * 1.5)
	_place(_kicker, Rect2(margin, y, left_w, s_h))
	_place(_status, Rect2(margin, y + s_h, left_w, t_h))
	_place(_club_line, Rect2(margin, y + s_h + t_h + 2.0, left_w, c_h))
	var parts: Array[String] = []
	for key: String in ["club_name", "division", "season"]:
		var value := str(_context.get(key, "")).strip_edges()
		if not value.is_empty(): parts.append(value)
	_club_line.text = " · ".join(parts)
	# Barre en segments et pied.
	var bar_h := maxf(14.0, roundf(40.0 * k))
	var bar_y := size.y - roundf(104.0 * k)
	var foot_px := _px(14.0, k, 13)
	_set_font(_progress_text, foot_px)
	_set_font(_percent, _px(30.0, k, 22))
	var foot_y := bar_y + bar_h + roundf(8.0 * k)
	var foot_h := size.y - foot_y - roundf(8.0 * k)
	_place(_progress_text, Rect2(margin, foot_y, size.x * 0.6, maxf(foot_h, 18.0)))
	_place(_percent, Rect2(size.x - margin - 200.0 * k, foot_y - roundf(6.0 * k), 200.0 * k, maxf(foot_h + 6.0 * k, 28.0)))
	_progress_text.text = str(_context.get("progress_label", ""))
	_percent.text = "%d %%" % roundi(_progress * 100.0) if _progress >= 0.0 else ""
	_set_font(_long, _px(14.0, k, 13))
	_place(_long, Rect2(margin, y + s_h + t_h + c_h + 2.0, left_w, roundf(_px(14.0, k, 13) * 1.5)))
	# En coulisses.
	var x_note := roundf(size.x * 0.675)
	var note_w := size.x - margin - x_note
	var nt_px := _px(12.0, k, 12)
	var n_px := _px(16.0, k, 13)
	_set_font(_tip_title, nt_px)
	_set_font(_tip, n_px)
	_set_font(_next_note, _px(16.0, k, 14))
	_set_font(_enter_hint, _px(13.0, k, 12))
	var mark_h := roundf(100.0 * k)
	var tx := x_note + Charte.decalage(mark_h) + roundf(16.0 * k)
	var tw := size.x - margin - tx
	var link_h := roundf(maxi(_px(14.0, k, 13), 13) * 1.6)
	var link_y := bar_y - link_h - roundf(12.0 * k)
	var tl_h := roundf(nt_px * 1.5)
	var tip_y := y + tl_h
	var line := roundf(n_px * 1.42)
	var lines := clampi(int(floor((link_y - 4.0 - tip_y) / line)), 1, 3)
	_tip.max_lines_visible = lines
	_place(_tip_title, Rect2(tx, y, tw, tl_h))
	_place(_tip, Rect2(tx, tip_y, tw, line * lines))
	var link_w := roundf(Charte.TITRE_GRAS.get_string_size("Anecdote suivante →", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(16.0, k, 14)).x) + 6.0
	_place(_next_note, Rect2(tx, link_y, link_w, link_h))
	_next_note.size = Vector2(link_w, link_h)
	_place(_enter_hint, Rect2(tx + link_w + roundf(14.0 * k), link_y, 80.0 * k, link_h))
	var has_note := not _notes.is_empty()
	_geo["bar_y"] = bar_y
	_geo["bar_h"] = bar_h
	_geo["note_x"] = x_note
	_geo["note_y"] = y
	_geo["note_h"] = mark_h
	_geo["has_note"] = has_note
	_update_long()
	_logo.visible = true
	_legend.visible = not stadium.is_empty()
	_club_line.visible = not parts.is_empty()
	_kicker.text = str(_context.get("kicker", ""))
	_kicker.visible = not _kicker.text.is_empty()
	_detail.hide()
	_progress_text.visible = not _progress_text.text.is_empty()
	_percent.visible = _progress >= 0.0
	_tip_title.visible = has_note
	_tip.visible = has_note
	_next_note.visible = _notes.size() > 1
	_enter_hint.visible = _notes.size() > 1
	_stop.hide()
	_stop_reason.hide()
	_long.visible = _long_visible()


func _long_visible() -> bool:
	return visible and _timing and float(Time.get_ticks_msec() - _since_ms) / 1000.0 >= LONG_SECONDS


func _update_long() -> void:
	var seconds := int((Time.get_ticks_msec() - _since_ms) / 1000) if _timing else 0
	if stage_mode(): _long.text = "Plus long que prévu (%d s)… Ne ferme pas le jeu." % seconds
	else: _long.text = "Plus long que prévu (%d s)…" % seconds
	_stop_reason.text = NO_STOP_REASON


func _process(delta: float) -> void:
	_shown_for += delta
	if _motion: _elapsed += delta
	var interval := STAGE_NOTE_SECONDS if stage_mode() else TIP_SECONDS
	if _notes.size() > 1:
		_note_clock += delta
		if _note_clock >= interval:
			_note_clock = 0.0
			_note_index = (_note_index + 1) % _notes.size()
			_apply_note()
	if _notes.size() > 1 and _motion:
		var phase := _note_clock / interval
		_tip.modulate.a = smoothstep(0.0, 0.06, phase) * (1.0 - smoothstep(0.94, 1.0, phase))
	else:
		_tip.modulate.a = 1.0
	# Le « Plus long que prévu » apparaît et se met à jour sans reconstruire tout le temps.
	var long_now := _long_visible()
	if long_now != _long.visible or (long_now and Engine.get_process_frames() % 30 == 0): _layout()
	queue_redraw()


func _apply_note() -> void:
	if _notes.is_empty():
		_tip.text = ""
		_tip_title.text = ""
		return
	var note: Dictionary = _notes[_note_index]
	_tip.text = str(note.get("text", ""))
	var title := str(note.get("title", "Le conseil de Gabi"))
	_tip_title.text = ("En coulisses · " + title) if stage_mode() else title


func _accent() -> Color:
	var value: Variant = _context.get("accent")
	return Charte.club_trait(value) if value is Color else Charte.CLUB_TRAIT


func _draw() -> void:
	if not visible or not _frame.visible or _geo.is_empty():
		return
	if _geo.mode == "stage": _draw_stage()
	else: _draw_panel()


func _fade(color: Color) -> Color:
	return Color(color, color.a * _alpha)


## Parallélogramme incliné à 10° (marqueurs de la charte) : x0 est le bord bas-gauche.
func _slant(x0: float, y0: float, width: float, height: float, color: Color) -> void:
	var dx := Charte.decalage(height)
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + dx, y0), Vector2(x0 + dx + width, y0), Vector2(x0 + width, y0 + height), Vector2(x0, y0 + height)]), _fade(color))


## Ovale du ballon (marque la tête de la barre).
func _oval(center: Vector2, rx: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		points.append(center + Vector2(cos(t) * rx, sin(t) * rx * 0.6).rotated(-0.35))
	draw_colored_polygon(points, _fade(color))


func _draw_panel() -> void:
	var s := _scale
	draw_rect(Rect2(Vector2.ZERO, size), _fade(SCRIM))
	var origin := _frame.position
	var w := _frame.size.x
	draw_rect(Rect2(origin, _frame.size), _fade(Charte.PANNEAU))
	# Filet de tête : un trait fin sur toute la largeur et le segment du club (pas de cadre complet).
	draw_rect(Rect2(origin, Vector2(w, 1.0)), _fade(Charte.FILET))
	draw_rect(Rect2(origin, Vector2(roundf(w * 0.15), maxf(3.0, roundf(3.0 * s)))), _fade(_accent()))
	var pad: float = _geo.pad
	if _geo.has_dates: _draw_dates(origin, s)
	# Barre de progression.
	var bar := Rect2(origin + Vector2(pad, _geo.bar_y), Vector2(w - pad * 2.0, _geo.bar_h))
	_draw_bar(bar, 4, Charte.PANNEAU_3, Charte.IVOIRE_2, Charte.FILET)
	# Séparation et conseil.
	draw_rect(Rect2(origin + Vector2(pad, _geo.rule_y), Vector2(w - pad * 2.0, 1.0)), _fade(Charte.FILET))
	if _geo.has_note: _slant(origin.x + pad, origin.y + _geo.tip_top + 2.0, maxf(2.0, roundf(2.0 * s)), roundf(44.0 * s), _accent())


func _draw_dates(origin: Vector2, s: float) -> void:
	var today := _date_parts(str(_context.get("date", "")))
	var tomorrow := _date_parts(_shift_date(str(_context.get("date", "")), 1))
	var cw: float = _geo.card_w
	var ch: float = _geo.card_h
	var x: float = origin.x + _geo.pad
	var y: float = origin.y + _geo.head_y
	for card: Array in [[x, today], [x + cw + roundf(34.0 * s), tomorrow]]:
		var rect := Rect2(card[0], y, cw, ch)
		draw_rect(rect, _fade(Charte.PANNEAU_3))
		var parts: Dictionary = card[1]
		var top_px := _px(12.0, s, 12)
		var small := "%s %s" % [str(parts.weekday).substr(0, 3) + ".", parts.month]
		_centered(Charte.TITRE_GRAS, Vector2(rect.get_center().x, rect.position.y + top_px + roundf(10.0 * s)), small, top_px, Charte.IVOIRE_2)
		_centered(Charte.TITRE_EXTRA_ITALIQUE, Vector2(rect.get_center().x, rect.end.y - roundf(14.0 * s)), str(parts.day), _px(42.0, s, 30), Charte.IVOIRE)
	var arrow_px := _px(16.0, s, 14)
	_centered(Charte.TEXTE, Vector2(x + cw + roundf(17.0 * s), y + ch * 0.5 + arrow_px * 0.35), "→", arrow_px, Charte.IVOIRE_2)


func _centered(font: Font, base: Vector2, text: String, px: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2(base.x - width * 0.5, base.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, _fade(color))


## Barre en segments : remplie jusqu'à `_progress` ; indéterminée (aucune donnée réelle) : un bloc qui glisse,
## ou fixe sous « Mouvements réduits ».
func _draw_bar(rect: Rect2, segments: int, back: Color, fill: Color, rule: Color) -> void:
	draw_rect(rect, _fade(back))
	var gap := 2.0
	var seg_w := (rect.size.x - gap * (segments - 1)) / segments
	var lit := Rect2()
	if _progress >= 0.0:
		lit = Rect2(rect.position, Vector2(rect.size.x * clampf(_progress, 0.0, 1.0), rect.size.y))
	else:
		var block := rect.size.x * 0.22
		var travel := rect.size.x - block
		var phase := fposmod(_elapsed, 2.4) / 2.4 if _motion else 0.0
		var eased := phase * phase * (3.0 - 2.0 * phase)
		lit = Rect2(rect.position + Vector2(travel * eased, 0), Vector2(block, rect.size.y))
	if lit.size.x > 0.0: draw_rect(lit, _fade(fill))
	for i in range(1, segments):
		var gx := rect.position.x + i * (seg_w + gap) - gap
		draw_rect(Rect2(gx, rect.position.y, gap, rect.size.y), _fade(Charte.NUIT if rule == Charte.NUIT else Charte.PANNEAU))
	if lit.size.x > 0.0:
		var head := lit.end.x
		_slant(head - 2.0, rect.position.y - 3.0, 3.0, rect.size.y + 6.0, Charte.IVOIRE)
		if rect.size.y >= 14.0: _oval(Vector2(head - rect.size.y * 0.5, rect.get_center().y), rect.size.y * 0.32, Charte.IVOIRE)


func _draw_stage() -> void:
	var band_top: float = _geo.band_top
	# Bandeau noir, puis photo au-dessus (recadrée en couverture), voile plat pour la lisibilité du logo.
	draw_rect(Rect2(Vector2.ZERO, size), _fade(Charte.NUIT))
	if _photo != null:
		var dst := Rect2(0, 0, size.x, band_top)
		var factor := maxf(dst.size.x / _photo.get_width(), dst.size.y / _photo.get_height())
		var src_size := dst.size / factor
		var src := Rect2((_photo.get_size() - src_size) * Vector2(0.5, 0.55), src_size)
		draw_texture_rect_region(_photo, dst, src, Color(Color.WHITE, _alpha))
		draw_rect(dst, _fade(Color(Charte.NUIT, 0.3)))
	if _geo.has_legend: draw_rect(_geo.legend, _fade(Color(Charte.NUIT, 0.78)))
	var m: float = _geo.margin
	var bar := Rect2(m, _geo.bar_y, size.x - m * 2.0, _geo.bar_h)
	_draw_bar(bar, SEGMENTS, Charte.PANNEAU, Charte.IVOIRE_2, Charte.NUIT)
	if _geo.has_note:
		_slant(_geo.note_x, _geo.note_y + 2.0, maxf(2.0, roundf(2.0 * _scale)), _geo.note_h, _accent())


static func _date_parts(iso: String) -> Dictionary:
	var parts := iso.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return {}
	var month := int(parts[1])
	if month < 1 or month > 12: return {}
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	var weekday := int(Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0))
	return {"day": str(int(parts[2])), "month": MONTHS[month - 1], "year": parts[0], "weekday": WEEKDAYS[weekday]}


static func _shift_date(iso: String, days: int) -> String:
	if _date_parts(iso).is_empty(): return ""
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00") + days * 86400
	return Time.get_date_string_from_unix_time(unix)


## Cartes de date du passage de jour : [jour, lendemain] ; vide hors passage de jour ou sans date réelle.
func _dates() -> Array:
	var iso := str(_context.get("date", ""))
	if not bool(_context.get("flip", false)) or _date_parts(iso).is_empty(): return []
	return [_date_parts(iso), _date_parts(_shift_date(iso, 1))]
