extends Control
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const ROW_HEIGHT := 33
const GROUP_HEIGHT := 29
const Training = preload("res://ui/immersive08/training_canvas.gd")
var app: Control
var state: Dictionary
var rows: VBoxContainer
var dossier: Control
var count: Label
var page_info: Label
var previous: Button
var next: Button
var compare: Button
var selected_summary: Label
var capacity := 24

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
	if not state.has("page"): state.page = 0
	state.family = app.roster_filter
	state.sort = app.roster_sort
	var tabs := ["Vue d’ensemble","Condition","Contrats","Développement"]
	for i in tabs.size():
		D.button(self,Rect2(i*211,0,199,42),tabs[i],func():
			state.immersive_tab=i
			state.sort=["Poste","Condition","Échéance","Potentiel"][i]
			state.descending=i in [1,3]
			state.page=0
			app.roster_sort=state.sort
			app._render(),int(state.get("immersive_tab",0))==i,"",true,app.accent,"RosterTab"+str(i))
	D.button(self,Rect2(1258,0,184,42),"Vestiaire",func():app._navigate("Vestiaire"),false,"people",true,app.accent,"RosterOpenLocker")
	compare = D.button(self,Rect2(1460,0,244,42),"Comparer la sélection",func():app.SquadViews.comparison(app),false,"",true,app.accent,"OpenComparison")
	if app.model.get("epcrPreparation") is Dictionary:
		D.button(self,Rect2(860,0,380,42),"Préparer l’Europe",func():load("res://ui/epcr_preparation_dialog.gd").open(app),false,"",true,app.accent,"OpenEpcrPreparation")
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
	search.text_changed.connect(func(value:String):state.search=value;state.page=0;state.scroll=0;_refresh(false))
	_choice(table,Rect2(389,19,259,34),"RosterPosition",app.SquadViews._positions(app.model.get("squad",[])),str(state.position),"Poste",func(value:String):state.position=value;state.page=0;_refresh(false))
	_choice(table,Rect2(660,19,218,34),"RosterFamily",["Tous","Avants","Arrières","Blessés","Hors groupe"],str(state.family),"Groupe",func(value:String):state.family=value;app.roster_filter=value;state.page=0;_refresh(false))
	_choice(table,Rect2(890,19,237,34),"RosterContract",["Tous","Fin de saison","Sans contrat"],str(state.contract),"Contrat",func(value:String):state.contract=value;state.page=0;_refresh(false))
	var options := D.button(table,Rect2(1140,19,192,34),"Filtres & tri",_advanced,false,"settings",true,app.accent,"RosterMoreFilters")
	options.add_theme_font_override("font",C.DISPLAY)
	options.add_theme_font_size_override("font_size",C.px(19))
	count=D.text(table,1680,43,"",19,C.MUTED,500,334,HORIZONTAL_ALIGNMENT_RIGHT)
	var header := D.rect(table,Rect2(17,71,1668,39),Color("1a2425"),4)
	header.name="RosterHeader"
	var columns := [["N°",9,"",40],["JOUEUR",61,"Nom",288],["POSTE",364,"Poste",196],["ÂGE",573,"Âge",60],["NIV.",648,"Niveau",50],["POT.",713,"Potentiel",58],["CONDITION",785,"Condition",128],["FAT.",923,"",60],["NOTE",994,"",72],["SALAIRE / SEM.",1083,"Salaire",160],["CONTRAT",1256,"Échéance",107],["MIN.",1378,"",95],["STATUT",1485,"",175]]
	for column: Array in columns:
		var caption := D.text(header,column[1],26,column[0],18,C.MUTED,600,column[3])
		caption.name={"Salaire":"RosterColumnSalary","Potentiel":"RosterColumnPotential"}.get(column[2],"RosterColumnFatigue" if column[0]=="FAT." else "RosterColumn_"+str(column[0]))
		if not str(column[2]).is_empty():
			var sort := Button.new()
			sort.name="Sort_"+str(column[2])
			sort.flat=true
			sort.tooltip_text="Trier par "+str(column[2])
			header.add_child(sort)
			D.place(sort,Rect2(column[1]-2,0,column[3],39))
			sort.pressed.connect(func():
				state.descending=not state.descending if state.sort==column[2] else column[2] in ["Niveau","Potentiel","Condition"]
				state.sort=column[2];app.roster_sort=state.sort;state.page=0;_refresh(false))
	var scroll := ScrollContainer.new()
	scroll.name="SquadScroll"
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	table.add_child(scroll)
	D.place(scroll,Rect2(18,116,1668,908))
	# Réserver la place de deux intertitres sur une page pleine.
	var full_page := capacity*C.px(ROW_HEIGHT)+2*C.px(GROUP_HEIGHT)
	var gap := floori((scroll.size.y-full_page)/float(capacity+1))
	rows=C.v(2)
	rows.add_theme_constant_override("separation",clampi(gap,0,C.px(2)))
	rows.name="ImmersiveRosterRows"
	rows.custom_minimum_size.x=C.px(1668)
	C.fill(rows)
	scroll.add_child(rows)
	selected_summary=D.text(table,27,1056,"",20,C.MUTED,500,850)
	previous=D.button(table,Rect2(1070,1030,170,30),"← Précédent",func():state.page=maxi(0,int(state.page)-1);_refresh(false),false,"",true,app.accent,"RosterPaginationPrevious")
	page_info=D.text(table,1366,1054,"",19,C.MUTED,500,190,HORIZONTAL_ALIGNMENT_CENTER)
	page_info.name="RosterPaginationInfo"
	next=D.button(table,Rect2(1480,1030,190,30),"Suivant →",func():state.page=int(state.page)+1;_refresh(false),false,"",true,app.accent,"RosterPaginationNext")
	var pager_height := maxf(25.0,C.px(30))
	var pager_max_top := table.size.y-pager_height-C.px(2)
	for button: Button in [previous,next]:
		for mode in ["hover","pressed","disabled"]:
			var style := button.get_theme_stylebox(mode)
			style.content_margin_top=0
			style.content_margin_bottom=0
		button.position.y=minf(button.position.y,pager_max_top)
		button.set_deferred("size",Vector2(button.size.x,pager_height))
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

