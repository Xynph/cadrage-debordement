extends "res://ui/contract_review_aides.gd"
## Échéances des contrats : construction de l'écran, rafraîchissement, bandeau haut (découpe sans changement).
## Chaîne d'héritage : socle ← aides ← corps ← ce fichier public (contract_review.gd).

func _build() -> void:
	name = "ContractReview"
	add_theme_constant_override("separation", 10)
	if not app.management_ui.roster.has("contract_review"):
		app.management_ui.roster.contract_review = {"season":0,"status":"Tous","precision":"Toutes","position":"Tous","search":"","scroll":0,"focus":""}
	state = app.management_ui.roster.contract_review
	_ctx = contexte(app.model)
	if not state.has("tranche"): state.tranche = ""
	if not state.has("conseil"): state.conseil = ""
	if not state.has("sort"): state.sort = "contractEnd"
	if not state.has("descending"): state.descending = false
	var delegation: Variant = app.model.get("decisions", {}).get("delegation") if app.model.get("decisions") is Dictionary else null
	if delegation is Dictionary and delegation.has("contracts"):
		_delegation_staff(delegation)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	var squad: Array = app.model.get("squad", [])
	var known_wage := 0.0
	var unknown_wage := 0
	for player: Dictionary in squad:
		var wage: Variant = player.get("salary")
		if wage is int or wage is float: known_wage += float(wage)
		else: unknown_wage += 1
	var wage_note := " · %d ?" % unknown_wage if unknown_wage > 0 else ""
	# Compteurs d'échéance (0-6 mois / 6-12 / 1-2 ans / 2 ans +), filtres du tableau, puis la masse salariale (Finances).
	_haut(top, known_wage, wage_note)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	# Bandeau des filtres (demande de Léo du 21/11/2026) : panneau teinté détouré, distinct des lignes de contrats.
	var bandeau := PanelContainer.new()
	bandeau.name = "BandeauFiltres"
	bandeau.add_theme_stylebox_override("panel", Bandeau.style(10))
	add_child(bandeau)
	bandeau.add_child(filters)
	var search := LineEdit.new()
	search.name = "ContractReviewSearch"
	search.placeholder_text = "Nom ou poste…"
	search.text = str(state.search)
	search.custom_minimum_size = Vector2(130, 36)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.size_flags_stretch_ratio = 1.5
	search.add_theme_font_size_override("font_size", 18)
	filters.add_child(search)
	search.text_changed.connect(func(value): state.search = value; state.scroll = 0; _refresh())
	_season = _choice(filters, "ContractReviewSeason", "Toutes les années", func(index): state.season = int(_season.get_item_metadata(index)); state.scroll = 0; _refresh())
	_season.set_item_metadata(0, 0)
	var years: Array[int] = []
	for player: Dictionary in squad:
		var end := horizon(player)
		if end >= 0 and not end in years: years.append(end)
	years.sort()
	for year in years:
		_season.add_item("Fin " + G.contract_year(year))
		_season.set_item_metadata(_season.item_count - 1, year)
		if year == int(state.season): _season.select(_season.item_count - 1)
	var status := _choice(filters, "ContractReviewStatus", "Contrats : tous", func(index): state.status = STATUS_OPTIONS[index]; state.scroll = 0; _refresh())
	_status_choice = status
	_fill_choice(status, STATUS_OPTIONS.slice(1), str(state.status))
	var precision := _choice(filters, "ContractReviewPrecision", "Échéance : toutes", func(index): state.precision = ["Toutes","Échéance connue","Non renseignée"][index]; state.scroll = 0; _refresh())
	_precision_choice = precision
	_fill_choice(precision, ["Échéance connue", "Non renseignée"], str(state.precision))
	_position = _choice(filters, "ContractReviewPosition", "Tous les postes", func(index): state.position = "Tous" if index == 0 else _position.get_item_text(index); state.scroll = 0; _refresh())
	var positions: Array = []
	var previous_matches: Array = []
	for player: Dictionary in squad:
		var caption := position_caption(player)
		if caption.strip_edges().is_empty() or caption == "—": continue
		if not caption in positions: positions.append(caption)
		if str(player.get("pos", "")) == str(state.position) and not caption in previous_matches: previous_matches.append(caption)
	# Preserve an unambiguous remembered legacy filter; never rewrite player.pos.
	if str(state.position) != "Tous" and not str(state.position) in positions:
		state.position = previous_matches[0] if previous_matches.size() == 1 else "Tous"
	positions.sort()
	_fill_choice(_position, positions, str(state.position))
	filters.add_child(_button("Réinitialiser", "ContractReviewReset", _reset))
	_count = _label("", 16, C.MUTED)
	_count.name = "ContractReviewCount"
	add_child(_count)
	var columns := BoxContainer.new()
	_columns = columns
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	var main := _panel(columns)
	main.get_parent().size_flags_stretch_ratio = 3.6
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", COL_GAP)
	var inset := Control.new()
	inset.custom_minimum_size.x = 8
	header.add_child(inset)
	var entetes: Array = [["JOUEUR",0,"name"],["POSTE",0,"pos"],["NIV.",0,"rating"],["ÂGE",0,"age"],["SALAIRE " + G.salary_period(true).to_upper(),0,"salary"],["% MASSE",0,"share"],["RÔLE · TEMPS DE JEU",0,"playtime"],["ÉCHÉANCE",0,"contractEnd"],["CONSEIL DU STAFF",0,"conseil"],["",0,""]]
	for column in entetes:
		if str(column[2]).is_empty():
			header.add_child(_fit(_cell(column[0], 0, C.MUTED, 16), "actions"))
			continue
		var key := str(column[2])
		var sort := _button(str(column[0]), "ContractSort_" + key, func(): _sort(key))
		sort.custom_minimum_size.y = 30
		_fit(sort, key)
		sort.add_theme_font_size_override("font_size", 16)
		sort.clip_text = true
		sort.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for mode in ["normal","hover","pressed"]:
			sort.add_theme_stylebox_override(mode, C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		sort.set_meta("caption", str(column[0]))
		sort.set_meta("tip", {"rating": "NIVEAU", "contractEnd": "FIN DE CONTRAT", "share": "PART DE LA MASSE SALARIALE", "playtime": "TEMPS DE JEU", "conseil": "CONSEIL DU STAFF"}.get(key, str(column[0])))
		header.add_child(sort)
		_headers[key] = sort
	var outset := Control.new()
	outset.custom_minimum_size.x = 8
	header.add_child(outset)
	# En-têtes de colonnes : bande de la même famille que le bandeau des filtres.
	var bande := PanelContainer.new()
	bande.name = "BandeauEntete"
	var style_bande := Bandeau.style_entete(Charte.RAYON_PETIT)
	style_bande.corner_radius_bottom_left = style_bande.corner_radius_top_left
	style_bande.corner_radius_bottom_right = style_bande.corner_radius_top_right
	style_bande.set_content_margin_all(0)
	bande.add_theme_stylebox_override("panel", style_bande)
	main.add_child(bande)
	bande.add_child(header)
	_scroll = ScrollContainer.new()
	_scroll.name = "ContractReviewScroll"
	_scroll.follow_focus = true
	_scroll.mouse_force_pass_scroll_events = false
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 400
	main.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "ContractReviewRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows)
	_scroll.get_v_scroll_bar().value_changed.connect(func(value): state.scroll = value)
	var sidebar := _panel(columns)
	sidebar.get_parent().size_flags_stretch_ratio = 1.0
	sidebar.get_parent().custom_minimum_size.x = 440
	resized.connect(_adapt)
	var host := get_parent_control()
	if host != null: host.resized.connect(_adapt)
	_adapt()
	# Marché des transferts (vente-joueurs.cjs) : joueurs proposés, offres reçues, ventes en attente.
	var sales := Sales.sales(app.model)
	if not sales.is_empty():
		sidebar.add_child(_label("Marché des transferts", 24))
		var tiles := HBoxContainer.new()
		tiles.name = "ContractReviewSalesSummary"
		tiles.add_theme_constant_override("separation", 8)
		sidebar.add_child(tiles)
		# Les trois chiffres ouvrent la même fenêtre (offres, ventes en attente, joueurs proposés).
		tiles.add_child(_tile("Proposés", (sales.get("listed", []) as Array).size(), "ContractReviewSalesListed", "Joueurs proposés aux autres clubs : ouvrir l'écran des offres", BLEU, "people"))
		tiles.add_child(_tile("Offres", (sales.get("offers", []) as Array).size(), "ContractReviewOpenSales", "Offres reçues : ouvrir l'écran des offres", VERT, "mail"))
		tiles.add_child(_tile("Ventes", (sales.get("pending", []) as Array).size(), "ContractReviewSalesPending", "Ventes en attente : ouvrir l'écran des offres", ORANGE, "money"))
	sidebar.add_child(_label("Échéances et postes à anticiper", 24))
	var departures := (sales.get("pending", []) as Array).size()
	var departures_chip := _chip_button("ContractReviewDepartures", "check" if departures == 0 else "warning", VERT if departures == 0 else ORANGE, "Aucun départ annoncé" if departures == 0 else "%d départ%s annoncé%s" % [departures, "s" if departures > 1 else "", "s" if departures > 1 else ""], "Ouvrir les offres et ventes (Recrutement)", func(): Pages.ouvrir(app, "offres"))
	sidebar.add_child(departures_chip)
	var side_scroll := ScrollContainer.new()
	side_scroll.follow_focus = true
	_scroll.mouse_force_pass_scroll_events = false
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(side_scroll)
	_coverage = VBoxContainer.new()
	_coverage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coverage.add_theme_constant_override("separation", 8)
	side_scroll.add_child(_coverage)
	_refresh()
	call_deferred("_restore_focus")

func _choice(parent: Node, id: String, first: String, changed: Callable) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = id
	# Filtres : largeur minimale réduite, le reste partagé (la rangée tient en 1280 comme en 1920) ; texte coupé, valeur complète au survol.
	choice.custom_minimum_size = Vector2(110, 36)
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.clip_text = true
	choice.add_theme_font_override("font", C.BODY)
	choice.add_theme_font_size_override("font_size", 18)
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.add_item(first)
	choice.item_selected.connect(changed)
	parent.add_child(choice)
	return choice

func _fill_choice(choice: OptionButton, values: Array, selected: String) -> void:
	for value in values:
		choice.add_item(str(value))
		if str(value) == selected: choice.select(choice.item_count - 1)

func _reset() -> void:
	state.merge({"season":0,"status":"Tous","precision":"Toutes","position":"Tous","search":"","scroll":0,"focus":"ContractReviewReset","sort":"contractEnd","descending":false,"tranche":"","conseil":""}, true)
	app._render(false)

func _sort(key: String) -> void:
	state.descending = not bool(state.descending) if str(state.sort) == key else false
	state.sort = key
	state.scroll = 0
	state.focus = "ContractSort_" + key
	_refresh()
	_restore_focus()

func _refresh() -> void:
	for node in _rows.get_children(): _rows.remove_child(node); node.queue_free()
	for node in _coverage.get_children(): _coverage.remove_child(node); node.queue_free()
	var filters := state.duplicate(true)
	filters.live = not app._live().is_empty()
	filters.ctx = _ctx
	var players := filtered(app.model.get("squad", []), filters)
	_count.text = "%d / %d" % [players.size(), app.model.get("squad", []).size()]
	for key: String in _headers:
		var sort: Button = _headers[key]
		var selected := str(state.sort) == key
		sort.text = str(sort.get_meta("caption")) + (" ▼" if state.descending else " ▲") if selected else str(sort.get_meta("caption")) + " ↕"
		sort.tooltip_text = "Trier par " + str(sort.get_meta("tip")) + (" · ordre décroissant" if selected and state.descending else " · ordre croissant" if selected else "")
		sort.accessibility_name = sort.tooltip_text
	if players.is_empty(): _rows.add_child(_label("Aucun joueur ne correspond. Modifie les filtres ou réinitialise la recherche.", 18, C.MUTED))
	for player: Dictionary in players: call("_row", player)
	var year := int(state.season) if int(state.season) > 0 else int(app.model.get("meta", {}).get("season", 1))
	_coverage.add_child(_label("Échéances par année", 19))
	var horizons: Dictionary = {}
	for player: Dictionary in app.model.get("squad", []):
		var end := horizon(player)
		horizons[end] = int(horizons.get(end, 0)) + 1
	var seasons: Array = horizons.keys()
	seasons.sort()
	for end in seasons:
		_bar(_coverage, "Non renseignée" if int(end) < 0 else "Fin " + G.contract_year(end), int(horizons[end]), app.model.get("squad", []).size(), C.MUTED if int(end) < 0 else ORANGE if int(end) <= year else CITRON if int(end) == year + 1 else VERT, "ContractReviewBar_" + str(end), func(): _ouvrir_fenetre("Non renseignée" if int(end) < 0 else "Fin " + G.contract_year(end), {"season": 0, "precision": "Non renseignée"} if int(end) < 0 else {"season": int(end), "precision": "Toutes"}, C.MUTED if int(end) < 0 else ORANGE if int(end) <= year else CITRON if int(end) == year + 1 else VERT, "ContractReviewBar_" + str(end)))
	_coverage.add_child(_label("Couverture · horizon " + G.contract_year(year), 19, C.IVORY))
	for group: Dictionary in coverage(app.model.get("squad", []), year):
		var button := _button("%s · %d / %d" % [group.position, group.ending, group.total], "ContractReviewCoverage_" + str(group.position).sha256_text().substr(0,16), func():
			state.position = str(group.position)
			state.focus = "ContractReviewCoverage_" + str(group.position).sha256_text().substr(0,16)
			for index in _position.item_count:
				if _position.get_item_text(index) == state.position: _position.select(index)
			_refresh()
			call_deferred("_restore_focus"))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "Filtrer le tableau sur ce poste"
		_coverage.add_child(button)
		var ratio := float(group.remaining) / maxf(1.0, float(group.total))
		var tint := ROUGE if ratio < 0.5 else ORANGE if ratio < 0.75 else VERT
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 8
		progress.max_value = maxf(1, group.total)
		progress.value = group.remaining
		progress.show_percentage = false
		progress.add_theme_stylebox_override("background", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 4, 0))
		progress.add_theme_stylebox_override("fill", C.box(tint, Color.TRANSPARENT, 4, 0))
		_coverage.add_child(progress)
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pill.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.PANNEAU.lerp(tint, 0.16), Color.TRANSPARENT, 12, 3))
		pill.tooltip_text = "%d sous contrat au-delà%s" % [group.remaining, " · %d sans échéance connue" % group.unknown if group.unknown > 0 else ""]
		var pill_text := _label("%d au-delà%s" % [group.remaining, " · %d ?" % group.unknown if group.unknown > 0 else ""], 16, tint)
		pill_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill.add_child(pill_text)
		_coverage.add_child(pill)
	_scroll.set_deferred("scroll_vertical", int(state.scroll))

