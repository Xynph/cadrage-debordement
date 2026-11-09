extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Manager = preload("res://ui/manager_career_view.gd")
const G = preload("res://ui/game_skin.gd")
const KEY = "immersive08_career_tab"
const PLAN_KEY = "immersive08_career_plan_index"

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveManagerCareer"
	var data: Dictionary = app.model.get("clubLife",{}).get("managerCareer",{})
	var tab := str(app.management_ui.get(KEY,"summary"))
	_hero(app,canvas,data)
	_tabs(app,canvas,tab)
	match tab:
		"plan": _plan(app,canvas,data)
		"details":
			var detail := Manager.build(app)
			U.place_detail(canvas, Rect2(0,439,2248,805), detail)
			Legacy.apply(detail,U.GREEN)
		_: _overview(app,canvas,data)

static func _hero(app: Control, canvas: Control, data: Dictionary) -> void:
	var hero := D.panel(canvas,Rect2(0,0,2248,227),"","","","CareerHero")
	hero.clip_contents = true
	var identity := G.identity(app.model.club)
	var city_art := str(identity.get("cityImage",""))
	var has_archive := not city_art.is_empty() and ResourceLoader.exists("res://"+city_art)
	if has_archive:
		var picture := G.picture(str(identity.get("slug","")),"city",false)
		hero.add_child(picture)
		D.place(picture,Rect2(980,1,1267,225))
	else:
		D.photo(hero,"club-forest",Rect2(980,1,1267,225))
	U.art_fade(hero,Rect2(980,1,1267,225))
	var crest := G.crest(app.model.club,C.px(124))
	hero.add_child(crest)
	D.place(crest,Rect2(26,46,124,135))
	D.line(hero,Vector2(180,41),Vector2(180,184),C.GOLD,2)
	U.italic(D.text(hero,211,52,"LE PARCOURS DU MANAGER",30,C.GOLD,700,470),700)
	D.line(hero,Vector2(597,35),Vector2(861,35),Color(C.GOLD,.65))
	D.text(hero,206,137,"Une carrière à écrire.",82,C.IVORY,800,1248)
	D.text(hero,211,178,G.club_name(app.model.club)+"  ·  "+P.league_name(app.model),26,C.IVORY,500,1248)
	var since: Variant = data.get("currentFrom",app.model.meta.get("season",1))
	D.chip(hero,Rect2(211,190,242,27),"MANDAT DEPUIS S"+G.n(since),C.GOLD)
	if has_archive:
		D.chip(hero,Rect2(2015,17,211,31),"PHOTO D’ARCHIVE",C.GOLD)

	var metrics := [
		["Places occupées","people","%s / %s" % [G.n(data.get("occupied","—")),G.n(data.get("capacity","—"))],C.IVORY],
		["Places disponibles","shield",G.n(data.get("places","—")),C.MINT],
		["Candidatures","mail",str(data.get("applications",[]).size()),C.IVORY],
		["Profils suivis","search",str(data.get("watch",[]).size()),C.MINT]
	]
	for i in metrics.size():
		var item: Array = metrics[i]
		var card := D.panel(canvas,Rect2(i*566,243,550,121),item[0],item[1],"","CareerMetric"+str(i))
		D.text(card,22,105,item[2],48,item[3],800,502)

static func _tabs(app: Control, canvas: Control, selected: String) -> void:
	var tabs := [["summary","Synthèse"],["plan","Plan sur trois saisons"],["details","Mobilité et recrutement"]]
	for i in tabs.size():
		var key: String = tabs[i][0]
		var id := "CareerTab_"+key
		U.tab(canvas,Rect2(i*353,380,343,45),tabs[i][1],selected == key,func(): U.select(app,KEY,key,id),id)

static func _overview(app: Control, canvas: Control, data: Dictionary) -> void:
	_mandate(D.panel(canvas,Rect2(0,441,855,526),"Mandat et mobilité","flag","","CareerMandate"),app,data)
	_seasons(D.panel(canvas,Rect2(871,441,1377,526),"Plan sur trois saisons","tactic","","CareerPlanSummary"),app,data)
	_history(D.panel(canvas,Rect2(0,983,1300,261),"Dernière prise de poste","clock","","CareerHistorySummary"),app,data)
	_recruitment(D.panel(canvas,Rect2(1316,983,932,261),"Le carnet du recrutement","search","","CareerRecruitmentSummary"),app,data)

