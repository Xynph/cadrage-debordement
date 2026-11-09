extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const S = preload("res://ui/data_semantics.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")

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

static func open_notebook(app: Control) -> void:
	preload("res://ui/coach_notes_view.gd").open(app, "career")

static func territory_art(club: Dictionary) -> VBoxContainer:
	var identity := G.identity(club)
	var photos: Dictionary = identity.get("photos", {})
	if photos.is_empty(): return null
	var cards := C.v(6)
	cards.name = "OfficeTerritoryPreviews"
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for info in [["city","VILLE DU CLUB","OfficeCityPreview"],["stadium","STADE DU CLUB","OfficeStadiumPreview"]]:
		var kind: String = info[0]
		var photo: Dictionary = photos.get(kind, {})
		if photo.is_empty(): continue
		var picture := G.picture(str(identity.get("slug", "")),kind,true,str(photo.get("path", "")))
		if not picture.get_meta("photo_from_pack", false):
			picture.free()
			continue
		picture.name = info[2]
		picture.custom_minimum_size = Vector2.ZERO
		C.fill(picture, true)
		cards.add_child(picture)
		var content: VBoxContainer = picture.get_meta("content")
		content.add_theme_constant_override("separation", C.px(3))
		content.add_child(G.spacer())
		var title := C.label(info[1] + " · " + str(identity.get(kind, "—")), 20, C.IVORY, true, 700)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(title)
		var credit := C.label(photo.get("credit", ""), 17, C.MUTED)
		credit.name = "OfficePhotoCredit"
		credit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(credit)
		describe_fixture(credit, "\n".join([title.text, credit.text, str(photo.get("source", "")), str(photo.get("license", ""))]))
	if cards.get_child_count() > 0: return cards
	cards.free()
	return null

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
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var territory := territory_art(app.model.club)
	if territory == null:
		var backdrop := Control.new()
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(backdrop)
		frame.move_child(backdrop, 0)
		var ground := P.fixture_ground(app.model.meta,"office-hero")
		var image := C.photo(ground,Vector2.ZERO,true,.53 if ground != "office-hero" else 0.0)
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
	if territory != null:
		C.fill(territory, true)
		row.add_child(territory)
	else:
		var space := Control.new()
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(space)
		row.add_child(space)
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	var preparation := SeasonPreparation.data(app.model.meta)
	if next.is_empty():
		var upcoming := P.next_nationale_fixture(app.model)
		if not upcoming.is_empty():
			left.add_child(C.label("NATIONALE", 21, C.GOLD))
			left.add_child(C.wrap("Pas de match cette semaine.", 42, C.IVORY, true))
			left.add_child(C.wrap("Prochain match · " + P.fixture_date(upcoming), 25, C.IVORY, true))
			left.add_child(C.wrap(P.fixture_venue(upcoming), 18))
		elif preparation.is_empty():
			left.add_child(C.label("LE PROCHAIN CHAPITRE", 21, C.GOLD))
			left.add_child(C.wrap("La saison se termine." if app.model.meta.get("canAdvanceSeason", false) else "Le travail continue.", 42, C.IVORY, true))
			left.add_child(C.wrap("Retrouvez les résultats et préparez la suite du projet.", 20))
		elif SeasonPreparation.is_champ(app.model.meta):
			var fixture := P.next_scheduled_fixture(app.model)
			left.add_child(C.wrap("Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))), 42, C.IVORY, true))
			left.add_child(C.wrap(P.fixture_date(fixture, true) if not fixture.is_empty() else World.preparation_note(preparation), 25, C.IVORY, true))
			left.add_child(C.wrap(P.fixture_venue(fixture), 18))
		else:
			left.add_child(C.label(World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))).to_upper(),21,C.GOLD))
			left.add_child(C.wrap("Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))),42,C.IVORY,true))
			left.add_child(C.wrap(World.preparation_note(preparation),20))
	else:
		var tags := C.h(12)
		left.add_child(tags)
		var match_label := str(next.get("label", "Prochain match"))
		var competition := C.chip(short_fixture_label(app.model,next) if japan else match_label,C.MINT)
		if japan: describe_fixture(competition,match_label)
		tags.add_child(competition)
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
		var date := P.fixture_date(next, true)
		if date.is_empty(): date = "SEMAINE %d" % [int(next.get("week",0))+1]
		var timing := C.wrap(date+" · "+fixture_competition(app.model,next),25,C.IVORY,true)
		timing.name="OfficeFixtureDate"
		left.add_child(timing)
		var venue_name := P.fixture_venue(next,false)
		if not venue_name.is_empty():
			var venue := C.wrap(venue_name,18)
			venue.name="OfficeFixtureVenue"
			left.add_child(venue)
		left.add_child(C.wrap("Préparez votre XV et confirmez vos choix de jeu.", 19))
	var spacer := Control.new()
	C.fill(spacer, true)
	left.add_child(spacer)
	var actions := C.h(12)
	left.add_child(actions)
	if next.is_empty():
		var primary := C.button(app.primary_text(),app.primary_action,true,app.accent)
		primary.name="OfficePreparationAction"
		actions.add_child(primary)
		C.fill(primary)
	else: C.fill(_link(actions, "OfficePreparationAction", "PRÉPARER LE MATCH  →", app, "Préparation", true))
	C.fill(_link(actions, "OfficeSelectionAction", "Vérifier les 23", app, "Composition"))

static func _priorities(parent: VBoxContainer, app: Control) -> void:
	var contracts := P.contracts(app.model)
	var choices: Array = []
	if not contracts.is_empty():
		var first: Dictionary = contracts[0]
		choices.append({"title":"%d contrats à préparer" % contracts.size(), "detail":str(first.get("name", "")) + " · " + str(first.get("contractLabel", "Échéance à examiner")), "action":func(): _open_player(app, str(first.id)), "id":"OfficeContractsAction"})
	var training: Dictionary = app.model.get("decisions", {}).get("training", {})
	choices.append({"title":"Préparer l’entraînement" if not app.model.meta.get("trained", false) else "La préparation est effectuée", "detail":str(training.get("advice", "Consultez les choix et la charge du groupe.")), "action":func(): app.Immersive.open_training(app), "id":"OfficeTrainingAction"})
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
		text.add_child(C.wrap(choice.detail, 17, C.MUTED))
	var notebook := C.button("Mon carnet personnel", func(): open_notebook(app), false, app.accent)
	notebook.name = "OpenCoachNotebook"
	notebook.custom_minimum_size.y = maxi(30, C.px(40))
	parent.add_child(notebook)

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
		tile.add_child(standing_action(app,club))
		var row := C.h(8)
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
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

static func standing_action(app: Control, club: Dictionary) -> Button:
	var action := Button.new()
	action.name="OfficeStandingRow_"+G.n(club.get("id",""))
	action.flat=true
	action.set_meta("club_id",club.get("id"))
	for key in ["won","drawn","lost"]: action.set_meta(key,S.count_text(club.get(key)))
	action.tooltip_text="%s\nVictoires %s  ·  Nuls %s  ·  Défaites %s\nOuvrir le classement complet" % [G.club_name(club),action.get_meta("won"),action.get_meta("drawn"),action.get_meta("lost")]
	action.accessibility_name=action.tooltip_text.replace("\n"," · ")
	var focus := C.box(Color(C.MINT,.07),C.GOLD,4,0)
	focus.set_border_width_all(2)
	action.add_theme_stylebox_override("focus",focus)
	action.add_theme_stylebox_override("hover",C.box(Color(C.MINT,.07),Color(C.MINT,.68),4,0))
	action.pressed.connect(func():
		app.table_division=str(app.model.meta.get("leagueId",app.table_division))
		app._navigate("Classements"))
	return action

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
		row.add_child(G.portrait(int(player.get("portraitIndex", 0)), C.px(125), player) if not str(player.get("id", "")).is_empty() else C.photo("recruit-profile", Vector2(125, 125)))
		var identity := C.v(6)
		C.fill(identity)
		row.add_child(identity)
		identity.add_child(C.wrap(player.get("name", "Profil à examiner"), 30, C.IVORY, true))
		identity.add_child(C.wrap(str(player.get("pos", "")) + " · " + G.n(player.get("age", "—")) + " ans", 20))
		identity.add_child(C.chip("NIVEAU  " + G.n(player.get("rating", "—"))))
		parent.add_child(C.wrap(G.euros(player.get("fee", 0)) + " · " + G.euros(player.get("salary", 0)) + " / sem.", 24, C.IVORY, true))
		parent.add_child(C.wrap(player.get("reason", "Consultez les disponibilités et les modalités avant une offre."), 18))
	_link(parent, "OfficeMarketAction", "Lire le dossier complet  →", app, "Recrutement")

static func fixture_competition(model: Dictionary, fixture: Dictionary) -> String:
	var competition := str(fixture.get("competitionId",""))
	if competition.is_empty(): return P.league_name(model)
	for league: Dictionary in model.get("leagues",[]):
		if league.get("id")==competition: return str(league.get("name","Championnat"))
	return str(fixture.get("label","Championnat")).get_slice(" · ",0)

static func short_fixture_label(model: Dictionary, fixture: Dictionary) -> String:
	var label := str(fixture.get("label","Rencontre"))
	if not fixture.has("competitionId"): return label
	var id := str(fixture.competitionId)
	var competition := World.name_for(model,id)
	if label.begins_with(competition+" · "):
		return World.short_name(id,competition,model)+label.trim_prefix(competition)
	return label

static func describe_fixture(node: Control, detail: String) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.tooltip_text = detail
	node.accessibility_name = detail.replace("\n"," · ")

static func timeline_period(fixture: Dictionary) -> String:
	var date := P.fixture_date(fixture)
	return date if not date.is_empty() else "SEM. %02d" % (int(fixture.get("week", 0))+1)

static func _timeline(parent: VBoxContainer, app: Control) -> void:
	var japan := SeasonPreparation.is_japan(app.model.meta)
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
		var period := C.label(timeline_period(fixture), 21, C.GOLD)
		period.name = "OfficeTimelineDate"
		period.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var local_date := P.fixture_date(fixture, true)
		if not local_date.is_empty(): describe_fixture(period, local_date)
		list.add_child(period)
		list.add_child(C.rule())
		var opponent: Dictionary = fixture.get("away", {}) if fixture.get("home", {}).get("id") == app.model.club.id else fixture.get("home", {})
		var name := C.label(G.club_name(opponent), 24)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		list.add_child(name)
		var label := str(fixture.get("label","Rencontre"))
		list.add_child(C.label(short_fixture_label(app.model,fixture) if japan else label,19,C.MUTED))
		if japan:
			var place := "Neutre" if fixture.get("neutral",false) else "Domicile" if fixture.get("home",{}).get("id")==app.model.club.id else "Extérieur"
			list.add_child(C.label(place,18,C.MUTED))
			describe_fixture(tile,"\n".join([G.club_name(opponent),label,place,P.fixture_venue(fixture)]).strip_edges())
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
