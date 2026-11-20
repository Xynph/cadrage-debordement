extends Control
## « Continuer » (avance jusqu'au prochain événement, native/engine/continuer.cjs), direction artistique
## « L'ovale du ballon » (choix de Léo, 20/11/2026) : écran sombre plein cadre, anneau ovale de progression et son
## pourcentage, « JOUR n SUR m », titre « Passage au jour suivant… », cartes de date jour → lendemain, arrêt prévu
## par le moteur, liste des jours (✓ passé, ▸ en cours, · à venir) tirée des vraies dates entre le départ et l'arrêt
## prévu, conseil de Gabi, « Échap : arrêter » et « Arrêter → ». L'or n'existe ici que pour l'anneau (Continuer).
## L'écran retient les clics (le jeu avance) : « Arrêter → » et Échap l'arrêtent, au jour en cours.
## À l'arrêt, il dit pourquoi (« Jour de match », « Rendez-vous obligatoire »…), puis s'efface (ou « Fermer → »).
## Aucune donnée inventée : sans arrêt prévu, pas de pourcentage ni de liste, seulement le jour atteint.
## Couleurs, polices, formes : ui/charte.gd.

signal stop_requested

const Charte = preload("res://ui/charte.gd")
const MONTHS := ["JANV.", "FÉVR.", "MARS", "AVRIL", "MAI", "JUIN", "JUIL.", "AOÛT", "SEPT.", "OCT.", "NOV.", "DÉC."]
const MONTHS_SHORT := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const WEEKDAYS := ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]
const WEEKDAYS_SHORT := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
## Durée d'affichage du motif d'arrêt avant l'effacement (secondes).
const VERDICT_SECONDS := 2.4
## Au-delà : « Plus long que prévu (N s)… ».
const LONG_SECONDS := 20.0
const DEFAULT_HINT := "Échap : arrêter"


