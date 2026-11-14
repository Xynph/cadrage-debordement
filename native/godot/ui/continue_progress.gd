extends Control
## Panneau de progression de « Continuer » (avance jusqu'au prochain événement, native/engine/continuer.cjs).
## Petit, centré, NON bloquant : aucun voile, l'écran derrière reste lisible et se parcourt (navigation locale) ;
## seule la carte retient les clics. Même famille visuelle que le panneau d'attente (command_wait_overlay.gd) :
## carte sombre, filet or, feuille de calendrier dont le jour change à chaque tranche reçue du moteur.
## La carte montre la date qui défile, le nombre de jours passés, la prochaine rencontre et « Arrêter ».
## À l'arrêt, elle dit pourquoi (« Jour de match », « Rendez-vous obligatoire »…) puis s'efface.

signal stop_requested

const PANEL := Color("121a1c")
const PANEL_HIGH := Color("18231f")
const LINE := Color("2c3a37")
const GOLD := Color("e0b35a")
const IVORY := Color("f2ecdc")
const MUTED := Color("aeb9b3")
const FAINT := Color("7b8a84")
const RED := Color("d43e47")
const INK := Color("0b1012")
const TITLE_FONT = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
const BOLD_FONT = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const BODY_FONT = preload("res://fonts/DMSans.ttf")
const MONTHS := ["JANV.", "FÉVR.", "MARS", "AVRIL", "MAI", "JUIN", "JUIL.", "AOÛT", "SEPT.", "OCT.", "NOV.", "DÉC."]
const WEEKDAYS := ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]
## Largeurs fixes des textes à retour à la ligne (sans elles, un conteneur les écrase et la carte s'allonge).
const CARD_WIDTH := 560.0
const TEXT_WIDTH := 330.0
const HINT_WIDTH := 330.0
## Durée d'affichage du motif d'arrêt avant l'effacement (secondes).
const VERDICT_SECONDS := 2.4

var card := PanelContainer.new()
var kicker := Label.new()
var counter := Label.new()
var sheet_month := Label.new()
var sheet_day := Label.new()
var sheet_weekday := Label.new()
var title := Label.new()
var detail := Label.new()
var bar := ProgressBar.new()
var hint := Label.new()
var stop_button := Button.new()
var _sheet := PanelContainer.new()
var _accent := RED
var _from := ""
var _target := ""
var _motion := true
var _tween: Tween
var _closing := Timer.new()
var running := false
var stopping := false


