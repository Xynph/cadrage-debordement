extends AcceptDialog
const G = preload("res://ui/carnet_skin.gd")
var app: Control
var rows: VBoxContainer
var query := ""
var selected_person: Dictionary = {}
var offer_fee := 0
var offer_salary := 1000
var negotiation: Dictionary = {}
var local_message: Label
var close_button: Button
var fee_input: SpinBox
var salary_input: SpinBox
var search_field: LineEdit
var pending := false
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
	search_field = search
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
	app.bridge.model_changed.connect(_on_model)
	app.bridge.command_failed.connect(_on_failure)
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
	selected_person = person.duplicate(true)
	offer_fee = int(person.fee)
	offer_salary = int(person.salary)
	negotiation = {}
	_draw_negotiation()

func _draw_negotiation() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	search_field.editable = false
	var person := selected_person
	rows.add_child(G.section(str(person.name), "Négocier avec " + str(person.club)))
	rows.add_child(G.wrap("Les montants sont fictifs. La consultation ne réserve pas le joueur. La clôture peut attribuer le joueur à un autre club ; vous verrez le gagnant pressenti avant de confirmer.",13))
	var fields := G.h(12)
	rows.add_child(fields)
	for item in [["Indemnité (€)","fee",offer_fee,1000000000,1000],["Salaire / semaine (€)","salary",offer_salary,100000,100]]:
		var column := G.v(4)
		fields.add_child(column)
		column.add_child(G.label(str(item[0]),13))
		var input := SpinBox.new()
		input.name = "InterclubFee" if item[1]=="fee" else "InterclubSalary"
		input.min_value = 0 if item[1]=="fee" else 1000
		input.max_value = int(item[3])
		input.step = int(item[4])
		input.value = int(item[2])
		column.add_child(input)
		if item[1]=="fee":
			fee_input = input
			input.value_changed.connect(func(value: float): offer_fee=int(value); _invalidate_quote())
		else:
			salary_input = input
			input.value_changed.connect(func(value: float): offer_salary=int(value); _invalidate_quote())
	local_message = G.wrap("Proposez vos conditions pour recevoir les réponses et découvrir les offres concurrentes.",13)
	local_message.name = "InterclubNegotiationMessage"
	rows.add_child(local_message)
	var examine := G.button("SOUMETTRE LES CONDITIONS",_negotiate)
	examine.name = "InterclubNegotiate"
	rows.add_child(examine)
	close_button = G.button("CLÔTURER SELON LE DEVIS",_confirm_auction)
	close_button.name = "InterclubCloseAuction"
	close_button.disabled = true
	rows.add_child(close_button)
	rows.add_child(G.button("REVENIR AUX JOUEURS",func():
		if pending: return
		selected_person={}; negotiation={}; search_field.editable=true; _redraw()))

func _invalidate_quote() -> void:
	negotiation = {}
	close_button.disabled = true
	local_message.text = "Conditions modifiées : soumettez-les à nouveau avant toute clôture."

func _payload() -> Dictionary:
	return {"playerId":str(selected_person.id),"sellerId":int(selected_person.clubId),"fee":offer_fee,"salary":offer_salary,"sourceSalary":int(selected_person.sourceSalary),"contractEnd":int(selected_person.contractEnd),"context":_data().get("context",{}).duplicate(true)}

func _negotiate() -> void:
	if pending or app.waiting: return
	pending = true
	fee_input.editable = false
	salary_input.editable = false
	close_button.disabled = true
	local_message.text = "Réponses des clubs et du joueur…"
	if not app._command("interclub_negotiate",_payload()): _on_failure("Consultation indisponible.")

func _on_model(value: Dictionary) -> void:
	if not pending or not app.bridge.last_response_ok: return
	if app.last_command == "interclub_negotiate":
		pending = false
		fee_input.editable = true
		salary_input.editable = true
		negotiation = value.get("meta",{}).get("interclubNegotiation",{}).duplicate(true)
		var lines := PackedStringArray()
		lines.append(str(negotiation.get("seller",{}).get("reason","")))
		lines.append(str(negotiation.get("player",{}).get("reason","")))
		lines.append(str(negotiation.get("humanReason","")))
		for offer: Dictionary in negotiation.get("offers",[]):
			lines.append("%s : %s d’indemnité, %s / semaine · besoin public %d" % [str(offer.club),G.euros(offer.fee),G.euros(offer.salary),int(offer.need)])
		var winner: Variant = negotiation.get("winner")
		if winner is Dictionary:
			lines.append("Gagnant pressenti : " + str(winner.club) + ". Vérification finale à la clôture.")
			close_button.disabled = false
		else: lines.append("Aucune offre recevable : modifiez vos conditions ou abandonnez.")
		local_message.text = "\n".join(lines)
	elif app.last_command == "interclub_auction":
		pending = false
		negotiation = {}
		close_button.disabled = true
		var receipt: Dictionary = value.get("meta",{}).get("interclubTransfer",{})
		local_message.text = "Accord conclu : le joueur rejoint votre club." if receipt.get("humanWon",false) else "Un club concurrent a remporté le joueur. Votre trésorerie est conservée."

func _on_failure(message: String) -> void:
	if not pending: return
	pending = false
	fee_input.editable = true
	salary_input.editable = true
	negotiation = {}
	close_button.disabled = true
	local_message.text = message + " Vos conditions sont conservées ; soumettez-les à nouveau."

func _confirm_auction() -> void:
	if pending or app.waiting or negotiation.is_empty(): return
	var winner: Variant = negotiation.get("winner")
	if not winner is Dictionary: return
	var payload := _payload()
	payload.context = negotiation.get("context",{}).duplicate(true)
	payload.merge({"expectedWinner":int(winner.clubId),"expectedFee":int(winner.fee),"expectedSalary":int(winner.salary),"confirmed":true})
	var confirm := ConfirmationDialog.new()
	confirm.name = "InterclubAuctionConfirmation"
	confirm.title = "Clôturer la négociation"
	confirm.dialog_text = "%s remportera le joueur au devis actuel : %s d’indemnité, %s / semaine. Confirmer cette transaction définitive ?" % [str(winner.club),G.euros(winner.fee),G.euros(winner.salary)]
	add_child(confirm)
	confirm.confirmed.connect(func():
		pending=true; close_button.disabled=true; fee_input.editable=false; salary_input.editable=false
		if not app._command("interclub_auction",payload): _on_failure("Clôture indisponible.")
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered(Vector2i(600,180))
