extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Tactics = preload("res://ui/immersive08/tactics_canvas.gd")
const Training = preload("res://ui/immersive08/training_canvas.gd")
const Notes = preload("res://ui/coach_notes_view.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")

class ConditionDial extends Control:
	var condition := 0.0
	var ink := C.MINT

	func _draw() -> void:
		var radius := size.x * .43
		var width := maxf(1, C.px(7))
		draw_arc(size * .5, radius, -PI * .5, PI * 1.5, 64, C.LINE, width, true)
		if condition > 0:
			draw_arc(size * .5, radius, -PI * .5, -PI * .5 + TAU * condition / 100.0, 64, ink, width, true)

class PositionPitch extends Control:
	const MARKS = [Vector2(.25,.14), Vector2(.5,.14), Vector2(.75,.14), Vector2(.38,.27), Vector2(.62,.27),
		Vector2(.25,.40), Vector2(.75,.40), Vector2(.5,.40), Vector2(.4,.53), Vector2(.6,.62),
		Vector2(.12,.75), Vector2(.36,.75), Vector2(.64,.75), Vector2(.88,.75), Vector2(.5,.88)]
	var primary_slot := 0

	func _point(x: float, y: float) -> Vector2:
		var margin := lerpf(.12,.025,y)
		return Vector2(lerpf(margin,1.0-margin,x)*size.x,lerpf(.05,.95,y)*size.y)

	func _draw() -> void:
		var factor := size.x/432.0
		var stroke := maxf(1.0,factor)
		var outline := PackedVector2Array([_point(0,0),_point(1,0),_point(1,1),_point(0,1)])
		draw_colored_polygon(outline,Color("14452e"))
		outline.append(outline[0])
		draw_polyline(outline,Color(C.IVORY,.85),stroke*1.5,true)
		for row in [.13,.32,.50,.68,.87]:
			draw_line(_point(0,row),_point(1,row),Color(C.IVORY,.48),stroke,true)
		for row in [.23,.42,.58,.77]:
			for segment in 12:
				draw_line(_point(segment/12.0,row),_point((segment+.46)/12.0,row),Color(C.IVORY,.37),stroke,true)
		for end in [0.0,1.0]:
			var inside := .13 if end==0.0 else .87
			for side in [.445,.555]: draw_line(_point(side,end),_point(side,inside),C.IVORY,stroke,true)
			draw_line(_point(.445,lerpf(end,inside,.52)),_point(.555,lerpf(end,inside,.52)),C.IVORY,stroke,true)
		for index in MARKS.size():
			var mark: Vector2 = MARKS[index]
			var center := _point(mark.x,mark.y)
			if index!=primary_slot:
				draw_circle(center,8*factor,C.IVORY,true,-1,true)
				continue
			for radius in [46,34,23]: draw_circle(center,radius*factor,Color(C.MINT,.10),true,-1,true)
			draw_circle(center,15*factor,C.MINT,true,-1,true)
			var number := str(index+1)
			var font := C.font(700)
			var font_size := maxi(10,roundi(20*factor))
			var width := font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			draw_string(font,center+Vector2(-width/2.0,6*factor),number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,C.BG)

