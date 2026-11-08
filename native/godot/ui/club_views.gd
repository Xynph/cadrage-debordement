extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func office(app: Control) -> Control:
	return preload("res://ui/office_view.gd").build(app)

static func club(app: Control) -> Control:
	var page := G.v(10)
	page.name = "CarnetClub"
	G.fill(page, true)
	var tabs := TabContainer.new()
	tabs.name = "ClubTabs"
	tabs.theme = G.T.paper()
	tabs.custom_minimum_size.y = 420
	G.fill(tabs, true)
	page.add_child(tabs)
	var territory := _territory(app)
	territory.name = "ClubTerritory"
	tabs.add_child(territory)
	tabs.set_tab_title(0, "Territoire")
	var memory: Control = preload("res://ui/club_memory_view.gd").build(app)
	tabs.add_child(memory)
	tabs.set_tab_title(1, "Histoire")
	tabs.current_tab = clampi(int(app.management_ui.get("club_tab", 0)), 0, 1)
	tabs.tab_changed.connect(func(index: int): app.management_ui.club_tab = index)
	return page

static func _territory(app: Control) -> Control:
	var page := G.v(14)
	page.name = "ClubTerritory"
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
		title.add_theme_font_override("font", G.T.DISPLAY)
		title.add_theme_font_size_override("font_size", 44)
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
		var tile := G.card(list, G.accent_ink(app.accent) if not fixture.get("played", false) and fixture.get("week", -1) == app.model.meta.get("week", -2) else G.LINE)
		var row := G.h(12)
		row.custom_minimum_size.y = 52
		tile.add_child(row)
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
	var archives:=G.button("ARCHIVES DES SAISONS",func():season_archives(app))
	archives.name="OpenArchives"
	sheet.add_child(archives)
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

static func _archive_club(app:Control,id:Variant) -> String:
	for league:Dictionary in app.model.get("leagues",[]):
		for club:Dictionary in league.get("rows",[]):
			if club.id==id:return G.club_name(club)
	for club:Dictionary in app.catalogue:
		if club.id==id:return G.club_name(club)
	return "Club #"+str(id)

static func season_archives(app:Control) -> void:
	app._clear_dialogs()
	var d:=AcceptDialog.new()
	d.name="SeasonArchives"
	app._prepare_dialog(d,820)
	d.title="Le carnet des saisons"
	d.get_ok_button().text="FERMER LES ARCHIVES"
	var content:=G.v(10)
	d.add_child(content)
	content.add_child(G.label("15 dernières saisons terminées · identités du pack actuel.\nRang de phase régulière conservé ; points et scores historiques non enregistrés.",12,G.MUTED))
	var list:=G.scroll(content)
	list.get_parent().custom_minimum_size.y=360
	var seasons:Array=app.model.get("archives",{}).get("seasons",[]).duplicate()
	seasons.reverse()
	if seasons.is_empty():
		list.add_child(G.wrap("Aucune saison archivée. Le championnat français alimente ce carnet au passage à la saison suivante. Les archives de la ligue historique à 14 ne sont pas présentées ici.",16))
	for year:Dictionary in seasons:
		list.add_child(G.section("SAISON "+G.n(year.season)))
		for winner:Dictionary in year.get("champions",[]):
			list.add_child(G.wrap("Champion %s : %s"%["Élite" if winner.leagueId=="elite" else "Accession",_archive_club(app,winner.clubId)],17,G.INK))
		for league_id in ["elite","accession"]:
			var ranks:Array=year.get("standings",{}).get(league_id,[])
			var position:=ranks.find(app.model.club.id)
			if position>=0:list.add_child(G.wrap("Votre club actuel · %s · rang %d / %d en phase régulière"%["Élite" if league_id=="elite" else "Accession",position+1,ranks.size()],14,G.accent_ink(app.accent)))
		for pair in [["promoted","Montée(s) vers l’Élite"],["relegated","Descente(s) en Accession"]]:
			var names:Array[String]=[]
			for id in year.get("movement",{}).get(pair[0],[]):names.append(_archive_club(app,id))
			list.add_child(G.wrap(pair[1]+" : "+(", ".join(names) if not names.is_empty() else "aucune"),14,G.MUTED))
		list.add_child(G.separator())
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	app.add_child(d)
	d.popup_centered(Vector2i(820,540))

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
	if ledger.is_empty():
		var empty := G.card(list, G.GOLD)
		empty.add_child(G.label("La première écriture reste à venir", 29, G.INK, true))
		empty.add_child(G.wrap("Le journal s’ouvrira avec les premières opérations : une journée jouée ou une décision financière.",17))
		empty.add_child(G.button("EXAMINER LES ENGAGEMENTS DU CLUB →", func(): app._navigate("Stratégie")))
	for entry in ledger:
		var line := G.h(12)
		line.custom_minimum_size.y=40
		list.add_child(line)
		line.add_child(G.cell(entry.get("title","Opération"),180,G.INK,true))
		line.add_child(G.cell(G.euros(entry.get("amount",0)),140,G.GOOD if float(entry.get("amount",0)) >= 0 else G.ALERT))
		list.add_child(G.separator())
	var side := G.panel(page,.85)
	var notes := G.scroll(side)
	G.photo_note(notes, app.model.club, "Gestion du club", "Les moyens du projet", "stadium", 140)
	notes.add_child(G.section("Les moyens du projet"))
	notes.add_child(G.metric(G.euros(info.get("cash", app.model.club.get("cash",0))),"Trésorerie disponible",G.GOLD))
	notes.add_child(G.separator())
	var wage := 0.0
	for p in app.model.get("squad", []): wage += float(p.get("salary",0))
	notes.add_child(G.metric(G.euros(info.get("wage",wage)),"Salaires hebdomadaires"))
	var recorded_income := 0.0
	var recorded_expense := 0.0
	for entry: Dictionary in ledger:
		var amount := float(entry.get("amount", 0))
		if amount >= 0: recorded_income += amount
		else: recorded_expense -= amount
	if not ledger.is_empty():
		notes.add_child(G.separator())
		notes.add_child(G.label("ÉCRITURES VISIBLES UNIQUEMENT", 12, G.GOLD))
		notes.add_child(G.wrap("Entrées " + G.euros(recorded_income) + "\nSorties " + G.euros(recorded_expense), 16, G.INK))
		G.gauge(notes, "Part des sorties dans les flux visibles (%)", 100 * recorded_expense / maxf(1, recorded_income + recorded_expense), 100, G.ALERT)
		notes.add_child(G.wrap("Journal partiel : ces flux ne constituent pas un bilan de saison.", 12))
	notes.add_child(G.separator())
	notes.add_child(G.wrap(info.get("notice","Toutes les valeurs de cette carrière sont fictives. Elles ne représentent pas les budgets des clubs réels."),14))
	notes.add_child(G.button("VOIR LES CONTRATS  →",func():app._navigate("Effectif")))
	return page
