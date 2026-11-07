extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func office(app: Control) -> Control:
	return preload("res://ui/office_view.gd").build(app)

static func club(app: Control) -> Control:
	var page := G.v(14)
	page.name = "CarnetClub"
	G.fill(page, true)
	var c := G.identity(app.model.club)
	var photos := G.h(14)
	G.fill(photos, true)
	page.add_child(photos)
	for kind in ["city", "stadium"]:
		var picture := G.picture(c.get("slug", "toulouse"), kind)
		G.fill(picture, true, 1.2 if kind == "city" else 1.0)
		photos.add_child(picture)
		var content: VBoxContainer = picture.get_meta("content")
		content.add_child(G.label("LE TERRITOIRE" if kind == "city" else "LE STADE", 14, G.WHITE))
		content.add_child(G.spacer())
		var title := G.wrap(c.get("city", "") if kind == "city" else c.get("stadium", ""), 34, G.WHITE)
		content.add_child(title)
		content.add_child(G.wrap("Photographie réelle d'archive · crédits accessibles", 12, G.WHITE))
	var dossier := G.panel(page)
	var row := G.h(20)
	dossier.add_child(row)
	row.add_child(G.crest(c, 78))
	var text := G.v(6)
	G.fill(text)
	row.add_child(text)
	text.add_child(G.wrap(c.get("name", "Votre club"), 28, G.INK))
	text.add_child(G.wrap("Un territoire, une identité, une saison à écrire.", 16, G.accent_ink(app.accent)))
	text.add_child(G.wrap("Capacités et finances de simulation, non officielles. Les photos d’archive ne certifient pas la configuration actuelle des stades.", 13))
	row.add_child(G.button("CRÉDITS & LICENCES", app._credits))
	return page

static func calendar(app: Control) -> Control:
	var page := G.h(14)
	page.name = "CarnetCalendar"
	G.fill(page, true)
	var sheet := G.panel(page)
	G.chapter(sheet,"06","Les rendez-vous du club","Résultats et rencontres à venir · les phases finales se précisent au fil de la saison.",app.accent)
	var list := G.scroll(sheet)
	var fixtures: Array = app.model.get("calendar", [])
	if fixtures.is_empty(): list.add_child(G.wrap("Aucune rencontre programmée pour le moment.", 16))
	for fixture in fixtures:
		var row := G.h(12)
		row.custom_minimum_size.y = 52
		list.add_child(row)
		var caption: String = fixture.get("label", "Semaine " + G.n(fixture.get("week", 0)))
		caption = {"barrage":"Barrage","semi":"Demi-finale","final":"Finale","access":"Barrage d’accession"}.get(caption,caption)
		row.add_child(G.cell(caption, 132, G.MUTED))
		var home: Dictionary = fixture.get("home", {})
		var away: Dictionary = fixture.get("away", {})
		row.add_child(G.crest(home, 36))
		row.add_child(G.cell(G.club_name(home), 128, G.INK, true))
		var score: Variant = fixture.get("score")
		var scores := G.cell("%s — %s" % [G.n(score[0]), G.n(score[1])] if score is Array else "à jouer", 85, G.GOLD)
		scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scores.add_theme_font_size_override("font_size", 18)
		row.add_child(scores)
		var opponent := G.cell(G.club_name(away), 128, G.INK, true)
		opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(opponent)
		row.add_child(G.crest(away, 36))
		list.add_child(G.separator())
	return page

