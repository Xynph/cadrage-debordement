extends RefCounted
# Page « Centre de formation » en lecture seule : suivre les jeunes sans les gérer.
# Toutes les valeurs viennent de la projection native clubLife.academyFollowUp (niveau exact
# pour nos jeunes, potentiel en fourchette par la frontière de connaissance). Les résultats et
# classements des compétitions de jeunes s'affichent dès que leur chantier alimente la projection.
const G = preload("res://ui/carnet_skin.gd")
const PAGE_SIZE := 8

static func build(app: Control) -> Control:
	var page := G.h(16)
	page.name = "CarnetAcademyFollowUp"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("academyFollowUp", {})
	if not app.management_ui.get("academy_follow_up") is Dictionary: app.management_ui["academy_follow_up"] = {"mode": "crabos"}
	var state: Dictionary = app.management_ui["academy_follow_up"]
	var mode := str(state.get("mode", "crabos"))
	var notes := G.panel(page, .72)
	G.chapter(notes, "13", "Centre de formation", "Suivre la progression, sans rien décider ici.", app.accent)
	var text := G.scroll(notes)
	if not data.get("available", false):
		text.add_child(G.wrap("Le suivi des Crabos et des Espoirs s’ouvre avec les groupes du centre de formation.", 16))
		text.add_child(G.button("LE CENTRE DE FORMATION →", func(): app._navigate("Formation")))
		return page
	_summary(text, data)
	text.add_child(G.separator())
	_competitions(text, data.get("competitions", {}))
	text.add_child(G.separator())
	for option: Array in [["crabos", "LES CRABOS · 16-17 ANS"], ["espoirs", "LES ESPOIRS · 18-21 ANS"]]:
		var key: String = option[0]
		var b := G.button(option[1], func():
			state.mode = key
			app._render())
		b.name = "FollowUp" + key.capitalize()
		if mode == key: G.selected(b, app.accent)
		text.add_child(b)
	text.add_child(G.wrap("Choix de la génération, promotions et premiers contrats restent dans les pages Formation et Centre.", 13))
	text.add_child(G.button("GÉRER LA FORMATION →", func(): app._navigate("Formation")))
	var body := G.panel(page, 1.9)
	var title := "Les Crabos" if mode == "crabos" else "Les Espoirs"
	G.chapter(body, "14", title, "Niveau, progression, temps de jeu et infirmerie.", app.accent)
	var people: Array = []
	for person: Dictionary in data.get("players", []):
		if str(person.get("group", "")) == mode: people.append(person)
	var list := G.scroll(body)
	list.get_parent().name = "FollowUpList"
	if people.is_empty(): list.add_child(G.wrap("Aucun jeune dans ce groupe pour le moment.", 17))
	var bounds := Vector2i(0, people.size())
	if people.size() > PAGE_SIZE:
		bounds = app.ClubViews._paged(app, body, "FollowUpPagination", people.size(), PAGE_SIZE, "academy_follow_up_" + mode)
	for index: int in range(bounds.x, bounds.y):
		_card(list, app, people[index], index, data)
	return page

static func _summary(parent: Node, data: Dictionary) -> void:
	var crabos: Dictionary = data.get("crabos", {})
	var espoirs: Dictionary = data.get("espoirs", {})
	var summary: Dictionary = data.get("summary", {})
	var groups := G.h(12)
	parent.add_child(groups)
	groups.add_child(G.metric("%s / %s" % [G.n(crabos.get("count", 0)), G.n(crabos.get("cap", 35))], "Crabos"))
	groups.add_child(G.metric(G.n(espoirs.get("count", 0)), "Espoirs"))
	groups.add_child(G.metric("%s / %s" % [G.n(data.get("total", 0)), G.n(data.get("capacity", 75))], "au centre"))
	var watch := G.h(12)
	parent.add_child(watch)
	var average: float = float(summary.get("progression", 0))
	watch.add_child(G.metric(("+" if average > 0 else "") + G.n(average), "progression moyenne", G.GOOD if average > 0 else G.INK))
	watch.add_child(G.metric(G.n(summary.get("injured", 0)), "à l’infirmerie", G.ALERT if int(summary.get("injured", 0)) > 0 else G.INK))
	watch.add_child(G.metric(G.n(summary.get("cracks", 0)), "cracks repérés", G.POTENTIAL_COLOR))
	var lines: Array[String] = []
	if int(summary.get("ending", 0)) > 0: lines.append("%s Espoir(s) en fin de contrat ou en dernière saison au centre." % G.n(summary.ending))
	if int(summary.get("jiff", 0)) > 0: lines.append("%s jeune(s) déjà JIFF." % G.n(summary.jiff))
	var report: Variant = summary.get("lastReport")
	if report != null: lines.append("Dernier rapport du responsable de la formation : semaine %s." % G.n(report))
	else: lines.append("Le responsable de la formation remet son rapport toutes les quatre semaines.")
	parent.add_child(G.wrap("\n".join(lines), 13))

