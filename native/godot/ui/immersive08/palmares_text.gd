extends RefCounted
# Textes du palmarès d'un club (projection moteur `club-palmares.cjs`) : aucun nom réel, les noms
# de compétitions viennent de l'identité du jeu ; état vide en langage de club.
const Club = preload("res://ui/club_views.gd")

const HISTORICAL := {
	"eng-third": "Troisième division anglaise", "jlo-d3": "Troisième division japonaise",
	"jp-top-league": "Ancienne élite japonaise", "jp-company": "Championnat national des entreprises",
	"jp-national": "Championnat national du Japon", "jp-top-challenge": "Ancienne deuxième division japonaise",
	"sr-au": "Championnat australien 2020–21", "sr-nz": "Championnat néo-zélandais 2020–21",
	"sr-trans-tasman": "Championnat trans-tasman 2021",
}

static func competition(model: Dictionary, id: String) -> String:
	if HISTORICAL.has(id): return str(HISTORICAL[id])
	var label := Club.competition_name(id, model)
	return label

static func titles_text(model: Dictionary, palmares: Dictionary, limit: int = 3) -> String:
	var parts: Array[String] = []
	for title: Dictionary in palmares.get("titles", []):
		if parts.size() >= limit: break
		var count := int(title.get("count", 0))
		parts.append("%s · %d titre%s" % [competition(model, str(title.get("competition", ""))), count, "s" if count > 1 else ""])
	return "  ·  ".join(parts)

## Lignes « 2025-26 · <nom de la compétition> · Finaliste », les plus récentes d'abord.
static func recent_lines(model: Dictionary, palmares: Dictionary, limit: int = 8) -> Array[String]:
	var lines: Array[String] = []
	for row: Dictionary in palmares.get("recent", []):
		if lines.size() >= limit: break
		lines.append("%s · %s · %s" % [str(row.get("season", "")), competition(model, str(row.get("competition", ""))), str(row.get("text", ""))])
	return lines

## Chiffre affiché à côté d'un intitulé : jamais « 0 » sec, un tiret quand il n'y a rien.
static func count_text(value: int) -> String:
	return str(value) if value > 0 else "—"
