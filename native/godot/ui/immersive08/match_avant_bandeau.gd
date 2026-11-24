extends "res://ui/immersive08/match_avant_outils.gd"
## Écran « Avant-match » (voir match_avant.gd) — Bandeau haut : Menu, statut de la feuille, date, « Déléguer le match » et bouton « COUP D'ENVOI » (verrou d'ouverture).

func _bandeau(next: Dictionary, play: Button, etat: Dictionary, en_page: bool) -> Control:
	var barre := MarginContainer.new()
	barre.name = "MatchPrematchHeader"
	barre.mouse_filter = Control.MOUSE_FILTER_PASS
	for edge in ["left", "right"]: barre.add_theme_constant_override("margin_" + edge, M(32))
	barre.add_theme_constant_override("margin_top", M(14))
	barre.add_theme_constant_override("margin_bottom", M(8))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(18))
	barre.add_child(ligne)
	# Menu : menu de la carrière (Échap), seule fenêtre de l'écran avec la mini-fiche.
	# Lien texte ivoire (style commun, sans cadre) avec le pictogramme ☰ dessiné à gauche.
	var menu := Button.new()
	menu.name = "MatchMenu"
	menu.text = "Menu"
	menu.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(menu, roundi(15 / .75))
	menu.add_theme_font_override("font", C.BODY)
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		(menu.get_theme_stylebox(look) as StyleBoxFlat).content_margin_left = M(28)
	var burger := Burger.new()
	burger.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	burger.offset_left = M(6)
	burger.offset_right = M(22)
	burger.offset_top = -M(7)
	burger.offset_bottom = M(7)
	menu.add_child(burger)
	menu.tooltip_text = "Menu : sauvegardes, réglages, quitter · Échap"
	menu.accessibility_name = "Menu · Échap"
	menu.pressed.connect(app.pause_menu)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(menu)
	var jour := italique(texte("JOUR DE MATCH", 14, Charte.IVOIRE, true, 700), false, true)
	jour.name = "MatchDayTitle"
	jour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(jour)
	status = texte("", 15, Charte.IVOIRE, false, 700)
	status.name = "MatchPrematchStatus"
	status.visible = false
	ligne.add_child(status)
	var nav: Node = app.get("navigation_controller")
	if en_page:
		var retour := _bouton_lien("← Retour à l'avant-match", fermer_page, "MatchPageBack", 15)
		retour.tooltip_text = "Retour à l'avant-match · Alt+←"
		retour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(retour)
	else:
		# Sans barre haute, un lien visible vers l'écran d'où l'on vient (Précédent de l'historique, Alt+←).
		var precedent := _bouton_lien("← Retour", _retour_precedent, "MatchBack", 15)
		precedent.tooltip_text = "Écran précédent · Alt+←"
		precedent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(precedent)
		if not next.is_empty(): ligne.add_child(_statut_feuille(etat))
		# Pastille du dernier match (choix de Léo du 21/11) : ouvre la petite fenêtre du bilan ; absente sans match joué.
		var dernier: Control = Bilan.pastille_bandeau(self, _model) if not next.is_empty() else null
		if dernier != null: ligne.add_child(dernier)
	var espace := Control.new()
	espace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(espace)
	ligne.add_child(espace)
	# Icône du ciel, date et heure du coup d'envoi (données du prochain match).
	if next.get("meteo") is Dictionary:
		var ciel := TextureRect.new()
		ciel.name = "MatchPrematchSky"
		ciel.texture = icone_meteo(next.meteo, Charte.IVOIRE)
		ciel.custom_minimum_size = Vector2(M(20), M(20))
		ciel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ciel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ciel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ciel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(ciel)
		ligne.move_child(ciel, ligne.get_child_count() - 1)
	var heure_match := " · " + str(next.get("kickoffLocal")) if next.get("kickoffLocal") is String and not str(next.get("kickoffLocal")).is_empty() else ""
	match_date = texte((date_courte(str(next.get("date", ""))) + heure_match) if not next.is_empty() else "", 15, Charte.IVOIRE, false, 500)
	match_date.name = "MatchPrematchDate"
	match_date.add_theme_font_override("font", C.BODY)
	match_date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(match_date)
	delegate = Button.new()
	delegate.name = "MatchOpenDelegation"
	delegate.text = "Déléguer le match →"
	delegate.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(delegate, roundi(15 / .75))
	delegate.add_theme_font_override("font", C.BODY)
	delegate.pressed.connect(func(): ouvrir_page("delegation"))
	delegate.visible = not next.is_empty() and not en_page
	delegate.disabled = play.disabled
	delegate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(delegate)
	_raison = null
	if not next.is_empty() and not en_page:
		if play.disabled and not play.tooltip_text.is_empty():
			_raison = lignes(play.tooltip_text, 13, Charte.IVOIRE_2, 2, false, 500)
			_raison.name = "MatchKickoffReason"
			_raison.custom_minimum_size.x = M(260)
			_raison.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_raison.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ligne.add_child(_raison)
		ligne.add_child(_bouton_coup_d_envoi(play))
	else:
		kickoff = null
	return barre

