extends SceneTree
## Recette de l'écran Effectif du socle des menus, dans le vrai jeu et avec le
## vrai moteur : tri, groupes, filtres, recherche, clavier, souris, vues, charge
## de 3 000 lignes, ouverture de la fiche. Aucune dépendance à un fichier d'aide.
var app: Control
var sortie := OS.get_environment("CD_SOCLE_OUTPUT")
var taille := OS.get_environment("CD_SOCLE_SIZE")
var echecs: Array[String] = []
var controles := 0
var mesures: Dictionary = {}

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 6) -> void:
	for i in images: await process_frame

func attendre_moteur() -> void:
	var limite := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(10)

func capture(nom: String) -> void:
	await poser(8)
	if DisplayServer.get_name() == "headless": return
	verifier(root.get_texture().get_image().save_png(sortie.path_join("%s-%s.png" % [nom, taille])) == OK, "capture " + nom)

func souris(point: Vector2, bouton := MOUSE_BUTTON_LEFT, double := false) -> void:
	var mouvement := InputEventMouseMotion.new()
	mouvement.position = point; mouvement.global_position = point
	root.push_input(mouvement, true); await process_frame
	for bas: bool in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.position = point; clic.global_position = point; clic.button_index = bouton; clic.pressed = bas; clic.double_click = double and bas
		root.push_input(clic, true); await process_frame
	await poser()

func touche(code: Key) -> void:
	for bas: bool in [true, false]:
		var evenement := InputEventKey.new()
		evenement.keycode = code; evenement.physical_keycode = code; evenement.pressed = bas
		root.push_input(evenement, true); await process_frame
	await poser(3)

func executer() -> void:
	var dimensions := taille.split("x")
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	app._command("new_career", {"mode": "common", "club": 29}); await attendre_moteur(); app.timer.stop()
	app._navigate("Effectif"); await poser(20)
	var ecran: Control = app.find_child("SocleEffectif", true, false)
	verifier(ecran != null, "l'écran du socle remplace l'ancien quand il est activé")
	if ecran != null: await parcours(ecran)
	var rapport := {"taille": taille, "affichage": DisplayServer.get_name(), "controles": controles, "failures": echecs, "mesures": mesures}
	var fichier := FileAccess.open(sortie.path_join("report-%s.json" % taille), FileAccess.WRITE)
	fichier.store_string(JSON.stringify(rapport, "\t")); fichier.close()
	print("SOCLE_EFFECTIF ", JSON.stringify(rapport))
	quit(0 if echecs.is_empty() else 1)