static func build(app:Control,player:Dictionary) -> Control:
	var page:=Control.new();page.name="ImmersivePlayerFull";page.custom_minimum_size=Vector2(2248,1236)*C.density;C.fill(page,true)
	var hero:=D.panel(page,Rect2(0,0,2248,350),"","","","FullPlayerHero")
	var portrait: TextureRect
	if not str(player.get("id","")).is_empty():
		portrait = G.portrait(int(player.get("portraitIndex",0)),0,player)
	else:
		portrait = C.photo("player-hero",Vector2.ZERO,false)
		portrait.tooltip_text = "Portrait décoratif fictif généré par IA"
	hero.add_child(portrait)
	# Le portrait occupe aussi la marge à gauche des onglets.
	D.place(portrait,Rect2(1,1,469,429))
	hero.tooltip_text = portrait.tooltip_text
	var shirt_number: Variant = player.get("shirtNumber")
	var number := G.n(shirt_number) if shirt_number != null else "—"
	var shirt := _slanted_badge(hero,Rect2(510,41,140,102),Color("102724"),Color(C.IVORY,.78))
	shirt.mouse_filter = Control.MOUSE_FILTER_PASS
	shirt.tooltip_text = "Numéro sur la feuille de match" if shirt_number != null else "Aucun numéro sur la feuille de match"
	ClubUI.italic(D.text(shirt,70,82,number,82,C.IVORY,800,110,HORIZONTAL_ALIGNMENT_CENTER),800).name="FullPlayerNumber"
	var heading:=ClubUI.italic(D.text(hero,668,123,str(player.name).to_upper(),88,C.IVORY,800,1030),800)
	heading.name="ProfilePlayerName"
	D.text(hero,671,180,str(player.pos).to_upper(),39,C.GOLD,700,1020)
	D.text(hero,671,231,G.n(player.get("age","—"))+" ans  ·  Saison "+G.n(app.model.meta.get("season",1)),31,C.IVORY,500,1020)
	var injury := float(player.get("injury", 0))
	var recovering := injury <= 0 and P.player_in_recovery(app.model, str(player.id))
	var availability := "Disponible"
	var availability_color := C.MINT
	if injury > 0:
		availability = "Indisponible"
		availability_color = C.ALERT
	elif recovering:
		availability = "En reprise"
		availability_color = C.AMBER
	var selection := "Hors groupe"
	if shirt_number != null:
		selection = "Titulaire" if int(shirt_number) <= 15 else "Remplaçant"
	D.chip(hero, Rect2(670,263,210,46), availability, availability_color).name = "PlayerHeroAvailability"
	D.chip(hero, Rect2(894,263,220,46), selection, C.AMBER).name = "PlayerHeroSelection"
	var rating := _slanted_badge(hero,Rect2(1710,43,236,160),Color("0a5735"),Color(C.MINT,.7))
	ClubUI.italic(D.text(rating,118,129,G.n(player.get("rating","—")),132,C.IVORY,800,218,HORIZONTAL_ALIGNMENT_CENTER),800)
	ClubUI.italic(D.text(hero,2084,151,G.n(player.get("potential","—")),98,C.IVORY,800,235,HORIZONTAL_ALIGNMENT_CENTER),800)
	D.text(hero,1828,234,"NIVEAU",23,C.MUTED,600,220,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(hero,2084,234,"POTENTIEL",23,C.GOLD,600,235,HORIZONTAL_ALIGNMENT_CENTER)
	D.button(hero,Rect2(1710,264,236,46),"Comparer",func():
		if str(player.id) not in app.management_ui.compare and app.management_ui.compare.size()<2:app.management_ui.compare.append(str(player.id))
		app.SquadViews.comparison(app),false,"people",true,app.accent,"FullPlayerCompare")
	D.button(hero,Rect2(1962,264,260,46),"Ma note",func():Notes.open(app,str(player.id)),false,"mail",true,app.accent,"OpenPlayerCoachNote")
	var active:=clampi(int(app.management_ui.get("immersive_player_tab",0)),0,5)
	var detailed := PlayerAttributes.detail(player)
	for i in 6:
		var id := "FullPlayerTab"+str(i)
		var caption: String = ["Vue d’ensemble","Attributs","Performances","Contrat","Développement","Repères"][i]
		var tab := ClubUI.tab(page,Rect2(500+i*230,365,218,44),caption,active==i,func():
			app.management_ui.immersive_player_tab=i
			app._render()
			ClubUI.focus(app,id),id)
		tab.toggle_mode = true
		tab.set_pressed_no_signal(active==i)
		tab.add_theme_stylebox_override("pressed",tab.get_theme_stylebox("normal"))
	D.button(page,Rect2(1900,365,348,44),"Retour à l’effectif",func():app.set_meta("immersive08_full_player",false);app._navigate("Effectif"),false,"",true,app.accent,"PlayerBackToSquad")
	match active:
		0:
			_position(D.panel(page,Rect2(0,430,480,520),"POSTE PRINCIPAL","tactic"),app,player)
			_evaluation(D.panel(page,Rect2(496,430,1174,520),"ÉVALUATION DU JOUEUR","star"),app,player,not detailed.is_empty())
			_health(D.panel(page,Rect2(1686,430,562,520),"DISPONIBILITÉ","heart"),app,player,injury,recovering)
			_usage(D.panel(page,Rect2(0,966,1670,270),"PERFORMANCES DE LA SAISON","trophy"),app,player)
			_contract(D.panel(page,Rect2(1686,966,562,270),"CONTRAT","money"),app,player)
		1:
			if detailed.is_empty():
				_evaluation(D.panel(page,Rect2(0,430,1174,520),"ÉVALUATION DU JOUEUR","star"),app,player,false)
				_position(D.panel(page,Rect2(1190,430,480,520),"POSTE PRINCIPAL","tactic"),app,player)
				_health(D.panel(page,Rect2(1686,430,562,520),"DISPONIBILITÉ","heart"),app,player,injury,recovering)
			else:
				_detailed_attributes(D.panel(page,Rect2(0,430,2248,590),"36 ATTRIBUTS DÉTAILLÉS","star","","PlayerDetailedAttributes"),player,detailed)
		2:
			_usage(D.panel(page,Rect2(0,430,1670,270),"PERFORMANCES DE LA SAISON","trophy"),app,player)
			_development(D.panel(page,Rect2(0,716,1670,420),"BILANS DU JOUEUR","calendar"),app,player)
			_health(D.panel(page,Rect2(1686,430,562,520),"DISPONIBILITÉ","heart"),app,player,injury,recovering)
		3:
			_contract(D.panel(page,Rect2(0,430,850,270),"CONTRAT ET NÉGOCIATION","money"),app,player)
			_health(D.panel(page,Rect2(866,430,562,520),"CHARGE INDIVIDUELLE","heart"),app,player,injury,recovering)
			D.photo(page,"hospitality",Rect2(1444,430,804,520))
		4:
			_development(D.panel(page,Rect2(0,430,1670,550),"DÉVELOPPEMENT ET PROGRESSION","school"),app,player)
			D.photo(page,"academy-player",Rect2(1686,430,562,550))
		5:
			_contexts(D.panel(page,Rect2(0,430,1498,806),"LE JOUEUR DANS LE GROUPE","people","","FullPlayerContexts"),app,player)
			_sources(D.panel(page,Rect2(1514,430,734,520),"REPÈRES DE DÉPART","info","","FullPlayerSources"),app,player)
			D.photo(page,"scouting",Rect2(1514,966,734,270))
	return page

static func _slanted_badge(parent: Control, area: Rect2, fill: Color, border: Color) -> Control:
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)
	D.place(badge, area)
	var slope := float(C.px(21))
	var stroke := maxf(1.0, C.px(2))
	badge.draw.connect(func():
		var size := badge.size
		var outline := PackedVector2Array([Vector2(slope,1), Vector2(size.x-1,1), Vector2(size.x-slope,size.y-1), Vector2(1,size.y-1)])
		badge.draw_colored_polygon(outline, fill)
		outline.append(outline[0])
		badge.draw_polyline(outline, border, stroke, true))
	return badge

