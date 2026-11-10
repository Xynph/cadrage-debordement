extends AcceptDialog
## Lecture du vivier et des observations publiques ; aucun talent secret déduit.
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const Decisions = preload("res://ui/decision_views.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const PAGE_SIZE := 20
const FAMILIES := ["Piliers","Talonneurs","Deuxième ligne","Troisième ligne","Demi de mêlée","Ouverture","Ailiers","Centres","Arrières"]
var app: Control
var state: Dictionary
var body: VBoxContainer
var list: VBoxContainer
var scroll: ScrollContainer
var counter: Label
var previous: Button
var next: Button
var page_label: Label

static func entry(owner_app: Control, parent: Container) -> Button:
	var button := G.button("REPÉRER LA RELÈVE →",func(): open(owner_app))
	button.name = "OpenRegenScouting"
	parent.add_child(button)
	return button

static func open(owner_app: Control) -> AcceptDialog:
	owner_app._clear_dialogs()
	var view: AcceptDialog = load("res://ui/regen_scouting_view.gd").new()
	view.app = owner_app
	view._build()
	return view

func _data() -> Dictionary:
	return app.model.get("clubLife",{}).get("regenScouting",{})

func _build() -> void:
	name = "RegenScouting"
	title = "Détecter la relève"
	get_ok_button().text = "FERMER"
	app._prepare_dialog(self,360)
	if not app.management_ui.get("regen_scouting") is Dictionary:
		app.management_ui.regen_scouting = {"page":0,"query":"","family":-1,"origin":0,"minAge":18,"maxAge":60,"needs":false,"watched":false}
	state = app.management_ui.regen_scouting
	scroll = ScrollContainer.new()
	scroll.name = "RegenScoutingScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	body = G.v(10); G.fill(body,true); scroll.add_child(body)
	body.add_child(G.section("La relève disponible", "Agents libres majeurs · centres de formation et petits clubs simulés"))
	body.add_child(G.wrap(str(_data().get("notice","Le vivier n’est pas disponible dans cette carrière.")),13))
	var filters := HFlowContainer.new(); filters.add_theme_constant_override("h_separation",8); body.add_child(filters)
	var search := LineEdit.new(); search.name = "RegenScoutSearch"; search.placeholder_text = "Nom ou identifiant…"; search.custom_minimum_size = Vector2(220,36); search.text = str(state.query); filters.add_child(search)
	search.text_changed.connect(func(value: String): state.query = value; state.page = 0; _redraw())
	var family := OptionButton.new(); family.name = "RegenScoutFamily"; family.add_item("Tous les postes")
	for label in FAMILIES: family.add_item(label)
	family.select(int(state.family)+1); filters.add_child(family)
	family.item_selected.connect(func(index: int): state.family = index-1; state.page = 0; _redraw())
	var origin := OptionButton.new(); origin.name = "RegenScoutOrigin"
	for label in ["Toutes les origines","Diplômés des centres","Petits clubs simulés"]: origin.add_item(label)
	origin.select(int(state.origin)); filters.add_child(origin)
	origin.item_selected.connect(func(index: int): state.origin = index; state.page = 0; _redraw())
	var ages := G.h(8); body.add_child(ages)
	ages.add_child(G.label("Âges",13))
	for field in ["minAge","maxAge"]:
		var age := SpinBox.new(); age.name = "RegenScout"+field.capitalize(); age.min_value = 18; age.max_value = 60; age.value = int(state[field]); ages.add_child(age)
		age.value_changed.connect(func(value: float): state[field] = int(value); state.page = 0; _redraw())
	var flags := HFlowContainer.new(); body.add_child(flags)
	for option in [["needs","Besoins du club"],["watched","Liste suivie (archives comprises)"]]:
		var flag := CheckBox.new(); flag.name = "RegenScout"+str(option[0]).capitalize(); flag.text = option[1]; flag.button_pressed = bool(state[option[0]]); flags.add_child(flag)
		flag.toggled.connect(func(value: bool): state[option[0]] = value; state.page = 0; _redraw())
	var mission := G.button("BESOINS, MISSIONS ET RAPPORTS · mission à 5 000 €",_missions)
	mission.name = "RegenScoutMissions"; body.add_child(mission)
	counter = G.wrap("",13); counter.name = "RegenScoutCount"; body.add_child(counter)
	list = G.v(8); list.name = "RegenScoutRows"; body.add_child(list)
	var paging := G.h(8); body.add_child(paging)
	previous = G.button("← PRÉCÉDENT",func(): state.page -= 1; _redraw()); previous.name = "RegenScoutPrevious"; paging.add_child(previous)
	page_label = G.label("",12); paging.add_child(page_label)
	next = G.button("SUIVANT →",func(): state.page += 1; _redraw()); next.name = "RegenScoutNext"; paging.add_child(next)
	confirmed.connect(queue_free); canceled.connect(queue_free)
	app.add_child(self)
	app.bridge.model_changed.connect(func(_model: Dictionary): if app.bridge.last_response_ok: _redraw())
	app.get_window().size_changed.connect(_fit)
	_redraw(); _fit()
	get_tree().process_frame.connect(_initial_focus.bind(search),CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func _initial_focus(search: LineEdit) -> void:
	if not is_visible(): return
	search.grab_focus()
	scroll.scroll_vertical = 0

func _fit() -> void:
	var host: Vector2i = app.get_window().size
	var width := mini(1060,host.x-48)
	body.custom_minimum_size.x = width-48
	scroll.custom_minimum_size.y = mini(600,host.y-160)
	Dialogs.show_centered(self,Vector2i(width,mini(780,host.y-80)))

func _matches(person: Dictionary) -> bool:
	var query := U.fold(str(state.query)).strip_edges()
	if not query.is_empty() and not U.fold(str(person.get("name",""))+" "+str(person.get("playerId",person.id))).contains(query): return false
	if int(state.family)>=0 and int(person.get("family",-1)) != int(state.family): return false
	if person.has("age"):
		if int(person.age)<int(state.minAge) or int(person.age)>int(state.maxAge): return false
	elif int(state.minAge)!=18 or int(state.maxAge)!=60: return false
	if bool(state.needs) and person.get("matchingSlots",[]).is_empty(): return false
	var kind := str(person.get("origin",{}).get("kind",""))
	if int(state.origin)==1 and kind!="academy": return false
	if int(state.origin)==2 and kind!="small-club": return false
	return true

func _redraw() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var data := _data()
	var source: Array = data.get("shortlist",[]) if bool(state.watched) else data.get("candidates",[])
	var people := source.filter(_matches)
	state.page = clampi(int(state.page),0,maxi(0,ceili(float(people.size())/PAGE_SIZE)-1))
	var start: int = int(state.page)*PAGE_SIZE
	for person: Dictionary in people.slice(start,start+PAGE_SIZE): _person(person,data)
	if people.is_empty(): list.add_child(G.wrap("Aucun profil dans cette sélection. Les profils sans provenance connue ne sont pas inventés.",14))
	counter.text = "%d profils · %d / %d suivis au total" % [people.size(),data.get("shortlist",[]).size(),int(data.get("shortlistLimit",30))]
	if int(state.minAge)>int(state.maxAge): counter.text = "Âge minimum supérieur au maximum : ajustez les filtres."
	previous.disabled = start == 0
	next.disabled = start+PAGE_SIZE >= people.size()
	page_label.text = "%d / %d" % [int(state.page)+1,maxi(1,ceili(float(people.size())/PAGE_SIZE))]

func _person(person: Dictionary,data: Dictionary) -> void:
	var card := G.card(list); card.name = "RegenScoutCard"; card.set_meta("player_id",str(person.get("playerId",person.id)))
	var row := G.h(10); card.add_child(row)
	if person.has("name"): row.add_child(G.portrait(0,64,person))
	var info := G.v(4); G.fill(info); row.add_child(info)
	info.add_child(G.wrap(str(person.get("name","Profil indisponible · "+str(person.id))),20,G.INK))
	if person.has("age"):
		info.add_child(G.wrap("%s · %d ans · %s" % [str(person.get("pos","")),int(person.age),str(person.get("origin",{}).get("label","Origine non précisée"))],13))
		var origin: Dictionary = person.get("origin",{})
		if origin.get("season") != null: info.add_child(G.wrap("Origine en saison %s · disponible depuis la saison %s" % [G.n(origin.season),G.n(origin.get("availableSince","—"))],12))
		var evidence: Dictionary = person.get("evidence",{})
		info.add_child(G.wrap(str(evidence.get("label","Pas encore observé")),13))
		info.add_child(G.wrap("Niveau : %s · potentiel : %s" % [_interval(evidence.get("noteMin"),evidence.get("noteMax")),_interval(evidence.get("potentialMin"),evidence.get("potentialMax"))],13))
		if evidence.get("seen",false): info.add_child(G.wrap("Rapport S%s · semaine %s%s" % [G.n(evidence.get("season","—")),G.n(evidence.get("week","—"))," · ancien : à actualiser" if evidence.get("stale",false) else ""],12))
		info.add_child(G.wrap("Prime %s · salaire demandé %s · %d besoin(s) compatible(s)" % [G.euros(person.get("fee",0)),G.salary(person.get("salary",0)),person.get("matchingSlots",[]).size()],12))
		for term: Dictionary in person.get("terms",[]):
			info.add_child(G.wrap("%d saison(s) · %d échéances · engagement connu %s" % [int(term.years),int(term.payments),G.euros(term.knownCommitment)],12))
	if not str(person.get("reason","")).is_empty(): info.add_child(G.wrap(str(person.reason),13,G.ALERT))
	var actions := HFlowContainer.new(); card.add_child(actions)
	var watched: bool = person.get("watched",false)
	var follow := G.button("RETIRER DU SUIVI" if watched else "SUIVRE",func(): _watch(person,not watched))
	follow.name = "RegenScoutWatch"; follow.set_meta("player_id",str(person.get("playerId",person.id)))
	follow.disabled = app.waiting or data.get("locked",true) or (not watched and data.get("shortlist",[]).size()>=int(data.get("shortlistLimit",30)))
	actions.add_child(follow)
	if person.has("name"):
		var offer := G.button("APPROCHER LE JOUEUR",func(): app.SquadViews.contract(app,person,true))
		offer.name = "RegenScoutOffer"; offer.set_meta("player_id",str(person.id)); offer.disabled = app.waiting or not person.get("available",false); actions.add_child(offer)

func _watch(person: Dictionary,watched: bool) -> void:
	if app.waiting: return
	app._command("regen_shortlist",{"playerId":str(person.get("playerId",person.id)),"watched":watched,"context":_data().get("context",{}).duplicate(true)})
	_redraw()

func _missions() -> void:
	Decisions.recruitment(app)
	var tabs := app.find_child("ScoutTabs",true,false) as TabContainer
	if tabs != null: tabs.current_tab = 1

static func _interval(low: Variant,high: Variant) -> String:
	return "non observé" if low == null or high == null else "%s–%s" % [G.n(low),G.n(high)]