func _cell(text: String, width: float, color: Color = C.IVORY, font_size: int = 18) -> Label:
	var label := _label(text, font_size, color, width)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	return label

func _reading_cell(content: Control, player: Dictionary, prefix: String, section: String = "") -> Button:
	var player_id := str(player.id)
	var control_id := action_id(prefix, player_id)
	var link := Button.new()
	link.name = control_id
	link.custom_minimum_size = content.get_combined_minimum_size()
	link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	link.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, 2, 0))
	link.set_meta("player_id", player_id)
	link.set_meta("entity_kind", "player")
	link.set_meta("entity_id", player_id)
	link.set_meta("entity_section", section)
	link.accessibility_name = ("Consulter le contrat · " if section == "contract" else "Consulter la fiche · ") + str(player.get("name", "Joueur"))
	link.tooltip_text = link.accessibility_name
	link.pressed.connect(func(): _open_profile(player_id, section, control_id))
	# Tout le contenu (pastille, barre, textes) laisse passer la souris au lien.
	_ignore_mouse(content)
	link.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return link

func _bar(parent: Node, caption: String, value: int, total: int, color: Color, id: String = "", action: Callable = Callable()) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if action.is_valid():
		var link := _link_button(id, row, Color.TRANSPARENT, "%s : %d" % [caption, value], action, Charte.RAYON_PETIT, 4)
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.custom_minimum_size.y = 34
		parent.add_child(link)
	else:
		parent.add_child(row)
	row.add_child(_cell(caption, 142, C.MUTED, 16))
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(140, 12)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.max_value = maxi(total, 1)
	progress.value = value
	progress.show_percentage = false
	progress.add_theme_stylebox_override("fill", C.box(color, Color.TRANSPARENT, 2, 0))
	row.add_child(progress)
	row.add_child(_cell(str(value), 40, color, 18))

