extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const Board = preload("res://ui/lineup_board.gd")
const U = preload("res://ui/management_state.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")

# Keep the bound dictionary when a career reset replaces management_ui. Retiring
# controls can only update their former UI state, never the new career's state.
class LineupReading extends HBoxContainer:
	var state: Dictionary
	var outer: ScrollContainer
	var restoring := true
	func _ready() -> void:
		for control: Control in find_children("*","Control",true,false):
			if control.focus_mode != Control.FOCUS_NONE:
				control.focus_entered.connect(func():
					if is_inside_tree() and not restoring: state.focus=str(control.name))
		outer.get_v_scroll_bar().value_changed.connect(func(value:float):
			if is_inside_tree() and not restoring:state.outer=int(value))
		var list:ScrollContainer=find_child("LineupCandidatesScroll",true,false)
		list.get_v_scroll_bar().value_changed.connect(func(value:float):
			if is_inside_tree() and not restoring:state.list=int(value))
		_restore.call_deferred()
	func _restore() -> void:
		if not is_inside_tree():return
		var tree:=get_tree()
		await tree.process_frame
		await tree.process_frame
		if not is_inside_tree() or not is_instance_valid(outer) or not outer.is_inside_tree():return
		var control:Control=find_child(str(state.focus),true,false) if not str(state.focus).is_empty() else null
		if control!=null and control.is_visible_in_tree() and (not control is BaseButton or not control.disabled):control.grab_focus()
		await tree.process_frame
		if not is_inside_tree() or not is_instance_valid(outer) or not outer.is_inside_tree():return
		var list:ScrollContainer=find_child("LineupCandidatesScroll",true,false)
		list.scroll_vertical=int(state.list)
		outer.scroll_vertical=int(state.outer)
		# The eligibility message may shrink after assignment and grow the list.
		# Keep the closest valid offset when its previous bottom no longer exists.
		state.list=list.scroll_vertical
		state.outer=outer.scroll_vertical
		restoring=false

static func squad(app: Control) -> Control:
	var page := G.h(8)
	G.fill(page,true)
	page.name="CarnetSquad"
	var table := G.panel(page,1.4)
	table.add_theme_constant_override("separation",4)
	G.chapter(table,"01","Le groupe professionnel","Rechercher, consulter et comparer sans perdre votre place.",app.accent)
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
	var family:=_choice(filters,"RosterFamily",["Tous","Avants","Arrières","Blessés","Hors groupe"],state.family,"Groupe")
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
	var pagination := _pagination(table,"RosterPagination",state)
	var profile := G.panel(page,1.1)
	profile.name="PlayerDossier"
	var refresh:=func():_squad_rows(app,list,profile,count,compare)
	var user_refresh:=func():list.set_meta("reveal_id", "");refresh.call()
	_bind_pagination(pagination,state,user_refresh)
	list.get_parent().resized.connect(func():
		var capacity:=maxi(1,int((list.get_parent().size.y+2)/28))
		var columns:=_roster_columns(list.get_parent().size.x).size()
		if capacity!=int(state.get("page_size",4)) or columns!=int(list.get_meta("column_count",0)):
			state.page_size=capacity;refresh.call_deferred())
	search.text_changed.connect(func(text:String):state.search=text;state.scroll=0;state.page=0;user_refresh.call())
	family.item_selected.connect(func(index:int):state.family=family.get_item_text(index);app.roster_filter=state.family;state.scroll=0;state.page=0;user_refresh.call())
	position.item_selected.connect(func(index:int):state.position=position.get_item_text(index);state.scroll=0;state.page=0;user_refresh.call())
	available.item_selected.connect(func(index:int):state.available=available.get_item_text(index);state.scroll=0;state.page=0;user_refresh.call())
	contract_filter.item_selected.connect(func(index:int):state.contract=contract_filter.get_item_text(index);state.scroll=0;state.page=0;user_refresh.call())
	sort.item_selected.connect(func(index:int):state.sort=sort.get_item_text(index);app.roster_sort=state.sort;state.descending=state.sort in ["Niveau","Condition"];state.scroll=0;app._render())
	refresh.call()
	U.restore(app,page,"roster")
	return page

static func _empty(parent:Node) -> void:
	for child in parent.get_children():parent.remove_child(child);child.queue_free()

static func _pagination(parent:Node,id:String,state:Dictionary) -> HBoxContainer:
	var row:=G.h(6)
	row.name=id
	parent.add_child(row)
	var previous:=G.reading_button(G.button("← Précédent",func():pass),88)
	previous.name=id+"Previous"
	row.add_child(previous)
	var info:=G.label("",12,G.MUTED)
	info.name=id+"Info"
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	G.fill(info)
	row.add_child(info)
	var next:=G.reading_button(G.button("Suivant →",func():pass),88)
	next.name=id+"Next"
	row.add_child(next)
	if not state.has("page"):state.page=0
	return row

static func _bind_pagination(row:HBoxContainer,state:Dictionary,refresh:Callable) -> void:
	row.get_child(0).pressed.connect(func():
		state.page=maxi(0,int(state.page)-1);state.scroll=0;refresh.call()
		if not row.get_child(0).disabled:row.get_child(0).grab_focus()
		elif not row.get_child(2).disabled:row.get_child(2).grab_focus())
	row.get_child(2).pressed.connect(func():
		state.page=int(state.page)+1;state.scroll=0;refresh.call()
		if not row.get_child(2).disabled:row.get_child(2).grab_focus()
		elif not row.get_child(0).disabled:row.get_child(0).grab_focus())

static func _page_range(row:HBoxContainer,state:Dictionary,total:int,capacity:int) -> Vector2i:
	var pages:=maxi(1,ceili(float(total)/capacity))
	state.page=clampi(int(state.get("page",0)),0,pages-1)
	row.get_child(0).disabled=int(state.page)==0
	row.get_child(2).disabled=int(state.page)>=pages-1
	row.get_child(1).text="Page %d / %d"%[int(state.page)+1,pages]
	return Vector2i(int(state.page)*capacity,mini(total,(int(state.page)+1)*capacity))

static func _search(parent:Node,id:String,state:Dictionary) -> LineEdit:
	var search:=LineEdit.new()
	search.name=id
	search.placeholder_text="Rechercher un nom ou un poste…"
	search.clear_button_enabled=true
	search.text=state.search
	search.custom_minimum_size.y=38
	search.add_theme_color_override("font_placeholder_color",G.MUTED)
	search.accessibility_name="Rechercher un joueur par nom ou poste"
	parent.add_child(search)
	return search

static func _positions(source:Array) -> Array:
	var values:Array=[]
	for p:Dictionary in source:
		if p.pos not in values:values.append(str(p.pos))
	values.sort()
	return ["Tous"]+values

