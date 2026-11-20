extends SceneTree
# Noms de compétition lus dans les données (identités d'un pack), jamais figés dans l'interface.
# Données entièrement fictives.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ", message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var World = load("res://ui/immersive08/world_archive.gd")
	var Memory = load("res://ui/club_memory_view.gd")
	var Palmares = load("res://ui/immersive08/palmares_text.gd")
	var model := {"meta": {"competitionIdentities": {
		"elite": {"name": "Ligue des Volcans"}, "accession": {"name": "Coupe des Brumes"},
		"nationale": {"name": "Trophée des Landes"}, "prem": {"name": "Grande Ligue du Nord"}, "champ": {"name": "Ligue des Collines"},
	}}}
	# Montées et descentes : la division d'arrivée vient des identités.
	check(World.movement_lines(model, "accession", true, false) == ["Montée en Ligue des Volcans"], "montée vers l'élite du pack")
	check(World.movement_lines(model, "elite", false, true) == ["Descente en Coupe des Brumes"], "descente vers l'accession du pack")
	check(World.movement_lines(model, "champ", true, false) == ["Montée en Grande Ligue du Nord"], "montée d'une autre ligue du pack")
	check(World.movement_lines(model, "prem", false, true) == ["Descente en Ligue des Collines"], "descente d'une autre ligue du pack")
	check(World.movement_lines(model, "inconnue", true, true) == ["Montée en division supérieure", "Descente en division inférieure"], "division inconnue : rien d'inventé")
	check(World.movement_lines(model, "elite", false, false).is_empty(), "aucun mouvement : aucune ligne")
	# Histoire du club : rang, titres et mouvements avec les noms du pack.
	var year := {"season": 2, "league_id": "prem", "rank": 3, "division_size": 10, "titles": ["prem"], "promoted": false, "relegated": true}
	var rank: String = Memory._rank(model, year)
	check(rank.contains("Grande Ligue du Nord") and rank.contains("3 / 10"), "rang dans la ligue du pack : " + rank)
	check(Memory._titles(model, year) == "Champion Grande Ligue du Nord", "titre avec le nom du pack")
	check(Memory._movement(model, year) == "Descente en Ligue des Collines", "descente avec le nom du pack")
	# Palmarès : le nom du pack est affiché tel quel.
	check(Palmares.competition(model, "elite") == "Ligue des Volcans", "palmarès : nom du pack inchangé")
	print("noms-lus-donnees.gd : %d échec(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)
