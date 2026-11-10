extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const TableOrder = preload("res://ui/player_table_order.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const Cover = preload("res://ui/lineup_cover.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")

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
	var auto:=D.button(composition,Rect2(738,14,306,30),"SÉLECTION DU STAFF",func():app._command("auto_lineup"),false,"people",true,app.accent,"LineupAutomatic")
	auto.disabled=not Selection.editable(app)
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
	var positions:Array=[[435,565,1],[815,565,2],[1195,565,3],[623,656,4],[1003,656,5],[435,744,6],[815,744,8],[1195,744,7],[675,835,9],[870,915,10],[397,1003,11],[632,958,12],[1060,958,13],[1231,1003,14],[815,1069,15]]
	var starters := 0
	for position:Array in positions:
		var slot:int=position[2]-1
		var person:=_player(app,slot)
		if not person.is_empty(): starters += 1
		var selected:bool=app.selected_slot==slot
		var button:=Selection.PlayerButton.new()
		button.name="LineupSlot%02d" % (slot+1)
		button.tooltip_text=_player_hint(app,person,slot)
		button.accessibility_name=button.tooltip_text
		button.add_theme_stylebox_override("normal",C.box(Color("16422f") if selected else Color("0c251d"),C.GOLD if selected else Color("789384"),4,0))
		button.add_theme_stylebox_override("hover",C.box(Color("26543c"),C.MINT,4,0))
		button.add_theme_stylebox_override("focus",C.box(Color("16422f"),C.GOLD,4,0))
		composition.add_child(button)
		D.place(button,Rect2(position[0]-280-84,position[1]-264-27,168,88))
		Selection.wire(button,app,str(person.get("id","")),slot,slot,str(person.get("name","Poste vacant")))
		if not person.is_empty():
			var portrait:=G.portrait(int(person.get("portraitIndex",0)),C.px(52),person)
			portrait.name="TacticsPortrait%02d" % (slot+1)
			portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.add_child(portrait);D.place(portrait,Rect2(5,3,52,52))
		D.chip(button,Rect2(64,8,34,28),str(slot+1),C.IVORY)
		var note:Variant=Selection.rating(app.model,person,slot)
		D.chip(button,Rect2(108,8,51,28),Selection.rating_text(app.model,person,slot),_note_color(note)).name="TacticsPositionRating%02d" % (slot+1)
		D.text(button,112,52,"AU POSTE",12,C.MUTED,500,90,HORIZONTAL_ALIGNMENT_CENTER)
		D.text(button,84,78,_slot_name(person),19,C.IVORY,600,158,HORIZONTAL_ALIGNMENT_CENTER)
		button.pressed.connect(func():_choose_slot(app,slot))
	var group:=P.group(app.model)
	var condition := "Condition · XV %s · Groupe %d %%" % [P.lineup_condition(app.model), group.condition]
	D.text(composition,25,893,condition,21,C.IVORY,600,342).name = "LineupCondition"
	_identity(_card(page,Rect2(1980,264,548,906),"IDENTITÉ DE JEU","flag","TacticsIdentity"),app,domains)
	var reserves := _bench(_card(page,Rect2(1366,264,598,529),"LE BANC","people","TacticsBench"),app)
	D.text(composition,1046,891,"%d titulaires · %d remplaçants" % [starters,reserves],19,C.MUTED,500,440,HORIZONTAL_ALIGNMENT_RIGHT)
	_outside(_card(page,Rect2(1366,809,598,361),"HORS GROUPE","people","TacticsOutside"),app)
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
	var watched: Array = app.model.get("squad", []).filter(func(player: Dictionary): return not U.watch_reason(player).is_empty())
	if watched.is_empty():
		D.text(vigilance,24,94,"Aucune alerte physique",27,C.MINT,600,514)
	else:
		var player: Dictionary = watched[0]
		D.text(vigilance,24,72,player.name,23,C.IVORY,600,514).name = "TacticsVigilancePlayer"
		D.text(vigilance,24,106,U.watch_reason(player),24,C.AMBER,600,514).name = "TacticsVigilanceReason"
	D.text(vigilance,24,131 if watched.is_empty() else 135,"Consulter l’effectif pour ajuster les charges individuelles.",19,C.MUTED,400,514,HORIZONTAL_ALIGNMENT_LEFT,true)
	_restore_focus.call_deferred(app)
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
	var quote := Cover.data(app)
	if not quote.is_empty():
		var cover := D.button(card, Rect2(22,855,504,34), Cover.caption(quote), func(): Cover.confirm(app, quote), false, "school", true, app.accent, "LineupCover")
		Cover.configure(cover, quote)
	else:D.text(card,23,884,"Indicateurs projetés · choix enregistrés immédiatement",18,C.GOLD,500,502)

static func _bench(card:Panel,app:Control) -> int:
	var vacancy := P.reduced_bench_number(app.model)
	if vacancy != 0:
		var action := D.button(card,Rect2(251,12,242,34),"Match · Feuille à 22",func():app._navigate("Match"),false,"arrow",true,app.accent,"LineupOpenMatchAt22")
		action.tooltip_text=P.reduced_bench_vacancy(vacancy)
		action.accessibility_name="Ouvrir le jour de match pour une feuille à 22"
	var state: Dictionary=app.management_ui.get("bench_reading",{"key":"slot","descending":false})
	app.management_ui.bench_reading=state
	for spec in [["N°",3,54,"slot"],["JOUEUR",86,220,"name"],["POSTE",310,174,"pos"],["COND.",484,74,"condition"]]:
		var key: String=spec[3]
		var button:=D.button(card,Rect2(20+spec[1],65,spec[2],30),str(spec[0])+((" ↓" if state.descending else " ↑") if state.key==key else ""),func():
			state.descending=not state.descending if state.key==key else false
			state.key=key;app._render()
			var focus: Control=app.root_content.find_child("BenchSort_"+key,true,false)
			if focus!=null:focus.grab_focus.call_deferred(),false,"",false,app.accent,"BenchSort_"+key)
		button.add_theme_font_size_override("font_size",C.px(16))
	var entries: Array=[]
	for slot in range(15,23):
		var person:=_player(app,slot)
		entries.append({"id":str(person.get("id","vacant"))+"/"+str(slot),"slot":slot,"person":person})
	entries=TableOrder.ordered(entries,state.key,state.descending,func(entry:Dictionary,key:String):return entry.slot if key=="slot" else entry.person.get(key))
	var scroll:=ScrollContainer.new();scroll.name="BenchPlayerScroll";scroll.follow_focus=true;scroll.mouse_force_pass_scroll_events=false
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll);D.place(scroll,Rect2(20,104,578,376))
	var rows:=Control.new();rows.name="BenchPlayerRows";rows.custom_minimum_size=Vector2(C.px(558),C.px(376));scroll.add_child(rows)
	var filled := 0
	for i in entries.size():
		var slot: int=entries[i].slot
		var person: Dictionary=entries[i].person
		if not person.is_empty():filled+=1
		var y:=i*47
		var action:=Selection.PlayerButton.new()
		action.name="LineupSlot%02d" % (slot+1)
		rows.add_child(action);D.place(action,Rect2(0,y,558,43))
		action.pressed.connect(func():_choose_slot(app,slot))
		Selection.wire(action,app,str(person.get("id","")),slot,slot,str(person.get("name","Poste vacant")))
		action.tooltip_text=_player_hint(app,person,slot)
		action.accessibility_name=action.tooltip_text
		action.add_theme_stylebox_override("normal",C.box(Color("14201e") if i%2 else Color("10181a"),Color.TRANSPARENT,3,0))
		D.chip(action,Rect2(8,7,34,28),str(slot+1),C.IVORY)
		if not person.is_empty():
			var portrait:=G.portrait(int(person.get("portraitIndex",0)),C.px(34),person)
			portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;action.add_child(portrait);D.place(portrait,Rect2(47,4,34,34))
		D.text(action,87,23,_slot_name(person),21,C.IVORY,600,215)
		D.text(action,87,39,"Note au poste "+Selection.rating_text(app.model,person,slot),14,_note_color(Selection.rating(app.model,person,slot)),500,215)
		D.text(action,312,29,Selection.positions(person),19,C.MUTED,500,160)
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

