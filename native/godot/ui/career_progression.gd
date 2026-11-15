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
	var today := str(meta.get("calendarToday", ""))
	if today.is_empty() or not bool(cadence.get("canAdvance", false)):
		return {"disabled": true, "label": str(cadence.get("reason", "L’avance est indisponible.")), "short": "Continuer"}
	# « Continuer » (façon Football Manager) : le moteur avance jour après jour jusqu'au prochain événement
	# (match, rendez-vous, presse, courrier, blessure…), avant-saison comprise ; voir native/engine/continuer.cjs.
	return {"command": CONTINUE_COMMAND, "payload": {"fromDate": today}, "label": "CONTINUER  →", "short": "Continuer"}

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
