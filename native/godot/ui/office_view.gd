extends RefCounted
# Présentation du Bureau uniquement : aucune commande de carrière à l'affichage.
const G = preload("res://ui/game_skin.gd")
const PAPER = Color("f3eddf")
const INK = Color("242321")
const MUTED = Color("746d63")
const CHARCOAL = Color("191b1c")
const RULE = Color("d5caba")

static func _text(value: Variant, size: int = 14, color: Color = INK, title: bool = false) -> Label:
	var label := G.wrap(value, size, color)
	if title: label.add_theme_font_override("font", G.T.DISPLAY)
	return label

static func _line(parent: Node, light: bool = true) -> void:
	var line := HSeparator.new()
	line.modulate = RULE if light else Color("494943")
	parent.add_child(line)

static func _panel(parent: Node, color: Color, padding: int = 16) -> VBoxContainer:
	var frame := PanelContainer.new()
	G.fill(frame, true)
	var style := G.T.box(color, 2)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)
	var list := G.v(10)
	frame.add_child(list)
	return list

static func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	G.fill(scroll, true)
	parent.add_child(scroll)
	var column := G.v(12)
	G.fill(column)
	scroll.add_child(column)
	return column

static func _heading(parent: Node, number: String, text: String, accent: Color) -> void:
	var row := G.h(8)
	parent.add_child(row)
	row.add_child(G.label(number + " /", 29, accent.darkened(.12), true))
	var heading := _text(text, 29, INK, true)
	G.fill(heading)
	row.add_child(heading)

static func _link(text: String, callback: Callable, accent: Color, paper: bool = true) -> Button:
	var button := G.button(text, callback)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size.y = 38
	var style := G.T.box(Color.TRANSPARENT, 2)
	style.content_margin_left = 0
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", G.T.box(Color(accent, .12), 2))
	button.add_theme_stylebox_override("pressed", G.T.box(Color(accent, .2), 2))
	button.add_theme_stylebox_override("focus", G.T.box(Color.TRANSPARENT, 2, accent.lightened(.2)))
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, accent.darkened(.18) if paper else G.INK)
	return button

static func _navigate(app: Control, route: String) -> void:
	app._navigate(route)

static func _player(app: Control, id: String) -> void:
	app.selected_player = id
	app._navigate("Effectif")

static func _decision(parent: Node, title: String, detail: String, callback: Callable, accent: Color, id: String) -> void:
	var box := G.v(3)
	box.name = id
	parent.add_child(box)
	box.add_child(_text(title, 25, INK, true))
	box.add_child(_text(detail, 14))
	var action := _link("Examiner  →", callback, accent)
	action.name = id + "Action"
	box.add_child(action)
	_line(parent)

static func _journal(parent: Node, app: Control) -> void:
	var block := G.v(10)
	block.name = "OfficeJournal"
	parent.add_child(block)
	block.add_child(_text("Le journal du club", 26, INK, true))
	block.add_child(_text("Les nouvelles de votre carrière", 12, MUTED))
	var messages: Array = app.model.get("messages", [])
	if messages.is_empty(): block.add_child(_text("Le carnet s'ouvre. Les premières nouvelles du club apparaîtront ici.", 14))
	for index in mini(5, messages.size()):
		var row := G.h(9)
		block.add_child(row)
		row.add_child(G.label("•", 20, app.accent))
		var text := str(messages[index]).replace("l’onglet Contrats", "les fiches des joueurs dans Effectif").replace("l'onglet Contrats", "les fiches des joueurs dans Effectif")
		var note := _text(text, 14)
		G.fill(note)
		row.add_child(note)
		_line(block)

