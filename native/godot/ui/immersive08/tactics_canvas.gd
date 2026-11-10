extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")

class JerseyButton extends Button:
	var density := 1.0
	func _has_point(point: Vector2) -> bool:
		var location := point/density
		return Rect2(50,2,68,55).has_point(location) or Rect2(2,57,164,28).has_point(location)
static var shirts: Dictionary = {}

class Pitch extends Control:
	func _draw() -> void:
		var border:=Rect2(Vector2.ZERO,size)
		draw_style_box(preload("res://ui/game_skin.gd").T.box(Color("154b32"),5,Color("b3c8a3")),border)
		for i in 10:
			if i%2==0:draw_rect(Rect2(2,size.y*i/10.0,size.x-4,size.y/10.0),Color("174f35"))
		var x:=size.x;var y:=size.y
		var line_color:=Color("d5e3c8");line_color.a=.75
		draw_rect(Rect2(x*.022,y*.027,x*.956,y*.946),line_color,false,1.5)
		for fraction in [.22,.5,.78]:draw_line(Vector2(x*.022,y*fraction),Vector2(x*.978,y*fraction),line_color,1.5)
		for fraction in [.19,.81]:draw_dashed_line(Vector2(x*fraction,y*.027),Vector2(x*fraction,y*.973),line_color,1.5,14)
		draw_line(Vector2(x*.475,2),Vector2(x*.475,42),Color("f2ecdc"),2)
		draw_line(Vector2(x*.525,2),Vector2(x*.525,42),Color("f2ecdc"),2)
		draw_line(Vector2(x*.475,25),Vector2(x*.525,25),Color("f2ecdc"),2)

static func _card(page:Control,rectangle:Rect2,title:String,icon:String,id:String) -> Panel:
	var local:=rectangle;local.position-=Vector2(280,204)
	return D.panel(page,local,title,icon,"",id)

static func _player(app:Control,slot:int) -> Dictionary:
	for assignment:Dictionary in app.model.get("selection",{}).get("slots",[]):
		if int(assignment.get("slot",-1))==slot:return P.player(app.model,str(assignment.get("playerId","")))
	return {}

static func _slot_name(player:Dictionary) -> String:
	if player.is_empty(): return "À pourvoir"
	var name := str(player.name)
	var parts := name.split(" ")
	return parts[0].left(1)+". "+" ".join(parts.slice(1)) if parts.size()>1 else name

static func _shirt(selected:bool) -> Texture2D:
	if shirts.has(selected):return shirts[selected]
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="136" height="110" viewBox="-7 -1 68 55"><path d="M15 0L4 7L-6 24L6 31L11 22V52H43V22L48 31L60 24L50 7L39 0L32 7H22Z" fill="%s" stroke="%s" stroke-width="%s"/></svg>' % ['#1f9b57' if selected else '#103b2c','#9af7ab' if selected else '#a9bcb0',3 if selected else 1.6]
	var image:=Image.new();image.load_svg_from_string(svg)
	var texture:=ImageTexture.create_from_image(image);shirts[selected]=texture
	return texture

