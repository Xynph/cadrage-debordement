extends "res://ui/contextual/live_view_journal.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : menu du match (Échap), pages du direct (relecture, réglages), vitesse.

## Menu du match (maquette 13-match-direct-3, exception de Léo à la règle « jamais de petite fenêtre ») :
## voile noir à 70 % sous le bandeau (score et minute lisibles), panneau de 480 px, « Reprendre » en tête.
## `mode` « deleguer » : la confirmation de « Confier la fin à l'adjoint », dans le même panneau.
func ouvrir_menu(mode: String = "menu") -> void:
	if _live().is_empty(): return
	_suspendre()
	_menu_mode = mode
	_menu_quitter_arme = false
	_menu_cle = ""
	if not is_instance_valid(menu): _construire_menu()
	_actualiser_menu()
	# Voile au-dessus de tout (3D, entracte 2D, bannières) ; la rangée du score passe au-dessus de lui :
	# le score et la minute restent lisibles.
	_menu_voile.show()
	menu.show()
	move_child(_menu_voile, get_child_count() - 1)
	move_child(menu, get_child_count() - 1)
	# Seul le bandeau du score passe au-dessus du voile (lisible) ; commandes et plaques restent dessous : rien
	# d'autre n'est cliquable tant que le menu est ouvert.
	_coque_score.z_index = 1
	menu.z_index = 1
	_placer_menu()
	var premier: Control = menu.find_child("MatchMenuReprendre" if mode == "menu" else "MatchMenuConfirmer", true, false)
	if premier != null: premier.call_deferred("grab_focus")
	director._refresh_controls()

func _cacher_menu() -> void:
	if is_instance_valid(menu): menu.hide()
	if is_instance_valid(_menu_voile): _menu_voile.hide()
	if is_instance_valid(_coque_score): _coque_score.z_index = 0

## Ferme le menu ; `reprendre` : le match repart (Reprendre, Échap, Espace).
func fermer_menu(reprendre: bool = true) -> void:
	_cacher_menu()
	if reprendre: _relancer()

func _construire_menu() -> void:
	_menu_voile = ColorRect.new()
	_menu_voile.name = "MatchMenuVeil"
	_menu_voile.color = Color(Charte.NUIT, 0.7)
	_menu_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	# Un clic sur le voile, hors du panneau, ferme le menu comme Échap (reprise du match ; délégation annulée).
	_menu_voile.gui_input.connect(func(evenement: InputEvent):
		var clic := evenement as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT and menu.visible:
			accept_event()
			fermer_menu(true))
	S.full(_menu_voile)
	add_child(_menu_voile)
	menu = Control.new()
	menu.name = "MatchMenu"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(menu)
	add_child(menu)
	_menu_panneau = PanelContainer.new()
	_menu_panneau.name = "MatchMenuPanel"
	# Menu pause : la seule fenêtre permise (charte finale §7.1), panneau rayon 18 sur l'écran voilé.
	_menu_panneau.add_theme_stylebox_override("panel", _fond_hud(Vector4(12, 20, 12, 4), Charte.PANNEAU))
	menu.add_child(_menu_panneau)
	var colonne := VBoxContainer.new()
	colonne.name = "MatchMenuColumn"
	colonne.add_theme_constant_override("separation", 0)
	_menu_panneau.add_child(colonne)
	menu.hide()

