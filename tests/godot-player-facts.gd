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
	print("Fiche joueur · drapeaux distincts, mensurations et caps vérifiés")
	quit()
