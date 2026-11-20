extends AcceptDialog
const Copy = preload("res://ui/management_copy.gd")
const G = preload("res://ui/carnet_skin.gd")
const Prospect = preload("res://ui/prospect_profile.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const EnPlace = preload("res://ui/confirmation_en_place.gd")
## Textes à 13 px au moins en 1280×720 (même règle que les ventes : le style immersif repose un plancher de 12 px).
const Sales = preload("res://ui/player_sales_view.gd")
var app: Control
var rows: VBoxContainer
var query := ""
var selected_person: Dictionary = {}
var offer_fee := 0
var offer_salary := 1000
var negotiation: Dictionary = {}
var local_message: Label
var close_button: Button
var examine_button: Button
var budget_note: Label
var extension_button: Button
var fee_input: SpinBox
var salary_input: SpinBox
var search_field: LineEdit
var pending := false
var only_ending := false
var pre_salary: SpinBox
var pre_years: SpinBox
var pre_premium: Label
var pre_button: Button
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

func inspection_allowed(target: Dictionary) -> bool:
	return not app.waiting and not pending and not Prospect.has_child_window(self) and target.get("kind") == "prospect" and target.get("source") == "interclub" and Prospect.target_available(app, "interclub", str(target.get("id", "")))

func _profile_heading(parent: Container, person: Dictionary) -> void:
	parent.add_child(Prospect.inspection_button(app, self, "interclub", str(person.id), str(person.name), "InterclubProfile_" + str(person.id).validate_node_name()))
	parent.add_child(G.wrap("%s · %s · %s ans" % [str(person.get("club", "")), str(person.get("pos", "")), G.n(person.get("age", "—"))], 13))

func _build() -> void:
	name = "InterclubMarket"
	set_meta("navigation_inspection_source", "interclub")
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
	# Période des mutations (calendrier-mutations.cjs) : hors période, un accord est conclu et exécuté à l'ouverture.
	var mutations: Dictionary = _data().get("window", {}) if _data().get("window") is Dictionary else {}
	if not mutations.is_empty():
		var period := G.wrap(str(mutations.get("note", "")), 14, G.MUTED if mutations.get("open", false) else G.ALERT)
		period.name = "InterclubWindow"
		body.add_child(period)
	body.add_child(G.wrap(Copy.notice("interclub", _data().get("notice","Marché indisponible dans cette édition.")),13))
	# Joueurs en fin de contrat : pré-contrat possible à moins de six mois de l'échéance (arrivée au 1er juillet).
	var ending := CheckButton.new()
	ending.name = "InterclubPreContractFilter"
	ending.text = "Seulement les fins de contrat (pré-contrats)"
	ending.add_theme_font_size_override("font_size", 14)
	ending.button_pressed = only_ending
	ending.toggled.connect(func(value: bool): only_ending = value; page = 0; _redraw())
	body.add_child(ending)
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
	Sales.lisible(body)

func _redraw() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var data := _data()
	var filtered: Array = []
	var available := 0
	var term := query.to_lower()
	for person: Dictionary in data.get("candidates",[]):
		if only_ending and not person.get("preContract") is Dictionary: continue
		if term.is_empty() or (str(person.name)+" "+str(person.club)+" "+str(person.pos)).to_lower().contains(term):
			filtered.append(person)
			if person.get("available", false): available += 1
	page = clampi(page,0,maxi(0,ceili(float(filtered.size())/PAGE_SIZE)-1))
	var buyer_status := G.wrap("Ton effectif professionnel est complet. Le catalogue reste consultable.", 13, G.ALERT)
	buyer_status.name = "InterclubBuyerStatus"
	buyer_status.visible = available == 0 and app.model.get("decisions", {}).get("recruitment", {}).get("places", -1) == 0
	rows.add_child(buyer_status)
	var navigation := G.h(10)
	rows.add_child(navigation)
	var previous := G.button("←",func(): page -= 1; _redraw())
	previous.disabled = page == 0
	navigation.add_child(previous)
	var proposals := "%d propositions possibles" % available if available > 1 else "%d proposition possible" % available
	var summary := G.label("%d profils · %s · page %d" % [filtered.size(), proposals, page+1], 13)
	summary.name = "InterclubOfferSummary"
	navigation.add_child(summary)
	var next := G.button("→",func(): page += 1; _redraw())
	next.disabled = (page+1)*PAGE_SIZE >= filtered.size()
	navigation.add_child(next)
	for i in range(page*PAGE_SIZE,mini((page+1)*PAGE_SIZE,filtered.size())):
		var person: Dictionary = filtered[i]
		var card := G.card(rows)
		_profile_heading(card, person)
		card.add_child(G.wrap("Indemnité %s · salaire proposé %s · échéance %s conservée" % [G.euros(person.fee),G.salary(person.salary),G.season_label(person.contractEnd)],13))
		if not str(person.reason).is_empty(): card.add_child(G.wrap(Copy.notice("interclub", person.reason),13,G.ALERT))
		var offer := G.button("PROPOSER L’ACCORD",func(): _offer(person))
		offer.name = "InterclubOffer"
		offer.set_meta("player_id",str(person.id))
		offer.disabled = app.waiting or not person.get("available",false)
		card.add_child(offer)
		_precontract_line(card, person)
	Sales.lisible(rows)

## Pré-contrat (calendrier-mutations.cjs, `candidates[].preContract`) : signé (arrivée au 1er juillet), possible
## (bouton) ou pas encore (raison écrite).
func _precontract_line(card: Container, person: Dictionary) -> void:
	var pre: Variant = person.get("preContract")
	if not pre is Dictionary: return
	if pre.get("signed") is Dictionary:
		var signed := G.wrap(str(pre.signed.get("label", "")), 14)
		signed.name = "InterclubPreContractStatus"
		card.add_child(signed)
	elif pre.get("available", false):
		var button := G.button("PROPOSER UN PRÉ-CONTRAT", func(): _precontract(person))
		button.name = "InterclubPreContract"
		button.set_meta("player_id", str(person.id))
		button.disabled = app.waiting
		card.add_child(button)
	else:
		var reason := G.wrap("Pré-contrat : " + str(pre.get("reason", "")), 13, G.MUTED)
		reason.name = "InterclubPreContractReason"
		card.add_child(reason)

## Fenêtre du pré-contrat : salaire (au moins la demande du joueur), durée, prime à la signature recalculée, budget de
## transferts ; « Proposer » ouvre la confirmation (W1).
func _precontract(person: Dictionary) -> void:
	if app.waiting or pending: return
	selected_person = person.duplicate(true)
	var pre: Dictionary = person.preContract
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	search_field.editable = false
	_profile_heading(rows, person)
	var note := G.wrap(str(pre.get("note", "")), 14)
	note.name = "PreContractNote"
	rows.add_child(note)
	var fields := G.h(12)
	rows.add_child(fields)
	for item in [["Salaire " + G.salary_period(), "PreContractSalary"], ["Durée (saisons)", "PreContractYears"]]:
		var column := G.v(4)
		fields.add_child(column)
		column.add_child(G.label(str(item[0]), 14))
		var input := SpinBox.new()
		input.name = str(item[1])
		column.add_child(input)
		if item[1] == "PreContractSalary":
			pre_salary = input
			input.min_value = 1000
			input.max_value = 100000
			input.step = 100
			preload("res://ui/salary_display.gd").bind_input(input, int(pre.get("salary", 1000)), int(pre.get("salary", 1000)), 100000)
			input.value_changed.connect(func(_value: float): _precontract_check())
		else:
			pre_years = input
			input.min_value = int(pre.get("minYears", 1))
			input.max_value = int(pre.get("maxYears", 1))
			input.step = 1
			input.value = int(pre.get("minYears", 1))
	pre_premium = G.wrap("", 14)
	pre_premium.name = "PreContractPremium"
	rows.add_child(pre_premium)
	local_message = G.wrap("Le joueur demande au moins %s ; il arrivera le %s." % [G.salary(pre.get("salary", 0)), str(pre.get("arrivalLabel", ""))], 14)
	local_message.name = "PreContractMessage"
	rows.add_child(local_message)
	pre_button = G.button("PROPOSER LE PRÉ-CONTRAT", _confirm_precontract)
	pre_button.name = "PreContractSubmit"
	rows.add_child(pre_button)
	rows.add_child(G.button("REVENIR AUX JOUEURS", func():
		if pending: return
		selected_person = {}; search_field.editable = true; _redraw()))
	_precontract_check()
	Sales.lisible(rows)

func _precontract_salary() -> int:
	return preload("res://ui/salary_display.gd").input_weekly(pre_salary) if is_instance_valid(pre_salary) else 0

## Prime = arrondi supérieur(salaire × premiumWeeks, premiumStep) ; refusée au-delà du budget de transferts disponible.
func _precontract_premium() -> int:
	var pre: Dictionary = selected_person.get("preContract", {})
	var step := maxi(1, int(pre.get("premiumStep", 1000)))
	return int(ceil(float(_precontract_salary()) * float(pre.get("premiumWeeks", 2)) / step)) * step

func _precontract_check() -> void:
	if not is_instance_valid(pre_premium): return
	var premium := _precontract_premium()
	var transfer := Budget.data(app.model)
	var over := not transfer.is_empty() and premium > int(transfer.get("disponible", 0))
	pre_premium.text = "Prime à la signature : %s, payée maintenant sur le budget de transferts (%s). Aucune indemnité pour %s." % [G.euros(premium), Budget.remaining(transfer) if not transfer.is_empty() else "trésorerie", str(selected_person.get("club", ""))]
	if over: pre_premium.text += " Prime supérieure au budget de transferts disponible."
	pre_premium.add_theme_color_override("font_color", G.ALERT if over else G.INK)
	if is_instance_valid(pre_button): pre_button.disabled = over or pending or app.waiting

## Confirmation EN PLACE du pré-contrat (deux temps, aucune fenêtre) : sous le bouton, la phrase d'engagement, la prime payée
## maintenant, « Signer le pré-contrat avec X » / « Annuler » (focus sur Annuler). La réponse s'écrit dans le message de la page.
func _confirm_precontract() -> void:
	if pending or app.waiting or selected_person.is_empty(): return
	var pre: Dictionary = selected_person.get("preContract", {})
	var payload := {"playerId":str(selected_person.id), "sellerId":int(selected_person.clubId), "salary":_precontract_salary(), "years":int(pre_years.value), "confirmed":true}
	var lines: Array = [
		{"id":"PreContractConfirmHeading", "text":"%s rejoindra ton club le %s pour %d saison%s (salaire : %s). Aucune indemnité pour %s." % [str(selected_person.get("name", "")), str(pre.get("arrivalLabel", "")), int(pre_years.value), "s" if int(pre_years.value) > 1 else "", G.salary(_precontract_salary()), str(selected_person.get("club", ""))]},
		{"id":"PreContractConfirmPremium", "text":"Prime à la signature : %s, payée maintenant (budget de transferts). Il reste à %s jusqu’au 30 juin." % [G.euros(_precontract_premium()), str(selected_person.get("club", ""))]}]
	var envoyer := func():
		pending = true
		if is_instance_valid(pre_button): pre_button.disabled = true
		local_message.text = "Proposition transmise au joueur…"
		if not app._command("precontract_offer", payload): _on_failure("Pré-contrat indisponible.")
	var bloc := EnPlace.ouvrir(app, rows, "PreContractConfirmation", "Signer un pré-contrat", lines, "Signer le pré-contrat avec " + str(selected_person.get("name", "")), envoyer, pre_button)
	Sales.lisible(bloc)
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
	_profile_heading(rows, person)
	rows.add_child(G.wrap("La consultation ne réserve pas le joueur. La clôture peut attribuer le joueur à un autre club ; tu verras le gagnant pressenti avant de confirmer.",13))
	var fields := G.h(12)
	rows.add_child(fields)
	for item in [["Indemnité (€)","fee",offer_fee,1000000000,1000],["Salaire "+G.salary_period(),"salary",offer_salary,100000,100]]:
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
			input.value_changed.connect(func(value: float): offer_fee=int(value); _invalidate_quote(); _budget_check())
		else:
			salary_input = input
			preload("res://ui/salary_display.gd").bind_input(input,offer_salary,1000,100000)
			input.value_changed.connect(func(_value: float): offer_salary=preload("res://ui/salary_display.gd").input_weekly(input); _invalidate_quote())
	local_message = G.wrap("Propose tes conditions pour recevoir les réponses et découvrir les offres concurrentes.",13)
	local_message.name = "InterclubNegotiationMessage"
	rows.add_child(local_message)
	budget_note = G.wrap("",13)
	budget_note.name = "InterclubTransferBudget"
	rows.add_child(budget_note)
	# Rallonge demandée au conseil (R3 bis) : visible quand l’indemnité dépasse l’enveloppe mais que la caisse la permettrait.
	extension_button = G.button("",_ask_extension)
	extension_button.name = "InterclubTransferBudgetExtension"
	extension_button.visible = false
	rows.add_child(extension_button)
	var examine := G.button("SOUMETTRE LES CONDITIONS",_negotiate)
	examine.name = "InterclubNegotiate"
	examine_button = examine
	rows.add_child(examine)
	close_button = G.button("CLÔTURER SELON LE DEVIS",_confirm_auction)
	close_button.name = "InterclubCloseAuction"
	close_button.disabled = true
	rows.add_child(close_button)
	rows.add_child(G.button("REVENIR AUX JOUEURS",func():
		if pending: return
		selected_person={}; negotiation={}; search_field.editable=true; _redraw()))
	_budget_check()
	Sales.lisible(rows)

## Enveloppe du conseil (finance.transferBudget) : une indemnité au-delà du disponible ne peut pas être soumise.
## Le moteur la refuse de toute façon ; la raison est écrite avant l’envoi. Le salaire n’entre pas dans le budget.
func _budget_check() -> void:
	if not is_instance_valid(budget_note) or not is_instance_valid(examine_button): return
	var transfer := Budget.data(app.model)
	budget_note.visible = not transfer.is_empty()
	var extension := Budget.extension_amount(transfer, offer_fee)
	if is_instance_valid(extension_button):
		extension_button.visible = extension > 0
		extension_button.text = Budget.extension_button(extension).to_upper() if extension > 0 else ""
		extension_button.set_meta("amount", extension)
		extension_button.disabled = pending or app.waiting
	if transfer.is_empty():
		examine_button.disabled = false
		return
	var over := offer_fee > int(transfer.get("disponible", 0))
	budget_note.text = "%s : %s %s." % [Budget.LABEL, Budget.remaining(transfer), Budget.allocated(transfer)]
	if over and extension > 0: budget_note.text += " Indemnité supérieure au budget de transferts : baisse-la, ou demande une rallonge au conseil."
	elif over and offer_fee > int(transfer.get("caisseLibre", 0)): budget_note.text += " La caisse ne permet pas cette indemnité : elle doit rester au-dessus de %s ; une rallonge du conseil n’y changerait rien." % G.euros(transfer.get("matelas", 0))
	elif over: budget_note.text += " Indemnité supérieure au budget de transferts : baisse-la pour soumettre tes conditions."
	budget_note.add_theme_color_override("font_color", G.ALERT if over else G.MUTED)
	examine_button.disabled = over

func _ask_extension() -> void:
	var amount := int(extension_button.get_meta("amount", 0)) if is_instance_valid(extension_button) else 0
	if pending or app.waiting or amount <= 0: return
	var envoyee := func():
		pending = true
		extension_button.disabled = true
		local_message.text = "Demande transmise au conseil…"
	Sales.lisible(Budget.confirm_extension(app, rows, Budget.data(app.model), amount, envoyee, extension_button))
func _invalidate_quote() -> void:
	negotiation = {}
	close_button.disabled = true
	local_message.text = "Conditions modifiées : soumets-les à nouveau avant toute clôture."

func _payload() -> Dictionary:
	return {"playerId":str(selected_person.id),"sellerId":int(selected_person.clubId),"fee":offer_fee,"salary":offer_salary,"sourceSalary":int(selected_person.sourceSalary),"contractEnd":int(selected_person.contractEnd),"context":_data().get("context",{}).duplicate(true)}

func _negotiate() -> void:
	if pending or app.waiting or (is_instance_valid(examine_button) and examine_button.disabled): return
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
		lines.append(Copy.notice("interclub", negotiation.get("seller",{}).get("reason","")))
		lines.append(Copy.notice("interclub", negotiation.get("player",{}).get("reason","")))
		lines.append(str(negotiation.get("humanReason","")))
		for offer: Dictionary in negotiation.get("offers",[]):
			lines.append("%s : %s d’indemnité, %s · besoin annoncé %d" % [str(offer.club),G.euros(offer.fee),G.salary(offer.salary),int(offer.need)])
		var winner: Variant = negotiation.get("winner")
		if negotiation.get("deferred") is Dictionary: lines.append(str(negotiation.deferred.get("note", "")))
		if winner is Dictionary:
			lines.append("Gagnant pressenti : " + str(winner.club) + ". Vérification finale à la clôture.")
			close_button.disabled = false
		else: lines.append("Aucune offre recevable : modifie tes conditions ou abandonne.")
		local_message.text = "\n".join(lines)
	elif app.last_command == Budget.EXTENSION_COMMAND:
		pending = false
		var answer: Variant = value.get("meta",{}).get("transferBudgetExtension")
		local_message.text = (str(answer.get("message","")) if answer is Dictionary else "") + " Soumets à nouveau tes conditions."
		_budget_check.call_deferred()
	elif app.last_command == "interclub_auction":
		pending = false
		negotiation = {}
		close_button.disabled = true
		var receipt: Dictionary = value.get("meta",{}).get("interclubTransfer",{})
		if receipt.get("deferred", false): local_message.text = "Accord conclu hors période des mutations : le joueur rejoindra ton club le %s. L’indemnité est engagée sur le budget de transferts ; elle sera versée à son arrivée." % str(receipt.get("dateLabel", ""))
		else: local_message.text = "Accord conclu : le joueur rejoint ton club." if receipt.get("humanWon",false) else "Un club concurrent a remporté le joueur. Ta trésorerie est conservée."
	elif app.last_command == "precontract_offer":
		pending = false
		var signed: Variant = value.get("meta",{}).get("preContract")
		local_message.text = str(signed.get("message","")) if signed is Dictionary else "Pré-contrat signé."
		if is_instance_valid(pre_button): pre_button.disabled = true

func _on_failure(message: String) -> void:
	if not pending: return
	pending = false
	if is_instance_valid(pre_button) and pre_button.is_inside_tree():
		local_message.text = message
		_precontract_check()
		return
	fee_input.editable = true
	salary_input.editable = true
	negotiation = {}
	close_button.disabled = true
	local_message.text = message + " Tes conditions sont conservées ; soumets-les à nouveau."
	_budget_check()

## Confirmation EN PLACE de la clôture (deux temps, aucune fenêtre) : sous le bouton de clôture.
func _confirm_auction() -> void:
	if pending or app.waiting or negotiation.is_empty(): return
	var winner: Variant = negotiation.get("winner")
	if not winner is Dictionary: return
	var payload := _payload()
	payload.context = negotiation.get("context",{}).duplicate(true)
	payload.merge({"expectedWinner":int(winner.clubId),"expectedFee":int(winner.fee),"expectedSalary":int(winner.salary),"confirmed":true})
	var phrase := "%s remportera le joueur au devis actuel : %s d’indemnité, %s. Confirmer cette transaction définitive ?" % [str(winner.club),G.euros(winner.fee),G.salary(winner.salary)]
	var libelle := "Clôturer au devis : " + G.euros(winner.fee)
	# Hors période des mutations (calendrier-mutations.cjs) : accord conclu maintenant, arrivée à l'ouverture.
	if negotiation.get("deferred") is Dictionary:
		phrase = "Hors période des mutations : l’accord est conclu maintenant (%s d’indemnité, %s), le joueur rejoindra ton club le %s. L’accord est définitif." % [G.euros(winner.fee), G.salary(winner.salary), str(negotiation.deferred.get("dateLabel", ""))]
		libelle = "Conclure l’accord"
	var envoyer := func():
		pending=true; close_button.disabled=true; fee_input.editable=false; salary_input.editable=false
		if not app._command("interclub_auction",payload): _on_failure("Clôture indisponible.")
	var bloc := EnPlace.ouvrir(app, rows, "InterclubAuctionConfirmation", "Clôturer la négociation", [{"id":"InterclubAuctionPhrase", "text":phrase}], libelle, envoyer, close_button)
	Sales.lisible(bloc)