static func _choice(parent:Node,id:String,values:Array,selected:Variant,caption:String) -> OptionButton:
	var box:=G.v(2)
	G.fill(box)
	parent.add_child(box)
	box.add_child(G.label(caption,12,G.MUTED))
	var choice:=OptionButton.new()
	choice.name=id
	choice.custom_minimum_size.y=34
	G.reading_button(choice,64)
	choice.fit_to_longest_item=false
	choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.tooltip_text=caption
	for text in values:choice.add_item(str(text))
	choice.select(maxi(0,values.find(selected)))
	box.add_child(choice)
	return choice

static func _squad_rows(app:Control,list:VBoxContainer,profile:VBoxContainer,count:Label,compare:Button) -> void:
	var focus:=app.get_viewport().gui_get_focus_owner()
	var focus_id:=str(focus.get_meta("player_id","")) if focus!=null and list.is_ancestor_of(focus) else ""
	_empty(list)
	var columns:=_roster_columns(list.get_parent().size.x)
	list.set_meta("column_count",columns.size())
	var header:HBoxContainer=list.get_parent().get_parent().find_child("RosterHeader",false,false)
	_empty(header)
	for column:Array in columns:
		var label:=G.cell(column[1],column[2],G.MUTED,column[0]=="name")
		label.name="RosterColumn_"+str(column[0])
		header.add_child(label)
	var players:Array=U.players(app.model.get("squad",[]),app.management_ui.roster,int(app.model.meta.get("season",1)))
	var state:Dictionary=app.management_ui.roster
	var capacity:=maxi(1,int(state.get("page_size",4)))
	var reveal_id := focus_id if not focus_id.is_empty() else str(list.get_meta("reveal_id", ""))
	if not reveal_id.is_empty():
		for i in players.size():
			if str(players[i].id)==reveal_id:state.page=i/capacity;break
	var bounds:=_page_range(list.get_parent().get_parent().find_child("RosterPagination",false,false),state,players.size(),capacity)
	count.text="%d / %d joueurs · lecture seule"%[players.size(),app.model.get("squad",[]).size()]
	compare.text="COMPARER (%d/2)"%app.management_ui.compare.size()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	state.visible_player=app.selected_player
	if players.is_empty():list.add_child(G.wrap("Aucun joueur ne correspond. Modifiez la recherche ou réinitialisez les filtres.",15))
	for p in players.slice(bounds.x,bounds.y):
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
		b.tooltip_text=str(p.name)+" · "+str(p.pos)
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
			var value:=_roster_value(p,str(column[0]))
			var label:=G.cell(value,column[2],G.INK if column[0]=="name" else G.MUTED,column[0]=="name")
			label.name="RosterValue_"+str(column[0])
			label.tooltip_text=value
			row.add_child(label)
		list.add_child(b)
		if str(p.id)==focus_id:b.grab_focus.call_deferred()
	list.get_parent().set_deferred("scroll_vertical",int(app.management_ui.roster.scroll))
	_show_profile(app,profile)

static func _roster_columns(width:float) -> Array:
	var columns:Array=[["name","JOUEUR",130],["pos","POSTE",64],["age","ÂGE",26],["rating","NIV.",30],["condition","COND.",42]]
	if width>=700:columns.append_array([["salary","SALAIRE / S.",78],["contractEnd","ÉCH.",38]])
	if width>=900:columns.append_array([["minutes","MIN.",42],["appearances","APP.",32],["physicalLoad","CHARGE",42]])
	if width>=950:
		columns[1][2]=100
		columns.append_array([["potential","POT.",32],["note","NOTE",34],["status","SÉLECTION",76]])
	return columns

static func _roster_value(p:Dictionary,key:String) -> String:
	if key=="salary":return G.euros(p.get(key,0))
	if key=="condition":return G.n(p.get(key,0))+"%"
	if key=="contractEnd":return "—" if p.get(key)==null else "S"+G.n(p[key])
	if key in ["name","pos","status"]:return str(p.get(key,"—"))
	return "—" if p.get(key)==null else G.n(p[key])

static func _show_profile(app:Control,parent:VBoxContainer) -> void:
	# Filtering changes the list only. Keep the currently read dossier intact.
	if parent.get_meta("player_id","")==app.selected_player and parent.get_child_count()>0:return
	_empty(parent)
	parent.set_meta("player_id",app.selected_player)
	for p:Dictionary in app.model.get("squad",[]):
		if str(p.id)==app.selected_player:_profile(app,parent,p);return
	parent.add_child(G.wrap("Sélectionnez un joueur pour consulter son dossier.",15))

static func player_load_unavailable_reason(app: Control) -> String:
	var meta: Dictionary = app.model.get("meta", {})
	var live: Dictionary = app._live()
	if not live.is_empty():
		return "Charge indisponible avant la validation de la journée." if live.get("finished", false) else "Charge indisponible pendant le match."
	if meta.get("phase") == "ended": return "Charge indisponible en fin de saison."
	if meta.get("trained", false): return "Séance effectuée. La charge se règle avant la prochaine séance."
	return ""

