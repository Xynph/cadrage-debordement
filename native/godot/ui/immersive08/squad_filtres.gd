extends "res://ui/immersive08/squad_socle.gd"
## Écran Effectif : puces de filtre, recherche, menus Poste et « Filtres & tri » (découpe de squad_canvas.gd, sans changement).

# ---------------------------------------------------------------- puces, recherche, menus

func _compte_puce(id: String) -> int:
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var n := 0
	for p: Variant in app.model.get("squad", []):
		if not p is Dictionary: continue
		match id:
			"tous": n += 1
			"avants": n += 1 if float(p.get("fam", 0)) <= 3 else 0
			"arrieres": n += 1 if float(p.get("fam", 0)) > 3 else 0
			"indisponibles": n += 0 if U.indisponibilite(p).is_empty() else 1
			"aptes": n += 1 if U.indisponibilite(p).is_empty() else 0
			"fin": n += 1 if p.get("contractEnd") != null and int(p.contractEnd) <= saison else 0
			"surveiller": n += 0 if U.watch_reason(p).is_empty() else 1
	return n

func _puce_active(id: String) -> bool:
	var famille := str(state.family)
	if id == "fin": return str(state.contract) == "Fin de saison"
	if id == "tous": return famille == "Tous" and str(state.contract) == "Tous"
	if str(state.contract) != "Tous": return false
	return famille == {"avants": "Avants", "arrieres": "Arrières", "indisponibles": "Indisponibles", "aptes": "Aptes", "surveiller": U.WATCH_FILTER}.get(id, "?")

func _appliquer_puce(id: String) -> void:
	var etait_surveillance: bool = state.family == U.WATCH_FILTER
	state.family = "Tous"
	state.contract = "Tous"
	if id != "fin": state.family = {"avants": "Avants", "arrieres": "Arrières", "indisponibles": "Indisponibles", "aptes": "Aptes", "surveiller": U.WATCH_FILTER}.get(id, "Tous")
	else: state.contract = "Fin de saison"
	app.roster_filter = state.family
	state.scroll = 0
	if etait_surveillance != (state.family == U.WATCH_FILTER):
		state.focus = "RosterChip_" + id
		app._render(false)
	else:
		_refresh(false)
		_styler_puces()

func _styler_puces() -> void:
	for action: String in _marques_tuiles:
		(_marques_tuiles[action] as Node2D).visible = _tuile_active(action)
	for id: String in _puces:
		var puce: Button = _puces[id].bouton
		var active := _puce_active(id)
		# Charte §7.1 : puce de filtre en pilule ; active = aplat crème, texte PANNEAU ; inactive = contour FILET.
		var fond := _plat(Charte.IVOIRE if active else Color.TRANSPARENT, Color.TRANSPARENT if active else Charte.FILET, 0 if active else 1, Charte.RAYON_PILULE)
		fond.content_margin_left = C.px(17)
		puce.add_theme_stylebox_override("normal", fond)
		var survol := _plat(Charte.IVOIRE if active else Charte.PANNEAU_2, Color.TRANSPARENT if active else Charte.IVOIRE_3, 0 if active else 1, Charte.RAYON_PILULE)
		survol.content_margin_left = C.px(17)
		puce.add_theme_stylebox_override("hover", survol)
		var appui := _plat(Charte.IVOIRE if active else Charte.PANNEAU_3, Color.TRANSPARENT if active else Charte.FILET, 0 if active else 1, Charte.RAYON_PILULE)
		appui.content_margin_left = C.px(17)
		puce.add_theme_stylebox_override("pressed", appui)
		var focus := _plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
		focus.set_expand_margin_all(2)
		puce.add_theme_stylebox_override("focus", focus)
		for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: puce.add_theme_color_override(cle, Charte.PANNEAU if active else Charte.IVOIRE_2)
		(_puces[id].compte as Label).add_theme_color_override("font_color", Charte.PANNEAU if active else C.MUTED)
		_puces[id].marque.visible = false
		puce.accessibility_name = "%s, %d%s" % [_puces[id].texte, _puces[id].nombre, " · actif" if active else ""]

