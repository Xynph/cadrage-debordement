extends RefCounted
## Budget de transferts fixé par le conseil (docs/gdd/budget-transferts.md), lu dans `finance.transferBudget`.
## Affichage seul : le moteur refuse les offres hors budget (devis indisponible + raison) et décide des rallonges
## (commande `transfer_budget_extension`).
const G = preload("res://ui/game_skin.gd")
const LABEL := "Disponible pour les transferts"
## Début du refus d’enveloppe écrit par le moteur (budget-transferts.cjs, refus) ; le refus de caisse commence autrement.
const REFUSAL := "Hors budget de transferts"
const EXTENSION_COMMAND := "transfer_budget_extension"
## Ligne « Dépensé · reconstitué » du Recrutement : au-delà, rallonge et report restent dans l’infobulle (bandeau à 520 px).
const MOVES_MAX_CHARS := 50

## Budget actif du club joué, ou {} (carrière sans budget de saison : on garde la trésorerie).
static func data(model: Dictionary) -> Dictionary:
	var finance: Variant = model.get("finance")
	if not finance is Dictionary: return {}
	var budget: Variant = finance.get("transferBudget")
	if not budget is Dictionary or not bool(budget.get("actif", false)): return {}
	return budget

static func remaining(budget: Dictionary) -> String:
	return G.euros(budget.get("disponible", 0))

## Enveloppe de la saison : fixée par le conseil + report de la saison passée + rallonges accordées.
static func season_total(budget: Dictionary) -> int:
	return int(budget.get("enveloppe", 0)) + int(budget.get("report", 0)) + int(budget.get("rallonge", 0))

static func allocated(budget: Dictionary) -> String:
	return "sur %s alloués par le conseil" % G.euros(season_total(budget))

static func movements(budget: Dictionary) -> String:
	var text := "Dépensé %s · reconstitué %s" % [G.euros(budget.get("depense", 0)), G.euros(budget.get("reconstitue", 0))]
	for item in [["rallonge", "rallonge"], ["report", "report"]]:
		var value := int(budget.get(item[0], 0))
		var more := " · %s %s" % [item[1], G.euros(value)]
		if value > 0 and text.length() + more.length() <= MOVES_MAX_CHARS: text += more
	return text

static func detail(budget: Dictionary, cash: Variant) -> String:
	var lines := PackedStringArray(["Enveloppe fixée par le conseil : %s" % G.euros(budget.get("enveloppe", 0))])
	if int(budget.get("report", 0)) > 0: lines.append("Report de la saison passée : %s" % G.euros(budget.get("report", 0)))
	if int(budget.get("rallonge", 0)) > 0 or int(budget.get("demandes", 0)) > 0:
		lines.append("Rallonges accordées par le conseil : %s (%d sur %d possibles)" % [G.euros(budget.get("rallonge", 0)), int(budget.get("rallongesAccordees", 0)), int(budget.get("rallongeMax", 0))])
	lines.append_array([
		"Trésorerie du club : %s" % (G.euros(cash) if cash is int or cash is float else "—"),
		"Dépensé en indemnités et primes : %s" % G.euros(budget.get("depense", 0)),
		"Reconstitué par les ventes : %s" % G.euros(budget.get("reconstitue", 0)),
		"Les salaires n’entrent pas dans ce budget : ils restent dans la masse salariale · joueurs.",
	])
	return "\n".join(lines)

## Rallonge à demander au conseil pour un montant refusé par l’enveloppe, ou 0 (le montant passe, ou la caisse limite).
## Même calcul que le moteur (budget-transferts.cjs, demandeRallonge) : possible si reste < montant ≤ caisse − matelas,
## montant − reste arrondi au millier supérieur. Le moteur rejuge la demande.
static func extension_amount(budget: Dictionary, fee: Variant) -> int:
	if budget.is_empty() or not (fee is int or fee is float): return 0
	var amount := int(fee)
	var rest := int(budget.get("reste", 0))
	if amount <= rest or amount > int(budget.get("caisseLibre", 0)): return 0
	var step := maxi(1, int(budget.get("rallongeArrondi", 1000)))
	return int(ceil(float(amount - rest) / float(step))) * step

## Refus d’enveloppe (pas de caisse) pour lequel une rallonge est possible : montant à demander, sinon 0.
static func extension_for_refusal(budget: Dictionary, fee: Variant, reason: Variant) -> int:
	if not str(reason).begins_with(REFUSAL): return 0
	return extension_amount(budget, fee)

static func extension_button(amount: int) -> String:
	return "Demander %s au conseil" % G.euros(amount)

static func extension_question(budget: Dictionary, amount: int) -> String:
	var cost: Dictionary = budget.get("rallongeCout", {}) if budget.get("rallongeCout") is Dictionary else {}
	return "Demander %s au conseil pour compléter le budget de transferts ?\nLe président répond tout de suite. Accordée, la rallonge s’ajoute à l’enveloppe de la saison et coûte %d points de confiance ; refusée, elle en coûte %d.\nRallonges accordées cette saison : %d sur %d." % [G.euros(amount), int(cost.get("accordee", 0)), int(cost.get("refusee", 0)), int(budget.get("rallongesAccordees", 0)), int(budget.get("rallongeMax", 0))]

## Confirmation (motif W1 : libellé = action, focus par défaut sur Annuler) puis envoi de la commande.
## `on_sent` est appelé si la commande part (la réponse arrive ensuite par le modèle).
static func confirm_extension(app: Control, parent: Node, budget: Dictionary, amount: int, on_sent: Callable) -> ConfirmationDialog:
	var confirm := ConfirmationDialog.new()
	confirm.name = "TransferBudgetExtensionConfirm"
	confirm.title = "Rallonge du budget de transferts"
	confirm.dialog_text = extension_question(budget, amount)
	confirm.get_ok_button().text = extension_button(amount).to_upper()
	confirm.get_cancel_button().text = "ANNULER"
	confirm.confirmed.connect(func():
		if not app.waiting and app._command(EXTENSION_COMMAND, {"amount": amount, "confirmed": true}): on_sent.call()
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	# Une fenêtre mère masquée (adoptée par une sous-page du Recrutement) ne montrerait pas sa fille : l'application l'accueille.
	var host: Node = app if parent is Window and not (parent as Window).visible else parent
	host.add_child(confirm)
	confirm.popup_centered(Vector2i(640, 230))
	confirm.get_cancel_button().grab_focus()
	return confirm

## Réponse du conseil lue dans la réponse du moteur (meta.transferBudgetExtension), ou l’erreur de la commande.
static func extension_answer(app: Control) -> String:
	if not app.bridge.last_response_ok: return "Demande non transmise : " + str(app.last_error)
	var answer: Variant = app.model.get("meta", {}).get("transferBudgetExtension")
	return str(answer.get("message", "")) if answer is Dictionary else ""
