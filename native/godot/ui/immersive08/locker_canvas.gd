extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Relations = preload("res://ui/relationships_view.gd")
const G = preload("res://ui/game_skin.gd")
const KEY = "immersive08_locker_tab"
const LOCKER_ART = "res://art/immersive08/lockerroom.png"
const STATUSES = {"open":"À suivre", "honored":"Honoré", "broken":"Non tenu", "expired":"Clos sans pénalité"}
const CHOICES = {"ecouter":"Écouter", "cadrer":"Rappeler les exigences", "responsabiliser":"Confier un rôle"}

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveLockerRoom"
	var data: Dictionary = app.model.get("clubLife",{}).get("relationships",{})
	var tab := str(app.management_ui.get(KEY,"week"))
	_hero(app,canvas,data)
	_tabs(app,canvas,tab)
	match tab:
		"people":
			var detail := Relations.build(app)
			U.place_detail(canvas, Rect2(0,439,2248,805), detail)
			Legacy.apply(detail,U.GREEN)
		"history": _history(app,canvas,data)
		_: _overview(app,canvas,data)

static func _hero(app: Control, canvas: Control, data: Dictionary) -> void:
	var hero := D.panel(canvas,Rect2(0,0,2248,227),"","","","LockerHero")
	hero.clip_contents = true
	var art := _art()
	D.photo(hero,art,Rect2(986,1,1261,225))
	U.art_fade(hero,Rect2(986,1,1261,225))
	D.chip(hero,Rect2(2043,16,182,28),"ILLUSTRATION",C.GOLD)
	D.scenario_photo(hero, "sneaker", Rect2(1950, 53, 275, 161))
	U.italic(D.text(hero,26,43,"LE VESTIAIRE",30,C.GOLD,700,375),700)
	D.line(hero,Vector2(237,28),Vector2(661,28),Color(C.GOLD,.65))
	D.text(hero,23,124,"Un groupe, une ambition.",82,C.IVORY,800,1195)
	D.text(hero,26,175,G.club_name(app.model.club)+"  ·  "+str(app.model.meta.get("roundLabel","La semaine du groupe")),26,C.MUTED,500,1225)
	var stage := "DÉCISIONS OUVERTES" if data.get("available",false) else "DÉCISIONS INDISPONIBLES"
	D.chip(hero,Rect2(26,187,263,29),stage,C.MINT if data.get("available",false) else C.AMBER)

	var open := 0
	for item: Dictionary in data.get("commitments",[]):
		if item.get("status") == "open": open += 1
	var leader := P.player(app.model,str(data.get("leaderId","")))
	var metrics := [
		["Moral du groupe","heart",_score(data.get("morale")),C.MINT],
		["Confiance du conseil","shield",_score(data.get("trust")),C.GOLD],
		["Engagements en cours","calendar",G.n(open),C.MINT],
		["Relais pressenti","star",leader.get("name","À déterminer"),C.IVORY]
	]
	for i in metrics.size():
		var item: Array = metrics[i]
		var card := D.panel(canvas,Rect2(i*566,243,550,121),item[0],item[1],"","LockerMetric"+str(i))
		D.text(card,22,105,item[2],38 if i == 3 else 47,item[3],700,502)

static func _score(value: Variant) -> String:
	return "%s / 100" % G.n(value) if value != null else "—"

static func _art() -> String:
	return "lockerroom" if ResourceLoader.exists(LOCKER_ART) else "tactics-briefing"

static func _name(model: Dictionary, id: Variant) -> String:
	if id == null: return "Aucun relais disponible"
	return str(P.player(model,str(id)).get("name","Joueur parti du club"))

static func _tabs(app: Control, canvas: Control, selected: String) -> void:
	var tabs := [["week","Cette semaine"],["people","Entretiens et duos"],["history","Engagements et historique"]]
	for i in tabs.size():
		var key: String = tabs[i][0]
		var id := "LockerTab_"+key
		U.tab(canvas,Rect2(i*344,380,334,45),tabs[i][1],selected == key,func(): U.select(app,KEY,key,id),id)