static func _mandate(card: Panel, app: Control, data: Dictionary) -> void:
	var active: bool = data.get("active",false)
	var pending: Variant = data.get("pending")
	var window: bool = data.get("window",false)
	D.text(card,23,108,"VOTRE CLUB",25,C.GOLD,700,804)
	D.text(card,23,162,G.club_name(app.model.club),46,C.IVORY,700,803)
	D.text(card,23,198,"Mandat depuis la saison "+G.n(data.get("currentFrom",app.model.meta.get("season",1))),26,C.MUTED,500,804)
	D.line(card,Vector2(23,221),Vector2(832,221))
	var caption := "Candidatures ouvertes" if window else "Candidatures en fin de saison" if active else "Suivi des candidatures à activer"
	var subtitle := "La prise de poste est effective au passage à la saison suivante."
	if pending is Dictionary:
		caption = "Prochaine saison"
		subtitle = Manager._club(app,pending.toClub)
	D.text(card,23,274,caption,37,C.MINT if window else C.IVORY,700,804)
	D.text(card,23,315,subtitle,24,C.MUTED,500,804)
	if not active:
		var enable := D.button(card,Rect2(23,365,809,59),"Activer les candidatures",func(): app._command("manager_career_activate",{"context":data.get("context",{})}),true,"arrow",false,U.GREEN,"ManagerCareerActivate")
		enable.disabled = app.waiting or not data.get("available",false)
	D.button(card,Rect2(23,444,809,57),"Ouvrir les dossiers de mobilité",func(): U.select(app,KEY,"details","CareerTab_details"),active,"arrow",false,U.GREEN,"CareerMobility")

static func _seasons(card: Panel, app: Control, data: Dictionary) -> void:
	var plans: Array = data.get("plan",[])
	if plans.is_empty(): D.text(card,23,121,"Aucun engagement de saison à afficher.",29,C.MUTED,600,1327)
	for i in mini(3,plans.size()):
		var entry: Dictionary = plans[i]
		var tile := D.panel(card,Rect2(23+i*446,78,434,318),"","","","CareerYear"+G.n(entry.year))
		D.text(tile,22,58,"SAISON "+G.n(entry.year),34,C.IVORY,700,384)
		D.line(tile,Vector2(22,76),Vector2(412,76))
		var covered := int(entry.get("covered",0))
		D.text(tile,22,139,"%d / 15" % covered,50,C.MINT if covered==15 else C.AMBER,800,388)
		D.text(tile,22,172,"Postes couverts",23,C.MUTED,500,388)
		D.bar(tile,Rect2(22,189,390,9),100.0*covered/15,C.MINT if covered==15 else C.AMBER)
		D.text(tile,22,240,U.amount(entry.get("payroll")),36,C.IVORY,700,388)
		D.text(tile,22,272,"Salaires connus sur %s semaine(s)" % G.n(entry.get("payments","—")),22,C.MUTED,500,388)
		D.text(tile,22,301,"%s poste(s) avec moins de deux candidats" % G.n(entry.get("thin","—")),20,C.MUTED,500,388)
	D.button(card,Rect2(23,444,1330,57),"Examiner la couverture poste par poste",func(): U.select(app,KEY,"plan","CareerTab_plan"),true,"arrow",false,U.GREEN,"CareerOpenPlan")

static func _history(card: Panel, app: Control, data: Dictionary) -> void:
	var moves: Array = data.get("history",[])
	if moves.is_empty():
		D.text(card,23,125,"Premier mandat de la carrière",34,C.IVORY,700,1249)
		D.text(card,23,162,"Les changements de club seront consignés ici.",25,C.MUTED,500,1249)
	else:
		var move: Dictionary = moves[0]
		var origin := Manager._club(app,move.get("fromClub"))
		var destination := Manager._club(app,move.get("toClub"))
		D.text(card,23,123,origin+"  →  "+destination,34,C.IVORY,700,1249)
		D.text(card,23,160,"Prise de poste en saison "+G.n(move.get("arrivalSeason","—")),25,C.GOLD,600,1249)
	D.button(card,Rect2(23,186,1254,48),"Consulter le parcours et les archives",func(): U.select(app,KEY,"details","CareerTab_details"),false,"arrow",true,U.GREEN,"CareerOpenHistory")

