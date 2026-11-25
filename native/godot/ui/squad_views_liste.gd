extends "res://ui/squad_views_fiche.gd"
## Liste de l'Effectif : page, lignes du tableau et ouverture de la fiche (découpe de squad_views.gd, sans changement).

static func squad(app: Control) -> Control:
	var page := G.h(8)
	G.fill(page,true)
	page.name="CarnetSquad"
	var table := G.panel(page,1.4)
	table.add_theme_constant_override("separation",4)
	G.chapter(table,"01","Le groupe professionnel","Rechercher, consulter et comparer sans perdre ta place.",app.accent)
	if app.model.get("epcrPreparation") is Dictionary:
		var europe := G.button("Préparer l’Europe",func():load("res://ui/epcr_preparation_dialog.gd").open(app))
		europe.name = "OpenEpcrPreparation"
		table.add_child(europe)
	var state:Dictionary=app.management_ui.roster
	state.family=app.roster_filter;state.sort=app.roster_sort
	var search:=_search(table,"RosterSearch",state)
	search.custom_minimum_size.y=28
	var filters:=G.h(6)
	table.add_child(filters)
	var family:=_choice(filters,"RosterFamily",["Tous","Avants","Arrières","Blessés","Hors groupe",U.WATCH_FILTER],state.family,"Groupe")
	var position:=_choice(filters,"RosterPosition",_positions(app.model.get("squad",[])),state.position,"Poste")
	var available:=_choice(filters,"RosterAvailability",["Tous","Disponibles","Blessés"],state.available,"Disponibilité")
	var contract_filter:=_choice(filters,"RosterContract",["Tous","Fin de saison","Sans contrat"],state.contract,"Contrat")
	var sorting:=G.h(6)
	sorting.name="RosterTools"
	table.add_child(sorting)
	var sort:=_choice(sorting,"RosterSort",["Poste","Nom","Niveau","Condition","Âge","Salaire","Échéance"],state.sort,"Trier par")
	var direction:=G.button("↓ Décroissant" if state.descending else "↑ Croissant",func():state.descending=not state.descending;app._render())
	direction.name="RosterDirection"
	G.reading_button(direction,105)
	sorting.add_child(direction)
	var compare:=G.button("COMPARER (%d/2)"%app.management_ui.compare.size(),func():comparison(app))
	compare.name="OpenComparison"
	G.reading_button(compare,130)
	sorting.add_child(compare)
	var reset:=G.button("Réinitialiser",func():app.management_ui.roster=U.defaults();app.roster_filter="Tous";app.roster_sort="Poste";app._render())
	reset.name="RosterReset"
	G.reading_button(reset,100)
	sorting.add_child(reset)
	var count:=G.label("",12,G.MUTED)
	count.name="RosterCount"
	table.add_child(count)
	var header := G.h(4)
	header.name="RosterHeader"
	table.add_child(header)
	var list := G.scroll(table)
	# A dossier opened by ID may be beyond the first page. Keep that request
	# through the initial container sizing, but never override voluntary paging.
	list.set_meta("reveal_id", app.selected_player if str(state.get("visible_player", "")) != app.selected_player else "")
	list.add_theme_constant_override("separation",2)
	list.get_parent().name="SquadScroll"
	list.get_parent().mouse_force_pass_scroll_events=false
	var profile := G.panel(page,1.1)
	profile.name="PlayerDossier"
	var refresh:=func():_squad_rows(app,list,profile,count,compare)
	var user_refresh:=func():list.set_meta("reveal_id", "");refresh.call()
	list.get_parent().resized.connect(func():
		if _roster_columns(list.get_parent().size.x).size()!=int(list.get_meta("column_count",0)): refresh.call_deferred())
	search.text_changed.connect(func(text:String):state.search=text;state.scroll=0;state.page=0;user_refresh.call())
	family.item_selected.connect(func(index:int):state.family=family.get_item_text(index);app.roster_filter=state.family;state.scroll=0;state.page=0;user_refresh.call())
	position.item_selected.connect(func(index:int):state.position=position.get_item_text(index);state.scroll=0;state.page=0;user_refresh.call())
	available.item_selected.connect(func(index:int):state.available=available.get_item_text(index);state.scroll=0;state.page=0;user_refresh.call())
	contract_filter.item_selected.connect(func(index:int):state.contract=contract_filter.get_item_text(index);state.scroll=0;state.page=0;user_refresh.call())
	sort.item_selected.connect(func(index:int):state.erase("table_sort");state.sort=sort.get_item_text(index);app.roster_sort=state.sort;state.descending=state.sort in ["Niveau","Condition"];state.scroll=0;app._render())
	refresh.call()
	U.restore(app,page,"roster")
	return page

