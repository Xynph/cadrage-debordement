extends RefCounted
## Budget de transferts fixé par le conseil (docs/gdd/budget-transferts.md), lu dans `finance.transferBudget`.
## Affichage seul : le moteur refuse les offres hors budget (devis indisponible + raison).
const G = preload("res://ui/game_skin.gd")
const LABEL := "Disponible pour les transferts"

## Budget actif du club joué, ou {} (carrière sans budget de saison : on garde la trésorerie).
static func data(model: Dictionary) -> Dictionary:
	var finance: Variant = model.get("finance")
	if not finance is Dictionary: return {}
	var budget: Variant = finance.get("transferBudget")
	if not budget is Dictionary or not bool(budget.get("actif", false)): return {}
	return budget

static func remaining(budget: Dictionary) -> String:
	return G.euros(budget.get("disponible", 0))

static func allocated(budget: Dictionary) -> String:
	return "sur %s alloués par le conseil" % G.euros(budget.get("enveloppe", 0))

static func movements(budget: Dictionary) -> String:
	return "Dépensé %s · reconstitué %s" % [G.euros(budget.get("depense", 0)), G.euros(budget.get("reconstitue", 0))]

static func detail(budget: Dictionary, cash: Variant) -> String:
	return "\n".join(PackedStringArray([
		"Enveloppe de la saison : %s" % G.euros(budget.get("enveloppe", 0)),
		"Trésorerie du club : %s" % (G.euros(cash) if cash is int or cash is float else "—"),
		"Dépensé en indemnités et primes : %s" % G.euros(budget.get("depense", 0)),
		"Reconstitué par les ventes : %s" % G.euros(budget.get("reconstitue", 0)),
		"Les salaires n’entrent pas dans ce budget : ils sont jugés par la masse salariale.",
	]))
