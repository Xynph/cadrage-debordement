extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")

static func _card(parent: Node, id: String, title: String, height: int, ratio: float = 1.0) -> PanelContainer:
	var frame := C.card(title, Vector2(0, height))
	frame.name = id
	C.fill(frame, true, ratio)
	parent.add_child(frame)
	return frame

static func _link(parent: Node, id: String, text: String, app: Control, route: String, primary: bool = false) -> Button:
	var action := C.button(text, func(): app._navigate(route), primary, app.accent)
	action.name = id
	parent.add_child(action)
	return action

static func _open_player(app: Control, id: String) -> void:
	app.selected_player = id
	app._navigate("Effectif")

static func build(app: Control) -> Control:
	var page := C.v(16)
	page.name = "ImmersiveOffice"
	C.fill(page, true)
	var top := C.h(16)
	page.add_child(top)
	var hero := _card(top, "OfficeFixture", "", 418, 1.56)
	_fixture(hero, app)
	var priorities := _card(top, "OfficeDecisions", "▦  Priorités de la semaine", 418)
	_priorities(C.content(priorities), app)
	var middle := C.h(16)
	page.add_child(middle)
	_group(C.content(_card(middle, "OfficeGroup", "♡  État du groupe", 448, .77)), app)
	_standings(C.content(_card(middle, "OfficeStandings", "♜  Classement · " + P.league_name(app.model), 448, 1.25)), app)
	_journal(C.content(_card(middle, "OfficeJournal", "✉  Dans votre Bureau", 448)), app)
	_recruitment(C.content(_card(middle, "OfficeRecruitment", "⌕  Le profil à suivre", 448)), app)
	_timeline(C.content(_card(page, "OfficeTimeline", "▦  Le fil de votre saison", 226)), app)
	return page

static func _fixture(frame: PanelContainer, app: Control) -> void:
	frame.clip_contents = true
	var backdrop := Control.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(backdrop)
	frame.move_child(backdrop, 0)
	var image := C.photo("office-hero")
	backdrop.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.anchor_left = .51
	C.veil(backdrop)
	var row := C.h(0)
	C.fill(row, true)
	C.content(frame).add_child(row)
	var left := C.v(8)
	C.fill(left, true, 1.1)
	row.add_child(left)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(space, false, 1.0)
	row.add_child(space)
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	if next.is_empty():
		left.add_child(C.label("LE PROCHAIN CHAPITRE", 21, C.GOLD))
		left.add_child(C.wrap("La saison se termine." if app.model.meta.get("canAdvanceSeason", false) else "Le travail continue.", 42, C.IVORY, true))
		left.add_child(C.wrap("Retrouvez les résultats et préparez la suite du projet.", 20))
	else:
		var tags := C.h(12)
		left.add_child(tags)
		tags.add_child(C.chip(str(next.get("label", "Prochain match")), C.MINT))
		var location: String = "NEUTRE" if next.get("neutral", false) else "À DOMICILE" if next.get("home", {}).get("id") == app.model.club.id else "À L’EXTÉRIEUR"
		tags.add_child(C.chip(location, C.GOLD))
		var teams := C.h(16)
		left.add_child(teams)
		teams.add_child(G.crest(next.get("home", {}), C.px(82)))
		teams.add_child(C.label("VS", 23, C.GOLD))
		teams.add_child(G.crest(next.get("away", {}), C.px(82)))
		var names := C.v(2)
		C.fill(names)
		teams.add_child(names)
		names.add_child(C.wrap(G.club_name(next.get("home", {})), 32, C.IVORY, true))
		names.add_child(C.wrap(G.club_name(next.get("away", {})), 30, C.IVORY, true))
		left.add_child(C.label("SEMAINE %d  ·  %s" % [int(next.get("week", 0))+1, P.league_name(app.model)], 25))
		var venue: Dictionary = next.get("home", {})
		left.add_child(C.wrap("Terrain neutre" if next.get("neutral", false) else str(G.identity(venue).get("stadium", venue.get("stadium", ""))), 18))
		left.add_child(C.wrap("Préparez votre XV et confirmez vos choix de jeu.", 19))
	var spacer := Control.new()
	C.fill(spacer, true)
	left.add_child(spacer)
	var actions := C.h(12)
	left.add_child(actions)
	C.fill(_link(actions, "OfficePreparationAction", "PRÉPARER LE MATCH  →", app, "Préparation", true))
	C.fill(_link(actions, "OfficeSelectionAction", "Vérifier les 23", app, "Composition"))

