extends RefCounted
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/carnet_skin.gd")
const Board = preload("res://ui/lineup_board.gd")
const U = preload("res://ui/management_state.gd")
const TableOrder = preload("res://ui/player_table_order.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Decisions = preload("res://ui/decision_views.gd")
const Cover = preload("res://ui/lineup_cover.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")

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
			if next!=null:next.grab_focus.call_deferred())
		label.name="RosterColumn_"+field
		label.custom_minimum_size.x=column[2]
		if field=="name": G.fill(label)
		label.tooltip_text="Trier "+str(column[1])+" · valeurs inconnues en dernier"
		header.add_child(label)
	var players:Array=TableOrder.ordered(U.players(app.model.get("squad",[]),app.management_ui.roster,int(app.model.meta.get("season",1))),key,state.descending,func(person:Dictionary,field:String): return U.watch_reason(person) if field=="watch" else G.knowledge_sort_value(person,field,true) if field in ["rating","potential","note"] else person.get(field))
	count.text="%d / %d joueurs · lecture seule"%[players.size(),app.model.get("squad",[]).size()]
	compare.text="COMPARER (%d/2)"%app.management_ui.compare.size()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	state.visible_player=app.selected_player
	if players.is_empty():list.add_child(G.wrap("Aucun joueur ne correspond. Modifiez la recherche ou réinitialisez les filtres.",15))
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
			var value:=_roster_value(p,str(column[0]))
			var color: Color = G.POTENTIAL_COLOR if column[0]=="potential" else G.INK if column[0]=="name" else (G.GOLD if column[0]=="watch" else G.MUTED)
			if state.family==U.WATCH_FILTER and column[0]=="condition" and float(p.get("injury",0))>0:
				value="Blessé"
				color=G.ALERT
			if column[0]=="condition" and on_leave.has(str(p.id)):
				value="Congés"
				color=G.GOLD
			var label:=G.cell(value,column[2],color,column[0]=="name")
			label.name="RosterValue_"+str(column[0])
			label.tooltip_text=value
			row.add_child(label)
		list.add_child(b)
		if str(p.id)==focus_id:b.grab_focus.call_deferred()
	list.get_parent().set_deferred("scroll_vertical",int(app.management_ui.roster.scroll))
	if revealed!=null:_reveal_roster_row.call_deferred(app,list,revealed)
	_show_profile(app,profile)

static func _reveal_roster_row(app: Control, list: Control, row: Control) -> void:
	if not is_instance_valid(list) or not list.is_inside_tree(): return
	await list.get_tree().process_frame
	if not is_instance_valid(row) or not row.is_inside_tree(): return
	var scroll := list.get_parent() as ScrollContainer
	if scroll == null: return
	scroll.ensure_control_visible(row)
	app.management_ui.roster.scroll=scroll.scroll_vertical
	list.set_meta("reveal_id","")

static func _roster_columns(width:float) -> Array:
	var columns:Array=[["name","JOUEUR",130],["pos","POSTE",64],["age","ÂGE",26],["rating","NIV.",30],["condition","COND.",42]]
	if width>=700:columns.append_array([["salary","SALAIRE "+G.salary_period(true).to_upper(),78],["contractEnd","ÉCH.",38]])
	if width>=900:columns.append_array([["minutes","MIN.",42],["appearances","APP.",32],["physicalLoad","CHARGE",42]])
	if width>=950:
		columns[1][2]=100
		columns.append_array([["potential","POT.",60],["status","SÉLECTION",76]])
	return columns

static func _roster_value(p:Dictionary,key:String) -> String:
	if key in ["rating","note"]:return G.rating_text(p,true)
	if key=="potential":return G.potential_text(p)
	if key=="salary":return G.salary_amount(p.get(key,0))
	if key=="condition":return G.n(p.get(key,0))+"%"
	if key=="watch":return U.watch_reason(p)
	if key=="contractEnd":return G.contract_year(p.get(key))
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