static func _profile(app:Control,parent:VBoxContainer,p:Dictionary) -> void:
	parent.get_parent().size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	var list:=G.scroll(parent)
	# Let the tabs share the actual dossier height inside its scroll viewport.
	list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.get_parent().name="ProfileScroll"
	list.add_theme_constant_override("separation",4)
	var top:=G.h(8)
	list.add_child(top)
	var portrait := G.portrait(int(p.get("portraitIndex",0)),48,p)
	top.add_child(portrait)
	var identity:=G.v(3)
	G.fill(identity)
	top.add_child(identity)
	var name:=G.label(p.name,18,G.INK)
	name.name="ProfilePlayerName"
	name.add_theme_font_size_override("font_size",18)
	name.add_theme_font_override("font",G.T.DISPLAY)
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(name)
	identity.add_child(G.wrap("%s · %s ans"%[p.pos,G.n(p.age)],12))
	list.add_child(G.separator())
	var tabs:=TabContainer.new()
	tabs.name="ProfileTabs"
	tabs.theme=G.T.paper()
	tabs.custom_minimum_size.y=200
	G.fill(tabs,true)
	list.add_child(tabs)
	var overview:=G.scroll(tabs)
	overview.get_parent().name="ProfileOverview"
	var attributes:=G.scroll(tabs)
	attributes.get_parent().name="ProfileAttributes"
	var contracts:=G.scroll(tabs)
	contracts.get_parent().name="ProfileContract"
	var references_tab:=G.scroll(tabs)
	references_tab.get_parent().name="ProfileReferences"
	for i in 4:tabs.set_tab_title(i,["Aperçu","Attributs","Contrat","Repères"][i])
	tabs.current_tab=clampi(int(app.management_ui.get("profile_tab",0)),0,3)
	tabs.tab_changed.connect(func(index:int):app.management_ui.profile_tab=index)
	var actions:=_profile_overview(overview,p,app.accent,app.model.get("clubLife",{}).get("coachNotebook",{}).get("entries",[]),app)
	var note:=G.button("MA NOTE SUR CE JOUEUR",func(): preload("res://ui/coach_notes_view.gd").open(app,str(p.id)))
	note.name="OpenPlayerCoachNote"
	G.fill(note)
	actions.add_child(note)
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",20)
	attributes.add_child(grid)
	for pair in [["scrum","Mêlée"],["lineout","Touche"],["tackle","Plaquage"],["speed","Vitesse"],["pass","Passe"],["kick","Jeu au pied"],["goal","But"],["mental","Mental"],["discipline","Discipline"],["stamina","Endurance"],["power","Puissance"]]:
		var value: Variant = p.get("attributes",{}).get(pair[0])
		if value != null: G.gauge(grid, pair[1], float(value), 100, G.accent_ink(app.accent))
		else: grid.add_child(G.label(pair[1]+"  —",14,G.MUTED))
	contracts.add_child(G.wrap("Contrat courant : "+p.get("contractLabel",""),13))
	contracts.add_child(G.wrap(G.euros(p.get("salary",0))+" / semaine",12,G.MUTED))
	var compared:bool=str(p.id) in app.management_ui.compare
	var compare:=G.button("RETIRER DE LA COMPARAISON" if compared else "AJOUTER À LA COMPARAISON",func():
		if str(p.id) in app.management_ui.compare:app.management_ui.compare.erase(str(p.id))
		elif app.management_ui.compare.size()<2:app.management_ui.compare.append(str(p.id))
		app._render())
	compare.name="CompareSelected"
	compare.disabled=not compared and app.management_ui.compare.size()>=2
	compare.tooltip_text="Deux joueurs maximum. Le dialogue Comparer permet de changer les deux dossiers."
	G.fill(compare)
	actions.add_child(compare)
	var renewal:Dictionary=p.get("renewal",{})
	var extend:=G.button("PROPOSER UNE PROLONGATION",func(): contract(app,p,false))
	extend.name="OfferRenewal"
	extend.disabled=not renewal.get("available",false) or not app._live().is_empty()
	extend.tooltip_text="Le contrat ne permet pas de prolongation supplémentaire dans la limite de trois saisons." if not renewal.get("available",false) else "Une offre sera soumise au joueur avant toute signature."
	contracts.add_child(extend)
	contracts.add_child(G.label("CHARGE INDIVIDUELLE",13,G.MUTED))
	var load_plan:=OptionButton.new()
	var modes:Array=["collective","repos","normal","intense"]
	for text in ["Suivre le collectif","Récupération individuelle","Charge normale","Charge intense"]:load_plan.add_item(text)
	load_plan.name="PlayerLoad"
	load_plan.select(maxi(0,modes.find(p.get("loadPlan","collective"))))
	var load_reason := player_load_unavailable_reason(app)
	load_plan.disabled = not load_reason.is_empty()
	load_plan.item_selected.connect(func(index:int):app._command("set_player_load",{"playerId":p.id,"mode":modes[index]}))
	contracts.add_child(load_plan)
	if not load_reason.is_empty():
		load_plan.focus_mode = Control.FOCUS_NONE
		var load_hint := G.wrap(load_reason,13)
		load_hint.name = "PlayerLoadUnavailableReason"
		contracts.add_child(load_hint)
	references_tab.add_child(G.section("Repères de départ","Origine et degré de vérification des données initiales"))
	var roster:Dictionary=p.get("rosterProfile",{}) if p.get("rosterProfile")!=null else {}
	if not roster.is_empty():
		var position:Dictionary=roster.get("position",{})
		var status:Dictionary=roster.get("status",{})
		var initial:Dictionary=roster.get("contract",{})
		var position_basis:String="poste officiel" if position.get("basis")=="official" else "poste estimé"
		references_tab.add_child(G.wrap("Poste principal : %s · %s"%[position.get("primary",p.pos),position_basis],13,G.MUTED))
		references_tab.add_child(G.wrap("Qualification initiale de jeu : %s"%", ".join(position.get("qualifications",[])),13,G.MUTED))
		var status_basis:String="type de contrat officiel" if status.get("basis")=="official" else "estimation de jeu au 01/07/2026"
		references_tab.add_child(G.wrap("Statut initial : %s · %s"%[str(status.get("value","inconnu")).capitalize(),status_basis],13,G.MUTED))
		if status.get("professionalFromSeason")!=null: references_tab.add_child(G.wrap("Référence initiale : passage professionnel prévu en saison %s."%G.n(status.professionalFromSeason),12,G.MUTED))
		var basis:String="échéance officielle publiée" if initial.get("basis")=="official" else "durée estimée de jeu"
		var references:String=", ".join(initial.get("sources",[]))
		references_tab.add_child(G.wrap("Référence initiale au 31/10/2026 : %s · %s (fin saison %s)."%[basis,G.n(initial.get("endYear",0)),G.n(initial.get("endSeason",0))],13,G.MUTED))
		if not references.is_empty():
			var source_dates:Array[String]=[]
			for source_id in initial.get("sources",[]):
				var source:Dictionary=app.model.get("meta",{}).get("rosterSources",{}).get(source_id,{})
				source_dates.append(str(source.get("published","date inconnue")))
			references_tab.add_child(G.wrap("Publication officielle : %s · les signatures en jeu restent indépendantes."%", ".join(source_dates),12,G.MUTED))
	references_tab.add_child(G.wrap(portrait.tooltip_text,12,G.MUTED))
	# The scroll owns these callbacks; weak captures also survive queued calls
	# after a different player replaces its retired dossier.
	var refs:Array[WeakRef]=[weakref(app),weakref(parent),weakref(list),weakref(tabs),weakref(overview)]
	var fit:=func():
		var nodes:Array=[]
		for ref:WeakRef in refs:
			var node:Variant=ref.get_ref()
			if node==null:return
			nodes.append(node)
		_fit_profile(nodes[0],nodes[1],nodes[2],nodes[3],nodes[4])
	var schedule:=func():fit.call_deferred()
	list.get_parent().resized.connect(schedule)
	app.resized.connect(schedule)
	list.tree_exiting.connect(func():
		var owner:Control=refs[0].get_ref()
		if owner!=null and owner.resized.is_connected(schedule):owner.resized.disconnect(schedule))
	overview.minimum_size_changed.connect(func():fit.call_deferred())
	fit.call_deferred()