## Contenu du panneau selon le mode (menu, délégation) et l'état du match ; reconstruit seulement quand
## ce qu'il dit change (le focus clavier est gardé).
func _actualiser_menu() -> void:
	if not is_instance_valid(_menu_panneau): return
	var cle := JSON.stringify([_menu_mode, _menu_quitter_arme, int(_live().get("minute", 0)), _vitesse_libelle(), echelle])
	if cle == _menu_cle: return
	_menu_cle = cle
	var colonne: VBoxContainer = _menu_panneau.get_child(0)
	var focus_avant := ""
	var focalise := get_viewport().gui_get_focus_owner()
	if focalise != null and colonne.is_ancestor_of(focalise): focus_avant = focalise.name
	S.clear(colonne)
	var e := echelle
	var tete := MarginContainer.new()
	for bord in ["left", "right"]: tete.add_theme_constant_override("margin_" + bord, roundi(12 * e))
	tete.add_theme_constant_override("margin_bottom", roundi(14 * e))
	colonne.add_child(tete)
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", roundi(4 * e))
	tete.add_child(pile)
	var minute := int(_live().get("minute", 0))
	var titre := _texte("CONFIER LA FIN À L’ADJOINT" if _menu_mode == "deleguer" else "MENU DU MATCH", Charte.TITRE_GRAS, Charte.IVOIRE)
	titre.name = "MatchMenuTitle"
	titre.add_theme_font_size_override("font_size", roundi(24 * e))
	pile.add_child(titre)
	# Plus de phrase : la minute d'arrêt est une pastille, le titre dit déjà ce que fait le menu.
	var arret := _pastille_hud("Pause · %d’" % maxi(1, minute), "MatchMenuMinute")
	pile.add_child(arret)
	colonne.add_child(_filet())
	if _menu_mode == "deleguer":
		colonne.add_child(_option("MatchMenuConfirmer", "Confirmer : l’adjoint finit le match", "", ["Entrée"], func():
			fermer_menu(false)
			director.command("delegate")))
		colonne.add_child(_option("MatchMenuAnnuler", "Annuler et reprendre le match", "", ["Échap"], func(): fermer_menu(true)))
	else:
		colonne.add_child(_option("MatchMenuReprendre", "Reprendre le match", "", ["Échap", "Espace"], func(): fermer_menu(true)))
		colonne.add_child(_option("MatchMenuReglages", "Réglages", "", "›", func(): ouvrir_reglages()))
		colonne.add_child(_option("MatchMenuVitesse", "Vitesse du match", "", {"vitesse": _vitesse_libelle()}, func(): _changer_vitesse(1)))
		var quitter_sous := "Appuie encore pour fermer" if _menu_quitter_arme else "Rejoué depuis le coup d’envoi"
		# Seule option qui ferme le jeu : dit à droite, en mots, ce qu'elle fait (pas la couleur seule).
		colonne.add_child(_option("MatchMenuQuitter", "Quitter le match", quitter_sous, "Ferme le jeu", _quitter))
	var pied := HBoxContainer.new()
	pied.name = "MatchMenuKeys"
	pied.add_theme_constant_override("separation", roundi(18 * e))
	var marge_pied := MarginContainer.new()
	for bord in ["left", "right"]: marge_pied.add_theme_constant_override("margin_" + bord, roundi(12 * e))
	for bord in ["top", "bottom"]: marge_pied.add_theme_constant_override("margin_" + bord, roundi(12 * e))
	marge_pied.add_child(pied)
	colonne.add_child(marge_pied)
	# Raccourcis clavier : derrière un « ? » (les puces de touche des options restent à droite des lignes).
	pied.add_child(_aide_touches("↑ ↓  choisir   ·   Entrée  valider   ·   Échap  " + ("reprendre" if _menu_mode == "menu" else "annuler"), "MatchMenuAide"))
	_menu_panneau.custom_minimum_size.x = roundf(480 * e)
	_menu_panneau.reset_size()
	_placer_menu()
	if not focus_avant.is_empty():
		var retrouve: Control = colonne.find_child(focus_avant, true, false)
		if retrouve != null: retrouve.call_deferred("grab_focus")