static func _note_color(value: Variant) -> Color:
	return C.MUTED if value==null else C.ALERT if float(value)<40 else C.AMBER if float(value)<65 else C.MINT

static func _player_hint(app: Control,person: Dictionary,index: int) -> String:
	var assignment:=Selection.slot(app.model,index)
	var number:=Selection.number(app.model,index)
	return "N°%d · %s\n%s · %s\nNote au poste %s : %s / 100 · Condition %s %%\nChoisir le numéro puis affecter un joueur, ou glisser vers une autre place." % [index+1,str(assignment.get("label","")),str(person.get("name","À pourvoir")),Selection.positions(person),str(number) if number>0 else "—",Selection.rating_text(app.model,person,index),G.n(person.get("condition","—"))]

static func _choose_slot(app: Control,index: int) -> void:
	if app.selected_slot==index:
		_candidates(app,index)
		return
	app.selected_slot=index
	var reading:=Selection.state(app)
	reading.focus="LineupSlot%02d" % (index+1)
	app._render()
	_restore_focus(app)

static func _restore_focus(app: Control) -> void:
	var focus_id:=str(Selection.state(app).get("focus",""))
	if focus_id.is_empty():return
	var focus:Control=app.root_content.find_child(focus_id,true,false)
	if focus!=null:focus.grab_focus.call_deferred()