func _players() -> Array:
	var result := U.players(app.model.get("squad",[]),state,int(app.model.meta.get("season",1)))
	if state.sort=="Potentiel":result.sort_custom(func(a:Dictionary,b:Dictionary):return float(a.get("potential",0))>float(b.get("potential",0)) if state.descending else float(a.get("potential",0))<float(b.get("potential",0)))
	if state.sort=="Poste":result.sort_custom(func(a:Dictionary,b:Dictionary):
		if a.get("fam",0)==b.get("fam",0):return str(a.id)<str(b.id)
		return float(a.get("fam",0))>float(b.get("fam",0)) if state.descending else float(a.get("fam",0))<float(b.get("fam",0)))
	return result

func _refresh(reveal: bool) -> void:
	for child in rows.get_children():rows.remove_child(child);child.queue_free()
	var players := _players()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	if reveal and str(state.get("visible_player",""))!=app.selected_player:
		for i in players.size():
			if str(players[i].id)==app.selected_player:state.page=i/capacity;break
	state.visible_player=app.selected_player
	var pages:=maxi(1,ceili(float(players.size())/capacity))
	state.page=clampi(int(state.page),0,pages-1)
	previous.disabled=int(state.page)==0
	next.disabled=int(state.page)>=pages-1
	page_info.text="Page %d / %d" % [int(state.page)+1,pages]
	count.text="%d / %d joueurs affichés" % [mini(capacity,maxi(0,players.size()-int(state.page)*capacity)),players.size()]
	compare.text="Comparer (%d/2)" % app.management_ui.compare.size()
	var family := ""
	var visible := players.slice(int(state.page)*capacity,(int(state.page)+1)*capacity)
	for i in visible.size():
		var player:Dictionary=visible[i]
		var group := "AVANTS" if float(player.get("fam",0))<=3 else "ARRIÈRES"
		if state.sort=="Poste" and group!=family:
			family=group
			var banner:=Control.new()
			banner.custom_minimum_size=Vector2(C.px(1668),C.px(GROUP_HEIGHT))
			rows.add_child(banner)
			D.rect(banner,Rect2(0,0,1668,GROUP_HEIGHT),Color("122421"),2)
			var total:int=app.model.get("squad",[]).filter(func(p:Dictionary):return (float(p.get("fam",0))<=3)==(group=="AVANTS")).size()
			D.text(banner,14,22,group+" · "+str(total)+" JOUEURS",19,C.GOLD,700,900)
		_row(player,i)
	if visible.is_empty():
		var empty:=C.wrap("Aucun joueur ne correspond. Modifiez les filtres ou réinitialisez la recherche.",22)
		rows.add_child(empty)
	_profile()
	selected_summary.text="1 joueur sélectionné · "+str(P.player(app.model,app.selected_player).get("name","—"))

