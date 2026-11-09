extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Tactics = preload("res://ui/immersive08/tactics_canvas.gd")
const Notes = preload("res://ui/coach_notes_view.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")

static func build(app:Control,player:Dictionary) -> Control:
	var page:=Control.new();page.name="ImmersivePlayerFull";page.custom_minimum_size=Vector2(2248,1236)*C.density;C.fill(page,true)
	var hero:=D.panel(page,Rect2(0,0,2248,350),"","","","FullPlayerHero")
	if not str(player.get("portraitPath","")).is_empty():
		var image:=G.portrait(int(player.get("portraitIndex",0)),C.px(482),player);hero.add_child(image);D.place(image,Rect2(1,1,482,348));hero.tooltip_text=image.tooltip_text
	else:D.photo(hero,"player-hero",Rect2(1,1,482,348));hero.tooltip_text="Portrait décoratif fictif généré par IA"
	var number:=G.n(player.shirtNumber) if player.get("shirtNumber")!=null else "—"
	D.chip(hero,Rect2(510,41,140,102),number,C.IVORY)
	var heading:=D.text(hero,668,123,str(player.name).to_upper(),88,C.IVORY,800,1030)
	heading.name="ProfilePlayerName"
	var italic:=FontVariation.new();italic.base_font=C.EXTRA_BOLD;italic.variation_transform=Transform2D(Vector2(1,0),Vector2(-.13,1),Vector2.ZERO)
	heading.add_theme_font_override("font",italic)
	D.text(hero,671,180,str(player.pos).to_upper(),39,C.GOLD,700,1020)
	D.text(hero,671,231,G.n(player.get("age","—"))+" ans  ·  Saison "+G.n(app.model.meta.get("season",1))+"  ·  "+str(player.get("status","")),31,C.IVORY,500,1020)
	D.chip(hero,Rect2(670,263,210,46),"Blessé" if float(player.get("injury",0))>0 else "Disponible",C.ALERT if float(player.get("injury",0))>0 else C.MINT)
	D.chip(hero,Rect2(894,263,220,46),str(player.get("status","Effectif")),C.GOLD)
	D.rect(hero,Rect2(1710,43,236,160),Color("123d2c"),8,C.MINT)
	D.text(hero,1828,172,G.n(player.get("rating","—")),132,C.IVORY,800,218,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(hero,2084,151,G.n(player.get("potential","—")),98,C.IVORY,800,235,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(hero,1828,234,"NIVEAU",23,C.MUTED,600,220,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(hero,2084,234,"POTENTIEL",23,C.GOLD,600,235,HORIZONTAL_ALIGNMENT_CENTER)
	D.button(hero,Rect2(1710,264,236,46),"Comparer",func():
		if str(player.id) not in app.management_ui.compare and app.management_ui.compare.size()<2:app.management_ui.compare.append(str(player.id))
		app.SquadViews.comparison(app),false,"people",true,app.accent,"FullPlayerCompare")
	D.button(hero,Rect2(1962,264,260,46),"Ma note",func():Notes.open(app,str(player.id)),false,"mail",true,app.accent,"OpenPlayerCoachNote")
	var active:=clampi(int(app.management_ui.get("immersive_player_tab",0)),0,5)
	for i in 6:
		D.button(page,Rect2(500+i*230,365,218,44),["Vue d’ensemble","Attributs","Performances","Contrat","Développement","Repères"][i],func():app.management_ui.immersive_player_tab=i;app._render(),active==i,"",true,app.accent,"FullPlayerTab"+str(i))
	D.button(page,Rect2(1900,365,348,44),"Retour à l’effectif",func():app.set_meta("immersive08_full_player",false);app._navigate("Effectif"),false,"",true,app.accent,"PlayerBackToSquad")
	match active:
		0:
			_position(D.panel(page,Rect2(0,430,480,520),"POSTE PRINCIPAL","tactic"),app,player)
			_attributes(D.panel(page,Rect2(496,430,1174,520),"PROFIL DE PERFORMANCE","star"),app,player)
			_health(D.panel(page,Rect2(1686,430,562,520),"DISPONIBILITÉ","heart"),app,player)
			_usage(D.panel(page,Rect2(0,966,1670,270),"PERFORMANCES DE LA SAISON","trophy"),app,player)
			_contract(D.panel(page,Rect2(1686,966,562,270),"CONTRAT","money"),app,player)
		1:
			_attributes(D.panel(page,Rect2(0,430,1174,520),"LES APTITUDES DU JOUEUR","star"),app,player)
			_position(D.panel(page,Rect2(1190,430,480,520),"POSTE PRINCIPAL","tactic"),app,player)
			_health(D.panel(page,Rect2(1686,430,562,520),"DISPONIBILITÉ","heart"),app,player)
		2:
			_usage(D.panel(page,Rect2(0,430,1670,270),"PERFORMANCES DE LA SAISON","trophy"),app,player)
			_development(D.panel(page,Rect2(0,716,1670,420),"BILANS DU JOUEUR","calendar"),app,player)
			_health(D.panel(page,Rect2(1686,430,562,520),"DISPONIBILITÉ","heart"),app,player)
		3:
			_contract(D.panel(page,Rect2(0,430,850,270),"CONTRAT ET NÉGOCIATION","money"),app,player)
			_health(D.panel(page,Rect2(866,430,562,520),"CHARGE INDIVIDUELLE","heart"),app,player)
			D.photo(page,"hospitality",Rect2(1444,430,804,520))
		4:
			_development(D.panel(page,Rect2(0,430,1670,550),"DÉVELOPPEMENT ET PROGRESSION","school"),app,player)
			D.photo(page,"academy-player",Rect2(1686,430,562,550))
		5:
			_contexts(D.panel(page,Rect2(0,430,1498,806),"LE JOUEUR DANS LE GROUPE","people","","FullPlayerContexts"),app,player)
			_sources(D.panel(page,Rect2(1514,430,734,520),"REPÈRES DE DÉPART","info","","FullPlayerSources"),app,player)
			D.photo(page,"scouting",Rect2(1514,966,734,270))
	return page

static func _position(card:Panel,app:Control,player:Dictionary) -> void:
	var field:=D.rect(card,Rect2(24,78,432,350),Color("154b32"),6,C.MINT)
	for i in 7:D.line(field,Vector2(12,16+i*53),Vector2(420,16+i*53),Color(C.IVORY,.45))
	var slots:Array=app.model.get("selection",{}).get("slots",[])
	var preferred:=clampi(int(player.get("fam",0)),0,8)
	var marks:Array=[[.25,.14],[.5,.14],[.75,.14],[.38,.27],[.62,.27],[.25,.40],[.75,.40],[.5,.40],[.4,.53],[.6,.62],[.12,.75],[.36,.75],[.64,.75],[.88,.75],[.5,.88]]
	var primary_slot:int=[0,1,3,7,8,9,10,11,14][preferred]
	if preferred==0 and str(player.get("pos","")).contains("droit"):primary_slot=2
	for i in marks.size():
		var center:Vector2=Vector2(marks[i][0]*432,marks[i][1]*350)
		var marker:=D.rect(field,Rect2(center-Vector2(8,8),Vector2(16,16)),C.MINT if i==primary_slot else C.IVORY,8)
		if i==primary_slot:marker.scale=Vector2(1.55,1.55)
	var compatible:Array[String]=[]
	for slot:Dictionary in slots:
		if int(slot.get("slot",99))<15 and str(player.id) in slot.get("eligibleIds",[]) and str(slot.get("label","")) not in compatible:compatible.append(str(slot.label))
	D.text(card,24,464,str(player.pos),26,C.GOLD,700,428)
	D.text(card,24,496," · ".join(compatible) if not compatible.is_empty() else "Poste de référence du dossier",18,C.MUTED,500,428)

static func _attributes(card:Panel,app:Control,player:Dictionary) -> void:
	var radar:=G.W.new();app.SquadViews.radar_setup(radar,player,app.accent);radar.grid_color=C.LINE;radar.data_color=C.MINT;card.add_child(radar);D.place(radar,Rect2(18,78,425,411))
	var attributes:Dictionary=player.get("attributes",{})
	var groups:Array=[["TECHNIQUE",[["pass","Passe"],["kick","Jeu au pied"],["goal","But"],["scrum","Mêlée"],["lineout","Touche"],["tackle","Plaquage"]]],["MENTAL",[["mental","Mental"],["discipline","Discipline"]]],["PHYSIQUE",[["speed","Vitesse"],["stamina","Endurance"],["power","Puissance"]]]]
	for i in groups.size():
		var x:=452+i*234
		D.rect(card,Rect2(x,81,224,390),Color("121c1c"),5,C.LINE)
		D.rect(card,Rect2(x,81,224,46),Color("123629"),4)
		D.text(card,x+12,113,groups[i][0],26,C.IVORY,700,200)
		for j in groups[i][1].size():
			var pair:Array=groups[i][1][j]
			var y:int=164+j*49
			var value:Variant=attributes.get(pair[0])
			D.text(card,x+12,y,pair[1],23,C.IVORY,500,147)
			var number:=D.text(card,x+210,y,G.n(value) if value!=null else "—",29,C.MINT if value!=null and float(value)>=85 else C.GOLD,700,54,HORIZONTAL_ALIGNMENT_RIGHT)
			number.name="PlayerAttribute_"+str(pair[0])
			D.line(card,Vector2(x+10,y+13),Vector2(x+213,y+13),Color(C.LINE,.45))

static func _health(card:Panel,app:Control,player:Dictionary) -> void:
	D.text(card,24,112,G.n(player.get("condition",0))+" %",62,C.MINT,700,240)
	D.text(card,24,149,"CONDITION PHYSIQUE",22,C.MUTED,500,240)
	D.text(card,300,112,G.n(player.get("physicalLoad",0)),62,C.GOLD,700,235)
	D.text(card,300,149,"FATIGUE",22,C.MUTED,500,235)
	D.bar(card,Rect2(24,171,514,8),float(player.get("condition",0)))
	D.text(card,24,222,"Indisponible · "+G.n(player.get("injury",0))+" sem." if float(player.get("injury",0))>0 else "Disponible pour le groupe",29,C.ALERT if float(player.get("injury",0))>0 else C.MINT,700,514)
	D.photo(card,"medical-recovery",Rect2(24,245,514,174))
	D.button(card,Rect2(24,447,514,45),"Régler la charge individuelle",func():Tactics._individual(app,player),false,"arrow",true,app.accent,"PlayerLoad")

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