static func _priorities(parent: VBoxContainer, app: Control) -> void:
	var contracts := P.contracts(app.model)
	var choices: Array = []
	if not contracts.is_empty():
		var first: Dictionary = contracts[0]
		choices.append({"title":"%d contrats à préparer" % contracts.size(), "detail":str(first.get("name", "")) + " · " + str(first.get("contractLabel", "Échéance à examiner")), "action":func(): _open_player(app, str(first.id)), "id":"OfficeContractsAction"})
	var training: Dictionary = app.model.get("decisions", {}).get("training", {})
	choices.append({"title":"Préparer l’entraînement" if not app.model.meta.get("trained", false) else "La préparation est effectuée", "detail":str(training.get("advice", "Consultez les choix et la charge du groupe.")), "action":func(): app._navigate("Préparation"), "id":"OfficeTrainingAction"})
	var selection: Dictionary = app.model.get("selection", {})
	var valid: bool = selection.get("valid", false)
	choices.append({"title":"Examiner le recrutement" if valid else "Compléter la feuille de match", "detail":"%d profils disponibles dans votre réseau." % app.model.get("market", []).size() if valid else "Les postes vacants ou indisponibles demandent votre attention.", "action":func(): app._navigate("Recrutement" if valid else "Composition"), "id":"OfficeRecruitmentAction"})
	if choices.size() < 3: choices.append({"title":"Retrouver les décisions du club", "detail":"Staff, direction et vie du groupe.", "action":func(): app._navigate("Travail du club"), "id":"OfficeSupportAction"})
	for i in mini(3, choices.size()):
		var choice: Dictionary = choices[i]
		var tile := C.card()
		tile.add_theme_stylebox_override("panel", C.box(C.RAISED if i == 0 else C.PANEL, Color.TRANSPARENT, 5, 10))
		parent.add_child(tile)
		var line := C.h(12)
		C.content(tile).add_child(line)
		line.add_child(C.chip(str(i+1), C.MINT))
		var text := C.v(2)
		C.fill(text)
		line.add_child(text)
		var action := C.button(choice.title + "  →", choice.action)
		action.name = choice.id
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action.clip_text = true
		action.custom_minimum_size.y = C.px(34)
		action.tooltip_text = choice.title + "\n" + choice.detail
		action.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		text.add_child(action)
		var detail := C.label(choice.detail, 17, C.MUTED, false)
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(detail)

static func _group(parent: VBoxContainer, app: Control) -> void:
	var group := P.group(app.model)
	var counts := C.h(20)
	parent.add_child(counts)
	for pair in [[group.available, "disponibles", C.MINT], [group.injured, "blessés", C.ALERT]]:
		var col := C.h(10)
		C.fill(col)
		counts.add_child(col)
		col.add_child(C.label(pair[0], 58, pair[2]))
		col.add_child(C.label(pair[1], 23))
	parent.add_child(C.rule())
	for pair in [["Condition physique", group.condition, C.MINT], ["Moral du groupe", app.model.meta.get("morale", 0), C.GOLD]]:
		var caption := C.h(5)
		parent.add_child(caption)
		var name := C.label(pair[0], 22, C.MUTED)
		C.fill(name)
		caption.add_child(name)
		caption.add_child(C.label(str(int(pair[1])) + " %", 24, pair[2]))
		parent.add_child(C.gauge(float(pair[1]), pair[2]))
	parent.add_child(C.rule())
	parent.add_child(C.wrap("⚠  %d joueur%s sous surveillance" % [group.watched, "s" if group.watched > 1 else ""], 22, C.AMBER, true))
	_link(parent, "OfficeSquadAction", "Consulter le groupe  →", app, "Effectif")

static func _standings(parent: VBoxContainer, app: Control) -> void:
	var rows := P.standings(app.model)
	var header := C.h(8)
	parent.add_child(header)
	for pair in [["#", 30], ["CLUB", 0], ["J", 36], ["DIFF.", 55], ["PTS", 40]]:
		var caption := C.label(pair[0], 18, C.MUTED)
		if pair[1] == 0: C.fill(caption)
		else: caption.custom_minimum_size.x = C.px(pair[1])
		header.add_child(caption)
	for club: Dictionary in rows:
		var tile := PanelContainer.new()
		var own: bool = club.get("id") == app.model.club.id
		tile.add_theme_stylebox_override("panel", C.box(Color(app.accent, .22) if own else Color.TRANSPARENT, Color.TRANSPARENT, 3, 4))
		parent.add_child(tile)
		var row := C.h(8)
		tile.add_child(row)
		var values: Array = [G.n(club.get("rank", "—")), G.club_name(club), G.n(club.get("played", 0)), "%+d" % (int(club.get("pf", 0))-int(club.get("pa", 0))), G.n(club.get("points", 0))]
		for i in values.size():
			var cell := C.label(values[i], 23, C.MINT if own else C.IVORY)
			if i == 1:
				C.fill(cell)
				cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			else: cell.custom_minimum_size.x = C.px([30, 0, 36, 55, 40][i])
			row.add_child(cell)
	if rows.is_empty(): parent.add_child(C.wrap("Le classement sera disponible lorsque le championnat sera ouvert.", 20))
	_link(parent, "OfficeStandingsAction", "Classement complet  →", app, "Classements")