static func _decisions(parent: Node, app: Control) -> void:
	parent.name = "OfficeDecisions"
	_heading(parent, "01", "À décider", app.accent)
	_line(parent)
	var model: Dictionary = app.model
	var contracts: Array = []
	for p: Dictionary in model.get("squad", []):
		if p.get("contractEnd") != null and int(p.contractEnd) <= int(model.meta.get("season", 1)) + 1:
			contracts.append(p)
	if not contracts.is_empty():
		var first: Dictionary = contracts[0]
		_decision(parent, "%d contrat%s à préparer" % [contracts.size(), "s" if contracts.size() > 1 else ""], "Échéances d’ici la saison %s. Consultez les contrats et les possibilités de prolongation." % G.n(int(model.meta.get("season", 1)) + 1), func(): _player(app, str(first.id)), app.accent, "OfficeContracts")
	var selection: Dictionary = model.get("selection", {})
	var vacant := 0
	for slot: Dictionary in selection.get("slots", []):
		if slot.get("playerId") == null: vacant += 1
	var errors: Array = selection.get("errors", [])
	if vacant > 0 or not errors.is_empty():
		_decision(parent, "%d poste%s à couvrir" % [vacant, "s" if vacant > 1 else ""] if vacant > 0 else "La feuille à vérifier", str(errors[0]) if not errors.is_empty() else "Complétez la sélection avant la rencontre.", func(): _navigate(app, "Composition"), app.accent, "OfficeSelection")
	if not model.meta.get("trained", false) and model.get("live") == null and not model.meta.get("canAdvanceSeason", false):
		_decision(parent, "La semaine à préparer", "L'entraînement de cette semaine reste à effectuer. Choisissez le travail du groupe.", func(): _navigate(app, "Préparation"), app.accent, "OfficeTraining")
	elif contracts.is_empty() and vacant == 0 and errors.is_empty():
		parent.add_child(_text("Le groupe est en ordre", 25, INK, true))
		parent.add_child(_text("Retrouvez vos choix de sélection et la préparation de la prochaine rencontre.", 14))
		parent.add_child(_link("Voir la composition  →", func(): _navigate(app, "Composition"), app.accent))
	var next: Dictionary = model.next if model.get("next") is Dictionary else {}
	if not next.is_empty():
		parent.add_child(_text("Le prochain rendez-vous", 22, INK, true))
		parent.add_child(_text(str(next.get("label", model.meta.get("roundLabel", ""))), 13, MUTED))
		parent.add_child(_link("Ouvrir le calendrier  →", func(): _navigate(app, "Calendrier"), app.accent))
	_line(parent)
	_journal(parent, app)

static func _summary(parent: Node, app: Control) -> void:
	var row := G.h(16)
	row.name = "OfficeSummary"
	parent.add_child(row)
	var club := G.h(8)
	G.fill(club, false, 1.4)
	row.add_child(club)
	club.add_child(G.crest(app.model.club, 42))
	var name := _text(G.club_name(app.model.club), 23, G.INK, true)
	G.fill(name)
	club.add_child(name)
	var total := 0.0
	var injured := 0
	var squad: Array = app.model.get("squad", [])
	for player: Dictionary in squad:
		total += float(player.get("condition", 0))
		if float(player.get("injury", 0)) > 0: injured += 1
	for pair in [["%se / %s pts" % [G.n(app.model.club.get("rank", "—")), G.n(app.model.club.get("points", 0))], "Classement"], ["%d %%" % (total / maxf(1, squad.size())), "Condition du groupe"], [str(injured), "Blessés"], [G.n(app.model.meta.get("trust", "—")) + " %", "Confiance"], [G.euros(app.model.get("finance", {}).get("cash", app.model.club.get("cash", 0))), "Trésorerie fictive"]]:
		var box := G.v(0)
		G.fill(box)
		row.add_child(box)
		box.add_child(_text(pair[0], 23, G.INK, true))
		box.add_child(_text(pair[1], 12, G.MUTED))