static func build(app:Control) -> Control:
	var page:=Control.new()
	page.name="ImmersiveTactics"
	page.custom_minimum_size=Vector2(2248,1140)*C.density
	C.fill(page,true)
	for i in 4:
		var captions: Array=["Composition","Consignes","Phases arrêtées","Analyse adverse"]
		D.button(page,Rect2(i*218,0,206,42),captions[i],func():
			if i==0:return
			if i==2:
				app.management_ui.playbook_tab=1
				app._navigate("Plan de jeu")
				return
			app.Immersive.open_preparation(app,0 if i==3 else 1),i==0,"",true,app.accent,"TacticsTab"+str(i))
	var next:Dictionary=app.model.next if app.model.get("next") is Dictionary else {}
	var fixture := "Aucun prochain match" if next.is_empty() else G.club_name(next.get("home",{}))+" – "+G.club_name(next.get("away",{}))+" · "+str(next.get("label",""))
	D.text(page,2248,30,fixture.to_upper(),22,C.MUTED,500,1100,HORIZONTAL_ALIGNMENT_RIGHT)
	var preparation: Variant = app.model.get("decisions",{}).get("preparation")
	var domains: Array = preparation.get("domains",[]) if preparation is Dictionary else []
	var composition:=_card(page,Rect2(280,264,1070,906),"COMPOSITION · ÉQUIPE PREMIÈRE","tactic","TacticsPitch")
	D.text(composition,1050,38,"ORGANISATION ACTUELLE",18,C.MUTED,500,300,HORIZONTAL_ALIGNMENT_RIGHT)
	var auto:=D.button(composition,Rect2(738,14,306,30),"SÉLECTION DU STAFF",func():app._command("auto_lineup"),false,"people",true,app.accent,"LineupAutomatic")
	auto.disabled=not app._live().is_empty()
	auto.add_theme_stylebox_override("normal",C.box(Color("101719"),Color.TRANSPARENT,0,0))
	D.photo(composition,"tactics-briefing",Rect2(23,72,1024,160),.5)
	var pitch:=Pitch.new();composition.add_child(pitch);D.place(pitch,Rect2(24,245,1022,626))
	_nationale_qualification(composition,app.model.get("selection",{}))
	if app.model.get("tactics",{}).get("attack")=="occupation":
		var overlay := TextureRect.new()
		overlay.name = "TacticsOccupationOverlay"
		overlay.texture = preload("res://art/immersive08/tactics-occupation.svg")
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_SCALE
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.focus_mode = Control.FOCUS_NONE
		pitch.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		D.text(composition,535,891,"Schéma du plan d’occupation",18,C.MUTED,500,330,HORIZONTAL_ALIGNMENT_CENTER)
	var positions:Array=[[435,565,1],[815,565,2],[1195,565,3],[623,656,4],[1003,656,5],[435,744,6],[815,744,8],[1195,744,7],[695,831,9],[905,893,10],[397,1003,11],[632,958,12],[1030,958,13],[1231,1003,14],[815,1069,15]]
	var starters := 0
	for position:Array in positions:
		var slot:int=position[2]-1
		var person:=_player(app,slot)
		if not person.is_empty(): starters += 1
		var selected:bool=app.selected_slot==slot
		var button:=JerseyButton.new()
		button.density=C.density
		button.name="LineupSlot%02d" % (slot+1)
		button.tooltip_text="Poste %02d · %s · choisir un joueur" % [slot+1,person.get("name","À pourvoir")]
		button.accessibility_name=button.tooltip_text
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover",C.box(Color(C.MINT,.1),Color.TRANSPARENT,4,0))
		button.add_theme_stylebox_override("focus",C.box(Color.TRANSPARENT,C.GOLD,4,0))
		composition.add_child(button)
		D.place(button,Rect2(position[0]-280-84,position[1]-264-27,168,88))
		var shirt:=TextureRect.new();shirt.texture=_shirt(selected);shirt.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;shirt.stretch_mode=TextureRect.STRETCH_SCALE;shirt.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(shirt);D.place(shirt,Rect2(50,2,68,55))
		D.text(button,84,39,str(slot+1),28,C.IVORY,700,55,HORIZONTAL_ALIGNMENT_CENTER)
		D.rect(button,Rect2(2,57,164,28),Color("26a45e") if selected else Color("0b201a"),4,C.MINT if selected else Color("728777"))
		D.text(button,84,78,_slot_name(person),22,Color("081d12") if selected else C.IVORY,600,158,HORIZONTAL_ALIGNMENT_CENTER)
		button.pressed.connect(func():app.selected_slot=slot;app._render();_candidates(app,slot))
	var group:=P.group(app.model)
	D.text(composition,25,891,"Condition du groupe : %d %%" % group.condition,19,C.MUTED,500,480)
	_identity(_card(page,Rect2(1366,264,548,906),"IDENTITÉ DE JEU","flag","TacticsIdentity"),app,domains)
	var reserves := _bench(_card(page,Rect2(1930,264,598,529),"LE BANC","people","TacticsBench"),app)
	D.text(composition,1046,891,"%d titulaires · %d remplaçants" % [starters,reserves],19,C.MUTED,500,440,HORIZONTAL_ALIGNMENT_RIGHT)
	_selected(_card(page,Rect2(1930,809,598,361),"JOUEUR SÉLECTIONNÉ","","TacticsSelectedPlayer"),app)
	for i in 3:
		var key:String=["scrum","lineout","kick"][i]
		var found:Dictionary={}
		for domain:Dictionary in domains:
			if domain.get("key")==key:found=domain
		var tile:=_card(page,Rect2(280+i*562,1186,546,158),["MÊLÉE","TOUCHE","JEU AU PIED"][i],["trophy","flag","ball"][i],"TacticsMatchup"+str(i))
		if found.is_empty():
			D.text(tile,25,105,"Aucune projection du staff",25,C.MUTED,500,496).name="TacticsNoReport"
			continue
		D.text(tile,28,105,G.n(found.get("own","—")),48,C.MINT,700,85)
		D.text(tile,105,96,"VS",20,C.MUTED,500,60)
		D.text(tile,157,105,G.n(found.get("opponent","—")),42,C.IVORY,600,105)
		D.text(tile,280,101,"Projection du staff",23,C.MUTED,500,245)
		D.bar(tile,Rect2(25,131,496,6),float(found.get("own",0)))
	var vigilance:=_card(page,Rect2(1966,1186,562,158),"VIGILANCE PHYSIQUE","warning","TacticsVigilance")
	var watched:Array=app.model.get("squad",[]).filter(func(player:Dictionary):return float(player.get("physicalLoad",0))>=70 or float(player.get("condition",100))<80)
	D.text(vigilance,24,94,"Aucune alerte physique" if watched.is_empty() else str(watched[0].name)+" · Charge "+G.n(watched[0].get("physicalLoad",0))+" %",27,C.MINT if watched.is_empty() else C.AMBER,600,514)
	D.text(vigilance,24,131,"Consulter l’effectif pour ajuster les charges individuelles.",19,C.MUTED,400,514,HORIZONTAL_ALIGNMENT_LEFT,true)
	return page