## Bouton d'action de ligne : largeur partagée, texte coupé plutôt que débordant, police de table.
func _compact(button: Button, ratio: float) -> void:
	button.custom_minimum_size.x = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = ratio
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 16)

func _find(id: String) -> Dictionary:
	for player: Dictionary in app.model.get("squad", []):
		if str(player.id) == id: return player
	return {}

func _remember(id: String) -> void:
	state.focus = id
	state.scroll = _scroll.scroll_vertical

func _open_wages() -> void:
	app.management_ui["immersive08_finance_tab"] = "wages"
	app._navigate("Finances")

func _open_profile(id: String, section: String = "", control_id: String = "") -> void:
	if _find(id).is_empty(): return
	_remember(control_id if not control_id.is_empty() else action_id("ContractProfile", id))
	app.navigation_controller.open_entity({"kind":"player", "id":id, "section":section})

func _open_quote(id: String) -> void:
	var player := _find(id)
	if player.is_empty() or not app._live().is_empty(): return
	_remember(action_id("ContractRenew", id))
	app.selected_player = id
	app.SquadViews.contract(app, player, false)
	var dialog := app.get_node_or_null("ContractOffer")
	if dialog != null: dialog.tree_exited.connect(func(): call_deferred("_restore_focus"), CONNECT_ONE_SHOT)

