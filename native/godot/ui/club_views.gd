extends RefCounted
const G = preload("res://ui/game_skin.gd")

static func office(app: Control) -> Control:
	return preload("res://ui/office_view.gd").build(app)

static func club(app: Control) -> Control:
	var page := G.v(15)
	G.fill(page, true)
	var c := G.identity(app.model.club)
	var photos := G.h(15)
	G.fill(photos, true)
	page.add_child(photos)
	for kind in ["city", "stadium"]:
		var picture := G.picture(c.get("slug", "toulouse"), kind)
		G.fill(picture, true, 1.4 if kind == "city" else 1.0)
		photos.add_child(picture)
		var content: VBoxContainer = picture.get_meta("content")
		content.add_child(G.label("LE TERRITOIRE" if kind == "city" else "LE STADE", 12, G.GOLD))
		content.add_child(G.spacer())
		var title := G.label(c.get("city", "") if kind == "city" else c.get("stadium", ""), 36, G.INK, true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(title)
		content.add_child(G.label("Photographie réelle d'archive · crédits accessibles", 11))
	var row := G.h(20)
	page.add_child(row)
	row.add_child(G.crest(c, 84))
	var text := G.v(4)
	G.fill(text)
	row.add_child(text)
	text.add_child(G.label(c.get("name", "Votre club"), 34, G.INK, true))
	text.add_child(G.label("UNE IDENTITÉ DE JEU ORIGINALE · UN TERRITOIRE RÉEL", 11, app.accent.lightened(0.4)))
	text.add_child(G.wrap("Joueurs et finances fictifs. Les photos ne certifient pas la configuration actuelle des stades.", 12))
	row.add_child(G.button("CRÉDITS & LICENCES", app._credits))
	return page

static func calendar(app: Control) -> Control:
	var page := G.v(12)
	G.fill(page, true)
	page.add_child(G.wrap("Le calendrier de votre club, résultats et prochains rendez-vous. Les rencontres éliminatoires se précisent à mesure de la compétition.", 13))
	var list := G.scroll(page)
	var fixtures: Array = app.model.get("calendar", [])
	if fixtures.is_empty(): list.add_child(G.wrap("Le calendrier sera disponible avec la nouvelle carrière à deux divisions.", 15))
	for fixture in fixtures:
		var row := G.h(12)
		var frame := G.panel(list)
		frame.add_child(row)
		var label: String = fixture.get("label", "Semaine " + G.n(fixture.get("week", 0)))
		label = {"barrage":"Barrage","semi":"Demi-finale","final":"Finale","access":"Barrage d’accession"}.get(label,label)
		row.add_child(G.cell(label, 140, G.MUTED))
		var home: Dictionary = fixture.get("home", {})
		var away: Dictionary = fixture.get("away", {})
		row.add_child(G.crest(home, 35))
		row.add_child(G.cell(G.club_name(home), 150, G.INK, true))
		var score: Variant = fixture.get("score")
		row.add_child(G.cell("%s — %s" % [G.n(score[0]), G.n(score[1])] if score is Array else "—  /  —", 70, G.GOLD))
		row.add_child(G.cell(G.club_name(away), 150, G.INK, true))
		row.add_child(G.crest(away, 35))
	return page

static func tables(app: Control) -> Control:
	var page := G.v(12)
	G.fill(page, true)
	var leagues: Array = app.model.get("leagues", [])
	if leagues.is_empty(): leagues = [{"id":"elite","name":"Championnat historique","rows":app.model.get("league", [])}]
	var tabs := G.h()
	page.add_child(tabs)
	for league in leagues:
		var b := G.button(str(league.get("name", league.id)).to_upper(), func(): app.table_division = league.id; app._render())
		G.fill(b)
		if app.table_division == league.id: b.add_theme_stylebox_override("normal", G.T.box(Color("3c352a"), 4, G.GOLD))
		tabs.add_child(b)
	var chosen: Dictionary = leagues[0]
	for league in leagues:
		if league.id == app.table_division: chosen = league
	for pair in [["champion","CHAMPION"],["finalist","FINALISTE"]]:
		if chosen.get(pair[0]) is Dictionary:
			page.add_child(G.label(pair[1] + "  /  " + G.club_name(chosen[pair[0]]),16,G.GOLD))
	var list := G.scroll(page)
	var header := G.h(12)
	list.add_child(header)
	for pair in [["RG",32],["CLUB",240],["MJ",34],["V",32],["N",32],["D",32],["DIFF.",60],["PTS",50]]:
		header.add_child(G.cell(pair[0],pair[1],G.MUTED,pair[0] == "CLUB"))
	for club in chosen.get("rows", []):
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", G.T.box(app.accent.darkened(0.75) if club.id == app.model.club.id else G.PANEL, 4))
		list.add_child(frame)
		var row := G.h(12)
		frame.add_child(row)
		row.add_child(G.cell(G.n(club.get("rank", 0)),32,G.GOLD))
		row.add_child(G.cell(G.club_name(club),240,G.INK,true))
		for pair in [["played",34],["won",32],["drawn",32],["lost",32]]: row.add_child(G.cell(G.n(club.get(pair[0],0)),pair[1],G.MUTED))
		row.add_child(G.cell(G.n(float(club.get("pf",0))-float(club.get("pa",0))),60))
		row.add_child(G.cell(G.n(club.get("points",0)),50,G.GOLD))
	return page

static func finance(app: Control) -> Control:
	var page := G.v(16)
	G.fill(page,true)
	var info: Dictionary = app.model.get("finance", {})
	var totals := G.h(16)
	page.add_child(totals)
	var cash := G.panel(totals)
	cash.add_child(G.metric(G.euros(info.get("cash", app.model.club.get("cash",0))),"Trésorerie disponible",G.GOLD))
	var wage := 0.0
	for p in app.model.get("squad", []): wage += float(p.get("salary",0))
	var wages := G.panel(totals)
	wages.add_child(G.metric(G.euros(info.get("wage",wage)),"Salaires hebdomadaires"))
	page.add_child(G.wrap(info.get("notice","Toutes les valeurs de cette carrière sont fictives. Elles ne représentent pas les budgets des clubs réels."),12))
	page.add_child(G.section("LE JOURNAL DES FLUX", "Les opérations réellement enregistrées par le moteur"))
	var list := G.scroll(page)
	var ledger: Array = info.get("ledger",app.model.get("ledger",[]))
	if ledger.is_empty(): list.add_child(G.wrap("Les premières opérations apparaîtront après la journée ou une décision financière.",15))
	for entry in ledger:
		var line := G.h(12)
		list.add_child(line)
		line.add_child(G.cell(entry.get("title","Opération"),200,G.INK,true))
		line.add_child(G.cell(G.euros(entry.get("amount",0)),130,G.GOOD if float(entry.get("amount",0)) >= 0 else Color("e4ae9c")))
		list.add_child(G.separator())
	return page