static func _profile_tile(parent:Node,id:String,caption:String,prefix:String="ProfileTile") -> VBoxContainer:
	var frame:=PanelContainer.new()
	frame.name=prefix+id
	G.fill(frame)
	frame.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	var style:=G.T.box(Color("fcfcf8"),3,G.LINE)
	style.shadow_color=Color(0,0,0,.07)
	style.shadow_size=2;style.shadow_offset=Vector2(0,1)
	style.content_margin_left=8;style.content_margin_right=8
	style.content_margin_top=3;style.content_margin_bottom=3
	frame.add_theme_stylebox_override("panel",style)
	parent.add_child(frame)
	var body:=G.v(2)
	frame.add_child(body)
	body.add_child(G.label(caption.to_upper(),11,G.MUTED))
	return body

static func _profile_fact(parent:Node,id:String,caption:String,value:String) -> void:
	var row:=G.h(5)
	parent.add_child(row)
	var label:=G.label(caption,11,G.MUTED)
	G.fill(label)
	row.add_child(label)
	var fact:=G.label(value,12,G.INK)
	fact.name=id
	row.add_child(fact)

static func _profile_overview(parent:VBoxContainer,p:Dictionary,accent:Color,notes:Array,app:Control) -> HBoxContainer:
	var tiles:=G.h(6)
	tiles.name="ProfileOverviewTiles"
	G.fill(tiles)
	parent.add_child(tiles)
	var left:=G.v(6);G.fill(left);tiles.add_child(left)
	var right:=G.v(6);G.fill(right);tiles.add_child(right)
	var condition:=_profile_tile(left,"Condition","Situation et préparation")
	_profile_fact(condition,"ProfileConditionValue","Condition",G.n(p.get("condition",0))+"%")
	_profile_fact(condition,"ProfileLoadValue","Charge",G.n(p.get("physicalLoad",0)))
	_profile_fact(condition,"ProfileStatusValue","Sélection",str(p.get("status","—")))
	var plans:Dictionary={"collective":"Collectif","repos":"Récupération","normal":"Normale","intense":"Intense"}
	_profile_fact(condition,"ProfilePlanValue","Charge prévue",str(plans.get(p.get("loadPlan","collective"),"—")))
	var contract_tile:=_profile_tile(right,"Contract","Contrat courant")
	var term:=G.wrap(str(p.get("contractLabel","—")),12,G.INK)
	term.name="ProfileContractValue";contract_tile.add_child(term)
	_profile_fact(contract_tile,"ProfileSalaryValue","Par semaine",G.euros(p.get("salary",0)))
	var renewal:Dictionary=p.get("renewal",{})
	_profile_fact(contract_tile,"ProfileRenewalValue","Prolongation","Disponible" if renewal.get("available",false) else "Indisponible")
	if renewal.get("available",false):
		_profile_fact(contract_tile,"ProfileRenewalTerm","Durée possible","%s–%s saisons"%[G.n(renewal.get("minYears",1)),G.n(renewal.get("maxYears",1))])
	var season:=_profile_tile(left,"Season","Usage en saison")
	_profile_fact(season,"ProfileMinutesValue","Minutes",G.n(p.get("minutes",0)))
	_profile_fact(season,"ProfileAppearancesValue","Apparitions",G.n(p.get("appearances",0)))
	_profile_fact(season,"ProfileNumberValue","Numéro","—" if p.get("shirtNumber")==null else G.n(p.shirtNumber))
	_profile_fact(season,"ProfileRoleValue","Note au poste",G.n(p.get("note",0)))
	var evaluation:=_profile_tile(right,"Evaluation","Évaluation")
	_profile_fact(evaluation,"ProfileRatingValue","Niveau",G.n(p.get("rating",0)))
	_profile_fact(evaluation,"ProfilePotentialValue","Potentiel",G.n(p.get("potential",0)))
	var qualities:=_profile_tile(left,"Attributes","Profil de jeu")
	var row:=G.h(4);qualities.add_child(row)
	var radar:=G.W.new()
	radar_setup(radar,p,accent)
	radar.custom_minimum_size=Vector2(72,72)
	row.add_child(radar)
	var figures:=G.v(0);G.fill(figures);row.add_child(figures)
	var attrs:Dictionary=p.get("attributes",{})
	for pair in [["scrum","Mêlée"],["lineout","Touche"],["tackle","Plaquage"],["speed","Vitesse"],["pass","Passe"],["kick","Pied"],["goal","But"],["mental","Mental"],["discipline","Discipline"],["stamina","Endurance"],["power","Puissance"]]:
		var value:Variant=attrs.get(pair[0])
		var quality:=G.h(4);figures.add_child(quality)
		var caption:=G.label(pair[1],11,G.MUTED);caption.custom_minimum_size.x=56;quality.add_child(caption)
		var bar:=ProgressBar.new();bar.name="ProfileAttributeBar_"+str(pair[0])
		bar.show_percentage=false;bar.max_value=100;bar.value=0 if value==null else float(value)
		bar.custom_minimum_size=Vector2(22,3);G.fill(bar);bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		quality.add_child(bar)
		var figure:=G.label("—" if value==null else G.n(value),11,G.INK)
		figure.name="ProfileAttribute_"+str(pair[0]);figure.custom_minimum_size.x=18;quality.add_child(figure)
	var qualifications:=_profile_tile(right,"Qualifications","Postes")
	var roster:Dictionary=p.get("rosterProfile",{}) if p.get("rosterProfile") is Dictionary else {}
	var positions:Array=roster.get("position",{}).get("qualifications",[])
	var qualification_text:=G.wrap("Non renseignées" if positions.is_empty() else ", ".join(positions),12,G.INK)
	qualification_text.name="ProfileQualificationsValue"
	qualifications.add_child(qualification_text)
	qualifications.add_child(G.label("Détails dans Repères",11,G.MUTED))
	var note_home:=G.v(3);note_home.name="ProfileCompactNoteHome";qualifications.add_child(note_home)
	for entry:Dictionary in notes:
		if str(entry.get("target",""))!=str(p.id):continue
		var note_content:=G.v(3);note_content.name="ProfileNoteContent";note_home.add_child(note_content)
		note_content.add_child(G.separator())
		note_content.add_child(G.label("MA NOTE · S%s / SEMAINE %s"%[G.n(entry.get("season",1)),G.n(int(entry.get("week",0))+1)],11,G.MUTED))
		var preview:=G.wrap(str(entry.get("text","")),12,G.INK)
		preview.name="ProfileNotePreview";preview.max_lines_visible=4
		preview.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		preview.tooltip_text=preview.text;note_content.add_child(preview)
		break
	_profile_contexts(parent,p,app)
	var actions:=G.h(6)
	actions.name="ProfileOverviewActions"
	parent.add_child(actions)
	return actions

