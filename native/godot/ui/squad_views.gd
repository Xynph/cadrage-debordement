extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const Board = preload("res://ui/lineup_board.gd")
const U = preload("res://ui/management_state.gd")

static func squad(app: Control) -> Control:
	var page := G.h(14)
	G.fill(page,true)
	page.name="CarnetSquad"
	var table := G.panel(page,1.65)
	G.chapter(table,"01","Le groupe professionnel","Rechercher, consulter et comparer sans perdre votre place.",app.accent)
	var state:Dictionary=app.management_ui.roster
	state.family=app.roster_filter;state.sort=app.roster_sort
	var search:=_search(table,"RosterSearch",state)
	var filters:=G.h(6)
	table.add_child(filters)
	var family:=_choice(filters,"RosterFamily",["Tous","Avants","Arrières","Blessés","Hors groupe"],state.family,"Groupe")
	var position:=_choice(filters,"RosterPosition",_positions(app.model.get("squad",[])),state.position,"Poste")
	var available:=_choice(filters,"RosterAvailability",["Tous","Disponibles","Blessés"],state.available,"Disponibilité")
	var contract_filter:=_choice(filters,"RosterContract",["Tous","Fin de saison","Sans contrat"],state.contract,"Contrat")
	var sorting:=G.h(6)
	table.add_child(sorting)
	var sort:=_choice(sorting,"RosterSort",["Poste","Nom","Niveau","Condition","Âge","Salaire","Échéance"],state.sort,"Trier par")
	var direction:=G.button("↓ Décroissant" if state.descending else "↑ Croissant",func():state.descending=not state.descending;app._render())
	direction.name="RosterDirection"
	sorting.add_child(direction)
	var compare:=G.button("COMPARER (%d/2)"%app.management_ui.compare.size(),func():comparison(app))
	compare.name="OpenComparison"
	sorting.add_child(compare)
	var reset:=G.button("Réinitialiser",func():app.management_ui.roster=U.defaults();app.roster_filter="Tous";app.roster_sort="Poste";app._render())
	reset.name="RosterReset"
	sorting.add_child(reset)
	var count:=G.label("",12,G.MUTED)
	count.name="RosterCount"
	table.add_child(count)
	var header := G.h(10)
	table.add_child(header)
	for pair in [["JOUEUR",100],["POSTE",78],["ÂGE",30],["NIV.",34],["COND.",48]]: header.add_child(G.cell(pair[0],pair[1],G.MUTED,pair[0]=="JOUEUR"))
	var list := G.scroll(table)
	list.get_parent().name="SquadScroll"
	var profile := G.panel(page,1.05)
	profile.name="PlayerDossier"
	var refresh:=func():_squad_rows(app,list,profile,count,compare)
	search.text_changed.connect(func(text:String):state.search=text;state.scroll=0;refresh.call())
	family.item_selected.connect(func(index:int):state.family=family.get_item_text(index);app.roster_filter=state.family;state.scroll=0;refresh.call())
	position.item_selected.connect(func(index:int):state.position=position.get_item_text(index);state.scroll=0;refresh.call())
	available.item_selected.connect(func(index:int):state.available=available.get_item_text(index);state.scroll=0;refresh.call())
	contract_filter.item_selected.connect(func(index:int):state.contract=contract_filter.get_item_text(index);state.scroll=0;refresh.call())
	sort.item_selected.connect(func(index:int):state.sort=sort.get_item_text(index);app.roster_sort=state.sort;state.descending=state.sort in ["Niveau","Condition"];state.scroll=0;app._render())
	refresh.call()
	U.restore(app,page,"roster")
	return page

static func _empty(parent:Node) -> void:
	for child in parent.get_children():parent.remove_child(child);child.queue_free()

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
	box.add_child(G.label(caption,11,G.MUTED))
	var choice:=OptionButton.new()
	choice.name=id
	choice.custom_minimum_size.y=34
	choice.fit_to_longest_item=false
	choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.tooltip_text=caption
	for text in values:choice.add_item(str(text))
	choice.select(maxi(0,values.find(selected)))
	box.add_child(choice)
	return choice

