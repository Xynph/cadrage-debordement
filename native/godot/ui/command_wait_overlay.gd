extends Control
## Panneau d’attente « vestiaire » : centré sur l’écran en cours (≈ 40 % de la
## largeur), l’écran derrière légèrement assombri. N’apparaît qu’après un court
## délai : une réponse rapide ne montre rien. Le contrôleur appelant reste
## propriétaire de la commande ; ce panneau ne fait que patienter avec le joueur.
##
## Tout est dessiné en code (_draw) : calendrier à feuilles qui tourne au passage
## de jour, terrain dont les lignes se tracent, ballon ovale aux rebonds
## irréguliers, barre de progression en ligne d’en-but, conseil de Gabi ou fait
## du club. Mouvements réduits : image fixe, aucune animation.

const DESIGN := Vector2(640, 396)
const SCRIM := Color(0.02, 0.035, 0.03, 0.42)
const PANEL := Color("121a1c")
const PANEL_HIGH := Color("18231f")
const LINE := Color("2c3a37")
const FIELD_A := Color("15291f")
const FIELD_B := Color("122319")
const CHALK := Color(0.93, 0.92, 0.86, 0.82)
const GOLD := Color("e0b35a")
const IVORY := Color("f2ecdc")
const INK := Color("0b1012")
const MUTED := Color("aeb9b3")
const FAINT := Color("7b8a84")
const RED := Color("d43e47")
const LEATHER := Color("c98f45")
const TITLE_FONT = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
const BOLD_FONT = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const BODY_FONT = preload("res://fonts/DMSans.ttf")
const FADE_IN := 0.18
const FADE_OUT := 0.14
const TIP_SECONDS := 4.6
const MONTHS := ["JANV.", "FÉVR.", "MARS", "AVRIL", "MAI", "JUIN", "JUIL.", "AOÛT", "SEPT.", "OCT.", "NOV.", "DÉC."]
const WEEKDAYS := ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]
## Rebonds d’un ballon ovale : hauteur relative et durée de chaque rebond.
const BOUNCES := [[1.0, 0.62], [0.42, 0.34], [0.78, 0.5], [0.18, 0.2], [0.55, 0.42], [0.3, 0.27], [0.86, 0.56], [0.12, 0.16]]

var _frame := Control.new()
var _status := Label.new()
var _tip := Label.new()
var _reveal := Timer.new()
var _scale := 1.0
var _origin := Vector2.ZERO
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
	_status.name = "CommandWaitStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 1
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.accessibility_live = AccessibilityServer.LIVE_POLITE
	_configure_label(_status, IVORY, TITLE_FONT, HORIZONTAL_ALIGNMENT_LEFT)
	_tip.name = "CommandWaitNote"
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.max_lines_visible = 2
	_tip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_configure_label(_tip, MUTED, BODY_FONT, HORIZONTAL_ALIGNMENT_LEFT)
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_reveal.one_shot = true
	add_child(_reveal)
	_reveal.timeout.connect(_show_frame)
	resized.connect(_layout)
	_layout()
	dismiss()


## Contexte visuel facultatif : kicker, date (AAAA-MM-JJ), flip (passage de jour),
## accent (couleur du club), notes [{title, text}] (conseils et faits réels).
func set_context(context: Dictionary) -> void:
	_context = context.duplicate(true)
	_notes.clear()
	for note: Variant in context.get("notes", []):
		if note is Dictionary and not str(note.get("text", "")).is_empty(): _notes.append(note)
	_note_index = int(context.get("note_seed", 0)) % maxi(1, _notes.size())
	_note_clock = 0.0
	_apply_note()
	queue_redraw()


## L’interface absorbe les clics dès l’appel. Le panneau peut apparaître plus tard.
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
	queue_redraw()
	_elapsed = 0.0
	_shown_for = 0.0
	if delay_seconds > 0.0:
		_reveal.start(delay_seconds)
	else:
		_show_frame()


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


