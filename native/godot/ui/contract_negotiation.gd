extends RefCounted
## Présentation des conditions projetées. Le moteur conserve la négociation et la signature.
const C = preload("res://ui/immersive08/components.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/game_skin.gd")
const Salary = preload("res://ui/salary_display.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const Prolongation = preload("res://ui/prolongation_visuelle.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

static func money(value: Variant) -> String:
	return G.euros(value) if value is int or value is float else "Non communiqué"

static func signed_money(value: int) -> String:
	return ("+" if value >= 0 else "−") + G.salary(absi(value))

static func state_text(quote: Dictionary) -> Dictionary:
	var negotiation: Dictionary = quote.get("negotiation", {})
	var status := str(negotiation.get("status", ""))
	if status == "withdrawn":
		return {"title":"RETRAIT POUR CETTE JOURNÉE", "progress":"Trois propositions refusées · discussion close", "action":"Reprise à la prochaine journée", "blocked":true}
	if status == "counter":
		var attempts := int(negotiation.get("attempts", 0))
		return {"title":"CONTRE-OFFRE REÇUE", "progress":"Proposition %d/3 enregistrée" % attempts, "action":"Proposition %d/3" % mini(3, attempts+1), "blocked":false}
	return {"title":"PRÉPARER UNE PROPOSITION", "progress":"Prochaine proposition · 1/3", "action":"Proposition 1/3", "blocked":false}

static func _card(parent: Node, title: String, id: String, tint: Color) -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = id
	card.set_meta("immersive_style_applied",true)
	card.add_theme_stylebox_override("panel",C.box(C.RAISED,tint,6,14))
	C.fill(card)
	parent.add_child(card)
	var body := C.v(8)
	card.add_child(body)
	body.add_child(C.label(title,17,tint,true,700))
	return body

static func _spin(parent: Node, id: String, title: String, minimum: float, maximum: float, initial: float, step: float, suffix: String) -> SpinBox:
	parent.add_child(C.label(title,16,C.MUTED))
	var control := SpinBox.new()
	control.name = id
	control.min_value = minimum
	control.max_value = maximum
	control.value = initial
	control.step = step
	control.suffix = suffix
	control.set_meta("immersive_style_applied",true)
	control.custom_minimum_size.y = C.px(38)
	control.get_line_edit().add_theme_font_override("font",C.BODY)
	control.get_line_edit().add_theme_font_size_override("font_size",C.px(20))
	control.get_line_edit().accessibility_name = title
	parent.add_child(control)
	return control

## `answer` : réponse du conseil à une demande de rallonge, affichée en tête quand le devis est rouvert après elle.
static func open(app: Control, player: Dictionary, recruiting: bool, answer: String = "") -> void:
	U.remember(app)
	app._clear_dialogs()
	var dialog := ConfirmationDialog.new()
	dialog.name = "ContractOffer"
	var taille := Vector2i(1540,860)
	# Prolongation (choix B de Léo, 21/11/2026) : fenêtre à la hauteur de la toile, sans bande vide sous la prime.
	if not recruiting: taille = Vector2i(roundi(1500 * C.density) + 70, roundi((Prolongation.HAUTEUR + 100) * C.density))
	app._prepare_dialog(dialog,taille.x)
	dialog.title = "Offre à " + str(player.name)
	dialog.dialog_text = ""
	var content := C.v(10)
	content.set_meta("immersive_style_applied",true)
	dialog.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	# L'offre dessinée garde sa largeur : si la fenêtre du jeu rétrécit l'offre ouverte, elle défile au lieu de déborder.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	C.fill(scroll,true)
	content.add_child(scroll)
	var body := C.v(12)
	C.fill(body)
	scroll.add_child(body)
	var quote: Dictionary = player if recruiting else player.get("renewal",{})
	var negotiation: Dictionary = quote.get("negotiation",{})
	var phase := state_text(quote)
	var blocked: bool = phase.blocked or not bool(quote.get("available",false)) or app.waiting or not app._live().is_empty()
	var identity := C.h(14)
	body.add_child(identity)
	var portrait := G.portrait(0,64,player)
	portrait.name = "ContractPlayerPortrait"
	portrait.set_meta("player_id",str(player.id))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(portrait)
	var identity_text := C.v(5)
	C.fill(identity_text)
	identity.add_child(identity_text)
	identity_text.add_child(C.label("RECRUTEMENT" if recruiting else "PROLONGATION",17,C.GOLD,true,700))
	identity_text.add_child(C.label(str(player.name),28,C.IVORY,true,800))
	var status := C.label(phase.title,19,C.ALERT if phase.blocked else C.GOLD,true,700)
	status.name = "ContractNegotiationStatus"
	body.add_child(status)
	var progress := C.label(phase.progress,16,C.MUTED)
	progress.name = "ContractNegotiationProgress"
	body.add_child(progress)
	if not answer.is_empty():
		var reply := C.wrap(answer,18,C.MINT if answer.begins_with("Le conseil accorde") else C.ALERT,true,700)
		reply.name = "ContractTransferBudgetAnswer"
		body.add_child(reply)
	var columns := C.h(16)
	body.add_child(columns)
	var demand := _card(columns,"DEMANDE ACTUELLE","ContractDemand",C.MINT)
	demand.add_child(C.label(G.salary(quote.get("salary")),20,C.IVORY,true,700))
	demand.add_child(C.wrap("Durée possible · %s à %s saison(s)" % [str(int(quote.get("minYears",1))),str(int(quote.get("maxYears",3)))],17,C.MUTED))
	demand.add_child(C.wrap("Prime à la signature · "+money(quote.get("fee")),18,C.GOLD))
	if not recruiting:
		demand.add_child(C.wrap("Contrat actuel · "+G.contract_year(player.get("contractEnd")),16,C.MUTED))
		demand.add_child(C.wrap("Salaire actuel · "+G.salary(player.get("salary")),16,C.MUTED))
	var counter := _card(columns,"DERNIÈRE CONTRE-OFFRE","ContractCounter",C.GOLD)
	var counter_text := C.wrap("Aucune contre-offre en cours.",20,C.IVORY,true,700)
	counter_text.name = "ContractCurrentNegotiation"
	if negotiation.get("status") == "counter":
		counter_text.text = "%s\n%d saison(s) · Proposition %d/3" % [G.salary(negotiation.get("salary")), int(negotiation.get("years",1)),int(negotiation.get("attempts",0))]
	elif phase.blocked:
		counter_text.text = "Discussion close.\n" + str(quote.get("reason","Négociation close jusqu’à la prochaine journée."))
	counter.add_child(counter_text)
	var proposal := _card(columns,"TA NOUVELLE PROPOSITION","ContractProposal",C.BLUE)
	# Le plus petit salaire qu’un contrat peut porter vient du moteur quand il le fournit.
	var floor_salary := float(app.model.get("finance",{}).get("salaryFloor",1000))
	var salary := _spin(proposal,"OfferSalary",Salary.field_label(),floor_salary,100000,float(quote.get("salary",player.get("salary",5000))),100,"€ / semaine")
	Salary.bind_input(salary,float(quote.get("salary",player.get("salary",5000))),floor_salary,100000)
	var years := _spin(proposal,"OfferYears","Durée du contrat",float(quote.get("minYears",1)),float(quote.get("maxYears",3)),maxf(float(quote.get("minYears",1)),2),1,"saison(s)")
	var difference := C.wrap("",16,C.GOLD)
	difference.name = "ContractOfferDifference"
	proposal.add_child(difference)
	var reuse := C.button("Reprendre la contre-offre",func():
		Salary.set_input_weekly(salary,float(negotiation.get("salary",Salary.input_weekly(salary))))
		years.value = float(negotiation.get("years",years.value)))
	reuse.name = "ContractUseCounteroffer"
	reuse.add_theme_font_size_override("font_size",C.px(18))
	reuse.disabled = blocked or negotiation.get("status") != "counter"
	proposal.add_child(reuse)
	salary.editable = not blocked
	years.editable = not blocked
	var summary_panel := PanelContainer.new()
	summary_panel.set_meta("immersive_style_applied",true)
	summary_panel.add_theme_stylebox_override("panel",C.box(C.PANEL,C.LINE,6,14))
	body.add_child(summary_panel)
	var summary := C.wrap("",18,C.IVORY)
	summary.name = "OfferSummary"
	summary_panel.add_child(summary)
	var meta: Dictionary = app.model.get("meta",{})
	var first_season := int(meta.get("season",1)) + (1 if meta.get("phase") == "ended" else 0)
	var refresh := func():
		var weekly_salary := Salary.input_weekly(salary)
		var delta := weekly_salary - (0 if recruiting else int(player.get("salary",0)))
		var term := "Fin de contrat proposée : " + G.contract_year(first_season + int(years.value) - 1)
		if not recruiting:
			var end: Variant = player.get("contractEnd")
			term = "Échéance actuelle : %s · " % ("—" if end == null else G.contract_year(end)) + term
		summary.text = "IMMÉDIAT À LA SIGNATURE · %s : %s\nNOUVEAU SALAIRE · %s · %s %s\n%s\nDurée totale : %s saison(s) · trésorerie actuelle : %s" % ["acquisition" if recruiting else "prime de prolongation",money(quote.get("fee")),G.salary(weekly_salary),"ajout" if recruiting else "écart",signed_money(delta),term,str(int(years.value)),money(app.model.get("finance",{}).get("cash"))]
		difference.text = "Écart avec la demande actuelle · %s" % signed_money(weekly_salary-int(quote.get("salary",weekly_salary)))
		if negotiation.get("status") == "counter":
			difference.text += "\nÉcart avec la contre-offre · %s" % signed_money(weekly_salary-int(negotiation.salary))
	salary.value_changed.connect(func(_value:float):refresh.call())
	years.value_changed.connect(func(_value:float):refresh.call())
	refresh.call()
	var action := C.wrap(phase.action,18,C.ALERT if phase.blocked else C.MINT)
	action.name = "ContractNextAction"
	body.add_child(action)
	var transfer := Budget.data(app.model)
	if blocked and not phase.blocked:
		var reason := C.wrap(str(quote.get("reason","Cette offre ne peut pas être envoyée dans la situation actuelle.")),18,C.ALERT)
		reason.name = "ContractBlockedReason"
		body.add_child(reason)
		# Refus d’enveloppe que la caisse permettrait : le manager peut demander le manquant au conseil (R3 bis).
		var extension := Budget.extension_for_refusal(transfer, quote.get("fee"), quote.get("reason","")) if recruiting and not bool(quote.get("available",false)) else 0
		if extension > 0:
			var ask := C.button(Budget.extension_button(extension),func(): pass)
			ask.pressed.connect(func(): _ask_extension(app,dialog,body,ask,player,transfer,extension))
			ask.name = "ContractTransferBudgetExtension"
			ask.add_theme_font_size_override("font_size",C.px(18))
			ask.disabled = app.waiting or not app._live().is_empty()
			body.add_child(ask)
	if recruiting and not transfer.is_empty():
		var share := C.wrap("%s : %s %s" % [Budget.LABEL, Budget.remaining(transfer), Budget.allocated(transfer)],16,C.MUTED)
		share.name = "ContractTransferBudget"
		share.mouse_filter = Control.MOUSE_FILTER_STOP
		share.tooltip_text = "La prime à la signature est prélevée sur ce budget ; le salaire n’y entre pas."
		body.add_child(share)
	# Offre au joueur (choix de Léo du 21/11/2026) : règle demande / proposition, frise des saisons, jeton de prime.
	# Les blocs ci-dessus restent construits (mêmes nœuds, mêmes champs) mais masqués.
	# Prolongation (choix B de Léo, 21/11/2026) : ancien contrat mis en regard du nouveau.
	for ancien: Variant in [identity, status, progress, columns, summary_panel, action, body.get_node_or_null("ContractTransferBudget")]:
		if ancien != null: (ancien as Control).visible = false
	var ctx := {"app":app, "player":player, "quote":quote, "salary":salary, "years":years, "first_season":first_season,
		"negotiation":negotiation, "phase":phase, "reuse":reuse, "prolongation":not recruiting}
	if recruiting: preload("res://ui/offre_visuelle.gd").construire(body, ctx)
	else: Prolongation.construire(body, ctx)
	dialog.get_ok_button().text = "AUTORISER LA SIGNATURE SI ACCORD"
	dialog.get_ok_button().tooltip_text = "Envoie ces conditions. Si le joueur accepte, le contrat est signé et la prime est débitée ; sinon, seule la discussion est enregistrée. Annuler ne transmet aucune proposition."
	dialog.get_ok_button().disabled = blocked
	dialog.get_cancel_button().text = "FERMER" if blocked else "ANNULER"
	dialog.confirmed.connect(func():
		if blocked: return
		app._command("recruit" if recruiting else "extend_contract",{"playerId":player.id,"salary":Salary.input_weekly(salary),"years":int(years.value),"confirmed":true})
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	# Échap ferme d'abord la petite fenêtre ouverte dans l'offre, puis seulement l'offre elle-même.
	dialog.dialog_close_on_escape = false
	dialog.window_input.connect(func(evenement: InputEvent):
		if not evenement.is_action_pressed("ui_cancel", false, true): return
		dialog.set_input_as_handled()
		if not PetiteFenetre.fermer_derniere(dialog.get_tree()): dialog.get_cancel_button().pressed.emit())
	app.add_child(dialog)
	Dialogs.show_centered(dialog,taille)
	dialog.add_theme_font_size_override("title_font_size",C.px(20))
	for button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
		button.add_theme_font_size_override("font_size",C.px(18))
		button.custom_minimum_size.y = C.px(40)
	# Doré réservé à la validation : le cadre de focus d'Annuler reste ivoire.
	var focus_annuler := dialog.get_cancel_button().get_theme_stylebox("focus")
	if focus_annuler is StyleBoxFlat:
		var ivoire := (focus_annuler as StyleBoxFlat).duplicate() as StyleBoxFlat
		ivoire.border_color = preload("res://ui/charte.gd").IVOIRE
		dialog.get_cancel_button().add_theme_stylebox_override("focus", ivoire)
	dialog.get_cancel_button().grab_focus()

## Rallonge demandée au conseil depuis le refus : confirmation (focus sur Annuler), puis devis rouvert avec la réponse.
static func _ask_extension(app: Control, dialog: ConfirmationDialog, body: Node, ask: Node, player: Dictionary, transfer: Dictionary, amount: int) -> void:
	var player_id := str(player.id)
	# Réponse traitée à l’image suivante, après la mise à jour du modèle et de l’erreur éventuelle par main.gd.
	var after := func(): _after_extension(app,player_id,player)
	var next_frame := func(_value: Dictionary): app.get_tree().process_frame.connect(after,CONNECT_ONE_SHOT)
	# Demande envoyée : l’ancienne vue se ferme, le devis est rouvert avec la réponse (jamais deux vues empilées).
	# Confirmation EN PLACE sous le bouton (deux temps, aucune fenêtre).
	var envoyee := func():
		app.bridge.model_changed.connect(next_frame,CONNECT_ONE_SHOT)
		dialog.queue_free()
	Budget.confirm_extension(app,body,transfer,amount,envoyee,ask)
static func _after_extension(app: Control, player_id: String, previous: Dictionary) -> void:
	if app.last_command != Budget.EXTENSION_COMMAND: return
	var refreshed := previous
	for candidate: Dictionary in app.model.get("market",[]):
		if str(candidate.get("id","")) == player_id: refreshed = candidate
	open(app,refreshed,true,Budget.extension_answer(app))