func _filtres() -> void:
	var y := Y_FILTRES
	var recherche := LineEdit.new()
	recherche.name = "RosterSearch"
	recherche.placeholder_text = "Rechercher un joueur…"
	recherche.text = str(state.search)
	recherche.clear_button_enabled = true
	recherche.accessibility_name = "Rechercher un joueur par nom ou poste"
	recherche.add_theme_font_override("font", C.BODY)
	recherche.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	recherche.add_theme_color_override("font_color", Charte.IVOIRE)
	recherche.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_2)
	var champ := _plat(Charte.PANNEAU_2, Charte.FILET, 1, Charte.RAYON_PILULE)
	champ.content_margin_left = C.px(46)
	champ.content_margin_right = C.px(60)
	recherche.add_theme_stylebox_override("normal", champ)
	var champ_actif := _plat(Charte.PANNEAU_3, Charte.IVOIRE, 1, Charte.RAYON_PILULE)
	champ_actif.content_margin_left = C.px(46)
	champ_actif.content_margin_right = C.px(60)
	recherche.add_theme_stylebox_override("focus", champ_actif)
	add_child(recherche)
	# Colonne de panneaux dépliée : la rangée tient dans la largeur restante (recherche et menu Poste plus étroits).
	var l_rech := 440.0 if _lt > 2000.0 else 300.0
	var l_poste := 330.0 if _lt > 2000.0 else 250.0
	D.place(recherche, C.reach_rect(Rect2(_x0 + Bandeau.MARGE, y, l_rech, 42)))
	var loupe := C.icon("search", 21, Charte.IVOIRE_2)
	loupe.name = "RosterSearchGlyph"
	recherche.add_child(loupe)
	D.place(loupe, Rect2(14, 10, 21, 21))
	var touche := D.text(recherche, l_rech - 26.0, 28, "/", 19, C.MUTED, 700, 28, HORIZONTAL_ALIGNMENT_RIGHT)
	touche.name = "RosterSearchKey"
	recherche.text_changed.connect(func(valeur: String): state.search = valeur; state.scroll = 0; _refresh(false))
	var x := _x0 + Bandeau.MARGE + l_rech + 24.0
	var definitions := [["tous", "Tous"], ["avants", "Avants"], ["arrieres", "Arrières"], ["indisponibles", "Indisponibles"], ["fin", "Fin de contrat"], ["surveiller", "À surveiller"]]
	if str(state.family) == "Aptes": definitions.append(["aptes", "Aptes"])
	for definition: Array in definitions:
		var id: String = definition[0]
		var texte: String = definition[1]
		var nombre := _compte_puce(id)
		var l_texte := _largeur(texte, 19)
		var l_nombre := _largeur(str(nombre), 19)
		var largeur := 34.0 + l_texte + 12.0 + l_nombre
		var bouton := _lien(self, Rect2(x, y, largeur, 42), texte, _appliquer_puce.bind(id), "RosterChip_" + id, Charte.IVOIRE_2, 19.0)
		bouton.tooltip_text = ""
		var compte := D.text(bouton, 17 + l_texte + 12, 28, str(nombre), 19, C.MUTED, 600, l_nombre + 4)
		compte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marque := _marqueur(bouton, Rect2(0, 0, 5, 42))
		_puces[id] = {"bouton": bouton, "marque": marque, "compte": compte, "texte": texte, "nombre": nombre}
		x += largeur + 8.0
	_styler_puces()
	# À droite : menu Poste et Filtres & tri (menus déroulants, pas de fenêtre).
	var largeur_filtres := _largeur("Filtres & tri", 19) + 22.0 + 40.0
	var filtres := MenuButton.new()
	filtres.name = "RosterMoreFilters"
	filtres.text = "Filtres & tri"
	filtres.flat = false
	filtres.focus_mode = Control.FOCUS_ALL
	filtres.icon = C.icon_texture("settings", Charte.IVOIRE)
	filtres.expand_icon = true
	C.style_bouton_lien(filtres, 19)
	filtres.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	filtres.add_theme_constant_override("icon_max_width", C.px(22))
	filtres.add_theme_constant_override("h_separation", C.px(8))
	add_child(filtres)
	D.place(filtres, C.reach_rect(Rect2(LARGEUR - Bandeau.MARGE - largeur_filtres, y, largeur_filtres, 42)))
	var menu := filtres.get_popup()
	menu.name = "RosterFiltersMenu"
	menu.about_to_popup.connect(_remplir_menu.bind(menu))
	menu.id_pressed.connect(_choix_menu)
	var poste := OptionButton.new()
	poste.name = "RosterPosition"
	poste.fit_to_longest_item = false
	poste.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	poste.tooltip_text = "Filtrer par poste"
	poste.add_theme_font_override("font", C.BODY)
	poste.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	for nom: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		poste.add_theme_color_override(nom, Charte.IVOIRE)
	poste.add_theme_stylebox_override("normal", _champ(Charte.PANNEAU_2, Charte.FILET))
	poste.add_theme_stylebox_override("hover", _champ(Charte.PANNEAU_3, Charte.IVOIRE_3))
	poste.add_theme_stylebox_override("pressed", _champ(Charte.PANNEAU_3, Charte.IVOIRE_3))
	poste.add_theme_stylebox_override("focus", _champ(Charte.PANNEAU_2, Charte.IVOIRE))
	var valeurs: Array = app.SquadViews._positions(app.model.get("squad", []))
	for valeur in valeurs: poste.add_item("Poste : " + str(valeur))
	poste.select(maxi(0, valeurs.find(str(state.position))))
	poste.item_selected.connect(func(index: int): state.position = str(valeurs[index]); _refresh(false))
	add_child(poste)
	D.place(poste, C.reach_rect(Rect2(LARGEUR - Bandeau.MARGE - largeur_filtres - 20 - l_poste, y, l_poste, 42)))