static func _squad_rows(app:Control,list:VBoxContainer,profile:VBoxContainer,count:Label,compare:Button) -> void:
	_empty(list)
	var players:Array=U.players(app.model.get("squad",[]),app.management_ui.roster,int(app.model.meta.get("season",1)))
	count.text="%d / %d joueurs · lecture seule"%[players.size(),app.model.get("squad",[]).size()]
	compare.text="COMPARER (%d/2)"%app.management_ui.compare.size()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	if players.is_empty():list.add_child(G.wrap("Aucun joueur ne correspond. Modifiez la recherche ou réinitialisez les filtres.",15))
	for p in players:
		var b := G.button("",func():
			app.selected_player=str(p.id);app.management_ui.profile_scroll=0
			for row:Button in list.get_children():
				row.remove_theme_stylebox_override("normal")
				row.add_theme_stylebox_override("normal",G.T.box(Color("e8dfce"),3,G.LINE))
				if str(row.get_meta("player_id",""))==str(p.id):G.selected(row,app.accent)
			_show_profile(app,profile))
		b.custom_minimum_size.y=48
		b.name="SquadPlayer"+str(p.id).replace(":","_")
		b.set_meta("player_id",str(p.id))
		b.tooltip_text=str(p.name)+" · "+str(p.pos)
		if str(p.id)==app.selected_player: G.selected(b,app.accent)
		var inset:=G.margin(10)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(inset)
		var row:=G.h(10)
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inset.add_child(row)
		row.add_child(G.cell(p.name,100,G.INK,true))
		row.add_child(G.cell(p.pos,78,G.MUTED))
		row.add_child(G.cell(G.n(p.age),30,G.MUTED))
		row.add_child(G.cell(G.n(p.rating),34,G.GOLD))
		row.add_child(G.cell(G.n(p.condition)+"%",48,G.GOOD))
		list.add_child(b)
	list.get_parent().set_deferred("scroll_vertical",int(app.management_ui.roster.scroll))
	_show_profile(app,profile)

static func _show_profile(app:Control,parent:VBoxContainer) -> void:
	# Filtering changes the list only. Keep the currently read dossier intact.
	if parent.get_meta("player_id","")==app.selected_player and parent.get_child_count()>0:return
	_empty(parent)
	parent.set_meta("player_id",app.selected_player)
	for p:Dictionary in app.model.get("squad",[]):
		if str(p.id)==app.selected_player:_profile(app,parent,p);return
	parent.add_child(G.wrap("Sélectionnez un joueur pour consulter son dossier.",15))