## « ✓ Feuille validée · 23 / 23 · condition moyenne 95 % » : mot cliquable (Composition), symbole et mot, jamais la couleur seule.
func _statut_feuille(etat: Dictionary) -> Control:
	var ligne := HBoxContainer.new()
	ligne.name = "MatchSheetStatus"
	ligne.add_theme_constant_override("separation", M(6))
	ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var alerte: bool = etat.incomplete or etat.avertissements > 0
	var suite: Array[String] = []
	if etat.incomplete and not etat.erreurs.is_empty(): suite.append(str(etat.erreurs[0]))
	elif etat.avertissements > 0: suite.append("(%d avertissement%s)" % [etat.avertissements, "s" if etat.avertissements > 1 else ""])
	suite.append("%d / %d" % [etat.remplis, etat.total])
	if etat.moyenne >= 0: suite.append("condition moyenne %d %%" % roundi(etat.moyenne))
	# Toute la ligne est un seul lien (symbole, mot et détail) vers la Composition.
	var lien := _bouton_lien("%s  %s" % [etat.mot, " · ".join(suite)], func(): _aller("Composition"), "MatchOpenSheetStatus", 15)
	_icone_dans_lien(lien, C.icon_texture("warning" if alerte else "check", Charte.D if etat.incomplete else Charte.N if alerte else Charte.V), 16)
	lien.tooltip_text = "Ouvrir la composition"
	lien.accessibility_name = "%s, %s. Ouvrir la composition" % [etat.mot, " · ".join(suite)]
	ligne.add_child(lien)
	return ligne

## Pictogramme ☰ du lien « Menu » : trois traits ivoire.
class Burger extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		for i in 3:
			var y := size.y * (0.18 + 0.32 * i)
			draw_line(Vector2(0, y), Vector2(size.x, y), Charte.IVOIRE, maxf(1.0, size.y * 0.11))
## Le bouton or : aplat or, bord droit incliné de 10° (charte §7), texte nuit, « Entrée » à droite. Le seul or de l'écran.
class PlaqueOr extends Control:
	var couleur := Color.WHITE
	var anneau := Color.TRANSPARENT
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		# Charte finale : pilule dorée.
		var forme := StyleBoxFlat.new()
		forme.bg_color = couleur
		forme.set_corner_radius_all(Charte.RAYON_PILULE)
		forme.anti_aliasing = true
		if anneau.a > 0.0:
			forme.border_color = anneau
			forme.set_border_width_all(2)
		draw_style_box(forme, Rect2(Vector2.ZERO, size))

func _bouton_coup_d_envoi(play: Button) -> Control:
	var on_kickoff: Callable = _on_kickoff
	kickoff = Button.new()
	kickoff.name = "MatchKickoff"
	kickoff.text = play.text
	kickoff.set_meta("immersive_style_applied", true)
	kickoff.disabled = play.disabled
	kickoff.tooltip_text = play.tooltip_text
	kickoff.accessibility_name = "%s · Entrée" % play.text.capitalize()
	kickoff.custom_minimum_size = Vector2(M(250), M(48))
	for look in ["normal", "hover", "pressed", "disabled"]: kickoff.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(Charte.RAYON_PILULE)
	focus.set_expand_margin_all(M(3))
	kickoff.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]: kickoff.add_theme_color_override(key, Color.TRANSPARENT)
	kickoff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plaque := PlaqueOr.new()
	plaque.name = "MatchKickoffPlate"
	plaque.couleur = Charte.OR if not play.disabled else Charte.PANNEAU_3
	plaque.show_behind_parent = true
	plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kickoff.add_child(plaque)
	var encre := Charte.NUIT if not play.disabled else Charte.IVOIRE_3
	var libelle := italique(texte(play.text.to_upper(), 24, encre, true, 800), true)
	libelle.name = "MatchKickoffLabel"
	libelle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	libelle.offset_left = M(22)
	libelle.offset_right = -M(96)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.autowrap_mode = TextServer.AUTOWRAP_OFF
	libelle.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	kickoff.add_child(libelle)
	var filet := ColorRect.new()
	filet.color = Color(encre, .35)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filet.anchor_left = 1.0
	filet.anchor_right = 1.0
	filet.anchor_top = .26
	filet.anchor_bottom = .74
	filet.offset_left = -M(96)
	filet.offset_right = -M(96) + 1
	kickoff.add_child(filet)
	_indice = texte("Entrée", 14, encre, false, 500)
	_indice.name = "MatchKickoffHint"
	_indice.add_theme_font_override("font", C.BODY)
	_indice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_indice.anchor_left = 1.0
	_indice.offset_left = -M(88)
	_indice.offset_right = -M(26)
	_indice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_indice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kickoff.add_child(_indice)
	kickoff.pressed.connect(on_kickoff)
	# Verrou d'ouverture : Entrée, Espace et touche maintenue sont ignorés pendant 0,5 s (fiche UX 12 §7) ; la souris non.
	kickoff.gui_input.connect(_garde_ouverture)
	if not play.disabled and verrou_actif():
		_indice.text = "…"
		get_tree().create_timer(VERROU_SECONDES).timeout.connect(_fin_verrou.bind(kickoff))
	return kickoff

func _on_kickoff() -> void:
	if _on_kickoff_cb.is_valid(): _on_kickoff_cb.call()

func verrou_actif() -> bool:
	return float(Time.get_ticks_msec() - _ouvert_a) / 1000.0 < VERROU_SECONDES

func _garde_ouverture(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed: return
	if touche.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: return
	if verrou_actif() or touche.echo: kickoff.accept_event()

func _fin_verrou(bouton: Variant) -> void:
	if is_instance_valid(_indice) and is_instance_valid(bouton) and bouton == kickoff: _indice.text = "Entrée"

# ---- Affiche ----------------------------------------------------------------------------------------------------