## Vrai lorsque le panneau est affiché (et non pendant le seul délai d’attente).
func panel_visible() -> bool:
	return visible and _frame.visible and not _closing


## Vrai tant que le voile retient clics et clavier (attente ou panneau affiché).
## Pendant le fondu de sortie, la réponse est déjà reçue : rien n’est retenu.
func blocks_input() -> bool:
	return visible and not _closing


func _finish_dismiss() -> void:
	_kill_tween()
	_closing = false
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


func _configure_label(label: Label, color: Color, font: Font, align: HorizontalAlignment) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", font)
	_frame.add_child(label)


func _layout() -> void:
	var width := clampf(size.x * 0.40, 420.0, 860.0)
	width = minf(width, size.x - 32.0)
	_scale = maxf(0.4, width / DESIGN.x)
	if DESIGN.y * _scale > size.y - 32.0: _scale = maxf(0.4, (size.y - 32.0) / DESIGN.y)
	_frame.size = DESIGN * _scale
	_frame.position = ((size - _frame.size) * 0.5).floor()
	_origin = _frame.position
	_status.position = Vector2(30, 238) * _scale
	_status.size = Vector2(580, 34) * _scale
	_status.add_theme_font_size_override("font_size", roundi(26 * _scale))
	_tip.position = Vector2(30, 343) * _scale
	_tip.size = Vector2(580, 44) * _scale
	_tip.add_theme_font_size_override("font_size", roundi(13.5 * _scale))
	queue_redraw()


func _process(delta: float) -> void:
	_shown_for += delta
	if _motion: _elapsed += delta
	if _notes.size() > 1:
		_note_clock += delta
		if _note_clock >= TIP_SECONDS:
			_note_clock = 0.0
			_note_index = (_note_index + 1) % _notes.size()
			_apply_note()
	if _notes.size() > 1 and _motion:
		var phase := _note_clock / TIP_SECONDS
		_tip.modulate.a = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.92, 1.0, phase))
	else:
		_tip.modulate.a = 1.0
	queue_redraw()


func _apply_note() -> void:
	if _notes.is_empty():
		_tip.text = ""
		return
	_tip.text = str(_notes[_note_index].get("text", ""))


func _accent() -> Color:
	var value: Variant = _context.get("accent")
	return value if value is Color else RED


