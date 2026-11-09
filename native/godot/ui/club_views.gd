extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const Semantics = preload("res://ui/data_semantics.gd")

static func competition_name(id: String) -> String:
	return {"elite":"Élite","accession":"Accession","prem":"Premiership","urc":"United Rugby Championship","srp":"Super Rugby Pacific","jlo-d1":"League One · Division 1","jlo-d2":"League One · Division 2","jlo-d1-d2":"Barrage Japon D1 / D2","nationale":"Nationale","champ":"Champ Rugby","access-nationale":"Barrage Pro D2 / Nationale","champions":"Coupe des champions","challenge":"Challenge européen","access":"Barrage d’accession"}.get(id, id)

static func phase_name(phase: String) -> String:
	return {"league":"Phase régulière","pool":"Phase de poules","barrage":"Barrage","elimination":"Match de barrage","promotion":"Barrage aller-retour","third-place":"Petite finale","r16":"Huitième de finale","quarter":"Quart de finale","semi":"Demi-finale","final":"Finale","access":"Barrage d’accession","ended":"Compétition terminée"}.get(phase, phase)

static func _calendar_date(iso: String) -> String:
	var parts := iso.split("-")
	return "%s/%s/%s" % [parts[2], parts[1], parts[0]] if parts.size() == 3 else iso

static func archive_titles(year: Dictionary) -> Array:
	var titles: Array = []
	var champions: Variant = year.get("champions", [])
	if champions is Array: titles.append_array(champions)
	elif champions is Dictionary:
		for id in champions:
			if champions[id] != null: titles.append({"leagueId":id,"clubId":champions[id]})
	for id in ["champions", "challenge"]:
		var champion: Variant = year.get("europe", {}).get(id, {}).get("champion")
		if champion != null: titles.append({"leagueId":id,"clubId":champion})
	return titles

# Resize only the standings presentation, keeping the live career and navigation.
class StandingsLayout extends HBoxContainer:
	var table_frame: Control
	var context: Control
	var scroll: ScrollContainer
	var list: VBoxContainer
	var total := 0
	var capacity := 6
	var redraw: Callable
	var pending := false
	func _ready() -> void:
		resized.connect(_schedule)
		scroll.resized.connect(_schedule)
		_schedule()
	func _schedule() -> void:
		if pending: return
		pending = true
		_adapt.call_deferred()
	func _adapt() -> void:
		pending = false
		if not is_inside_tree() or scroll.size.y <= 0: return
		var wide := size.x >= 1380
		context.visible = wide
		table_frame.custom_minimum_size.x = 1040 if wide else 0
		table_frame.size_flags_horizontal = Control.SIZE_FILL if wide else Control.SIZE_EXPAND_FILL
		var overhead := 36.0
		var stride := 36.0
		if list.get_child_count() >= 2:
			overhead = list.get_child(0).get_combined_minimum_size().y + list.get_child(1).get_combined_minimum_size().y + 6
		for child: Control in list.get_children().slice(2):
			stride = maxf(stride,child.get_combined_minimum_size().y + 3)
		var next_capacity := clampi(floori((scroll.size.y-overhead-4)/stride),1,maxi(1,total))
		if next_capacity != capacity:
			capacity = next_capacity
			redraw.call(capacity)

static func _page_turn(app:Control,id:String,state:Dictionary,page:int,button_index:int) -> void:
	state.page=page
	app._render()
	var row:=app.find_child(id,true,false)
	if row!=null:
		var target:Button=row.get_child(button_index)
		if target.disabled:target=row.get_child(2 if button_index==0 else 0)
		if not target.disabled:target.grab_focus.call_deferred()

