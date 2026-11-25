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

## Rien n'est annoncé avant la demande (ni coût en confiance, ni risque) : seulement le montant, ou la date de réouverture
## après un refus (le président ne veut plus en entendre parler avant).
static func extension_closed(budget: Dictionary) -> String:
	return str(budget.get("rallongeBloqueLabel", "")) if budget.get("rallongeBloqueJusqu") != null else ""

static func extension_button(amount: int, budget: Dictionary = {}) -> String:
	var ferme := extension_closed(budget)
	if ferme != "": return "Conseil fermé jusqu’au %s" % ferme
	return "Demander %s au conseil" % G.euros(amount)

## Un clic envoie la demande (décision de Léo : clic direct, sans confirmation). `on_sent` est appelé si la commande part ;
## la réponse arrive ensuite par le modèle et s'affiche dans la page.
static func send_extension(app: Control, amount: int, on_sent: Callable) -> void:
	if app.waiting or amount <= 0: return
	if app._command(EXTENSION_COMMAND, {"amount": amount, "confirmed": true}): on_sent.call()

## Réponse du conseil lue dans la réponse du moteur (meta.transferBudgetExtension), ou l’erreur de la commande.
static func extension_answer(app: Control) -> String:
	if not app.bridge.last_response_ok: return "Demande non transmise : " + str(app.last_error)
	var answer: Variant = app.model.get("meta", {}).get("transferBudgetExtension")
	return str(answer.get("message", "")) if answer is Dictionary else ""
