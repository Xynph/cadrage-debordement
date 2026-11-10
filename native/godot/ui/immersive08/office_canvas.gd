extends RefCounted
## Reproduction du gabarit approuvé : positions et typographie du SVG, données natives.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const Office = preload("res://ui/immersive08/office.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")

static func _card(page: Control, rectangle: Rect2, title: String, icon: String, id: String) -> Panel:
	var local := rectangle
	local.position -= Vector2(280,220)
	return D.panel(page,local,title,icon,"",id)

static func _crest(parent: Node, club: Dictionary, rectangle: Rect2) -> void:
	var image := G.crest(club, C.px(rectangle.size.x))
	parent.add_child(image)
	D.place(image,rectangle)

static func build(app: Control) -> Control:
	var page := Control.new()
	page.name = "ImmersiveOffice"
	page.custom_minimum_size = Vector2(2248,1124)*C.density
	C.fill(page,true)
	_fixture(_card(page,Rect2(280,220,1360,418),"","","OfficeFixture"),app)
	_priorities(_card(page,Rect2(1656,220,872,418),"PRIORITÉS DE LA SEMAINE","calendar","OfficeDecisions"),app)
	_group(_card(page,Rect2(280,654,422,448),"ÉTAT DU GROUPE","heart","OfficeGroup"),app)
	_standings(_card(page,Rect2(718,654,684,448),"CLASSEMENT · "+P.league_name(app.model),"trophy","OfficeStandings"),app)
	_journal(_card(page,Rect2(1418,654,548,448),"DANS VOTRE BUREAU","mail","OfficeJournal"),app)
	_recruitment(_card(page,Rect2(1982,654,546,448),"LE PROFIL À SUIVRE","search","OfficeRecruitment"),app)
	var recent := Office.recent_results(app)
	if recent != null:
		page.add_child(recent)
		page.custom_minimum_size.y += C.px(150)
	_timeline(_card(page,Rect2(280,1118,2248,226),"PROCHAINS MATCHS","calendar","OfficeTimeline"),app,recent)
	return page