static func _position(card:Panel,app:Control,player:Dictionary) -> void:
	var slots:Array=app.model.get("selection",{}).get("slots",[])
	var preferred:=clampi(int(player.get("fam",0)),0,8)
	var primary_slot:int=[0,1,3,7,8,9,10,11,14][preferred]
	if preferred==0 and str(player.get("pos","")).contains("droit"):primary_slot=2
	var field := PositionPitch.new()
	field.name = "PlayerRolePitch"
	field.primary_slot = primary_slot
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(field)
	D.place(field,Rect2(24,78,432,350))
	var compatible:Array[String]=[]
	for slot:Dictionary in slots:
		if int(slot.get("slot",99))<15 and str(player.id) in slot.get("eligibleIds",[]) and str(slot.get("label","")) not in compatible:compatible.append(str(slot.label))
	D.text(card,24,464,str(player.pos),26,C.GOLD,700,428)
	D.text(card,24,496," · ".join(compatible) if not compatible.is_empty() else "Poste de référence du dossier",18,C.MUTED,500,428)

static func _evaluation(card: Panel, app: Control, player: Dictionary, has_details: bool) -> void:
	D.text(card,30,121,"NOTE GLOBALE / 100",26,C.MUTED,700,500)
	D.text(card,30,225,G.n(player.get("rating","—")),88,C.MINT,800,360).name = "PlayerGlobalRating"
	D.text(card,30,285,"Note de simulation dans cette carrière.",26,C.IVORY,500,900)
	if has_details:
		D.button(card,Rect2(30,332,465,60),"Voir les 36 attributs",func():
			app.management_ui.immersive_player_tab = 1
			app._render()
			ClubUI.focus(app,"FullPlayerTab1"),true,"arrow",true,app.accent,"OpenDetailedPlayerAttributes")
	else:
		D.text(card,30,344,"Le détail à 36 attributs est indisponible pour ce profil.",25,C.MUTED,500,1080)

