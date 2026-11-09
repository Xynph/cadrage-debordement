extends RefCounted
## Présentation et sélection de la commande native pendant une semaine sans match.

static func is_japan(meta: Dictionary) -> bool:
	return meta.get("leagueId") in ["jlo-d1", "jlo-d2"]

static func is_champ(meta: Dictionary) -> bool:
	return meta.get("leagueId") == "champ"

static func _kind(meta: Dictionary) -> String:
	if is_japan(meta): return "japan"
	if is_champ(meta): return "champ"
	return "pacific"

static func data(meta: Dictionary) -> Dictionary:
	return meta.get(_kind(meta) + "Preparation", {})

static func command(meta: Dictionary) -> String:
	return "advance_" + _kind(meta) + "_preparation"

static func ground(meta: Dictionary, fallback: String) -> String:
	if is_japan(meta): return "japan-ground"
	if is_champ(meta): return "champ-ground"
	if meta.get("leagueId") == "srp": return "pacific-ground"
	return fallback