func _row(player:Dictionary,index:int) -> void:
	var row:=Button.new()
	row.name="SquadPlayer"+str(player.id).replace(":","_")
	row.set_meta("player_id",str(player.id))
	row.custom_minimum_size=Vector2(C.px(1668),C.px(ROW_HEIGHT))
	row.clip_contents=true
	row.tooltip_text=str(player.name)+" · "+str(player.pos)
	row.add_theme_stylebox_override("normal",C.box(Color("155f3e") if str(player.id)==app.selected_player else Color("141d1f") if index%2==0 else Color.TRANSPARENT,Color.TRANSPARENT,3,0))
	row.add_theme_stylebox_override("hover",C.box(Color("244638"),C.MINT,3,0))
	row.add_theme_stylebox_override("focus",C.box(Color.TRANSPARENT,C.GOLD,3,0))
	rows.add_child(row)
	D.text(row,14,24,G.n(player.get("shirtNumber","—")) if player.get("shirtNumber")!=null else "—",21,C.MUTED,600,38)
	var portrait:Control=G.portrait(int(player.get("portraitIndex",0)),C.px(31),player) if not str(player.get("id","")).is_empty() else C.photo("player-%02d" % posmod(int(player.get("portraitIndex",index)),16))
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.tooltip_text+="\n"+portrait.tooltip_text
	row.add_child(portrait)
	D.place(portrait,Rect2(54,2,31,30))
	D.text(row,95,24,player.name,23,C.IVORY,600,259)
	D.text(row,363,24,player.pos,21,C.MUTED,500,202)
	D.text(row,590,24,G.n(player.get("age","—")),22,C.IVORY,500,44,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(row,662,24,G.n(player.get("rating","—")),24,C.MINT if float(player.get("rating",0))>=84 else C.IVORY,700,48,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(row,729,24,G.n(player.get("potential","—")),24,C.GOLD if float(player.get("potential",0))>=87 else C.IVORY,600,48,HORIZONTAL_ALIGNMENT_CENTER)
	var condition:float=player.get("condition",0)
	if float(player.get("injury",0))>0:D.text(row,835,24,"Indisponible",19,C.ALERT,600,110,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		D.bar(row,Rect2(786,17,64,5),condition,C.AMBER if condition<85 else C.MINT)
		D.text(row,892,24,"%d%%" % condition,21,C.AMBER if condition<85 else C.MINT,600,55,HORIZONTAL_ALIGNMENT_RIGHT)
	var fatigue:float=player.get("physicalLoad",0)
	D.text(row,942,24,G.n(fatigue),21,C.AMBER if fatigue>50 else C.MUTED,500,48,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(row,1018,24,G.n(player.get("note","—")),22,C.MINT,600,55,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(row,1198,24,G.euros(player.get("salary",0)),23,C.IVORY,500,162,HORIZONTAL_ALIGNMENT_RIGHT)
	var contract_end: Variant = player.get("contractEnd")
	var expiring: bool = contract_end != null and int(contract_end) <= int(app.model.meta.get("season",1))
	D.text(row,1289,24,"—" if contract_end == null else "S"+G.n(contract_end),22,C.AMBER if expiring else C.MUTED,500,90,HORIZONTAL_ALIGNMENT_CENTER)
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
	D.text(hero,227,100,str(player.pos).to_upper(),24,C.GOLD,700,281)
	D.text(hero,227,133,G.n(player.get("age","—"))+" ans",22,C.MUTED,500,281)
	D.text(hero,227,167,G.n(player.get("appearances",0))+" apparitions · "+G.n(player.get("minutes",0))+" min",22,C.MUTED,500,281)
	D.text(hero,240,241,G.n(player.get("rating","—")),74,C.MINT,700,123)
	D.text(hero,372,237,G.n(player.get("potential","—")),53,C.GOLD,700,123)
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
	D.text(contract,24,94,G.euros(player.get("salary",0))+" / semaine",34,C.IVORY,600,480)
	D.text(contract,24,129,str(player.get("contractLabel","—")),23,C.MUTED,500,480)
	var renewal:Dictionary=player.get("renewal",{})
	var offer:=D.button(contract,Rect2(305,143,198,32),"Prolonger",func():app.SquadViews.contract(app,player,false),false,"",true,app.accent,"OfferRenewal")
	offer.disabled=not renewal.get("available",false) or not app._live().is_empty()
	var contract_end: Variant = player.get("contractEnd")
	D.text(contract,24,167,"Échéance : —" if contract_end == null else "Échéance : saison "+G.n(contract_end),21,C.MUTED,500,280)
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
	_choice(fields,Rect2(0,0,500,40),"RosterAvailability",["Tous","Disponibles","Blessés"],str(state.available),"Disponibilité",func(value:String):state.available=value;state.page=0;_refresh(false))
	_choice(fields,Rect2(0,55,500,40),"RosterSort",["Poste","Nom","Niveau","Potentiel","Condition","Âge","Salaire","Échéance"],str(state.sort),"Trier par",func(value:String):state.sort=value;app.roster_sort=value;state.page=0;_refresh(false))
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