static func _paged(app:Control,parent:Node,id:String,total:int,capacity:int,state_id:String="") -> Vector2i:
	var key:=state_id if not state_id.is_empty() else id
	if not app.management_ui.get(key) is Dictionary:app.management_ui[key]={"page":0}
	var state:Dictionary=app.management_ui[key]
	var pages:=maxi(1,ceili(float(total)/capacity))
	state.page=clampi(int(state.page),0,pages-1)
	var row:=G.h(8)
	row.name=id
	parent.add_child(row)
	var previous:=G.reading_button(G.button("← Précédent",func():_page_turn(app,id,state,maxi(0,int(state.page)-1),0)),88)
	previous.disabled=int(state.page)==0
	row.add_child(previous)
	var caption:=G.label("Page %d / %d"%[int(state.page)+1,pages],12,G.MUTED)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	G.fill(caption);row.add_child(caption)
	var next:=G.reading_button(G.button("Suivant →",func():_page_turn(app,id,state,mini(pages-1,int(state.page)+1),2)),88)
	next.disabled=int(state.page)>=pages-1
	row.add_child(next)
	return Vector2i(int(state.page)*capacity,mini(total,(int(state.page)+1)*capacity))

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
		var slug: String = c.get("slug", "")
		var photo: Dictionary = c.get("photos", {}).get(kind, {})
		var picture := G.picture(slug, kind, true, str(photo.get("path", "")))
		var archive_available: bool = picture.get_meta("has_photo", false)
		if not archive_available:
			var backing := ColorRect.new()
			backing.color = Color(c.get("color", "#303c42")).darkened(.28)
			backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			picture.add_child(backing)
			picture.move_child(backing, 0)
		G.fill(picture, true, 1.2 if kind == "city" else 1.0)
		photos.add_child(picture)
		var content: VBoxContainer = picture.get_meta("content")
		content.add_child(G.label("LE TERRITOIRE" if kind == "city" else "LE STADE", 14, G.WHITE))
		content.add_child(G.spacer())
		var title := G.wrap(c.get("city", "") if kind == "city" else c.get("stadium", ""), 34, G.WHITE)
		title.add_theme_font_override("font", G.T.DISPLAY)
		title.add_theme_font_size_override("font_size", 24)
		content.add_child(title)
		if picture.get_meta("photo_from_pack", false):
			var credit := G.wrap("Photo · " + str(photo.get("credit", "")), 12, G.WHITE)
			credit.name = "VenuePhotoCredit_" + kind
			credit.mouse_filter = Control.MOUSE_FILTER_STOP
			credit.tooltip_text = "Source : %s\nLicence : %s" % [photo.get("source", ""), photo.get("license", "")]
			content.add_child(credit)
		else:
			content.add_child(G.wrap("Photo d’archive · crédits accessibles" if archive_available else "Aucune photo d’archive disponible", 12, G.WHITE))
	var dossier := G.panel(page)
	var row := G.h(20)
	dossier.add_child(row)
	row.add_child(G.crest(c, 78))
	var text := G.v(6)
	G.fill(text)
	row.add_child(text)
	text.add_child(G.wrap(c.get("name", "Votre club"), 28, G.INK))
	text.add_child(G.wrap("Un territoire, une identité, une saison à écrire.", 16, G.accent_ink(app.accent)))
	text.add_child(G.wrap("Retrouvez les repères du territoire et l’histoire du club.", 13))
	row.add_child(G.button("CRÉDITS & LICENCES", app._credits))
	return page

static func calendar(app: Control) -> Control:
	var page := G.h(14)
	page.name = "CarnetCalendar"
	G.fill(page, true)
	var sheet := G.panel(page)
	G.chapter(sheet,"06","Les rendez-vous du club","Résultats et rencontres à venir · les phases finales se précisent au fil de la saison.",app.accent)
	var list := G.scroll(sheet)
	list.get_parent().name="CalendarScroll"
	var fixtures: Array = app.model.get("calendar", [])
	var international: bool = app.model.get("meta", {}).get("mode") == "world"
	var bounds:=_paged(app,sheet,"CalendarPagination",fixtures.size(),5)
	if fixtures.is_empty(): list.add_child(G.wrap("Aucune rencontre programmée pour le moment.", 16))
	for fixture in fixtures.slice(bounds.x,bounds.y):
		var tile := G.card(list, G.accent_ink(app.accent) if not fixture.get("played", false) and fixture.get("week", -1) == app.model.meta.get("week", -2) else G.LINE)
		tile.set_meta("fixture_id", fixture.get("id", ""))
		var row := G.h(12)
		row.custom_minimum_size.y = 36
		tile.add_child(row)
		var caption: String = fixture.get("label", "Semaine " + G.n(fixture.get("week", 0)))
		caption = {"barrage":"Barrage","semi":"Demi-finale","final":"Finale","access":"Barrage d’accession"}.get(caption,caption)
		if international:
			var details := G.v(1)
			details.custom_minimum_size.x = 174
			row.add_child(details)
			var competition := competition_name(str(fixture.get("competitionId", "")))
			var date := G.label(_calendar_date(str(fixture.get("date", ""))), 13, G.GOLD)
			date.name = "CalendarFixtureDate"
			details.add_child(date)
			var phase := str(fixture.get("phase", ""))
			var stage := "J%d · %s" % [int(fixture.get("competitionRound", 0)) + 1, "Poules" if phase == "pool" else "Championnat"] if phase in ["league", "pool"] else phase_name(phase)
			details.add_child(G.wrap(competition + " · " + stage, 12, G.INK))
			var venue := str(fixture.get("venue", ""))
			if not venue.is_empty(): details.add_child(G.wrap(venue, 11, G.MUTED))
		else:
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
		var winner: Variant = fixture.get("winner")
		if international and score is Array and score[0] == score[1] and winner != null:
			tile.add_child(G.wrap("Qualifié après départage · " + G.club_name(home if home.get("id") == winner else away), 12, G.GOLD))
		list.add_child(G.separator())
	return page