static func _detailed_attributes(card: Panel, player: Dictionary, values: Dictionary) -> void:
	D.text(card,24,88,PlayerAttributes.subtitle(player),23,C.MUTED,500,600)
	for i in PlayerAttributes.GROUPS.size():
		var group: Array = PlayerAttributes.GROUPS[i]
		var x := 24 + i * 554
		D.rect(card,Rect2(x,108,538,448),Color("121c1c"),5,C.LINE)
		D.rect(card,Rect2(x,108,538,46),Color("123629"),4)
		D.text(card,x+16,141,group[0],25,C.IVORY,700,506)
		var entries: Array = group[1]
		for j in entries.size():
			var pair: Array = entries[j]
			var y := 192 + j * 41
			D.text(card,x+16,y,pair[1],24,C.IVORY,500,425)
			var number := D.text(card,x+522,y,PlayerAttributes.caption(values.get(pair[0])),26,C.GOLD,700,80,HORIZONTAL_ALIGNMENT_RIGHT)
			number.name = "PlayerDetailedAttribute_" + str(pair[0])
			D.line(card,Vector2(x+14,y+10),Vector2(x+524,y+10),Color(C.LINE,.45))

static func _health(card:Panel,app:Control,player:Dictionary,injury:float,recovering:bool) -> void:
	var condition := clampf(float(player.get("condition", 0)), 0, 100)
	var condition_color := C.AMBER if condition < 85 else C.MINT
	var dial := ConditionDial.new()
	dial.name = "PlayerConditionDial"
	dial.condition = condition
	dial.ink = condition_color
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dial)
	D.place(dial, Rect2(23,68,86,86))
	var pulse := C.icon("heart", 38, condition_color)
	dial.add_child(pulse)
	D.place(pulse, Rect2(24,24,38,38))
	D.text(card,123,112,G.n(condition)+" %",62,condition_color,700,180)
	D.text(card,123,149,"CONDITION PHYSIQUE",22,C.MUTED,500,180)
	D.line(card,Vector2(319,70),Vector2(319,154))
	D.text(card,348,112,G.n(player.get("physicalLoad",0)),62,C.GOLD,700,190)
	D.text(card,348,149,"FATIGUE",22,C.MUTED,500,190)
	D.line(card,Vector2(24,175),Vector2(538,175))
	var available := "Disponible pour le groupe"
	if injury > 0: available = "Indisponible · "+G.n(injury)+" sem."
	elif recovering: available = "En reprise"
	D.text(card,24,222,available,29,C.ALERT if injury>0 else C.GOLD if recovering else C.MINT,700,514).name = "PlayerAvailability"
	var show_medical := injury > 0 or recovering
	if show_medical: D.photo(card,"medical-recovery",Rect2(306,245,232,174))
	var satisfaction: Variant = null
	for member: Dictionary in app.model.get("clubLife",{}).get("relationships",{}).get("players",[]):
		if member.get("id") == player.id:
			satisfaction = member.get("score")
			break
	var width := 266 if show_medical else 514
	_health_fact(card,245,width,"SATISFACTION DU JOUEUR",G.n(satisfaction)+" / 100" if satisfaction!=null else "Non renseignée","PlayerSatisfaction")
	var plan: String = Training.INDIVIDUAL.get(player.get("loadPlan",""),"Non renseigné")
	_health_fact(card,335,width,"PLAN DE CHARGE",plan,"PlayerTrainingLoadPlan")
	D.button(card,Rect2(24,447,514,45),"Régler la charge individuelle",func():Tactics._individual(app,player),false,"arrow",true,app.accent,"PlayerLoad")

