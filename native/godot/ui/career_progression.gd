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
	return {"command": "advance_day", "payload": {"fromDate": today}, "label": "JOUR SUIVANT  →", "short": "Jour suivant"}
