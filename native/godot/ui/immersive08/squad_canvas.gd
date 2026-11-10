extends Control
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const POTENTIAL_COLOR := Color("ffb454")
const ROW_HEIGHT := 34
const GROUP_HEIGHT := 29
const Training = preload("res://ui/immersive08/training_canvas.gd")
var app: Control
var state: Dictionary
var rows: VBoxContainer
var dossier: Control
var count: Label
var compare: Button
var selected_summary: Label
var sort_headers: Dictionary = {}

static func build(owner_app: Control) -> Control:
	var page: Control = load("res://ui/immersive08/squad_canvas.gd").new()
	page.app = owner_app
	page._build()
	return page

func _build() -> void:
	name = "CarnetSquad"
	custom_minimum_size = Vector2(2248,1128)*C.density
	C.fill(self,true)
	state = app.management_ui.roster
	state.family = app.roster_filter
	state.sort = app.roster_sort
	if state.sort == "Note":
		state.sort = "Niveau"; state.descending = true; app.roster_sort = "Niveau"
	var tabs := ["Vue d’ensemble","Condition","Contrats","Développement"]
	for i in tabs.size():
		D.button(self,Rect2(i*211,0,199,42),tabs[i],func():
			state.immersive_tab=i
			state.sort=["Poste","Condition","Échéance","Potentiel"][i]
			state.descending=i in [1,3]
			app.roster_sort=state.sort
			app._render(),int(state.get("immersive_tab",0))==i,"",true,app.accent,"RosterTab"+str(i))
	D.button(self,Rect2(1258,0,184,42),"Vestiaire",func():app._navigate("Vestiaire"),false,"people",true,app.accent,"RosterOpenLocker")
	compare = D.button(self,Rect2(1460,0,244,42),"Comparer la sélection",func():app.SquadViews.comparison(app),false,"",true,app.accent,"OpenComparison")
	if app.model.get("epcrPreparation") is Dictionary:
		D.button(self,Rect2(860,0,380,42),"Préparer l’Europe",func():load("res://ui/epcr_preparation_dialog.gd").open(app),false,"",true,app.accent,"OpenEpcrPreparation")
	if int(state.get("immersive_tab", 0)) == 2:
		var review := preload("res://ui/contract_review.gd").build(app)
		add_child(review)
		D.place(review, Rect2(0, 60, 2248, 1068))
		return
	var table := D.panel(self,Rect2(0,60,1704,1068),"","","","ImmersiveRosterTable")
	var search := LineEdit.new()
	search.name="RosterSearch"
	search.placeholder_text="Rechercher dans l’effectif…"
	search.text=str(state.search)
	search.clear_button_enabled=true
	search.accessibility_name="Rechercher un joueur par nom ou poste"
	search.add_theme_font_override("font",C.BODY)
	search.add_theme_font_size_override("font_size",maxi(12,C.px(18)))
	search.add_theme_color_override("font_color",C.IVORY)
	search.add_theme_color_override("font_placeholder_color",C.MUTED)
	var search_surface := C.box(Color("0b1315"),C.LINE,5,12)
	search_surface.content_margin_left = C.px(47)
	search_surface.content_margin_top = C.px(8)
	search_surface.content_margin_bottom = C.px(8)
	search.add_theme_stylebox_override("normal",search_surface)
	table.add_child(search)
	D.place(search,Rect2(18,16,355,40))
	var search_glyph := C.icon("search",21,C.MUTED)
	search_glyph.name = "RosterSearchGlyph"
	search.add_child(search_glyph)
	D.place(search_glyph,Rect2(13,10,21,21))
	search.text_changed.connect(func(value:String):state.search=value;state.scroll=0;_refresh(false))
	_choice(table,Rect2(389,19,259,34),"RosterPosition",app.SquadViews._positions(app.model.get("squad",[])),str(state.position),"Poste",func(value:String):state.position=value;_refresh(false))
	_choice(table,Rect2(660,19,218,34),"RosterFamily",["Tous","Avants","Arrières","Blessés","Hors groupe",U.WATCH_FILTER],str(state.family),"Groupe",func(value:String):
		var redraw: bool = (state.family==U.WATCH_FILTER)!=(value==U.WATCH_FILTER)
		state.family=value;app.roster_filter=value
		if redraw:
			state.focus="RosterFamily"
			app._render(false)
		else:
			_refresh(false))
	_choice(table,Rect2(890,19,237,34),"RosterContract",["Tous","Fin de saison","Sans contrat"],str(state.contract),"Contrat",func(value:String):state.contract=value;_refresh(false))
	var options := D.button(table,Rect2(1140,19,192,34),"Filtres & tri",_advanced,false,"settings",true,app.accent,"RosterMoreFilters")
	options.add_theme_font_override("font",C.DISPLAY)
	options.add_theme_font_size_override("font_size",C.px(19))
	count=D.text(table,1680,43,"",19,C.MUTED,500,334,HORIZONTAL_ALIGNMENT_RIGHT)
	var header := D.rect(table,Rect2(17,71,1668,39),Color("1a2425"),4)
	header.name="RosterHeader"
	var columns := [["N°",9,"Numéro",40],["JOUEUR",61,"Nom",248],["POSTE PRINCIPAL",326,"Poste",154],["AUTRES",492,"Autres postes",70],["ÂGE",573,"Âge",60],["NIV.",648,"Niveau",50],["POT.",713,"Potentiel",58],["CONDITION",785,"Condition",128],["FAT.",923,"Fatigue",60],["SALAIRE "+G.salary_period(true).to_upper(),994,"Salaire",210],["FIN DE CONTRAT",1216,"Échéance",160],["MIN.",1378,"Minutes",95],["STATUT",1485,"Statut",175]]
	if state.family==U.WATCH_FILTER:
		columns = columns.slice(0,9) + [["MOTIF DE SURVEILLANCE",994,"Motif",364]] + columns.slice(11)
	for column: Array in columns:
		var caption := D.text(header,column[1],26,column[0],18,C.MUTED,600,column[3])
		caption.name={"Salaire":"RosterColumnSalary","Potentiel":"RosterColumnPotential","Poste":"RosterColumn_POSTE","Autres postes":"RosterColumnSecondaryPositions"}.get(column[2],"RosterColumnFatigue" if column[0]=="FAT." else "RosterColumn_"+str(column[0]))
		var key := str(column[2])
		var sort := Button.new()
		sort.name = "Sort_"+key
		sort.flat = true
		sort.focus_mode = Control.FOCUS_ALL
		header.add_child(sort)
		D.place(sort,Rect2(column[1]-2,0,column[3],39))
		sort_headers[key] = {"label":caption,"caption":str(column[0]),"button":sort}
		sort.pressed.connect(_toggle_sort.bind(key))
	var scroll := ScrollContainer.new()
	scroll.name="SquadScroll"
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	table.add_child(scroll)
	D.place(scroll,Rect2(18,116,1668,908))
	rows=C.v(2)
	rows.add_theme_constant_override("separation",C.px(2))
	rows.name="ImmersiveRosterRows"
	rows.custom_minimum_size.x=C.px(1668)
	C.fill(rows)
	scroll.add_child(rows)
	selected_summary=D.text(table,27,1056,"",20,C.MUTED,500,850)
	D.text(table,1680,1056,"Molette dans la liste · Début / Fin · Page ↑ / ↓",17,C.MUTED,400,780,HORIZONTAL_ALIGNMENT_RIGHT).name = "RosterScrollHint"
	dossier=Control.new()
	dossier.name="PlayerDossier"
	add_child(dossier)
	D.place(dossier,Rect2(1720,0,528,1128))
	_refresh(true)
	U.restore(app,self,"roster")