## Option du menu : ligne de 52 px (1080p), libellé, précision en gris-vert, indication à droite ; survol en
## panneau plus clair (rayon 12), focus en panneau choisi avec l'anneau doré de la charte et le marqueur crème à gauche.
func _option(nom: String, libelle: String, precision: String, droite: Variant, action: Callable) -> Button:
	var e := echelle
	var bouton := Button.new()
	bouton.name = nom
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.pressed.connect(action)
	bouton.set_meta("contextual_enabled", true)
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fond := Color(0, 0, 0, 0)
		if etat in ["hover", "pressed"]: fond = Charte.PANNEAU_2
		if etat == "focus": fond = Charte.PANNEAU_3
		var style := _fond_hud(Vector4.ZERO, fond, Charte.RAYON_CARTE)
		if etat == "focus":
			style.border_color = Charte.OR
			style.set_border_width_all(2)
			style.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override(etat, style)
	var rangee := HBoxContainer.new()
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_theme_constant_override("separation", roundi(12 * e))
	S.full(rangee)
	rangee.offset_left = roundf(16 * e)
	rangee.offset_right = -roundf(12 * e)
	bouton.add_child(rangee)
	var marqueur := Marqueur.new()
	marqueur.name = "Marqueur"
	marqueur.custom_minimum_size = Vector2(roundf(6 * e), roundf(26 * e))
	marqueur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marqueur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marqueur.modulate.a = 0.0
	rangee.add_child(marqueur)
	bouton.focus_entered.connect(func(): marqueur.modulate.a = 1.0)
	bouton.focus_exited.connect(func(): marqueur.modulate.a = 0.0)
	var pile := VBoxContainer.new()
	pile.alignment = BoxContainer.ALIGNMENT_CENTER
	pile.add_theme_constant_override("separation", 0)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(pile)
	rangee.add_child(pile)
	var titre := _texte(libelle, Charte.texte_moyen(), Charte.IVOIRE)
	titre.name = "Libelle"
	titre.add_theme_font_size_override("font_size", roundi(17 * e))
	pile.add_child(titre)
	if not precision.is_empty():
		var sous := _texte(precision, Charte.TEXTE, Charte.IVOIRE_2)
		sous.name = "Precision"
		sous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sous.add_theme_font_size_override("font_size", roundi(13 * e))
		pile.add_child(sous)
	if droite is Dictionary:
		# Vitesse : ◂ ralentit, ▸ accélère (deux zones distinctes) ; la ligne elle-même avance d'un cran.
		var reglage := HBoxContainer.new()
		reglage.name = "Droite"
		reglage.add_theme_constant_override("separation", roundi(6 * e))
		reglage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for sens: int in [-1, 1]:
			var fleche := Button.new()
			fleche.name = "MatchMenuVitesseMoins" if sens < 0 else "MatchMenuVitessePlus"
			fleche.text = "◂" if sens < 0 else "▸"
			fleche.focus_mode = Control.FOCUS_NONE
			fleche.tooltip_text = "Plus lent" if sens < 0 else "Plus rapide"
			fleche.set_meta("contextual_enabled", true)
			fleche.pressed.connect(_changer_vitesse.bind(sens))
			C.style_bouton_lien(fleche, 16)
			fleche.add_theme_font_override("font", Charte.texte_moyen())
			fleche.add_theme_font_size_override("font_size", roundi(16 * e))
			fleche.custom_minimum_size = Vector2(roundf(28 * e), roundf(32 * e))
			fleche.alignment = HORIZONTAL_ALIGNMENT_CENTER
			if sens > 0:
				var valeur := _texte(str(droite.get("vitesse", "")), Charte.texte_moyen(), Charte.IVOIRE)
				valeur.name = "Valeur"
				valeur.add_theme_font_size_override("font_size", roundi(16 * e))
				reglage.add_child(valeur)
			reglage.add_child(fleche)
		rangee.add_child(reglage)
	elif droite is Array:
		# Touches du raccourci (« Échap », « Espace ») en puces, comme la maquette.
		var touches := HBoxContainer.new()
		touches.name = "Droite"
		touches.mouse_filter = Control.MOUSE_FILTER_IGNORE
		touches.add_theme_constant_override("separation", roundi(6 * e))
		touches.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for nom_touche: Variant in droite:
			var puce := _touche(str(nom_touche))
			(puce.get_child(0) as Label).add_theme_font_size_override("font_size", roundi(13 * e))
			touches.add_child(puce)
		rangee.add_child(touches)
	elif not str(droite).is_empty():
		var texte_droite := str(droite)
		var indication := _texte(texte_droite, Charte.texte_moyen(), Charte.IVOIRE if texte_droite.begins_with("◂") else Charte.IVOIRE_2)
		indication.name = "Droite"
		indication.add_theme_font_size_override("font_size", roundi((16 if texte_droite.begins_with("◂") else 15) * e))
		rangee.add_child(indication)
	bouton.custom_minimum_size.y = maxf(roundf(52 * e), (pile.get_combined_minimum_size().y if not precision.is_empty() else 0.0) + roundf(16 * e))
	return bouton

func _changer_vitesse(sens: int) -> void:
	if regie != null:
		var i := VITESSES.find(str(regie.horloge))
		var suivante: String = VITESSES[wrapi(i + sens, 0, VITESSES.size())]
		regie.choisir_horloge(suivante)
		if regie.between != null: regie.between.horloge = suivante
	else:
		var pas := [1, 4, 12]
		var j := wrapi(pas.find(int(app.tick_steps)) + sens, 0, pas.size())
		_cadence.select(j)
		_choisir_cadence(j)
	_actualiser_menu()

## « Quitter le match » : un premier appui arme (la ligne dit ce qui va se passer), le second ferme le jeu.
## Pas de reprise en plein match (décision de Léo, 16/11/2026) : la carrière repart avant le match.
func _quitter() -> void:
	if not _menu_quitter_arme:
		_menu_quitter_arme = true
		_actualiser_menu()
		return
	app._close()