func _draw() -> void:
	if not visible or not _frame.visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(SCRIM, SCRIM.a * _alpha))
	var rise := (1.0 - _alpha) * 10.0
	draw_set_transform(_origin + Vector2(0, rise), 0, Vector2.ONE * _scale)
	var a := _alpha
	# Ombre portée et caisson.
	for i in 4:
		var grow := 3.0 + i * 4.0
		_rounded(Rect2(Vector2(-grow, -grow + 6), DESIGN + Vector2(grow, grow) * 2.0), Color(0, 0, 0, 0.09 * a), 18.0 + grow)
	_rounded(Rect2(Vector2.ZERO, DESIGN), Color(PANEL, a), 14.0)
	_rounded_outline(Rect2(Vector2.ZERO, DESIGN), Color(LINE, a), 14.0)
	# Bande du club puis filet d’or.
	draw_rect(Rect2(14, 0, DESIGN.x - 28, 3), Color(_accent(), a))
	draw_rect(Rect2(14, 3, DESIGN.x - 28, 1), Color(GOLD, 0.55 * a))
	_draw_header(a)
	_draw_calendar(Rect2(24, 56, 140, 164), a)
	_draw_pitch(Rect2(180, 56, 436, 164), a)
	_draw_try_line(Rect2(30, 284, 580, 30), a)
	# Pied : conseil de Gabi ou fait du club.
	draw_line(Vector2(30, 322), Vector2(610, 322), Color(LINE, a), 1.0)
	if not _notes.is_empty():
		var note: Dictionary = _notes[_note_index]
		var title := str(note.get("title", "LE CONSEIL DE GABI")).to_upper()
		draw_circle(Vector2(36, 334), 3.0, Color(GOLD if note.get("kind", "tip") == "tip" else _accent(), a))
		draw_string(BOLD_FONT, Vector2(46, 339), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(GOLD, a * _tip.modulate.a))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_header(a: float) -> void:
	var kicker := str(_context.get("kicker", "EN COULISSES")).to_upper()
	draw_string(BOLD_FONT, Vector2(30, 38), kicker, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(GOLD, a))
	var kicker_width := BOLD_FONT.get_string_size(kicker, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var club := str(_context.get("club", ""))
	var right := DESIGN.x - 30.0
	if not club.is_empty():
		var chip := TITLE_FONT.get_string_size(club, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
		_rounded(Rect2(right - chip, 22, chip, 22), Color(_accent(), 0.9 * a), 4.0)
		draw_string(TITLE_FONT, Vector2(right - chip + 9, 38), club, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(IVORY, a))
		right -= chip + 12.0
	draw_line(Vector2(30 + kicker_width + 12, 33), Vector2(right, 33), Color(LINE, a), 1.0)


## Calendrier à feuilles : la page du jour se soulève et découvre le lendemain.
func _draw_calendar(box: Rect2, a: float) -> void:
	var today := _date_parts(str(_context.get("date", "")))
	var flip := bool(_context.get("flip", false)) and not today.is_empty()
	var tomorrow := _date_parts(_shift_date(str(_context.get("date", "")), 1)) if flip else {}
	# Socle et pages dessous (épaisseur).
	for i in range(3, 0, -1):
		_rounded(Rect2(box.position + Vector2(i * 2.0, i * 3.0), box.size), Color(Color("cfc6b2"), (0.35 + 0.12 * (3 - i)) * a), 8.0)
	var page := Rect2(box.position, box.size)
	if flip:
		# Cycle : pause, soulèvement, pause sur le lendemain, retour discret.
		var cycle := fposmod(_elapsed, 2.6) if _motion else 1.9
		var lift := smoothstep(0.55, 1.35, cycle) * (1.0 - smoothstep(2.3, 2.6, cycle))
		_page(page, tomorrow, a)
		if lift < 0.999:
			# La feuille du jour pivote autour de la reliure (raccourci vertical).
			var height := page.size.y * (1.0 - lift)
			var shade := Color(0, 0, 0, 0.25 * lift * a)
			var sheet := Rect2(page.position, Vector2(page.size.x, maxf(2.0, height)))
			_page(sheet, today, a, 1.0 - lift)
			draw_rect(Rect2(sheet.position + Vector2(0, sheet.size.y - 6), Vector2(sheet.size.x, 6)), shade)
	else:
		_page(page, today, a)
	# Reliure : deux anneaux.
	for x in [box.position.x + 38.0, box.position.x + box.size.x - 38.0]:
		draw_circle(Vector2(x, box.position.y + 2), 6.0, Color(INK, a))
		draw_arc(Vector2(x, box.position.y - 2), 6.0, PI, TAU, 12, Color(Color("8b938d"), a), 2.4, true)


func _page(rect: Rect2, parts: Dictionary, a: float, squash: float = 1.0) -> void:
	_rounded(rect, Color(IVORY, a), 8.0)
	var band_height := minf(rect.size.y, 34.0 * squash)
	_rounded(Rect2(rect.position, Vector2(rect.size.x, band_height)), Color(_accent(), a), 8.0)
	draw_rect(Rect2(rect.position + Vector2(0, band_height * 0.5), Vector2(rect.size.x, band_height * 0.5)), Color(_accent(), a))
	if squash < 0.35 or parts.is_empty():
		if parts.is_empty() and squash >= 0.35:
			_ball_shape(rect.get_center() + Vector2(0, 10), 26.0, 0.5, a)
		return
	var center_x := rect.position.x + rect.size.x * 0.5
	draw_set_transform(_origin + Vector2(0, (1.0 - _alpha) * 10.0) + Vector2(0, rect.position.y) * _scale, 0, Vector2(_scale, _scale * squash))
	var local_top := 0.0
	_center_string(TITLE_FONT, Vector2(center_x, local_top + 24), str(parts.month), 17, Color(IVORY, a))
	_center_string(BOLD_FONT, Vector2(center_x, local_top + 104), str(parts.day), 72, Color(INK, a))
	_center_string(TITLE_FONT, Vector2(center_x, local_top + 132), str(parts.weekday), 15, Color(Color("4a5450"), a))
	_center_string(BODY_FONT, Vector2(center_x, local_top + 152), str(parts.year), 11, Color(FAINT, a))
	draw_set_transform(_origin + Vector2(0, (1.0 - _alpha) * 10.0), 0, Vector2.ONE * _scale)


## Terrain vu du ciel : bandes de tonte, lignes tracées à la craie, ballon qui rebondit.
func _draw_pitch(box: Rect2, a: float) -> void:
	_rounded(box, Color(FIELD_B, a), 8.0)
	var inner := box.grow(-10)
	var stripes := 10
	for i in stripes:
		if i % 2 == 0: continue
		var w := inner.size.x / stripes
		draw_rect(Rect2(inner.position.x + i * w, inner.position.y, w, inner.size.y), Color(FIELD_A, a))
	var t := _elapsed if _motion else 99.0
	var draw_progress := clampf(t / 1.4, 0.0, 1.0)
	var x0 := inner.position.x + 26.0
	var x1 := inner.end.x - 26.0
	var top := inner.position.y + 6.0
	var bottom := inner.end.y - 6.0
	var chalk := Color(CHALK, CHALK.a * a)
	# Lignes de touche puis lignes transversales, dans l’ordre du traceur.
	_partial_line(Vector2(inner.position.x + 6, top), Vector2(inner.end.x - 6, top), draw_progress, chalk, 1.6)
	_partial_line(Vector2(inner.end.x - 6, bottom), Vector2(inner.position.x + 6, bottom), draw_progress, chalk, 1.6)
	var marks := [[0.0, "en-but"], [0.22, "22"], [0.4, "10"], [0.5, "50"], [0.6, "10"], [0.78, "22"], [1.0, "en-but"]]
	for index in marks.size():
		var mark: Array = marks[index]
		var x := lerpf(x0, x1, float(mark[0]))
		var local := clampf(draw_progress * 1.6 - index * 0.08, 0.0, 1.0)
		if mark[1] == "10":
			_dashed_line(Vector2(x, top), Vector2(x, bottom), local, chalk)
		else:
			_partial_line(Vector2(x, top), Vector2(x, top + (bottom - top) * local), 1.0, chalk, 2.0 if mark[1] != "22" else 1.4)
	# Lignes des 5 m et 15 m (pointillés courts).
	for y_ratio in [0.12, 0.3, 0.7, 0.88]:
		var y := lerpf(top, bottom, y_ratio)
		for x_ratio in [0.11, 0.22, 0.4, 0.5, 0.6, 0.78, 0.89]:
			var x := lerpf(x0, x1, x_ratio)
			draw_line(Vector2(x - 3, y), Vector2(x + 3, y), Color(chalk, chalk.a * 0.7 * draw_progress), 1.2)
	# Poteaux en H (vus du ciel : barre et montants).
	for side in [x0, x1]:
		var mid := (top + bottom) * 0.5
		var post := Color(GOLD, a * draw_progress)
		draw_line(Vector2(side, mid - 12), Vector2(side, mid + 12), post, 2.4)
		draw_circle(Vector2(side, mid - 12), 2.4, post)
		draw_circle(Vector2(side, mid + 12), 2.4, post)
	# Marquages des lignes, à la craie.
	for mark_text: Array in [[0.22, "22"], [0.4, "10"], [0.5, "50"], [0.6, "10"], [0.78, "22"]]:
		var label_x := lerpf(x0, x1, float(mark_text[0]))
		_center_string(TITLE_FONT, Vector2(label_x, bottom - 8), str(mark_text[1]), 11, Color(chalk, chalk.a * 0.55 * draw_progress))
	# Ballon : traversée gauche → droite, rebonds irréguliers, culbute.
	var travel := 4.2
	var phase := fposmod(t, travel) / travel if _motion else 0.56
	var x_ball := lerpf(x0 + 12, x1 - 12, phase)
	var y_ground := lerpf(top, bottom, 0.56 + 0.12 * sin(phase * TAU * 1.3))
	# Deux lignes de joueurs : l’attaque (club) suit le ballon, la défense monte et glisse.
	var players_alpha := a * smoothstep(0.6, 1.2, t)
	for k in 7:
		var spread := (k - 3) * 17.0
		var attack := Vector2(x_ball - 18.0 - absf(k - 3) * 7.0, clampf(y_ground + spread, top + 6, bottom - 6))
		var defense := Vector2(minf(x1 - 6, x_ball + 34.0 + sin(t * 1.7 + k) * 3.0 - absf(k - 3) * 2.0), clampf(y_ground + spread * 1.08 + sin(t * 1.3 + k * 0.7) * 2.0, top + 6, bottom - 6))
		draw_circle(attack, 3.6, Color(_accent(), players_alpha))
		draw_arc(attack, 3.6, 0.0, TAU, 12, Color(IVORY, 0.5 * players_alpha), 1.0, true)
		draw_circle(defense, 3.6, Color(Color("1d6b8f"), players_alpha))
		draw_arc(defense, 3.6, 0.0, TAU, 12, Color(INK, 0.6 * players_alpha), 1.0, true)
	var bounce := _bounce_height(t if _motion else 1.1)
	var height := bounce.x * 34.0
	var shadow_scale := 1.0 - bounce.x * 0.45
	draw_set_transform(_origin + Vector2(0, (1.0 - _alpha) * 10.0) + Vector2(x_ball, y_ground + 6) * _scale, 0, Vector2(_scale * shadow_scale, _scale * shadow_scale * 0.42))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.32 * a))
	draw_set_transform(_origin + Vector2(0, (1.0 - _alpha) * 10.0), 0, Vector2.ONE * _scale)
	_ball_shape(Vector2(x_ball, y_ground - height), 11.0, bounce.y, a)