static func _fit_profile(app:Control,parent:VBoxContainer,list:VBoxContainer,tabs:TabContainer,overview:VBoxContainer) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():return
	if not is_instance_valid(list) or not list.is_inside_tree() or not parent.is_ancestor_of(list):return
	var desktop:bool=app.size.y>=1000
	overview.get_node("ProfileContexts").visible=desktop
	var peer_rows:VBoxContainer=overview.find_child("ProfileContextPeerRows",true,false)
	for i in peer_rows.get_child_count():peer_rows.get_child(i).visible=i<(5 if app.size.y>=1200 else 3)
	var content:=overview.find_child("ProfileNoteContent",true,false)
	if content!=null:
		var destination:=overview.find_child("ProfileStaffNoteSlot" if desktop else "ProfileCompactNoteHome",true,false)
		if content.get_parent()!=destination:content.reparent(destination,false)
	for label:Label in overview.find_children("ProfileContextText*","Label",true,false):label.max_lines_visible=3 if app.size.y>=1200 else 2
	tabs.custom_minimum_size.y=overview.get_combined_minimum_size().y+tabs.get_tab_bar().get_combined_minimum_size().y+16
	var budget:float=app.body_scroll.size.y-12.0 if is_instance_valid(app.body_scroll) else app.size.y-180.0
	if budget>0:list.get_parent().custom_minimum_size.y=minf(list.get_combined_minimum_size().y,budget)

static func radar_setup(radar:Control,p:Dictionary,accent:Color) -> void:
	radar_mode(radar)
	radar.accent=accent
	var attrs:Dictionary=p.get("attributes",{})
	radar.values=[attrs.get("power",0),attrs.get("speed",0),attrs.get("pass",0),attrs.get("tackle",0),attrs.get("stamina",0),attrs.get("mental",0)]
	radar.grid_color=G.LINE
	radar.data_color=G.accent_ink(accent)
	radar.custom_minimum_size=Vector2(140,140)

static func radar_mode(radar:Control) -> void:
	radar.mode="radar"

static func lineup(app:Control) -> Control:
	var page:=LineupReading.new()
	page.add_theme_constant_override("separation",14)
	if not app.management_ui.get("lineup") is Dictionary:app.management_ui.lineup={"outer":0,"list":0,"focus":""}
	page.state=app.management_ui.lineup
	page.outer=app.body_scroll
	G.fill(page,true)
	page.name="CarnetLineup"
	var pitch:=G.panel(page,1.15)
	if app.size.y<=760:pitch.add_theme_constant_override("separation",3)
	G.chapter(pitch,"02","La feuille de match","Titulaire ou remplaçant : choisissez un poste.",app.accent)
	var board:=Board.new()
	board.app=app
	pitch.add_child(board)
	var bench:=G.h(5)
	pitch.add_child(bench)
	for i in 8:
		var slot:=15+i
		var b:=G.button(str(slot+1),func():app.selected_slot=slot;app._render())
		b.name="LineupSlot%02d"%(slot+1)
		G.fill(b)
		if app.selected_slot==slot: b.add_theme_stylebox_override("normal",G.T.box(Color("ddd1bc"),3,G.GOLD))
		bench.add_child(b)
	var side:=G.panel(page,1.0)
	side.add_child(G.section("Poste %02d"%(app.selected_slot+1),"Seuls les joueurs disponibles et qualifiés peuvent être affectés."))
	var selection:Dictionary=app.model.get("selection",{})
	var slots:Array=selection.get("slots",[])
	var selected:Dictionary={}
	for s in slots:
		if int(s.get("slot",-1))==app.selected_slot:selected=s
	var errors:Array=selection.get("errors",[])
	if errors.is_empty():side.add_child(G.label("FEUILLE VALIDE",12,G.GOOD))
	else:side.add_child(G.wrap("\n".join(errors),12,G.ALERT))
	var licences: Dictionary = selection.get("nationaleQualification", {})
	if not licences.is_empty():
		var bloc := G.wrap("FFR  ·  4 licences B/C dont 1 C maximum  ·  %d à vérifier" % int(licences.unverified), 11, G.MUTED)
		bloc.name = "NationaleLicenceNotice"
		var note: Dictionary = licences.get("notice", {})
		bloc.tooltip_text = str(note.get("summary", "")) + "\n" + str(note.get("detail", ""))
		side.add_child(bloc)
	var auto:=G.button("SÉLECTION AUTOMATIQUE DU STAFF",func():app._command("auto_lineup"))
	auto.name="LineupAutomatic"
	auto.disabled=not app._live().is_empty()
	side.add_child(auto)
	if not selection.get("valid",true):
		var cover:=G.button("COMPLÉTER AVEC LE CENTRE DE FORMATION",func():app.confirm("Renforcer la feuille de match", "Le staff sélectionne d'abord les joueurs disponibles, puis promeut de vrais joueurs aux postes manquants. Chaque promotion ajoute 2 500 € de salaire par semaine. Confirmer ?",func():app._command("promote_cover",{"confirmed":true})))
		cover.disabled=not app._live().is_empty() or app.model.meta.get("canAdvanceSeason",false)
		cover.tooltip_text="Une solution de secours payante ; vous pouvez aussi composer votre groupe ou recruter."
		side.add_child(cover)
	var list:=G.scroll(side)
	list.get_parent().name="LineupCandidatesScroll"
	var eligible:Variant=selected.get("eligibleIds")
	for p in app.model.get("squad",[]):
		var b:=G.button("%s  ·  %s  ·  %s"%[p.name,p.pos,G.n(p.rating)],func():app._command("set_lineup",{"playerId":p.id,"slot":app.selected_slot}))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text="%s · %s · niveau %s"%[p.name,p.pos,G.n(p.rating)]
		b.set_meta("player_id",str(p.id))
		b.name="LineupPlayer"+str(p.id).replace(":","_")
		b.disabled=not app._live().is_empty() or float(p.get("injury",0))>0 or (eligible is Array and p.id not in eligible)
		if b.disabled:b.tooltip_text="Indisponible ou qualification incompatible avec ce poste. Pendant un match, utilisez les remplacements."
		list.add_child(b)
	var remove:=G.button("LIBÉRER CE POSTE",func():app._command("set_lineup",{"playerId":null,"slot":app.selected_slot}))
	remove.name="LineupRemove"
	remove.disabled=not app._live().is_empty()
	side.add_child(remove)
	return page

static func preparation(app:Control) -> Control:
	return preload("res://ui/preparation_view.gd").build(app)