static func tables(app: Control) -> Control:
	var page := G.h(14)
	page.name = "CarnetStandings"
	G.fill(page, true)
	var sheet := G.panel(page)
	var leagues: Array = app.model.get("leagues", [])
	if leagues.is_empty(): leagues = [{"id":"elite","name":"Championnat historique","rows":app.model.get("league", [])}]
	G.chapter(sheet,"07","La course du championnat","Le classement de votre carrière, dans l’ordre de la compétition.",app.accent)
	var tabs := G.h(10)
	sheet.add_child(tabs)
	for league in leagues:
		var b := G.button(str(league.get("name", league.id)).to_upper(), func(): app.table_division = league.id; app._render())
		G.fill(b)
		if app.table_division == league.id: G.selected(b,app.accent)
		tabs.add_child(b)
	var chosen: Dictionary = leagues[0]
	for league in leagues:
		if league.id == app.table_division: chosen = league
	for pair in [["champion","CHAMPION"],["finalist","FINALISTE"]]:
		if chosen.get(pair[0]) is Dictionary:
			sheet.add_child(G.label(pair[1] + "  /  " + G.club_name(chosen[pair[0]]),18,G.GOLD))
	var list := G.scroll(sheet)
	var header := G.h(12)
	list.add_child(header)
	for pair in [["RG",36],["CLUB",220],["MJ",40],["V",36],["N",36],["D",36],["DIFF.",66],["PTS",52]]:
		header.add_child(G.cell(pair[0],pair[1],G.MUTED,pair[0] == "CLUB"))
	list.add_child(G.separator())
	for club in chosen.get("rows", []):
		var frame := PanelContainer.new()
		var own: bool = club.id == app.model.club.id
		var style := G.T.box(Color(app.accent,.10) if own else Color.TRANSPARENT, 2)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		frame.add_theme_stylebox_override("panel", style)
		list.add_child(frame)
		var row := G.h(12)
		frame.add_child(row)
		row.add_child(G.cell(G.n(club.get("rank", 0)),36,G.accent_ink(app.accent) if own else G.MUTED))
		row.add_child(G.cell(G.club_name(club),220,G.INK,true))
		for pair in [["played",40],["won",36],["drawn",36],["lost",36]]: row.add_child(G.cell(G.n(club.get(pair[0],0)),pair[1],G.MUTED))
		row.add_child(G.cell(G.n(float(club.get("pf",0))-float(club.get("pa",0))),66))
		var points := G.cell(G.n(club.get("points",0)),52,G.GOLD)
		points.add_theme_font_size_override("font_size",19)
		row.add_child(points)
	sheet.add_child(G.wrap("MJ : matchs joués · V / N / D : victoires, nuls, défaites · DIFF. : points marqués moins encaissés",12))
	return page

static func finance(app: Control) -> Control:
	var page := G.h(14)
	page.name = "CarnetFinance"
	G.fill(page,true)
	var info: Dictionary = app.model.get("finance", {})
	var journal := G.panel(page,1.65)
	G.chapter(journal,"08","Le journal des flux","Les opérations réellement enregistrées dans votre carrière",app.accent)
	var columns := G.h()
	journal.add_child(columns)
	columns.add_child(G.cell("OPÉRATION",180,G.MUTED,true))
	columns.add_child(G.cell("MONTANT",140,G.MUTED))
	var list := G.scroll(journal)
	var ledger: Array = info.get("ledger",app.model.get("ledger",[]))
	if ledger.is_empty(): list.add_child(G.wrap("Le journal s’ouvrira avec les premières opérations : une journée jouée ou une décision financière.",17))
	for entry in ledger:
		var line := G.h(12)
		line.custom_minimum_size.y=40
		list.add_child(line)
		line.add_child(G.cell(entry.get("title","Opération"),180,G.INK,true))
		line.add_child(G.cell(G.euros(entry.get("amount",0)),140,G.GOOD if float(entry.get("amount",0)) >= 0 else G.ALERT))
		list.add_child(G.separator())
	var side := G.panel(page,.85)
	var notes := G.scroll(side)
	notes.add_child(G.section("Les moyens du projet"))
	notes.add_child(G.metric(G.euros(info.get("cash", app.model.club.get("cash",0))),"Trésorerie disponible",G.GOLD))
	notes.add_child(G.separator())
	var wage := 0.0
	for p in app.model.get("squad", []): wage += float(p.get("salary",0))
	notes.add_child(G.metric(G.euros(info.get("wage",wage)),"Salaires hebdomadaires"))
	notes.add_child(G.separator())
	notes.add_child(G.wrap(info.get("notice","Toutes les valeurs de cette carrière sont fictives. Elles ne représentent pas les budgets des clubs réels."),14))
	notes.add_child(G.button("VOIR LES CONTRATS  →",func():app._navigate("Effectif")))
	return page
