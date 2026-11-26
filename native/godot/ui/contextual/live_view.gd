extends "res://ui/contextual/live_view_bandeau.gd"
## Écran 13 « Match en direct » : habillage télé du match 3D (design/ux/13-match-direct.md, revue DA du
## 19/11/2026, variante 1 « Bandeau d'angle » choisie par Léo). Bandeau du score incliné en haut à gauche
## (horloge et période, plaques des deux clubs, score ivoire 40 px), commandes en haut à droite, journal
## de deux lignes en bas à gauche, bannière d'essai dans le tiers inférieur (match_temps_forts.gd) et menu
## du match ouvert par Échap (seule petite fenêtre, exception de Léo). Jetons et polices : ui/charte.gd,
## aucun or. Plein écran obligatoire : on ne quitte jamais le direct avant la fin. Les plaques des clubs et les noms
## de nos joueurs ouvrent une petite fenêtre visuelle par-dessus le match (match en pause, repris à la fermeture) ;
## le menu ouvre ses réglages dans une page du direct.

func _ready() -> void:
	name = "ContextualLiveMatch"
	app = director.app
	var container := SubViewportContainer.new()
	container.name = "LiveMatchViewport"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(container)
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	_viewport = viewport
	stage = load("res://match_view.gd").new()
	if stage.has_method("set_club_identity"): stage.set_club_identity(app.model.get("club", {}))
	viewport.add_child(stage)
	var frame := S.frame(self, MARGE)
	frame.name = "MatchHud"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rangée du haut : bandeau du score, bande des commandes (Équipe, Réglages, Plus), Pause.
	var haut := HBoxContainer.new()
	haut.name = "MatchTopRow"
	haut.add_theme_constant_override("separation", 12)
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(haut)
	_construire_bandeau(haut)
	if TempsForts.enabled():
		bande_temps_forts = HBoxContainer.new()
		bande_temps_forts.name = "MatchCommandBand"
		bande_temps_forts.add_theme_constant_override("separation", 12)
		bande_temps_forts.alignment = BoxContainer.ALIGNMENT_END
		bande_temps_forts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		C.fill(bande_temps_forts)
		bande_temps_forts.draw.connect(_fond_bande)
		haut.add_child(bande_temps_forts)
	else:
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(vide)
		haut.add_child(vide)
	play = _bouton_hud("Pause", "Espace", _pause, "MatchPauseButton")
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(play)
	_rangee_haut = haut
	# Sous le bandeau : qui a le ballon (en 3D) et météo (aux arrêts) à gauche, rappel « Échap · Pause et
	# menu » à droite.
	var sous := HBoxContainer.new()
	sous.name = "MatchSubRow"
	sous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sous.add_theme_constant_override("separation", 12)
	frame.add_child(sous)
	ligne_possession = PanelContainer.new()
	ligne_possession.name = "MatchPossession"
	ligne_possession.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_possession.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ligne_possession.add_theme_stylebox_override("panel", _fond_hud(Vector4(22, 0, 16, 0)))
	var possession_rangee := HBoxContainer.new()
	possession_rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_possession.add_child(possession_rangee)
	_possession_trait = Marqueur.new()
	_possession_trait.name = "Trait"
	_possession_trait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_possession_trait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	possession_rangee.add_child(_possession_trait)
	_possession_texte = _texte("", Charte.texte_moyen(), Charte.IVOIRE)
	_possession_texte.name = "Texte"
	possession_rangee.add_child(_possession_texte)
	ligne_possession.hide()
	sous.add_child(ligne_possession)
	meteo_ligne = S.label("", 13, Charte.IVOIRE_2)
	meteo_ligne.name = "MatchWeather"
	meteo_ligne.add_theme_font_override("font", Charte.TEXTE)
	meteo_ligne.hide()
	# Boîte propre à la ligne météo : le mode compact la masque sans lutter avec la régie, qui règle
	# la visibilité de la ligne elle-même.
	_meteo_boite = PanelContainer.new()
	_meteo_boite.name = "MatchWeatherBox"
	_meteo_boite.add_theme_stylebox_override("panel", _fond_hud(Vector4(12, 4, 12, 4)))
	_meteo_boite.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_meteo_boite.add_child(meteo_ligne)
	sous.add_child(_meteo_boite)
	var vide_sous := Control.new()
	vide_sous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(vide_sous)
	sous.add_child(vide_sous)
	indice_menu = _bouton_hud("Pause et menu", "Échap", ouvrir_menu, "MatchMenuHint", true)
	indice_menu.tooltip_text = "Met le match en pause et ouvre le menu du match."
	sous.add_child(indice_menu)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(space, true)
	frame.add_child(space)
	_construire_journal(frame)
	_construire_barre_bas(frame)
	if TempsForts.enabled():
		regie = TempsForts.new()
		add_child(regie)
		regie.setup(self, container, viewport, space)
	_construire_tiroir()
	equipe = FenetreEquipe.new()
	equipe.view = self
	equipe.app = app
	add_child(equipe)
	app.match_view = stage
	app.pause_button = play
	play.set_meta("toujours_cliquable", true)
	app.match_finish = finish
	app.match_clock = clock
	_mettre_a_l_echelle()
	get_viewport().size_changed.connect(_mettre_a_l_echelle)
	_dessiner_journal()
	apply_preferences()