static func market(app:Control) -> Control:
	var page:=G.h(14)
	page.name="CarnetMarket"
	G.fill(page,true)
	var workspace:=G.panel(page)
	G.chapter(workspace,"05","Les pistes de recrutement","Joueurs disponibles · une offre ouvre une négociation.",app.accent)
	var tabs:=TabContainer.new()
	tabs.name="MarketTabs"
	tabs.theme=G.T.paper()
	G.fill(tabs,true)
	workspace.add_child(tabs)
	var browse:=G.v(8)
	browse.name="MarketBrowse"
	G.fill(browse,true)
	tabs.add_child(browse)
	var staff:=G.scroll(tabs)
	staff.get_parent().name="RecruitmentStaff"
	preload("res://ui/decision_views.gd").recruitment_summary(app,staff)
	preload("res://ui/regen_scouting_view.gd").entry(app,staff)
	preload("res://ui/interclub_market_view.gd").entry(app,staff)
	tabs.set_tab_title(0,"Pistes")
	tabs.set_tab_title(1,"Travail du staff")
	tabs.current_tab=clampi(int(app.management_ui.get("market_tab",0)),0,1)
	tabs.tab_changed.connect(func(index:int):app.management_ui.market_tab=index)
	workspace=browse
	var state:Dictionary=app.management_ui.market
	var search:=_search(workspace,"MarketSearch",state)
	var controls:=G.h(8)
	workspace.add_child(controls)
	var position:=_choice(controls,"MarketPosition",_positions(app.model.get("market",[])),state.position,"Poste")
	var available:=_choice(controls,"MarketAvailability",["Tous","Disponibles"],state.available,"Offres")
	var sort:=_choice(controls,"MarketSort",["Poste","Nom","Niveau","Âge","Salaire"],state.sort,"Trier par")
	var direction:=G.button("↓ Décroissant" if state.descending else "↑ Croissant",func():state.descending=not state.descending;app._render())
	direction.name="MarketDirection"
	controls.add_child(direction)
	var follow:=CheckBox.new()
	follow.name="MarketFollowed"
	follow.text="Joueurs suivis"
	follow.button_pressed=state.followed
	controls.add_child(follow)
	var reset:=G.button("Réinitialiser",func():app.management_ui.market=U.defaults();app._render())
	reset.name="MarketReset"
	controls.add_child(reset)
	var count:=G.label("",12,G.MUTED)
	count.name="MarketCount"
	workspace.add_child(count)
	var list:=G.scroll(workspace)
	list.get_parent().name="MarketScroll"
	var pagination:=_pagination(workspace,"MarketPagination",state)
	var refresh:=func():_market_rows(app,list,count)
	_bind_pagination(pagination,state,refresh)
	page.resized.connect(func():
		var capacity:=2 if app.size.y<=760 else 4 if app.size.y<=940 else 6
		if int(state.get("page_size",0))!=capacity:state.page_size=capacity;refresh.call_deferred())
	search.text_changed.connect(func(text:String):state.search=text;state.navigation_id="";state.scroll=0;state.page=0;refresh.call())
	position.item_selected.connect(func(index:int):state.position=position.get_item_text(index);state.scroll=0;state.page=0;refresh.call())
	available.item_selected.connect(func(index:int):state.available=available.get_item_text(index);state.scroll=0;state.page=0;refresh.call())
	sort.item_selected.connect(func(index:int):state.sort=sort.get_item_text(index);state.descending=state.sort=="Niveau";state.scroll=0;app._render())
	follow.toggled.connect(func(value:bool):state.followed=value;state.scroll=0;state.page=0;refresh.call())
	refresh.call()
	U.restore(app,page,"market")
	return page

static func _market_rows(app:Control,list:VBoxContainer,count:Label) -> void:
	_empty(list)
	var players:Array=U.players(app.model.get("market",[]),app.management_ui.market,int(app.model.meta.get("season",1)),true,app.management_ui.shortlist)
	var capacity:=2 if app.size.y<=760 else 4 if app.size.y<=940 else 6
	app.management_ui.market.page_size=capacity
	var bounds:=_page_range(list.get_parent().get_parent().find_child("MarketPagination",false,false),app.management_ui.market,players.size(),capacity)
	count.text="%d / %d pistes · %d joueurs suivis dans votre carrière"%[players.size(),app.model.get("market",[]).size(),app.management_ui.shortlist.size()]
	var grid:=GridContainer.new()
	grid.columns=2
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	list.add_child(grid)
	for p in players.slice(bounds.x,bounds.y):
		var card:=G.panel(grid)
		card.add_theme_constant_override("separation",7)
		G.person(card, p, p.name, p.pos.to_upper(), 40)
		var summary:=G.h(10)
		card.add_child(summary)
		summary.add_child(G.label(G.n(p.age)+" ans",13))
		summary.add_child(G.label("Niveau "+G.n(p.rating),13,G.GOLD))
		card.add_child(G.wrap(G.euros(p.get("salary",0))+" / semaine · salaire demandé",13,G.MUTED))
		var followed:bool=str(p.id) in app.management_ui.shortlist
		var track:=G.button("RETIRER DU SUIVI" if followed else "SUIVRE CETTE PISTE",func():
			var saved:Dictionary=app.model.get("clubLife",{}).get("managerCareer",{})
			app._command("manager_recruitment_watch",{"context":saved.context.duplicate(true),"playerId":str(p.id)}))
		track.disabled=app.waiting or not app._live().is_empty() or app.model.meta.get("phase","")=="ended"
		track.name="Follow"+str(p.id).replace(":","_")
		track.set_meta("follow_id",str(p.id))
		var b:=G.button("PROPOSER UN CONTRAT",func():contract(app,p,true))
		b.set_meta("player_id",str(p.id))
		b.disabled=not p.get("available",true) or not app._live().is_empty()
		b.tooltip_text=p.get("reason","")
		if not str(p.get("reason","")).is_empty():
			var reason:String=p.reason
			if reason=="Effectif complet":reason="Effectif complet (%d/%d)"%[app.model.get("squad",[]).size(),app.model.get("decisions",{}).get("recruitment",{}).get("capacity",42)]
			card.add_child(G.wrap(reason,13,G.ALERT))
		var actions:=G.h(8)
		card.add_child(actions)
		G.fill(track);G.fill(b)
		actions.add_child(track)
		actions.add_child(b)
	if players.is_empty():list.add_child(G.wrap("Aucune piste ne correspond. Modifiez la recherche, le filtre Suivis ou réinitialisez les filtres.",15))
	list.get_parent().set_deferred("scroll_vertical",int(app.management_ui.market.scroll))