static func _standings_rows(app: Control, list: VBoxContainer, rows: Array, bounds: Vector2i) -> void:
	var header := G.h(12)
	list.add_child(header)
	for pair in [["RG",36],["CLUB",220],["MJ",40],["V",36],["N",36],["D",36],["DIFF.",66],["PTS",52],["FORME",136]]:
		header.add_child(G.cell(pair[0],pair[1],G.MUTED,pair[0] == "CLUB"))
	list.add_child(G.separator())
	for club: Dictionary in rows.slice(bounds.x,bounds.y):
		var frame := PanelContainer.new()
		frame.name = "StandingsRow_" + str(club.id)
		frame.custom_minimum_size.y = 32
		frame.set_meta("club_id",club.id)
		var own: bool = club.id == app.model.club.id
		var style := G.T.box(Color(app.accent,.10) if own else Color.TRANSPARENT, 2)
		if own:
			style.border_color = G.accent_ink(app.accent)
			style.border_width_bottom = 2
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		frame.add_theme_stylebox_override("panel", style)
		list.add_child(frame)
		var row := G.h(12)
		frame.add_child(row)
		row.add_child(G.cell(Semantics.count_text(club.get("rank")),36,G.accent_ink(app.accent) if own else G.MUTED))
		row.add_child(G.cell(G.club_name(club),220,G.INK,true))
		row.add_child(G.cell(Semantics.count_text(club.get("played")),40,G.MUTED))
		for pair in [["won","V"],["drawn","N"],["lost","D"]]:
			var badge := Semantics.count_badge(club.get(pair[0]), pair[1], 36)
			badge.name = "StandingCount_" + pair[0]
			row.add_child(badge)
		row.add_child(G.cell(Semantics.difference_text(club.get("pf"),club.get("pa")),66))
		var points := G.cell(Semantics.number_text(club.get("points")),52,G.GOLD)
		points.add_theme_font_size_override("font_size",19)
		row.add_child(points)
		var form := Semantics.recent_form(club.get("form"))
		form.custom_minimum_size.x = 136
		row.add_child(form)

static func _standings_context(app: Control, page: Control) -> Control:
	var content := G.panel(page)
	var frame: Control = content.get_parent()
	frame.name = "StandingsContext"
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var club: Dictionary = app.model.club
	var meta: Dictionary = app.model.get("meta", {})
	var division := ""
	for league: Dictionary in app.model.get("leagues",[]):
		if meta.get("mode") == "world" and league.id != meta.get("leagueId"): continue
		for row: Dictionary in league.get("rows",[]):
			if row.id == app.model.club.id:
				club = row
				division = str(league.get("name",""))
	content.add_child(G.label("NOTRE CLUB",12,G.MUTED))
	var identity := G.h(10)
	content.add_child(identity)
	identity.add_child(G.crest(app.model.club,48))
	var name := G.wrap(G.club_name(app.model.club),22,G.INK)
	name.name = "StandingsContextClubName"
	G.fill(name)
	identity.add_child(name)
	if not division.is_empty():content.add_child(G.wrap(division,12))
	content.add_child(G.separator())
	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation",16)
	facts.add_theme_constant_override("v_separation",16)
	content.add_child(facts)
	for pair in [["rank","Rang"],["points","Points"],["played","Matchs joués"],["pf","Points marqués"],["pa","Points encaissés"]]:
		var value := Semantics.number_text(club.get(pair[0])) if pair[0]=="points" else Semantics.count_text(club.get(pair[0]))
		facts.add_child(G.metric(value,pair[1]))
	content.add_child(G.separator())
	content.add_child(G.label("BILAN DU CHAMPIONNAT",12,G.MUTED))
	var record := G.h(10)
	content.add_child(record)
	for pair in [["won","V"],["drawn","N"],["lost","D"]]:
		var result := G.v(3)
		record.add_child(result)
		result.add_child(Semantics.count_badge(club.get(pair[0]),pair[1],44))
		result.add_child(G.label(Semantics.RESULTS[pair[1]].plural,12,G.MUTED))
	content.add_child(G.label("Forme · championnat · ancien → récent",12,G.MUTED))
	content.add_child(Semantics.recent_form(club.get("form")))
	content.add_child(G.wrap("Chiffres du classement actuel. — : donnée ou résultat non renseigné.",12))
	return frame