func _remplir_menu(menu: PopupMenu) -> void:
	menu.clear()
	menu.add_separator("Disponibilité")
	var i := 0
	for valeur: String in ["Tous", "Disponibles", "Blessés"]:
		menu.add_radio_check_item(valeur, 100 + i)
		menu.set_item_checked(menu.get_item_index(100 + i), str(state.available) == valeur)
		i += 1
	menu.add_separator("Contrat")
	i = 0
	for valeur: String in ["Tous", "Fin de saison", "Sans contrat"]:
		menu.add_radio_check_item(valeur, 200 + i)
		menu.set_item_checked(menu.get_item_index(200 + i), str(state.contract) == valeur)
		i += 1
	menu.add_separator("Groupe")
	menu.add_radio_check_item("Hors groupe seulement", 300)
	menu.set_item_checked(menu.get_item_index(300), str(state.family) == "Hors groupe")
	menu.add_separator("Trier par")
	i = 0
	for valeur: String in TRIS:
		menu.add_radio_check_item(valeur, 400 + i)
		menu.set_item_checked(menu.get_item_index(400 + i), str(state.sort) == valeur)
		i += 1
	menu.add_separator()
	menu.add_item("Changer le sens du tri", 500)
	menu.add_item("Réinitialiser les filtres", 600)

func _choix_menu(id: int) -> void:
	if id >= 100 and id < 103:
		state.available = ["Tous", "Disponibles", "Blessés"][id - 100]
	elif id >= 200 and id < 203:
		state.contract = ["Tous", "Fin de saison", "Sans contrat"][id - 200]
	elif id == 300:
		state.family = "Tous" if str(state.family) == "Hors groupe" else "Hors groupe"
		app.roster_filter = state.family
	elif id >= 400 and id < 400 + TRIS.size():
		state.sort = TRIS[id - 400]
		app.roster_sort = state.sort
		state.descending = state.sort in ["Niveau", "Potentiel", "Condition", "Fatigue", "Minutes", "Moyenne", "Forme"]
	elif id == 500:
		state.descending = not state.descending
	elif id == 600:
		app.management_ui.roster = U.defaults(); app.roster_filter = "Tous"; app.roster_sort = "Poste"
		app._render()
		return
	state.scroll = 0
	_refresh(false)
	_styler_puces()