static func comparison(app:Control) -> void:
	var opener := app.get_viewport().gui_get_focus_owner() as Button
	var return_focus := str(opener.name) if opener != null else ""
	U.remember(app)
	U.sync(app)
	app._clear_dialogs()
	var d:=AcceptDialog.new()
	d.name="PlayerComparison"
	app._prepare_dialog(d,880)
	d.title="Comparer deux dossiers"
	d.get_ok_button().text="RETOUR À LA FICHE" if app.get_meta("immersive08_full_player",false) else "RETOUR À L’EFFECTIF"
	var content:=G.v(10)
	d.add_child(content)
	content.add_child(G.label("Valeurs de jeu sur 100, sauf âge, salaire et échéance.\nLes postes différents demandent une lecture par attribut, sans classement global.",12,G.MUTED))
	var selectors:=G.h(12)
	content.add_child(selectors)
	var ids:Array=app.management_ui.compare.duplicate()
	while ids.size()<2:ids.append("")
	var choices:Array=[]
	for slot in 2:
		var choice:=OptionButton.new()
		choice.name="ComparisonPlayer"+str(slot)
		choice.fit_to_longest_item=false
		choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		G.fill(choice)
		choice.custom_minimum_size=Vector2(180,38)
		choice.add_item("Choisir le dossier "+str(slot+1))
		choice.set_item_metadata(0,"")
		for p:Dictionary in app.model.get("squad",[]):
			choice.add_item(str(p.name)+" · "+str(p.pos))
			var index:=choice.item_count-1
			choice.set_item_metadata(index,str(p.id))
			if str(p.id)==ids[slot]:choice.select(index)
		selectors.add_child(choice)
		choices.append(choice)
	var list:=G.scroll(content)
	list.get_parent().custom_minimum_size.y=340
	list.get_parent().name="ComparisonScroll"
	var refresh:=func():
		var current:Array=[]
		for choice:OptionButton in choices:
			var id:String=choice.get_item_metadata(choice.selected)
			current.append(id)
		app.management_ui.compare=[]
		for id in current:
			if not id.is_empty() and id not in app.management_ui.compare:app.management_ui.compare.append(id)
		_comparison_rows(app,list,current)
	for choice:OptionButton in choices:choice.item_selected.connect(func(_index:int):refresh.call())
	refresh.call()
	var close := func():
		d.hide()
		d.queue_free()
		app._render()
		ClubUI.focus(app, return_focus)
	d.confirmed.connect(close)
	d.canceled.connect(close)
	app.add_child(d)
	Dialogs.show_centered(d,Vector2i(880,600))

static func _comparison_rows(app:Control,list:VBoxContainer,ids:Array) -> void:
	_empty(list)
	var players:Array=[]
	for id in ids:
		var found:Dictionary={}
		for p:Dictionary in app.model.get("squad",[]):
			if str(p.id)==id:found=p
		players.append(found)
	if ids[0]==ids[1] and not str(ids[0]).is_empty():list.add_child(G.wrap("Choisissez deux joueurs distincts.",14,G.ALERT));return
	var dossiers := G.h(14)
	list.add_child(dossiers)
	for p: Dictionary in players:
		var card := G.card(dossiers, G.accent_ink(app.accent))
		G.fill(card.get_parent())
		if not p.is_empty(): G.person(card, p, p.name, str(p.pos) + " · " + G.n(p.age) + " ans", 58)
		else: card.add_child(G.wrap("Choisissez un dossier", 18, G.MUTED))
	var columns:=GridContainer.new()
	columns.columns=3
	columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("h_separation",18)
	columns.add_theme_constant_override("v_separation",10)
	list.add_child(columns)
	var rows:Array=[["Identité","name"],["Poste","pos"],["Âge · ans","age"],["Niveau / 100","rating"],["Condition · %","condition"],["Salaire / semaine","salary"],["Contrat courant","contractLabel"]]
	for pair in [["Mêlée","scrum"],["Touche","lineout"],["Plaquage","tackle"],["Vitesse","speed"],["Passe","pass"],["Jeu au pied","kick"],["But","goal"],["Mental","mental"],["Discipline","discipline"],["Endurance","stamina"],["Puissance","power"]]:rows.append([pair[0]+" / 100","attr:"+pair[1]])
	for row in rows:
		columns.add_child(G.label(row[0],13,G.MUTED))
		for p:Dictionary in players:
			var value:Variant="—"
			if not p.is_empty():
				value=p.get("attributes",{}).get(str(row[1]).trim_prefix("attr:"),"—") if str(row[1]).begins_with("attr:") else p.get(row[1],"—")
				if row[1]=="salary":value=G.euros(value)
				elif value is float:value=G.n(value)
			var label:=G.wrap(str(value),14,G.INK)
			label.custom_minimum_size.x=180
			G.fill(label)
			columns.add_child(label)

static func contract(app:Control,p:Dictionary,recruiting:bool) -> void:
	U.remember(app)
	app._clear_dialogs()
	var d:=ConfirmationDialog.new()
	d.name="ContractOffer"
	app._prepare_dialog(d,630)
	d.title="Offre à "+str(p.name)
	d.dialog_text=""
	var fields:=G.v(8)
	# A zero-width autowrap label inflates the initial minimum height of Window.
	# Two explicit lines give the dialog a bounded minimum before its first layout.
	fields.add_child(G.label("Salaire hebdomadaire et durée proposés.\nLe joueur peut refuser ou faire une contre-offre.",13,G.MUTED))
	var salary:=SpinBox.new()
	salary.name="OfferSalary"
	var quote:Dictionary=p if recruiting else p.get("renewal",{})
	salary.min_value=1000
	salary.max_value=100000
	salary.step=100
	salary.value=float(quote.get("salary",p.get("salary",5000)))
	salary.suffix="€ / semaine"
	fields.add_child(G.label("Salaire hebdomadaire",13,G.MUTED))
	fields.add_child(salary)
	var years:=SpinBox.new()
	years.name="OfferYears"
	years.min_value=quote.get("minYears",1)
	years.max_value=quote.get("maxYears",3)
	years.value=maxf(years.min_value,2)
	years.suffix="saison(s)"
	fields.add_child(G.label("Durée du contrat",13,G.MUTED))
	fields.add_child(years)
	var summary:=G.label("",13,G.INK)
	summary.name="OfferSummary"
	fields.add_child(summary)
	var refresh:=func():
		var delta:=int(salary.value)-(0 if recruiting else int(p.get("salary",0)))
		summary.text="IMMÉDIAT · %s : %s\nRÉCURRENT · %s / semaine · %s %s / semaine\nDurée : %s saison(s) · trésorerie actuelle : %s\nPaiement à la signature, uniquement si l’offre est acceptée."%["acquisition" if recruiting else "prime de prolongation",G.euros(quote.get("fee",0)),G.euros(salary.value),"ajout" if recruiting else "écart",("+" if delta>=0 else "−")+G.euros(absi(delta)),G.n(years.value),G.euros(app.model.get("finance",{}).get("cash",0))]
	salary.value_changed.connect(func(_value:float):refresh.call())
	years.value_changed.connect(func(_value:float):refresh.call())
	refresh.call()
	d.get_ok_button().text="SOUMETTRE L'OFFRE"
	d.get_cancel_button().text="ANNULER"
	d.add_child(fields)
	d.confirmed.connect(func():app._command("recruit" if recruiting else "extend_contract",{"playerId":p.id,"salary":int(salary.value),"years":int(years.value),"confirmed":true});d.queue_free())
	d.canceled.connect(d.queue_free)
	app.add_child(d)
	d.popup_centered(Vector2i(630,440))