static func _fixture(parent: Node, app: Control) -> void:
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	var neutral: bool = next.get("neutral", false)
	var venue: Dictionary = app.model.club if neutral else next.get("home", app.model.club)
	var picture := G.picture(str(G.identity(venue).get("slug", "toulouse")), "city" if neutral else "stadium")
	picture.name = "OfficeFixture"
	picture.custom_minimum_size.y = 250 if next.is_empty() or (G.club_name(next.home) + G.club_name(next.away)).length() < 75 else 330
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, .22)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.add_child(veil)
	picture.move_child(veil, picture.get_child_count() - 2)
	parent.add_child(picture)
	var over: VBoxContainer = picture.get_meta("content")
	over.add_theme_constant_override("separation", 5)
	for edge in ["left", "right", "top", "bottom"]:
		over.get_parent().add_theme_constant_override("margin_" + edge, 16)
	over.add_child(G.label("LE PROCHAIN RENDEZ-VOUS", 12, G.GOLD))
	if not next.is_empty():
		var crests := G.h(12)
		over.add_child(crests)
		crests.add_child(G.crest(next.home, 40))
		crests.add_child(G.label("vs", 21, G.INK, true))
		crests.add_child(G.crest(next.away, 40))
		over.add_child(_text(next.get("label", ""), 13, G.GOLD))
		over.add_child(_text(G.club_name(next.home) + " — " + G.club_name(next.away), 30, G.INK, true))
		var caption: String = "Terrain neutre · enceinte générique\nTerritoire du club · " + str(G.identity(venue).get("city", "")) if neutral else str(G.identity(venue).get("stadium", venue.get("stadium", "")))
		over.add_child(_text(caption, 12, G.INK))
	else:
		over.add_child(_text("La saison se termine" if app.model.meta.get("canAdvanceSeason", false) else "Le travail continue", 34, G.INK, true))
		over.add_child(_text("Retrouvez les résultats et préparez la suite du projet.", 14, G.INK))
	var action := G.button(app.primary_text(), app.primary_action, true)
	action.name = "OfficePrimaryAction"
	action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# The global primary action owns live-match, interseason and pending-command guards.
	over.add_child(action)

static func _timeline(parent: Node, app: Control) -> void:
	var block := G.v(7)
	block.name = "OfficeTimeline"
	parent.add_child(block)
	var header := G.h(6)
	block.add_child(header)
	var title := _text("La suite de la saison", 25, G.INK, true)
	G.fill(title)
	header.add_child(title)
	var link := _link("Calendrier  →", func(): _navigate(app, "Calendrier"), app.accent, false)
	link.name = "OfficeCalendarAction"
	header.add_child(link)
	var fixtures: Array = []
	for fixture: Dictionary in app.model.get("calendar", []):
		if not fixture.get("played", false) and int(fixture.get("week", 0)) >= int(app.model.meta.get("week", 0)): fixtures.append(fixture)
	fixtures.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("week", 0)) < int(b.get("week", 0)))
	if fixtures.is_empty():
		block.add_child(_text("Aucune rencontre programmée pour le moment.", 13, G.MUTED))
		return
	var row := G.h(10)
	block.add_child(row)
	for fixture: Dictionary in fixtures.slice(0, 4):
		var tile := G.v(3)
		G.fill(tile)
		row.add_child(tile)
		tile.add_child(_text("Sem. " + str(int(fixture.get("week", 0)) + 1), 12, G.GOLD))
		var opponent: Dictionary = fixture.away if fixture.home.id == app.model.club.id else fixture.home
		var side := G.h(5)
		tile.add_child(side)
		side.add_child(G.crest(opponent, 30))
		var name := _text(G.club_name(opponent), 14, G.INK, true)
		G.fill(name)
		side.add_child(name)
		tile.add_child(_text("Neutre" if fixture.get("neutral", false) else "Domicile" if fixture.home.id == app.model.club.id else "Extérieur", 12, G.MUTED))

static func _group(parent: Node, app: Control) -> void:
	var block := _panel(parent, Color("202222"), 12)
	block.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	block.name = "OfficeGroup"
	block.add_theme_constant_override("separation", 2)
	var top := G.h(8)
	block.add_child(top)
	var title := _text("Le groupe", 25, G.INK, true)
	G.fill(title)
	top.add_child(title)
	var action := _link("Effectif  →", func(): _navigate(app, "Effectif"), app.accent, false)
	action.name = "OfficeSquadAction"
	top.add_child(action)
	var chosen: Array = []
	var squad: Array = app.model.get("squad", [])
	for id in app.model.get("lineup", []):
		for player: Dictionary in squad:
			if player.id == id and chosen.size() < 5: chosen.append(player)
	for player: Dictionary in squad:
		if chosen.size() < 5 and not chosen.has(player): chosen.append(player)
	for player: Dictionary in chosen:
		var row := G.h(8)
		block.add_child(row)
		var profile := _link(str(player.name) + "  ↗", func(): _player(app, str(player.id)), app.accent, false)
		profile.name = "OfficePlayer" + str(chosen.find(player))
		profile.set_meta("player_id", str(player.id))
		profile.custom_minimum_size.y = 25
		profile.add_theme_font_size_override("font_size", 14)
		profile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		G.fill(profile, false, 1.4)
		row.add_child(profile)
		var position := _text(player.get("pos", ""), 13, G.MUTED)
		G.fill(position)
		row.add_child(position)
		row.add_child(G.label("%d %%" % float(player.get("condition", 0)), 13, G.INK))
		var bar := ProgressBar.new()
		bar.min_value = 0; bar.max_value = 100; bar.value = float(player.get("condition", 0)); bar.show_percentage = false
		bar.custom_minimum_size = Vector2(44, 6)
		for kind in ["background", "fill"]:
			var style := G.T.box(Color("445249") if kind == "background" else Color("9bc69e"), 3)
			style.content_margin_left = 0; style.content_margin_right = 0
			style.content_margin_top = 0; style.content_margin_bottom = 0
			bar.add_theme_stylebox_override(kind, style)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var health := _text("Blessé" if float(player.get("injury", 0)) > 0 else "Disponible", 12, G.MUTED)
		health.custom_minimum_size.x = 63
		row.add_child(health)
	var injured := 0
	for player: Dictionary in squad:
		if float(player.get("injury", 0)) > 0: injured += 1
	block.add_child(_text("Infirmerie · %d joueur%s blessé%s" % [injured, "s" if injured > 1 else "", "s" if injured > 1 else ""], 12, G.GOLD))