## Hauteur (0–1) et angle du ballon : chaque rebond a sa hauteur et sa durée.
func _bounce_height(t: float) -> Vector2:
	var total := 0.0
	for b: Array in BOUNCES: total += float(b[1])
	var local := fposmod(t, total)
	var spin := t * 5.2
	for index in BOUNCES.size():
		var b: Array = BOUNCES[index]
		var duration := float(b[1])
		if local <= duration:
			var u := local / duration
			# Un ovale rebondit de travers : la rotation change de sens selon le rebond.
			var direction := 1.0 if index % 3 != 1 else -1.6
			return Vector2(float(b[0]) * 4.0 * u * (1.0 - u), spin * direction + u * PI * float(b[0]))
		local -= duration
	return Vector2(0.0, spin)


func _ball_shape(center: Vector2, radius: float, angle: float, a: float) -> void:
	var points := PackedVector2Array()
	for segment in 28:
		var theta := TAU * segment / 28.0
		points.append(center + Vector2(cos(theta) * radius * 1.45, sin(theta) * radius * 0.86).rotated(angle))
	draw_colored_polygon(points, Color(LEATHER, a))
	var shine := PackedVector2Array()
	for segment in 14:
		var theta := PI + PI * segment / 13.0
		shine.append(center + Vector2(cos(theta) * radius * 1.2, sin(theta) * radius * 0.55 - radius * 0.12).rotated(angle))
	draw_polyline(shine, Color(1, 0.92, 0.75, 0.45 * a), 1.4, true)
	points.append(points[0])
	draw_polyline(points, Color(Color("6b4520"), a), 1.4, true)
	var axis := Vector2(radius * 0.62, 0).rotated(angle)
	var normal := Vector2(0, radius * 0.2).rotated(angle)
	draw_line(center - axis, center + axis, Color(IVORY, a), 1.5, true)
	for k in 5:
		var p := center.lerp(center + axis, -0.75 + k * 0.375)
		draw_line(p - normal, p + normal, Color(IVORY, a), 1.2, true)