static func _profile_reading_link(app: Control, content: Control, player_id: String, caption: String, id: String) -> Button:
	var link := Button.new()
	link.name = id
	link.custom_minimum_size = content.get_combined_minimum_size()
	link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	link.add_theme_stylebox_override("focus", G.T.box(Color.TRANSPARENT, 2, G.GOLD))
	link.accessibility_name = "Consulter la fiche · " + caption
	link.tooltip_text = link.accessibility_name
	link.set_meta("entity_kind", "player")
	link.set_meta("entity_id", player_id)
	link.pressed.connect(func(): app.navigation_controller.open_entity({"kind":"player", "id":player_id}))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return link

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
	top.add_child(_profile_reading_link(app,portrait,str(p.id),str(p.name),"ProfileOpenPlayerPortrait"))
	var identity:=G.v(3)
	G.fill(identity)
	top.add_child(identity)
	var name:=G.label(p.name,18,G.INK)
	name.name="ProfilePlayerName"
	name.add_theme_font_size_override("font_size",18)
	name.add_theme_font_override("font",G.T.DISPLAY)
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(_profile_reading_link(app,name,str(p.id),str(p.name),"ProfileOpenPlayerName"))
	identity.add_child(G.wrap("%s · %s ans"%[p.pos,G.n(p.age)],12))
	var facts: Dictionary = p.get("playerFacts", {})
	if not facts.is_empty(): identity.add_child(preload("res://ui/player_identity.gd").row(facts,15,G.INK,app))
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
	var details := PlayerAttributes.detail(p,true)
	var actions:=_profile_overview(overview,p,app.model.get("clubLife",{}).get("coachNotebook",{}).get("entries",[]),app,tabs,not details.is_empty())
	var note:=G.button("MA NOTE SUR CE JOUEUR",func(): preload("res://ui/coach_notes_view.gd").open(app,str(p.id)))
	note.name="OpenPlayerCoachNote"
	G.fill(note)
	actions.add_child(note)
	_profile_attributes(attributes,p,details)
	contracts.add_child(G.wrap("Fin de contrat : "+G.contract_year(p.get("contractEnd")),13))
	contracts.add_child(G.wrap(G.salary(p.get("salary",0)),12,G.MUTED))
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
	var renewal_reason := str(renewal.get("reason", ""))
	extend.tooltip_text=renewal_reason if not renewal_reason.is_empty() else ("Le contrat ne permet pas de prolongation supplémentaire dans la limite de trois saisons." if not renewal.get("available",false) else "Une offre sera soumise au joueur avant toute signature.")
	if not renewal_reason.is_empty(): contracts.add_child(G.wrap(renewal_reason,13,G.ALERT))
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
	references_tab.add_child(G.section("Repères de départ","Situation du joueur au début de la carrière"))
	var roster:Dictionary=p.get("rosterProfile",{}) if p.get("rosterProfile")!=null else {}
	if not roster.is_empty():
		var position:Dictionary=roster.get("position",{})
		var status:Dictionary=roster.get("status",{})
		var initial:Dictionary=roster.get("contract",{})
		references_tab.add_child(G.wrap("Poste principal : %s"%position.get("primary",p.pos),13,G.MUTED))
		references_tab.add_child(G.wrap("Qualification initiale de jeu : %s"%", ".join(position.get("qualifications",[])),13,G.MUTED))
		references_tab.add_child(G.wrap("Statut initial : %s"%str(status.get("value","inconnu")).capitalize(),13,G.MUTED))
		if status.get("professionalFromSeason")!=null: references_tab.add_child(G.wrap("Référence initiale : passage professionnel prévu en saison %s."%G.season_label(status.professionalFromSeason),12,G.MUTED))
		references_tab.add_child(G.wrap("Échéance initiale : %s (fin saison %s)."%[G.n(initial.get("endYear",0)),G.season_label(initial.get("endSeason",0))],13,G.MUTED))
	references_tab.add_child(G.wrap(portrait.tooltip_text,12,G.MUTED))
	var academy := preload("res://ui/immersive08/academy_canvas.gd")
	var player_id := str(p.id)
	if not academy.professional_progress(app, player_id).is_empty():
		var follow_up := G.button("OUVRIR LE SUIVI INDIVIDUEL", func():
			academy.open_professional_progress(app, player_id, "ProfileDevelopmentAction"))
		follow_up.name = "ProfileDevelopmentAction"
		references_tab.add_child(follow_up)
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
	var fact:=G.label(value,12,G.POTENTIAL_COLOR if id=="ProfilePotentialValue" else G.INK)
	fact.name=id
	row.add_child(fact)