## Anneau ovale incliné (rapport du ballon) : piste, trait fin intérieur, arc de progression en or, pourcentage au
## centre. `value` de 0 à 1 ; `determinate` faux : aucun pourcentage réel, un arc court tourne (fixe si mouvements réduits).
class Anneau extends Control:
	const Charte = preload("res://ui/charte.gd")
	var value := 0.0:
		set(v):
			value = clampf(v, 0.0, 1.0)
			queue_redraw()
	var determinate := false:
		set(v):
			determinate = v
			queue_redraw()
	var motion := true
	var _clock := 0.0

	func _init() -> void:
		name = "ContinueProgressBar"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if motion and not determinate:
			_clock += delta
			queue_redraw()

	func _point(center: Vector2, a: float, b: float, t: float) -> Vector2:
		return center + Vector2(cos(t) * a, sin(t) * b).rotated(-0.45)

	func _arc(center: Vector2, a: float, b: float, from: float, sweep: float, width: float, color: Color) -> void:
		var steps := maxi(8, int(absf(sweep) / TAU * 96.0))
		var points := PackedVector2Array()
		for i in steps + 1: points.append(_point(center, a, b, from + sweep * i / steps))
		draw_polyline(points, color, width, true)
		draw_circle(points[0], width * 0.5, color)
		draw_circle(points[points.size() - 1], width * 0.5, color)

	func _draw() -> void:
		var center := size * 0.5
		var a := minf(size.x * 0.5 - 20.0, size.y * 0.62 + 10.0)
		var b := a * 0.7
		var thick := maxf(9.0, size.x * 0.034)
		_arc(center, a, b, PI, TAU * 0.999, thick, Color(Charte.OR, 0.2))
		_arc(center, a * 0.84, b * 0.84, PI, TAU * 0.999, 1.5, Charte.FILET)
		if determinate:
			if value > 0.0: _arc(center, a, b, PI, TAU * value * 0.999, thick, Charte.OR)
		else:
			_arc(center, a, b, PI + (_clock * 2.2 if motion else 0.0), TAU * 0.22, thick, Charte.OR)
		if determinate:
			var text := "%d %%" % roundi(value * 100.0)
			var px := maxi(40, roundi(size.x * 0.2))
			var font: Font = Charte.TITRE_EXTRA_ITALIQUE
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			draw_string(font, center + Vector2(-width * 0.5, px * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Charte.IVOIRE)


var card := HBoxContainer.new()
var kicker := Label.new()
var counter := Label.new()
var sheet_month := Label.new()
var sheet_day := Label.new()
var sheet_weekday := Label.new()
var title := Label.new()
var detail := Label.new()
var bar := Anneau.new()
var hint := Label.new()
var stop_button := Button.new()
var close_button := LinkButton.new()
var tip_title := Label.new()
var tip := Label.new()
var long_line := Label.new()
var _sheet := PanelContainer.new()
var _from_sheet := PanelContainer.new()
var _from_month := Label.new()
var _from_day := Label.new()
var _arrow := Label.new()
var _days_box := VBoxContainer.new()
var _right := VBoxContainer.new()
var _left := VBoxContainer.new()
var _logo := TextureRect.new()
var _tip_box := VBoxContainer.new()
var _accent := Charte.CLUB_TRAIT
var _from := ""
var _target := ""
var _today := ""
var _plan: Dictionary = {}
var _motion := true
var _tween: Tween
var _closing := Timer.new()
var _started_ms := 0
var running := false
var stopping := false
var _verdict := false


func _ready() -> void:
	name = "ContinueProgress"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_logo.name = "ContinueProgressLogo"
	_logo.texture = load("res://branding/rugby-legacy-27-logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var composite := ShaderMaterial.new()
	composite.shader = load("res://branding/black_key.gdshader")
	_logo.material = composite
	add_child(_logo)
	card.name = "ContinueProgressCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 56)
	add_child(card)
	# Colonne de gauche : l'anneau et « JOUR n SUR m ».
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.add_theme_constant_override("separation", 8)
	card.add_child(_left)
	_left.add_child(bar)
	_style_label(counter, "", 14, Charte.IVOIRE_2, Charte.TITRE_GRAS, HORIZONTAL_ALIGNMENT_CENTER)
	counter.name = "ContinueProgressDays"
	counter.uppercase = true
	_left.add_child(counter)
	# Colonne de droite.
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.add_theme_constant_override("separation", 14)
	card.add_child(_right)
	_style_label(kicker, "CONTINUER", 13, Charte.IVOIRE_2, Charte.TITRE_GRAS)
	kicker.name = "ContinueProgressKicker"
	kicker.uppercase = true
	_right.add_child(kicker)
	_style_label(title, "Passage au jour suivant…", 56, Charte.IVOIRE, Charte.TITRE_EXTRA_ITALIQUE)
	title.name = "ContinueProgressTitle"
	title.uppercase = true
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.accessibility_live = AccessibilityServer.LIVE_POLITE
	_right.add_child(title)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_right.add_child(head)
	_build_sheet(_from_sheet, _from_month, null, _from_day, "ContinueProgressFrom")
	head.add_child(_from_sheet)
	_style_label(_arrow, "→", 18, Charte.IVOIRE_2, Charte.TEXTE, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(_arrow)
	_build_sheet(_sheet, sheet_month, sheet_weekday, sheet_day, "ContinueProgressSheet")
	sheet_day.name = "ContinueProgressDate"
	head.add_child(_sheet)
	_style_label(detail, "", 16, Charte.IVOIRE_2, Charte.TEXTE)
	detail.name = "ContinueProgressDetail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 2
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(detail)
	_days_box.name = "ContinueProgressDays_list"
	_days_box.add_theme_constant_override("separation", 0)
	_right.add_child(_days_box)
	_tip_box.add_theme_constant_override("separation", 2)
	_right.add_child(_tip_box)
	_style_label(tip_title, "LE CONSEIL DE GABI", 12, Charte.IVOIRE_2, Charte.TITRE_GRAS)
	tip_title.name = "ContinueProgressTipTitle"
	tip_title.uppercase = true
	_tip_box.add_child(tip_title)
	_style_label(tip, "", 16, Charte.IVOIRE, Charte.TEXTE)
	tip.name = "ContinueProgressTip"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.max_lines_visible = 3
	_tip_box.add_child(tip)
	_style_label(long_line, "", 14, Charte.IVOIRE, Charte.TEXTE)
	long_line.name = "ContinueProgressLong"
	long_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(long_line)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	_right.add_child(foot)
	_style_label(hint, DEFAULT_HINT, 14, Charte.IVOIRE_2, Charte.TEXTE)
	hint.name = "ContinueProgressHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	close_button.name = "ContinueProgressClose"
	close_button.text = "Fermer →"
	close_button.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_font_override("font", Charte.TITRE_GRAS)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", Charte.IVOIRE)
	close_button.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	close_button.pressed.connect(dismiss)
	close_button.hide()
	foot.add_child(close_button)
	stop_button.name = "ContinueProgressStop"
	stop_button.text = "Arrêter →"
	stop_button.tooltip_text = "Arrêter l'avance à la fin du jour en cours (Échap)"
	stop_button.focus_mode = Control.FOCUS_ALL
	stop_button.custom_minimum_size = Vector2(150, 44)
	stop_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stop_button.add_theme_font_override("font", Charte.TITRE_GRAS)
	stop_button.add_theme_font_size_override("font_size", 20)
	stop_button.pressed.connect(request_stop)
	foot.add_child(stop_button)
	_closing.one_shot = true
	add_child(_closing)
	_closing.timeout.connect(_fade_out)
	resized.connect(_layout)
	_apply_style()
	set_process(false)
	hide()


func _build_sheet(sheet: PanelContainer, month: Label, weekday: Label, day: Label, node_name: String) -> void:
	sheet.name = node_name
	sheet.custom_minimum_size = Vector2(96, 0)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	sheet.add_child(box)
	_style_label(month, "", 13, Charte.IVOIRE_2, Charte.TITRE_GRAS, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(month)
	_style_label(day, "", 46, Charte.IVOIRE, Charte.TITRE_EXTRA_ITALIQUE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(day)
	if weekday != null:
		# Jour de la semaine : lu avec le mois dans la même ligne (« VEN. NOV. »), ce libellé reste pour l'accessibilité.
		_style_label(weekday, "", 12, Charte.IVOIRE_2, Charte.TITRE_GRAS, HORIZONTAL_ALIGNMENT_CENTER)
		weekday.hide()
		box.add_child(weekday)


func _style_label(label: Label, value: String, size_px: int, color: Color, font: Font, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	label.text = value
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_style() -> void:
	for sheet: PanelContainer in [_sheet, _from_sheet]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_3
		style.border_width_top = 3
		style.border_color = _accent
		style.set_content_margin_all(6)
		sheet.add_theme_stylebox_override("panel", style)
	var button := StyleBoxFlat.new()
	button.bg_color = Charte.IVOIRE
	button.set_content_margin_all(8)
	var hover := button.duplicate()
	hover.bg_color = Charte.IVOIRE_2
	var off := button.duplicate()
	off.bg_color = Charte.PANNEAU_3
	stop_button.add_theme_stylebox_override("normal", button)
	stop_button.add_theme_stylebox_override("hover", hover)
	stop_button.add_theme_stylebox_override("pressed", hover)
	stop_button.add_theme_stylebox_override("focus", hover)
	stop_button.add_theme_stylebox_override("disabled", off)
	stop_button.add_theme_color_override("font_color", Charte.ENCRE)
	stop_button.add_theme_color_override("font_hover_color", Charte.ENCRE)
	stop_button.add_theme_color_override("font_pressed_color", Charte.ENCRE)
	stop_button.add_theme_color_override("font_focus_color", Charte.ENCRE)
	stop_button.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Charte.NUIT, 0.97))


func _process(_delta: float) -> void:
	if running and _started_ms > 0 and not _verdict:
		var seconds := int((Time.get_ticks_msec() - _started_ms) / 1000)
		var long := float(seconds) >= LONG_SECONDS
		var text := "Plus long que prévu (%d s)… Si tu arrêtes, le jeu reste au dernier jour calculé." % seconds if long else ""
		if long_line.text != text:
			long_line.text = text
			long_line.visible = long
			call_deferred("_layout")


func _layout() -> void:
	if not is_node_ready(): return
	var small := size.y < 800.0
	var ring_w := clampf(size.x * 0.26, 300.0, 520.0)
	bar.custom_minimum_size = Vector2(ring_w, ring_w * 0.78)
	var right_w := clampf(size.x * 0.42, 480.0, 820.0)
	card.add_theme_constant_override("separation", roundi(clampf(size.x * 0.03, 24.0, 64.0)))
	_right.custom_minimum_size = Vector2(right_w, 0)
	title.custom_minimum_size = Vector2(right_w, 0)
	title.add_theme_font_size_override("font_size", 40 if small else clampi(roundi(size.x * 0.029), 40, 64))
	detail.custom_minimum_size = Vector2(maxf(120.0, right_w - 2.0 * 96.0 - 3.0 * 14.0 - 18.0), 0)
	tip.custom_minimum_size = Vector2(right_w, 0)
	long_line.custom_minimum_size = Vector2(right_w, 0)
	hint.custom_minimum_size = Vector2(right_w - 360.0, 0)
	_left.custom_minimum_size = Vector2(ring_w, 0)
	card.size = card.get_combined_minimum_size()
	card.position = ((size - card.size) * 0.5).round()
	var logo_h := roundf(clampf(size.y * 0.11, 64.0, 130.0))
	_logo.position = Vector2(roundf(size.x * 0.043), roundf(size.y * 0.02))
	_logo.size = Vector2(roundf(logo_h * 2.28), logo_h)


## Début d'une avance. `context` : date du jour, couleur du club, prochaine rencontre ({date, opponent}), notes.
func begin(context: Dictionary, animate: bool = true) -> void:
	_closing.stop()
	_kill_tween()
	running = true
	stopping = false
	_verdict = false
	_motion = animate
	_started_ms = Time.get_ticks_msec()
	var accent: Variant = context.get("accent")
	_accent = Charte.club_trait(accent) if accent is Color else Charte.CLUB_TRAIT
	_from = str(context.get("date", ""))
	_today = _from
	var next: Variant = context.get("next")
	_target = str(next.get("date", "")) if next is Dictionary else ""
	_apply_style()
	bar.motion = animate
	bar.set_process(true)
	set_process(true)
	_plan = {}
	if next is Dictionary and not _target.is_empty(): _plan = {"kind": "match", "date": _target, "opponent": str(next.get("opponent", ""))}
	title.text = "Passage au jour suivant…"
	_set_kicker()
	detail.text = _plan_text()
	detail.max_lines_visible = 2
	hint.text = DEFAULT_HINT
	stop_button.text = "Arrêter →"
	stop_button.disabled = false
	stop_button.visible = true
	close_button.hide()
	long_line.text = ""
	long_line.hide()
	_apply_tip(context.get("notes", []), int(context.get("note_seed", Time.get_ticks_msec())))
	_show_date(_from, 0)
	show()
	_layout()
	call_deferred("_layout")
	# Mouvements réduits : l'écran est là tout de suite, sans fondu.
	modulate.a = 1.0
	if animate:
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.16)


## Conseil de Gabi choisi dans les notes réelles du jeu (type « tip ») ; aucune note : bloc omis.
func _apply_tip(notes: Variant, seed_value: int) -> void:
	var tips: Array[String] = []
	if notes is Array:
		for note: Variant in notes:
			if note is Dictionary and str(note.get("kind", "tip")) == "tip" and not str(note.get("text", "")).is_empty(): tips.append(str(note.text))
	_tip_box.visible = not tips.is_empty()
	tip.text = "« %s »" % tips[posmod(seed_value, tips.size())] if not tips.is_empty() else ""


## Une tranche reçue du moteur : nouvelle date, jours écoulés, prochaine rencontre.
func advance_to(progress: Dictionary) -> void:
	if not running: return
	var next: Variant = progress.get("next")
	if next is Dictionary and _target.is_empty(): _target = str(next.get("date", ""))
	# Prochain arrêt prévisible calculé par le moteur (match, reprise, rendez-vous) : « Arrêt prévu » l'annonce et
	# l'anneau mesure l'avance vers lui (jours écoulés / jours jusqu'à cet arrêt).
	var plan: Variant = progress.get("plan")
	if plan is Dictionary and not str(plan.get("date", "")).is_empty():
		_plan = plan
		_target = str(plan.date)
	elif next is Dictionary and _plan.is_empty() and not _target.is_empty():
		_plan = {"kind": "match", "date": _target, "opponent": str(next.get("opponent", ""))}
	_set_kicker()
	detail.text = _plan_text()
	_show_date(str(progress.get("today", _from)), int(progress.get("days", 0)))
	if _motion:
		_kill_tween()
		# Le nouveau jour apparaît en fondu.
		sheet_day.modulate.a = 0.25
		_tween = create_tween()
		_tween.tween_property(sheet_day, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)


func request_stop() -> void:
	if not running or stopping: return
	stopping = true
	stop_button.disabled = true
	stop_button.text = "Arrêt…"
	hint.text = "Arrêt à la fin du jour en cours, la carrière est sauvegardée."
	stop_requested.emit()


## Fin de l'avance : motif d'arrêt (libellé, détail), puis effacement.
func finish(info: Dictionary) -> void:
	running = false
	stopping = false
	_verdict = true
	_kill_tween()
	bar.set_process(false)
	var stop: Dictionary = info.get("stop", {}) if info.get("stop") is Dictionary else {}
	var days := int(info.get("days", 0))
	_show_date(str(info.get("to", _from)), days)
	kicker.text = "ARRÊT · " + _days_text(days).to_upper() if days > 0 else "ARRÊT"
	title.text = str(stop.get("label", "Avance arrêtée"))
	detail.text = str(stop.get("detail", "")) if stop.get("detail") != null else ""
	# Motif d'arrêt écrit en entier (« Effectif trop juste » : postes et suite, 4-5 lignes).
	detail.max_lines_visible = -1
	# Conférences ordinaires tenues par Gabi pendant l'avance (réglage « envoyer l'adjoint ») : dites, sans arrêt.
	var delegated := int(info.get("pressDelegated", 0))
	hint.text = ("Gabi a tenu %s à ta place. " % ("la conférence de presse" if delegated == 1 else "%d conférences de presse" % delegated) if delegated > 0 else "") + "Carrière sauvegardée."
	# Autres arrêts du même jour (façon FM) : un nouvel appui sur Continuer les montre sans avancer.
	var queued := int(info.get("queued", 0))
	if queued > 0: hint.text = ("Encore %d élément%s aujourd’hui : Continuer pour %s. " % [queued, "s" if queued > 1 else "", "les voir" if queued > 1 else "le voir"]) + hint.text
	stop_button.visible = false
	close_button.show()
	long_line.hide()
	_days_box.hide()
	_tip_box.hide()
	if not visible: show()
	modulate.a = 1.0
	_layout()
	call_deferred("_layout")
	_closing.start(VERDICT_SECONDS if _motion else VERDICT_SECONDS + 0.6)


func dismiss() -> void:
	running = false
	stopping = false
	_verdict = false
	_closing.stop()
	_kill_tween()
	set_process(false)
	bar.set_process(false)
	hide()


func _fade_out() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2 if _motion else 0.01)
	_tween.tween_callback(dismiss)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null


func _set_kicker() -> void:
	kicker.text = "CONTINUER · " + _plan_kicker(_plan) if not _plan.is_empty() else "CONTINUER"


func _show_date(iso: String, days: int) -> void:
	if not iso.is_empty(): _today = iso
	var left := _parts(iso)
	var right := _parts(_shift(iso, 1))
	if not left.is_empty() and not right.is_empty():
		_from_month.text = "%s %s" % [str(left.weekday).substr(0, 3) + ".", left.month]
		_from_day.text = str(left.day)
		sheet_month.text = "%s %s" % [str(right.weekday).substr(0, 3) + ".", right.month]
		sheet_day.text = str(right.day)
		sheet_weekday.text = str(right.weekday)
	var span := _day_number(_target) - _day_number(_from) if not _target.is_empty() and not _from.is_empty() else 0
	var pos := _day_number(iso) - _day_number(_from) if not _from.is_empty() else 0
	bar.determinate = span > 0
	bar.value = clampf(float(pos) / float(span), 0.0, 1.0) if span > 0 else 0.0
	if span > 0: counter.text = "Jour %d sur %d · %s" % [clampi(pos + 1, 1, span + 1), span + 1, _short_day(iso)]
	else: counter.text = ("Jour %d · %s" % [maxi(1, pos + 1), _short_day(iso)]) if not iso.is_empty() else ""
	_rebuild_days(pos, span)


## Liste des jours entre le départ et l'arrêt prévu : jours réels (✓ passé, ▸ en cours, · à venir). Fenêtre de cinq
## jours autour du jour en cours, plus l'arrêt prévu ; omise sans arrêt prévu.
func _rebuild_days(pos: int, span: int) -> void:
	for child in _days_box.get_children():
		_days_box.remove_child(child)
		child.queue_free()
	if span < 1 or _from.is_empty():
		_days_box.hide()
		return
	var lines := 4 if size.y < 800.0 else 5
	var lo := maxi(0, pos - 1)
	var hi := mini(span, lo + lines - 1)
	var rows: Array[int] = []
	for i in range(lo, hi + 1): rows.append(i)
	if rows.back() != span: rows.append(span)
	for i: int in rows:
		var iso := _shift(_from, i)
		var mark := "✓" if i < pos else ("▸" if i == pos else "·")
		var text := _long_day(iso)
		if i == span:
			var motive := _plan_motive(_plan)
			if not motive.is_empty(): text += " · " + motive
		_days_box.add_child(_day_row(mark, text, i == pos))
	_days_box.show()


func _day_row(mark: String, text: String, current: bool) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU_2 if current else Color(Charte.NUIT, 0.0)
	style.border_width_top = 1
	style.border_color = Charte.FILET
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	var symbol := Label.new()
	_style_label(symbol, mark, 14, Charte.IVOIRE if current else Charte.IVOIRE_2, Charte.TEXTE)
	symbol.custom_minimum_size = Vector2(16, 0)
	line.add_child(symbol)
	var label := Label.new()
	_style_label(label, text, 14, Charte.IVOIRE if current else Charte.IVOIRE_2, Charte.TITRE_GRAS if current else Charte.TEXTE)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	return row


## « JOUR 3 SUR 4 » : libellé court d'une date (« ven. 20 »).
func _short_day(iso: String) -> String:
	var parts := _parts(iso)
	return "%s %s" % [str(parts.weekday).substr(0, 3).to_lower() + ".", parts.day] if not parts.is_empty() else ""


## « ven. 20 nov. » depuis une date ISO.
func _long_day(iso: String) -> String:
	var p := iso.split("-")
	if p.size() != 3: return iso
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	var weekday := int(Time.get_datetime_dict_from_unix_time(unix).weekday)
	return "%s %d %s" % [WEEKDAYS_SHORT[weekday], int(p[2]), MONTHS_SHORT[clampi(int(p[1]), 1, 12) - 1]]


func _parts(iso: String) -> Dictionary:
	var p := iso.split("-")
	if p.size() != 3 or not p[0].is_valid_int() or not p[1].is_valid_int() or not p[2].is_valid_int() or int(p[1]) < 1 or int(p[1]) > 12: return {}
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	var weekday := int(Time.get_datetime_dict_from_unix_time(unix).weekday)
	return {"day": str(int(p[2])), "month": MONTHS[int(p[1]) - 1], "weekday": WEEKDAYS[weekday]}


func _shift(iso: String, days: int) -> String:
	if _parts(iso).is_empty(): return ""
	return Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(iso + "T12:00:00") + days * 86400)


## Ligne « Arrêt prévu » : date et vrai motif donnés par le moteur ; sans arrêt prévu, la ligne est omise.
func _plan_text() -> String:
	if _plan.is_empty() or str(_plan.get("date", "")).is_empty(): return ""
	var motive := _plan_motive(_plan)
	return "Arrêt prévu : %s%s" % [_long_day(str(_plan.date)), (" · " + motive) if not motive.is_empty() else ""]


## Motif écrit de l'arrêt prévu (« match contre X », « rendez-vous : … »).
func _plan_motive(plan: Dictionary) -> String:
	match str(plan.get("kind", "")):
		"match":
			var opponent := str(plan.get("opponent", ""))
			return "match contre %s" % opponent if not opponent.is_empty() else "prochain match"
		"rendez_vous":
			var label := str(plan.get("detail", "")).to_lower()
			return "rendez-vous : %s" % label if not label.is_empty() else "rendez-vous du club"
		"reprise": return "reprise de l’entraînement"
		"decision":
			var what := str(plan.get("detail", "")).to_lower()
			return "décision : %s" % what if not what.is_empty() else "prochaine décision"
		"a_noter":
			var note := str(plan.get("detail", ""))
			return "élément à noter : %s" % note if not note.is_empty() else "prochain élément à noter"
		"info": return str(plan.get("detail", ""))
	return ""


func _plan_kicker(plan: Dictionary) -> String:
	match str(plan.get("kind", "")):
		"match": return "jusqu’au match"
		"rendez_vous": return "jusqu’au rendez-vous"
		"reprise": return "jusqu’à la reprise"
		"decision": return "jusqu’à la décision"
		"a_noter": return "jusqu’au prochain élément"
	return "jusqu’au prochain événement"


func _days_text(days: int) -> String:
	return "%d jour%s" % [days, "" if days <= 1 else "s"]


func _day_number(iso: String) -> int:
	if iso.length() != 10: return 0
	return int(Time.get_unix_time_from_datetime_string(iso + "T12:00:00") / 86400)
