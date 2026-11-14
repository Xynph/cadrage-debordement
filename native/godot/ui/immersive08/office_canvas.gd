extends RefCounted
## Reproduction du gabarit approuvé : positions et typographie du SVG, données natives.
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
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

static func _label_reading(app: Control, parent: Node, label: Label, target: Dictionary, id: String, caption: String) -> void:
	Office.reading_overlay(app, parent, Rect2(label.position / C.density, label.size / C.density), target, id, caption)

static func _scheduled_reading(app: Control, parent: Node, fixture: Dictionary, opponent: Label, timing: Label) -> void:
	var club := Office.fixture_opponent(app.model, fixture)
	_label_reading(app, parent, opponent, Office.club_reading_target(app, club), "OfficeScheduledOpponent", opponent.text)
	_label_reading(app, parent, timing, Office.date_reading_target(app, fixture), "OfficeScheduledDate", timing.text)

## Zone de Gabi au Bureau (option C, choix de Léo du 13/11/2026) : une colonne à droite, sur toute la hauteur
## des blocs (du prochain match à la frise des matchs), où Gabi est debout sous son carnet de la semaine.
## Les blocs du Bureau sont réagencés à sa gauche ; Gabi coupé : mise en page classique, pleine largeur.
const PAGE_WIDTH := 2248
const GABI_WIDTH := 440
const GAP := 16
const ROW2_CLASSIC := [422, 684, 548, 546]
const ROW2_GABI := [392, 540, 420, 392]

static func build(app: Control) -> Control:
	var page := Control.new()
	page.name = "ImmersiveOffice"
	page.custom_minimum_size = Vector2(PAGE_WIDTH,1124)*C.density
	C.fill(page,true)
	var gabi: bool = is_instance_valid(app.get("coach")) and app.coach.has_method("bureau_disponible") and app.coach.bureau_disponible()
	var main_w: int = PAGE_WIDTH - GABI_WIDTH - GAP if gabi else PAGE_WIDTH
	var fixture_w := 1060 if gabi else 1360
	_fixture(_card(page,Rect2(280,220,fixture_w,418),"","","OfficeFixture"),app,fixture_w)
	var priorities_w := main_w - fixture_w - GAP
	_priorities(_card(page,Rect2(280+fixture_w+GAP,220,priorities_w,418),"VOS TROIS PRIORITÉS","calendar","OfficeDecisions"),app,priorities_w)
	var widths: Array = ROW2_GABI if gabi else ROW2_CLASSIC
	var x := 280
	_group(_card(page,Rect2(x,654,widths[0],448),"ÉTAT DU GROUPE","heart","OfficeGroup"),app,widths[0])
	x += widths[0] + GAP
	_standings(_card(page,Rect2(x,654,widths[1],448),"CLASSEMENT · "+P.league_name(app.model),"trophy","OfficeStandings"),app,widths[1])
	x += widths[1] + GAP
	_journal(_card(page,Rect2(x,654,widths[2],448),"DANS VOTRE BUREAU","mail","OfficeJournal"),app,widths[2])
	x += widths[2] + GAP
	_recruitment(_card(page,Rect2(x,654,widths[3],448),"LE PROFIL À SUIVRE","search","OfficeRecruitment"),app,widths[3])
	var recent := Office.recent_results(app)
	if recent != null:
		page.add_child(recent)
		page.custom_minimum_size.y += C.px(150)
	var timeline := _card(page,Rect2(280,1118,main_w,226),"PROCHAINS MATCHS","calendar","OfficeTimeline")
	_timeline(timeline,app,recent,main_w)
	if gabi:
		var zone := D.panel(page,Rect2(main_w+GAP,0,GABI_WIDTH,1124),"","","","GabiBureau")
		zone.add_theme_stylebox_override("panel",D.surface(GABI_WIDTH,1124,Color("13241f"),Color("0b1512"),Color(C.GOLD,.45)))
		zone.clip_contents = true
		# La zone de Gabi suit la hauteur de la frise (compacte ou dépliée selon la place).
		var follow := func(): zone.size.y = timeline.position.y + timeline.size.y
		page.resized.connect(follow)
		follow.call()
		app.coach.installer_bureau(zone)
	return page