static func _profile(app:Control,parent:VBoxContainer,p:Dictionary) -> void:
	var list:=G.scroll(parent)
	list.get_parent().name="ProfileScroll"
	var top:=G.h(12)
	list.add_child(top)
	var portrait := G.portrait(int(p.get("portraitIndex",0)),90,p)
	top.add_child(portrait)
	var identity:=G.v(3)
	G.fill(identity)
	top.add_child(identity)
	var name:=G.label(p.name,25,G.INK)
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(name)
	identity.add_child(G.wrap("%s · %s ans"%[p.pos,G.n(p.age)],12))
	identity.add_child(G.label(p.get("status",""),13,G.accent_ink(app.accent)))
	list.add_child(G.separator())
	var numbers:=G.h(16)
	list.add_child(numbers)
	numbers.add_child(G.metric(G.n(p.rating),"Niveau"))
	numbers.add_child(G.metric(G.n(p.potential),"Potentiel"))
	numbers.add_child(G.metric(G.n(p.condition)+"%","Condition",G.GOOD))
	var radar:=G.W.new()
	radar_setup(radar,p,app.accent)
	list.add_child(radar)
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",20)
	list.add_child(grid)
	for pair in [["scrum","Mêlée"],["lineout","Touche"],["tackle","Plaquage"],["speed","Vitesse"],["pass","Passe"],["kick","Jeu au pied"],["goal","But"],["mental","Mental"],["discipline","Discipline"],["stamina","Endurance"],["power","Puissance"]]:
		grid.add_child(G.label(pair[1]+"  "+G.n(p.get("attributes",{}).get(pair[0],"—")),14,G.MUTED))
	list.add_child(G.separator())
	list.add_child(G.label("Contrat courant : "+p.get("contractLabel",""),13))
	list.add_child(G.label(G.euros(p.get("salary",0))+" / semaine · estimation de jeu",12,G.MUTED))
	list.add_child(G.label("%s minutes · %s apparitions"%[G.n(p.get("minutes",0)),G.n(p.get("appearances",0))],12,G.MUTED))
	var compared:bool=str(p.id) in app.management_ui.compare
	var compare:=G.button("RETIRER DE LA COMPARAISON" if compared else "AJOUTER À LA COMPARAISON",func():
		if str(p.id) in app.management_ui.compare:app.management_ui.compare.erase(str(p.id))
		elif app.management_ui.compare.size()<2:app.management_ui.compare.append(str(p.id))
		app._render())
	compare.name="CompareSelected"
	compare.disabled=not compared and app.management_ui.compare.size()>=2
	compare.tooltip_text="Deux joueurs maximum. Le dialogue Comparer permet de changer les deux dossiers."
	list.add_child(compare)
	var renewal:Dictionary=p.get("renewal",{})
	var extend:=G.button("PROPOSER UNE PROLONGATION",func(): contract(app,p,false))
	extend.name="OfferRenewal"
	extend.disabled=not renewal.get("available",false) or not app._live().is_empty()
	extend.tooltip_text="Le contrat ne permet pas de prolongation supplémentaire dans la limite de trois saisons." if not renewal.get("available",false) else "Une offre sera soumise au joueur avant toute signature."
	list.add_child(extend)
	list.add_child(G.label("CHARGE INDIVIDUELLE",13,G.MUTED))
	var load_plan:=OptionButton.new()
	var modes:Array=["collective","repos","normal","intense"]
	for text in ["Suivre le collectif","Récupération individuelle","Charge normale","Charge intense"]:load_plan.add_item(text)
	load_plan.name="PlayerLoad"
	load_plan.select(maxi(0,modes.find(p.get("loadPlan","collective"))))
	load_plan.disabled=not app._live().is_empty()
	load_plan.item_selected.connect(func(index:int):app._command("set_player_load",{"playerId":p.id,"mode":modes[index]}))
	list.add_child(load_plan)
	list.add_child(G.separator())
	list.add_child(G.section("Repères de départ","Origine et degré de vérification des données initiales"))
	var roster:Dictionary=p.get("rosterProfile",{}) if p.get("rosterProfile")!=null else {}
	if not roster.is_empty():
		var position:Dictionary=roster.get("position",{})
		var status:Dictionary=roster.get("status",{})
		var initial:Dictionary=roster.get("contract",{})
		var position_basis:String="poste officiel" if position.get("basis")=="official" else "poste estimé"
		list.add_child(G.wrap("Poste principal : %s · %s"%[position.get("primary",p.pos),position_basis],13,G.MUTED))
		list.add_child(G.wrap("Qualification initiale de jeu : %s"%", ".join(position.get("qualifications",[])),13,G.MUTED))
		var status_basis:String="type de contrat officiel" if status.get("basis")=="official" else "estimation de jeu au 01/07/2026"
		list.add_child(G.wrap("Statut initial : %s · %s"%[str(status.get("value","inconnu")).capitalize(),status_basis],13,G.MUTED))
		if status.get("professionalFromSeason")!=null: list.add_child(G.wrap("Référence initiale : passage professionnel prévu en saison %s."%G.n(status.professionalFromSeason),12,G.MUTED))
		var basis:String="échéance officielle publiée" if initial.get("basis")=="official" else "durée estimée de jeu"
		var references:String=", ".join(initial.get("sources",[]))
		list.add_child(G.wrap("Référence initiale au 31/10/2026 : %s · %s (fin saison %s)."%[basis,G.n(initial.get("endYear",0)),G.n(initial.get("endSeason",0))],13,G.MUTED))
		if not references.is_empty():
			var source_dates:Array[String]=[]
			for source_id in initial.get("sources",[]):
				var source:Dictionary=app.model.get("meta",{}).get("rosterSources",{}).get(source_id,{})
				source_dates.append(str(source.get("published","date inconnue")))
			list.add_child(G.wrap("Publication officielle : %s · les signatures en jeu restent indépendantes."%", ".join(source_dates),12,G.MUTED))
	list.add_child(G.wrap(portrait.tooltip_text,12,G.MUTED))

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
	var page:=G.h(14)
	G.fill(page,true)
	page.name="CarnetLineup"
	var pitch:=G.panel(page,1.15)
	G.chapter(pitch,"02","La feuille de match","Titulaire ou remplaçant : choisissez un poste.",app.accent)
	var board:=Board.new()
	board.app=app
	pitch.add_child(board)
	var bench:=G.h(5)
	pitch.add_child(bench)
	for i in 8:
		var slot:=15+i
		var b:=G.button(str(slot+1),func():app.selected_slot=slot;app._render())
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
	var auto:=G.button("SÉLECTION AUTOMATIQUE DU STAFF",func():app._command("auto_lineup"))
	auto.disabled=not app._live().is_empty()
	side.add_child(auto)
	if not selection.get("valid",true):
		var cover:=G.button("COMPLÉTER AVEC LE CENTRE DE FORMATION",func():app.confirm("Renforcer la feuille de match", "Le staff sélectionne d'abord les joueurs disponibles, puis promeut de vrais joueurs aux postes manquants. Chaque promotion ajoute 2 500 € de salaire par semaine. Confirmer ?",func():app._command("promote_cover",{"confirmed":true})))
		cover.disabled=not app._live().is_empty() or app.model.meta.get("canAdvanceSeason",false)
		cover.tooltip_text="Une solution de secours payante ; vous pouvez aussi composer votre groupe ou recruter."
		side.add_child(cover)
	var list:=G.scroll(side)
	var eligible:Variant=selected.get("eligibleIds")
	for p in app.model.get("squad",[]):
		var b:=G.button("%s  ·  %s  ·  %s"%[p.name,p.pos,G.n(p.rating)],func():app._command("set_lineup",{"playerId":p.id,"slot":app.selected_slot}))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text="%s · %s · niveau %s"%[p.name,p.pos,G.n(p.rating)]
		b.set_meta("player_id",str(p.id))
		b.disabled=not app._live().is_empty() or float(p.get("injury",0))>0 or (eligible is Array and p.id not in eligible)
		if b.disabled:b.tooltip_text="Indisponible ou qualification incompatible avec ce poste. Pendant un match, utilisez les remplacements."
		list.add_child(b)
	var remove:=G.button("LIBÉRER CE POSTE",func():app._command("set_lineup",{"playerId":null,"slot":app.selected_slot}))
	remove.disabled=not app._live().is_empty()
	side.add_child(remove)
	return page