func _ready() -> void:
	name = "ContinueProgress"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	card.name = "ContinueProgressCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_style_label(kicker, "CONTINUER", 15, GOLD, BOLD_FONT)
	kicker.name = "ContinueProgressKicker"
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(kicker)
	_style_label(counter, "", 15, MUTED, BOLD_FONT)
	counter.name = "ContinueProgressDays"
	head.add_child(counter)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	# Feuille de calendrier : mois sur bandeau aux couleurs du club, grand chiffre, jour de la semaine.
	_sheet.name = "ContinueProgressSheet"
	_sheet.custom_minimum_size = Vector2(96, 0)
	row.add_child(_sheet)
	var sheet_box := VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", 0)
	_sheet.add_child(sheet_box)
	_style_label(sheet_month, "", 14, IVORY, BOLD_FONT, HORIZONTAL_ALIGNMENT_CENTER)
	sheet_box.add_child(sheet_month)
	_style_label(sheet_day, "", 46, INK, BOLD_FONT, HORIZONTAL_ALIGNMENT_CENTER)
	sheet_day.name = "ContinueProgressDate"
	sheet_box.add_child(sheet_day)
	_style_label(sheet_weekday, "", 12, Color("3b4442"), BOLD_FONT, HORIZONTAL_ALIGNMENT_CENTER)
	sheet_box.add_child(sheet_weekday)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	_style_label(title, "Les jours défilent…", 26, IVORY, TITLE_FONT)
	title.name = "ContinueProgressTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	title.accessibility_live = AccessibilityServer.LIVE_POLITE
	text.add_child(title)
	_style_label(detail, "", 15, MUTED, BODY_FONT)
	detail.name = "ContinueProgressDetail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	detail.max_lines_visible = 2
	text.add_child(detail)
	bar.name = "ContinueProgressBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	bar.max_value = 1.0
	box.add_child(bar)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	_style_label(hint, "Arrêt au prochain match, rendez-vous ou courrier important.", 13, FAINT, BODY_FONT)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(HINT_WIDTH, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(hint)
	stop_button.name = "ContinueProgressStop"
	stop_button.text = "ARRÊTER"
	stop_button.tooltip_text = "Arrêter l’avance à la fin du jour en cours (Échap)"
	stop_button.focus_mode = Control.FOCUS_ALL
	stop_button.custom_minimum_size = Vector2(124, 40)
	stop_button.add_theme_font_override("font", BOLD_FONT)
	stop_button.add_theme_font_size_override("font_size", 18)
	stop_button.pressed.connect(request_stop)
	foot.add_child(stop_button)
	_closing.one_shot = true
	add_child(_closing)
	_closing.timeout.connect(_fade_out)
	resized.connect(_layout)
	_apply_style()
	hide()


func _style_label(label: Label, value: String, size_px: int, color: Color, font: Font, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	label.text = value
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = LINE
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.border_color = LINE
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	card.add_theme_stylebox_override("panel", style)
	var top := StyleBoxFlat.new()
	top.bg_color = Color(0, 0, 0, 0)
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = IVORY
	sheet.set_corner_radius_all(5)
	sheet.border_width_top = 22
	sheet.border_color = _accent
	sheet.set_content_margin_all(4)
	sheet.content_margin_top = 2
	_sheet.add_theme_stylebox_override("panel", sheet)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = PANEL_HIGH
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	var button := StyleBoxFlat.new()
	button.bg_color = Color(0, 0, 0, 0)
	button.border_color = GOLD
	button.set_border_width_all(1)
	button.set_corner_radius_all(5)
	button.set_content_margin_all(8)
	var hover := button.duplicate()
	hover.bg_color = Color(GOLD, 0.16)
	stop_button.add_theme_stylebox_override("normal", button)
	stop_button.add_theme_stylebox_override("hover", hover)
	stop_button.add_theme_stylebox_override("pressed", hover)
	stop_button.add_theme_stylebox_override("focus", hover)
	stop_button.add_theme_stylebox_override("disabled", button)
	stop_button.add_theme_color_override("font_color", GOLD)
	stop_button.add_theme_color_override("font_hover_color", IVORY)
	stop_button.add_theme_color_override("font_disabled_color", FAINT)


func _layout() -> void:
	# Carte de largeur fixe, mise à l'échelle avec la hauteur de la fenêtre (1080p = 1), centrée.
	var factor := clampf(size.y / 1080.0, 0.6, 1.6)
	factor = minf(factor, (size.x - 32.0) / CARD_WIDTH) if size.x > 64.0 else factor
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.size = card.get_combined_minimum_size()
	card.scale = Vector2(factor, factor)
	card.position = ((size - card.size * factor) / 2.0).round()


## Début d'une avance. `context` : date du jour, couleur du club, prochaine rencontre ({date, opponent}).
func begin(context: Dictionary, animate: bool = true) -> void:
	_closing.stop()
	_kill_tween()
	running = true
	stopping = false
	_motion = animate
	_accent = context.get("accent", RED)
	_from = str(context.get("date", ""))
	var next: Variant = context.get("next")
	_target = str(next.get("date", "")) if next is Dictionary else ""
	_apply_style()
	kicker.text = "CONTINUER"
	kicker.add_theme_color_override("font_color", GOLD)
	title.text = "Les jours défilent…"
	detail.text = _next_text(next)
	hint.text = "Arrêt au prochain match, rendez-vous ou courrier important."
	stop_button.text = "ARRÊTER"
	stop_button.disabled = false
	stop_button.visible = true
	_show_date(_from, 0)
	show()
	modulate.a = 0.0
	_layout()
	call_deferred("_layout")
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.16 if animate else 0.01)


## Une tranche reçue du moteur : nouvelle date, jours écoulés, prochaine rencontre.
func advance_to(progress: Dictionary) -> void:
	if not running: return
	var next: Variant = progress.get("next")
	if next is Dictionary and _target.is_empty(): _target = str(next.get("date", ""))
	if next is Dictionary: detail.text = _next_text(next)
	_show_date(str(progress.get("today", _from)), int(progress.get("days", 0)))
	if _motion:
		_kill_tween()
		# Feuille qui tourne : le nouveau jour apparaît en fondu (la position appartient au conteneur).
		sheet_day.modulate.a = 0.25
		_tween = create_tween()
		_tween.tween_property(sheet_day, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)


func request_stop() -> void:
	if not running or stopping: return
	stopping = true
	stop_button.disabled = true
	stop_button.text = "ARRÊT…"
	hint.text = "Arrêt à la fin du jour en cours, la carrière est sauvegardée."
	stop_requested.emit()


## Fin de l'avance : motif d'arrêt (libellé, détail), puis effacement.
func finish(info: Dictionary) -> void:
	running = false
	stopping = false
	var stop: Dictionary = info.get("stop", {}) if info.get("stop") is Dictionary else {}
	var days := int(info.get("days", 0))
	_show_date(str(info.get("to", _from)), days)
	kicker.text = "ARRÊT · " + _days_text(days).to_upper() if days > 0 else "ARRÊT"
	kicker.add_theme_color_override("font_color", IVORY)
	title.text = str(stop.get("label", "Avance arrêtée"))
	detail.text = str(stop.get("detail", "")) if stop.get("detail") != null else ""
	# Conférences ordinaires tenues par Gabi pendant l'avance (réglage « envoyer l'adjoint ») : dites, sans arrêt.
	var delegated := int(info.get("pressDelegated", 0))
	hint.text = ("Gabi a tenu %s à votre place. " % ("la conférence de presse" if delegated == 1 else "%d conférences de presse" % delegated) if delegated > 0 else "") + "Carrière sauvegardée."
	stop_button.visible = false
	bar.value = 1.0
	if not visible: show()
	_layout()
	call_deferred("_layout")
	_closing.start(VERDICT_SECONDS if _motion else VERDICT_SECONDS + 0.6)


func dismiss() -> void:
	running = false
	stopping = false
	_closing.stop()
	_kill_tween()
	hide()


func _fade_out() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2 if _motion else 0.01)
	_tween.tween_callback(hide)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null