static func _results(parent: Node, app: Control) -> void:
	var block := G.v(6)
	block.name = "OfficeResults"
	parent.add_child(block)
	_line(block, false)
	block.add_child(_text("Derniers résultats", 24, G.INK, true))
	var results: Array = []
	for fixture: Dictionary in app.model.get("calendar", []):
		if fixture.get("played", false) and fixture.get("score") is Array: results.append(fixture)
	results.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("week", 0)) > int(b.get("week", 0)))
	if results.is_empty(): block.add_child(_text("La première page reste à écrire. Aucun match joué.", 13, G.MUTED))
	var row := G.h(10)
	block.add_child(row)
	for result: Dictionary in results.slice(0, 3):
		var own_home: bool = result.home.id == app.model.club.id
		var score: Array = result.score
		var own: float = float(score[0] if own_home else score[1])
		var other: float = float(score[1] if own_home else score[0])
		var tile := G.v(3)
		G.fill(tile)
		row.add_child(tile)
		var opponent: Dictionary = result.away if own_home else result.home
		tile.add_child(_text(("V" if own > other else "D" if own < other else "N") + "  " + G.n(own) + " — " + G.n(other), 18, G.GOOD if own > other else Color("e4ae9c") if own < other else G.GOLD, true))
		tile.add_child(_text(G.club_name(opponent), 12, G.INK))
		tile.add_child(_text(str(result.get("label", "")), 12, G.MUTED))

# The projection already ranks these rows, including competition tie-breakers.
static func standings_window(model: Dictionary) -> Array:
	var rows: Array = model.get("league", [])
	for league: Dictionary in model.get("leagues", []):
		if str(league.get("id", "")) == str(model.meta.get("leagueId", "elite")): rows = league.get("rows", [])
	var index := 0
	for i in rows.size():
		if rows[i].id == model.club.id: index = i; break
	var start := clampi(index - 3, 0, maxi(0, rows.size() - 8))
	return rows.slice(start, mini(start + 8, rows.size()))

static func _table(parent: Node, app: Control) -> void:
	parent.name = "OfficeStandings"
	_heading(parent, "02", "Le cap sportif", app.accent)
	parent.add_child(_link("Classement complet  →", func(): _navigate(app, "Classements"), app.accent))
	parent.get_child(parent.get_child_count()-1).name = "OfficeStandingsAction"
	var objective := G.v(2)
	parent.add_child(objective)
	objective.add_child(_text("OBJECTIF DU CLUB", 12, MUTED))
	objective.add_child(_text(app.model.club.get("goal", "Développer le club"), 17, app.accent, true))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 0)
	parent.add_child(grid)
	for text in ["#", "Club", "J", "V", "N", "Pts"]:
		grid.add_child(G.label(text, 12, MUTED))
	for club: Dictionary in standings_window(app.model):
		var ours: bool = club.id == app.model.club.id
		for value in [G.n(club.get("rank", "")), G.club_name(club), G.n(club.get("played", 0)), G.n(club.get("won", 0)), G.n(club.get("drawn", 0)), G.n(club.get("points", 0))]:
			var cell := PanelContainer.new()
			var style := G.T.box(app.accent if ours else Color.TRANSPARENT, 0)
			style.content_margin_left = 3; style.content_margin_right = 3
			style.content_margin_top = 4; style.content_margin_bottom = 4
			cell.add_theme_stylebox_override("panel", style)
			grid.add_child(cell)
			var label := G.label(value, 14, G.INK if ours else INK)
			if cell.get_index() % 6 == 1:
				G.fill(cell)
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				cell.custom_minimum_size.x = 80
				cell.tooltip_text = value
			cell.add_child(label)
	var form: Array = []
	for club: Dictionary in standings_window(app.model):
		if club.id == app.model.club.id: form = club.get("form", [])
	parent.add_child(_text("Forme · " + (" / ".join(form.slice(maxi(0, form.size() - 5))) if not form.is_empty() else "aucun match joué"), 12, MUTED))

