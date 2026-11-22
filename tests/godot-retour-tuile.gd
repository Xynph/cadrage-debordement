extends SceneTree
## Retour visuel commun des tuiles (choix de Léo, option A : éclaircissement + liseré du club au survol, plus clair et
## filet sombre à l'appui, 80 ms) et rayures « une ligne sur deux » alignées sur l'Effectif (ui/survol_ligne.gd).
## Scène nue, sans carrière : on construit des boutons et des lignes et on lit ce que les composants communs décident.
const RetourTuile = preload("res://ui/retour_tuile.gd")
const SurvolLigne = preload("res://ui/survol_ligne.gd")
const Charte = preload("res://ui/charte.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func plat(cadre: Control, taille: Vector2, texte: String = "") -> Button:
	var b := Button.new()
	b.flat = true
	b.text = texte
	b.custom_minimum_size = taille
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	cadre.add_child(b)
	b.size = taille
	return b

func boite(couleur: Color, rayon: int, bord: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = couleur
	s.set_corner_radius_all(rayon)
	s.set_border_width_all(bord)
	return s

func run() -> void:
	# La variante B n'existe plus : la variable d'environnement ne change rien.
	OS.set_environment("CD_VARIANTE_VISUELLE", "B")
	var cadre := Control.new()
	cadre.size = Vector2(1920, 1080)
	root.add_child(cadre)
	await process_frame

	# Branchement explicite : un seul calque, pas d'ombre, survol puis appui.
	var tuile := plat(cadre, Vector2(220, 120))
	var retour = RetourTuile.brancher(tuile, tuile, 12.0)
	check(retour != null and tuile.has_node(RetourTuile.NOM), "le retour est posé sur la tuile")
	check(RetourTuile.brancher(tuile, tuile, 12.0) == retour, "brancher est idempotent")
	var source := FileAccess.get_file_as_string("res://ui/retour_tuile.gd")
	check(not source.contains("ECHELLE_B") and not source.contains("RetourTuileOmbre") and not source.contains("CD_VARIANTE_VISUELLE"), "variante B retirée (ni ombre ni soulèvement ni variable)")
	check(RetourTuile.DUREE == 0.08, "transition de 80 ms")
	retour.forcer(1.0, 0.0)
	check(retour.survol == 1.0 and retour.appui == 0.0, "survol forcé")
	retour.forcer(1.0, 1.0)
	check(retour.appui == 1.0, "appui forcé")
	check(tuile.get_theme_stylebox("hover") == tuile.get_theme_stylebox("normal"), "le bouton ne dessine plus de survol propre")

	# Classement automatique des boutons.
	check(RetourTuile.classer(plat(cadre, Vector2(220, 120))) == "tuile", "zone plate sur une carte = tuile")
	check(RetourTuile.classer(plat(cadre, Vector2(120, 40), "Voir")) == "", "lien de texte = pas de retour")
	check(RetourTuile.classer(plat(cadre, Vector2(1000, 36))) == "ligne", "zone plate très large = ligne")
	check(RetourTuile.classer(plat(cadre, Vector2(18, 18))) == "", "zone minuscule = pas de retour")
	check(RetourTuile.classer(plat(cadre, Vector2(1800, 900))) == "", "voile plein écran = pas de retour")
	var pastille := Button.new()
	pastille.text = "Tous 19"
	pastille.add_theme_stylebox_override("normal", boite(Color(0, 0, 0, 0), 99, 1))
	cadre.add_child(pastille)
	pastille.size = Vector2(110, 32)
	check(RetourTuile.classer(pastille) == "pastille", "pastille à contour = pastille")
	var dore := Button.new()
	dore.text = "Continuer"
	dore.add_theme_stylebox_override("normal", boite(Charte.OR, 99))
	cadre.add_child(dore)
	dore.size = Vector2(200, 44)
	check(RetourTuile.classer(dore) == "", "bouton doré : pas de retour (un seul aplat doré par écran)")
	var inactif := plat(cadre, Vector2(220, 120))
	inactif.disabled = true
	check(RetourTuile.classer(inactif) == "", "bouton désactivé : pas de retour")
	var neutre := plat(cadre, Vector2(220, 120))
	neutre.set_meta("sans_retour", true)
	check(RetourTuile.classer(neutre) == "", "écran qui s'en retire : pas de retour")

	# Premier survol : le retour se pose tout seul sur un bouton créé après l'installation.
	RetourTuile.installer(cadre)
	var tardif := plat(cadre, Vector2(200, 100))
	await process_frame
	tardif.mouse_entered.emit()
	check(tardif.has_node(RetourTuile.NOM), "le premier survol branche le retour")

	# Zone non bouton (carte qui écoute la souris elle-même).
	var carte := PanelContainer.new()
	carte.custom_minimum_size = Vector2(240, 90)
	cadre.add_child(carte)
	carte.size = Vector2(240, 90)
	carte.mouse_filter = Control.MOUSE_FILTER_STOP
	carte.gui_input.connect(func(_e: InputEvent): pass)
	check(RetourTuile.zone_cliquable(carte), "carte qui écoute la souris détectée")
	check(RetourTuile.habiller_zone(carte) != null and carte.has_node(RetourTuile.NOM), "retour posé sur la carte")

	# Rayures : une ligne sur deux (rang impair), même crème que l'Effectif.
	var liste := Control.new()
	cadre.add_child(liste)
	check(SurvolLigne.rayure(liste, 0) == null, "ligne 1 : fond de base")
	var rayure := SurvolLigne.rayure(liste, 1)
	check(rayure != null and rayure.get_theme_stylebox("panel") is StyleBoxFlat and (rayure.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == SurvolLigne.RAYURE, "ligne 2 : rayure de l'Effectif")
	check(SurvolLigne.rayure(liste, 2) == null and SurvolLigne.rayure(liste, 3) != null, "une sur deux")
	var rangs := Control.new()
	cadre.add_child(rangs)
	var lignes: Array = []
	for i in 4:
		var l := plat(rangs, Vector2(500, 36))
		lignes.append(SurvolLigne.appliquer(l))
	var ordre: Array = []
	for fond in lignes: ordre.append(fond.rang())
	check(ordre == [0, 1, 2, 3], "rang des lignes boutons : " + str(ordre))
	lignes[2].rang_fixe = 5
	check(lignes[2].rang() == 5, "rang imposé par l'écran")
	# Ligne de cellules (conteneur) : le fond couvre les marges intérieures du panneau.
	var rangee := PanelContainer.new()
	var style := boite(Color(0, 0, 0, 0), 0)
	style.content_margin_left = 8
	style.content_margin_right = 10
	rangee.add_theme_stylebox_override("panel", style)
	cadre.add_child(rangee)
	rangee.size = Vector2(400, 30)
	var fond_rangee = SurvolLigne.poser(rangee)
	check(fond_rangee.get_parent() == rangee and rangee.get_child(0) == fond_rangee, "fond posé derrière les cellules")
	check(rangee.mouse_filter == Control.MOUSE_FILTER_PASS, "la ligne reçoit la souris sans bloquer ses enfants")
	await process_frame
	check(fond_rangee._cadre().size.x >= rangee.size.x - 0.5, "le fond couvre toute la ligne (marges comprises)")
	# Jamais de vert de sélection : la ligne choisie n'est pas colorée.
	var choisie = SurvolLigne.appliquer(plat(rangs, Vector2(500, 36)), true)
	check(choisie.choisi and not choisie.survole, "ligne choisie : mémorisée, jamais dessinée en vert")
	var bilan := "RETOUR_TUILE checks=%d failures=%d" % [checks, failures.size()]
	print(bilan)
	quit(0 if failures.is_empty() else 1)
