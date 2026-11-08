extends RefCounted
## Devis en lecture seule : aucun calcul économique ni décision implicite.
const G = preload("res://ui/carnet_skin.gd")

static func _find(items: Variant, field: String, value: Variant) -> Dictionary:
	if items is Array:
		for item: Variant in items:
			if item is Dictionary and item.get(field) == value: return item
	return {}

static func describe(command: String, payload: Dictionary, model: Dictionary) -> Dictionary:
	var data: Dictionary = model.get("clubLife",{}).get("clubStrategy",{})
	if data.is_empty(): return {}
	var result := {"amount":0,"direction":"debit","recurring_amount":0,"later":"","caution":"","recurring_label":"APRÈS LA DÉCISION"}
	match command:
		"club_academy_investment":
			var amount: Variant = payload.get("amount")
			if not typeof(amount) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(amount)) or float(amount)!=floor(float(amount)) or int(amount) not in [0,4000,12000]: return {}
			result.recurring_amount=payload.amount
			result.recurring_label="À CHAQUE SÉANCE"
			result.later="%s à chaque séance de formation."%G.euros(payload.amount)
			result.caution="Aucun débit au réglage : prélèvement à la séance. L'investissement ne garantit pas la progression d'un joueur."
		"club_facility_upgrade":
			var quote: Variant = data.get("finance",{}).get("facility")
			if not quote is Dictionary or quote.get("cost")!=payload.get("cost") or quote.get("level")!=payload.get("level"): return {}
			result.amount=quote.cost
			result.later="Installations : niveau %d → %d. Entretien hebdomadaire en plus."%[int(quote.level),int(quote.nextLevel)]
			result.caution="Une amélioration par saison. L'entretien n'est pas chiffré dans ce devis. Aucun résultat sportif garanti."
		"club_board_project":
			var quote := _find(data.get("board",{}).get("projectOptions",[]),"id",payload.get("kind"))
			if quote.is_empty(): return {}
			result.amount=quote.cost
			result.later=str(quote.label)+" · paiement unique."
			result.caution="Ce projet structure l'organisation du club ; il ne donne pas de bonus automatique pendant le match."
		"club_sponsor_sign":
			var quote := _find(data.get("sponsors",[]),"id",payload.get("key"))
			if quote.is_empty(): return {}
			result.direction="credit"
			result.amount=quote.signing
			result.recurring_amount=quote.weekly
			result.recurring_label="REVENU HEBDOMADAIRE"
			result.later="%s par semaine ; %s par victoire."%[G.euros(quote.weekly),G.euros(quote.win)]
			result.caution="Une signature par saison. La prime dépend des victoires ; les revenus futurs ne sont pas encore encaissés."
		"club_fans_campaign","club_fans_community","club_fans_service":
			var category: String = {"club_fans_campaign":"campaigns","club_fans_community":"community","club_fans_service":"services"}[command]
			var quote := _find(data.get("fans",{}).get(category,[]),"id",payload.get("key"))
			if quote.is_empty(): return {}
			result.amount=quote.cost
			result.later=str(quote.label)+" · paiement unique."
			result.caution="L'affluence reste une prévision. Cette décision ne verse pas une seconde recette de billetterie."
		_: return {}
	return result

static func open(app: Control, title: String, question: String, detail: Dictionary, callback: Callable) -> ConfirmationDialog:
	if app.has_method("_clear_dialogs"): app._clear_dialogs()
	var d := ConfirmationDialog.new()
	d.name="DecisionPreviewDialog"
	d.title=title
	if app.has_method("_prepare_dialog"): app._prepare_dialog(d,650)
	else:
		d.theme=G.T.paper()
		d.min_size=Vector2i(650,0)
		d.dialog_autowrap=true
	d.dialog_text=""
	var body := G.v(8)
	body.name="DecisionPreviewBody"
	body.custom_minimum_size.x=600
	var purpose := G.wrap(question,14,G.INK)
	purpose.custom_minimum_size.x=600
	body.add_child(purpose)
	var money := G.h(12)
	body.add_child(money)
	var immediate := G.v(3)
	G.fill(immediate)
	money.add_child(immediate)
	immediate.add_child(G.label("VERSEMENT À LA SIGNATURE" if detail.direction=="credit" else "DÉBIT À LA VALIDATION",11,G.MUTED))
	var amount := G.label(G.euros(detail.amount),24,G.GOOD if detail.direction=="credit" else G.INK,true)
	amount.name="DecisionImmediateAmount"
	immediate.add_child(amount)
	var future := G.v(3)
	G.fill(future)
	money.add_child(future)
	future.add_child(G.label(detail.recurring_label,11,G.MUTED))
	var later := G.wrap(detail.later,13,G.INK)
	later.name="DecisionRecurringDetail"
	later.custom_minimum_size.x=282
	future.add_child(later)
	body.add_child(G.separator())
	var caution := G.wrap(detail.caution,12,G.MUTED)
	caution.name="DecisionUncertainty"
	caution.custom_minimum_size.x=600
	body.add_child(caution)
	d.add_child(body)
	d.get_ok_button().text="VALIDER L'ENGAGEMENT"
	d.get_cancel_button().text="ANNULER"
	d.confirmed.connect(func():d.hide();d.queue_free();callback.call())
	d.canceled.connect(func():d.hide();d.queue_free())
	app.add_child(d)
	d.popup_centered(Vector2i(650,270))
	return d
