extends RefCounted
## Published facts only. Opening a briefing never sends a sporting command.
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")

static func _check(id: String, title: String, detail: String, action: String, caption: String, level: String = "info") -> Dictionary:
	return {"id":id,"title":title,"detail":detail,"action":action,"caption":caption,"level":level}

static func project(model: Dictionary) -> Dictionary:
	var result: Array[Dictionary] = []
	var meta: Dictionary = model.get("meta", {})
	var live: Dictionary = model.get("live") if model.get("live") is Dictionary else {}
	var fixture: Dictionary = model.get("next") if model.get("next") is Dictionary else {}
	var report: Dictionary = model.get("decisions", {}).get("preparation", {}) if model.get("decisions", {}).get("preparation") is Dictionary else {}
	var ended: bool = meta.get("phase") == "ended"
	if not live.is_empty():
		result.append(_check("live", "Résultat à consulter" if live.get("finished", false) else "Le match est en cours", "Reprends la rencontre pour retrouver le score et les décisions du direct.", "match", "Retour au match", "important"))
	if ended and live.is_empty():
		result.append(_check("ended", "La saison est clôturée", "Les décisions de préparation reprendront avec la prochaine saison.", "calendar", "Consulter le calendrier"))
	elif live.is_empty():
		var press: Dictionary = model.get("clubLife", {}).get("press", {}).get("conference", {})
		if press.get("required", false):
			result.append(_check("press", "Répondre à la presse", "La conférence obligatoire doit être reçue avant de poursuivre la journée.", "press", "Ouvrir l’invitation", "urgent"))
		var selection: Dictionary = model.get("selection", {})
		if not fixture.is_empty() and not selection.get("valid", false):
			var reasons: Array = selection.get("errors", [])
			result.append(_check("selection", "Compléter la feuille", str(reasons[0]) if not reasons.is_empty() else "Vérifie les postes et le banc dans la composition.", "selection", "Vérifier la composition", "urgent"))
		if not fixture.is_empty() and meta.get("calendarCadence", {}).get("matchReady", false):
			result.append(_check("day", "C’est le jour du match", "Le calendrier autorise la préparation du coup d’envoi aujourd’hui.", "match", "Ouvrir le jour de match", "important"))
		var availability: Dictionary = model.get("international", {}).get("availability", {})
		var absent := int(availability.get("absentCount", 0))
		if availability.get("clubManaged", false) and absent > 0:
			var detail := "%d joueur%s convoqué%s. Vérifie les postes exposés." % [absent, "s" if absent > 1 else "", "s" if absent > 1 else ""]
			if availability.get("nextReturn") is String: detail += " Premier retour prévu : " + P.fixture_date({"date":availability.nextReturn}) + "."
			result.append(_check("international", "Absences internationales", detail, "international", "Voir les joueurs et retours", "important"))
		var injured: Array = model.get("squad", []).filter(func(player: Dictionary): return float(player.get("injury", 0)) > 0)
		if not injured.is_empty():
			result.append(_check("injuries", "%d joueur%s blessé%s" % [injured.size(), "s" if injured.size() > 1 else "", "s" if injured.size() > 1 else ""], "Consulte les indisponibilités et les solutions de remplacement dans ton effectif.", "squad", "Ouvrir l’effectif", "important"))
		if not fixture.is_empty() and selection.get("valid", false):
			result.append(_check("sheet", "Feuille projetée valide", "La feuille est valide. Vérifie les titulaires, le banc et les choix individuels.", "selection", "Consulter la composition"))
		if not fixture.is_empty():
			var when := P.fixture_date(fixture, true)
			result.append(_check("calendar", "Vérifier le rendez-vous", when if not when.is_empty() else "Date non publiée : consulte le calendrier de la carrière.", "calendar", "Ouvrir le calendrier"))
		result.append(_check("tactics", "Vérifier les consignes", "Attaque et défense dans Consignes ; choix par zone dans le carnet de jeu.", "consignes", "Revoir les consignes"))
	return {"checks":result,"reportAvailable":not report.is_empty(),"domains":report.get("domains", []).size(),"recent":report.get("recent", []).size(),"threats":report.get("threats", []).size()}

static func open_action(app: Control, action: String, consignes: Callable) -> void:
	match action:
		"press": app._show_press_inbox()
		"selection": app._navigate("Composition")
		"international":
			app.management_ui.international_section = "availability"
			app._navigate("Sélections")
		"squad": app.navigation_controller.open_roster_group()
		"match": app._navigate("Match")
		"calendar": app._navigate("Calendrier")
		"consignes": consignes.call()

static func color(check: Dictionary) -> Color:
	return C.ALERT if check.level == "urgent" else C.GOLD if check.level == "important" else C.MINT