# --- Construction ---------------------------------------------------------------

## Barre du bas : repli sans régie (caméras, cadence, tiroirs) et fin de match (« Valider la journée »,
## action principale : la seule pilule dorée du direct, charte finale §4.3).
func _construire_barre_bas(frame: Control) -> void:
	var cadre := PanelContainer.new()
	cadre.name = "MatchBottomBar"
	cadre.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO))
	frame.add_child(cadre)
	barre_commandes = cadre
	var marge := S.G.margin(8)
	cadre.add_child(marge)
	var controls := VBoxContainer.new()
	marge.add_child(controls)
	var bar := S.G.h(7)
	controls.add_child(bar)
	var bouton_equipe := _lien("ÉQUIPE", func(): ouvrir_equipe())
	bouton_equipe.name = "MatchTeamButton"
	bouton_equipe.tooltip_text = "Composition, banc, cris de la touche et consignes (le match se met en pause)."
	bar.add_child(bouton_equipe)
	for title in ["Stats", "Journal"]:
		bar.add_child(_lien(title.to_upper(), func(): _toggle_drawer(title)))
	for pair in [["tv", "TV"], ["tactical", "VUE DE DESSUS"], ["action", "CONTACT"]]:
		var button := _lien(pair[1], func(): _choose_camera(pair[0]))
		_camera_controls.append(button)
		bar.add_child(button)
	_cadence = OptionButton.new()
	_cadence.custom_minimum_size.y = 38
	for text in ["Cadence ×1", "Cadence ×4", "Cadence ×12"]: _cadence.add_item(text)
	_cadence.select(maxi(0, [1, 4, 12].find(app.tick_steps)))
	_cadence.item_selected.connect(_choisir_cadence)
	_cadence.set_meta("contextual_enabled", true)
	bar.add_child(_cadence)
	# Ce que le match montre, des temps forts choisis au match complet : visible en temps forts.
	_niveau = OptionButton.new()
	_niveau.name = "MatchLevel"
	_niveau.custom_minimum_size.y = 38
	_niveau.tooltip_text = "Ce que le match montre : des temps forts choisis au match complet. Conservé pour les prochains matchs."
	_niveau.set_meta("contextual_enabled", true)
	_niveau.item_selected.connect(func(index: int): if regie != null and index >= 0 and index < _niveaux.size(): regie.choisir_niveau(str(_niveaux[index].get("id", ""))))
	_niveau.hide()
	bar.add_child(_niveau)
	bar.add_child(S.G.spacer())
	bar.add_child(_lien("CONFIER LA FIN À L’ADJOINT", confier_fin))
	finish = Button.new()
	finish.text = "VALIDER LA JOURNÉE  →"
	finish.name = "MatchFinishButton"
	finish.pressed.connect(func(): director.command("finish_round"))
	finish.set_meta("contextual_enabled", false)
	finish.disabled = true
	C.style_bouton_ivoire_plein(finish, 21)
	bar.add_child(finish)

