extends RefCounted

const G = preload("res://ui/carnet_skin.gd")

static func data(app: Control) -> Dictionary:
	return app.model.get("selection", {}).get("coverage", {})

static func caption(quote: Dictionary) -> String:
	var places := int(quote.places)
	if places == 0 or places < quote.slots.size():
		var capacity := "Effectif complet" if places == 0 else "%d/%d places libres" % [places, quote.slots.size()]
		if quote.get("reviewAfterTraining", false):
			return capacity + " · Revoir après entraînement"
		return "Renforts · " + capacity.to_lower()
	return "Renforts · +%s/sem." % G.euros(quote.totalWeeklySalary)

static func configure(button: Button, quote: Dictionary) -> void:
	button.disabled = int(quote.places) < quote.slots.size()
	button.tooltip_text = "Le groupe professionnel compte trop peu de places libres." if button.disabled else "Voir les places et les salaires avant de signer."

static func confirm(app: Control, quote: Dictionary) -> void:
	var slots: Array = quote.slots.duplicate()
	var count := slots.size()
	var players := "un nouvel Espoir" if count == 1 else "%d nouveaux Espoirs" % count
	var numbers := ", ".join(slots.map(func(slot): return str(int(slot))))
	var places := "la place %s" % numbers if count == 1 else "les places %s" % numbers
	var detail := "Le club signera %s pour %s de la feuille.\n\n" % [players, places]
	detail += "Salaires supplémentaires de %s par semaine, soit %s par joueur." % [
		G.euros(quote.totalWeeklySalary), G.euros(quote.weeklySalary)
	]
	if quote.get("reviewAfterTraining", false):
		detail += "\n\nUn retour de blessure pourrait réduire le besoin. Si vous prévoyez une séance, revérifiez la feuille ensuite avant de signer."
	app.confirm("Renforts d’urgence", detail, func(): app._command("promote_cover", {"confirmed": true, "expectedSlots": slots}), true)