func _restore_focus() -> void:
	if not is_inside_tree(): return
	if str(state.get("focus", "")).is_empty(): return
	var control := find_child(str(state.get("focus", "")), true, false) as Control
	if control != null and control.is_visible_in_tree(): control.grab_focus()

## ---- Lignes et compteurs de « Contrats en un coup d'œil » ----

## Compteur ou pastille de filtre : un clic filtre le tableau, un second clic retire le filtre.
func _basculer(cle: String, valeur: String) -> void:
	state[cle] = "" if str(state.get(cle, "")) == valeur else valeur
	state.scroll = 0
	state.focus = ("ContractTranche_" if cle == "tranche" else "ContractConseilFiltre_") + valeur.replace("+", "p")
	app._render(false)

func _compter() -> Dictionary:
	var out := {"tranches": {}, "conseils": {}}
	for p: Dictionary in app.model.get("squad", []):
		var t := tranche(mois_restants(p, str(_ctx.today)))
		out.tranches[t] = int(out.tranches.get(t, 0)) + 1
		var c := conseil(p)
		out.conseils[c] = int(out.conseils.get(c, 0)) + 1
	return out

## Haut de l'onglet : quatre compteurs d'échéance (filtres) et la masse salariale (Finances).
func _haut(top: HBoxContainer, known_wage: float, wage_note: String = "") -> void:
	var n := _compter()
	for t: Array in TRANCHES:
		var id := str(t[0])
		var couleur: Color = t[2]
		var nombre := int(n.tranches.get(id, 0))
		var choisi := str(state.tranche) == id
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 14)
		var rond := C.icon("hourglass", 34, couleur if nombre > 0 else Charte.GRIS_VERT)
		rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(rond)
		var textes := VBoxContainer.new()
		textes.add_theme_constant_override("separation", 0)
		ligne.add_child(textes)
		var chiffre := _label(str(nombre), 34, couleur if nombre > 0 else Charte.GRIS_VERT)
		chiffre.name = "ContractTrancheNombre_" + id.replace("+", "p")
		chiffre.autowrap_mode = TextServer.AUTOWRAP_OFF
		textes.add_child(chiffre)
		var legende := _label(str(t[1]), 16, C.IVORY if choisi else C.MUTED)
		legende.autowrap_mode = TextServer.AUTOWRAP_OFF
		textes.add_child(legende)
		var tuile := _link_button("ContractTranche_" + id.replace("+", "p"), ligne, Charte.PANNEAU.lerp(couleur, 0.26 if choisi else 0.10), "Finit dans %s : %d" % [t[1], nombre], func(): _basculer("tranche", id), Charte.RAYON_CARTE, 14)
		if choisi: tuile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU.lerp(couleur, 0.26), couleur, Charte.RAYON_CARTE, 14))
		tuile.set_meta("choisi", choisi)
		tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tuile)
	var ligne_m := HBoxContainer.new()
	ligne_m.add_theme_constant_override("separation", 14)
	ligne_m.add_child(C.icon("money", 34, BLEU))
	var tm := VBoxContainer.new()
	tm.add_theme_constant_override("separation", 0)
	ligne_m.add_child(tm)
	var vm := _label(G.salary_amount(known_wage), 34, BLEU)
	vm.name = "ContractReviewWage"
	vm.autowrap_mode = TextServer.AUTOWRAP_OFF
	tm.add_child(vm)
	var lm := _label("masse " + G.salary_period(true) + wage_note, 16, C.MUTED)
	lm.autowrap_mode = TextServer.AUTOWRAP_OFF
	tm.add_child(lm)
	var masse := _link_button("ContractReviewStatWages", ligne_m, Charte.PANNEAU.lerp(BLEU, 0.10), "Masse salariale : Finances", func(): _open_wages(), Charte.RAYON_CARTE, 14)
	masse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masse.size_flags_stretch_ratio = 1.2
	top.add_child(masse)
