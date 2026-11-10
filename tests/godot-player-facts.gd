extends SceneTree

func _initialize() -> void:
	var facts = load("res://ui/player_identity.gd")
	if facts == null:
		quit(1)
		return
	var example := {"nationality":"Australie", "flagCode":"au", "seniorNationName":"France", "seniorFlagCode":"fr", "seniorCaps":22, "heightCm":189, "weightKg":108}
	var parts: Array = facts.identity_parts(example)
	if parts.size() != 3 or parts[0].flag != "au" or parts[2].flag != "fr" or parts[2].text != "France · 22 sélections XV":
		printerr(str(parts))
		quit(1)
		return
	var unknown: Array = facts.identity_parts({"nationality":"Irlande", "flagCode":"ie", "seniorCaps":0})
	if unknown.size() != 2 or unknown[1].text != "0 sélections XV":
		printerr(str(unknown))
		quit(1)
		return
	example.nationalitySource = "simulated"
	example.dimensionsSource = "estimated"
	var visible: Control = facts.row(example, 20, Color.WHITE)
	var origin := visible.get_node("PlayerOriginFact") as Label
	var dimensions := visible.get_node("PlayerDimensionsFact") as Label
	var uniform := origin.text == "Australie" and origin.tooltip_text.is_empty() and dimensions.text == "189 cm · 108 kg" and dimensions.tooltip_text.is_empty()
	visible.free()
	if not uniform:
		printerr("Les données affichées doivent avoir la même présentation quelle que soit leur origine.")
		quit(1)
		return
	print("Fiche joueur · drapeaux distincts, mensurations et caps vérifiés")
	quit()