func parcours(ecran: Control) -> void:
	var t: Control = ecran.tableau
	var J = load("res://ui/socle/jetons.gd")
	var total: int = app.model.squad.size()
	var avant := JSON.stringify(app.model.squad)
	var profil_avant := FileAccess.get_md5(OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json"))
	mesures["colonnes"] = t.colonnes_affichees()
	mesures["echelle"] = J.echelle
	verifier(t.lignes_visibles().size() == total and total > 24, "tous les joueurs sont dans le tableau")
	verifier(J.px(J.T_CORPS) >= 12, "texte courant d'au moins 12 pixels à cette taille")
	verifier(t.colonnes_affichees().has("joueur") and t.colonnes_affichees().has("niveau"), "Joueur et Niveau restent visibles à cette taille")
	verifier(ecran.get_global_rect().end.y <= root.size.y and ecran.get_global_rect().end.x <= root.size.x, "l'écran tient dans la fenêtre")
	var ordre: Array = t.lignes_visibles()
	var feuille := func(j: Dictionary) -> int: return {"Titulaire": 0, "Remplaçant": 1}.get(str(j.get("status", "")), 2)
	var bien_range := true
	for i in range(1, ordre.size()):
		if int(ordre[i].fam) == int(ordre[i - 1].fam) and feuille.call(ordre[i]) < feuille.call(ordre[i - 1]): bien_range = false
	verifier(bien_range, "ordre par défaut : titulaires, puis remplaçants, puis le reste, dans chaque ligne")
	await capture("socle-effectif")

	# Tri par clic sur l'en-tête Niveau.
	var origine := t.get_global_rect().position
	var place: Dictionary = t._places.filter(func(p: Dictionary): return p.colonne.id == "niveau")[0]
	await souris(origine + Vector2(place.x + 20, 10))
	verifier(t.tri_colonne == "niveau" and t.tri_decroissant, "un clic sur Niveau classe du meilleur au moins bon")
	mesures["tri_40_ms"] = t.duree_dernier_tri_ms()
	var piliers: Array = t.lignes_visibles().filter(func(j: Dictionary): return int(j.fam) == 0).map(func(j: Dictionary): return int(j.rating))
	var attendus := piliers.duplicate(); attendus.sort(); attendus.reverse()
	verifier(piliers == attendus, "les piliers sont classés par niveau dans leur ligne")
	await souris(origine + Vector2(place.x + 20, 10))
	verifier(t.tri_colonne == "niveau" and not t.tri_decroissant, "un second clic inverse le sens")
	await souris(origine + Vector2(place.x + 20, 10))
	await capture("socle-tri-niveau")

	# Sans groupes.
	var grouper: Button = ecran.find_child("GrouperParLigne", true, false)
	grouper.pressed.emit(); await poser()
	var tous: Array = t.lignes_visibles().map(func(j: Dictionary): return int(j.rating))
	attendus = tous.duplicate(); attendus.sort(); attendus.reverse()
	verifier(tous == attendus, "sans groupes, tout l'effectif est classé par niveau")
	await capture("socle-sans-groupes")
	grouper.pressed.emit(); await poser()

	# Filtres et recherche.
	ecran.find_child("Filtre_fin", true, false).pressed.emit(); await poser()
	var saison := int(app.model.meta.get("season", 1))
	verifier(t.lignes_visibles().size() > 0 and t.lignes_visibles().all(func(j: Dictionary): return int(j.contractEnd) <= saison), "filtre des contrats qui finissent cette saison")
	ecran.find_child("Filtre_avants", true, false).pressed.emit(); await poser()
	verifier(t.lignes_visibles().size() > 0 and t.lignes_visibles().all(func(j: Dictionary): return int(j.fam) <= 3), "filtre des avants")
	ecran.find_child("Filtre_tous", true, false).pressed.emit(); await poser()
	var champ: LineEdit = ecran.find_child("RechercheEffectif", true, false)
	champ.text = "deuxieme"; champ.text_changed.emit("deuxieme"); await poser()
	verifier(t.lignes_visibles().size() > 0 and t.lignes_visibles().all(func(j: Dictionary): return int(j.fam) == 2), "recherche sans accent : « deuxieme » trouve les deuxièmes lignes")
	champ.text = "zzzz"; champ.text_changed.emit("zzzz"); await poser()
	verifier(t.lignes_visibles().is_empty(), "recherche sans résultat : liste vide et message")
	await capture("socle-recherche-vide")
	champ.text = ""; champ.text_changed.emit(""); await poser()
	verifier(t.lignes_visibles().size() == total, "recherche effacée : tout l'effectif revient")

	# Souris : clic sur une ligne, molette.
	t.trier("", false); await poser()
	var premiere_ligne := origine + Vector2(120, J.px(J.ENTETE_H) + J.px(J.GROUPE_H) + J.px(J.LIGNE_H) * 1.5)
	await souris(premiere_ligne)
	verifier(app.selected_player == str(t.lignes_visibles()[1].id), "un clic sélectionne la ligne sous le pointeur")
	verifier(ecran.find_child("CarteJoueur", true, false) != null, "la fiche de droite suit la sélection")
	await souris(premiere_ligne, MOUSE_BUTTON_WHEEL_DOWN)
	verifier(t._defilement > 0, "la molette fait défiler la liste")
	await souris(premiere_ligne, MOUSE_BUTTON_WHEEL_UP)

	# Clavier.
	t.grab_focus(); await poser(2)
	await touche(KEY_HOME)
	verifier(app.selected_player == str(t.lignes_visibles()[0].id) and t._defilement == 0, "Début : premier joueur, titre de sa ligne visible")
	await touche(KEY_DOWN); await touche(KEY_DOWN)
	verifier(app.selected_player == str(t.lignes_visibles()[2].id), "Bas, Bas : troisième joueur")
	await touche(KEY_END)
	verifier(app.selected_player == str(t.lignes_visibles()[total - 1].id) and t._defilement > 0, "Fin : dernier joueur, amené à l'écran")
	await capture("socle-clavier-fin")

	# Vues.
	for i in [1, 2, 3]:
		ecran.find_child("Vue_%d" % i, true, false).pressed.emit(); await poser()
		verifier(t.lignes_visibles().size() == total, "vue %d : tout l'effectif" % i)
		await touche(KEY_HOME)
		await capture("socle-vue-%d" % i)
	ecran.find_child("Vue_0", true, false).pressed.emit(); await poser()

	# Rien n'a été demandé au moteur, rien n'a changé.
	verifier(JSON.stringify(app.model.squad) == avant, "données du moteur intactes")
	verifier(not app.waiting, "aucune commande en attente")
	verifier(FileAccess.get_md5(OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")) == profil_avant, "profil de carrière inchangé sur le disque")

	# Charge : 3 000 lignes dans le même tableau.
	var gros: Array = []
	for k in 75:
		for j: Dictionary in app.model.squad:
			var copie := j.duplicate(); copie.id = "%s#%d" % [j.id, k]; gros.append(copie)
	t.definir_lignes(gros)
	var debut := Time.get_ticks_usec()
	t.trier("salaire", true)
	mesures["tri_3000_total_ms"] = (Time.get_ticks_usec() - debut) / 1000.0
	mesures["tri_3000_calcul_ms"] = t.duree_dernier_tri_ms()
	verifier(t.lignes_visibles().size() == gros.size(), "3 000 lignes acceptées")
	verifier(t._vignettes.size() < 200, "seules les lignes visibles ont un portrait instancié")
	verifier(t.duree_dernier_tri_ms() < 100.0, "tri de 3 000 lignes calculé en moins de 100 ms (%.1f)" % t.duree_dernier_tri_ms())
	var salaires: Array = t.lignes_visibles().slice(0, 200).map(func(j: Dictionary): return float(j.salary))
	attendus = salaires.duplicate(); attendus.sort(); attendus.reverse()
	verifier(salaires == attendus, "tri décroissant exact sur 3 000 lignes")
	t.trier("", false); t.definir_lignes(ecran._joueurs_ordonnes()); await poser()

	# Entrée ouvre la fiche complète existante.
	await touche(KEY_HOME)
	t.grab_focus(); await touche(KEY_ENTER); await poser(12)
	verifier(app.get_meta("immersive08_full_player", false) and app.find_child("SocleEffectif", true, false) == null, "Entrée ouvre la fiche complète du joueur")
	await capture("socle-fiche-complete")
