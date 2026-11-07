extends RefCounted
const G = preload("res://ui/game_skin.gd")
const Board = preload("res://ui/lineup_board.gd")

static func squad(app: Control) -> Control:
	var page := G.h(14)
	G.fill(page,true)
	var table := G.panel(page,1.7)
	var controls := G.h(8)
	table.add_child(controls)
	var filter := OptionButton.new()
	for name in ["Tous","Avants","Arrières","Blessés","Hors groupe"]: filter.add_item(name)
	filter.select(["Tous","Avants","Arrières","Blessés","Hors groupe"].find(app.roster_filter))
	filter.item_selected.connect(func(index:int): app.roster_filter=filter.get_item_text(index);app._render())
	controls.add_child(filter)
	var sort := OptionButton.new()
	for name in ["Poste","Niveau","Condition","Âge"]: sort.add_item(name)
	sort.select(["Poste","Niveau","Condition","Âge"].find(app.roster_sort))
	sort.item_selected.connect(func(index:int): app.roster_sort=sort.get_item_text(index);app._render())
	controls.add_child(sort)
	controls.add_child(G.label("JOUEURS PROFESSIONNELS",11,G.MUTED))
	var header := G.h(10)
	table.add_child(header)
	for pair in [["JOUEUR",180],["POSTE",105],["ÂGE",33],["NIV.",36],["COND.",50]]: header.add_child(G.cell(pair[0],pair[1],G.MUTED,pair[0]=="JOUEUR"))
	var players: Array = app.model.get("squad",[]).duplicate()
	if app.roster_sort != "Poste":
		var key: String = {"Niveau":"rating","Condition":"condition","Âge":"age"}.get(app.roster_sort,"rating")
		players.sort_custom(func(a:Dictionary,b:Dictionary): return float(a.get(key,0))>float(b.get(key,0)))
	var list := G.scroll(table)
	var selected: Dictionary = app.model.squad[0] if not app.model.get("squad",[]).is_empty() else {}
	for p in app.model.get("squad",[]):
		if str(p.id)==app.selected_player: selected=p
	for p in players:
		if app.roster_filter=="Avants" and float(p.get("fam",0))>3: continue
		if app.roster_filter=="Arrières" and float(p.get("fam",0))<=3: continue
		if app.roster_filter=="Blessés" and float(p.get("injury",0))<=0: continue
		if app.roster_filter=="Hors groupe" and p.get("shirtNumber")!=null: continue
		var b := G.button("",func():app.selected_player=str(p.id);app._render())
		b.custom_minimum_size.y=43
		if str(p.id)==str(selected.get("id","")): b.add_theme_stylebox_override("normal",G.T.box(app.accent.darkened(.70),4,app.accent))
		var inset:=G.margin(5)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(inset)
		var row:=G.h(10)
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inset.add_child(row)
		row.add_child(G.cell(p.name,180,G.INK,true))
		row.add_child(G.cell(p.pos,105,G.MUTED))
		row.add_child(G.cell(G.n(p.age),33,G.MUTED))
		row.add_child(G.cell(G.n(p.rating),36,G.GOLD))
		row.add_child(G.cell(G.n(p.condition)+"%",50,G.GOOD))
		list.add_child(b)
	var profile := G.panel(page,1.0)
	if not selected.is_empty(): _profile(app,profile,selected)
	return page