static func _profile_overview(parent:VBoxContainer,p:Dictionary,notes:Array,app:Control,tabs:TabContainer,has_details:bool) -> HBoxContainer:
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
	var term:=G.wrap("Fin de contrat : "+G.contract_year(p.get("contractEnd")),12,G.INK)
	term.name="ProfileContractValue";contract_tile.add_child(term)
	_profile_fact(contract_tile,"ProfileSalaryValue",G.salary_period().capitalize(),G.salary_amount(p.get("salary",0)))
	var renewal:Dictionary=p.get("renewal",{})
	_profile_fact(contract_tile,"ProfileRenewalValue","Prolongation","Disponible" if renewal.get("available",false) else "Indisponible")
	if renewal.get("available",false):
		_profile_fact(contract_tile,"ProfileRenewalTerm","Durée possible","%s–%s saisons"%[G.n(renewal.get("minYears",1)),G.n(renewal.get("maxYears",1))])
	var season:=_profile_tile(left,"Season","Usage en saison")
	_profile_fact(season,"ProfileMinutesValue","Minutes",G.n(p.get("minutes",0)))
	_profile_fact(season,"ProfileAppearancesValue","Apparitions",G.n(p.get("appearances",0)))
	_profile_fact(season,"ProfileNumberValue","Numéro","—" if p.get("shirtNumber")==null else G.n(p.shirtNumber))
	var evaluation:=_profile_tile(right,"Evaluation","Évaluation")
	_profile_fact(evaluation,"ProfileRatingValue","Niveau général",G.rating_text(p,true))
	_profile_fact(evaluation,"ProfilePotentialValue","Potentiel",G.potential_text(p))
	var qualities := _profile_tile(left,"Attributes","Profil de jeu")
	if has_details:
		var detail_button := G.button("VOIR LES 36 ATTRIBUTS", func():
			tabs.current_tab = 1
			tabs.get_tab_bar().grab_focus())
		detail_button.name = "OpenCompactDetailedAttributes"
		qualities.add_child(detail_button)
	else:
		qualities.add_child(G.wrap("Détail des attributs indisponible.",12))
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
		note_content.add_child(G.label("MA NOTE · %s / SEMAINE %s"%[G.season_label(entry.get("season",1)),G.n(int(entry.get("week",0))+1)],11,G.MUTED))
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

