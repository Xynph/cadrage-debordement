extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const ClubViews = preload("res://ui/club_views.gd")

static func _club(app: Control, id: Variant) -> String:
	for league: Dictionary in app.model.get("leagues", []):
		for c: Dictionary in league.get("rows", []):
			if c.get("id") == id: return G.club_name(c)
	for c: Dictionary in app.model.get("meta", {}).get("catalogue", []):
		if c.get("id") == id: return str(c.get("name", "Club " + str(id)))
	return "Club " + str(id)

static func build(app: Control) -> Control:
	var page := G.h(18)
	page.name = "CarnetMonde"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("clubWorld", {})
	var meta: Dictionary = app.model.get("meta", {})
	var international: bool = meta.get("mode") == "world"
	var left := G.panel(page, 1.0)
	G.chapter(left, "13", "Les confrontations", "La mémoire des rencontres suivies dans cette carrière.", app.accent)
	var preparation: Dictionary = meta.get("pacificPreparation", {})
	if not preparation.is_empty():
		var next_date := str(preparation.get("nextDate", ""))
		var weeks := int(preparation.get("weeksUntil", 0))
		var block := G.card(left, G.accent_ink(app.accent))
		block.add_child(G.section("Préparation du Pacifique"))
		block.add_child(G.wrap("Prochain match le %s · %d semaine(s)." % [next_date, weeks], 15))
		var advance := G.button("AVANCER DE %d SEMAINE(S)  →" % mini(weeks, 4), func(): app._command("advance_pacific_preparation", {"fromWeek":int(meta.get("week", 0))}))
		advance.name = "PacificPreparationAdvance"
		advance.disabled = app.waiting
		advance.tooltip_text = "Les semaines sont simulées une par une. L’avance s’arrête au prochain match."
		block.add_child(advance)
	var duels := G.scroll(left)
	var slug := str(G.identity(app.model.club).get("slug", ""))
	if ResourceLoader.exists("res://assets/club-atlas/%s-city.webp" % slug):
		G.photo_note(duels, app.model.club, "Territoires de rugby", G.club_name(app.model.club), "city", 140)
	var pairs: Array = data.get("pairs", [])
	if pairs.is_empty(): duels.add_child(G.wrap("Les premières confrontations apparaîtront après les rencontres réellement disputées.", 17))
	for p: Dictionary in pairs:
		duels.add_child(G.wrap(_club(app, p.a) + " / " + _club(app, p.b), 24, G.INK))
		duels.add_child(G.wrap("%s rencontre(s) · %s / %s victoires · %s nul(s)" % [int(p.games), int(p.winsA), int(p.winsB), int(p.draws)], 16, G.INK))
		duels.add_child(G.wrap("Intensité de la rivalité %s / 100 · dernière rencontre saison %s" % [int(p.tension), int(p.lastSeason)], 13))
		G.gauge(duels, "Victoires de " + _club(app, p.a), float(p.winsA), maxf(1, float(p.games)), G.GOLD)
		duels.add_child(G.separator())
	duels.add_child(G.section("Palmarès conservé"))
	for archive: Dictionary in data.get("archives", []):
		var champions := ClubViews.archive_titles(archive)
		if not champions.is_empty():
			for champion: Dictionary in champions:
				duels.add_child(G.wrap("S%s · %s : %s" % [int(archive.season), ClubViews.competition_name(champion.leagueId), _club(app, champion.clubId)], 15))
		elif archive.get("champion") != null:
			duels.add_child(G.wrap("S%s · %s" % [int(archive.season), _club(app, archive.champion)], 15))
	for year: Dictionary in data.get("years", []):
		duels.add_child(G.wrap("S%s · %s rencontres suivies · %s rivalité(s) intenses" % [int(year.season), int(year.matches), int(year.rivalries)], 13))
	var right := G.panel(page, 1.25)
	G.chapter(right, "14", "Les échos des clubs", "Les résultats qui agitent les vestiaires.", app.accent)
	var events := G.scroll(right)
	if data.get("events", []).is_empty(): events.add_child(G.wrap("Aucun résultat suivi pour le moment. Aucun passé n’est inventé.", 17))
	for e: Dictionary in data.get("events", []):
		var card := G.card(events, G.accent_ink(app.accent))
		var stage := ClubViews.phase_name(e.phase) if international else str({"league":"Championnat", "barrage":"Barrage", "semi":"Demi-finale", "final":"Finale", "access":"Accession"}.get(e.phase, e.phase))
		var competition := ClubViews.competition_name(e.get("leagueId", "")) + " · " if international else ""
		var unit := "semaine" if international else "journée"
		card.add_child(G.label("S%s · %s%s · %s %s" % [int(e.season), competition, stage, unit, int(e.round) + 1], 13, G.GOLD))
		card.add_child(G.wrap("%s  %s – %s  %s" % [_club(app, e.a), int(e.home), int(e.away), _club(app, e.b)], 24, G.INK))
		if e.winner != null and int(e.home) == int(e.away): events.add_child(G.wrap("Vainqueur après départage : " + _club(app, e.winner), 14))
		events.add_child(G.wrap("Écho du vestiaire · " + _club(app, e.clubId) + "\n« " + str(e.reaction) + " »", 15))
		events.add_child(G.wrap("Pression du moment %s / 100 · tension du duel %s / 100" % [int(e.pressure), int(e.tension)], 13))
		events.add_child(G.separator())
	right.add_child(G.wrap(data.get("notice", ""), 12))
	return page