static func _recruitment(card: Panel, app: Control, data: Dictionary) -> void:
	var profiles: Array = data.get("recruitment",[])
	var reports: Array = data.get("reports",[])
	D.text(card,23,122,"%d profils au carnet  ·  %d rapports datés" % [profiles.size(),reports.size()],33,C.IVORY,700,882)
	D.text(card,23,159,"Suivis, devis indicatifs et rapports d’observation.",24,C.MUTED,500,882)
	D.button(card,Rect2(23,186,886,48),"Ouvrir le carnet du recrutement",func(): U.select(app,KEY,"details","CareerTab_details"),false,"arrow",true,U.GREEN,"CareerOpenRecruitment")

static func _plan(app: Control, canvas: Control, data: Dictionary) -> void:
	var grid := D.panel(canvas,Rect2(0,441,1456,803),"Couverture de l’effectif","tactic","","CareerCoverageTable")
	var plans: Array = data.get("plan",[])
	if plans.is_empty():
		D.text(grid,23,126,"Aucun plan de succession disponible.",32,C.MUTED,600,1406)
		return
	var index := clampi(int(app.management_ui.get(PLAN_KEY,0)),0,plans.size()-1)
	var entry: Dictionary = plans[index]
	for i in plans.size():
		var id := "CareerPlanYear"+str(i)
		D.button(grid,Rect2(701+i*243,10,230,36),"Saison "+G.n(plans[i].year),func():
			app.management_ui[PLAN_KEY] = i
			app._render()
			U.focus(app,id),i==index,"",true,U.GREEN,id)
	D.rect(grid,Rect2(13,65,1430,38),Color("1a2929"),3)
	for pair: Array in [["N°",25],["POSTE",111],["CANDIDATS SOUS CONTRAT",686],["COUVERTURE",1123]]:
		D.text(grid,pair[1],91,pair[0],21,C.MUTED,700,330)
	var slots: Array = entry.get("slots",[])
	var gaps: Array = entry.get("gaps",[])
	for i in mini(15,slots.size()):
		var slot: Dictionary = slots[i]
		var y := 107+i*44
		if i%2==0: D.rect(grid,Rect2(14,y,1428,42),Color("142021"))
		D.text(grid,25,y+31,"%02d" % (int(slot.get("slot",i))+1),23,C.MUTED,600,67)
		D.text(grid,111,y+31,slot.get("pos","—"),25,C.IVORY,700,545)
		var count := int(slot.get("count",0))
		D.text(grid,795,y+31,count,26,C.IVORY,600,210,HORIZONTAL_ALIGNMENT_CENTER)
		var gap := int(slot.get("slot",i)) in gaps
		var badge := "À couvrir" if gap else "Un candidat" if count == 1 else "Couvert"
		D.chip(grid,Rect2(1123,y+6,295,30),badge,C.ALERT if gap else C.AMBER if count == 1 else C.MINT)
	var side := D.panel(canvas,Rect2(1472,441,776,803),"Engagements connus","money","","CareerCoverageContext")
	D.text(side,23,115,"SAISON "+G.n(entry.year),31,C.GOLD,700,726)
	D.text(side,23,174,U.amount(entry.get("payroll")),55,C.IVORY,800,726)
	D.text(side,23,211,"Masse salariale connue sur %s semaine(s)" % G.n(entry.get("payments","—")),25,C.MUTED,500,726)
	D.line(side,Vector2(23,233),Vector2(753,233))
	D.text(side,23,284,"%s / 15 postes couverts" % G.n(entry.get("covered","—")),37,C.MINT if int(entry.get("covered",0)) == 15 else C.AMBER,700,726)
	D.text(side,23,328,"%s poste(s) avec moins de deux candidats" % G.n(entry.get("thin","—")),25,C.MUTED,500,726)
	var notes := C.wrap(data.get("planNotice",""),20,C.MUTED)
	side.add_child(notes)
	D.place(notes,Rect2(23,360,730,125))
	D.photo(side,"scouting",Rect2(23,488,730,198))
	D.button(side,Rect2(23,713,730,58),"Ouvrir le recrutement",func(): app._navigate("Recrutement"),true,"arrow",false,U.GREEN,"CareerRecruitmentAction")