static func _overview(app: Control, canvas: Control, data: Dictionary) -> void:
	_event(D.panel(canvas,Rect2(0,441,1328,526),"La décision de la semaine","mail","","LockerWeeklyEvent"),app,data)
	_group(D.panel(canvas,Rect2(1344,441,904,526),"Les personnes et les liens","people","","LockerGroup"),app,data)
	_commitments(D.panel(canvas,Rect2(0,983,1328,261),"Engagements de vestiaire","calendar","","LockerOverviewCommitments"),app,data,2,true)
	_recent(D.panel(canvas,Rect2(1344,983,904,261),"Dernière décision enregistrée","clock","","LockerLastDecision"),app,data)

static func _event(card: Panel, app: Control, data: Dictionary) -> void:
	var event: Variant = data.get("event")
	var context: Dictionary = data.get("context",{})
	if event is Dictionary:
		var member := P.player(app.model,str(event.get("playerId","")))
		if not member.is_empty():
			var portrait := G.portrait(int(member.get("portraitIndex",0)),C.px(125),member)
			card.add_child(portrait)
			D.place(portrait,Rect2(22,73,125,118))
		D.text(card,166,110,event.get("title","Point de vestiaire"),36,C.IVORY,700,1134)
		D.text(card,166,146,_name(app.model,event.get("playerId")),26,C.GOLD,600,1120)
		D.text(card,166,177,"%s  ·  Leadership %s / 100" % [event.get("trait","Personnalité"),G.n(event.get("leadership","—"))],23,C.MUTED,500,1120)
		var lines := D.words(str(event.get("context","")),102,2)
		for i in lines.size(): D.text(card,23,219+i*26,lines[i],24,C.IVORY,500,1278)
		var choices: Array = event.get("choices",[])
		for i in mini(3,choices.size()):
			var choice: Dictionary = choices[i]
			var y := 272+i*78
			var key := str(choice.id)
			var action := D.button(card,Rect2(23,y,442,62),CHOICES.get(key,choice.label),func(): app._command("locker_room_decision",{"context":context,"eventKey":event.key,"choice":key}),i==0,"arrow",false,U.GREEN,"LockerDecision_"+key)
			action.disabled = app.waiting or not event.get("available",false)
			var notes := D.words(str(choice.get("detail","")),65,2)
			for j in notes.size(): D.text(card,489,y+26+j*24,notes[j],22,C.MUTED,500,812)
		if not event.get("available",false): D.text(card,23,512,data.get("reason","Les choix sont indisponibles dans cette phase."),22,C.AMBER,600,1278)
	else:
		D.photo(card,_art(),Rect2(22,74,1283,222))
		D.text(card,23,358,"Aucun entretien hebdomadaire à traiter",38,C.IVORY,700,1278)
		D.text(card,23,404,"Les entretiens individuels et les duos restent dans les dossiers du groupe.",24,C.MUTED,500,1278)
		D.button(card,Rect2(23,433,484,57),"Consulter les dossiers du groupe",func(): U.select(app,KEY,"people","LockerTab_people"),true,"arrow",false,U.GREEN,"LockerOpenPeople")

static func _group(card: Panel, app: Control, data: Dictionary) -> void:
	var players: Array = data.get("players",[])
	var ready := players.filter(func(person: Dictionary): return person.get("conversationAvailable",false)).size()
	var pairs: Array = data.get("pairs",[])
	var leader := _name(app.model,data.get("leaderId"))
	D.text(card,23,113,"RELAIS PRESSENTI",24,C.GOLD,700,843)
	D.text(card,23,166,leader,49,C.IVORY,700,843)
	D.line(card,Vector2(23,188),Vector2(881,188))
	var rows := [["Entretiens possibles",ready],["Liens suivis",pairs.size()],["Joueurs du groupe",players.size()]]
	for i in rows.size():
		var y := 235+i*57
		D.text(card,23,y,rows[i][0],28,C.IVORY,600,650)
		D.text(card,879,y,rows[i][1],31,C.MINT,700,180,HORIZONTAL_ALIGNMENT_RIGHT)
		D.line(card,Vector2(23,y+15),Vector2(881,y+15),Color(C.LINE,.55))
	if not data.get("active",false):
		var activate := D.button(card,Rect2(23,380,858,54),"Activer le suivi du vestiaire",func(): app._command("relationship_activate",{"context":data.get("context",{})}),true,"arrow",false,U.GREEN,"ActivateRelationships")
		activate.disabled = app.waiting or not data.get("available",false)
	D.button(card,Rect2(23,445,858,59),"Ouvrir les entretiens, promesses et duos",func(): U.select(app,KEY,"people","LockerTab_people"),true,"arrow",false,U.GREEN,"LockerPeopleDetail")

