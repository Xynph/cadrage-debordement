extends RefCounted
## Présentation et sélection de la commande native pendant une semaine sans match.

static func is_japan(meta: Dictionary) -> bool:
	return meta.get("leagueId") in ["jlo-d1", "jlo-d2"]

static func data(meta: Dictionary) -> Dictionary:
	return meta.get("japanPreparation", {}) if is_japan(meta) else meta.get("pacificPreparation", {})

static func command(meta: Dictionary) -> String:
	return "advance_japan_preparation" if is_japan(meta) else "advance_pacific_preparation"

static func ground(meta: Dictionary, fallback: String) -> String:
	if is_japan(meta): return "japan-ground"
	if meta.get("leagueId") == "srp": return "pacific-ground"
	return fallback
