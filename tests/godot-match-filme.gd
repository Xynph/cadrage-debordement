extends SceneTree
## Match filmé (tools/match-filme/match_filme.gd) : lecture des arguments, détection des images
## noires, répartition et planche-contact. Sans rendu : vérifie la logique de l'outil en --headless.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func run() -> void:
	var outil = load(ProjectSettings.globalize_path("res://").path_join("../../tools/match-filme/match_filme.gd"))
	if outil == null:
		check(false, "Outil chargé")
		print("MATCH_FILME_CHECKS ", JSON.stringify({"failures": failures}))
		quit(1)
		return
	var sortie := "C:/film" if OS.get_name() == "Windows" else "/tmp/film"
	var carriere := sortie.path_join("carriere.json")
	var lu: Dictionary = outil.lire_options(PackedStringArray(["--match-filme", "--sortie", sortie, "--export", carriere, "--camera", "action", "--cadence", "1.5", "--duree-max", "120", "--minutes", "12", "--niveau", "integral", "--taille", "1600x900", "--sans-planche"]))
	check(lu.erreurs.is_empty(), "Arguments complets acceptés : " + str(lu.erreurs))
	check(lu.options.camera == "action" and is_equal_approx(lu.options.cadence, 1.5) and lu.options.duree_max == 120.0 and lu.options.minutes == 12, "Caméra, cadence, durée et minute lues")
	check(lu.options.niveau == "integral" and lu.options.taille == Vector2i(1600, 900) and lu.options.planche == false, "Niveau, taille et planche lus")
	var defauts: Dictionary = outil.lire_options(PackedStringArray(["--sortie", sortie, "--export", carriere])).options
	check(defauts.camera == "tv" and defauts.niveau == "dynamique" and defauts.minutes == 0 and defauts.planche, "Défauts : caméra TV, réglage du jeu, match entier, planche")
	var mauvais: Dictionary = outil.lire_options(PackedStringArray(["--camera", "drone", "--cadence", "0", "--taille", "640x360", "--minutes", "-3", "--inconnu", "--sortie", "relatif"]))
	check(mauvais.erreurs.size() >= 6, "Caméra, cadence, taille, minute, argument inconnu, sortie relative et export absent refusés : " + str(mauvais.erreurs))
	check(not outil.lire_options(PackedStringArray(["--sortie"])).erreurs.is_empty(), "Valeur manquante refusée")
	# Grands moments : cadence rapprochée (essai, sortie des joueurs à la mi-temps et en fin de match).
	check(is_equal_approx(defauts.cadence_moments, 0.5), "Défaut : une image toutes les 0,5 s pendant un grand moment")
	var moments: Dictionary = outil.lire_options(PackedStringArray(["--sortie", sortie, "--export", carriere, "--cadence-moments", "0.25"]))
	check(moments.erreurs.is_empty() and is_equal_approx(moments.options.cadence_moments, 0.25), "--cadence-moments lu : " + str(moments.erreurs))
	check(not outil.lire_options(PackedStringArray(["--sortie", sortie, "--export", carriere, "--cadence-moments", "0.1"])).erreurs.is_empty(), "--cadence-moments trop court refusé")
	check(outil.ETATS.size() == 4 and outil.ETATS[3] == "sortie", "État « sortie » de la régie nommé dans le rapport")
	var faux := GDScript.new()
	faux.source_code = "extends Node\nvar etat := 1\nvar index := 0\nvar tf := {\"plans\": [{\"kind\": \"try\"}, {\"kind\": \"transformation\"}]}\nvar _live := {}\nvar en_sortie := false\nvar titre := \"\"\nfunc sortie_en_cours() -> bool:\n\treturn en_sortie\nfunc bandeau_affiche() -> Dictionary:\n\treturn {\"visible\": not titre.is_empty(), \"titre\": titre}\n"
	check(faux.reload() == OK, "Régie factice")
	var regie: Node = faux.new()
	check(outil.moment_de(null) == "", "Sans régie : aucun moment")
	check(outil.moment_de(regie) == "essai", "Plan d'essai en cours : moment « essai »")
	regie.index = 1
	check(outil.moment_de(regie) == "", "Transformation sans bandeau : plus de moment")
	regie.titre = "ESSAI"
	check(outil.moment_de(regie) == "essai", "Bandeau « ESSAI » encore affiché : moment « essai »")
	regie.titre = "MI-TEMPS"
	regie.en_sortie = true
	check(outil.moment_de(regie) == "mi-temps", "Sortie à la mi-temps")
	regie._live = {"finished": true}
	check(outil.moment_de(regie) == "fin", "Sortie en fin de match")
	regie.free()

	var noire := Image.create_empty(320, 180, false, Image.FORMAT_RGB8)
	check(outil.luminance(noire) < outil.SEUIL_NOIR, "Image noire détectée")
	var pelouse := Image.create_empty(320, 180, false, Image.FORMAT_RGB8)
	pelouse.fill(Color(0.2, 0.55, 0.25))
	check(outil.luminance(pelouse) > 0.3, "Image de pelouse non noire")

	check(outil.repartir(5, 24) == [0, 1, 2, 3, 4], "Peu d'images : toutes gardées")
	var gardees: Array = outil.repartir(100, 24)
	check(gardees.size() == 24 and gardees[0] == 0 and gardees[-1] == 99, "Planche répartie du début à la fin")
	var feuille: Image = outil.planche([pelouse, noire, pelouse, pelouse, noire], 4, 200)
	check(feuille != null and feuille.get_width() == 6 + 4 * 206 and feuille.get_height() == 6 + 2 * (113 + 6), "Planche de 4 colonnes sur 2 lignes : " + (str(feuille.get_size()) if feuille != null else "aucune"))
	check(outil.planche([], 4, 200) == null, "Planche vide refusée")
	print("MATCH_FILME_CHECKS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
