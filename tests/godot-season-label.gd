extends SceneTree
# Libellé de saison côté Godot : même formule que libelleSaison() du moteur (dist/season-label.js).
const G = preload("res://ui/game_skin.gd")
const C = preload("res://ui/carnet_skin.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ", message)

func _initialize() -> void:
	SeasonLabel.start_year = 2026
	check(G.season_label(1) == "2026-2027", "saison interne 1 → 2026-2027")
	check(G.season_label(2) == "2027-2028", "saison interne 2 → 2027-2028")
	check(G.season_label(5.0) == "2030-2031", "nombre entier flottant accepté")
	check(C.season_label(1) == "2026-2027", "carnet_skin relaie le même libellé")
	for bad in [0, -1, 1.5, null, "", "x", "—"]:
		check(G.season_label(bad) == "—", "valeur invalide → tiret : " + str(bad))
	SeasonLabel.start_year = 2030
	check(G.season_label(1) == "2030-2031", "l'année de départ vient du modèle")
	SeasonLabel.start_year = 2026
	print("season-label.gd : %d échec(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)