static func tables(app: Control) -> Control:
	var page := StandingsLayout.new()
	page.add_theme_constant_override("separation",14)
	page.name = "CarnetStandings"
	G.fill(page, true)
	var sheet := G.panel(page)
	page.table_frame = sheet.get_parent()
	page.table_frame.name = "StandingsTableFrame"
	var leagues: Array = app.model.get("leagues", [])
	if leagues.is_empty(): leagues = [{"id":"elite","name":"Championnat historique","rows":app.model.get("league", [])}]
	var international: bool = app.model.get("meta", {}).get("mode") == "world"
	var toolbar: HBoxContainer
	if international:
		sheet.add_theme_constant_override("separation", 5)
		toolbar = G.h(10)
		sheet.add_child(toolbar)
		G.chapter(toolbar,"07","Les classements","",app.accent)
		G.fill(toolbar.get_child(0))
	else:
		G.chapter(sheet,"07","La course du championnat","Le classement de votre carrière, dans l’ordre de la compétition.",app.accent)
	var archives:=G.button("ARCHIVES DES SAISONS",func():season_archives(app))
	archives.name="OpenArchives"
	if not international: sheet.add_child(archives)
	var tabs := G.h(10)
	sheet.add_child(tabs)
	for league: Dictionary in leagues:
		var label := str(league.get("name", league.id))
		var short := str({"prem":"PREM","urc":"URC","champions":"CHAMPIONS","challenge":"CHALLENGE"}.get(league.id, label.to_upper())) if international else label.to_upper()
		var b := G.button(short, func(): app.table_division = league.id; app._render())
		b.name = "StandingsDivision_" + str(league.id)
		if international: G.reading_button(b, 82)
		b.tooltip_text = label
		G.fill(b)
		if app.table_division == league.id: G.selected(b,app.accent)
		tabs.add_child(b)
	var chosen: Dictionary = leagues[0]
	for league: Dictionary in leagues:
		if league.id == app.table_division: chosen = league
	var rows: Array = chosen.get("rows", [])
	var pagination_key := "standings_" + str(chosen.id)
	var pools: Array = chosen.get("pools", [])
	if international and not pools.is_empty():
		var pool_key := "standings_pool_" + str(chosen.id)
		var initial_pool := 0
		for i in range(pools.size()):
			if pools[i].rows.any(func(club: Dictionary): return club.id == app.model.club.id):
				initial_pool = i
				break
		var selected_pool := clampi(int(app.management_ui.get(pool_key, initial_pool)), 0, pools.size()-1)
		var pool_choice := OptionButton.new()
		pool_choice.name = "StandingsPoolChoice"
		G.reading_button(pool_choice, 104)
		for pool: Dictionary in pools: pool_choice.add_item(str(pool.label))
		pool_choice.select(selected_pool)
		pool_choice.item_selected.connect(func(index: int): app.management_ui[pool_key] = index; app._render())
		toolbar.add_child(pool_choice)
		toolbar.add_child(G.label(phase_name(str(chosen.get("phase", "pool"))), 12, G.MUTED))
		rows = pools[selected_pool].rows
		pagination_key += "_poule_" + str(pools[selected_pool].id)
	if international: toolbar.add_child(G.reading_button(archives, 144))
	for pair in [["champion","CHAMPION"],["finalist","FINALISTE"]]:
		if chosen.get(pair[0]) is Dictionary:
			sheet.add_child(G.label(pair[1] + "  /  " + G.club_name(chosen[pair[0]]),18,G.GOLD))
	var list := G.scroll(sheet)
	page.list = list
	page.scroll = list.get_parent()
	page.scroll.name="StandingsScroll"
	page.total = rows.size()
	list.add_theme_constant_override("separation",3)
	var pager := G.v(0)
	sheet.add_child(pager)
	page.redraw = func(capacity: int):
		var focus := app.get_viewport().gui_get_focus_owner()
		var focus_index := focus.get_index() if focus != null and pager.is_ancestor_of(focus) else -1
		for node in list.get_children():list.remove_child(node);node.queue_free()
		for node in pager.get_children():pager.remove_child(node);node.queue_free()
		var bounds := _paged(app,pager,"StandingsPagination",rows.size(),capacity,pagination_key)
		pager.visible = rows.size()>capacity
		_standings_rows(app,list,rows,bounds)
		if focus_index in [0,2]:
			var target: Button = pager.get_child(0).get_child(focus_index)
			if target.disabled:target=pager.get_child(0).get_child(2 if focus_index==0 else 0)
			if not target.disabled:target.grab_focus.call_deferred()
	page.redraw.call(page.capacity)
	if international:
		var legend := G.h(10)
		sheet.add_child(legend)
		legend.add_child(Semantics.legend())
		legend.add_child(G.label("MJ : matchs joués · DIFF. : différence de points · — : non renseigné", 11, G.MUTED))
	else:
		sheet.add_child(Semantics.legend(false))
		sheet.add_child(G.wrap("MJ : matchs joués · DIFF. : points marqués moins encaissés · Forme : 6 résultats de championnat conservés, ancien → récent · — : non renseigné",12))
	page.context = _standings_context(app,page)
	page.context.hide()
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
	var international: bool = app.model.get("meta", {}).get("mode") == "world"
	if seasons.is_empty():
		list.add_child(G.wrap("Aucune saison archivée. Les quatre championnats et les deux coupes d’Europe alimentent ce carnet au passage à la saison suivante." if international else "Aucune saison archivée. Le championnat français alimente ce carnet au passage à la saison suivante. Les archives de la ligue historique à 14 ne sont pas présentées ici.",16))
	for year:Dictionary in seasons:
		list.add_child(G.section("SAISON "+G.n(year.season)))
		for winner:Dictionary in archive_titles(year):
			list.add_child(G.wrap("Champion %s : %s"%[competition_name(winner.leagueId),_archive_club(app,winner.clubId)],17,G.INK))
		for league_id in (["elite","accession","prem","urc"] if international else ["elite","accession"]):
			var ranks:Array=year.get("standings",{}).get(league_id,[])
			var position:=ranks.find(app.model.club.id)
			if position>=0:list.add_child(G.wrap("Votre club actuel · %s · rang %d / %d en phase régulière"%[competition_name(league_id),position+1,ranks.size()],14,G.accent_ink(app.accent)))
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
	list.get_parent().name="FinanceScroll"
	var ledger: Array = info.get("ledger",app.model.get("ledger",[]))
	var bounds:=_paged(app,journal,"FinancePagination",ledger.size(),6)
	if ledger.is_empty():
		var empty := G.card(list, G.GOLD)
		empty.add_child(G.label("La première écriture reste à venir", 29, G.INK, true))
		empty.add_child(G.wrap("Le journal s’ouvrira avec les premières opérations : une journée jouée ou une décision financière.",17))
		empty.add_child(G.button("EXAMINER LES ENGAGEMENTS DU CLUB →", func(): app._navigate("Stratégie")))
	for entry in ledger.slice(bounds.x,bounds.y):
		var line := G.h(12)
		line.custom_minimum_size.y=32
		list.add_child(line)
		line.add_child(G.cell(entry.get("title","Opération"),180,G.INK,true))
		line.add_child(G.cell(G.euros(entry.get("amount",0)),140,G.GOOD if float(entry.get("amount",0)) >= 0 else G.ALERT))
		list.add_child(G.separator())
	var side := G.panel(page,.85)
	var notes := G.scroll(side)
	G.photo_note(notes, app.model.club, "Gestion du club", "Les moyens du projet", "stadium", 96)
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
		notes.add_child(G.label("ÉCRITURES DU JOURNAL · TOUTES LES PAGES", 12, G.GOLD))
		notes.add_child(G.wrap("Entrées " + G.euros(recorded_income) + "\nSorties " + G.euros(recorded_expense), 16, G.INK))
		G.gauge(notes, "Part des sorties dans les flux visibles (%)", 100 * recorded_expense / maxf(1, recorded_income + recorded_expense), 100, G.ALERT)
		notes.add_child(G.wrap("Journal partiel : ces flux ne constituent pas un bilan de saison.", 12))
	notes.add_child(G.separator())
	var financial_calendar:=str(info.get("notice","")).replace("Montants fictifs. ","").replace(" Monde fermé sans Nationale.","")
	if not financial_calendar.is_empty():notes.add_child(G.wrap(financial_calendar,14))
	side.add_child(G.button("VOIR LES CONTRATS  →",func():app._navigate("Effectif")))
	return page