static func _means(parent: Node, app: Control) -> void:
	var box := _panel(parent, CHARCOAL, 12)
	box.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.name = "OfficeMeans"
	box.add_child(_text("Confiance & moyens", 25, G.INK, true))
	var row := G.h(10)
	box.add_child(row)
	for pair in [[G.n(app.model.meta.get("trust", "—")) + " %", "Confiance"], [G.euros(app.model.get("finance", {}).get("cash", app.model.club.get("cash", 0))), "Trésorerie"], [G.euros(app.model.get("finance", {}).get("wage", 0)), "Salaires / sem."]]:
		var metric := G.v(2)
		G.fill(metric)
		row.add_child(metric)
		metric.add_child(_text(pair[0], 20, G.INK, true))
		metric.add_child(_text(pair[1], 12, G.MUTED))
	box.add_child(_text("Montants fictifs de votre carrière.", 12, G.MUTED))
	var button := _link("Voir les finances  →", func(): _navigate(app, "Finances"), app.accent, false)
	button.name = "OfficeFinanceAction"
	box.add_child(button)

static func _preparation(parent: Node, app: Control) -> void:
	var box := G.v(5)
	box.name = "OfficePreparation"
	parent.add_child(box)
	box.add_child(_text("Préparation", 26, INK, true))
	var selected := 0
	for slot: Dictionary in app.model.get("selection", {}).get("slots", []):
		if slot.get("playerId") != null: selected += 1
	box.add_child(_text("Sélection  %d / %d" % [selected, app.model.get("selection", {}).get("slots", []).size()], 16, INK, true))
	var preparation_state := "Saison terminée · bilan du groupe" if app.model.meta.get("canAdvanceSeason", false) else "Match en cours" if app.model.get("live") is Dictionary else "Entraînement effectué" if app.model.meta.get("trained", false) else "Entraînement à effectuer"
	box.add_child(_text(preparation_state, 13, MUTED))
	var tactics: Dictionary = app.model.get("tactics", {})
	var attack: String = str(tactics.get("attack", ""))
	for option: Dictionary in tactics.get("attacks", []):
		if option.id == attack: box.add_child(_text("Jeu · " + str(option.label), 13, MUTED))
	var button := _link("Ajuster la préparation  →", func(): _navigate(app, "Préparation"), app.accent)
	button.name = "OfficePreparationAction"
	box.add_child(button)

static func build(app: Control) -> Control:
	var page := G.v(12)
	page.name = "OfficeCarnet"
	G.fill(page, true)
	_summary(page, app)
	_line(page, false)
	var columns := G.h(12)
	G.fill(columns, true)
	page.add_child(columns)
	var journal := _panel(columns, PAPER, 16)
	journal.get_parent().size_flags_stretch_ratio = .85
	var journal_body := _scroll(journal)
	_decisions(journal_body, app)
	var center := G.v(10)
	G.fill(center, true, 1.88)
	columns.add_child(center)
	var center_body := _scroll(center)
	_fixture(center_body, app)
	_timeline(center_body, app)
	_group(center_body, app)
	_results(center_body, app)
	var sport := _panel(columns, PAPER, 14)
	sport.get_parent().size_flags_stretch_ratio = 1.07
	var sport_body := _scroll(sport)
	sport_body.add_theme_constant_override("separation", 7)
	_table(sport_body, app)
	_line(sport_body)
	_means(sport_body, app)
	_preparation(sport_body, app)
	return page