static func preparation(app:Control) -> Control:
	var page:=G.v(14)
	page.name="CarnetPreparation"
	G.fill(page,true)
	var tactics:Dictionary=app.model.get("tactics",{})
	var row:=G.h(14)
	G.fill(row,true)
	page.add_child(row)
	for pair in [["attack","attacks","03","Avec le ballon"],["defense","defenses","04","Sans le ballon"]]:
		var card:=G.panel(row)
		G.chapter(card,pair[2],pair[3],"Votre intention de jeu pour la rencontre",app.accent)
		var list:=G.scroll(card)
		for option in tactics.get(pair[1],[]):
			var b:=G.button(str(option.label).to_upper(),func():
				var current:Dictionary=app.model.get("tactics",{})
				var data:Dictionary={"attack":current.get("attack","equilibre"),"defense":current.get("defense","equilibre")}
				data[pair[0]]=option.id
				app._command("set_tactics",data))
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT
			b.set_meta("tactic_id",str(option.id))
			if tactics.get(pair[0])==option.id:G.selected(b,app.accent)
			b.disabled=not app._live().is_empty() and not app._live().get("paused",false)
			list.add_child(b)
			list.add_child(G.wrap(option.get("description",""),14))
			list.add_child(G.separator())
	var training:=G.panel(page)
	training.add_child(G.section("Le travail de la semaine","La séance collective agit sur la récupération et le développement."))
	var choices:=G.h(12)
	training.add_child(choices)
	for pair in [["repos","RÉCUPÉRATION"],["normal","CHARGE NORMALE"],["intense","INTENSIVE"]]:
		var b:=G.button(pair[1],func():app._command("train",{"mode":pair[0]}))
		G.fill(b)
		b.disabled=app.model.meta.get("trained",false) or not app._live().is_empty()
		choices.add_child(b)
	if app.model.meta.get("trained",false):training.add_child(G.label("Séance déjà effectuée cette semaine.",14,G.GOOD))
	training.add_child(G.button("ALLER AU JOUR DE MATCH  →",func():app._navigate("Match"),true))
	return page