static func _fixture(card: Panel, app: Control, w: int = 1360) -> void:
	card.clip_contents = true
	var signature: Color = app.accent.lightened(.36)
	card.add_theme_stylebox_override("panel", D.surface(w,418,Color("192524").lerp(app.accent,.18),Color("0d1517"),signature))
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var territory := Office.territory_art(app.model.club)
	if territory != null:
		card.add_child(territory)
		D.place(territory,Rect2(694,1,w-695,416))
	else:
		var ground := P.fixture_ground(app.model.meta,"office-hero")
		D.photo(card,ground,Rect2(694,1,w-695,416),.53 if ground != "office-hero" else 0.0)
		C.veil(card).set_offsets_preset(Control.PRESET_FULL_RECT,Control.PRESET_MODE_KEEP_SIZE,C.px(1))
	D.rect(card,Rect2(1,22,4,374),signature,0)
	var match_info := Office.live_match(app.model)
	if not match_info.is_empty():
		_live_content(card, app, match_info)
		return
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	if next.is_empty():
		var preparation := SeasonPreparation.data(app.model.meta)
		var upcoming := P.next_nationale_fixture(app.model)
		var scheduled := P.next_scheduled_fixture(app.model)
		if not upcoming.is_empty():
			D.chip(card,Rect2(24,22,281,29),"SEMAINE EXEMPTE",C.GOLD)
			var opponent := D.text(card,27,121,Office.scheduled_opponent(app,upcoming),51,C.IVORY,800,645)
			opponent.name = "UpcomingOpponent"
			var timing := D.text(card,27,183,"Prochain match · " + Office.scheduled_when(app,upcoming),27,C.IVORY,600,645)
			timing.name = "UpcomingWhen"
			_scheduled_reading(app,card,upcoming,opponent,timing)
			var venue := Office.scheduled_venue(app,upcoming)
			if not venue.is_empty(): D.text(card,27,223,"Lieu · " + venue,21,C.MUTED,400,645,HORIZONTAL_ALIGNMENT_LEFT,true)
		elif preparation.is_empty() and not scheduled.is_empty():
			D.text(card,27,45,"PROCHAINE RENCONTRE",22,C.GOLD,700,640)
			var opponent := D.text(card,27,115,Office.scheduled_opponent(app, scheduled),48,C.IVORY,800,645)
			var timing := D.text(card,27,169,Office.scheduled_when(app, scheduled),27,C.IVORY,600,645)
			_scheduled_reading(app,card,scheduled,opponent,timing)
			D.text(card,27,210,P.fixture_venue(scheduled),22,C.MUTED,400,645,HORIZONTAL_ALIGNMENT_LEFT,true)
		elif preparation.is_empty():
			D.text(card,27,100,"La saison se termine." if app.model.meta.get("canAdvanceSeason",false) else "Le travail continue.",42,C.IVORY,700,740)
			D.text(card,27,156,"Retrouvez les résultats et préparez la suite du projet.",21,C.MUTED,400,740,HORIZONTAL_ALIGNMENT_LEFT,true)
		elif SeasonPreparation.is_champ(app.model.meta):
			var fixture := P.next_scheduled_fixture(app.model)
			D.chip(card,Rect2(24,22,210,29),"PRÉPARATION",C.GOLD)
			if fixture.is_empty():
				D.text(card,27,121,"Préparation · " + World.name_for(app.model,"champ"),58,C.IVORY,800,920)
				D.text(card,27,183,World.preparation_note(preparation),30,C.IVORY,600,720)
			else:
				var opponent := D.text(card,27,121,Office.scheduled_opponent(app,fixture),51,C.IVORY,800,645)
				opponent.name = "UpcomingOpponent"
				var timing := D.text(card,27,183,Office.scheduled_when(app,fixture),27,C.IVORY,600,645)
				timing.name = "UpcomingWhen"
				_scheduled_reading(app,card,fixture,opponent,timing)
				var venue := Office.scheduled_venue(app,fixture)
				if not venue.is_empty(): D.text(card,27,223,"Lieu · " + venue,21,C.MUTED,400,645,HORIZONTAL_ALIGNMENT_LEFT,true)

		else:
			D.chip(card,Rect2(24,22,322 if japan else 281,29),World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))).to_upper(),C.GOLD)
			D.text(card,27,121,"Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))),58,C.IVORY,800,920)
			D.text(card,27,183,World.preparation_note(preparation),30,C.IVORY,600,720)
			D.text(card,27,223,"Avancez de quatre semaines au plus, jusqu’à la prochaine rencontre.",21,C.MUTED,400,735,HORIZONTAL_ALIGNMENT_LEFT,true)
		D.button(card,Rect2(27,354,420,45),app.primary_text().trim_suffix("  →"),app.primary_action,true,"arrow",false,app.accent,"OfficePreparationAction")
		return
	var match_label := str(next.get("label",P.league_name(app.model)))
	var competition := Office.fixture_stage(app.model,next,match_label)
	D.text(card,27,45,"PROCHAIN MATCH",22,C.GOLD,700,205)
	var chip := D.chip(card,Rect2(224,22,269,29),competition.to_upper(),C.MUTED)
	Office.describe_fixture(chip,match_label)
	var location := "NEUTRE" if next.get("neutral",false) else "À DOMICILE" if next.get("home",{}).get("id")==app.model.club.id else "EXTÉRIEUR"
	D.chip(card,Rect2(505,22,164,29),location,C.GOLD)
	_crest(card,next.get("home",{}),Rect2(27,72,64,64))
	_crest(card,next.get("away",{}),Rect2(27,151,64,64))
	Office.reading_overlay(app,card,Rect2(27,72,64,64),Office.club_reading_target(app,next.get("home",{})),"OfficeNextHomeClubCrest",G.club_name(next.get("home",{})))
	Office.reading_overlay(app,card,Rect2(27,151,64,64),Office.club_reading_target(app,next.get("away",{})),"OfficeNextAwayClubCrest",G.club_name(next.get("away",{})))
	var home_name := D.text(card,111,111,G.club_name(next.get("home",{})).to_upper(),39,C.IVORY,800,554)
	_label_reading(app,card,home_name,Office.club_reading_target(app,next.get("home",{})),"OfficeNextHomeClubName",home_name.text)
	D.line(card,Vector2(111,143),Vector2(669,143),Color(C.LINE,.60))
	D.text(card,61,148,"VS",17,C.GOLD,700,44,HORIZONTAL_ALIGNMENT_CENTER)
	var away_name := D.text(card,111,189,G.club_name(next.get("away",{})).to_upper(),39,C.IVORY,800,554)
	_label_reading(app,card,away_name,Office.club_reading_target(app,next.get("away",{})),"OfficeNextAwayClubName",away_name.text)
	for side in ["home","away"]:
		var team: Dictionary = next.get(side,{})
		if not team.has("rank") or not team.has("points"): continue
		var rank := G.n(team.rank)
		var standing := "%s%s · %s pts" % [rank,"er" if rank=="1" else "e",G.n(team.points)] if P.standings_open(team) else "Pas encore classé · %s pts" % G.n(team.points)
		var tint := C.MINT if team.get("id")==app.model.club.id else C.MUTED
		D.text(card,111,135 if side=="home" else 213,standing,20,tint,600,420)
	var calendar := C.icon("calendar",25,C.GOLD)
	card.add_child(calendar)
	D.place(calendar,Rect2(29,227,25,25))
	var date := P.fixture_date(next, true)
	if date.is_empty(): date = "SEMAINE %d" % [int(next.get("week",0))+1]
	var next_timing := D.text(card,67,250,date+" · "+Office.fixture_competition(app.model,next),27,C.IVORY,600,601)
	next_timing.name="OfficeFixtureDate"
	_label_reading(app,card,next_timing,Office.date_reading_target(app,next),"OfficeNextDate",next_timing.text)
	var venue_name := P.fixture_venue(next,false)
	if not venue_name.is_empty():
		var home := C.icon("home",23,C.MUTED)
		card.add_child(home)
		D.place(home,Rect2(29,269,23,23))
		D.text(card,67,288,venue_name,22,C.MUTED,400,596,HORIZONTAL_ALIGNMENT_LEFT,true).name="OfficeFixtureVenue"
	var valid: bool = app.model.get("selection",{}).get("valid",false)
	D.text(card,29,327,"Feuille complète" if valid else "Feuille à préparer",21,C.MINT if valid else C.AMBER,700,310)
	D.button(card,Rect2(27,348,320,51),"PRÉPARER LE MATCH",func():app._navigate("Préparation"),true,"arrow",false,app.accent,"OfficePreparationAction")
	D.button(card,Rect2(362,348,190,51),"Vérifier les 23",func():app._navigate("Composition"),false,"",false,app.accent,"OfficeSelectionAction")
	if P.fixture_location_kind(next, app.model.club.id) == "away":
		var bag := Rect2(w - 284, 192, 260, 165) if territory == null else Rect2(573, 306, 117, 99)
		D.scenario_photo(card, "travel-bag", bag)

static func _live_content(card: Panel, app: Control, match_info: Dictionary) -> void:
	D.text(card,27,45,match_info.heading,22,C.GOLD,700,205).name = "OfficeLiveHeading"
	if not match_info.location.is_empty():
		D.chip(card,Rect2(224,22,176,29),match_info.location,C.MUTED)
	var teams: Array = match_info.teams
	for i in teams.size():
		var team: Dictionary = teams[i]
		var y := 71 + 77 * i
		_crest(card,team,Rect2(27,y,62,62))
		D.text(card,111,y+42,G.club_name(team),39,C.IVORY,800,548)
	D.text(card,27,257,match_info.score,44,C.IVORY,800,158).name = "OfficeLiveScore"
	D.text(card,188,254,match_info.state,25,C.GOLD,650,490).name = "OfficeLiveState"
	if not match_info.detail.is_empty():
		D.text(card,27,304,match_info.detail,22,C.MUTED,400,638,HORIZONTAL_ALIGNMENT_LEFT,true).name = "OfficeLiveFixtureDetail"
	D.button(card,Rect2(27,348,358,51),app.primary_text().trim_suffix("  →"),app.primary_action,true,"arrow",false,app.accent,"OfficePreparationAction")
	var review := D.button(card,Rect2(401,348,232,51),"Revoir le match",func():app._navigate("Match"),false,"",false,app.accent,"OfficeMatchReviewAction")
	review.visible = match_info.finished

static func _priorities(card: Panel, app: Control, w: int = 872) -> void:
	var tasks := Office.priorities(app.model)
	if tasks.is_empty(): D.text(card,26,108,"Reprenez une carrière pour retrouver les décisions du club.",21,C.MUTED,400,w-56,HORIZONTAL_ALIGNMENT_LEFT,true)
	for i in tasks.size():
		var y := 66+i*102
		var item: Dictionary = tasks[i]
		var tint := Office.priority_color(item)
		D.rect(card,Rect2(18,y+3,w-36,94),Color(tint,.035),4,Color(tint,.22)).name = "OfficePriority" + str(i+1)
		var icon := C.icon(item.icon,25,tint)
		card.add_child(icon)
		D.place(icon,Rect2(29,y+12,25,25))
		var action := D.button(card,Rect2(62,y+2,w-87,39),str(i+1)+". "+str(item.title),Office.open_priority.bind(app,item),false,"arrow",false,app.accent,item.id)
		action.set_meta("priority_number",i+1)
		action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,12))
		action.tooltip_text = item.title + "\n" + Office.priority_description(item)
		action.accessibility_name = action.tooltip_text.replace("\n"," · ")
		D.text(card,78,y+58,item.deadline,17,tint,650,w-125).name = "OfficePriorityDeadline" + str(i+1)
		var reason := D.text(card,78,y+82,item.detail,18,C.MUTED,400,w-126,HORIZONTAL_ALIGNMENT_LEFT,true)
		reason.name = "OfficePriorityReason" + str(i+1)
		reason.tooltip_text = item.detail
	if not tasks.any(func(item: Dictionary): return item.id == "OfficeTrainingAction") and not app.model.meta.get("canAdvanceSeason",false) and app.model.meta.get("phase","") != "ended":
		D.button(card,Rect2(24,378,249,27),"Entraînement",func():app.Immersive.open_training(app),false,"arrow",true,app.accent,"OfficeTrainingAction")
	D.button(card,Rect2(w-308,378,287,27),"Mon carnet personnel",func():Office.open_notebook(app),false,"arrow",true,app.accent,"OpenCoachNotebook")