static func _context_text(parent:Node,text:String,id:String="") -> Label:
	var label:=G.wrap(text,12,G.INK)
	label.name="ProfileContextText"+id;label.max_lines_visible=2
	label.tooltip_text=text;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label);return label

static func _profile_contexts(parent:VBoxContainer,p:Dictionary,app:Control) -> void:
	var grid:=GridContainer.new();grid.name="ProfileContexts";grid.columns=2;G.fill(grid)
	grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6)
	grid.visible=app.size.y>=1000;parent.add_child(grid)
	var competition:=_profile_tile(grid,"Competition","Concurrence au poste","ProfileContext")
	var cohort:=G.v(3);cohort.name="ProfileContextCohort";competition.add_child(cohort)
	var squad:Array=app.model.get("squad",[])
	cohort.add_child(G.label("Joueur / moyenne de l’effectif · %d joueurs"%squad.size(),11,G.MUTED))
	for field:Array in [["rating","Niveau",""],["condition","Condition","%"],["age","Âge"," ans"],["salary","Salaire / semaine",""]]:
		var total:=0.0
		for member:Dictionary in squad:total+=float(member.get(field[0],0))
		var mean:float=total/squad.size() if not squad.is_empty() else NAN
		var average:String="—" if not is_finite(mean) else G.euros(roundi(mean)) if field[0]=="salary" else ("%.1f"%mean).replace(".",",")+field[2]
		var own:String=G.euros(p.get(field[0],0)) if field[0]=="salary" else G.n(p.get(field[0],0))+field[2]
		_profile_fact(cohort,"ProfileMean_"+str(field[0]),field[1],own+" / "+average)
	var peers:=G.v(3);peers.name="ProfileContextPeers";competition.add_child(peers)
	peers.add_child(G.label("Même poste principal · "+str(p.pos)+" · niveau / condition",11,G.MUTED))
	var people:Array=squad.filter(func(person):return str(person.id)!=str(p.id) and person.pos==p.pos).slice(0,5)
	var rows:=G.v(3);rows.name="ProfileContextPeerRows";peers.add_child(rows)
	for i in people.size():
		var person:Dictionary=people[i];var row:=G.h(5);rows.add_child(row)
		var name:=G.label(person.name,12,G.INK);G.fill(name);name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name.tooltip_text=person.name;row.add_child(name)
		row.add_child(G.label(G.n(person.rating)+" / "+G.n(person.condition)+"%",11,G.MUTED))
		var compare:=G.button("Comparer",func():app.management_ui.compare=[str(p.id),str(person.id)];comparison(app))
		compare.name="ProfilePeerCompare"+str(i);compare.set_meta("peer_id",str(person.id));compare.custom_minimum_size.y=24;row.add_child(compare)
	if people.is_empty():_context_text(peers,"Aucun autre coéquipier à afficher au même poste principal.","PeersEmpty")
	var development:=_profile_tile(grid,"Development","Développement","ProfileContext")
	var records:Array=app.model.get("decisions",{}).get("development",{}).get("professionals",[]).filter(func(person):return str(person.id)==str(p.id))
	if records.is_empty():_context_text(development,"Aucun suivi de développement disponible.","DevelopmentEmpty")
	else:
		var record:Dictionary=records[0];var data:Dictionary=record.get("development",{});var focus:="—"
		for option:Dictionary in data.get("options",[]):
			if option.id==data.get("focus"):focus=str(option.label)
		_profile_fact(development,"ProfileDevelopmentFocus","Orientation",focus)
		if data.get("seasonStart")!=null:
			_profile_fact(development,"ProfileDevelopmentStart","Début de saison",G.n(data.seasonStart))
			var delta:float=float(record.rating)-float(data.seasonStart)
			_profile_fact(development,"ProfileDevelopmentDelta","Évolution du niveau",("+" if delta>=0 else "")+G.n(delta))
		var history:Array=data.get("history",[])
		if history.is_empty():_context_text(development,"Premier bilan annuel à venir.","AnnualEmpty")
		for year:Dictionary in history.slice(maxi(0,history.size()-2)):_context_text(development,"S%s · %s → %s · %s min / %s app."%[G.n(year.get("season","—")),G.n(year.get("start","—")),G.n(year.get("end","—")),G.n(year.get("minutes","—")),G.n(year.get("appearances","—"))],"Annual")
		var reason:=str(data.get("reason",""))
		if not reason.is_empty():_context_text(development,"Progression annuelle." if reason.begins_with("Évolution annuelle") else reason,"DevelopmentReason")
	var form:=_profile_tile(grid,"Form","Forme & prestations","ProfileContext")
	_profile_fact(form,"ProfileFormAvailability","Disponibilité","Blessure en cours" if float(p.get("injury",0))>0 else "Disponible")
	_profile_fact(form,"ProfileFormCondition","Condition / charge",G.n(p.get("condition",0))+"% / "+G.n(p.get("physicalLoad",0)))
	if int(p.get("appearances",0))==0 and float(p.get("minutes",0))==0:_context_text(form,"Première apparition à venir.","FirstAppearance")
	elif int(p.get("appearances",0))>0:_profile_fact(form,"ProfileMinutesPerAppearance","Minutes par apparition",("%.1f"%(float(p.get("minutes",0))/int(p.appearances))).replace(".",","))
	else:_profile_fact(form,"ProfileFormMinutes","Temps de jeu cumulé",G.n(p.get("minutes",0))+" min")
	var staff:=_profile_tile(grid,"Staff","Staff & carnet","ProfileContext")
	var advice:=str(app.model.get("decisions",{}).get("training",{}).get("advice",""))
	if not advice.is_empty():staff.add_child(G.label("Consigne collective",11,G.MUTED));_context_text(staff,advice.replace("Effectif & 23","Effectif"),"CollectiveAdvice")
	var reports:Array=app.model.get("decisions",{}).get("recruitment",{}).get("reports",[]).filter(func(report):return str(report.get("playerId",""))==str(p.id))
	if reports.is_empty():_context_text(staff,"Aucun avis individuel archivé.","IndividualEmpty")
	else:
		var assessment:Dictionary=reports[0].get("assessment",{})
		_context_text(staff,str(assessment.get("source","Rapport conservé")),"ReportDate")
		for opinion:String in assessment.get("estimates",[]).slice(0,1):_context_text(staff,opinion,"ReportOpinion")
	var slot:=G.v(3);slot.name="ProfileStaffNoteSlot";staff.add_child(slot)
	if parent.find_child("ProfileNoteContent",true,false)==null:_context_text(slot,"Aucune note personnelle pour ce joueur.","NoteEmpty")