static func _profile(app:Control,parent:VBoxContainer,p:Dictionary) -> void:
	var list:=G.scroll(parent)
	var top:=G.h(12)
	list.add_child(top)
	var portrait := G.portrait(int(p.get("portraitIndex",0)),90,p)
	top.add_child(portrait)
	var identity:=G.v(3)
	G.fill(identity)
	top.add_child(identity)
	var name:=G.label(p.name,29,G.INK,true)
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(name)
	identity.add_child(G.wrap("%s · %s ans"%[p.pos,G.n(p.age)],12))
	identity.add_child(G.label(p.get("status",""),11,app.accent.lightened(.5)))
	var roster:Dictionary=p.get("rosterProfile",{}) if p.get("rosterProfile")!=null else {}
	if not roster.is_empty():
		var position:Dictionary=roster.get("position",{})
		var status:Dictionary=roster.get("status",{})
		var initial:Dictionary=roster.get("contract",{})
		var position_basis:String="poste officiel" if position.get("basis")=="official" else "poste estimé"
		list.add_child(G.wrap("Poste principal : %s · %s"%[position.get("primary",p.pos),position_basis],11,G.MUTED))
		list.add_child(G.wrap("Qualification initiale de jeu : %s"%", ".join(position.get("qualifications",[])),11,G.MUTED))
		var status_basis:String="type de contrat officiel" if status.get("basis")=="official" else "estimation de jeu au 01/07/2026"
		list.add_child(G.wrap("Statut initial : %s · %s"%[str(status.get("value","inconnu")).capitalize(),status_basis],11,G.MUTED))
		if status.get("professionalFromSeason")!=null: list.add_child(G.wrap("Référence initiale : passage professionnel prévu en saison %s."%G.n(status.professionalFromSeason),10,G.MUTED))
		var basis:String="échéance officielle publiée" if initial.get("basis")=="official" else "durée estimée de jeu"
		var references:String=", ".join(initial.get("sources",[]))
		list.add_child(G.wrap("Référence initiale au 31/10/2026 : %s · %s (fin saison %s)."%[basis,G.n(initial.get("endYear",0)),G.n(initial.get("endSeason",0))],11,G.MUTED))
		if not references.is_empty():
			var source_dates:Array[String]=[]
			for source_id in initial.get("sources",[]):
				var source:Dictionary=app.model.get("meta",{}).get("rosterSources",{}).get(source_id,{})
				source_dates.append("%s · %s"%[source_id,source.get("published","date inconnue")])
			list.add_child(G.wrap("Source officielle %s · référence initiale, indépendante des signatures en jeu."%", ".join(source_dates),10,G.MUTED))
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
		grid.add_child(G.label(pair[1]+"  "+G.n(p.get("attributes",{}).get(pair[0],"—")),12,G.MUTED))
	list.add_child(G.separator())
	list.add_child(G.label("Contrat courant : "+p.get("contractLabel",""),13))
	list.add_child(G.label(G.euros(p.get("salary",0))+" / semaine · estimation de jeu",12,G.MUTED))
	list.add_child(G.label("%s minutes · %s apparitions"%[G.n(p.get("minutes",0)),G.n(p.get("appearances",0))],12,G.MUTED))
	var renewal:Dictionary=p.get("renewal",{})
	var extend:=G.button("PROPOSER UNE PROLONGATION",func(): contract(app,p,false))
	extend.disabled=not renewal.get("available",false) or not app._live().is_empty()
	extend.tooltip_text="Le contrat ne permet pas de prolongation supplémentaire dans la limite de trois saisons." if not renewal.get("available",false) else "Une offre sera soumise au joueur avant toute signature."
	list.add_child(extend)
	list.add_child(G.label("CHARGE INDIVIDUELLE",11,G.MUTED))
	var load_plan:=OptionButton.new()
	var modes:Array=["collective","repos","normal","intense"]
	for text in ["Suivre le collectif","Récupération individuelle","Charge normale","Charge intense"]:load_plan.add_item(text)
	load_plan.select(maxi(0,modes.find(p.get("loadPlan","collective"))))
	load_plan.disabled=not app._live().is_empty()
	load_plan.item_selected.connect(func(index:int):app._command("set_player_load",{"playerId":p.id,"mode":modes[index]}))
	list.add_child(load_plan)
	list.add_child(G.wrap(portrait.tooltip_text,10,G.MUTED))

static func radar_setup(radar:Control,p:Dictionary,accent:Color) -> void:
	radar_mode(radar)
	radar.accent=accent
	var attrs:Dictionary=p.get("attributes",{})
	radar.values=[attrs.get("power",0),attrs.get("speed",0),attrs.get("pass",0),attrs.get("tackle",0),attrs.get("stamina",0),attrs.get("mental",0)]
	radar.custom_minimum_size=Vector2(160,160)

static func radar_mode(radar:Control) -> void:
	radar.mode="radar"

static func lineup(app:Control) -> Control:
	var page:=G.h(14)
	G.fill(page,true)
	var pitch:=G.panel(page,1.15)
	pitch.add_child(G.section("VOTRE XV TITULAIRE","Choisissez un poste sur le terrain"))
	var board:=Board.new()
	board.app=app
	pitch.add_child(board)
	var bench:=G.h(5)
	pitch.add_child(bench)
	for i in 8:
		var slot:=15+i
		var b:=G.button(str(slot+1),func():app.selected_slot=slot;app._render())
		G.fill(b)
		if app.selected_slot==slot: b.add_theme_stylebox_override("normal",G.T.box(Color("494132"),4,G.GOLD))
		bench.add_child(b)
	var side:=G.panel(page,1.0)
	side.add_child(G.section("POSTE %02d"%(app.selected_slot+1),"Le moteur vérifie les qualifications et les indisponibilités"))
	var selection:Dictionary=app.model.get("selection",{})
	var slots:Array=selection.get("slots",[])
	var selected:Dictionary={}
	for s in slots:
		if int(s.get("slot",-1))==app.selected_slot:selected=s
	var errors:Array=selection.get("errors",[])
	if errors.is_empty():side.add_child(G.label("FEUILLE VALIDE",12,G.GOOD))
	else:side.add_child(G.wrap("\n".join(errors),12,Color("efbaa5")))
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
		b.disabled=not app._live().is_empty() or float(p.get("injury",0))>0 or (eligible is Array and p.id not in eligible)
		if b.disabled:b.tooltip_text="Indisponible ou qualification incompatible avec ce poste. Pendant un match, utilisez les remplacements."
		list.add_child(b)
	var remove:=G.button("LIBÉRER CE POSTE",func():app._command("set_lineup",{"playerId":null,"slot":app.selected_slot}))
	remove.disabled=not app._live().is_empty()
	side.add_child(remove)
	return page