static func market(app:Control) -> Control:
	var page:=G.h(14)
	page.name="CarnetMarket"
	G.fill(page,true)
	var workspace:=G.panel(page)
	G.chapter(workspace,"05","Les pistes de recrutement","Joueurs fictifs disponibles · une offre ouvre une négociation.",app.accent)
	var state:Dictionary=app.management_ui.market
	var search:=_search(workspace,"MarketSearch",state)
	var controls:=G.h(8)
	workspace.add_child(controls)
	var position:=_choice(controls,"MarketPosition",_positions(app.model.get("market",[])),state.position,"Poste")
	var available:=_choice(controls,"MarketAvailability",["Tous","Disponibles"],state.available,"Offres")
	var sort:=_choice(controls,"MarketSort",["Poste","Nom","Niveau","Âge","Salaire"],state.sort,"Trier par")
	var direction:=G.button("↓ Décroissant" if state.descending else "↑ Croissant",func():state.descending=not state.descending;app._render())
	controls.add_child(direction)
	var follow:=CheckBox.new()
	follow.name="MarketFollowed"
	follow.text="Suivis de session"
	follow.button_pressed=state.followed
	controls.add_child(follow)
	controls.add_child(G.button("Réinitialiser",func():app.management_ui.market=U.defaults();app._render()))
	var count:=G.label("",12,G.MUTED)
	count.name="MarketCount"
	workspace.add_child(count)
	var list:=G.scroll(workspace)
	list.get_parent().name="MarketScroll"
	var refresh:=func():_market_rows(app,list,count)
	search.text_changed.connect(func(text:String):state.search=text;state.scroll=0;refresh.call())
	position.item_selected.connect(func(index:int):state.position=position.get_item_text(index);state.scroll=0;refresh.call())
	available.item_selected.connect(func(index:int):state.available=available.get_item_text(index);state.scroll=0;refresh.call())
	sort.item_selected.connect(func(index:int):state.sort=sort.get_item_text(index);state.descending=state.sort=="Niveau";state.scroll=0;app._render())
	follow.toggled.connect(func(value:bool):state.followed=value;state.scroll=0;refresh.call())
	refresh.call()
	U.restore(app,page,"market")
	return page