func _process(_delta: float) -> void:
	if not is_instance_valid(play) or not is_instance_valid(_coque_score): return
	_suivre_fond_bande()
	var etat := _etat_bandeau()
	_poser_pause(etat)
	if bool(etat.compact) != compact: _appliquer_bandeau(bool(etat.compact))
	_suivre_apres_match()
	if _recouvrir > 0:
		_recouvrir -= 1
		if _recouvrir == 0: _recadrer()
	_poser_periode()
	_suivre_journal()
	# Rappel « Échap » : en 3D seulement (l'entracte a ses propres rappels) et hors action en cours.
	var entracte: bool = regie != null and regie.between != null and regie.between.visible
	var rappel: bool = not compact and not entracte and not _live().get("finished", false)
	if indice_menu.visible != rappel: indice_menu.visible = rappel
	_suivre_possession(entracte)
	# Écran 2D : la météo est posée sur le terrain en icônes (retouche de Léo du 21/11/2026), plus de phrase ici.
	var meteo_vue: bool = not compact and meteo_ligne.visible and not entracte
	if _meteo_boite.visible != meteo_vue: _meteo_boite.visible = meteo_vue
	# La fenêtre Équipe ouverte depuis la bande ferme le menu (le match reste en pause).
	if is_instance_valid(menu) and menu.visible and is_instance_valid(equipe) and equipe.visible: _cacher_menu()
	# Panneau du menu : ses lignes à retour automatique ne connaissent leur hauteur qu'après une mise en page.
	if is_instance_valid(menu) and menu.visible: _placer_menu()
	if _pause_voulue != 0 and not app.waiting and not app.closing and not app.connection_error:
		var voulue := _pause_voulue > 0
		_pause_voulue = 0
		_pause_clic = false
		if bool(_live().get("paused", false)) != voulue and not _live().get("finished", false): director.command("pause", {"paused": voulue})

func update_frame(value: Dictionary) -> void:
	model = value
	if not is_node_ready(): return
	var live := _live()
	var teams: Array = live.get("teams", [{}, {}])
	if teams.size() >= 2:
		for cote in 2: _sigles[cote].text = S.G.club_abbr(teams[cote]) if teams[cote] is Dictionary else ""
		_poser_plaques(teams)
	var scores: Array = live.get("score", [0, 0])
	score.text = "%d — %d" % [int(scores[0]), int(scores[1])]
	clock.text = "%d′" % int(live.get("minute", 0))
	if live.get("finished", false): clock.text = "TERMINÉ"
	elif live.get("atBreak", false): clock.text = "MI-TEMPS"
	meteo_ligne.text = Meteo.bandeau(live)
	meteo_ligne.visible = not meteo_ligne.text.is_empty()
	meteo_ligne.add_theme_color_override("font_color", Charte.IVOIRE if live.get("atBreak", false) else Charte.IVOIRE_2)
	meteo_ligne.tooltip_text = Meteo.conseil(live)
	meteo_ligne.mouse_filter = Control.MOUSE_FILTER_PASS if not meteo_ligne.tooltip_text.is_empty() else Control.MOUSE_FILTER_IGNORE
	finish.visible = live.get("finished", false)
	finish.set_meta("contextual_enabled", live.get("finished", false))
	if stage.has_method("set_club_identity"): stage.set_club_identity(model.get("club", {}))
	if regie == null:
		stage.set_live_cadence(app.tick_steps)
		stage.apply_frame(live)
		# Repli : les deux derniers faits du moteur, avec leur minute.
		var rows: Array = live.get("events", [])
		var faits: Array = []
		for event: Variant in rows.slice(maxi(0, rows.size() - 2)):
			if event is Dictionary: faits.push_front({"minute": "%s'" % str(event.get("min", "")), "texte": sigles_affiches(str(event.get("text", "")), live.get("teams", []))})
			else: faits.push_front({"minute": "", "texte": str(event)})
		_journal = faits
		events.text = str(faits[0].texte) if not faits.is_empty() else ""
		_journal_texte = events.text.strip_edges()
		_dessiner_journal()
		events.get_parent().get_parent().visible = not faits.is_empty()
		_legende.visible = not faits.is_empty()
	if regie != null:
		regie.receive(model, live)
		if live.get("direct") is Dictionary: montrer_reglages_temps_forts(live.direct, regie)
	_update_drawer()
	if is_instance_valid(equipe): equipe.update_frame(model)
	if is_instance_valid(apres_match): apres_match.update_frame(model)
	_suivre_apres_match()
	apply_preferences()
	# Après la régie (elle dit si un temps fort se joue) : libellé et accès du bouton de pause ;
	# une causerie retenue par un temps fort bloque aussi la reprise (elle passera par elle).
	var etat := _etat_bandeau()
	_poser_pause(etat)
	if bool(etat.compact) != compact: _appliquer_bandeau(bool(etat.compact))
	if is_instance_valid(page) and page.visible: _actualiser_page()
	if is_instance_valid(menu) and menu.visible: _actualiser_menu()
	director._refresh_controls()