static func _profile_attributes(parent: VBoxContainer, player: Dictionary, details: Dictionary) -> void:
	if details.is_empty():
		_profile_fact(parent, "ProfileDetailedFallbackRating", "Niveau général", G.rating_text(player,true))
		parent.add_child(G.wrap("Les attributs détaillés sont indisponibles pour ce dossier.",12))
		return
	parent.add_child(G.label("36 ATTRIBUTS · " + PlayerAttributes.SUBTITLE.to_upper(), 12, G.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	G.fill(grid)
	parent.add_child(grid)
	for index in PlayerAttributes.GROUPS.size():
		var group: Array = PlayerAttributes.GROUPS[index]
		var card := _profile_tile(grid, str(index), group[0], "ProfileDetailedGroup")
		for pair: Array in group[1]:
			var row := G.h(5)
			card.add_child(row)
			row.add_child(G.fill(G.wrap(pair[1], 12, G.MUTED)))
			var caption := G.label(PlayerAttributes.caption(details.get(pair[0])), 13, G.INK)
			caption.name = "PlayerDetailedAttribute_" + pair[0]
			caption.accessibility_name = "%s : %s sur 100" % [pair[1], caption.text]
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			caption.custom_minimum_size.x = 37
			row.add_child(caption)

static func lineup(app:Control) -> Control:
	var page:=LineupReading.new()
	page.add_theme_constant_override("separation",14)
	if not app.management_ui.get("lineup") is Dictionary:app.management_ui.lineup={"outer":0,"list":0,"focus":""}
	page.state=app.management_ui.lineup
	if page.state.get("candidate_slot", app.selected_slot) != app.selected_slot:
		page.state.list = 0
		if str(page.state.focus).begins_with("LineupPlayer"):
			page.state.focus = "LineupSlot%02d" % (app.selected_slot + 1)
	page.state.candidate_slot = app.selected_slot
	page.outer=app.body_scroll
	G.fill(page,true)
	page.name="CarnetLineup"
	var pitch:=G.panel(page,1.15)
	if app.size.y<=760:pitch.add_theme_constant_override("separation",3)
	G.chapter(pitch,"02","La feuille de match","Titulaire ou remplaçant : choisissez un poste.",app.accent)
	var condition := G.label("Condition du XV · " + P.lineup_condition(app.model), 15)
	condition.name = "LineupCondition"
	pitch.add_child(condition)
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
	var heading := G.section("Poste %02d" % (app.selected_slot + 1))
	var candidate_count := G.wrap("", 13, G.MUTED)
	candidate_count.name = "LineupCandidateCount"
	heading.add_child(candidate_count)
	side.add_child(heading)
	var selection:Dictionary=app.model.get("selection",{})
	var slots:Array=selection.get("slots",[])
	var selected:Dictionary={}
	for s in slots:
		if int(s.get("slot",-1))==app.selected_slot:selected=s
	var errors:Array=selection.get("errors",[])
	if errors.is_empty():side.add_child(G.label("FEUILLE VALIDE",12,G.GOOD))
	else:side.add_child(G.wrap("\n".join(errors),12,G.ALERT))
	var vacancy := P.reduced_bench_number(app.model)
	if vacancy != 0:
		var action := G.button("MATCH · FEUILLE À 22",func():app._navigate("Match"))
		action.name="LineupOpenMatchAt22"
		action.tooltip_text=P.reduced_bench_vacancy(vacancy)
		action.accessibility_name="Ouvrir le jour de match pour une feuille à 22"
		side.add_child(action)
	var licences: Dictionary = selection.get("nationaleQualification", {})
	if not licences.is_empty():
		var bloc := G.wrap("FFR  ·  4 licences B/C dont 1 C maximum  ·  %d à vérifier" % int(licences.unverified), 11, G.MUTED)
		bloc.name = "NationaleLicenceNotice"
		var note: Dictionary = licences.get("notice", {})
		bloc.tooltip_text = str(note.get("summary", "")) + "\n" + str(note.get("detail", ""))
		side.add_child(bloc)
	var jiff: Dictionary = app.model.get("clubLife", {}).get("jiff", {})
	if bool(jiff.get("applies", false)):
		var current := int(jiff.get("currentSheet", 0))
		var target := int(jiff.get("target", 16))
		var line := "JIFF  ·  %d sur cette feuille  ·  %d exigés en moyenne" % [current, target]
		if jiff.get("average") != null:
			line += "  ·  moyenne de la saison %s" % String.num(float(jiff.average), 2)
		if int(jiff.get("deduction", 0)) > 0:
			line += "  ·  retrait de %d point(s) cette saison" % int(jiff.deduction)
		var jiff_bloc := G.wrap(line, 11, G.ALERT if current < target else G.MUTED)
		jiff_bloc.name = "LineupJiffNotice"
		jiff_bloc.tooltip_text = "Joueurs issus des filières de formation : 3 saisons en centre de formation français ou 5 saisons de licence en France avant 22 ans. Sous la moyenne de %d par feuille sur la saison, le club perd des points la saison suivante ; à partir de %d, le fonds JIFF verse une prime." % [target, int(jiff.get("bonusFrom", 17))]
		side.add_child(jiff_bloc)
	var auto:=G.button("SÉLECTION AUTOMATIQUE DU STAFF",func():app._command("auto_lineup"))
	auto.name="LineupAutomatic"
	auto.disabled=not app._live().is_empty()
	side.add_child(auto)
	var quote := Cover.data(app)
	if not quote.is_empty():
		var cover := G.button(Cover.caption(quote), func(): Cover.confirm(app, quote))
		cover.name = "LineupCover"
		Cover.configure(cover, quote)
		side.add_child(cover)
	var list:=G.scroll(side)
	list.get_parent().name="LineupCandidatesScroll"
	var eligible:Variant=selected.get("eligibleIds")
	for p in app.model.get("squad",[]):
		var identity := "%s · %s" % [p.name, p.pos]
		var metrics := "Condition %s %% · Niveau %s" % [G.n(p.condition), G.rating_text(p,true)]
		var b := G.button("",func():app._command("set_lineup",{"playerId":p.id,"slot":app.selected_slot}))
		b.accessibility_name = identity + " · " + metrics
		b.tooltip_text = b.accessibility_name
		b.set_meta("player_id",str(p.id))
		b.name="LineupPlayer"+str(p.id).replace(":","_")
		b.disabled=not app._live().is_empty() or float(p.get("injury",0))>0 or (eligible is Array and p.id not in eligible)
		if b.disabled:b.tooltip_text+="\nIndisponible ou qualification incompatible avec ce poste. Pendant un match, utilisez les remplacements."
		var inset := G.margin(8)
		inset.add_theme_constant_override("margin_top",0)
		inset.add_theme_constant_override("margin_bottom",0)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inset)
		var row := G.h(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(row)
		var ink := G.MUTED if b.disabled else G.INK
		var name := G.label(identity,14,ink)
		name.name = "LineupCandidateIdentity"
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		var values := G.label(metrics,12,ink)
		values.name = "LineupCandidateMetrics"
		values.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(values)
		list.add_child(b)
	var allowed_count := 0
	for candidate: Button in list.get_children():
		if candidate.disabled: continue
		list.move_child(candidate, allowed_count)
		allowed_count += 1
	var plural := "s" if allowed_count > 1 else ""
	candidate_count.text = "%d candidat%s autorisé%s sur %d" % [allowed_count, plural, plural, list.get_child_count()]
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
	Decisions.recruitment_summary(app,staff)
	preload("res://ui/regen_scouting_view.gd").entry(app,staff)
	preload("res://ui/interclub_market_view.gd").entry(app,staff)
	tabs.set_tab_title(0,"Pistes")
	tabs.set_tab_title(1,"Travail du staff")
	tabs.current_tab=clampi(int(app.management_ui.get("market_tab",0)),0,1)
	tabs.tab_changed.connect(func(index:int):app.management_ui.market_tab=index)
	workspace=browse
	var state:Dictionary=app.management_ui.market
	var search_row := G.h(8)
	workspace.add_child(search_row)
	var search := _search(search_row, "MarketSearch", state)
	G.fill(search)
	var controls:=G.h(8)
	workspace.add_child(controls)
	var positions := _positions(app.model.get("market", []))
	var position := _choice(controls, "MarketPosition", positions, state.position, "Poste")
	_market_watch(app, search_row, position, positions)
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

static func _market_watch(app: Control, row: HBoxContainer, picker: OptionButton, positions: Array) -> void:
	var watch := Decisions.market_watch(app)
	if watch.is_empty(): return
	var description := G.v(1)
	description.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(description)
	description.add_child(G.label(watch.heading + " · " + watch.position, 13, G.INK, true))
	var stock := G.label(watch.caption, 12, G.MUTED)
	stock.name = "MarketPriorityStock"
	description.add_child(stock)
	var index := positions.find(watch.position)
	if index > 0:
		var action := G.button("Filtrer sur ce poste", func(): Decisions.select_market_position(picker, index))
		action.name = "MarketPriorityFilter"
		action.accessibility_name = "Filtrer sur ce poste · " + watch.position
		row.add_child(action)

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
		summary.add_child(G.label("Niveau "+G.rating_text(p),13,G.GOLD))
		card.add_child(G.wrap(G.salary(p.get("salary",0))+" · salaire demandé",13,G.MUTED))
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
		var observer := G.button("",func(): pass)
		preload("res://ui/player_observation.gd").configure(observer,app,p)
		card.add_child(observer)
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
	content.add_child(G.label("La note globale est sur 100. Tenez compte du poste et de la condition des joueurs.",12,G.MUTED))
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
	list.get_parent().custom_minimum_size.y=260
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
	Dialogs.show_centered(d,Vector2i(880,460))

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
	var rows:Array=[["Identité","name"],["Poste","pos"],["Âge · ans","age"],["Niveau / 100","rating"],["Condition · %","condition"],["Salaire "+G.salary_period(),"salary"],["Fin de contrat","contractEnd"]]
	for row in rows:
		columns.add_child(G.label(row[0],13,G.MUTED))
		for p:Dictionary in players:
			var value:Variant="—"
			if not p.is_empty():
				value=p.get(row[1],"—")
				if row[1]=="rating":value=G.rating_text(p,true)
				elif row[1]=="salary":value=G.salary_amount(value)
				elif row[1]=="contractEnd":value=G.contract_year(value)
				elif value is float:value=G.n(value)
			var label:=G.wrap(str(value),14,G.INK)
			label.custom_minimum_size.x=180
			G.fill(label)
			columns.add_child(label)

static func contract(app:Control,p:Dictionary,recruiting:bool) -> void:
	preload("res://ui/contract_negotiation.gd").open(app,p,recruiting)

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
	for field:Array in [["rating","Niveau",""],["condition","Condition","%"],["age","Âge"," ans"],["salary","Salaire "+G.salary_period(),""]]:
		var total:=0.0
		for member:Dictionary in squad:total+=float(member.get(field[0],0))
		var mean:float=total/squad.size() if not squad.is_empty() else NAN
		var average:String="—" if not is_finite(mean) else G.salary_amount(mean) if field[0]=="salary" else ("%.1f"%mean).replace(".",",")+field[2]
		var own:String=G.rating_text(p,true) if field[0]=="rating" else G.salary_amount(p.get(field[0],0)) if field[0]=="salary" else G.n(p.get(field[0],0))+field[2]
		_profile_fact(cohort,"ProfileMean_"+str(field[0]),field[1],own+" / "+average)
	var peers:=G.v(3);peers.name="ProfileContextPeers";competition.add_child(peers)
	peers.add_child(G.label("Même poste principal · "+str(p.pos)+" · niveau / condition",11,G.MUTED))
	var people:Array=squad.filter(func(person):return str(person.id)!=str(p.id) and person.pos==p.pos).slice(0,5)
	var rows:=G.v(3);rows.name="ProfileContextPeerRows";peers.add_child(rows)
	for i in people.size():
		var person:Dictionary=people[i];var row:=G.h(5);rows.add_child(row)
		var name:=G.label(person.name,12,G.INK);G.fill(name);name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name.tooltip_text=person.name;row.add_child(name)
		row.add_child(G.label(G.rating_text(person,true)+" / "+G.n(person.condition)+"%",11,G.MUTED))
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
		for year:Dictionary in history.slice(maxi(0,history.size()-2)):_context_text(development,"%s · %s → %s · %s min / %s app."%[G.season_label(year.get("season","—")),G.n(year.get("start","—")),G.n(year.get("end","—")),G.n(year.get("minutes","—")),G.n(year.get("appearances","—"))],"Annual")
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
