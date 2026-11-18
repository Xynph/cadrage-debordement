extends SceneTree
## Bandeau du score et bouton de pause du direct (film du 18 novembre 2026, vue TV 1280×720) :
## - pendant l'action 3D, la grande barre (≈ 20 % de l'image) devient un bloc compact (horloge,
##   sigles, score) ; elle revient aux arrêts de jeu, à la pause, à la mi-temps et à la fin ;
## - le bouton dit « PAUSE » tant que le match joue à l'écran, « REPRENDRE » seulement en pause,
##   y compris quand le moteur a déjà atteint la mi-temps pendant la dernière action (40+2′) ;
## - la ligne météo écrit « Temps sec » au lieu d'un « Sec » incompréhensible.
## Fonctions sans nœud de ui/contextual/live_view.gd et meteo_texte.gd ; le flux réel (régie,
## temps fort joué puis mis en pause) est contrôlé dans godot-match-temps-forts.gd.
const LiveView = preload("res://ui/contextual/live_view.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func etat(live: Dictionary, regie_active: bool, action: bool, figee: bool, attente: bool = false) -> Dictionary:
	return LiveView.etat_bandeau(live, regie_active, action, figee, attente)

func run() -> void:
	var jeu := {"minute": 23, "paused": false}
	var pause := {"minute": 23, "paused": true}
	var mi_temps := {"minute": 40, "paused": true, "atBreak": true}
	var fin := {"minute": 80, "paused": true, "finished": true}

	# Temps forts : action 3D en cours.
	var e := etat(jeu, true, true, false)
	check(e.compact and e.pause == "PAUSE" and e.pause_possible, "Action 3D : bandeau compact, bouton PAUSE actif " + str(e))
	# Constat du film : 40+2′, le moteur a atteint la mi-temps (il est arrêté) mais l'action se joue encore.
	e = etat(mi_temps, true, true, false)
	check(e.pause == "PAUSE", "40+2′, dernière action à l'écran : PAUSE, jamais REPRENDRE " + str(e))
	check(e.compact, "40+2′, dernière action à l'écran : bandeau compact " + str(e))
	check(not e.pause_possible, "40+2′ : rien à mettre en pause, l'action se termine puis la mi-temps " + str(e))
	# Match repris d'une sauvegarde en pause : le temps fort se joue quand même.
	e = etat(pause, true, true, false)
	check(e.pause == "PAUSE" and e.compact and not e.pause_possible, "Temps fort joué sur un moteur déjà en pause : PAUSE, compact " + str(e))
	# Pause du manager pendant l'action : image figée.
	e = etat(pause, true, true, true)
	check(e.pause == "REPRENDRE" and not e.compact and e.pause_possible, "Action figée par la pause : REPRENDRE, grande barre " + str(e))
	# Entre deux temps forts (terrain 2D) : arrêt de jeu, grande barre.
	e = etat(jeu, true, false, false)
	check(e.pause == "PAUSE" and not e.compact, "Entracte, match qui joue : PAUSE, grande barre " + str(e))
	e = etat(pause, true, false, false)
	check(e.pause == "REPRENDRE" and not e.compact and e.pause_possible, "Entracte en pause : REPRENDRE " + str(e))
	# 3D restée à l'écran entre deux temps forts contigus : le bandeau ne bat pas.
	e = etat(jeu, true, false, false, true)
	check(e.compact and e.pause == "PAUSE", "Attente entre deux temps forts contigus : compact " + str(e))
	e = etat(pause, true, false, false, true)
	check(not e.compact and e.pause == "REPRENDRE", "Attente en pause : grande barre, REPRENDRE " + str(e))
	# Mi-temps et fin : grande barre.
	e = etat(mi_temps, true, false, false)
	check(not e.compact and e.pause == "REPRENDRE", "Mi-temps (sortie des joueurs) : grande barre " + str(e))
	e = etat(fin, true, false, false)
	check(not e.compact and not e.pause_possible, "Fin du match : grande barre, bouton inactif " + str(e))
	e = etat(fin, true, true, false)
	check(not e.compact and not e.pause_possible, "Fin du match même pendant la dernière action : bouton inactif " + str(e))
	# Direct sans régie (repli) : la 3D joue tant que le moteur joue.
	e = etat(jeu, false, false, false)
	check(e.compact and e.pause == "PAUSE" and e.pause_possible, "Repli, match qui joue : compact, PAUSE " + str(e))
	e = etat(pause, false, false, false)
	check(not e.compact and e.pause == "REPRENDRE" and e.pause_possible, "Repli en pause : grande barre, REPRENDRE " + str(e))
	e = etat(mi_temps, false, false, false)
	check(not e.compact and e.pause == "REPRENDRE", "Repli à la mi-temps : grande barre " + str(e))
	e = etat({}, false, false, false)
	check(not e.compact, "Sans direct : grande barre " + str(e))
	# Bloc compact plus petit que la grande barre, à toutes les tailles.
	for cle in ["horloge", "score", "pause"]:
		check(int(LiveView.BANDEAU_COMPACT[cle]) < int(LiveView.BANDEAU_TAILLES[cle]), "Bloc compact plus petit : " + cle)

	# Météo : libellé clair sous le score et dans l'avant-match.
	var sec := {"minute": 12, "meteo": {"libelle": "sec", "pluie": 0, "vent": 0, "chaleur": 0}}
	check(Meteo.libelle(sec) == "Temps sec", "Libellé météo clair : « %s »" % Meteo.libelle(sec))
	check(Meteo.bandeau(sec) == "Temps sec", "Ligne sous le score : « %s »" % Meteo.bandeau(sec))
	check(Meteo.libelle({"weather": "Sec"}) == "Temps sec", "Ancien champ weather « Sec » écrit en clair")
	check(Meteo.libelle({"meteo": {"libelle": "forte pluie, terrain lourd"}}) == "Forte pluie, terrain lourd", "Autres libellés inchangés")
	check(Meteo.avant_match({"meteo": {"libelle": "sec", "date": "2026-11-18"}}, "2026-11-18").ciel == "Temps sec", "Avant-match : ciel « Temps sec »")
	var source := FileAccess.get_file_as_string("res://ui/immersive08/match_avant.gd")
	check(not source.contains("else \"Sec\""), "Tuile météo de l'avant-match : plus de « Sec » seul")

	print("MATCH_BANDEAU_COMPACT %d controles, %d echec" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
