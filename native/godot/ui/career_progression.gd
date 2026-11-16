extends RefCounted

static func press_required(model: Dictionary) -> bool:
	return bool(model.get("clubLife", {}).get("press", {}).get("conference", {}).get("required", false))

static func kickoff_allowed(meta: Dictionary) -> bool:
	var cadence: Dictionary = meta.get("calendarCadence", {})
	return cadence.is_empty() or (bool(cadence.get("matchReady", false)) and not bool(cadence.get("resultConfirmed", false)))

static func daily(meta: Dictionary, fixture: Variant, route: String) -> Dictionary:
	var cadence: Dictionary = meta.get("calendarCadence", {})
	if cadence.is_empty(): return {}
	if kickoff_allowed(meta) and fixture is Dictionary:
		if route == "Préparation":
			return {"route": "Match", "label": "ALLER AU MATCH  →", "short": "Jour de match"}
		return {"route": "Préparation", "label": "PRÉPARER LE MATCH  →", "short": "Préparer"}
	# « Doit répondre » (façon FM) : une décision de la préparation attend ; le bouton change de libellé et ouvre
	# « La reprise » au lieu d'avancer (reprise.cjs, meta.decisionsDue).
	var due: Array = meta.get("decisionsDue", []) if meta.get("decisionsDue") is Array else []
	if not due.is_empty():
		return {"open": "reprise", "label": "DÉCISION ATTENDUE  →", "short": "Décision attendue", "tooltip": "Décision attendue : Gabi attend votre réponse dans « La reprise » avant de continuer."}
	var today := str(meta.get("calendarToday", ""))
	if today.is_empty() or not bool(cadence.get("canAdvance", false)):
		return {"disabled": true, "label": str(cadence.get("reason", "L’avance est indisponible.")), "short": "Continuer"}
	# « Continuer » (façon Football Manager) : le moteur avance jour après jour jusqu'au prochain événement
	# (match, rendez-vous, presse, courrier, blessure…), avant-saison comprise ; voir native/engine/continuer.cjs.
	return {"command": CONTINUE_COMMAND, "payload": {"fromDate": today}, "label": "CONTINUER  →", "short": "Continuer", "tooltip": continue_tooltip(meta)}

const WEEKDAYS := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]

## Info-bulle de « Continuer » : le prochain arrêt prévisible annoncé par le moteur (meta.continuePlan :
## rencontre du club, reprise de l'entraînement, rendez-vous en file) et ce qui peut arrêter l'avance plus tôt.
static func continue_tooltip(meta: Dictionary) -> String:
	var lines: Array[String] = ["Continuer jusqu’au prochain événement."]
	var plan: Variant = meta.get("continuePlan")
	var today := str(meta.get("calendarToday", ""))
	if plan is Dictionary and not str(plan.get("date", "")).is_empty():
		var date := str(plan.date)
		var what := ""
		match str(plan.get("kind", "")):
			"match": what = "Match contre " + str(plan.get("opponent", "l’adversaire")) if not str(plan.get("opponent", "")).is_empty() else "Jour de match"
			"reprise": what = "Reprise de l’entraînement"
			"decision": what = "Décision attendue : " + str(plan.get("detail", "")).to_lower()
			"a_noter": what = "À noter : " + str(plan.get("detail", ""))
			"info":
				var info := str(plan.get("detail", ""))
				what = info.left(1).to_upper() + info.substr(1)
			_: what = str(plan.get("detail", "Rendez-vous du club"))
		lines.append("Prochain arrêt prévu : %s, %s%s." % [what, short_date(date), in_days(today, date)])
	lines.append("Arrêt plus tôt si un rendez-vous, un courrier important, une offre ou la blessure d’un titulaire l’exige.")
	lines.append("Jour suivant : un seul jour (Ctrl+J).")
	return "\n".join(lines)

## « sam. 19/09 » depuis une date ISO.
static func short_date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3: return iso
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	var weekday := int(Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0))
	return "%s %s/%s" % [WEEKDAYS[weekday], parts[2], parts[1]]

## « (dans 5 jours) », « (demain) » ou rien.
static func in_days(today: String, date: String) -> String:
	if today.is_empty() or date.is_empty(): return ""
	var days := int(round((Time.get_unix_time_from_datetime_string(date + "T12:00:00") - Time.get_unix_time_from_datetime_string(today + "T12:00:00")) / 86400.0))
	if days <= 0: return " (aujourd’hui)"
	if days == 1: return " (demain)"
	return " (dans %d jours)" % days

const CONTINUE_COMMAND := "advance_until_event"

## « Jour suivant » reste accessible (petit bouton du bandeau, Ctrl+J) : un seul jour, jamais un match sauté.
static func next_day(meta: Dictionary, fixture: Variant) -> Dictionary:
	var step := daily(meta, fixture, "")
	if not step.has("command"): return {}
	return {"command": "advance_day", "payload": {"fromDate": str(meta.get("calendarToday", ""))}, "label": "JOUR SUIVANT  →", "short": "Jour suivant"}

## Réglages d'arrêt de « Continuer » transmis au moteur (préférences du joueur).
static func continue_stops(preferences: Dictionary) -> Dictionary:
	var messages := str(preferences.get("continue_messages", "importants"))
	var blessures := str(preferences.get("continue_injuries", "titulaires"))
	return {"messages": messages if messages in ["importants", "tous", "aucun"] else "importants", "blessures": blessures if blessures in ["titulaires", "effectif"] else "titulaires"}

## Sauvegarde complète due entre `last` et `now` (AAAA-MM-JJ) pour la fréquence des Réglages : même règle que
## `due` dans native/engine/action-journal.cjs (jour : date changée ; semaine : autre lundi ; mois : autre mois).
static func autosave_due(policy: String, last: String, now: String) -> bool:
	if last.length() != 10 or now.length() != 10: return false
	match policy:
		"jour": return now != last
		"mois": return now.substr(0, 7) != last.substr(0, 7)
	return shift_day(now, -weekday_from_monday(now)) != shift_day(last, -weekday_from_monday(last))

## Date ISO décalée de `days` jours (UTC, midi : aucun effet d'heure d'été).
static func shift_day(iso: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00") + days * 86400
	return Time.get_date_string_from_unix_time(unix)

## Rang du jour dans la semaine, lundi = 0.
static func weekday_from_monday(iso: String) -> int:
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	return (int(Time.get_datetime_dict_from_unix_time(unix).weekday) + 6) % 7
