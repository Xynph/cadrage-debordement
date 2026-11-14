extends SceneTree

var failures := 0

func check(condition: bool, description: String) -> void:
	if condition: return
	failures += 1
	printerr(description)

func _initialize() -> void:
	var progression = load("res://ui/career_progression.gd")
	if progression == null:
		quit(1)
		return
	var fixture := {"date": "2026-09-05"}
	var date := "2026-09-04"
	var meta := {"calendarToday": date, "calendarCadence": {"matchReady": false, "canAdvance": true}}
	check(progression.daily({}, fixture, "Bureau").is_empty(), "Le parcours hebdomadaire n’est pas modifié.")
	var advance: Dictionary = progression.daily(meta, fixture, "Bureau")
	check(advance.get("command") == "advance_until_event" and advance.get("payload") == {"fromDate": date} and advance.get("short") == "Continuer", "Le bouton principal est « Continuer » jusqu’au prochain événement, depuis la date affichée.")
	var single: Dictionary = progression.next_day(meta, fixture)
	check(single.get("command") == "advance_day" and single.get("payload") == {"fromDate": date}, "« Jour suivant » reste disponible : un seul pas.")
	var preseason := {"calendarToday": "2026-07-13", "calendarCadence": {"matchReady": false, "canAdvance": true, "preseason": true}}
	check(progression.daily(preseason, null, "Bureau").get("command") == "advance_until_event", "L’avant-saison avance aussi jusqu’au prochain événement (plus de « + 7 jours »).")
	check(progression.continue_stops({}) == {"messages": "importants", "blessures": "titulaires"}, "Arrêts par défaut : messages importants, blessures des titulaires.")
	check(progression.continue_stops({"continue_messages": "aucun", "continue_injuries": "effectif"}) == {"messages": "aucun", "blessures": "effectif"}, "Réglages d’arrêt du joueur transmis au moteur.")
	check(progression.continue_stops({"continue_messages": "x"}).messages == "importants", "Réglage inconnu : valeur par défaut.")
	check(not progression.kickoff_allowed(meta), "Le coup d’envoi est fermé avant le jour du match.")
	meta.calendarCadence = {"matchReady": true, "canAdvance": false}
	check(progression.daily(meta, fixture, "Bureau").get("route") == "Préparation", "Le jour du match ouvre la préparation depuis le Bureau.")
	check(progression.daily(meta, fixture, "Préparation").get("route") == "Match", "La préparation mène au match le jour prévu.")
	check(progression.next_day(meta, fixture).is_empty(), "Le jour du match, « Jour suivant » ne saute pas la rencontre.")
	check(progression.kickoff_allowed(meta), "Le coup d’envoi est ouvert le jour prévu.")
	meta.calendarCadence.resultConfirmed = true
	meta.calendarCadence.canAdvance = true
	check(progression.daily(meta, fixture, "Match").get("command") == "advance_until_event", "La confirmation du résultat permet d’avancer sans rejouer la rencontre.")
	check(not progression.kickoff_allowed(meta), "Le résultat confirmé ferme le coup d’envoi.")
	meta.calendarCadence = {"matchReady": false, "canAdvance": false}
	check(progression.daily(meta, null, "Match").get("disabled") == true, "Une avance refusée par le moteur reste inactive.")
	check(progression.press_required({"clubLife": {"press": {"conference": {"required": true}}}}), "Une obligation presse est détectée depuis la Réception.")
	check(not progression.press_required({}), "Une ancienne projection reste lisible.")
	if failures == 0: print("Parcours quotidien Godot · 17 contrôles réussis")
	quit(failures)