func _show_date(iso: String, days: int) -> void:
	var parts := iso.split("-")
	if parts.size() == 3:
		var month := clampi(int(parts[1]), 1, 12)
		sheet_month.text = MONTHS[month - 1]
		sheet_day.text = str(int(parts[2]))
		var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
		sheet_weekday.text = WEEKDAYS[int(Time.get_datetime_dict_from_unix_time(unix).weekday)]
	counter.text = _days_text(days) if days > 0 else ""
	if not _target.is_empty() and not _from.is_empty():
		var span := _day_number(_target) - _day_number(_from)
		bar.value = clampf(float(_day_number(iso) - _day_number(_from)) / maxf(1.0, float(span)), 0.0, 1.0) if span > 0 else 0.0
	else:
		bar.value = 0.0


func _days_text(days: int) -> String:
	return "%d jour%s" % [days, "" if days <= 1 else "s"]


func _day_number(iso: String) -> int:
	if iso.length() != 10: return 0
	return int(Time.get_unix_time_from_datetime_string(iso + "T12:00:00") / 86400)


func _next_text(next: Variant) -> String:
	if not next is Dictionary or str(next.get("date", "")).is_empty(): return "Aucune rencontre annoncée pour le moment."
	var parts := str(next.date).split("-")
	var when := "%s/%s" % [parts[2], parts[1]] if parts.size() == 3 else str(next.date)
	var opponent := str(next.get("opponent", ""))
	return "Prochain match le %s%s." % [when, (" contre " + opponent) if not opponent.is_empty() else ""]