static func _outside(card: Panel,app: Control) -> void:
	var index:int=app.selected_slot
	var target:=Selection.slot(app.model,index)
	var label:="CIBLE N°%d · %s" % [index+1,str(target.get("label",""))]
	D.text(card,20,82,label,18,C.GOLD,600,555).name="TacticsOutsideTarget"
	D.text(card,76,109,"JOUEUR · POSTES MAÎTRISÉS",15,C.MUTED,600,348)
	D.text(card,562,109,"NOTE AU POSTE",15,C.MUTED,600,130,HORIZONTAL_ALIGNMENT_RIGHT)
	var scroll:=ScrollContainer.new();scroll.name="TacticsOutsideScroll";scroll.follow_focus=true;scroll.mouse_force_pass_scroll_events=false
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll);D.place(scroll,Rect2(20,119,558,201))
	var rows:=Control.new();rows.name="TacticsOutsideRows";scroll.add_child(rows)
	var people:Array=[]
	for person:Dictionary in app.model.get("squad",[]):
		if Selection.source(app.model,str(person.id))<0:people.append(person)
	people.sort_custom(func(a:Dictionary,b:Dictionary):
		var ar:Variant=Selection.rating(app.model,a,index);var br:Variant=Selection.rating(app.model,b,index)
		if ar==null and br!=null:return false
		if br==null and ar!=null:return true
		if ar!=br:return ar>br
		return str(a.id)<str(b.id))
	rows.custom_minimum_size=Vector2(C.px(538),C.px(maxi(201,people.size()*51)))
	for i in people.size():
		var person:Dictionary=people[i]
		var action:=Selection.PlayerButton.new()
		action.name="TacticsOutsidePlayer_"+str(person.id).replace(":","_")
		action.set_meta("player_id",str(person.id))
		action.add_theme_stylebox_override("normal",C.box(Color("14201e") if i%2 else Color("10181a"),Color.TRANSPARENT,3,0))
		action.add_theme_stylebox_override("hover",C.box(Color("234331"),C.MINT,3,0))
		action.add_theme_stylebox_override("focus",C.box(Color("14201e"),C.GOLD,3,0))
		rows.add_child(action);D.place(action,Rect2(0,i*51,538,47))
		var portrait:=G.portrait(int(person.get("portraitIndex",0)),C.px(40),person)
		portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;action.add_child(portrait);D.place(portrait,Rect2(4,3,40,40))
		D.text(action,56,22,str(person.name),21,C.IVORY,600,366)
		D.text(action,56,41,Selection.positions(person)+" · "+str(person.get("status","")),15,C.MUTED,500,365)
		var note:Variant=Selection.rating(app.model,person,index)
		D.text(action,524,32,Selection.rating_text(app.model,person,index),27,_note_color(note),700,84,HORIZONTAL_ALIGNMENT_RIGHT).name="TacticsOutsideRating"
		var allowed:=Selection.eligible(app,str(person.id),index)
		action.tooltip_text=_player_hint(app,person,index)+("\nClic ou Entrée : affecter à cette cible." if allowed else "\nAffectation à cette cible indisponible ; consulter un autre numéro.")
		action.accessibility_name=action.tooltip_text
		Selection.wire(action,app,str(person.id),-1,-1,str(person.name))
		action.pressed.connect(func():
			if not Selection.eligible(app,str(person.id),app.selected_slot):
				app.notice("Affectation indisponible","Ce joueur ne peut pas occuper ce poste. Consultez ses qualifications, sa disponibilité et le contexte du match.")
				return
			Selection.apply(app,Selection.payload(app,str(person.id),-1),app.selected_slot))
	D.text(card,578,38,str(people.size())+" joueurs",18,C.MUTED,500,120,HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(card,20,345,"Choisir un numéro · clic pour affecter · glisser pour déplacer",16,C.MUTED,500,558)
	if people.is_empty():D.text(rows,16,46,"Tous les joueurs figurent sur la feuille.",20,C.MUTED,500,500)
	var reading:=Selection.state(app)
	scroll.set_deferred("scroll_vertical",int(reading.scroll))
	scroll.get_v_scroll_bar().value_changed.connect(func(value:float):reading.scroll=int(value))

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
	for player:Dictionary in app.model.get("squad",[]):
		var action:=C.button(str(player.name)+" · "+Selection.positions(player)+" · Note "+Selection.rating_text(app.model,player,slot)+" · "+G.n(player.get("condition",0))+" %",func():dialog.queue_free();app._command("set_lineup",{"playerId":player.id,"slot":slot}))
		action.name="LineupPlayer"+str(player.id).replace(":","_")
		action.set_meta("player_id",str(player.id))
		action.disabled=not Selection.eligible(app,str(player.id),slot)
		action.tooltip_text="Indisponible ou qualification incompatible avec ce poste." if action.disabled else "Affecter ce joueur au poste %02d" % (slot+1)
		list.add_child(action)
	var clear:=C.button("Libérer ce poste",func():dialog.queue_free();app._command("set_lineup",{"playerId":null,"slot":slot}))
	var actions:=C.h(8);body.add_child(actions)
	clear.name="LineupRemove";clear.disabled=not Selection.editable(app);C.fill(clear);actions.add_child(clear)
	var current:=_player(app,slot)
	if not current.is_empty():
		var individual:=C.button("Consignes du joueur",func():dialog.queue_free();_individual(app,current))
		individual.name="TacticsIndividualInstructions";C.fill(individual);actions.add_child(individual)
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
	var load_reason: String = app.SquadViews.player_load_unavailable_reason(app)
	var load_hint := C.wrap(load_reason if not load_reason.is_empty() else "La charge individuelle est appliquée par le moteur à la prochaine préparation.",18)
	if not load_reason.is_empty(): load_hint.name = "PlayerLoadUnavailableReason"
	body.add_child(load_hint)
	for pair in [["collective","Suivre le collectif"],["repos","Récupération"],["normal","Charge normale"],["intense","Travail intense"]]:
		var action:=C.button(pair[1],func():popup.queue_free();app._command("set_player_load",{"playerId":player.id,"mode":pair[0]}),player.get("loadPlan","collective")==pair[0],app.accent)
		action.name = "IndividualLoad_" + pair[0]
		action.disabled = not load_reason.is_empty()
		if action.disabled: action.focus_mode = Control.FOCUS_NONE
		body.add_child(action)
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	app.add_child(popup)
	Dialogs.show_centered(popup,Vector2i(740,620))