static func _health_fact(card: Panel, y: int, width: int, caption: String, value: String, id: String) -> void:
	var fact := D.rect(card,Rect2(24,y,width,80),Color("121c1c"),5,C.LINE)
	D.text(fact,14,29,caption,20,C.MUTED,600,width-28)
	D.text(fact,14,61,value,28,C.IVORY,600,width-28).name = id

static func _usage(card:Panel,app:Control,player:Dictionary) -> void:
	var stats:Array=[[G.n(player.get("appearances",0)),"APPARITIONS"],[G.n(player.get("minutes",0)),"MINUTES"],[G.n(player.get("note","—")),"NOTE AU POSTE"]]
	for i in stats.size():
		var x:=24+i*300
		D.text(card,x,145,stats[i][0],64,C.MINT if i==2 else C.IVORY,700,260)
		D.text(card,x,182,stats[i][1],22,C.MUTED,600,260)
	D.line(card,Vector2(914,80),Vector2(914,245))
	D.text(card,946,111,"MON CARNET PERSONNEL",26,C.GOLD,700,690)
	var note := _note(app,player)
	var preview := "Conservez vos observations sur ce joueur." if note.is_empty() else str(note.get("text","")).replace("\n"," ")
	D.text(card,946,151,preview,19,C.MUTED,400,690,HORIZONTAL_ALIGNMENT_LEFT,true).name="FullPlayerNotePreview"
	D.button(card,Rect2(946,181,670,48),"Ouvrir ma note",func():Notes.open(app,str(player.id)),false,"mail",true,app.accent,"OpenPlayerNoteFromUsage")

static func _contract(card:Panel,app:Control,player:Dictionary) -> void:
	D.text(card,24,113,G.euros(player.get("salary",0))+" / semaine",40,C.IVORY,700,515)
	D.text(card,24,151,str(player.get("contractLabel","—")),27,C.MUTED,500,515)
	D.text(card,24,183,"Montants de jeu",19,C.MUTED,400,515,HORIZONTAL_ALIGNMENT_LEFT,true)
	var offer:=D.button(card,Rect2(24,206,514,44),"Proposer une prolongation",func():app.SquadViews.contract(app,player,false),true,"arrow",true,app.accent,"OfferRenewal")
	offer.disabled=not player.get("renewal",{}).get("available",false) or not app._live().is_empty()