static func _group(card: Panel, app: Control, w: int = 422) -> void:
	var group := P.group(app.model)
	var right := w - 25
	D.text(card,25,108,group.available,58,C.MINT,700,65)
	D.text(card,96,98,"disponibles",23,C.IVORY,600,130)
	D.text(card,w-112,105,group.injured,47,C.ALERT,700,40)
	D.text(card,w-74,98,"blessés",22,C.IVORY,500,64)
	D.line(card,Vector2(22,131),Vector2(w-22,131))
	D.text(card,24,167,"Condition physique",22,C.MUTED,500,260)
	D.text(card,right,168,str(group.condition)+" %",28,C.MINT,600,90,HORIZONTAL_ALIGNMENT_RIGHT)
	D.bar(card,Rect2(24,187,right-24,9),group.condition)
	var trust: float = app.model.meta.get("trust",0)
	D.text(card,24,236,"Confiance du conseil",22,C.MUTED,500,270)
	D.text(card,right,236,"%d / 100" % trust,26,C.GOLD,600,110,HORIZONTAL_ALIGNMENT_RIGHT)
	D.bar(card,Rect2(24,255,right-24,8),trust,C.GOLD)
	D.text(card,24,299,"Moral du vestiaire",22,C.MUTED,500,255)
	D.text(card,right,299,"%d / 100" % float(app.model.meta.get("morale",0)),25,C.MINT,600,120,HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(card,Vector2(22,321),Vector2(w-22,321))
	if group.watched > 0:
		var action := D.button(card,Rect2(25,337,w-50,36),U.watch_caption(group.watched),app.navigation_controller.open_watched_roster,false,"arrow",true,app.accent,"OfficeWatchedAction")
		action.add_theme_color_override("font_color", C.AMBER)
		for player: Dictionary in app.model.get("squad", []):
			var reason := U.watch_reason(player)
			if reason.is_empty(): continue
			var example := D.text(card,25,399,str(player.name)+" · "+reason,21,C.MUTED,500,w-52)
			example.tooltip_text = example.text
			_label_reading(app,card,example,{"kind":"player","id":str(player.id)},"OfficeWatchedPlayer_"+str(player.id).validate_node_name(),str(player.name))
			break
	else:
		D.text(card,25,366,"Aucune alerte physique",22,C.MINT,600,w-52)
	D.button(card,Rect2(25,412,w-50,27),"Consulter le groupe",app.navigation_controller.open_roster_group,false,"arrow",true,app.accent,"OfficeSquadAction")

static func _standings(card: Panel, app: Control, w: int = 684) -> void:
	# Colonnes calées sur le bord droit : la largeur du club s'adapte au bloc.
	var played_x := w - 223
	for pair in [["#",26],["CLUB",78],["J",played_x],["DIFF.",w-142],["PTS",w-37]]: D.text(card,pair[1],90,pair[0],18,C.MUTED,500,35)
	var rows := P.standings(app.model)
	for i in rows.size():
		var club: Dictionary = rows[i]
		var y := 105+i*42
		var own: bool = club.get("id")==app.model.club.id
		if own: D.rect(card,Rect2(17,y-4,w-34,40),Color(app.accent,.32),4)
		var hit := Office.standing_action(app,club)
		card.add_child(hit)
		D.place(hit,Rect2(17,y-4,w-34,40))
		D.text(card,36,y+23,G.n(club.get("rank","—")) if P.standings_open(club) else "–",25,C.MINT if own else C.IVORY,600,30,HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card,80,y+23,G.club_name(club),23,C.IVORY,600,played_x-104)
		D.text(card,played_x,y+23,G.n(club.get("played",0)),22,C.MUTED,500,32,HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card,w-130,y+23,"%+d" % (int(club.get("pf",0))-int(club.get("pa",0))),23,C.MUTED,500,70,HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card,w-37,y+23,G.n(club.get("points",0)),25,C.IVORY,700,60,HORIZONTAL_ALIGNMENT_RIGHT)
		if not own: D.line(card,Vector2(20,y+33),Vector2(w-20,y+33),Color(C.LINE,.35))
	D.text(card,26,392,"FORME",18,C.MUTED,500,75)
	var form: Array = []
	for club: Dictionary in rows:
		if club.get("id")==app.model.club.id: form=club.get("form",[])
	if form.is_empty(): D.text(card,100,392,"—  Début de saison",20,C.MUTED,500,240)
	for i in mini(5,form.size()):
		var result: String = str(form[i])
		D.chip(card,Rect2(100+i*42,370,32,30),result,C.ALERT if result=="D" else C.GOLD if result=="N" else C.MINT)
	var action := D.button(card,Rect2(w-324,403,300,32),"Classement complet",func():app._navigate("Classements"),false,"arrow",true,app.accent,"OfficeStandingsAction")
	action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
	action.add_theme_color_override("font_color",C.GOLD)

static func _journal(card: Panel, app: Control, w: int = 548) -> void:
	var text_w := w - 68
	var compact := w < 500
	# Bloc étroit (à côté de Gabi) : « Courrier », pour laisser le titre lisible.
	D.button(card,Rect2(w-162,14,142,33) if compact else Rect2(w-218,14,198,33),"Courrier" if compact else "Tout le courrier",func():app._navigate("Réception"),false,"arrow",true,app.accent,"OfficeInboxAction")
	var messages: Array = app.model.get("messages",[])
	for i in mini(3,messages.size()):
		var y := 79+i*116
		var message := Copy.news(str(messages[i])).replace("l’onglet Contrats","les fiches joueurs")
		var category := "DIRECTION" if message.to_lower().contains("contrat") else "FORMATION" if message.to_lower().contains("espoir") else "VIE DU CLUB"
		var color: Color = [C.BLUE,C.ALERT,C.GOLD][i]
		D.rect(card,Rect2(18,y,4,92),color,2)
		D.text(card,37,y+19,category+" · JOURNAL",17,color,600,text_w)
		D.text(card,37,y+49,"Les échéances du groupe" if category=="DIRECTION" else "La relève est en marche" if category=="FORMATION" else "Les nouvelles de votre carrière",22 if compact else 23,C.IVORY,600,text_w)
		var lines := D.words(message,int(52.0*text_w/480.0),2)
		for j in lines.size(): D.text(card,37,y+75+j*24,lines[j],18,C.MUTED,400,text_w,HORIZONTAL_ALIGNMENT_LEFT,true)
		if i<2: D.line(card,Vector2(36,y+105),Vector2(w-24,y+105),Color(C.LINE,.5))
	if messages.is_empty(): D.text(card,37,120,"Le journal s’ouvrira avec votre carrière.",20,C.MUTED,400,text_w,HORIZONTAL_ALIGNMENT_LEFT,true)

static func _recruitment(card: Panel, app: Control, w: int = 546) -> void:
	var spotlight := Office.recruitment_spotlight(app.model)
	var player: Dictionary = spotlight.player
	var inner := w - 46
	var compact := w < 500
	if player.is_empty():
		D.photo(card,"scouting",Rect2(23,74,inner,116))
		D.text(card,23,231,spotlight.empty,27,C.IVORY,700,inner)
	else:
		var portrait := G.portrait(int(player.get("portraitIndex",0)),C.px(133),player)
		card.add_child(portrait)
		D.place(portrait,Rect2(22,74,133,117))
		var name := D.text(card,174,104,str(player.name).to_upper(),25 if compact else 29,C.IVORY,700,w-196)
		name.name = "OfficeSpotlightName"
		D.text(card,174,135,str(player.pos)+" · "+G.n(player.age)+" ans",22,C.MUTED,500,w-196)
		D.chip(card,Rect2(174,154,150,32),"NIV. "+G.rating_text(player),C.MINT)
		var available: bool = player.get("available", false)
		D.text(card,23,230,"Offre possible" if available else "Offre indisponible",24,C.MINT if available else C.ALERT,600,inner)
		var reason := str(player.get("reason", ""))
		if not reason.is_empty(): D.text(card,23,260,reason,20,C.MUTED,500,inner)
		var fee_w := roundi(inner * 0.44)
		D.text(card,23,336,G.euros(player.fee),28 if compact else 32,C.IVORY,600,fee_w)
		D.text(card,23+fee_w+10,336,G.salary(player.salary),24 if compact else 28,C.MUTED,500,inner-fee_w-10)
	if not str(spotlight.need).is_empty():
		D.text(card,23,295,spotlight.need,20,C.IVORY,500,inner,HORIZONTAL_ALIGNMENT_LEFT,true)
	D.button(card,Rect2(23,391,inner,39),"Ouvrir le recrutement" if player.is_empty() else "Voir le dossier",Office.open_spotlight.bind(app,str(player.get("id",""))),false,"arrow",true,app.accent,"OfficeMarketAction")

static func _timeline(card: Panel, app: Control, recent: PanelContainer, w: int = 2248) -> void:
	# En-tête : « Préparer la suite du club » à gauche de « Tout le calendrier », sans chevauchement
	# (ils se recouvraient : 1710..2220 et 1888..2223).
	var calendar_left := w - 360
	D.button(card, Rect2(calendar_left - 16 - 420, 10, 420, 42), "Préparer la suite du club", func(): load("res://ui/manager_planning.gd").open(app), false, "calendar", false, app.accent, "OfficeManagerPlanning")
	var all_fixtures := Office.upcoming_matches(app.model)
	# Autant de tuiles que la largeur en accueille (7 en pleine largeur, 5 à côté de Gabi), élargies au besoin.
	var fit := maxi(1, int((w - 28) / 316))
	var count := mini(all_fixtures.size(), fit)
	var fixtures := all_fixtures.slice(0, count)
	var step := floorf((w - 28.0) / fit) if count == fit else 316.0
	var extra := step - 316.0
	var tiles: Array[Panel] = []
	var grounds: Array[Label] = []
	for i in fixtures.size():
		var fixture: Dictionary = fixtures[i]
		var x := 20+i*step
		var at_home: bool = fixture.get("home",{}).get("id")==app.model.club.id
		var opponent: Dictionary = fixture.get("away",{}) if at_home else fixture.get("home",{})
		var location := P.fixture_location_kind(fixture, app.model.club.id)
		var place: String = {"neutral":"Neutre","home":"Domicile","away":"Extérieur"}.get(location,"Terrain à confirmer")
		var is_next := i == 0
		var border := C.GOLD if is_next else Office.UPCOMING_BORDER
		tiles.append(D.rect(card,Rect2(x,75,304+extra,132),Color("39301e") if is_next else Office.UPCOMING_TILE,5,border))
		var period := D.text(card,x+16,103,Office.timeline_period(fixture),21,C.GOLD,700,(174 if is_next else 244)+extra)
		if is_next: D.chip(card,Rect2(x+199+extra,84,89,25),"À SUIVRE",C.AMBER)
		var marker := C.icon(C.fixture_location_icon(location,true),48,C.GOLD)
		marker.name = "OfficeVenueIcon%d" % i
		card.add_child(marker)
		D.place(marker,Rect2(x+240+extra,120,48,48))
		period.name = "OfficeTimelineDate%d" % i
		var local_date := P.fixture_date(fixture, true)
		if not local_date.is_empty(): Office.describe_fixture(period, local_date)
		var fixture_key := str(fixture.get("id", fixture.get("date", ""))).validate_node_name()
		_label_reading(app,card,period,Office.date_reading_target(app,fixture),"OfficeTimelineDateLink_"+fixture_key,period.text)
		D.line(card,Vector2(x+14,118),Vector2(x+290+extra,118),Office.UPCOMING_BORDER)
		var crest := Office.opponent_crest(opponent,42)
		crest.name += str(i)
		card.add_child(crest)
		D.place(crest,Rect2(x+16,122,42,42))
		Office.reading_overlay(app,card,Rect2(x+16,122,42,42),Office.club_reading_target(app,opponent),"OfficeTimelineClubCrest_"+fixture_key,G.club_name(opponent))
		var name := D.text(card,x+64,151,G.club_name(opponent),23,C.IVORY,600,170+extra)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.max_lines_visible = 2
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.add_theme_constant_override("line_spacing",-C.px(2))
		D.place(name,Rect2(x+64,119,170+extra,50))
		Office.describe_fixture(name, name.text + " · " + place)
		_label_reading(app,card,name,Office.club_reading_target(app,opponent),"OfficeTimelineClubName_"+fixture_key,name.text)
		var label := Office.short_fixture_label(app.model,fixture)
		D.text(card,x+16,196,label+" · "+place,20,C.MUTED,500,272+extra)
		var venue := P.fixture_venue(fixture, false)
		var ground := D.text(card,x+16,232,venue if not venue.is_empty() else "Terrain à confirmer",22,C.MUTED,500,272+extra)
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
	var action := D.button(card,Rect2(calendar_left,15,335,32),"Tout le calendrier",func():app._navigate("Calendrier"),false,"arrow",true,app.accent,"OfficeCalendarAction")
	action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