static func _market_rows(app:Control,list:VBoxContainer,count:Label) -> void:
	_empty(list)
	var players:Array=U.players(app.model.get("market",[]),app.management_ui.market,int(app.model.meta.get("season",1)),true,app.management_ui.shortlist)
	count.text="%d / %d pistes · %d suivies dans cette session"%[players.size(),app.model.get("market",[]).size(),app.management_ui.shortlist.size()]
	var grid:=GridContainer.new()
	grid.columns=2
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",18)
	list.add_child(grid)
	for p in players:
		var card:=G.panel(grid)
		card.add_child(G.label(p.pos.to_upper(),13,G.accent_ink(app.accent)))
		var name:=G.wrap(p.name,23,G.INK)
		card.add_child(name)
		var summary:=G.h(18)
		card.add_child(summary)
		summary.add_child(G.metric(G.n(p.age),"ans"))
		summary.add_child(G.metric(G.n(p.rating),"niveau"))
		card.add_child(G.separator())
		card.add_child(G.label(G.euros(p.get("salary",0))+" / semaine",17,G.GOLD))
		card.add_child(G.wrap("Rémunération estimée de jeu",12))
		var followed:bool=str(p.id) in app.management_ui.shortlist
		var track:=G.button("RETIRER DU SUIVI" if followed else "SUIVRE CETTE PISTE",func():
			if str(p.id) in app.management_ui.shortlist:app.management_ui.shortlist.erase(str(p.id))
			else:app.management_ui.shortlist.append(str(p.id))
			app._render())
		track.name="Follow"+str(p.id).replace(":","_")
		track.set_meta("follow_id",str(p.id))
		card.add_child(track)
		var b:=G.button("PROPOSER UN CONTRAT",func():contract(app,p,true))
		b.set_meta("player_id",str(p.id))
		b.disabled=not p.get("available",true) or not app._live().is_empty()
		b.tooltip_text=p.get("reason","")
		if not str(p.get("reason","")).is_empty():
			var reason:String=p.reason
			if reason=="Effectif complet":reason="Effectif complet (%d/42)"%app.model.get("squad",[]).size()
			card.add_child(G.wrap(reason,13,G.ALERT))
		card.add_child(b)
	if players.is_empty():list.add_child(G.wrap("Aucune piste ne correspond. Modifiez la recherche, le filtre Suivis ou réinitialisez les filtres.",15))
	list.get_parent().set_deferred("scroll_vertical",int(app.management_ui.market.scroll))

static func comparison(app:Control) -> void:
	U.remember(app)
	U.sync(app)
	app._clear_dialogs()
	var d:=AcceptDialog.new()
	d.name="PlayerComparison"
	app._prepare_dialog(d,880)
	d.title="Comparer deux dossiers"
	d.get_ok_button().text="REVENIR À LA LISTE"
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
	d.confirmed.connect(func():d.queue_free();app._render())
	d.canceled.connect(func():d.queue_free();app._render())
	app.add_child(d)
	d.popup_centered(Vector2i(880,600))

static func _comparison_rows(app:Control,list:VBoxContainer,ids:Array) -> void:
	_empty(list)
	var players:Array=[]
	for id in ids:
		var found:Dictionary={}
		for p:Dictionary in app.model.get("squad",[]):
			if str(p.id)==id:found=p
		players.append(found)
	if ids[0]==ids[1] and not str(ids[0]).is_empty():list.add_child(G.wrap("Choisissez deux joueurs distincts.",14,G.ALERT));return
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
		summary.text="IMMÉDIAT · %s : %s\nRÉCURRENT · %s / semaine · %s %s / semaine\nDurée : %s saison(s) · trésorerie actuelle : %s\nMontants fictifs ; débit uniquement si signature acceptée."%["acquisition" if recruiting else "prime de prolongation",G.euros(quote.get("fee",0)),G.euros(salary.value),"ajout" if recruiting else "écart",("+" if delta>=0 else "−")+G.euros(absi(delta)),G.n(years.value),G.euros(app.model.get("finance",{}).get("cash",0))]
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
