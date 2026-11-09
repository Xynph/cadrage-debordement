extends RefCounted
# Lecture des projections canoniques uniquement. Aucun état moteur ni fichier modifié.
const G = preload("res://ui/carnet_skin.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Nationale = preload("res://ui/immersive08/nationale_archive.gd")
const DIVISIONS = {"elite":"Élite", "accession":"Accession", "nationale":"Nationale", "prem":"Premiership", "urc":"United Rugby Championship", "srp":"Super Rugby Pacific", "jlo-d1":"League One · Division 1", "jlo-d2":"League One · Division 2"}

static func _id_index(ids: Array, club_id: int) -> int:
	# JSON.parse_string représente les nombres par des flottants : Array.find
	# distingue leur type, contrairement à une comparaison d’IDs normalisés.
	for i in ids.size():
		if int(ids[i]) == club_id: return i
	return -1

static func _name(model: Dictionary, id: int) -> String:
	# Les lignes projetées portent la présentation du pack actif.
	for league: Dictionary in model.get("leagues", []):
		for club: Dictionary in league.get("rows", []):
			if int(club.get("id", -1)) == id: return G.club_name(club)
	for club: Dictionary in model.get("meta", {}).get("catalogue", []):
		if int(club.get("id", -1)) == id: return G.club_name(club)
	var own: Dictionary = model.get("club", {})
	if int(own.get("id", -1)) == id: return G.club_name(own)
	return "Club #" + str(id)

static func project(model: Dictionary, club_id: int) -> Dictionary:
	var seasons: Array = []
	for archive: Dictionary in model.get("archives", {}).get("seasons", []):
		var year := {"season":int(archive.get("season", 0)), "league_id":"", "rank":null, "division_size":null, "titles":[], "promoted":false, "relegated":false}
		for division: String in ["elite", "accession"]:
			var standings: Array = archive.get("standings", {}).get(division, [])
			var index := _id_index(standings, club_id)
			if index >= 0:
				year.league_id = division
				year.rank = index + 1
				year.division_size = standings.size()
		for champion: Dictionary in archive.get("champions", []):
			if int(champion.get("clubId", -1)) == club_id: year.titles.append(str(champion.get("leagueId", "")))
		year.promoted = _id_index(archive.get("movement", {}).get("promoted", []), club_id) >= 0
		year.relegated = _id_index(archive.get("movement", {}).get("relegated", []), club_id) >= 0
		if year.rank != null or not year.titles.is_empty() or year.promoted or year.relegated: seasons.append(year)
	seasons.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.season) > int(b.season))
	var events: Array = []
	for event: Dictionary in model.get("clubLife", {}).get("clubWorld", {}).get("events", []):
		if int(event.get("a", -1)) != club_id and int(event.get("b", -1)) != club_id: continue
		var entry := event.duplicate(true)
		entry.home_name = _name(model, int(event.get("a", -1)))
		entry.away_name = _name(model, int(event.get("b", -1)))
		if event.has("clubId"): entry.reaction_club_name = _name(model, int(event.clubId))
		if event.get("winner") != null: entry.winner_name = _name(model, int(event.winner))
		events.append(entry)
	var manager: Dictionary = model.get("clubLife", {}).get("managerCareer", {})
	var history: Array = []
	for move: Dictionary in manager.get("history", []):
		var entry := move.duplicate(true)
		entry.from_name = _name(model, int(move.get("fromClub", -1)))
		entry.to_name = _name(model, int(move.get("toClub", -1)))
		history.append(entry)
	return {"club_id":club_id, "club_name":_name(model, club_id), "seasons":seasons, "events":events, "manager_history":history, "manager_current_from":manager.get("currentFrom"), "historical":model.get("meta", {}).get("engine", "") == "historical"}

static func world_seasons(app: Control, club_id: int) -> Array:
	var years := World.club_seasons(app.model, club_id)
	var nationale_by_season := {}
	for year: Dictionary in app.model.get("archives", {}).get("seasons", []):
		if year.has("nationale"): nationale_by_season[int(year.season)] = Nationale.lines(app, year, club_id)
	for year: Dictionary in years:
		year.nationale_lines = nationale_by_season.get(year.season, [])
	return years

static func _division(id: String) -> String:
	return DIVISIONS.get(id, "Division non conservée")