## « Relire » (et « → » d'un fait) dans le tiroir Journal : la relecture des faits filtrés dans une page du direct,
## match en pause, « ← Retour au direct » (jamais une fenêtre pendant le match).
func ouvrir_relecture(evenements: Array, equipes: Array, depart: int = -1) -> void:
	if evenements.is_empty(): return
	_suspendre()
	_relecture = [evenements, equipes, depart]
	_ouvrir_page("relecture")

## Réglages (son, image, commandes) depuis le menu du match : l'écran Réglages de la coque, monté dans une
## page du direct ; « Retour au menu du match ».
func ouvrir_reglages() -> void:
	_cacher_menu()
	_ouvrir_page("reglages")

func _ouvrir_page(sorte: String) -> void:
	_mini_fiche().cacher(app)
	if drawer.visible: _fermer_tiroir()
	_page_sorte = sorte
	_page_cle = ""
	if not is_instance_valid(page):
		page = Control.new()
		page.name = "MatchPage"
		page.mouse_filter = Control.MOUSE_FILTER_STOP
		S.full(page)
		add_child(page)
	page.show()
	move_child(page, get_child_count() - 1)
	_actualiser_page()
	director._refresh_controls()

## Page reconstruite quand son contenu change (onglet de la fiche, réponse du moteur, échelle).
func _actualiser_page() -> void:
	if not is_instance_valid(page) or not page.visible: return
	var etat_page: Variant = null
	if _page_sorte == "relecture": etat_page = [_relecture[2], _relecture[0].size()] if _relecture.size() == 3 else null
	var cle := JSON.stringify([_page_sorte, etat_page, size, C.density])
	if cle == _page_cle: return
	_page_cle = cle
	S.clear(page)
	var fond := ColorRect.new()
	fond.color = Charte.FOND
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fond)
	page.add_child(fond)
	var marge := MarginContainer.new()
	S.full(marge)
	for bord in ["left", "top", "right", "bottom"]: marge.add_theme_constant_override("margin_" + bord, roundi(MARGE * echelle))
	page.add_child(marge)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", roundi(12 * echelle))
	marge.add_child(colonne)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", roundi(18 * echelle))
	colonne.add_child(tete)
	var retour := Button.new()
	retour.name = "MatchPageBack"
	retour.text = "←  Retour au menu du match" if _page_sorte == "reglages" else "←  Retour au direct"
	retour.pressed.connect(fermer_page)
	retour.set_meta("contextual_enabled", true)
	C.style_bouton_lien(retour, 19, true)
	retour.add_theme_font_size_override("font_size", roundi(16 * echelle))
	tete.add_child(retour)
	if _page_sorte in ["reglages", "relecture"]:
		var titre := _texte("RÉGLAGES" if _page_sorte == "reglages" else "RELIRE LES ACTIONS", Charte.TITRE_GRAS, Charte.IVOIRE)
		titre.add_theme_font_size_override("font_size", roundi(22 * echelle))
		tete.add_child(titre)
	var espace := Control.new()
	espace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(espace)
	tete.add_child(espace)
	var rappel := _pastille_hud("Pause · %d’" % maxi(1, int(_live().get("minute", 0))), "MatchPageNote")
	tete.add_child(rappel)
	colonne.add_child(_filet())
	var defile := ScrollContainer.new()
	defile.name = "MatchPageScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	defile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	C.fill(defile, true)
	colonne.add_child(defile)
	if _page_sorte == "relecture":
		# Relecture des faits du tiroir Journal : son propre défilement, colonne de lecture de 960 px (1080p).
		defile.hide()
		var contenu: Control = load("res://match_action_review.gd").page(colonne, _relecture[0], _relecture[1], int(_relecture[2]))
		if contenu != null:
			contenu.size_flags_vertical = Control.SIZE_EXPAND_FILL
			contenu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			contenu.custom_minimum_size = Vector2(minf(size.x - 2.0 * MARGE * echelle, 960.0 * echelle), 0)
	elif _page_sorte == "reglages":
		var contenu: Control = load("res://ui/preferences_dialog.gd").page(app, app.get("user_preferences"))
		C.fill(contenu, true)
		defile.add_child(contenu)
	retour.call_deferred("grab_focus")

## Retour : au menu du match depuis les réglages, au direct depuis une fiche (le match repart s'il jouait).
func fermer_page() -> void:
	_mini_fiche().cacher(app)
	if not is_instance_valid(page): return
	var sorte := _page_sorte
	page.hide()
	S.clear(page)
	_page_sorte = ""
	_page_cle = ""
	if sorte == "reglages":
		apply_preferences()
		var reprendre := _reprendre_apres
		ouvrir_menu()
		_reprendre_apres = reprendre
	elif _reprendre_apres:
		_relancer()
	director._refresh_controls()