static func preparation(app:Control) -> Control:
	var page:=G.v(15)
	G.fill(page,true)
	var row:=G.h(15)
	G.fill(row,true)
	page.add_child(row)
	var tactics:Dictionary=app.model.get("tactics",{})
	for pair in [["attack","attacks","EN ATTAQUE"],["defense","defenses","EN DÉFENSE"]]:
		var card:=G.panel(row)
		card.add_child(G.section(pair[2],"Un choix de jeu appliqué au moteur"))
		var list:=G.scroll(card)
		for option in tactics.get(pair[1],[]):
			var b:=G.button(str(option.label).to_upper(),func():
				var current:Dictionary=app.model.get("tactics",{})
				var data:Dictionary={"attack":current.get("attack","equilibre"),"defense":current.get("defense","equilibre")}
				data[pair[0]]=option.id
				app._command("set_tactics",data))
			if tactics.get(pair[0])==option.id:b.add_theme_stylebox_override("normal",G.T.box(app.accent.darkened(.65),4,app.accent))
			b.disabled=not app._live().is_empty() and not app._live().get("paused",false)
			list.add_child(b)
			list.add_child(G.wrap(option.get("description",""),12))
	var training:=G.h(14)
	page.add_child(training)
	var panel:=G.panel(training)
	panel.add_child(G.section("LA SÉANCE COLLECTIVE","La charge agit réellement sur la récupération et le développement"))
	var choices:=G.h(10)
	panel.add_child(choices)
	for pair in [["repos","RÉCUPÉRATION"],["normal","CHARGE NORMALE"],["intense","INTENSIVE"]]:
		var b:=G.button(pair[1],func():app._command("train",{"mode":pair[0]}))
		G.fill(b)
		b.disabled=app.model.meta.get("trained",false) or not app._live().is_empty()
		choices.add_child(b)
	if app.model.meta.get("trained",false):panel.add_child(G.label("Séance déjà effectuée cette semaine.",12,G.GOOD))
	page.add_child(G.button("ALLER AU JOUR DE MATCH  →",func():app._navigate("Match"),true))
	return page

static func market(app:Control) -> Control:
	var page:=G.v(12)
	G.fill(page,true)
	page.add_child(G.wrap("Joueurs fictifs disponibles. Une proposition passe par la négociation du joueur et ne garantit pas sa signature.",13))
	var list:=G.scroll(page)
	for p in app.model.get("market",[]):
		var card:=G.panel(list)
		var row:=G.h(15)
		card.add_child(row)
		var identity:=G.v(3)
		G.fill(identity)
		row.add_child(identity)
		identity.add_child(G.label(p.name,24,G.INK,true))
		identity.add_child(G.label("%s · %s ans · niveau %s"%[p.pos,G.n(p.age),G.n(p.rating)],12,G.MUTED))
		row.add_child(G.label(G.euros(p.get("salary",0))+" / semaine · estimation de jeu",13,G.GOLD))
		var b:=G.button("PROPOSER UN CONTRAT",func():contract(app,p,true))
		b.disabled=not p.get("available",true) or not app._live().is_empty()
		b.tooltip_text=p.get("reason","")
		row.add_child(b)
	if app.model.get("market",[]).is_empty():list.add_child(G.wrap("Aucune offre disponible à ce stade de la carrière. Les nouvelles opportunités suivent les journées.",15))
	return page

static func contract(app:Control,p:Dictionary,recruiting:bool) -> void:
	app._clear_dialogs()
	var d:=ConfirmationDialog.new()
	d.title="Offre à "+str(p.name)
	d.dialog_text=""
	var fields:=G.v(8)
	# A zero-width autowrap label inflates the initial minimum height of Window.
	# Two explicit lines give the dialog a bounded minimum before its first layout.
	fields.add_child(G.label("Salaire hebdomadaire et durée proposés.\nLe joueur peut refuser ou faire une contre-offre.",13,G.MUTED))
	var salary:=SpinBox.new()
	var quote:Dictionary=p if recruiting else p.get("renewal",{})
	salary.min_value=1000
	salary.max_value=100000
	salary.step=100
	salary.value=float(quote.get("salary",p.get("salary",5000)))
	salary.suffix="€ / semaine"
	fields.add_child(salary)
	var years:=SpinBox.new()
	years.min_value=quote.get("minYears",1)
	years.max_value=quote.get("maxYears",3)
	years.value=maxf(years.min_value,2)
	years.suffix="saison(s)"
	fields.add_child(years)
	fields.add_child(G.label(("Coût d'acquisition : " if recruiting else "Prime de prolongation : ")+G.euros(quote.get("fee",0)),12,G.MUTED))
	d.get_ok_button().text="SOUMETTRE L'OFFRE"
	d.get_cancel_button().text="ANNULER"
	d.add_child(fields)
	d.confirmed.connect(func():app._command("recruit" if recruiting else "extend_contract",{"playerId":p.id,"salary":int(salary.value),"years":int(years.value),"confirmed":true});d.queue_free())
	d.canceled.connect(d.queue_free)
	app.add_child(d)
	d.popup_centered(Vector2i(630,280))
