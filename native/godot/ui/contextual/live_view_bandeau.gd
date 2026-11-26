extends "res://ui/contextual/live_view_menu.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : construction du bandeau, du journal, du tiroir, mise à l'échelle, rafraîchissement.

## Bandeau d'angle : [horloge / période] [plaque du club recevant] [score] [plaque du visiteur ⟋].
func _construire_bandeau(parent: Control) -> void:
	var bandeau := BandeauAngle.new()
	bandeau.name = "MatchScoreboard"
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(bandeau)
	_coque_score = bandeau
	var horloge := _segment("MatchClockBlock", Charte.PANNEAU_3)
	bandeau.add_child(horloge)
	var pile := VBoxContainer.new()
	pile.alignment = BoxContainer.ALIGNMENT_CENTER
	pile.add_theme_constant_override("separation", -4)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horloge.add_child(pile)
	clock = _texte("", Charte.TITRE_EXTRA, Charte.IVOIRE)
	clock.name = "MatchClock"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(clock)
	phase = _texte("", Charte.texte_moyen(), Charte.IVOIRE_2)
	phase.name = "MatchPhase"
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(phase)
	for cote in 2:
		var sigle := _texte("", Charte.TITRE_EXTRA, Charte.IVOIRE)
		sigle.name = "MatchCompactAbbr%d" % cote
		sigle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sigles.append(sigle)
	home = _texte("", Charte.TITRE_GRAS, Charte.IVOIRE)
	home.name = "MatchHomeName"
	away = _texte("", Charte.TITRE_GRAS, Charte.IVOIRE)
	away.name = "MatchAwayName"
	bandeau.add_child(_plaque(0))
	var bloc_score := _segment("MatchScoreBlock", Charte.PANNEAU)
	bandeau.add_child(bloc_score)
	score = _texte("", Charte.TITRE_EXTRA, Charte.IVOIRE)
	score.name = "MatchScore"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bloc_score.add_child(score)
	bandeau.add_child(_plaque(1))

## Plaque d'un club : logo du club (_poser_ecusson, à la place de la pastille du sigle), nom en capitales ; survol ou focus : le nom se souligne.
## Clic ou Entrée : petite fenêtre du club par-dessus le match (le match se met en pause).
func _plaque(cote: int) -> PanelContainer:
	var plaque := _segment("MatchClubPlaque%d" % cote, Charte.CLUB)
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	plaque.focus_mode = Control.FOCUS_ALL
	plaque.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rangee := HBoxContainer.new()
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	plaque.add_child(rangee)
	var puce := PanelContainer.new()
	puce.name = "MatchClubChip%d" % cote
	puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puce.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	puce.add_child(_sigles[cote])
	var nom := VBoxContainer.new()
	nom.name = "MatchClubName%d" % cote
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nom.alignment = BoxContainer.ALIGNMENT_CENTER
	nom.add_theme_constant_override("separation", 0)
	nom.size_flags_vertical = Control.SIZE_FILL
	var etiquette: Label = home if cote == 0 else away
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nom.add_child(etiquette)
	var souligne := ColorRect.new()
	souligne.name = "Souligne"
	souligne.color = Charte.IVOIRE
	souligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	souligne.modulate.a = 0.0
	nom.add_child(souligne)
	if cote == 0:
		rangee.add_child(puce)
		rangee.add_child(nom)
	else:
		rangee.add_child(nom)
		rangee.add_child(puce)
	var survol := func(actif: bool): souligne.modulate.a = 1.0 if actif else 0.0
	plaque.mouse_entered.connect(survol.bind(true))
	plaque.mouse_exited.connect(func(): survol.call(plaque.has_focus()))
	plaque.focus_entered.connect(survol.bind(true))
	plaque.focus_exited.connect(survol.bind(false))
	plaque.gui_input.connect(func(event: InputEvent):
		var souris := event as InputEventMouseButton
		var touche := event as InputEventKey
		if is_instance_valid(menu) and menu.visible: return
		if (souris != null and souris.pressed and souris.button_index == MOUSE_BUTTON_LEFT) or (touche != null and touche.pressed and not touche.echo and touche.is_action("ui_accept")):
			plaque.accept_event()
			ouvrir_fiche_club(cote))
	plaques.append(plaque)
	return plaque