static func _fixture(card: Panel, app: Control) -> void:
	card.clip_contents = true
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var territory := Office.territory_art(app.model.club)
	if territory != null:
		card.add_child(territory)
		D.place(territory,Rect2(694,1,665,416))
	else:
		var ground := P.fixture_ground(app.model.meta,"office-hero")
		D.photo(card,ground,Rect2(694,1,665,416),.53 if ground != "office-hero" else 0.0)
		C.veil(card).set_offsets_preset(Control.PRESET_FULL_RECT,Control.PRESET_MODE_KEEP_SIZE,C.px(1))
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	if next.is_empty():
		var preparation := SeasonPreparation.data(app.model.meta)
		var upcoming := P.next_nationale_fixture(app.model)
		if not upcoming.is_empty():
			D.chip(card,Rect2(24,22,281,29),"NATIONALE",C.GOLD)
			D.text(card,27,121,"Pas de match cette semaine.",58,C.IVORY,800,920)
			D.text(card,27,183,"Prochain match · " + P.fixture_date(upcoming),30,C.IVORY,600,720)
			D.text(card,27,223,P.fixture_venue(upcoming),21,C.MUTED,400,735,HORIZONTAL_ALIGNMENT_LEFT,true)
		elif preparation.is_empty():
			D.text(card,27,100,"La saison se termine." if app.model.meta.get("canAdvanceSeason",false) else "Le travail continue.",42,C.IVORY,700,740)
			D.text(card,27,156,"Retrouvez les résultats et préparez la suite du projet.",21,C.MUTED,400,740,HORIZONTAL_ALIGNMENT_LEFT,true)
		elif SeasonPreparation.is_champ(app.model.meta):
			var fixture := P.next_scheduled_fixture(app.model)
			D.chip(card,Rect2(24,22,281,29),World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))).to_upper(),C.GOLD)
			D.text(card,27,121,"Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))),58,C.IVORY,800,920)
			D.text(card,27,183,P.fixture_date(fixture, true) if not fixture.is_empty() else World.preparation_note(preparation),30,C.IVORY,600,720)
			D.text(card,27,223,P.fixture_venue(fixture),21,C.MUTED,400,735,HORIZONTAL_ALIGNMENT_LEFT,true)
		else:
			D.chip(card,Rect2(24,22,322 if japan else 281,29),World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))).to_upper(),C.GOLD)
			D.text(card,27,121,"Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))),58,C.IVORY,800,920)
			D.text(card,27,183,World.preparation_note(preparation),30,C.IVORY,600,720)
			D.text(card,27,223,"Avancez de quatre semaines au plus, jusqu’à la prochaine rencontre.",21,C.MUTED,400,735,HORIZONTAL_ALIGNMENT_LEFT,true)
		D.button(card,Rect2(27,354,420,45),app.primary_text().trim_suffix("  →"),app.primary_action,true,"arrow",false,app.accent,"OfficePreparationAction")
		return
	var match_label := str(next.get("label",P.league_name(app.model)))
	var competition := Office.short_fixture_label(app.model,next) if japan else match_label
	var chip := D.chip(card,Rect2(24,22,281,29),competition.to_upper(),C.MUTED)
	if japan: Office.describe_fixture(chip,match_label)
	var location := "NEUTRE" if next.get("neutral",false) else "À DOMICILE" if next.get("home",{}).get("id")==app.model.club.id else "EXTÉRIEUR"
	D.chip(card,Rect2(323,22,147,29),location,C.GOLD)
	_crest(card,next.get("home",{}),Rect2(32,70,91,98))
	_crest(card,next.get("away",{}),Rect2(188,69,88,99))
	D.text(card,154,130,"VS",24,C.GOLD,600,45,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(card,305,110,G.club_name(next.get("home",{})).to_upper(),37,C.IVORY,700,520)
	D.text(card,305,150,G.club_name(next.get("away",{})).to_upper(),33,C.IVORY,600,520)
	var calendar := C.icon("calendar",25,C.GOLD)
	card.add_child(calendar)
	D.place(calendar,Rect2(29,194,25,25))
	var date := P.fixture_date(next, true)
	if date.is_empty(): date = "SEMAINE %d" % [int(next.get("week",0))+1]
	D.text(card,67,216,date+" · "+Office.fixture_competition(app.model,next),28,C.IVORY,600,680).name="OfficeFixtureDate"
	var venue_name := P.fixture_venue(next,false)
	if not venue_name.is_empty():
		var home := C.icon("home",23,C.MUTED)
		card.add_child(home)
		D.place(home,Rect2(29,235,23,23))
		D.text(card,67,255,venue_name,21,C.MUTED,400,650,HORIZONTAL_ALIGNMENT_LEFT,true).name="OfficeFixtureVenue"
	for i in 2:
		var club: Dictionary = next.get("home",{}) if i==0 else next.get("away",{})
		var rank := G.n(club.get("rank","—"))
		D.text(card,29+i*180,300,rank+("er" if rank=="1" else "e")+" · "+G.n(club.get("points",0))+" points",22,C.MINT if i==0 else C.MUTED,600,170)
	D.text(card,29,330,"Votre XV et votre plan de jeu pour la prochaine rencontre.",19,C.MUTED,400,660,HORIZONTAL_ALIGNMENT_LEFT,true)
	D.button(card,Rect2(27,354,304,45),"PRÉPARER LE MATCH",func():app._navigate("Préparation"),true,"arrow",false,app.accent,"OfficePreparationAction")
	D.button(card,Rect2(345,354,226,45),"Vérifier les 23",func():app._navigate("Composition"),false,"",false,app.accent,"OfficeSelectionAction")
	var badge := Rect2(1118,371,218,26) if territory==null else Rect2(432,277,218,26)
	D.chip(card,badge,"FEUILLE À PRÉPARER" if not app.model.get("selection",{}).get("valid",false) else "FEUILLE COMPLÈTE",C.GOLD)
	if P.fixture_location_kind(next, app.model.club.id) == "away":
		var bag := Rect2(1076, 192, 260, 165) if territory == null else Rect2(573, 306, 117, 99)
		D.scenario_photo(card, "travel-bag", bag)

static func _priorities(card: Panel, app: Control) -> void:
	var contracts := P.contracts(app.model)
	var tasks: Array = []
	if not contracts.is_empty():
		var player: Dictionary = contracts[0]
		tasks.append(["Prolonger "+str(player.name),str(player.get("status",""))+" · "+str(player.get("contractLabel","")),"SAISON "+G.n(player.get("contractEnd","—")),func():app.selected_player=str(player.id);app._navigate("Effectif"),"OfficeContractsAction"])
	else: tasks.append(["Consulter les contrats","Échéances et engagements du groupe.","EFFECTIF",func():app._navigate("Effectif"),"OfficeContractsAction"])
	var trained: bool = app.model.meta.get("trained", false)
	tasks.append(["Valider l’entraînement" if not trained else "Revoir la préparation","Choix collectifs et charge du groupe.","CETTE SEMAINE",func():
		if trained: app._navigate("Préparation")
		else: app.Immersive.open_training(app),"OfficeTrainingAction"])
	var needs: Array = app.model.get("decisions",{}).get("recruitment",{}).get("needs",[])
	var need := str(needs[0].get("pos","Effectif")) if not needs.is_empty() else "Effectif"
	tasks.append(["Examiner le recrutement","%d profils · Priorité : %s" % [app.model.get("market",[]).size(),need],"CETTE SEMAINE",func():app._navigate("Recrutement"),"OfficeRecruitmentAction"])
	D.text(card,852,38,"%d DOSSIERS" % tasks.size(),18,C.MUTED,500,150,HORIZONTAL_ALIGNMENT_RIGHT)
	for i in tasks.size():
		var y := 71+i*108
		D.rect(card,Rect2(19,y,833,91),Color("1b2722") if i==0 else C.PANEL,6)
		D.rect(card,Rect2(35,y+18,36,36),Color("376448"),5)
		D.text(card,53,y+46,str(i+1),27,C.MINT,700,30,HORIZONTAL_ALIGNMENT_CENTER)
		var action := D.button(card,Rect2(89,y+7,530,35),tasks[i][0],tasks[i][3],false,"",false,app.accent,tasks[i][4])
		action.add_theme_font_override("font",C.DISPLAY)
		action.add_theme_font_size_override("font_size",C.px(27))
		action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
		D.text(card,89,y+64,tasks[i][1],19,C.MUTED,400,530,HORIZONTAL_ALIGNMENT_LEFT,true)
		D.chip(card,Rect2(645,y+25,188,34),tasks[i][2],C.AMBER)
	D.button(card,Rect2(578,382,274,30),"Mon carnet personnel",func():Office.open_notebook(app),false,"arrow",true,app.accent,"OpenCoachNotebook")

static func _group(card: Panel, app: Control) -> void:
	var group := P.group(app.model)
	D.text(card,25,108,group.available,58,C.MINT,700,65)
	D.text(card,96,98,"disponibles",23,C.IVORY,600,130)
	D.text(card,310,105,group.injured,47,C.ALERT,700,40)
	D.text(card,348,98,"blessés",22,C.IVORY,500,64)
	D.line(card,Vector2(22,131),Vector2(400,131))
	D.text(card,24,167,"Condition physique",22,C.MUTED,500,260)
	D.text(card,397,168,str(group.condition)+" %",28,C.MINT,600,90,HORIZONTAL_ALIGNMENT_RIGHT)
	D.bar(card,Rect2(24,187,373,9),group.condition)
	var trust: float = app.model.meta.get("trust",0)
	D.text(card,24,236,"Confiance du conseil",22,C.MUTED,500,270)
	D.text(card,397,236,"%d / 100" % trust,26,C.GOLD,600,110,HORIZONTAL_ALIGNMENT_RIGHT)
	D.bar(card,Rect2(24,255,373,8),trust,C.GOLD)
	D.text(card,24,299,"Moral du vestiaire",22,C.MUTED,500,255)
	D.text(card,397,299,"%d / 100" % float(app.model.meta.get("morale",0)),25,C.MINT,600,120,HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(card,Vector2(22,321),Vector2(400,321))
	var warning := C.icon("warning",23,C.AMBER)
	card.add_child(warning)
	D.place(warning,Rect2(24,343,23,23))
	D.text(card,62,363,"%d joueurs sous surveillance" % group.watched,22,C.AMBER if group.watched>0 else C.MINT,600,338)
	var watched: Array = app.model.get("squad",[]).filter(func(player:Dictionary):return float(player.get("physicalLoad",0))>=70 or float(player.get("condition",100))<80)
	D.text(card,25,399,"Aucune alerte physique" if watched.is_empty() else str(watched[0].name)+" · Charge "+G.n(watched[0].get("physicalLoad",0))+" %",21,C.MUTED,500,370)
	D.button(card,Rect2(25,412,372,27),"Consulter le groupe",func():app._navigate("Effectif"),false,"arrow",true,app.accent,"OfficeSquadAction")

static func _standings(card: Panel, app: Control) -> void:
	for pair in [["#",26],["CLUB",78],["J",461],["DIFF.",542],["PTS",647]]: D.text(card,pair[1],90,pair[0],18,C.MUTED,500,35)
	var rows := P.standings(app.model)
	for i in rows.size():
		var club: Dictionary = rows[i]
		var y := 105+i*42
		var own: bool = club.get("id")==app.model.club.id
		if own: D.rect(card,Rect2(17,y-4,650,40),Color(app.accent,.32),4)
		var hit := Office.standing_action(app,club)
		card.add_child(hit)
		D.place(hit,Rect2(17,y-4,650,40))
		D.text(card,36,y+23,G.n(club.get("rank","—")),25,C.MINT if own else C.IVORY,600,30,HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card,80,y+23,G.club_name(club),23,C.IVORY,600,357)
		D.text(card,461,y+23,G.n(club.get("played",0)),22,C.MUTED,500,32,HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card,554,y+23,"%+d" % (int(club.get("pf",0))-int(club.get("pa",0))),23,C.MUTED,500,70,HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card,647,y+23,G.n(club.get("points",0)),25,C.IVORY,700,60,HORIZONTAL_ALIGNMENT_RIGHT)
		if not own: D.line(card,Vector2(20,y+33),Vector2(664,y+33),Color(C.LINE,.35))
	D.text(card,26,392,"FORME",18,C.MUTED,500,75)
	var form: Array = []
	for club: Dictionary in rows:
		if club.get("id")==app.model.club.id: form=club.get("form",[])
	if form.is_empty(): D.text(card,100,392,"—  Début de saison",20,C.MUTED,500,240)
	for i in mini(5,form.size()):
		var result: String = str(form[i])
		D.chip(card,Rect2(100+i*42,370,32,30),result,C.ALERT if result=="D" else C.GOLD if result=="N" else C.MINT)
	var action := D.button(card,Rect2(360,403,300,32),"Classement complet",func():app._navigate("Classements"),false,"arrow",true,app.accent,"OfficeStandingsAction")
	action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
	action.add_theme_color_override("font_color",C.GOLD)

static func _journal(card: Panel, app: Control) -> void:
	D.button(card,Rect2(330,14,198,33),"Tout le courrier",func():app._navigate("Réception"),false,"arrow",true,app.accent,"OfficeInboxAction")
	var messages: Array = app.model.get("messages",[])
	for i in mini(3,messages.size()):
		var y := 79+i*116
		var message := str(messages[i]).replace("l’onglet Contrats","les fiches joueurs")
		var category := "DIRECTION" if message.to_lower().contains("contrat") else "FORMATION" if message.to_lower().contains("espoir") else "VIE DU CLUB"
		var color: Color = [C.BLUE,C.ALERT,C.GOLD][i]
		D.rect(card,Rect2(18,y,4,92),color,2)
		D.text(card,37,y+19,category+" · JOURNAL",17,color,600,480)
		D.text(card,37,y+49,"Les échéances du groupe" if category=="DIRECTION" else "La relève est en marche" if category=="FORMATION" else "Les nouvelles de votre carrière",23,C.IVORY,600,480)
		var lines := D.words(message,52,2)
		for j in lines.size(): D.text(card,37,y+75+j*24,lines[j],18,C.MUTED,400,480,HORIZONTAL_ALIGNMENT_LEFT,true)
		if i<2: D.line(card,Vector2(36,y+105),Vector2(524,y+105),Color(C.LINE,.5))
	if messages.is_empty(): D.text(card,37,120,"Le journal s’ouvrira avec votre carrière.",20,C.MUTED,400,480,HORIZONTAL_ALIGNMENT_LEFT,true)

static func _recruitment(card: Panel, app: Control) -> void:
	var spotlight := Office.recruitment_spotlight(app.model)
	var player: Dictionary = spotlight.player
	if player.is_empty():
		D.photo(card,"scouting",Rect2(23,74,500,116))
		D.text(card,23,231,spotlight.empty,27,C.IVORY,700,500)
	else:
		var portrait := G.portrait(int(player.get("portraitIndex",0)),C.px(133),player)
		card.add_child(portrait)
		D.place(portrait,Rect2(22,74,133,117))
		D.text(card,174,104,str(player.name).to_upper(),29,C.IVORY,700,350)
		D.text(card,174,135,str(player.pos)+" · "+G.n(player.age)+" ans",22,C.MUTED,500,350)
		D.chip(card,Rect2(174,154,150,32),"NIV. "+G.n(player.rating),C.MINT)
		var available: bool = player.get("available", false)
		D.text(card,23,230,"Offre possible" if available else "Offre indisponible",24,C.MINT if available else C.ALERT,600,500)
		var reason := str(player.get("reason", ""))
		if not reason.is_empty(): D.text(card,23,260,reason,20,C.MUTED,500,500)
		D.text(card,23,336,G.euros(player.fee),32,C.IVORY,600,220)
		D.text(card,253,336,G.euros(player.salary)+" / sem.",28,C.MUTED,500,270)
	if not str(spotlight.need).is_empty():
		D.text(card,23,295,spotlight.need,20,C.IVORY,500,500,HORIZONTAL_ALIGNMENT_LEFT,true)
	D.button(card,Rect2(23,391,500,39),"Ouvrir le recrutement" if player.is_empty() else "Voir le dossier",Office.open_spotlight.bind(app,str(player.get("id",""))),false,"arrow",true,app.accent,"OfficeMarketAction")

static func _timeline(card: Panel, app: Control, recent: PanelContainer) -> void:
	var fixtures := P.upcoming(app.model)
	var tiles: Array[Panel] = []
	var grounds: Array[Label] = []
	for i in fixtures.size():
		var fixture: Dictionary = fixtures[i]
		var x := 20+i*316
		var at_home: bool = fixture.get("home",{}).get("id")==app.model.club.id
		var opponent: Dictionary = fixture.get("away",{}) if at_home else fixture.get("home",{})
		var location := P.fixture_location_kind(fixture, app.model.club.id)
		var place: String = {"neutral":"Neutre","home":"Domicile","away":"Extérieur"}.get(location,"Terrain à confirmer")
		var is_next := i == 0
		var border := C.GOLD if is_next else Office.UPCOMING_BORDER
		tiles.append(D.rect(card,Rect2(x,75,304,132),Color("39301e") if is_next else Office.UPCOMING_TILE,5,border))
		var period := D.text(card,x+16,103,Office.timeline_period(fixture),21,C.GOLD,700,174 if is_next else 244)
		if is_next: D.chip(card,Rect2(x+199,84,89,25),"À SUIVRE",C.AMBER)
		var marker := C.icon(C.fixture_location_icon(location,true),48,C.GOLD)
		marker.name = "OfficeVenueIcon%d" % i
		card.add_child(marker)
		D.place(marker,Rect2(x+240,120,48,48))
		period.name = "OfficeTimelineDate%d" % i
		var local_date := P.fixture_date(fixture, true)
		if not local_date.is_empty(): Office.describe_fixture(period, local_date)
		D.line(card,Vector2(x+14,118),Vector2(x+290,118),Office.UPCOMING_BORDER)
		var crest := Office.opponent_crest(opponent,42)
		crest.name += str(i)
		card.add_child(crest)
		D.place(crest,Rect2(x+16,122,42,42))
		var name := D.text(card,x+64,151,G.club_name(opponent),23,C.IVORY,600,170)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.max_lines_visible = 2
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.add_theme_constant_override("line_spacing",-C.px(2))
		D.place(name,Rect2(x+64,119,170,50))
		Office.describe_fixture(name, name.text + " · " + place)
		var label := Office.short_fixture_label(app.model,fixture)
		D.text(card,x+16,196,label+" · "+place,20,C.MUTED,500,272)
		var venue := P.fixture_venue(fixture, false)
		var ground := D.text(card,x+16,232,venue if not venue.is_empty() else "Terrain à confirmer",22,C.MUTED,500,272)
		ground.name = "OfficeTimelineGround%d" % i
		ground.tooltip_text = ground.text
		grounds.append(ground)
	var page := card.get_parent() as Control
	var update := func():
		var tail := 150 if recent != null else 0
		var expanded := not fixtures.is_empty() and page.size.y >= card.position.y + C.px(304 + tail)
		card.size.y = C.px(304 if expanded else 226)
		for tile in tiles: tile.size.y = C.px(210 if expanded else 132)
		for ground in grounds: ground.visible = expanded
		if recent != null:
			recent.position = Vector2(0,card.position.y + card.size.y + C.px(12))
			recent.size.x = card.size.x
	page.resized.connect(update)
	update.call()
	if fixtures.is_empty(): D.text(card,25,130,"Aucune rencontre programmée pour le moment.",25,C.MUTED,500,1500)
	var action := D.button(card,Rect2(1888,15,335,32),"Tout le calendrier",func():app._navigate("Calendrier"),false,"arrow",true,app.accent,"OfficeCalendarAction")
	action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