func _choice(parent: Node, rectangle: Rect2, id: String, values: Array, selected: String, caption: String, changed: Callable) -> OptionButton:
	var choice:=OptionButton.new()
	choice.name=id
	choice.fit_to_longest_item=false
	choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.tooltip_text=caption
	choice.add_theme_font_override("font",C.DISPLAY)
	choice.add_theme_font_size_override("font_size",maxi(12,C.px(19)))
	choice.add_theme_color_override("font_color",C.MUTED)
	choice.add_theme_stylebox_override("normal",C.box(Color("123d2c"),C.MUTED,5,8))
	for value in values:choice.add_item(caption+" : "+str(value))
	choice.select(maxi(0,values.find(selected)))
	choice.item_selected.connect(func(index:int):changed.call(str(values[index])))
	parent.add_child(choice)
	D.place(choice,rectangle)
	return choice

static func _known_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func primary_numbers(player: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var source: Variant = player.get("primaryPositions",[player.get("primaryPosition")])
	if not source is Array: return result
	for value: Variant in source:
		if not _known_number(value): continue
		var number := int(value)
		if float(value)==float(number) and number>=1 and number<=15 and not number in result: result.append(number)
	result.sort()
	return result

static func primary_caption(player: Dictionary) -> String:
	var numbers := primary_numbers(player)
	if numbers==[1,3]: return "Pilier G/D"
	if numbers==[6,7]: return "Troisième ligne aile"
	if numbers==[8]: return "Troisième ligne centre"
	return str(player.get("pos","—"))

static func secondary_numbers(player: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var source: Variant = player.get("secondaryPositions")
	if not source is Array: return result
	var primary := primary_numbers(player)
	for value: Variant in source:
		if not _known_number(value): continue
		var number := int(value)
		if float(value) != float(number) or number < 1 or number > 15 or number in result or number in primary: continue
		result.append(number)
	result.sort()
	return result

static func secondary_caption(player: Dictionary) -> String:
	var roles := secondary_roles(player)
	return "·".join(roles) if not roles.is_empty() else "—"

static func secondary_roles(player: Dictionary) -> Array[String]:
	var labels := {1:"PG",2:"T",3:"PD",4:"2E L",5:"2E L",6:"3E L",7:"3E L",8:"8",9:"DM",10:"DO",11:"AL",12:"C",13:"C",14:"AL",15:"AR"}
	var found: Array[String] = []
	for number: int in secondary_numbers(player):
		var role: String = labels[number]
		if not role in found: found.append(role)
	var result: Array[String] = []
	for role: String in ["PG","PD","T","2E L","3E L","8","DM","DO","C","AL","AR"]:
		if role in found: result.append(role)
	return result

static func secondary_tooltip(player: Dictionary, _model: Dictionary) -> String:
	var result: Array[String] = []
	var names := {"PG":"Pilier gauche", "PD":"Pilier droit", "T":"Talonneur", "2E L":"Deuxième ligne (4–5)", "3E L":"Troisième ligne aile (6–7)", "8":"Troisième ligne centre", "DM":"Demi de mêlée", "DO":"Demi d’ouverture", "C":"Centre (12–13)", "AL":"Ailier (11 et 14)", "AR":"Arrière"}
	for role: String in secondary_roles(player): result.append(role+" · "+str(names[role]))
	return "\n".join(result) if not result.is_empty() else "—"

static func _compare_secondary(left: Array, right: Array) -> int:
	for index in mini(left.size(),right.size()):
		if int(left[index]) != int(right[index]): return -1 if int(left[index]) < int(right[index]) else 1
	if left.size() == right.size(): return 0
	return -1 if left.size() < right.size() else 1

static func sort_value(player: Dictionary, key: String) -> Variant:
	if key in ["Niveau","Potentiel"]: return G.knowledge_sort_value(player,"rating" if key == "Niveau" else "potential",true)
	if key == "Autres postes":
		var order: Array[int] = []
		var roles: Array = ["PG","PD","T","2E L","3E L","8","DM","DO","C","AL","AR"]
		for role: String in secondary_roles(player): order.append(roles.find(role))
		return order if not order.is_empty() else null
	if key == "Statut":
		if _known_number(player.get("injury")) and float(player.injury) > 0: return U.fold("Blessé")
		var status: Variant = player.get("status")
		return U.fold(status.strip_edges()) if status is String and not status.strip_edges().is_empty() and status != "—" else null
	if key == "Motif":
		var source := player.duplicate()
		if not _known_number(source.get("condition")): source.condition = 100
		if not _known_number(source.get("physicalLoad")): source.physicalLoad = 0
		var reason := U.watch_reason(source)
		return U.fold(reason) if not reason.is_empty() else null
	var field: String = {"Numéro":"shirtNumber","Poste":"pos","Nom":"name","Niveau":"rating","Potentiel":"potential","Condition":"condition","Âge":"age","Salaire":"salary","Échéance":"contractEnd","Fatigue":"physicalLoad","Minutes":"minutes"}.get(key,"pos")
	var value: Variant = primary_caption(player) if key == "Poste" else player.get(field)
	if key in ["Nom","Poste"]:
		if not value is String or value.strip_edges().is_empty() or value.strip_edges() in ["—","-"]: return null
		var text := U.fold(value.strip_edges())
		# Le tri de poste conserve les familles rugby du tableau, puis le poste.
		if key == "Poste" and _known_number(player.get("fam")): return "%03d/" % int(player.fam) + text
		return text
	return value if _known_number(value) else null

static func ordered_players(source: Array, reading: Dictionary, season: int) -> Array:
	# Réutiliser les filtres sans subir un premier tri numérique sur un inconnu.
	var filtering := reading.duplicate()
	filtering.sort = "Nom"
	filtering.descending = false
	var result := U.players(source,filtering,season)
	var key := str(reading.get("sort","Poste"))
	var descending: bool = reading.get("descending",false)
	result.sort_custom(func(a: Dictionary,b: Dictionary):
		var left: Variant = sort_value(a,key)
		var right: Variant = sort_value(b,key)
		if left == null and right == null: return str(a.get("id","")) < str(b.get("id",""))
		if left == null: return false
		if right == null: return true
		if key == "Autres postes":
			var comparison := _compare_secondary(left,right)
			if comparison == 0: return str(a.get("id","")) < str(b.get("id",""))
			return comparison > 0 if descending else comparison < 0
		if left == right: return str(a.get("id","")) < str(b.get("id",""))
		return left > right if descending else left < right)
	return result

func _players() -> Array:
	return ordered_players(app.model.get("squad",[]),state,int(app.model.meta.get("season",1)))

func _toggle_sort(key: String) -> void:
	state.descending = not state.descending if state.sort == key else key in ["Niveau","Potentiel","Condition","Fatigue","Minutes"]
	state.sort = key
	app.roster_sort = key
	state.scroll = 0
	state.focus = "Sort_"+key
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	if scroll != null: scroll.scroll_vertical = 0
	_refresh(false)
	var button := find_child("Sort_"+key,true,false) as Button
	if button != null: button.grab_focus()

func _sort_header_state() -> void:
	for key: String in sort_headers:
		var header: Dictionary = sort_headers[key]
		var active: bool = state.sort == key
		var direction := "décroissant" if state.descending else "croissant"
		header.label.text = header.caption + (" ↓" if state.descending else " ↑") if active else header.caption
		header.label.add_theme_color_override("font_color",C.GOLD if active else C.MUTED)
		var detail := "par famille puis poste" if key == "Poste" else "par "+key
		header.button.tooltip_text = "Tri "+direction+" "+detail+" · cliquer pour inverser" if active else "Trier "+detail+" · valeurs inconnues en dernier"
		if key == "Niveau": header.button.tooltip_text += "\nNiveau global du joueur / 100."
		header.button.accessibility_name = str(header.caption)+" · "+("tri "+direction if active else "trier")

func _refresh(reveal: bool) -> void:
	_sort_header_state()
	for child in rows.get_children():rows.remove_child(child);child.queue_free()
	var players := _players()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	state.visible_player=app.selected_player
	count.text="%d / %d joueurs · liste complète" % [players.size(),app.model.get("squad",[]).size()]
	compare.text="Comparer (%d/2)" % app.management_ui.compare.size()
	var family := ""
	var visible := players
	for i in visible.size():
		var player:Dictionary=visible[i]
		var group := "AVANTS" if float(player.get("fam",0))<=3 else "ARRIÈRES"
		if state.sort=="Poste" and group!=family:
			family=group
			var banner:=Control.new()
			banner.custom_minimum_size=Vector2(C.px(1668),C.px(GROUP_HEIGHT))
			rows.add_child(banner)
			D.rect(banner,Rect2(0,0,1668,GROUP_HEIGHT),Color("122421"),2)
			var source: Array = players if state.family==U.WATCH_FILTER else app.model.get("squad",[])
			var total:int=source.filter(func(p:Dictionary):return (float(p.get("fam",0))<=3)==(group=="AVANTS")).size()
			D.text(banner,14,22,group+" · "+str(total)+" JOUEURS",19,C.GOLD,700,900)
		_row(player,i)
	if visible.is_empty():
		var empty:=C.wrap("Aucun joueur ne correspond. Modifiez les filtres ou réinitialisez la recherche.",22)
		rows.add_child(empty)
	if reveal:
		var scroll := find_child("SquadScroll",true,false) as ScrollContainer
		for row: Control in rows.get_children():
			if row.get_meta("player_id","") == app.selected_player and scroll != null:
				scroll.ensure_control_visible.call_deferred(row)
				break
	_profile()
	selected_summary.text="1 joueur sélectionné · "+str(P.player(app.model,app.selected_player).get("name","—"))

func _row(player:Dictionary,index:int) -> void:
	var row:=Button.new()
	row.name="SquadPlayer"+str(player.id).replace(":","_")
	row.set_meta("player_id",str(player.id))
	row.custom_minimum_size=Vector2(C.px(1668),C.px(ROW_HEIGHT))
	row.clip_contents=true
	row.tooltip_text=str(player.name)+" · "+primary_caption(player)
	row.add_theme_stylebox_override("normal",C.box(Color("155f3e") if str(player.id)==app.selected_player else Color("141d1f") if index%2==0 else Color.TRANSPARENT,Color.TRANSPARENT,3,0))
	row.add_theme_stylebox_override("hover",C.box(Color("244638"),C.MINT,3,0))
	row.add_theme_stylebox_override("focus",C.box(Color.TRANSPARENT,C.GOLD,3,0))
	rows.add_child(row)
	row.gui_input.connect(_row_key.bind(row))
	D.text(row,14,24,G.n(player.get("shirtNumber","—")) if player.get("shirtNumber")!=null else "—",21,C.MUTED,600,38)
	var portrait:Control=G.portrait(int(player.get("portraitIndex",0)),C.px(31),player) if not str(player.get("id","")).is_empty() else C.photo("player-%02d" % posmod(int(player.get("portraitIndex",index)),16))
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.tooltip_text+="\n"+portrait.tooltip_text
	var reason := U.watch_reason(player) if state.family==U.WATCH_FILTER else ""
	if not reason.is_empty():
		row.tooltip_text += "\n" + reason
		row.accessibility_name = str(player.name) + " · " + primary_caption(player) + " · " + reason
	row.add_child(portrait)
	D.place(portrait,Rect2(54,2,31,30))
	D.text(row,95,24,player.name,23,C.IVORY,600,190)
	var main_position := D.text(row,325,24,primary_caption(player),21,C.MUTED,500,154)
	main_position.name = "RosterPrimaryPosition"
	main_position.mouse_filter = Control.MOUSE_FILTER_PASS
	var primary: Array[String] = []
	for number: int in primary_numbers(player): primary.append(str(number))
	main_position.tooltip_text = "Poste principal · %s · %s" % ["·".join(primary),primary_caption(player)] if not primary.is_empty() else primary_caption(player)
	var other := D.text(row,529,24,secondary_caption(player),18,C.BLUE,600,76,HORIZONTAL_ALIGNMENT_CENTER)
	other.name = "RosterSecondaryPositions"
	other.mouse_filter = Control.MOUSE_FILTER_PASS
	other.tooltip_text = secondary_tooltip(player,app.model)
	other.accessibility_name = "Autres postes · "+other.tooltip_text.replace("\n"," ; ")
	row.tooltip_text += "\nAutres postes · "+other.tooltip_text.replace("\n"," ; ")
	D.text(row,590,24,G.n(player.get("age","—")),22,C.IVORY,500,44,HORIZONTAL_ALIGNMENT_CENTER)
	var level := D.text(row,662,24,G.rating_text(player,true),20,C.MINT,700,60,HORIZONTAL_ALIGNMENT_CENTER)
	var potential := D.text(row,729,24,G.potential_text(player),20,POTENTIAL_COLOR,600,60,HORIZONTAL_ALIGNMENT_CENTER)
	level.name = "RosterLevel"
	potential.name = "RosterPotential"
	var condition:float=player.get("condition",0)
	if float(player.get("injury",0))>0:D.text(row,835,24,"Indisponible",19,C.ALERT,600,110,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		D.bar(row,Rect2(786,17,64,5),condition,C.AMBER if condition<85 else C.MINT)
		D.text(row,892,24,"%d%%" % condition,21,C.AMBER if condition<85 else C.MINT,600,55,HORIZONTAL_ALIGNMENT_RIGHT)
	var fatigue:float=player.get("physicalLoad",0)
	D.text(row,942,24,G.n(fatigue),21,C.AMBER if fatigue>50 else C.MUTED,500,48,HORIZONTAL_ALIGNMENT_CENTER)
	if state.family==U.WATCH_FILTER:
		D.text(row,1002,24,reason,22,C.AMBER,600,354).name="RosterWatchReason"
	else:
		D.text(row,1203,24,G.salary_amount(player.get("salary",0)),23,C.IVORY,500,210,HORIZONTAL_ALIGNMENT_RIGHT)
		var contract_end: Variant = player.get("contractEnd")
		var expiring: bool = contract_end != null and int(contract_end) <= int(app.model.meta.get("season",1))
		D.text(row,1296,24,G.contract_year(contract_end),22,C.AMBER if expiring else C.MUTED,500,150,HORIZONTAL_ALIGNMENT_CENTER).name = "RosterContractEnd"
	D.text(row,1407,24,G.n(player.get("minutes",0)),22,C.MUTED,500,90,HORIZONTAL_ALIGNMENT_RIGHT)
	var status:String="Blessé" if float(player.get("injury",0))>0 else str(player.get("status","Disponible"))
	D.chip(row,Rect2(1477,3,170,26),status,C.ALERT if status=="Blessé" else C.GOLD if status.contains("clé") else C.MINT)
	row.pressed.connect(func():
		app.selected_player=str(player.id);app.management_ui.profile_scroll=0;state.visible_player=app.selected_player
		for button:Node in rows.get_children():
			if button is Button:button.add_theme_stylebox_override("normal",C.box(Color("155f3e") if button.get_meta("player_id","")==app.selected_player else Color("141d1f"),Color.TRANSPARENT,3,0))
		_profile()
		selected_summary.text="1 joueur sélectionné · "+str(player.name)
		app._observe_navigation())

func _row_key(event: InputEvent, current: Button) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed: return
	if event.keycode not in [KEY_HOME,KEY_END,KEY_PAGEUP,KEY_PAGEDOWN]: return
	var items := rows.get_children().filter(func(node: Node): return node is Button and node.has_meta("player_id"))
	if items.is_empty(): return
	var index := items.find(current)
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	var stride := maxi(1,floori(scroll.size.y / float(C.px(ROW_HEIGHT)+C.px(2)))-1)
	var target := 0 if event.keycode == KEY_HOME else items.size()-1 if event.keycode == KEY_END else clampi(index+(-stride if event.keycode == KEY_PAGEUP else stride),0,items.size()-1)
	get_viewport().set_input_as_handled()
	items[target].grab_focus()
	scroll.ensure_control_visible(items[target])
	state.scroll = scroll.scroll_vertical

func _profile() -> void:
	for child in dossier.get_children():dossier.remove_child(child);child.queue_free()
	var player:=P.player(app.model,app.selected_player)
	dossier.set_meta("player_id",app.selected_player)
	if player.is_empty():return
	var shirt: Variant = player.get("shirtNumber")
	var injury := float(player.get("injury", 0))
	var recovering := injury <= 0 and P.player_in_recovery(app.model, str(player.id))
	var status := str(player.get("status", "Disponible"))
	var hero:=D.panel(dossier,Rect2(0,0,528,432),str(player.name),"",G.n(shirt) if shirt != null else "","SelectedPlayerCard")
	if not str(player.get("id","")).is_empty():
		var portrait:=G.portrait(int(player.get("portraitIndex",0)),C.px(187),player)
		hero.add_child(portrait);D.place(portrait,Rect2(19,74,187,235))
	else:D.photo(hero,"squad-portrait",Rect2(19,74,187,235))
	D.text(hero,227,100,primary_caption(player).to_upper(),24,C.GOLD,700,281)
	D.text(hero,227,133,G.n(player.get("age","—"))+" ans",22,C.MUTED,500,281)
	D.text(hero,227,167,G.n(player.get("appearances",0))+" apparitions · "+G.n(player.get("minutes",0))+" min",22,C.MUTED,500,281)
	D.text(hero,240,241,G.rating_text(player,true),48,C.MINT,700,123)
	D.text(hero,372,237,G.potential_text(player),34,POTENTIAL_COLOR,700,123)
	D.text(hero,240,271,"NIVEAU",18,C.MUTED,500,123)
	D.text(hero,372,271,"POTENTIEL",18,C.MUTED,500,123)
	D.chip(hero,Rect2(19,329,137,31),status,C.ALERT if injury > 0 else C.MINT).name = "SelectedPlayerStatus"
	var compared:bool=app.selected_player in app.management_ui.compare
	var toggle:=D.button(hero,Rect2(167,329,148,31),"Retirer" if compared else "Comparer",func():
		if app.selected_player in app.management_ui.compare:app.management_ui.compare.erase(app.selected_player)
		elif app.management_ui.compare.size()<2:app.management_ui.compare.append(app.selected_player)
		var action := dossier.find_child("CompareSelected",true,false) as Button
		if action != null: action.text="Retirer" if app.selected_player in app.management_ui.compare else "Comparer"
		compare.text="Comparer (%d/2)" % app.management_ui.compare.size(),false,"",true,app.accent,"CompareSelected")
	toggle.disabled=not compared and app.management_ui.compare.size()>=2
	D.button(hero,Rect2(19,380,489,36),"Ouvrir la fiche joueur",func():app.set_meta("immersive08_full_player",true);app._render(),true,"arrow",true,app.accent,"OpenPlayerFull")
	var health:=D.panel(dossier,Rect2(0,448,528,254),"DISPONIBILITÉ","heart")
	D.text(health,23,92,"Condition",22,C.MUTED,500,350)
	D.text(health,504,92,G.n(player.get("condition",0))+" %",29,C.MINT,600,120,HORIZONTAL_ALIGNMENT_RIGHT)
	D.bar(health,Rect2(23,112,481,8),float(player.get("condition",0)))
	D.text(health,23,156,"Fatigue",22,C.MUTED,500,350)
	D.text(health,504,156,G.n(player.get("physicalLoad",0))+" / 100",26,C.MINT,600,160,HORIZONTAL_ALIGNMENT_RIGHT)
	D.bar(health,Rect2(23,175,481,7),float(player.get("physicalLoad",0)),C.GOLD)
	var availability := "En reprise" if recovering else "Disponible"
	if injury > 0: availability = "Blessure · " + G.n(injury) + " sem."
	var plan: String = Training.INDIVIDUAL.get(player.get("loadPlan", "collective"), "Charge non renseignée")
	D.text(health,23,223,availability+" · "+plan,22,C.ALERT if injury > 0 else C.AMBER if recovering else C.IVORY,500,481).name = "SelectedPlayerAvailability"
	var contract:=D.panel(dossier,Rect2(0,718,528,188),"CONTRAT & STATUT","money")
	D.text(contract,24,94,G.salary(player.get("salary",0)),34,C.IVORY,600,480)
	D.text(contract,24,129,"Fin de contrat : " + G.contract_year(player.get("contractEnd")),23,C.MUTED,500,480)
	var renewal:Dictionary=player.get("renewal",{})
	var reason := str(renewal.get("reason", ""))
	var offer:=D.button(contract,Rect2(305,143,198,32),"Prolonger" if reason.is_empty() else "Négociation close",func():app.SquadViews.contract(app,player,false),false,"",true,app.accent,"OfferRenewal")
	offer.disabled=not renewal.get("available",false) or not app._live().is_empty()
	if not reason.is_empty(): offer.tooltip_text = reason
	var contract_end: Variant = player.get("contractEnd")
	var depth:=D.panel(dossier,Rect2(0,922,528,206),"L’ÉQUILIBRE DU GROUPE","people")
	var source:Array=app.model.get("squad",[])
	var forwards:int=source.filter(func(p:Dictionary):return float(p.get("fam",0))<=3).size()
	var young:int=source.filter(func(p:Dictionary):return int(p.get("age",99))<=21).size()
	for i in 3:
		var values:Array=[["Avants",forwards],["Arrières",source.size()-forwards],["Joueurs U21",young]][i]
		D.text(depth,24,88+i*36,values[0],21,C.MUTED,500,180)
		D.text(depth,503,88+i*36,str(values[1]),24,C.IVORY,600,60,HORIZONTAL_ALIGNMENT_RIGHT)
		D.bar(depth,Rect2(225,79+i*36,203,6),100.0*int(values[1])/maxi(1,source.size()),C.GOLD if i==2 else C.MINT)

func _advanced() -> void:
	var dialog:=AcceptDialog.new()
	dialog.name="RosterAdvancedFilters"
	app._prepare_dialog(dialog,600)
	dialog.title="Filtres et tri de l’effectif"
	var fields:=C.v(12)
	dialog.add_child(fields)
	_choice(fields,Rect2(0,0,500,40),"RosterAvailability",["Tous","Disponibles","Blessés"],str(state.available),"Disponibilité",func(value:String):state.available=value;_refresh(false))
	_choice(fields,Rect2(0,55,500,40),"RosterSort",["Numéro","Poste","Autres postes","Nom","Niveau","Potentiel","Condition","Fatigue","Minutes","Statut","Âge","Salaire","Échéance","Motif"],str(state.sort),"Trier par",func(value:String):state.sort=value;app.roster_sort=value;_refresh(false))
	var direction:=C.button("Changer le sens du tri",func():state.descending=not state.descending;_refresh(false))
	direction.name="RosterDirection"
	fields.add_child(direction)
	var reset:=C.button("Réinitialiser les filtres",func():app.management_ui.roster=U.defaults();app.roster_filter="Tous";app.roster_sort="Poste";dialog.queue_free();app._render())
	reset.name="RosterReset"
	fields.add_child(reset)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(600,280))