## Journal en bas à gauche (charte §7) : deux faits, minute en Barlow Condensed droite, texte DM Sans 16 px sur
## panneau 90 % rayon 18 ; le plus ancien en ivoire secondaire. Les noms de nos joueurs sont des liens (survol : mini-fiche ;
## clic : la fenêtre Équipe sur lui).
func _construire_journal(frame: Control) -> void:
	var rangee := S.G.h(10)
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rangee)
	var cadre := PanelContainer.new()
	cadre.name = "MatchJournalPanel"
	cadre.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO))
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	rangee.add_child(cadre)
	_legende = cadre
	var marge := MarginContainer.new()
	marge.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.add_child(marge)
	var colonne := VBoxContainer.new()
	colonne.name = "MatchJournalLines"
	colonne.mouse_filter = Control.MOUSE_FILTER_PASS
	marge.add_child(colonne)
	events = S.wrap("", 16, Charte.IVOIRE)
	events.name = "MatchLastEvent"
	events.hide()
	colonne.add_child(events)
	for rang in 2:
		var ligne := HBoxContainer.new()
		ligne.name = "MatchJournalLine%d" % rang
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_theme_constant_override("separation", 12)
		colonne.add_child(ligne)
		var minute := _texte("", Charte.TITRE_GRAS, Charte.IVOIRE if rang == 0 else Charte.IVOIRE_2)
		minute.name = "Minute"
		minute.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		ligne.add_child(minute)
		var texte := RichTextLabel.new()
		texte.name = "Texte"
		texte.bbcode_enabled = true
		texte.fit_content = true
		texte.scroll_active = false
		texte.autowrap_mode = TextServer.AUTOWRAP_OFF
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		texte.add_theme_font_override("normal_font", Charte.texte_moyen())
		texte.add_theme_color_override("default_color", Charte.IVOIRE if rang == 0 else Charte.IVOIRE_2)
		C.fill(texte)
		texte.meta_hover_started.connect(func(meta: Variant): _survol_joueur(str(meta), texte))
		texte.meta_hover_ended.connect(func(_meta: Variant): _mini_fiche().cacher(app, texte))
		texte.meta_clicked.connect(func(meta: Variant): ouvrir_joueur(str(meta)))
		ligne.add_child(texte)
		ligne.hide()
		_journal_lignes.append([minute, texte, ligne])
	rangee.add_child(S.G.spacer())

func _construire_tiroir() -> void:
	drawer = PanelContainer.new()
	drawer.name = "MatchDrawer"
	drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	drawer.offset_left = -450
	drawer.offset_right = -MARGE
	drawer.offset_top = 100
	# En temps forts, le tiroir s'ouvre sous la rangée du haut : Équipe, Réglages et Plus restent
	# cliquables tiroir ouvert.
	if bande_temps_forts != null:
		var caler := func():
			if is_instance_valid(drawer) and bande_temps_forts.is_inside_tree():
				drawer.offset_top = maxf(100.0, bande_temps_forts.get_global_rect().end.y - get_global_rect().position.y + 8.0)
		bande_temps_forts.resized.connect(caler)
		bande_temps_forts.item_rect_changed.connect(caler)
	drawer.anchor_bottom = 1
	drawer.offset_bottom = -90
	# Charte finale §3 : panneau rayon 18, sans bordure ; il se détache de l'image par sa clarté.
	drawer.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO, Charte.PANNEAU))
	add_child(drawer)
	var drawer_margin := S.G.margin(14)
	drawer.add_child(drawer_margin)
	var drawer_column := S.G.v(8)
	drawer_margin.add_child(drawer_column)
	drawer_column.add_child(_lien("FERMER  ×", _fermer_tiroir))
	drawer_body = S.G.scroll(drawer_column)
	S.G.fill(drawer_body.get_parent(), true)
	_journal_shell = PanelContainer.new()
	_journal_shell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	S.G.fill(_journal_shell, true)
	drawer_column.add_child(_journal_shell)
	var journal_margin := S.G.margin(8)
	_journal_shell.add_child(journal_margin)
	journal = preload("res://ui/match_journal.gd").new()
	journal.setup(app)
	# Journal du tiroir aux jetons de la Charte ; « Relire » ouvre une page du direct ; nos joueurs sont liés
	# (survol : mini-fiche, clic : fiche complète), les adversaires restent du texte inerte (pas de fiche).
	journal.habiller_charte()
	journal.relire = ouvrir_relecture
	journal.lier = func(texte: String) -> String: return liens_joueurs(texte, model.get("squad", []) if model.get("squad") is Array else [])
	journal.sur_joueur = ouvrir_joueur
	journal.survol_joueur = _survol_joueur
	journal.fin_survol = func(ancre: Control): _mini_fiche().cacher(app, ancre)
	journal.contexte_change = func(): if _page_sorte == "relecture": fermer_page()
	journal_margin.add_child(journal)
	for defilement: Node in drawer.find_children("*", "ScrollContainer", true, false):
		(defilement as Control).add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_journal_shell.hide()
	drawer.hide()

