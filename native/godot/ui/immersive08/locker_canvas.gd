extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Relations = preload("res://ui/relationships_view.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const R = preload("res://ui/immersive08/reperes.gd")
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
	var art := _art(app.model)
	var photo := D.photo(hero,art,Rect2(986,1,1261,225))
	var identite := G.identity(app.model.get("club", {}))
	var RI = preload("res://ui/contextual/rooms/room_identity.gd")
	BanqueImages.recolorer(photo, art, RI.primary(identite), RI.secondary(identite))
	U.art_fade(hero,Rect2(986,1,1261,225))
	D.text(hero,26,80,"LE VESTIAIRE",64,C.IVORY,700,900).add_theme_font_override("font",Charte.TITRE_FICHE)
	D.text(hero,26,130,G.club_name(app.model.club)+"  ·  "+str(app.model.meta.get("roundLabel","La semaine du groupe")),26,C.IVORY,600,1225)
	var stage := "DÉCISIONS OUVERTES" if data.get("available",false) else "DÉCISIONS INDISPONIBLES"
	D.chip(hero,Rect2(26,146,263,29),stage,C.MINT if data.get("available",false) else C.AMBER)

	var open := 0
	for item: Dictionary in data.get("commitments",[]):
		if item.get("status") == "open": open += 1
	var leader := P.player(app.model,str(data.get("leaderId","")))
	# Confiance des joueurs envers le manager (moteur, 21/11/2026) : celle du conseil reste dans Club › Direction.
	var tensions: Dictionary = data.get("tensions",{}) if data.get("tensions") is Dictionary else {}
	var niveau := int(tensions.get("level",0))
	var Panneaux = load("res://ui/immersive08/panneaux_effectif.gd")
	var metrics := [
		["Moral du groupe","heart",_score(data.get("morale")),Charte.MORAL],
		["Confiance des joueurs","shield",_score(data.get("playerTrust")),Charte.CONFIANCE],
		["Tensions","warning","%s · %d" % [Panneaux.NIVEAUX[clampi(niveau,0,3)],tensions.get("players",[]).size()],Panneaux._couleur_niveau(niveau) if niveau > 0 else C.MUTED],
		["Engagements en cours","calendar",G.n(open),C.MINT],
		["Relais pressenti","star",leader.get("name","À déterminer"),C.IVORY]
	]
	var cartes: Array = []
	for i in metrics.size():
		var item: Array = metrics[i]
		var card := D.panel(canvas,Rect2(i*452,243,440,121),item[0],item[1],"","LockerMetric"+str(i))
		D.text(card,22,105,item[2],34 if i in [2,4] else 47,item[3],700,400)
		cartes.append(card)
	R.cliquable(cartes[2],func(): Panneaux.fenetre_tensions(canvas,app),"LockerTensionsOuvrir","Tensions")
	if not leader.is_empty():
		var rid := str(leader.get("id",""))
		R.cliquable(cartes[4],func():
			app.selected_player = rid
			app.navigation_controller.open_entity({"kind":"player","id":rid,"section":""}),"LockerRelaisOuvrir",str(leader.get("name","")))

static func _score(value: Variant) -> String:
	return "%s / 100" % G.n(value) if value != null else "—"

## Vestiaire de la banque d'images selon le dernier résultat du club (victoire, défaite ; sinon avant-match),
## puis l'ancienne illustration en repli.
static func _art(model: Dictionary = {}) -> String:
	var id := BanqueImages.choisir("vestiaire", {"phase": "post", "resultat": dernier_resultat(model)})
	if id.is_empty() or dernier_resultat(model) in ["", "nul"]: id = BanqueImages.choisir("vestiaire", {"phase": "pre"})
	if not id.is_empty() and BanqueImages.texture(id) != null: return id
	return "lockerroom" if ResourceLoader.exists(LOCKER_ART) else "tactics-briefing"

## Dernier résultat du club au classement (`form`, du plus ancien au plus récent ; lettres V/N/D ou W/D/L).
static func dernier_resultat(model: Dictionary) -> String:
	if model.is_empty() or not model.get("club") is Dictionary: return ""
	for row: Variant in P.standings(model):
		if not row is Dictionary or row.get("id") != model.club.get("id"): continue
		var form: Array = row.get("form", []) if row.get("form") is Array else []
		if form.is_empty(): return ""
		var anglais := "W" in form or "L" in form
		var x := str(form[-1])
		if x in ["V", "W"]: return "victoire"
		if x == "L" or (x == "D" and not anglais): return "defaite"
		return "nul"
	return ""

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
		D.text(card,166,177,"%s  ·  Leadership %s / 100" % [event.get("trait","Personnalité"),G.n(event.get("leadership","—"))],23,C.MUTED,500,1120,HORIZONTAL_ALIGNMENT_LEFT,true)
		Pastilles.poser(card, Relations.contexte(app, event), 23, 196)
		var choices: Array = event.get("choices",[])
		for i in mini(3,choices.size()):
			var choice: Dictionary = choices[i]
			var y := 272+i*78
			var key := str(choice.id)
			var action := _action(card,Rect2(23,y,442,62),CHOICES.get(key,choice.label),func(): app._command("locker_room_decision",{"context":context,"eventKey":event.key,"choice":key}),"LockerDecision_"+key)
			action.disabled = app.waiting or not event.get("available",false)
			var effets := Relations.effets(str(choice.get("detail","")))
			effets.name = "LockerEffects_" + key
			Pastilles.poser(card, effets, 489, y + 14)
		if not event.get("available",false): Pastilles.poser(card, Pastilles.pastille("Choix indisponibles", Pastilles.ORANGE, "warning", str(data.get("reason","Les choix sont indisponibles dans cette phase.")), 22, "LockerUnavailable"), 23, 486)
	else:
		D.photo(card,_art(app.model),Rect2(22,74,1283,222))
		D.text(card,23,358,"Aucun entretien hebdomadaire à traiter",38,C.IVORY,700,1278)
		_action(card,Rect2(23,433,484,57),"Consulter les dossiers du groupe",func(): U.select(app,KEY,"people","LockerTab_people"),"LockerOpenPeople")

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
		var activate := _action(card,Rect2(23,380,858,54),"Activer le suivi du vestiaire",func(): app._command("relationship_activate",{"context":data.get("context",{})}),"ActivateRelationships")
		activate.disabled = app.waiting or not data.get("available",false)
	_action(card,Rect2(23,445,858,59),"Ouvrir les entretiens, promesses et duos",func(): U.select(app,KEY,"people","LockerTab_people"),"LockerPeopleDetail")

static func _commitments(card: Panel, app: Control, data: Dictionary, limit: int, overview: bool) -> void:
	var commitments: Array = data.get("commitments",[]).duplicate()
	commitments.reverse()
	if commitments.is_empty(): D.text(card,23,116,"Aucun engagement",28,C.MUTED,600,1280,HORIZONTAL_ALIGNMENT_LEFT,true)
	for i in mini(limit,commitments.size()):
		var entry: Dictionary = commitments[i]
		var status := str(entry.get("status","open"))
		var color := C.MINT if status == "honored" else C.ALERT if status == "broken" else C.AMBER
		var y := 68+i*61
		D.text(card,23,y+23,_name(app.model,entry.get("playerId")),27,C.IVORY,700,465)
		D.text(card,23,y+49,"%s min · semaine de carrière %s" % [G.n(entry.get("target","—")),G.n(int(entry.get("dueWeek",0))+1)],21,C.MUTED,500,595,HORIZONTAL_ALIGNMENT_LEFT,true)
		D.chip(card,Rect2(1052,y+9,251,33),STATUSES.get(status,status),color)
		D.line(card,Vector2(23,y+56),Vector2(1303,y+56),Color(C.LINE,.55))
	if overview:
		_action(card,Rect2(23,205,1280,40),"Voir les engagements et décisions passées",func(): U.select(app,KEY,"history","LockerTab_history"),"LockerHistoryAction",true)

static func _recent(card: Panel, app: Control, data: Dictionary) -> void:
	var events: Array = data.get("history",[])
	if events.is_empty():
		D.text(card,23,117,"Aucune décision",28,C.MUTED,600,850,HORIZONTAL_ALIGNMENT_LEFT,true)
		return
	var entry: Dictionary = events[0]
	D.text(card,23,100,"SAISON %s  ·  SEMAINE %s" % [G.season_label(entry.get("season","—")),G.n(int(entry.get("week",0))+1)],22,C.GOLD,700,846)
	D.text(card,23,145,_name(app.model,entry.get("playerId")),32,C.IVORY,700,846)
	D.text(card,23,183,entry.get("title","Entretien"),24,C.MUTED,500,846,HORIZONTAL_ALIGNMENT_LEFT,true)
	D.text(card,23,221,CHOICES.get(entry.get("choice"),"Décision consignée"),25,C.MINT,600,846)

static func _history(app: Control, canvas: Control, data: Dictionary) -> void:
	_commitments(D.panel(canvas,Rect2(0,441,1328,803),"Engagements de vestiaire","calendar","","LockerCommitmentHistory"),app,data,11,false)
	var events: Array = data.get("history",[])
	var card := D.panel(canvas,Rect2(1344,441,904,803),"Journal du vestiaire","clock","","LockerDecisionHistory")
	if events.is_empty(): D.text(card,23,112,"Aucune décision",28,C.MUTED,600,850,HORIZONTAL_ALIGNMENT_LEFT,true)
	for i in mini(8,events.size()):
		var entry: Dictionary = events[i]
		var y := 68+i*88
		D.text(card,23,y+22,"SAISON %s  ·  SEMAINE %s" % [G.season_label(entry.get("season","—")),G.n(int(entry.get("week",0))+1)],21,C.GOLD,700,850)
		D.text(card,23,y+48,_name(app.model,entry.get("playerId"))+"  ·  "+str(CHOICES.get(entry.get("choice"),"Décision consignée")),25,C.IVORY,600,850)
		D.text(card,23,y+73,entry.get("title","Entretien"),21,C.MUTED,500,850,HORIZONTAL_ALIGNMENT_LEFT,true)
		D.line(card,Vector2(23,y+81),Vector2(881,y+81),Color(C.LINE,.55))

## Action secondaire : pilule à contour (charte), texte centré ; le doré reste à Continuer.
static func _action(parent: Node, rectangle: Rect2, caption: String, callback: Callable, id: String, small: bool = false) -> Button:
	var control := D.button(parent, rectangle, caption, callback, false, "", small, U.GREEN, id)
	C.style_bouton_contour(control, 20 if small else 23)
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return control