static func _nationale_qualification(parent: Panel, selection: Dictionary) -> void:
	var qualification: Dictionary = selection.get("nationaleQualification",{})
	var notice: Dictionary = qualification.get("notice",{})
	if notice.is_empty(): return
	var alert: bool = notice.get("tone") == "alert"
	var panel := D.rect(parent,Rect2(40,84,732,136),Color("101819",.94),5,C.ALERT if alert else C.LINE)
	panel.name = "NationaleLicenceNotice"
	D.text(panel,17,32,notice.get("title",""),26,C.GOLD,700,698).name = "NationaleQualificationTitle"
	D.text(panel,17,64,notice.get("summary",""),28,C.ALERT if alert else C.IVORY,700,698).name = "NationaleQualificationSummary"
	D.text(panel,17,93,notice.get("detail",""),24,C.MUTED,500,698,HORIZONTAL_ALIGNMENT_LEFT,true).name = "NationaleQualificationDetail"
	var estimates: Variant = notice.get("estimates")
	if estimates is String and not estimates.is_empty():
		D.text(panel,17,122,estimates,24,C.MUTED,500,698,HORIZONTAL_ALIGNMENT_LEFT,true).name = "NationaleQualificationEstimates"

static func _identity(card:Panel,app:Control,domains:Array) -> void:
	for i in 3:
		var key:String=["equilibre","occupation","large"][i]
		D.button(card,Rect2(21+i*169,74,157,39),["Équilibré","Occupation","Large"][i],func():app._command("set_tactics",{"attack":key,"defense":app.model.get("tactics",{}).get("defense","equilibre")}),app.model.get("tactics",{}).get("attack")==key,"",true,app.accent,"TacticsAttack_"+key)
	var keys:Array=["scrum","backs","power","kick","discipline"]
	for i in keys.size():
		var found:Dictionary={}
		for domain:Dictionary in domains:
			if domain.get("key")==keys[i]:found=domain
		var y:=162+i*69
		D.text(card,23,y,["Conquête · mêlée","Passe et vitesse","Puissance des avants","Jeu au pied","Discipline"][i],24,C.IVORY,600,500)
		if found.is_empty():
			D.text(card,23,y+29,"Analyse indisponible",18,C.MUTED,500,400)
			continue
		D.text(card,23,y+29,"XV sélectionné",18,C.MUTED,500,160)
		D.text(card,525,y+29,G.n(found.get("own","—"))+" / 100",18,C.MUTED,500,85,HORIZONTAL_ALIGNMENT_RIGHT)
		D.bar(card,Rect2(154,y+14,252,7),float(found.get("own",0)))
	var domain_values:Dictionary={}
	for domain:Dictionary in domains:domain_values[str(domain.get("key",""))]=float(domain.get("own",0))
	var defensive:=0.0;var selected_count:=0
	for slot in 15:
		var player:=_player(app,slot)
		if not player.is_empty():defensive+=float(player.get("attributes",{}).get("tackle",0));selected_count+=1
	var attack_description:="Consultez le plan de jeu."
	for option:Dictionary in app.model.get("tactics",{}).get("attacks",[]):
		if option.get("id")==app.model.get("tactics",{}).get("attack"):attack_description=str(option.get("description",""))
	var defense_description:="Choisir les consignes défensives."
	for option:Dictionary in app.model.get("tactics",{}).get("defenses",[]):
		if option.get("id")==app.model.get("tactics",{}).get("defense"):defense_description=str(option.get("description",""))
	var conquest := "—"
	if domain_values.has("scrum") and domain_values.has("lineout"):
		conquest = G.n(roundi((domain_values.scrum+domain_values.lineout)/2.0))
	var defense := G.n(roundi(defensive/selected_count)) if selected_count>0 else "—"
	var backs := G.n(roundi(domain_values.backs)) if domain_values.has("backs") else "—"
	var summaries:Array=[["CONQUÊTE",conquest,"Mêlée et touche du XV sélectionné.","trophy"],["DÉFENSE",defense,defense_description,"shield"],["ANIMATION OFFENSIVE",backs,attack_description,"tactic"]]
	for i in summaries.size():
		var summary:Array=summaries[i]
		var y:=533+i*105
		D.rect(card,Rect2(22,y,504,92),Color("14211e"),6,C.LINE)
		var symbol:=C.icon(summary[3],23,C.IVORY);card.add_child(symbol);D.place(symbol,Rect2(487,y+13,23,23))
		D.text(card,41,y+27,summary[0],21,C.IVORY,700,425)
		D.text(card,38,y+75,G.n(summary[1]),42,C.MINT,700,80)
		var description := D.text(card,118,y+53,summary[2],17,C.MUTED,400,380,HORIZONTAL_ALIGNMENT_LEFT,true)
		description.name = "TacticsSummaryText" + str(i)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.max_lines_visible = 2
		description.size.y = C.px(44)
		var hit := Button.new()
		hit.flat = true
		hit.name = "TacticsSummary" + str(i)
		var action: String = ["Ouvrir le dossier de préparation","Modifier les consignes défensives","Ouvrir le plan de jeu"][i]
		hit.tooltip_text = action + "\n" + description.text
		hit.accessibility_name = "%s · %s · %s" % [summary[0], action, description.text]
		card.add_child(hit)
		D.place(hit,Rect2(22,y,504,92))
		hit.pressed.connect(func():
			if i==1:_defense(app)
			else:app._navigate("Plan de jeu" if i==2 else "Préparation"))
	if not app.model.get("selection",{}).get("valid",false):D.button(card,Rect2(22,855,504,34),"Compléter avec le centre",func():app.confirm("Renforcer la feuille de match","Le staff sélectionne les joueurs disponibles, puis promeut de vrais joueurs aux postes manquants. Chaque promotion ajoute 2 500 € de salaire par semaine. Confirmer ?",func():app._command("promote_cover",{"confirmed":true})),false,"school",true,app.accent,"LineupCover")
	else:D.text(card,23,884,"Indicateurs projetés · choix enregistrés immédiatement",18,C.GOLD,500,502)