# --- Échelle et état du bandeau ---------------------------------------------------

## Bandeau du score (le même en 3D et pendant l'entracte 2D), commandes et journal à l'échelle.
func _mettre_a_l_echelle() -> void:
	if not is_instance_valid(clock): return
	echelle = echelle_pour(get_viewport().get_visible_rect().size.y)
	var eh := echelle * BARRE_HAUT
	var t := func(cle: String) -> int: return roundi(float(BANDEAU_TAILLES[cle]) * (echelle if cle == "legende" else eh))
	# Les tuiles du haut (score, commandes, Reprendre) séparées par le vide des grandes tuiles (24 px en 2560) : la
	# gouttière couvre aussi le débord du fond dessiné derrière les commandes.
	var rangee_haut: HBoxContainer = clock.find_parent("MatchTopRow") as HBoxContainer
	if rangee_haut != null: rangee_haut.add_theme_constant_override("separation", roundi((18 + 14) * echelle))
	var marge: MarginContainer = clock.find_parent("MatchHud").get_parent() if clock.find_parent("MatchHud") != null else null
	if marge != null:
		for bord in ["left", "top", "right", "bottom"]: marge.add_theme_constant_override("margin_" + bord, roundi(MARGE * echelle))
	clock.add_theme_font_size_override("font_size", t.call("horloge"))
	phase.add_theme_font_size_override("font_size", t.call("phase"))
	score.add_theme_font_size_override("font_size", t.call("score"))
	for nom: Label in [home, away]: nom.add_theme_font_size_override("font_size", t.call("equipe"))
	for sigle: Label in _sigles: sigle.add_theme_font_size_override("font_size", t.call("sigle"))
	var hauteur := roundf(BANDEAU_HAUTEUR * eh)
	for segment: Control in _coque_score.get_children():
		segment.custom_minimum_size.y = hauteur
		var marges := StyleBoxEmpty.new()
		marges.content_margin_left = roundf(12 * eh)
		marges.content_margin_right = roundf(16 * eh)
		if segment.name == "MatchClubPlaque1": marges.content_margin_right = roundf(18 * eh)
		if segment.name == "MatchClockBlock": marges.content_margin_left = roundf(14 * eh)
		if segment.name == "MatchScoreBlock":
			marges.content_margin_left = roundf(16 * eh)
		segment.add_theme_stylebox_override("panel", marges)
	(_coque_score.get_node("MatchClockBlock") as Control).custom_minimum_size.x = roundf(96 * eh)
	score.custom_minimum_size.x = roundf(104 * eh)
	for plaque: PanelContainer in plaques:
		var rangee: HBoxContainer = plaque.get_child(0)
		rangee.add_theme_constant_override("separation", roundi(10 * eh))
		var souligne: ColorRect = plaque.find_child("Souligne", true, false)
		souligne.custom_minimum_size.y = maxf(1.0, roundf(2 * eh))
	for etiquette: Label in [meteo_ligne]: etiquette.add_theme_font_size_override("font_size", t.call("meteo"))
	for bouton: Button in [play, indice_menu]: _habiller_bouton_hud(bouton)
	_possession_texte.add_theme_font_size_override("font_size", t.call("legende"))
	_possession_trait.custom_minimum_size = Vector2(roundf(7 * echelle), roundf(20 * echelle))
	ligne_possession.custom_minimum_size.y = roundf(36 * echelle)
	ligne_possession.add_theme_stylebox_override("panel", _fond_hud(Vector4(roundf(9 * echelle), 0, roundf(16 * echelle), 0)))
	(ligne_possession.get_child(0) as HBoxContainer).add_theme_constant_override("separation", roundi(10 * echelle))
	if is_instance_valid(_legende):
		# 744 px en 1080p ; jamais plus de 45 % de la largeur (1280 × 720 : 576 px, la 3D garde sa place).
		_legende.custom_minimum_size.x = mini(roundi(LEGENDE_LARGEUR * echelle), roundi(get_viewport_rect().size.x * 0.45))
		var marge_journal: MarginContainer = _legende.get_child(0)
		for bord in ["left", "right"]: marge_journal.add_theme_constant_override("margin_" + bord, roundi(16 * echelle))
		for bord in ["top", "bottom"]: marge_journal.add_theme_constant_override("margin_" + bord, roundi(9 * echelle))
	for ligne: Array in _journal_lignes:
		(ligne[0] as Label).add_theme_font_size_override("font_size", roundi(17 * echelle))
		(ligne[0] as Label).custom_minimum_size.x = roundf(32 * echelle)
		(ligne[1] as RichTextLabel).add_theme_font_size_override("normal_font_size", t.call("legende"))
	events.add_theme_font_size_override("font_size", t.call("legende"))
	_plaques_cle = ""
	_poser_plaques(_live().get("teams", []))
	if is_instance_valid(_menu_panneau): _placer_menu()