static func _journal(parent: VBoxContainer, app: Control) -> void:
	var messages: Array = app.model.get("messages", [])
	if messages.is_empty(): parent.add_child(C.wrap("Les nouvelles de votre carrière apparaîtront ici.", 21))
	for index in mini(3, messages.size()):
		parent.add_child(C.label("CARRIÈRE  ·  ÉVÉNEMENT %02d" % (index+1), 18, [C.BLUE, C.ALERT, C.GOLD][index]))
		var note := C.wrap(str(messages[index]).replace("l’onglet Contrats", "les fiches joueurs"), 19)
		note.max_lines_visible = 3
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		parent.add_child(note)
		if index < 2: parent.add_child(C.rule())

static func _recruitment(parent: VBoxContainer, app: Control) -> void:
	var market: Array = app.model.get("market", []).duplicate()
	market.sort_custom(func(first: Dictionary, second: Dictionary): return float(first.get("rating", 0)) > float(second.get("rating", 0)))
	if market.is_empty():
		parent.add_child(C.photo("scouting", Vector2(0, 150)))
		parent.add_child(C.wrap("Votre réseau prépare les prochaines opportunités.", 23, C.IVORY, true))
	else:
		var player: Dictionary = market[0]
		var row := C.h(14)
		parent.add_child(row)
		row.add_child(G.portrait(int(player.get("portraitIndex", 0)), C.px(125), player) if not str(player.get("portraitPath", "")).is_empty() else C.photo("recruit-profile", Vector2(125, 125)))
		var identity := C.v(6)
		C.fill(identity)
		row.add_child(identity)
		identity.add_child(C.wrap(player.get("name", "Profil à examiner"), 30, C.IVORY, true))
		identity.add_child(C.wrap(str(player.get("pos", "")) + " · " + G.n(player.get("age", "—")) + " ans", 20))
		identity.add_child(C.chip("NIVEAU  " + G.n(player.get("rating", "—"))))
		parent.add_child(C.wrap(G.euros(player.get("fee", 0)) + " · " + G.euros(player.get("salary", 0)) + " / sem.", 24, C.IVORY, true))
		parent.add_child(C.wrap(player.get("reason", "Consultez les disponibilités et les modalités avant une offre."), 18))
	_link(parent, "OfficeMarketAction", "Lire le dossier complet  →", app, "Recrutement")

static func _timeline(parent: VBoxContainer, app: Control) -> void:
	var row := C.h(12)
	parent.add_child(row)
	var fixtures := P.upcoming(app.model)
	if fixtures.is_empty():
		parent.add_child(C.wrap("Aucune rencontre programmée. Retrouvez les résultats dans le calendrier.", 21))
	for fixture: Dictionary in fixtures:
		var tile := C.card()
		C.fill(tile)
		row.add_child(tile)
		var list := C.content(tile)
		list.add_theme_constant_override("separation", C.px(4))
		list.add_child(C.label("SEM. %02d" % (int(fixture.get("week", 0))+1), 21, C.GOLD))
		list.add_child(C.rule())
		var opponent: Dictionary = fixture.get("away", {}) if fixture.get("home", {}).get("id") == app.model.club.id else fixture.get("home", {})
		var name := C.label(G.club_name(opponent), 24)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		list.add_child(name)
		list.add_child(C.label(str(fixture.get("label", "Rencontre")), 19, C.MUTED))
	var action := _link(parent, "OfficeCalendarAction", "Tout le calendrier  →", app, "Calendrier")
	var title: Label = parent.find_child("CardTitle", true, false)
	parent.remove_child(title)
	parent.remove_child(action)
	var heading := C.h(12)
	parent.add_child(heading)
	parent.move_child(heading, 0)
	C.fill(title)
	heading.add_child(title)
	heading.add_child(action)
	action.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	action.add_theme_font_size_override("font_size", C.px(21))
	action.custom_minimum_size.y = C.px(30)
	action.size_flags_horizontal = Control.SIZE_SHRINK_END
