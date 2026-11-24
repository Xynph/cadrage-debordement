extends "res://ui/squad_views_composition.gd"
## Recrutement générique : liste du marché, veille et lignes (découpe de squad_views.gd, sans changement).

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
	count.text="%d / %d pistes · %d joueurs suivis dans ta carrière"%[players.size(),app.model.get("market",[]).size(),app.management_ui.shortlist.size()]
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
		# Statut JIFF / EQP de la piste pour le quota du club (moteur : market[].quota), seulement quand il compte.
		var quota_badge: Variant = p.get("quota")
		if quota_badge is Dictionary and bool(quota_badge.get("ok", false)):
			var quota_note := G.wrap(str(quota_badge.get("note", "")), 12, G.GOLD if bool(quota_badge.get("useful", false)) else G.MUTED)
			quota_note.name = "MarketQuota" + str(p.id).replace(":", "_")
			card.add_child(quota_note)
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
	if players.is_empty():list.add_child(G.wrap("Aucune piste ne correspond. Modifie la recherche, le filtre Suivis ou réinitialise les filtres.",15))
	list.get_parent().set_deferred("scroll_vertical",int(app.management_ui.market.scroll))