static func _titles(year: Dictionary) -> String:
	var titles: Array[String] = []
	for division: String in year.titles: titles.append("Champion " + _division(division))
	return " · ".join(titles) if not titles.is_empty() else "Aucun titre dans l’archive"

static func _movement(year: Dictionary) -> String:
	var movements: Array[String] = []
	if year.promoted: movements.append("Montée en Élite")
	if year.relegated: movements.append("Descente en Accession")
	return " · ".join(movements) if not movements.is_empty() else "Aucune montée ni descente dans l’archive"

static func _rank(year: Dictionary) -> String:
	return "Rang de phase régulière non conservé" if year.rank == null else "Dans sa division · %s · rang %d / %d" % [_division(year.league_id), int(year.rank), int(year.division_size)]

static func _season(parent: Node, year: Dictionary, app: Control) -> void:
	var card := G.card(parent, G.accent_ink(app.accent))
	G.fill(card.get_parent())
	card.add_child(G.section("Saison " + str(int(year.season))))
	card.add_child(G.wrap(_rank(year), 17, G.INK))
	card.add_child(G.wrap(_titles(year), 15, G.GOLD))
	var barrages: Array = year.get("japan_barrages",[])
	var nationale_lines: Array = year.get("nationale_lines", [])
	if barrages.is_empty() and str(year.league_id) not in ["jlo-d1","jlo-d2"] and (nationale_lines.is_empty() or year.promoted or year.relegated):
		card.add_child(G.wrap(_movement(year),14))
	for line: String in nationale_lines: card.add_child(G.wrap(line,16,G.INK))
	for barrage: Dictionary in barrages:
		for line: String in World.japan_lines(app,barrage): card.add_child(G.wrap(line,16,G.INK))

static func _choice(parent: Node, app: Control, seasons: Array, key: String, label: String, fallback: int, draw: Callable) -> void:
	var block := G.v(5)
	G.fill(block)
	parent.add_child(block)
	block.add_child(G.label(label, 12, G.MUTED))
	var selector := OptionButton.new()
	selector.name = "ClubMemorySeasonA" if key.ends_with("_a") else "ClubMemorySeasonB"
	selector.custom_minimum_size.y = 44
	selector.fit_to_longest_item = false
	G.fill(selector)
	var chosen: int = int(app.management_ui.get(key, fallback))
	var selected := -1
	for year: Dictionary in seasons:
		selector.add_item("Saison %d · %s" % [int(year.season), _division(year.league_id)], int(year.season))
		if int(year.season) == chosen: selected = selector.item_count - 1
	if selected < 0: selected = 0; chosen = int(seasons[0].season)
	selector.select(selected)
	app.management_ui[key] = chosen
	selector.item_selected.connect(func(index: int):
		app.management_ui[key] = selector.get_item_id(index)
		draw.call())
	block.add_child(selector)

static func _comparison(parent: Node, app: Control, seasons: Array) -> void:
	parent.add_child(G.section("Comparer deux saisons", "Chaque rang correspond à la division de la saison."))
	if seasons.size() < 2:
		parent.add_child(G.wrap("Il faut deux saisons archivées pour ouvrir la comparaison. Les premières pages s’écrivent au passage à la saison suivante.", 16))
		return
	var selectors := G.h(12)
	parent.add_child(selectors)
	var result := G.h(12)
	result.name = "ClubMemoryComparison"
	var draw := func():
		for child in result.get_children(): result.remove_child(child); child.queue_free()
		var a: int = int(app.management_ui.get("club_memory_season_a", seasons[0].season))
		var b: int = int(app.management_ui.get("club_memory_season_b", seasons[1].season))
		if a == b:
			result.add_child(G.wrap("Même saison sélectionnée : choisissez deux saisons différentes pour les comparer.", 15))
			return
		for chosen: int in [a, b]:
			for year: Dictionary in seasons:
				if int(year.season) == chosen: _season(result, year, app)
	_choice(selectors, app, seasons, "club_memory_season_a", "PREMIÈRE SAISON", int(seasons[0].season), draw)
	_choice(selectors, app, seasons, "club_memory_season_b", "DEUXIÈME SAISON", int(seasons[1].season), draw)
	parent.add_child(result)
	draw.call()

