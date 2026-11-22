extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Manager = preload("res://ui/manager_career_view.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const KEY = "immersive08_career_tab"
const PLAN_KEY = "immersive08_career_plan_index"

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveManagerCareer"
	var data: Dictionary = app.model.get("clubLife",{}).get("managerCareer",{})
	var tab := str(app.management_ui.get(KEY,"summary"))
	# Synthèse « façon Effectif » (choix de Léo du 22/11/2026) ; Plan et Mobilité gardent leur page.
	if tab not in ["plan","details"]:
		load("res://ui/immersive08/career_synthese.gd").construire(app,canvas,data)
		return
	_hero(app,canvas,data)
	_tabs(app,canvas,tab)
	match tab:
		"plan": _plan(app,canvas,data)
		"details":
			var detail := Manager.build(app)
			U.place_detail(canvas, Rect2(0,439,2248,805), detail)
			Legacy.apply(detail,U.GREEN)

static func _hero(app: Control, canvas: Control, data: Dictionary) -> void:
	_bandeau_photo(app,canvas,data)
	_metriques(app,canvas,data)

## Bandeau photo du héros : blason, titre, club et ligue, mandat, crédit photo.
static func _bandeau_photo(app: Control, canvas: Control, data: Dictionary) -> void:
	var hero := D.panel(canvas,Rect2(0,0,2248,227),"","","","CareerHero")
	hero.clip_contents = true
	var picture := G.club_picture(app.model.club, "city", false)
	hero.add_child(picture)
	D.place(picture,Rect2(980,1,1267,225))
	U.art_fade(hero,Rect2(980,1,1267,225))
	var crest := G.crest(app.model.club,C.px(124))
	hero.add_child(crest)
	D.place(crest,Rect2(26,46,124,135))
	D.line(hero,Vector2(180,41),Vector2(180,184),C.GOLD,2)
	D.text(hero,211,128,"LE PARCOURS DU MANAGER",70,C.IVORY,700,1248).add_theme_font_override("font",Charte.TITRE_FICHE)
	D.text(hero,211,178,G.club_name(app.model.club)+"  ·  "+P.league_name(app.model),28,C.IVORY,600,1248,HORIZONTAL_ALIGNMENT_LEFT,true)
	var since: Variant = data.get("currentFrom",app.model.meta.get("season",1))
	D.chip(hero,Rect2(211,190,242,27),"MANDAT DEPUIS S"+G.n(since),C.GOLD)
	# Immersion : pas d'étiquette de provenance (pack, archive) ; seul le crédit reste, au survol.
	if not picture.tooltip_text.is_empty():
		var credit := D.chip(hero,Rect2(2015,17,211,31),"CRÉDIT PHOTO",C.GOLD)
		credit.mouse_filter = Control.MOUSE_FILTER_PASS
		credit.tooltip_text = picture.tooltip_text
		credit.accessibility_name = credit.tooltip_text.replace("\n", " · ")

static func _metriques(app: Control, canvas: Control, data: Dictionary) -> void:
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
		Pieces.rendre_cliquable(card,Vector2(550,121),func(): U.select(app,KEY,"details","CareerTab_details"),"CareerMetricLien"+str(i),"%s %s" % [item[2],item[0]],"",Charte.RAYON_PANNEAU)

static func _tabs(app: Control, canvas: Control, selected: String) -> void:
	var tabs := [["summary","Synthèse"],["plan","Plan sur trois saisons"],["details","Mobilité et recrutement"]]
	for i in tabs.size():
		var key: String = tabs[i][0]
		var id := "CareerTab_"+key
		U.tab(canvas,Rect2(i*353,380,343,45),tabs[i][1],selected == key,func(): U.select(app,KEY,key,id),id)

static func _pastilles_saison(parent: Control, x: float, y: float, entry: Dictionary, action: Callable) -> void:
	var semaines := int(entry.get("payments",0))
	var fragiles := int(entry.get("thin",0))
	var largeur := Pieces.pastille(parent,x,y,"%d sem." % semaines,"calendar","CareerWeeks"+G.n(entry.year),"Salaires connus sur %d %s." % [semaines,"semaine" if semaines <= 1 else "semaines"],Pieces.BLEU,Charte.PANNEAU_3,action)
	var texte := "%d %s < 2 candidats" % [fragiles,"poste" if fragiles <= 1 else "postes"] if fragiles > 0 else "Tous couverts"
	Pieces.pastille(parent,x+largeur+8,y,texte,"warning" if fragiles > 0 else "check","CareerThin"+G.n(entry.year),"Postes avec moins de deux candidats : %d." % fragiles,Pieces.ORANGE if fragiles > 0 else Pieces.VERT,Charte.PANNEAU_3,action)

static func _plan(app: Control, canvas: Control, data: Dictionary) -> void:
	var grid := D.panel(canvas,Rect2(0,441,1456,803),"Couverture de l’effectif","tactic","","CareerCoverageTable")
	var plans: Array = data.get("plan",[])
	if plans.is_empty():
		D.text(grid,23,126,"Aucun plan de succession disponible.",32,C.MUTED,600,1406,HORIZONTAL_ALIGNMENT_LEFT,true)
		return
	var index := clampi(int(app.management_ui.get(PLAN_KEY,0)),0,plans.size()-1)
	var entry: Dictionary = plans[index]
	for i in plans.size():
		var id := "CareerPlanYear"+str(i)
		var annee := _action(grid,Rect2(701+i*243,10,230,36),"Saison "+G.season_label(plans[i].year),func():
			app.management_ui[PLAN_KEY] = i
			app._render()
			U.focus(app,id),id,true)
		D.tab_state(annee,Vector2(230,36),i==index,"")
		annee.icon = null
	D.rect(grid,Rect2(13,65,1430,38),Color("1a2929"),3)
	for pair: Array in [["N°",25],["POSTE",111],["CANDIDATS SOUS CONTRAT",686],["COUVERTURE",1123]]:
		D.text(grid,pair[1],91,pair[0],21,C.MUTED,700,330)
	var slots: Array = entry.get("slots",[])
	var gaps: Array = entry.get("gaps",[])
	for i in mini(15,slots.size()):
		var slot: Dictionary = slots[i]
		var y := 107+i*44
		var rayure = load("res://ui/survol_ligne.gd").rayure(grid,i)
		if rayure != null: D.place(rayure,Rect2(14,y,1428,42))
		D.text(grid,25,y+31,"%02d" % (int(slot.get("slot",i))+1),23,C.MUTED,600,67,HORIZONTAL_ALIGNMENT_LEFT,true)
		D.text(grid,111,y+31,slot.get("pos","—"),25,C.IVORY,700,545)
		var count := int(slot.get("count",0))
		D.text(grid,795,y+31,count,26,C.IVORY,600,210,HORIZONTAL_ALIGNMENT_CENTER)
		var gap := int(slot.get("slot",i)) in gaps
		var badge := "À couvrir" if gap else "Un candidat" if count == 1 else "Couvert"
		D.chip(grid,Rect2(1123,y+6,295,30),badge,C.ALERT if gap else C.AMBER if count == 1 else C.MINT)
	var side := D.panel(canvas,Rect2(1472,441,776,803),"Engagements connus","money","","CareerCoverageContext")
	D.text(side,23,115,"SAISON "+G.season_label(entry.year),31,C.GOLD,700,726)
	D.text(side,23,174,U.amount(entry.get("payroll")),55,C.IVORY,800,726)
	Pieces.info(side,23+minf(560.0,Pieces.largeur_titre(U.amount(entry.get("payroll")),55))+18,148,str(data.get("planNotice","")),"Engagements")
	_pastilles_saison(side,23,196,entry,func(): app._navigate("Recrutement"))
	D.line(side,Vector2(23,233),Vector2(753,233))
	D.text(side,23,284,"%s / 15 postes couverts" % G.n(entry.get("covered","—")),37,C.MINT if int(entry.get("covered",0)) == 15 else C.AMBER,700,726)
	D.photo(side,"scouting",Rect2(23,320,730,370))
	_action(side,Rect2(23,713,730,58),"Ouvrir le recrutement",func(): app._navigate("Recrutement"),"CareerRecruitmentAction")

## Action secondaire : pilule à contour (charte), texte centré ; le doré reste à Continuer.
static func _action(parent: Node, rectangle: Rect2, caption: String, callback: Callable, id: String, small: bool = false) -> Button:
	var control := D.button(parent, rectangle, caption, callback, false, "", small, U.GREEN, id)
	C.style_bouton_contour(control, 20 if small else 23)
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return control