static func _competitions(parent: Node, data: Dictionary) -> void:
	var box := G.section("Compétitions de jeunes", "Résultats et classements des Crabos et des Espoirs.")
	box.name = "FollowUpCompetitions"
	parent.add_child(box)
	if not data.get("available", false):
		box.add_child(G.wrap("Les résultats et les classements apparaîtront ici dès les premières rencontres de la saison.", 13))
		return
	for competition: Dictionary in data.get("competitions", []):
		box.add_child(G.label(str(competition.get("name", "Compétition")), 17, G.INK, true))
		var standings: Array = competition.get("standings", [])
		for position: int in mini(standings.size(), 6):
			var line: Dictionary = standings[position]
			box.add_child(G.wrap("%d. %s · %s pts · %s matchs" % [position + 1, str(line.get("club", "—")), G.n(line.get("points", 0)), G.n(line.get("played", 0))], 13, G.INK))
		var results: Array = competition.get("results", [])
		for result: Variant in results.slice(maxi(0, results.size() - 3)):
			if result is Dictionary and result.has("text"): box.add_child(G.wrap(str(result.text), 12))
			elif result is String: box.add_child(G.wrap(result, 12))

static func _card(parent: Node, app: Control, person: Dictionary, index: int, data: Dictionary) -> void:
	var tone: Color = G.POTENTIAL_COLOR if person.get("crack", false) else G.ALERT if int(person.get("injury", 0)) > 0 else G.accent_ink(app.accent)
	var card := G.card(parent, tone)
	card.set_meta("follow_up_id", person.get("id", ""))
	var row := G.h(16)
	card.add_child(row)
	row.add_child(G.portrait(int(person.get("portraitIndex", index)), 48, person))
	var identity := G.v(3)
	G.fill(identity)
	row.add_child(identity)
	identity.add_child(G.wrap(str(person.get("name", "")), 23, G.INK))
	identity.add_child(G.wrap("%s · %s ans" % [str(person.get("pos", "")), G.n(person.get("age", 0))], 13))
	row.add_child(G.metric(G.rating_text(person, true), "niveau"))
	row.add_child(G.metric(G.potential_text(person), "potentiel", G.POTENTIAL_COLOR))
	var progression: Dictionary = person.get("progression", {})
	var season_gain := int(progression.get("season", 0))
	row.add_child(G.metric(_signed(season_gain), "cette saison", G.GOOD if season_gain > 0 else G.ALERT if season_gain < 0 else G.INK))
	var details: Array[String] = []
	var month: Variant = progression.get("month")
	if month != null: details.append("%s depuis le dernier rapport" % _signed(int(month)))
	details.append("%s min · %s match(s) en équipe première" % [G.n(person.get("minutes", 0)), G.n(person.get("appearances", 0))])
	var junior: Variant = person.get("juniorMinutes")
	if junior != null: details.append("%s min chez les jeunes" % G.n(junior))
	card.add_child(G.wrap(" · ".join(details), 13))
	var flags: Array[String] = []
	if person.get("crack", false): flags.append("PRODIGE" if person.get("prodigy", false) else "CRACK")
	var injury := int(person.get("injury", 0))
	if injury > 0: flags.append("BLESSÉ · %s SEM." % G.n(injury))
	var jiff: Variant = person.get("jiff")
	if jiff is Dictionary:
		if jiff.get("status", false): flags.append("JIFF")
		else: flags.append("JIFF · %s / 3 SAISONS" % G.n(jiff.get("centreSeasons", 0)))
	var contract_end: Variant = person.get("contractEnd")
	var season := int(data.get("season", 0))
	if contract_end != null:
		flags.append("CONTRAT ESPOIR · FIN DE SAISON" if int(contract_end) <= season else "CONTRAT ESPOIR · SAISON %s" % G.season_label(contract_end))
	if person.get("lastSeason", false): flags.append("DERNIÈRE SAISON AU CENTRE")
	var cap: Variant = person.get("matchCap")
	if cap is Dictionary:
		var count := int(cap.get("count", 0))
		var limit := int(cap.get("limit", 30))
		flags.append("%s / %s MATCHS" % [G.n(count), G.n(limit)])
		G.gauge(card, "Plafond de matchs", float(count), float(limit), G.ALERT if count >= int(data.get("matchCap", {}).get("warning", 25)) else G.GOOD)
	if not flags.is_empty(): card.add_child(G.label("  ·  ".join(flags), 12, tone, true))

static func _signed(value: int) -> String:
	return ("+" if value > 0 else "") + G.n(value)
