extends SceneTree
## Tour des écrans filmé (tools/ecrans-filmes/visite.gd) : lecture des arguments et des tailles, liste et
## filtre des écrans, nommage des fichiers, débordements et textes tronqués, planche. Sans rendu : vérifie
## la logique de l'outil (et qu'il se compile) en --headless.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func ids(liste: Array) -> Array:
	return liste.map(func(e: Dictionary): return str(e.id))

func run() -> void:
	var outil = load(ProjectSettings.globalize_path("res://").path_join("../../tools/ecrans-filmes/visite.gd"))
	if outil == null:
		check(false, "Outil chargé")
		print("ECRANS_FILMES_CHECKS ", JSON.stringify({"failures": failures}))
		quit(1)
		return
	# Nommage : minuscules, sans accents, tirets.
	check(outil.slug("Réception") == "reception", "Réception → reception : " + outil.slug("Réception"))
	check(outil.slug("Plan de jeu") == "plan-de-jeu", "Plan de jeu → plan-de-jeu")
	check(outil.slug("Stratégie") == "strategie" and outil.slug("Rivalités") == "rivalites" and outil.slug("Sélections") == "selections", "Accents retirés")
	check(outil.slug("  Fenêtre Équipe · consignes ") == "fenetre-equipe-consignes", "Majuscules accentuées et ponctuation : " + outil.slug("  Fenêtre Équipe · consignes "))
	check(outil.nom_fichier("plan-de-jeu", 1920) == "plan-de-jeu-1920.png" and outil.nom_planche(1280) == "planche-1280.png", "Noms des images et des planches")
	check(outil.nom_fichier("bureau", 1920, 1080) == "bureau-1920.png" and outil.nom_fichier("bureau", 1366, 768) == "bureau-1366.png" and outil.nom_fichier("bureau", 2560, 1080) == "bureau-2560x1080.png" and outil.nom_planche(2560, 1440) == "planche-2560.png" and outil.nom_planche(2560, 1080) == "planche-2560x1080.png", "Tailles de même largeur (2560 × 1440 et 2560 × 1080) sans écrasement")

	# Tailles.
	var tailles: Dictionary = outil.lire_tailles("1920x1080, 1280X720,1920x1080")
	check(tailles.erreurs.is_empty() and tailles.tailles == [Vector2i(1920, 1080), Vector2i(1280, 720)], "Tailles lues, doublon retiré : " + str(tailles))
	check(outil.lire_tailles("640x360").erreurs.size() == 1 and outil.lire_tailles("grand").erreurs.size() == 1 and not outil.lire_tailles("").erreurs.is_empty(), "Tailles trop petites, illisibles ou absentes refusées")

	# Arguments.
	var sortie := "C:/ecrans" if OS.get_name() == "Windows" else "/tmp/ecrans"
	var carriere := sortie.path_join("carriere.json")
	var lu: Dictionary = outil.lire_options(PackedStringArray(["--ecrans-filmes", "--sortie", sortie, "--export", carriere, "--tailles", "1600x900", "--ecrans", "bureau, Plan de jeu,,equipe", "--duree-max", "120", "--sans-planche", "--sans-direct"]))
	check(lu.erreurs.is_empty(), "Arguments complets acceptés : " + str(lu.erreurs))
	check(lu.options.tailles == [Vector2i(1600, 900)] and lu.options.ecrans == ["bureau", "Plan de jeu", "equipe"] and lu.options.duree_max == 120.0, "Tailles, écrans et durée lus : " + str(lu.options))
	check(lu.options.planche == false and lu.options.direct == false, "Planche et direct désactivables")
	var defauts: Dictionary = outil.lire_options(PackedStringArray(["--sortie", sortie, "--export", carriere])).options
	check(defauts.tailles == [Vector2i(1920, 1080), Vector2i(1280, 720)] and defauts.ecrans.is_empty() and defauts.planche and defauts.direct and defauts.duree_max == 900.0, "Défauts : 1920x1080 et 1280x720, tous les écrans, planche, direct, 900 s")
	var mauvais: Dictionary = outil.lire_options(PackedStringArray(["--tailles", "640x360", "--duree-max", "5", "--inconnu", "--sortie", "relatif"]))
	check(mauvais.erreurs.size() >= 5, "Taille, durée, argument inconnu, sortie relative et export absent refusés : " + str(mauvais.erreurs))
	check(not outil.lire_options(PackedStringArray(["--sortie"])).erreurs.is_empty(), "Valeur manquante refusée")

	# Liste des écrans : celle de tests/small-window-geometry.gd, puis compléments, hors carrière, direct.
	var texte := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/small-window-geometry.gd"))
	var routes: Array = outil.routes_depuis_texte(texte)
	check(routes == outil.ROUTES_GEOMETRIE, "Copie des ROUTES identique à tests/small-window-geometry.gd : " + str(routes))
	check(outil.routes_depuis_texte("const AUTRE = 1").is_empty(), "Texte sans ROUTES : liste vide")
	var liste: Array = outil.liste_ecrans(outil.ROUTES_GEOMETRIE)
	var noms := ids(liste)
	check(liste.size() == outil.ROUTES_GEOMETRIE.size() + outil.EXTRAS.size() + outil.EN_DIRECT.size(), "Tous les écrans listés : " + str(liste.size()))
	var uniques := {}
	for nom in noms: uniques[nom] = true
	check(uniques.size() == noms.size(), "Noms de fichiers uniques")
	check(noms[0] == "reception" and noms[-1] == "apres-match" and noms.slice(-4) == ["direct", "equipe-composition", "equipe-consignes", "apres-match"], "Réception d'abord, le direct à la fin, l'après-match en dernier")
	check(noms.find("options") < noms.find("accueil") and noms.find("packs") < noms.find("direct") and noms.find("selections") < noms.find("fiche-joueur"), "Compléments après la gestion, hors carrière avant le direct")
	for attendu in ["fiche-joueur", "fiche-club", "calendrier-semaine", "calendrier", "classements", "recrutement", "presse", "options"]:
		check(attendu in noms, "Écran couvert : " + attendu)

	# Filtre : nom de fichier, nom de l'écran, alias ; inconnus signalés.
	var choix: Dictionary = outil.filtrer(liste, ["Plan de jeu", "transferts", "Équipe", "classement", "FICHE-JOUEUR", "vestiare"])
	check(ids(choix.ecrans) == ["plan-de-jeu", "recrutement", "classements", "fiche-joueur", "equipe-composition", "equipe-consignes"], "Écrans filtrés dans l'ordre de visite : " + str(ids(choix.ecrans)))
	check(choix.inconnus == ["vestiare"], "Écran inconnu signalé : " + str(choix.inconnus))
	check(outil.filtrer(liste, []).ecrans.size() == liste.size(), "Sans filtre : tous les écrans")

	# Débordements et textes tronqués.
	var vue := Rect2(0, 0, 1280, 720)
	check(outil.depassement(Rect2(1200, 700, 100, 40), vue) == [0.0, 0.0, 20.0, 20.0], "Dépassement à droite et en bas")
	check(outil.depassement(Rect2(10, 10, 100, 40), vue) == [0.0, 0.0, 0.0, 0.0], "Contrôle dans l'écran")
	var etiquette := Label.new()
	etiquette.text = "Un libellé beaucoup trop long pour la place qui lui est donnée"
	etiquette.clip_text = true
	etiquette.size = Vector2(40, 24)
	root.add_child(etiquette)
	check(outil.texte_tronque(etiquette), "Libellé coupé détecté")
	etiquette.size = Vector2(2400, 24)
	check(not outil.texte_tronque(etiquette), "Libellé à l'aise non signalé")
	etiquette.clip_text = false
	etiquette.size = Vector2(40, 24)
	check(not outil.texte_tronque(etiquette), "Libellé sans coupe ni « … » non signalé (il s'agrandit)")
	var bouton := Button.new()
	bouton.text = "Valider et reprendre le match tout de suite"
	bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bouton.clip_text = true
	bouton.size = Vector2(60, 30)
	root.add_child(bouton)
	check(outil.texte_tronque(bouton), "Bouton à texte coupé détecté")
	etiquette.queue_free()
	bouton.queue_free()

	# Images : noire, vignette, planche.
	var noire := Image.create_empty(320, 180, false, Image.FORMAT_RGB8)
	check(outil.luminance(noire) < outil.SEUIL_NOIR, "Image noire détectée")
	var claire := Image.create_empty(1920, 1080, false, Image.FORMAT_RGBA8)
	claire.fill(Color(0.8, 0.75, 0.6))
	var petite: Image = outil.vignette(claire, 384)
	check(petite.get_size() == Vector2i(384, 216) and petite.get_format() == Image.FORMAT_RGB8, "Vignette 384×216 en RGB : " + str(petite.get_size()))
	var feuille: Image = outil.planche([petite, petite, petite, petite, petite, petite, petite], 5)
	check(feuille != null and feuille.get_size() == Vector2i(6 + 5 * 390, 6 + 2 * 222), "Planche de 5 colonnes sur 2 lignes : " + (str(feuille.get_size()) if feuille != null else "aucune"))
	check(outil.planche([], 5) == null, "Planche vide refusée")
	for k in 2: await process_frame
	print("ECRANS_FILMES_CHECKS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
