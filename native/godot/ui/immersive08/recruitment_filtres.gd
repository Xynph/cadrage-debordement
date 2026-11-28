extends "res://ui/immersive08/recruitment_entete.gd"
## Écran Recrutement : recherche, menus de filtre, liens d'action, pastilles de poste (découpe de recruitment_canvas.gd, sans changement).

func _filters(positions: Array) -> void:
	var recherche := LineEdit.new()
	recherche.name = "MarketSearch"
	recherche.placeholder_text = "Rechercher une piste…"
	recherche.text = str(state.get("search", ""))
	recherche.clear_button_enabled = true
	recherche.accessibility_name = "Rechercher une piste par nom ou poste"
	recherche.add_theme_font_override("font", Charte.TEXTE)
	recherche.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	recherche.add_theme_color_override("font_color", Charte.IVOIRE)
	recherche.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_3)
	recherche.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3, Charte.IVOIRE_3, Charte.RAYON_PILULE, 10))
	var focus := C.box(Charte.PANNEAU_3, Charte.IVOIRE, Charte.RAYON_PILULE, 10)
	focus.set_border_width_all(2)
	recherche.add_theme_stylebox_override("focus", focus)
	add_child(recherche)
	var l_rech := 230.0 if C.density < .75 else 330.0
	D.place(recherche, Rect2(Bandeau.MARGE, Y_FILTRES, l_rech, 38))
	recherche.text_changed.connect(func(value: String):
		state.search = value
		state.navigation_id = ""
		_filter_changed())
	var k := 1.3 if C.density < .75 else 1.0
	var x := l_rech + 16.0 + Bandeau.MARGE
	position_filter = _choice(Rect2(x, Y_FILTRES, 270, 38), "MarketPosition", "Poste", positions, state.position, func(value: String): state.position = value; state.position_libre = true; _filter_changed())
	x += 282
	_choice(Rect2(x, Y_FILTRES, 190, 38), "MarketAge", "Âge", ["Tous", "≤ 22 ans", "23–28 ans", "≥ 29 ans"], state.get("age_filter", "Tous"), func(value: String): state.age_filter = value; _filter_changed())
	x += 202
	_choice(Rect2(x, Y_FILTRES, 210, 38), "MarketAvailability", "Offres", ["Tous", "Disponibles", "Indisponibles"], state.available, func(value: String): state.available = value; _filter_changed())
	x += 222
	_choice(Rect2(x, Y_FILTRES, 250 * k, 38), "MarketBudget", "Indemnité", ["Toutes", "≤ 100 k€", "≤ 400 k€", "≤ 1 M€"], state.get("budget_filter", "Toutes"), func(value: String): state.budget_filter = value; _filter_changed())
	x += 262 * k
	_choice(Rect2(x, Y_FILTRES, 290, 38), "MarketObservation", "Observation", ["Toutes", "Observées", "Non observées"], state.get("observation", "Toutes"), func(value: String): state.observation = value; _filter_changed())
	x += 302
	var reset := Kit.lien(self, Rect2(x, Y_FILTRES + 4, 0, 32), "Réinitialiser", func():
		app.management_ui.market = U.defaults()
		app.management_ui.market.immersive_tab = tab
		app.management_ui.market.followed = tab == 2
		app.management_ui.market.focus = "MarketReset"
		app._render(false), "MarketReset", 18)
	reset.tooltip_text = ""
	# Liens d'action, de droite à gauche : « Comparer », puis ceux de la ligne des onglets qui n'y tenaient pas.
	var droite := float(WIDTH) - Bandeau.MARGE
	var comparer := Kit.lien(self, Rect2(droite, Y_FILTRES + 4, 0, 32), "Comparer →", func(): _compare(), "CompareMarket", 18, true)
	comparer.accessibility_name = "Comparer deux pistes de recrutement"
	droite -= comparer.size.x / C.density + 18
	# Recherche ciblée du recruteur (revue FM27, idée 26).
	var ciblee := Kit.lien(self, Rect2(droite, Y_FILTRES + 4, 0, 32), "Recherche ciblée →", func(): _recherche(), "RechercheCibleeOuvrir", 18, true)
	droite -= ciblee.size.x / C.density + 18
	for lien: Array in _liens_filtre:
		var bouton := Kit.lien(self, Rect2(droite, Y_FILTRES + 4, 0, 32), str(lien[1]), lien[2], str(lien[0]), 18, true)
		bouton.tooltip_text = ""
		if lien[3]: bouton.add_theme_font_override("font", Charte.TITRE_GRAS)
		droite -= bouton.size.x / C.density + 18	# Barre des rapports (onglet Rapports) : les filtres de la liste n'y servent pas.
	for nom in ["MarketPosition", "MarketAge", "MarketAvailability", "MarketBudget", "MarketObservation", "MarketSearch"]:
		var champ := get_node_or_null(nom) as Control
		if champ != null: champ.visible = tab != 3
	reset.visible = tab != 3
	var missions := Kit.lien(self, Rect2(Bandeau.MARGE, Y_FILTRES + 4, 0, 32), "Missions et échéances →", func(): _staff(1), "OpenRecruitmentMissions", 18)
	missions.visible = tab == 3

func _choice(zone: Rect2, id: String, caption: String, values: Array, current: Variant, change: Callable) -> OptionButton:
	var champ := OptionButton.new()
	champ.name = id
	champ.fit_to_longest_item = false
	champ.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	champ.accessibility_name = caption
	for valeur in values: champ.add_item(caption + " : " + str(valeur))
	champ.select(maxi(0, values.find(current)))
	champ.item_selected.connect(func(index: int): change.call(str(values[index])))
	add_child(champ)
	D.place(champ, zone)
	Kit.styler_liste(champ)
	return champ

func _filter_changed() -> void:
	state.page = 0
	state.scroll = 0
	if table_scroll != null: table_scroll.scroll_vertical = 0
	_refresh()



# --- Pastilles de poste (choix de Léo du 21/11/2026) ------------------------------------------------------------

func _choisir_groupe(id: String) -> void:
	state.poste_groupe = id
	if not id.is_empty():
		state.position = "Tous"
		state.position_libre = true
	state.scroll = 0
	state.focus = "PostePastille_" + (id if not id.is_empty() else "tous")
	app._render(false)

func _pastilles_postes() -> void:
	# Le bandeau des filtres finit au-dessus du tableau ; Rapports : filtres seuls, sans pastilles de poste.
	var bas := Y_FILTRES + 38.0 + 10.0
	if tab != 3: bas += 48.0
	_dy = bas + Bandeau.ECART_LIGNES - TABLE_TOP
	Bandeau.poser(self, Rect2(0, Y_BANDEAU, WIDTH, bas - Y_BANDEAU))
	if tab == 3: return
	var marche: Array = app.model.get("market", [])
	Listes.pastilles_postes(self, Vector2(Bandeau.MARGE, Y_FILTRES + 46.0), Listes.compter_groupes(marche), marche.size(), str(state.get("poste_groupe", "")), _choisir_groupe)