func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not is_visible_in_tree(): return
	if touche.ctrl_pressed or touche.alt_pressed or touche.meta_pressed: return
	var code: int = touche.keycode if touche.keycode != 0 else touche.physical_keycode
	var menu_ouvert := is_instance_valid(menu) and menu.visible
	# Petite fenêtre ouverte : comme une page, elle garde Espace et T.
	var page_ouverte := (is_instance_valid(page) and page.visible) or fenetre_ouverte()
	if code == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		# Une petite fenêtre ouverte passe avant le menu du match.
		if not PetiteFenetre.fermer_derniere(get_tree()): echap()
	elif code == KEY_SPACE:
		if menu_ouvert:
			get_viewport().set_input_as_handled()
			fermer_menu(true)
		# Une commande qui a le focus (liste du journal, bouton) garde son Espace.
		elif not page_ouverte and not equipe.visible and not play.disabled and not get_viewport().gui_get_focus_owner() is BaseButton:
			get_viewport().set_input_as_handled()
			_pause()
	elif code == KEY_T and not menu_ouvert and not page_ouverte and not equipe.visible and not _live().get("finished", false):
		get_viewport().set_input_as_handled()
		ouvrir_equipe()
	elif menu_ouvert and code in [KEY_LEFT, KEY_RIGHT]:
		var vitesse: Control = menu.find_child("MatchMenuVitesse", true, false)
		if vitesse != null and vitesse.has_focus():
			get_viewport().set_input_as_handled()
			_changer_vitesse(1 if code == KEY_RIGHT else -1)

## Échap : ferme ce qui est ouvert (page, menu, fenêtre Équipe, tiroir) ; sinon met en pause et ouvre le
## menu du match (jamais celui de la carrière).
func echap() -> void:
	_mini_fiche().cacher(app)
	# Après-match (écran 15) : Échap ne ferme rien et n'ouvre pas le menu du match (décision du 16/11).
	if is_instance_valid(apres_match) and apres_match.visible: return
	if is_instance_valid(page) and page.visible:
		fermer_page()
	elif is_instance_valid(menu) and menu.visible:
		fermer_menu(true)
	elif is_instance_valid(equipe) and equipe.visible:
		equipe.fermer()
	elif drawer.visible:
		_fermer_tiroir()
	else:
		ouvrir_menu()

## « Confier la fin à l'adjoint » (Plus) : confirmation dans le menu du match, pas dans une fenêtre.
func confier_fin() -> void:
	ouvrir_menu("deleguer")

# --- Petites fenêtres du direct : club, joueur ------------------------------------------------------

