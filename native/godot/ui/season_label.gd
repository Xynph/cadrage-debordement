extends RefCounted
# Libellé de saison affiché : « 2026-2027 » pour la saison interne 1, « 2027-2028 » pour la 2.
# Même formule que libelleSaison() du moteur (dist/storage.js) ; l'année de départ vient du
# modèle (meta.seasonStartYear). Le numéro interne `season` reste dans les données.
static var start_year := 2026

static func label(season: Variant) -> String:
	if not (season is int or season is float) or not is_finite(float(season)) or float(season) != floorf(float(season)) or season < 1 or season > 7973: return "—"
	return "%d-%d" % [start_year + int(season) - 1, start_year + int(season)]