## Barre de progression façon ligne d’en-but : le porteur file vers les poteaux.
func _draw_try_line(box: Rect2, a: float) -> void:
	var y := box.position.y + box.size.y * 0.5
	var start := box.position.x
	var goal := box.end.x - 34.0
	draw_line(Vector2(start, y), Vector2(goal, y), Color(Color("26322f"), a), 6.0, true)
	for i in range(0, 11):
		var x := lerpf(start, goal, i / 10.0)
		var tall := 7.0 if i % 5 == 0 else 4.0
		draw_line(Vector2(x, y - tall), Vector2(x, y + tall), Color(LINE, a), 1.0)
	# En-but : zone hachurée et poteaux.
	draw_rect(Rect2(goal, y - 9, 30, 18), Color(_accent(), 0.22 * a))
	for k in 4:
		draw_line(Vector2(goal + 4 + k * 7, y + 9), Vector2(goal + 10 + k * 7, y - 9), Color(_accent(), 0.5 * a), 1.0)
	draw_line(Vector2(goal, y - 12), Vector2(goal, y + 12), Color(IVORY, a), 2.0)
	var posts := Vector2(goal + 22, y)
	draw_line(posts + Vector2(-7, -14), posts + Vector2(-7, 12), Color(GOLD, a), 2.0)
	draw_line(posts + Vector2(7, -14), posts + Vector2(7, 12), Color(GOLD, a), 2.0)
	draw_line(posts + Vector2(-7, 2), posts + Vector2(7, 2), Color(GOLD, a), 2.0)
	# Progression indéterminée : une course, un aplatissement, on repart.
	var run := 1.9
	var u := fposmod(_elapsed, run) / run if _motion else 0.62
	var eased := u * u * (3.0 - 2.0 * u)
	var head := lerpf(start, goal, eased)
	var tail := maxf(start, head - lerpf(40.0, 150.0, sin(u * PI)))
	var gradient_steps := 10
	for i in gradient_steps:
		var x_a := lerpf(tail, head, float(i) / gradient_steps)
		var x_b := lerpf(tail, head, float(i + 1) / gradient_steps)
		draw_line(Vector2(x_a, y), Vector2(x_b, y), Color(GOLD, a * (0.15 + 0.85 * float(i + 1) / gradient_steps)), 6.0)
	_ball_shape(Vector2(head + 2, y), 6.0, -0.35 + sin(u * TAU * 2.0) * 0.18, a)
	if _motion and u > 0.9:
		var burst := (u - 0.9) / 0.1
		draw_arc(Vector2(goal, y), 6.0 + burst * 16.0, 0.0, TAU, 24, Color(GOLD, (1.0 - burst) * 0.7 * a), 1.6, true)
	draw_string(BODY_FONT, Vector2(start, box.end.y + 4), str(_context.get("progress_label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(FAINT, a))


func _partial_line(from: Vector2, to: Vector2, progress: float, color: Color, width: float) -> void:
	if progress <= 0.0: return
	draw_line(from, from.lerp(to, clampf(progress, 0.0, 1.0)), color, width, true)


func _dashed_line(from: Vector2, to: Vector2, progress: float, color: Color) -> void:
	var length := from.distance_to(to) * progress
	var direction := (to - from).normalized()
	var d := 0.0
	while d < length:
		draw_line(from + direction * d, from + direction * minf(d + 5.0, length), color, 1.2)
		d += 10.0


func _center_string(font: Font, baseline_center: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(baseline_center.x - width * 0.5, baseline_center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _rounded(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	draw_style_box(style, rect)


func _rounded_outline(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)


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