static func _development(card:Panel,app:Control,player:Dictionary) -> void:
	var records:Array=app.model.get("decisions",{}).get("development",{}).get("professionals",[]).filter(func(record:Dictionary):return str(record.get("id",""))==str(player.id))
	var development:Dictionary=records[0].get("development",{}) if not records.is_empty() else {}
	D.text(card,24,108,"NIVEAU ACTUEL  "+G.n(player.get("rating","—"))+"     ·     POTENTIEL  "+G.n(player.get("potential","—")),31,C.MINT,700,1550)
	D.text(card,24,163,"Bilan et objectifs individuels dans le suivi de formation.",22,C.MUTED,400,1550,HORIZONTAL_ALIGNMENT_LEFT,true)
	var history:Array=development.get("history",[])
	if history.is_empty():D.text(card,24,223,"Premier bilan annuel à venir.",25,C.MUTED,500,1550)
	for i in mini(4,history.size()):
		var year:Dictionary=history[history.size()-1-i]
		D.text(card,24,223+i*42,"Saison %s · %s → %s · %s minutes" % [G.n(year.get("season","—")),G.n(year.get("start","—")),G.n(year.get("end","—")),G.n(year.get("minutes","—"))],24,C.IVORY,500,1500)
	D.button(card,Rect2(24,352,520,42),"Ouvrir le suivi de formation",func():app._navigate("Formation"),false,"school",true,app.accent,"PlayerDevelopmentAction")

static func _sources(card:Panel,app:Control,player:Dictionary) -> void:
	var profile:Dictionary=player.rosterProfile if player.get("rosterProfile") is Dictionary else {}
	if profile.is_empty():
		D.text(card,24,120,"Repères du joueur dans votre carrière",31,C.IVORY,700,686)
		D.text(card,24,179,"Aucun dossier de référence externe associé.",22,C.MUTED,400,686,HORIZONTAL_ALIGNMENT_LEFT,true)
		return
	var pos:Dictionary=profile.get("position",{})
	var contract:Dictionary=profile.get("contract",{})
	var status:Dictionary=profile.get("status",{})
	var qualifications: Array=pos.get("qualifications",[])
	var details:Array=["Poste d’origine : "+str(pos.get("primary",player.pos)),"Qualifications de départ : "+(", ".join(qualifications) if not qualifications.is_empty() else "Non renseignées"),"Statut initial : "+str(status.get("value","—")),"Échéance de départ : "+G.n(contract.get("endYear","—"))]
	if contract.has("basis"): details.append("Échéance officielle publiée" if contract.basis=="official" else "Durée initiale estimée pour le jeu")
	for source_id in contract.get("sources",[]):
		var source:Dictionary=app.model.get("meta",{}).get("rosterSources",{}).get(source_id,{})
		details.append("Publication : "+str(source.get("published","date inconnue")))
	var scroll := _scroll(card,Rect2(22,72,690,422))
	for i in details.size(): scroll.add_child(C.wrap(details[i],23,C.IVORY if i==0 else C.MUTED,true,600 if i==0 else 500))

static func _contexts(card: Panel, app: Control, player: Dictionary) -> void:
	var content := _scroll(card,Rect2(20,74,1458,710))
	var entry := _note(app,player)
	var note: VBoxContainer
	if not entry.is_empty():
		note=C.v(4)
		note.name="ProfileNoteContent"
		note.add_child(C.label("MA NOTE · S%s / SEMAINE %s" % [G.n(entry.get("season",1)),G.n(int(entry.get("week",0))+1)],19,C.GOLD))
		var preview := C.wrap(entry.get("text",""),19,C.IVORY)
		preview.name="ProfileNotePreview"
		preview.max_lines_visible=4
		preview.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		note.add_child(preview)
		content.add_child(note)
	app.SquadViews._profile_contexts(content,player,app)
	content.get_node("ProfileContexts").show()
	if note!=null: note.reparent(content.find_child("ProfileStaffNoteSlot",true,false),false)
	Legacy.apply(content,app.accent)

static func _scroll(parent: Control, rectangle: Rect2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	D.place(scroll,rectangle)
	var content := C.v(10)
	C.fill(content)
	scroll.add_child(content)
	return content

static func _note(app: Control, player: Dictionary) -> Dictionary:
	for entry: Dictionary in app.model.get("clubLife",{}).get("coachNotebook",{}).get("entries",[]):
		if str(entry.get("target",""))==str(player.id): return entry
	return {}