## Fenêtre « Équipe » (choix de Léo, 18/11/2026 : un seul bouton à la place de Tactique et Banc) :
## plein écran, le match se met en pause à l'ouverture et repart avec « Valider et reprendre ».
## `onglet` : « composition » ou « consignes » ; `poste` : joueur du XV déjà choisi (0 à 14).
func ouvrir_equipe(onglet: String = "composition", poste: int = -1) -> void:
	if not is_instance_valid(equipe) or _live().get("finished", false): return
	if drawer.visible: _fermer_tiroir()
	_cacher_menu()
	equipe.update_frame(model)
	equipe.ouvrir(onglet, poste)
	director._refresh_controls()

func _toggle_drawer(title: String) -> void:
	# Composition, banc et consignes : la fenêtre Équipe (anciens onglets Tactique et Banc compris).
	if title in ["Équipe", "Banc", "Tactique"]:
		ouvrir_equipe("consignes" if title == "Tactique" else "composition")
		return
	if title == drawer_tab and drawer.visible:
		_fermer_tiroir()
		return
	drawer_tab = title
	drawer.show()
	_drawer_key = ""
	_update_drawer()
	if regie != null: regie.tiroir_ferme()

func _update_drawer() -> void:
	_journal_shell.visible = drawer_tab == "Journal"
	drawer_body.get_parent().visible = drawer_tab != "Journal"
	if drawer_tab.is_empty(): return
	var live := _live()
	if drawer_tab == "Journal":
		journal.update_frame(regie.montre(live) if regie != null else live)
		return
	var key := JSON.stringify([drawer_tab, _stats(live), live.get("finished")])
	if key == _drawer_key: return
	_drawer_key = key
	S.clear(drawer_body)
	drawer_body.add_child(S.label(drawer_tab, 23, Charte.IVOIRE))
	for stat: Dictionary in _stats(live):
		drawer_body.add_child(S.label(str(stat.get("label", "")), 13, Charte.IVOIRE_2))
		drawer_body.add_child(S.label("%s    —    %s" % [str(stat.get("home", "")), str(stat.get("away", ""))], 23, Charte.IVOIRE))
		# Détail par équipe sous le compte (pénalités par phase, lancers pas droits) : une ligne courte chacune.
		if stat.get("detail") is Array:
			for ligne: Variant in stat.detail: drawer_body.add_child(S.wrap(str(ligne), 12, Charte.IVOIRE_2))
	if _stats(live).is_empty(): drawer_body.add_child(S.wrap("Aucune statistique", 14, Charte.IVOIRE_2))
	director._refresh_controls()

## L'après-match prend toute la vue dès que le match est fini et entièrement montré (bouton de validation du direct
## visible) ; la scène 3D, cachée dessous, cesse alors d'être rendue.
func _suivre_apres_match() -> void:
	# Retour d'une consultation (fiche d'un club, levier…) : la vue est neuve et la régie rejouerait sa fin (sortie des
	# joueurs, dernier temps fort) avant de rendre la validation ; l'après-match déjà montré pour cette rencontre
	# revient tout de suite, sans dépendre de ce délai.
	var cle := cle_apres_match(_live())
	var deja_vu: bool = not cle.is_empty() and is_instance_valid(director) and str(director.get("apres_match_vu")) == cle
	var fini: bool = bool(_live().get("finished", false)) and ((is_instance_valid(finish) and finish.visible) or deja_vu)
	if fini and is_instance_valid(director) and director.get("apres_match_vu") != null: director.apres_match_vu = cle
	if fini and not is_instance_valid(apres_match):
		apres_match = ApresMatch.new()
		apres_match.app = app
		apres_match.director = director
		add_child(apres_match)
		apres_match.update_frame(model)
		if is_instance_valid(drawer) and drawer.visible: _fermer_tiroir()
	if is_instance_valid(apres_match) and apres_match.visible != fini:
		apres_match.visible = fini
		if fini: apres_match.update_frame(model)
	if is_instance_valid(_viewport):
		var mode := SubViewport.UPDATE_DISABLED if fini else SubViewport.UPDATE_ALWAYS
		if _viewport.render_target_update_mode != mode: _viewport.render_target_update_mode = mode
