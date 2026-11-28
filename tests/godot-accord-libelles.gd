extends SceneTree
## Accord en nombre des libellés (ui/accord.gd) : « (s) » et « (nt) » suivent le dernier nombre du segment.
const Accord = preload("res://ui/accord.gd")
const G = preload("res://ui/game_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func egal(obtenu: String, attendu: String) -> void:
	checks += 1
	if obtenu != attendu: failures.append("%s ≠ %s" % [obtenu, attendu]); printerr("FAIL: « %s » au lieu de « %s »" % [obtenu, attendu])
func run() -> void:
	egal(Accord.texte("1 saison(s)"), "1 saison")
	egal(Accord.texte("0 semaine(s) d’indisponibilité"), "0 semaine d’indisponibilité")
	egal(Accord.texte("3 saison(s) · 1 besoin(s) compatible(s)"), "3 saisons · 1 besoin compatible")
	egal(Accord.texte("1,5 saison(s)"), "1,5 saison")
	egal(Accord.texte("Tu gardes 4 jeune(s) et tu en libères 1."), "Tu gardes 4 jeunes et tu en libères 1.")
	egal(Accord.texte("2 contrat(s) expire(nt)"), "2 contrats expirent")
	egal(Accord.texte("1 contrat(s) expire(nt)"), "1 contrat expire")
	egal(Accord.texte("Montée(s) vers la Pro D2"), "Montées vers la Pro D2")
	egal(Accord.texte("Sans marque"), "Sans marque")
	egal(G.label("1 an(s)").text, "1 an")
	egal(C.label("2 jour(s)").text, "2 jours")
	print("godot-accord-libelles : %d vérifications, %d échec(s)" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
