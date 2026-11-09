extends AcceptDialog
const G = preload("res://ui/carnet_skin.gd")
var app: Control
var rows: VBoxContainer
var query := ""
var page := 0
const PAGE_SIZE := 12

static func entry(owner_app: Control, parent: Container) -> Button:
	var button := G.button("NÉGOCIER ENTRE CLUBS →",func(): open(owner_app))
	button.name = "OpenInterclubMarket"
	parent.add_child(button)
	return button

static func open(owner_app: Control) -> AcceptDialog:
	owner_app._clear_dialogs()
	var view: AcceptDialog = load("res://ui/interclub_market_view.gd").new()
	view.app = owner_app
	view._build()
	return view

func _data() -> Dictionary:
	return app.model.get("clubLife",{}).get("interclubMarket",{})

func _build() -> void:
	name = "InterclubMarket"
	title = "Marché entre clubs"
	get_ok_button().text = "FERMER"
	app._prepare_dialog(self,880)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var body := G.v(10)
	G.fill(body,true)
	scroll.add_child(body)
	body.add_child(G.section("Approcher un joueur sous contrat"))
	body.add_child(G.wrap(str(_data().get("notice","Marché indisponible dans cette édition.")),13))
	var search := LineEdit.new()
	search.name = "InterclubSearch"
	search.placeholder_text = "Rechercher un club, joueur ou poste…"
	body.add_child(search)
	search.text_changed.connect(func(value: String): query = value; page = 0; _redraw())
	rows = G.v(8)
	body.add_child(rows)
	_redraw()
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	app.add_child(self)
	popup_centered(Vector2i(880,580))

func _redraw() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var data := _data()
	var filtered: Array = []
	for person: Dictionary in data.get("candidates",[]):
		if query.is_empty() or (str(person.name)+" "+str(person.club)+" "+str(person.pos)).to_lower().contains(query.to_lower()): filtered.append(person)
	page = clampi(page,0,maxi(0,ceili(float(filtered.size())/PAGE_SIZE)-1))
	var navigation := G.h(10)
	rows.add_child(navigation)
	var previous := G.button("←",func(): page -= 1; _redraw())
	previous.disabled = page == 0
	navigation.add_child(previous)
	navigation.add_child(G.label("%d profils · page %d" % [filtered.size(),page+1],13))
	var next := G.button("→",func(): page += 1; _redraw())
	next.disabled = (page+1)*PAGE_SIZE >= filtered.size()
	navigation.add_child(next)
	for i in range(page*PAGE_SIZE,mini((page+1)*PAGE_SIZE,filtered.size())):
		var person: Dictionary = filtered[i]
		var card := G.card(rows)
		card.add_child(G.section(str(person.name),"%s · %s · %d ans" % [str(person.club),str(person.pos),int(person.age)]))
		card.add_child(G.wrap("Indemnité %s · salaire proposé %s / semaine · échéance S%d conservée" % [G.euros(person.fee),G.euros(person.salary),int(person.contractEnd)],13))
		if not str(person.reason).is_empty(): card.add_child(G.wrap(str(person.reason),12,G.ALERT))
		var offer := G.button("PROPOSER L’ACCORD",func(): _offer(person))
		offer.name = "InterclubOffer"
		offer.set_meta("player_id",str(person.id))
		offer.disabled = app.waiting or not person.get("available",false)
		card.add_child(offer)

func _offer(person: Dictionary) -> void:
	if app.waiting: return
	var payload := {"playerId":str(person.id),"sellerId":int(person.clubId),"fee":int(person.fee),"salary":int(person.salary),"sourceSalary":int(person.sourceSalary),"contractEnd":int(person.contractEnd),"context":_data().get("context",{}).duplicate(true),"confirmed":true}
	app.confirm("Confirmer la libération anticipée", "%s : verser %s à %s et engager %s par semaine jusqu’à la fin de S%d ?" % [str(person.name),G.euros(person.fee),str(person.club),G.euros(person.salary),int(person.contractEnd)],func(): app._command("interclub_transfer",payload))