static func _bench(card:Panel,app:Control) -> int:
	for pair in [["N°",23],["JOUEUR",72],["POSTE",323]]:D.text(card,pair[1],87,pair[0],18,C.MUTED,500,100)
	D.text(card,574,87,"COND.",18,C.MUTED,500,70,HORIZONTAL_ALIGNMENT_RIGHT)
	var filled := 0
	for i in 8:
		var slot:=15+i
		var person:=_player(app,slot)
		if not person.is_empty(): filled += 1
		var y:=104+i*47
		var action:=D.button(card,Rect2(20,y,558,43),"",func():app.selected_slot=slot;app._render();_candidates(app,slot),false,"",true,app.accent,"LineupSlot%02d" % (slot+1))
		action.add_theme_stylebox_override("normal",C.box(Color("14201e") if i%2 else Color("10181a"),Color.TRANSPARENT,3,0))
		D.chip(action,Rect2(8,7,34,28),str(slot+1),C.IVORY)
		D.text(action,56,29,_slot_name(person),24,C.IVORY,600,239)
		D.text(action,304,29,str(person.get("pos","—")),22,C.MUTED,500,170)
		var condition := "—" if person.is_empty() else G.n(person.get("condition","—"))+"%"
		D.text(action,550,29,condition,25,C.MUTED if person.is_empty() else C.MINT,600,70,HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(card,578,38,"%d / 8" % filled,18,C.MUTED,500,100,HORIZONTAL_ALIGNMENT_RIGHT)
	var selection: Dictionary = app.model.get("selection", {})
	var errors: Array = selection.get("errors", [])
	if errors.is_empty():
		D.text(card, 22, 512, "Feuille complète et valide" if selection.get("valid", false) else "Des points restent à traiter dans la feuille.", 19, C.MUTED, 500, 554)
	else:
		# Le moteur place les motifs par poste après les messages généraux.
		var issue := D.text(card, 22, 512, errors.back(), 21, C.AMBER, 600, 554)
		issue.name = "TacticsLineupIssue"
		var width := issue.get_theme_font("font").get_string_size(issue.text, HORIZONTAL_ALIGNMENT_LEFT, -1, issue.get_theme_font_size("font_size")).x
		if errors.size() > 1 or width > issue.size.x:
			issue.size.x = C.px(428)
			var more := D.button(card, Rect2(462, 482, 116, 32), "Motifs (%d)" % errors.size(), validate.bind(app),
				false, "", true, app.accent, "LineupMoreIssues")
			more.tooltip_text = "Afficher tous les motifs de la feuille incomplète"
			more.accessibility_name = "Motifs de la feuille (%d)" % errors.size()
	return filled

static func _selected(card:Panel,app:Control) -> void:
	var player:=_player(app,app.selected_slot)
	D.text(card,578,38,"N°"+str(app.selected_slot+1),18,C.MUTED,500,120,HORIZONTAL_ALIGNMENT_RIGHT)
	if player.is_empty():
		D.rect(card,Rect2(20,75,170,213),Color("101719"),5,C.LINE)
		var symbol := C.icon("people",48,C.MUTED)
		card.add_child(symbol)
		D.place(symbol,Rect2(81,157,48,48))
		D.text(card,209,104,"POSTE À POURVOIR",34,C.IVORY,700,369)
		D.text(card,209,137,"Choisissez un joueur qualifié.",24,C.MUTED,600,369)
		D.button(card,Rect2(20,311,558,33),"Choisir un joueur",func():_candidates(app,app.selected_slot),false,"arrow",true,app.accent,"TacticsChoosePlayer")
		return
	if not str(player.get("id","")).is_empty():
		var image:=G.portrait(int(player.get("portraitIndex",0)),C.px(170),player);card.add_child(image);D.place(image,Rect2(20,75,170,213))
	else:D.photo(card,"squad-portrait",Rect2(20,75,170,213))
	D.text(card,209,104,str(player.name).to_upper(),34,C.IVORY,700,369)
	D.text(card,209,137,str(player.get("pos","—")),24,C.GOLD,600,369)
	D.text(card,209,208,G.n(player.get("note","—")),68,C.MINT,700,105)
	D.text(card,323,198,G.n(player.get("condition","—"))+" %",44,C.MINT,600,240)
	D.text(card,211,237,"NOTE AU POSTE",17,C.MUTED,500,145)
	D.text(card,326,237,"CONDITION",17,C.MUTED,500,180)
	D.chip(card,Rect2(208,258,368,34),str(player.get("status","—")),C.MINT)
	D.button(card,Rect2(20,311,558,33),"Ouvrir les consignes individuelles",func():_individual(app,player),false,"arrow",true,app.accent,"TacticsChoosePlayer")

static func _candidates(app:Control,slot:int) -> void:
	app._clear_dialogs()
	var dialog:=AcceptDialog.new();dialog.name="LineupCandidates"
	app._prepare_dialog(dialog,800)
	dialog.title="Poste %02d · choisir un joueur" % (slot+1)
	var body:=C.v(12);dialog.add_child(body)
	body.add_child(C.photo("tactics-briefing",Vector2(720,100)))
	var scroll:=ScrollContainer.new();scroll.follow_focus=true;body.add_child(scroll)
	var viewport := app.get_viewport()
	var list_width := C.px(720)
	var list_height := C.px(500)
	# La photo, les actions et le titre conservent leur place après réduction.
	var reserved_height := C.px(230) + 68
	var fit_list := func():
		scroll.custom_minimum_size = Vector2(list_width,clampf(viewport.get_visible_rect().size.y-reserved_height,1,list_height))
	fit_list.call()
	viewport.size_changed.connect(fit_list)
	dialog.tree_exiting.connect(func():
		if is_instance_valid(viewport) and viewport.size_changed.is_connected(fit_list): viewport.size_changed.disconnect(fit_list),CONNECT_ONE_SHOT)
	var list:=C.v(8);list.name="LineupCandidatesList";C.fill(list);scroll.add_child(list)
	var eligible:Array=[]
	for assignment:Dictionary in app.model.get("selection",{}).get("slots",[]):
		if int(assignment.get("slot",-1))==slot:eligible=assignment.get("eligibleIds",[])
	for player:Dictionary in app.model.get("squad",[]):
		var action:=C.button(str(player.name)+" · "+str(player.pos)+" · "+G.n(player.get("condition",0))+" %",func():dialog.queue_free();app._command("set_lineup",{"playerId":player.id,"slot":slot}))
		action.name="LineupPlayer"+str(player.id).replace(":","_")
		action.set_meta("player_id",str(player.id))
		action.disabled=not app._live().is_empty() or float(player.get("injury",0))>0 or player.id not in eligible
		action.tooltip_text="Indisponible ou qualification incompatible avec ce poste." if action.disabled else "Affecter ce joueur au poste %02d" % (slot+1)
		list.add_child(action)
	var clear:=C.button("Libérer ce poste",func():dialog.queue_free();app._command("set_lineup",{"playerId":null,"slot":slot}))
	clear.name="LineupRemove";clear.disabled=not app._live().is_empty();body.add_child(clear)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	Dialogs.show_centered(dialog,Vector2i(800,720))

static func validate(app:Control) -> void:
	if app.model.get("selection",{}).get("valid",false):app._navigate("Préparation")
	else:app.notice("La feuille reste à compléter","\n".join(app.model.get("selection",{}).get("errors",[])))

static func _defense(app:Control) -> void:
	app._clear_dialogs()
	var popup:=AcceptDialog.new();popup.name="TacticsDefenseChoices";app._prepare_dialog(popup,700);popup.title="Les consignes défensives"
	var body:=C.v(12);popup.add_child(body)
	body.add_child(C.photo("tactics-briefing",Vector2(640,120)))
	for option:Dictionary in app.model.get("tactics",{}).get("defenses",[]):
		var action:=C.button(str(option.label),func():popup.queue_free();app._command("set_tactics",{"attack":app.model.get("tactics",{}).get("attack","equilibre"),"defense":option.id}),app.model.get("tactics",{}).get("defense")==option.id,app.accent)
		action.name="TacticsDefense_"+str(option.id);body.add_child(action);body.add_child(C.wrap(str(option.get("description","")),18))
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	app.add_child(popup)
	popup.popup_centered(Vector2i(700,560))

static func _individual(app:Control,player:Dictionary) -> void:
	app._clear_dialogs()
	var popup:=AcceptDialog.new();popup.name="IndividualInstructions";app._prepare_dialog(popup,740);popup.title="Consignes · "+str(player.name)
	var body:=C.v(12);popup.add_child(body)
	body.add_child(C.photo("medical-recovery" if float(player.get("injury",0))>0 else "training-session",Vector2(680,170)))
	body.add_child(C.wrap(str(player.pos)+" · Condition "+G.n(player.get("condition",0))+" % · Charge "+G.n(player.get("physicalLoad",0))+" / 100",22,C.IVORY,true))
	body.add_child(C.wrap("La charge individuelle est appliquée par le moteur à la prochaine préparation.",18))
	for pair in [["collective","Suivre le collectif"],["repos","Récupération"],["normal","Charge normale"],["intense","Travail intense"]]:
		var action:=C.button(pair[1],func():popup.queue_free();app._command("set_player_load",{"playerId":player.id,"mode":pair[0]}),player.get("loadPlan","collective")==pair[0],app.accent)
		action.name="IndividualLoad_"+pair[0];action.disabled=not app._live().is_empty();body.add_child(action)
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	app.add_child(popup)
	popup.popup_centered(Vector2i(740,620))