## Qui a le ballon : en 3D, la phrase d'état de l'écran 14 passe sous le bandeau, sur panneau, avec le liseré
## du club nommé en tête ; la phrase de la bande s'efface (elle revient telle quelle à l'entracte).
func _suivre_possession(entracte: bool) -> void:
	var etat_jeu: Label = regie.between.get("etat") if regie != null and regie.between != null and regie.between.get("etat") is Label else null
	var texte := etat_jeu.text.strip_edges() if etat_jeu != null else ""
	# Pendant une bannière (essai, mi-temps, fin), la phrase se tait : la bannière dit déjà le fait.
	var banniere: bool = regie != null and regie.get("bandeau") is Control and (regie.bandeau as Control).visible
	var montre: bool = etat_jeu != null and not entracte and not banniere and not texte.is_empty() and texte != "Le match" and not _live().get("finished", false)
	if etat_jeu != null:
		var alpha := 0.0 if montre else 1.0
		if etat_jeu.modulate.a != alpha: etat_jeu.modulate.a = alpha
	if ligne_possession.visible != montre: ligne_possession.visible = montre
	if not montre or _possession_texte.text == texte: return
	_possession_texte.text = texte
	var couleur := Charte.IVOIRE_2
	var equipes: Array = _live().get("teams", [])
	for cote in equipes.size():
		if equipes[cote] is Dictionary and texte.begins_with(S.G.club_name(equipes[cote])):
			couleur = Charte.club_trait(Color.from_string(str(S.G.identity(equipes[cote]).get("color", "")), Charte.CLUB))
	(_possession_trait as Marqueur).couleur = couleur
	_possession_trait.queue_redraw()

## Période sous l'horloge, et horloge plus petite quand elle écrit un mot (« MI-TEMPS », « TERMINÉ »).
func _poser_periode() -> void:
	var numerique := not clock.text.is_empty() and clock.text.substr(0, 1).is_valid_int()
	var texte := periode_texte(_live()) if numerique else ""
	if phase.text != texte: phase.text = texte
	phase.visible = not texte.is_empty()
	var taille := roundi((BANDEAU_TAILLES.horloge if numerique else 22) * echelle)
	if clock.get_theme_font_size("font_size") != taille: clock.add_theme_font_size_override("font_size", taille)

## Libellé et accès du bouton : « Pause » tant que le match joue à l'écran, « Reprendre » en pause.
func _poser_pause(etat: Dictionary) -> void:
	var libelle := libelle_pause(etat)
	if play.text != libelle: play.text = libelle
	# Jamais grisé tant que le match n'est pas fini (voulu par Léo) : le clic est mémorisé si le moteur est occupé.
	var possible: bool = not bool(_live().get("finished", false)) and not _live().is_empty()
	var aide := "" if bool(etat.pause_possible) or bool(_live().get("finished", false)) else "Le match est déjà arrêté : l’action en cours se termine."
	if _pause_voulue != 0 and aide.is_empty(): aide = "Demande de %s mémorisée : appliquée dès que le jeu répond." % ("pause" if _pause_voulue > 0 else "reprise")
	if play.tooltip_text != aide: play.tooltip_text = aide
	if bool(play.get_meta("contextual_enabled", true)) != possible:
		play.set_meta("contextual_enabled", possible)
		director._refresh_controls()