static func _squad_rows(app:Control,list:VBoxContainer,profile:VBoxContainer,count:Label,compare:Button) -> void:
	var focus:=app.get_viewport().gui_get_focus_owner()
	var focus_id:=str(focus.get_meta("player_id","")) if focus!=null and list.is_ancestor_of(focus) else ""
	_empty(list)
	var state:Dictionary=app.management_ui.roster
	var columns:=_roster_columns(list.get_parent().size.x)
	if state.family==U.WATCH_FILTER: columns.insert(1,["watch","MOTIF",190])
	list.set_meta("column_count",columns.size())
	var header:HBoxContainer=list.get_parent().get_parent().find_child("RosterHeader",false,false)
	_empty(header)
	var key: String = str(state.get("table_sort",{"Nom":"name","Poste":"pos","Âge":"age","Niveau":"rating","Condition":"condition","Salaire":"salary","Échéance":"contractEnd"}.get(state.sort,"pos")))
	for column:Array in columns:
		var field: String=column[0]
		var label:=G.button(str(column[1])+((" ↓" if state.descending else " ↑") if key==field else ""),func():
			state.descending=not state.descending if key==field else false
			state.table_sort=field;state.scroll=0
			_squad_rows(app,list,profile,count,compare)
			var next: Control=header.find_child("RosterColumn_"+field,false,false)
			if next!=null:FocusLater.grab(next))
		label.name="RosterColumn_"+field
		label.custom_minimum_size.x=column[2]
		if field=="name": G.fill(label)
		label.tooltip_text="Trier "+str(column[1])+" · valeurs inconnues en dernier"
		header.add_child(label)
	var players:Array=TableOrder.ordered(U.players(app.model.get("squad",[]),app.management_ui.roster,int(app.model.meta.get("season",1))),key,state.descending,func(person:Dictionary,field:String): return U.watch_reason(person) if field=="watch" else load("res://ui/notation_staff.gd").tri_champ(person,"potential" if field == "potential" else "rating",true) if field in ["rating","potential","note"] else person.get(field))
	count.text="%d / %d joueurs · lecture seule"%[players.size(),app.model.get("squad",[]).size()]
	compare.text="COMPARER (%d/2)"%app.management_ui.compare.size()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	state.visible_player=app.selected_player
	if players.is_empty():list.add_child(G.wrap("Aucun joueur ne correspond. Modifie la recherche ou réinitialise les filtres.",15))
	var revealed: Button = null
	# Reprise : internationaux encore en congés après leur tournée d'été (reprise.cjs).
	var on_leave := {}
	for away: Dictionary in app.model.get("clubLife", {}).get("reprise", {}).get("internationals", []):
		if str(away.get("status", "")).begins_with("en congés"): on_leave[str(away.get("id", ""))] = str(away.get("returnDate", ""))
	for p in players:
		var b := G.button("",func():
			list.set_meta("reveal_id", "")
			app.selected_player=str(p.id);app.management_ui.profile_scroll=0
			for row:Button in list.get_children():
				G.clear_selection(row)
				if str(row.get_meta("player_id",""))==str(p.id):G.selected(row,app.accent)
			_show_profile(app,profile)
			if app.has_method("_observe_navigation"): app._observe_navigation())
		b.custom_minimum_size.y=26
		b.name="SquadPlayer"+str(p.id).replace(":","_")
		b.set_meta("player_id",str(p.id))
		if str(p.id)==str(list.get_meta("reveal_id","")):revealed=b
		b.tooltip_text=str(p.name)+" · "+str(p.pos)
		if on_leave.has(str(p.id)): b.tooltip_text += "\nEn congés · retour le " + preload("res://ui/reprise_view.gd").day_text(on_leave[str(p.id)])
		if state.family==U.WATCH_FILTER:
			b.tooltip_text += "\n" + U.watch_reason(p)
			b.accessibility_name = b.tooltip_text
		if str(p.id)==app.selected_player: G.selected(b,app.accent)
		var inset:=G.margin(4)
		inset.add_theme_constant_override("margin_top",2)
		inset.add_theme_constant_override("margin_bottom",2)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(inset)
		var row:=G.h(4)
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inset.add_child(row)
		for column:Array in columns:
			var value:=_roster_value(p,str(column[0]),columns[1][2]<=POS_COMPACT_WIDTH)
			var color: Color = G.POTENTIAL_COLOR if column[0]=="potential" else G.INK if column[0]=="name" else (G.GOLD if column[0]=="watch" else G.MUTED)
			if state.family==U.WATCH_FILTER and column[0]=="condition" and float(p.get("injury",0))>0:
				value="Blessé"
				color=G.ALERT
			if column[0]=="condition" and on_leave.has(str(p.id)):
				value="Congés"
				color=G.GOLD
			var label:=G.cell(value,column[2],color,column[0]=="name")
			label.name="RosterValue_"+str(column[0])
			label.tooltip_text=position_label(str(p.get("pos","—"))) if column[0]=="pos" else value
			row.add_child(label)
		list.add_child(b)
		if str(p.id)==focus_id:FocusLater.grab(b)
	list.get_parent().set_deferred("scroll_vertical",int(app.management_ui.roster.scroll))
	if revealed!=null:_reveal_roster_row.call_deferred(app,list,revealed)
	_show_profile(app,profile)

static func _show_profile(app:Control,parent:VBoxContainer) -> void:
	# Filtering changes the list only. Keep the currently read dossier intact.
	if parent.get_meta("player_id","")==app.selected_player and parent.get_child_count()>0:return
	_empty(parent)
	parent.set_meta("player_id",app.selected_player)
	for p:Dictionary in app.model.get("squad",[]):
		if str(p.id)==app.selected_player:_profile(app,parent,p);return
	parent.add_child(G.wrap("Sélectionne un joueur pour consulter son dossier.",15))