static func _date(event: Dictionary) -> String:
	var parts: Array[String] = []
	if event.has("season"): parts.append("Saison " + str(int(event.season)))
	parts.append({"league":"Championnat", "barrage":"Barrage", "semi":"Demi-finale", "final":"Finale", "access":"Barrage d’accession"}.get(event.get("phase", ""), "Rencontre"))
	if event.get("phase") == "league" and event.has("round"): parts.append("Journée " + str(int(event.round) + 1))
	elif event.has("week"): parts.append("Semaine " + str(int(event.week) + 1))
	return " · ".join(parts)

static func build(app: Control) -> Control:
	var page := G.v(12)
	page.name = "CarnetClubMemory"
	G.fill(page, true)
	var sheet := G.panel(page)
	G.fill(sheet.get_parent(), true)
	var data := project(app.model, int(app.model.get("club", {}).get("id", -1)))
	var japanese: bool = app.model.get("meta",{}).get("edition") == "world-japan"
	var nationale: bool = app.model.get("meta",{}).get("edition") == "world-nationale"
	if japanese or nationale: data.seasons = world_seasons(app,data.club_id)
	G.chapter(sheet, "21", "L’histoire de " + data.club_name, "Les faits conservés pour ce club, quelle que soit la carrière de son coach.", app.accent)
	var list := G.scroll(sheet)
	list.get_parent().name = "ClubMemoryScroll"
	var notice := "Points, scores de saisons, affluence, finances et évolution des attributs ne sont pas conservés dans ces archives."
	if japanese: notice = "Les rangs de phase régulière et les scores des barrages japonais sont conservés."
	if nationale: notice = "Les rangs de phase régulière, les mouvements et le barrage Pro D2 / Nationale sont conservés."
	list.add_child(G.wrap("Identités du pack actuel · 15 dernières saisons archivées au maximum. "+notice,13))
	_comparison(list, app, data.seasons)
	list.add_child(G.separator())
	list.add_child(G.section("La chronologie du club"))
	if data.seasons.is_empty():
		list.add_child(G.wrap("Aucune saison archivée pour ce club. Aucun passé n’est inventé.", 17, G.INK))
		if data.historical: list.add_child(G.wrap("Les saisons de la ligue historique à 14 ne sont pas conservées dans ce carnet par division.", 14))
	for year: Dictionary in data.seasons: _season(list, year, app)
	list.add_child(G.separator())
	list.add_child(G.section("Les rencontres conservées", "Uniquement les rencontres impliquant ce club. Ce registre récent n’est pas un historique exhaustif."))
	if data.events.is_empty(): list.add_child(G.wrap("Aucune rencontre de ce club n’est conservée dans le registre récent.", 16))
	for event: Dictionary in data.events:
		var card := G.card(list, G.LINE)
		card.add_child(G.wrap(_date(event), 13, G.GOLD))
		if event.has("home") and event.has("away"):
			card.add_child(G.wrap("%s  %d — %d  %s" % [event.home_name, int(event.home), int(event.away), event.away_name], 21, G.INK))
			if int(event.home) == int(event.away) and event.get("winner") != null: card.add_child(G.wrap("Vainqueur après départage : " + event.winner_name, 14, G.INK))
		if not str(event.get("reaction", "")).is_empty(): card.add_child(G.wrap("Réaction simulée · %s\n« %s »" % [event.get("reaction_club_name", "Banc"), event.reaction], 14))
	list.add_child(G.wrap("Les scores enregistrés sont des faits de la carrière ; réactions des bancs, surprise, rivalité, tension et pression sont des récits simulés.", 12))
	list.add_child(G.separator())
	list.add_child(G.section("Le parcours du coach, à part", "Les prises de poste concernent le manager ; elles ne constituent pas le palmarès du club actuel."))
	if data.manager_current_from != null: list.add_child(G.wrap("Mandat actuel depuis la saison " + str(int(data.manager_current_from)), 15, G.INK))
	if data.manager_history.is_empty(): list.add_child(G.wrap("Aucune prise de poste antérieure enregistrée.", 14))
	for move: Dictionary in data.manager_history:
		list.add_child(G.wrap("Saison %s · %s → %s" % [str(int(move.arrivalSeason)) if move.has("arrivalSeason") else "non conservée", move.from_name, move.to_name], 15))
	return page