static func _commitments(card: Panel, app: Control, data: Dictionary, limit: int, overview: bool) -> void:
	var commitments: Array = data.get("commitments",[]).duplicate()
	commitments.reverse()
	if commitments.is_empty(): D.text(card,23,116,"Aucun engagement de vestiaire enregistré.",28,C.MUTED,600,1280)
	for i in mini(limit,commitments.size()):
		var entry: Dictionary = commitments[i]
		var status := str(entry.get("status","open"))
		var color := C.MINT if status == "honored" else C.ALERT if status == "broken" else C.AMBER
		var y := 68+i*61
		D.text(card,23,y+23,_name(app.model,entry.get("playerId")),27,C.IVORY,700,465)
		D.text(card,23,y+49,"%s min · semaine de carrière %s" % [G.n(entry.get("target","—")),G.n(int(entry.get("dueWeek",0))+1)],21,C.MUTED,500,595)
		D.chip(card,Rect2(1052,y+9,251,33),STATUSES.get(status,status),color)
		D.line(card,Vector2(23,y+56),Vector2(1303,y+56),Color(C.LINE,.55))
	if overview:
		D.button(card,Rect2(23,205,1280,40),"Voir les engagements et décisions passées",func(): U.select(app,KEY,"history","LockerTab_history"),false,"arrow",true,U.GREEN,"LockerHistoryAction")

static func _recent(card: Panel, app: Control, data: Dictionary) -> void:
	var events: Array = data.get("history",[])
	if events.is_empty():
		D.text(card,23,117,"Aucune décision archivée.",28,C.MUTED,600,850)
		return
	var entry: Dictionary = events[0]
	D.text(card,23,100,"SAISON %s  ·  SEMAINE %s" % [G.n(entry.get("season","—")),G.n(int(entry.get("week",0))+1)],22,C.GOLD,700,846)
	D.text(card,23,145,_name(app.model,entry.get("playerId")),32,C.IVORY,700,846)
	D.text(card,23,183,entry.get("title","Entretien"),24,C.MUTED,500,846)
	D.text(card,23,221,CHOICES.get(entry.get("choice"),"Décision consignée"),25,C.MINT,600,846)

static func _history(app: Control, canvas: Control, data: Dictionary) -> void:
	_commitments(D.panel(canvas,Rect2(0,441,1328,803),"Engagements de vestiaire","calendar","","LockerCommitmentHistory"),app,data,11,false)
	var events: Array = data.get("history",[])
	var card := D.panel(canvas,Rect2(1344,441,904,803),"Journal du vestiaire","clock","","LockerDecisionHistory")
	if events.is_empty(): D.text(card,23,112,"Aucune décision archivée.",28,C.MUTED,600,850)
	for i in mini(8,events.size()):
		var entry: Dictionary = events[i]
		var y := 68+i*88
		D.text(card,23,y+22,"SAISON %s  ·  SEMAINE %s" % [G.n(entry.get("season","—")),G.n(int(entry.get("week",0))+1)],21,C.GOLD,700,850)
		D.text(card,23,y+48,_name(app.model,entry.get("playerId"))+"  ·  "+str(CHOICES.get(entry.get("choice"),"Décision consignée")),25,C.IVORY,600,850)
		D.text(card,23,y+73,entry.get("title","Entretien"),21,C.MUTED,500,850)
		D.line(card,Vector2(23,y+81),Vector2(881,y+81),Color(C.LINE,.55))
