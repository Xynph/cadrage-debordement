extends SceneTree
## Panneaux latéraux de l'Effectif (21/11/2026) : colonne XV / SEMAINE / GROUPE à gauche du tableau, chaque panneau
## repliable, rail d'icônes quand tout est replié (le tableau reprend sa largeur), état mémorisé dans les préférences.
## Chaque élément est cliqué pour de vrai : n° du XV -> fiche, terrain et flèche -> Composition, jours et charges ->
## Entraînement, jauges -> Vestiaire, tensions -> petite fenêtre (portraits des joueurs du moteur), fermée par Échap.
## Entraînement : programme jour par jour du moteur ; Vestiaire : confiance des joueurs et tensions.
## CD_PANNEAUX_CAPTURES=<dossier> (+ CD_PANNEAUX_TAILLE=LxH) : enregistre développé, replié et fenêtre des tensions.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Panneaux = preload("res://ui/immersive08/panneaux_effectif.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_PANNEAUX_CAPTURES")
var taille := Vector2i(1920, 1080)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func settle(frames := 8) -> void:
	for frame in frames: await process_frame
func wait_worker(limit_ms := 240000) -> void:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
func found(id: String) -> Control: return app.find_child(id, true, false) as Control
func click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new(); move.position = point; move.global_position = point
	Input.parse_input_event(move); await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down; event.position = point; event.global_position = point
		Input.parse_input_event(event); await process_frame
	await settle()
func click_id(id: String) -> bool:
	var control := found(id)
	check(control != null and control.is_visible_in_tree(), "Présent et visible · " + id)
	if control == null: return false
	await click(control.get_global_rect().get_center())
	return true
func escape() -> void:
	var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true; root.push_input(key, true)
	key = key.duplicate(); key.pressed = false; root.push_input(key, true)
	await settle()
func effectif() -> void:
	app._clear_dialogs()
	app._navigate("Effectif")
	await settle(12)
func prefs() -> Dictionary:
	return app.user_preferences.data.get("panneaux_effectif", {})
func capture(nom: String) -> void:
	if captures.is_empty(): return
	if is_instance_valid(app.coach): app.coach.close()
	await appliquer_taille()
	await settle(20)
	await create_timer(0.6).timeout
	if is_instance_valid(app.coach):
		if app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
		app.coach.close()
	await settle(6)
	await create_timer(1.2).timeout
	var image := root.get_texture().get_image()
	if image != null: image.save_png(captures.path_join("%s-%d.png" % [nom, taille.x]))

func appliquer_taille() -> void:
	if captures.is_empty() or Vector2i(root.get_texture().get_size()) == taille: return
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.borderless = true
	root.size = taille
	DisplayServer.window_set_size(taille)
	await create_timer(0.5).timeout
	print("PANNEAUX taille rendue ", root.get_texture().get_size())

## Maillot du terrain XV -> liste classée par note au poste (note du moteur, sur 100) + familiarité, maillot marqué,
## titre du poste ; badge « Jeune » -> Formation ; nom du titulaire -> sa fiche ; ✕ -> retour au tri par poste.
func etoiles_au_poste(xv: Dictionary) -> void:
	const Etoiles = preload("res://ui/immersive08/liste_etoiles.gd")
	var numero := 10 if xv.has(10) else (int(xv.keys()[0]) if not xv.is_empty() else 0)
	if numero == 0 or not await click_id("PanneauJoueur_%d" % numero): return
	check(app.route == "Effectif" and found("CarnetSquad") != null, "N° %d : on reste sur l'Effectif" % numero)
	check(int(app.management_ui.roster.get("etoiles_poste", 0)) == numero and str(app.management_ui.roster.sort) == "Note au poste", "N° %d -> tri par note au poste" % numero)
	check(found("PanneauChoisi_%d" % numero) != null, "Maillot %d marqué sur le terrain" % numero)
	var titre: Label = found("EtoilesTitrePoste") as Label
	check(titre != null and titre.text.contains(Etoiles.nom_poste(numero).to_upper()), "Titre du poste au-dessus de la liste")
	var effacer: Control = found("EtoilesEffacer")
	check(effacer != null and not effacer.tooltip_text.to_lower().contains("toile") and not titre.text.contains("★"), "Plus aucune étoile de poste (titre, ✕)")
	# Niveaux du moteur (positionFamiliarityLevels, indice 0 = maillot 1) prioritaires sur la déduction ; repli sinon.
	var lu := {"primaryPositions": [10], "positionFamiliarityLevels": [0, 0, 0, 1, 1, 1, 1, 1, 2, 3, 2, 4, 2, 2, 2]}
	check(Familiarite.niveau(lu, 12) == Familiarite.NATUREL and Familiarite.niveau(lu, 10) == Familiarite.CONFIRME, "Familiarité lue dans le moteur")
	check(Familiarite.niveau({"primaryPositions": [10], "positionFamiliarityLevels": [1, 2]}, 10) == Familiarite.NATUREL, "Tableau du moteur incomplet : repli sur les postes")
	var lignes: Array = found("ImmersiveRosterRows").get_children().filter(func(n: Node): return n is Button and n.has_meta("player_id"))
	var notes: Array = []
	var par_id := {}
	for p: Dictionary in app.model.squad: par_id[str(p.id)] = p
	for ligne: Button in lignes: notes.append(Etoiles.note_poste(par_id.get(str(ligne.get_meta("player_id")), {}), numero))
	var connues: Array = notes.filter(func(v: float): return v >= 0.0)
	var meilleure := -1.0
	for p: Dictionary in app.model.squad: meilleure = maxf(meilleure, Etoiles.note_poste(p, numero))
	var classe := true
	for i in range(1, connues.size()): classe = classe and connues[i - 1] >= connues[i]
	# Note au poste (sur 100, la même pour tous les clubs) : la meilleure du groupe en tête de liste.
	check(connues.size() >= 10 and classe and is_equal_approx(float(connues[0]), meilleure), "Liste classée par note au poste décroissante (%s)" % str(connues.slice(0, 6)))
	var premiere: Control = lignes[0] if not lignes.is_empty() else null
	var note: Label = premiere.find_child("RosterNotePoste", true, false) as Label if premiere != null else null
	check(note != null and note.text == str(int(roundf(float(connues[0])))), "Note au poste écrite sur la ligne (%s)" % (note.text if note != null else "—"))
	var marque: Control = premiere.find_child("RosterFamiliarite*", true, false) as Control if premiere != null else null
	var attendu_f := Familiarite.niveau(par_id.get(str(premiere.get_meta("player_id")), {}), numero) if premiere != null else -1
	check(marque != null and (attendu_f < 0 or int(marque.get_meta("familiarite", -2)) == attendu_f or (marque.get_parent() != null and int(marque.get_parent().get_meta("familiarite", -2)) == attendu_f)), "Familiarité au poste sur la ligne (%s)" % Familiarite.mot(attendu_f))
	var niveaux := {}
	for p: Dictionary in app.model.squad: niveaux[Familiarite.niveau(p, numero)] = true
	check(niveaux.size() >= 3, "Plusieurs niveaux de familiarité dans le groupe (%s)" % str(niveaux.keys()))
	var naturels: int = app.model.squad.filter(func(p: Dictionary): return Familiarite.niveau(p, numero) == Familiarite.NATUREL).size()
	var compte: Control = found("FamiliariteCompte_%d" % Familiarite.NATUREL)
	check(compte != null, "Nombre de joueurs Naturels au poste près du titre (%d)" % naturels)
	# Badge « Jeune » (21 ans et moins) derrière le nom -> Formation.
	var jeune: Control = found("RosterBadgeOuvrir_Jeune")
	var attendu: bool = app.model.squad.any(func(p: Dictionary): return (p.get("age") is int or p.get("age") is float) and int(p.age) <= 21)
	check(not attendu or jeune != null, "Badge Jeune présent")
	if jeune != null:
		await montrer(jeune)
		await click(jeune.get_global_rect().get_center())
		check(app.route != "Effectif", "Badge Jeune -> Formation (%s)" % app.route)
		await effectif()
	# La fiche du titulaire reste ouverte par son nom dans la liste.
	var titulaire := str(xv[numero].id)
	await montrer(found("SquadOpenPlayer_" + titulaire.validate_node_name()))
	if await click_id("SquadOpenPlayer_" + titulaire.validate_node_name()):
		check(app.selected_player == titulaire and found("CarnetSquad") == null, "Nom du titulaire -> sa fiche")
		check(found("PlayerRolePitch") != null, "Fiche : terrain des postes (familiarité)")
		await capture("fiche")
	await effectif()
	# Souris hors de la liste : pas de carte joueur au survol sur la capture.
	var loin := InputEventMouseMotion.new(); loin.position = Vector2(4, 1070); loin.global_position = loin.position
	Input.parse_input_event(loin)
	await settle(4)
	# Liste en haut pour la capture (le retour de fiche garde le défilement).
	var defile := found("SquadScroll") as ScrollContainer
	if defile != null: defile.scroll_vertical = 0
	await settle(2)
	await capture("etoiles")
	check(found("EtoilesTitrePoste") != null, "Choix du poste gardé au retour sur l'Effectif")
	if await click_id("EtoilesEffacer"):
		check(int(app.management_ui.roster.get("etoiles_poste", 0)) == 0 and str(app.management_ui.roster.sort) == "Poste" and found("EtoilesTitrePoste") == null and found("PanneauChoisi_%d" % numero) == null, "✕ -> retour au tri par poste")

## Fait défiler la liste de l'Effectif jusqu'au contrôle (ligne hors de la zone visible).
func montrer(control: Control) -> void:
	var defile := found("SquadScroll") as ScrollContainer
	if control == null or defile == null: return
	defile.ensure_control_visible(control)
	await settle(4)

func finish() -> void:
	print("PANNEAUX EFFECTIF : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var t := OS.get_environment("CD_PANNEAUX_TAILLE").split("x")
	if t.size() == 2: taille = Vector2i(int(t[0]), int(t[1]))
	if not captures.is_empty():
		root.mode = Window.MODE_WINDOWED
		root.borderless = true
		DisplayServer.window_set_size(taille)
	root.size = taille
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await appliquer_taille()
	var export := OS.get_environment("CD_PANNEAUX_EXPORT")
	check(not export.is_empty() and app._command("import", {"text": FileAccess.get_file_as_string(export)}), "Carrière de test importée")
	await wait_worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	app.coach.close()
	var rel: Dictionary = app.model.clubLife.relationships
	var tensions: Dictionary = rel.get("tensions", {})
	var programme: Dictionary = app.model.clubLife.get("weekProgram", {})
	check(int(tensions.get("level", 0)) >= 2 and tensions.get("players", []).size() >= 3, "Carrière de test : tension vive dans le moteur")
	check(programme.get("days", []).size() == 7, "Programme de la semaine du moteur")
	check(rel.get("playerTrust") is float or rel.get("playerTrust") is int, "Confiance des joueurs du moteur")

	# Captures : premier passage sur l'Effectif pour laisser passer la bulle d'accueil de Gabi (une fois par écran).
	if not captures.is_empty():
		await effectif()
		await create_timer(2.5).timeout
		if app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
		app.coach.close()
		await create_timer(1.0).timeout
	# Déplié par défaut : trois panneaux empilés à gauche, tableau décalé.
	await effectif()
	for id in ["xv", "semaine", "groupe"]: check(found("PanneauEffectif_" + id) != null, "Panneau déplié · " + id)
	var table := found("ImmersiveRosterTable")
	var colonne := found("PanneauEffectif_xv")
	check(table != null and colonne != null and colonne.get_global_rect().end.x < table.get_global_rect().position.x, "Panneaux à gauche du tableau")
	check(found("PanneauxRail") == null, "Pas de rail quand la colonne est dépliée")
	var dossier := found("CarnetSquad")
	check(dossier != null and table.get_global_rect().end.x >= dossier.get_global_rect().end.x - 2, "Rien à droite du tableau")
	await capture("developpe")

	# XV : un numéro -> fiche du joueur ; terrain et flèche -> Composition.
	var xv: Dictionary = Panneaux._xv(app)
	var numero: int = xv.keys()[0] if not xv.is_empty() else 0
	check(numero > 0, "Feuille de match : numéros du XV")
	await etoiles_au_poste(xv)
	await effectif()
	if await click_id("PanneauEcran_xv"): check(app.route == "Composition", "Flèche XV -> Composition")

	# Semaine : jours du moteur (match, séance), clic -> Entraînement.
	await effectif()
	var jours: Array = programme.get("days", [])
	for i in jours.size():
		check(found("PanneauJour_%d" % i) != null, "Jour %d affiché" % i)
	var jm: Variant = programme.get("matchDay")
	if jm != null: check(found("PanneauJour_%d" % int(jm)).get_child_count() > 0, "Jour de match marqué d'une icône")
	if await click_id("PanneauJourOuvrir_%d" % int(programme.get("sessionDay", 0))): check(app.route == "Préparation", "Jour de séance -> Entraînement")
	await effectif()
	if await click_id("PanneauChargeOuvrir_intense"): check(app.route == "Préparation", "Charge -> Entraînement")

	# Groupe : jauges -> Vestiaire ; tensions -> petite fenêtre visuelle, Échap la ferme.
	await effectif()
	if await click_id("PanneauJauge_playerTrust"): check(app.route == "Vestiaire", "Confiance -> Vestiaire")
	await effectif()
	if await click_id("PanneauJauge_morale"): check(app.route == "Vestiaire", "Moral -> Vestiaire")
	await effectif()
	if await click_id("PanneauTensionsOuvrir"):
		var fenetre := found("FenetreTensions")
		check(fenetre != null, "Tensions -> petite fenêtre")
		for row: Dictionary in tensions.get("players", []).slice(0, 6):
			check(found("FenetreTensionsJoueur_" + str(row.id).replace(":", "_")) != null, "Fenêtre : portrait du joueur en tension " + str(row.id))
		check(not tensions.get("duos", []).is_empty() and found("FenetreTensionsDuo") != null, "Fenêtre : duo à risque relié")
		await capture("tensions")
		await escape()
		check(found("FenetreTensions") == null and app.route == "Effectif", "Échap ferme la fenêtre, on reste sur l'Effectif")
	if await click_id("PanneauTensionsOuvrir"):
		var premier := str(tensions.players[0].id)
		if await click_id("FenetreTensionsJoueur_" + premier.replace(":", "_")):
			check(found("FenetreTensions") == null and app.selected_player == premier, "Portrait en tension -> fiche du joueur")

	# Replier un panneau, puis toute la colonne : rail, tableau pleine largeur, état mémorisé.
	await effectif()
	if await click_id("PanneauPoignee_semaine"):
		check(not bool(prefs().get("semaine", true)) and found("PanneauJour_0") == null, "Semaine repliée et mémorisée")
	if await click_id("PanneauxReplier"):
		check(bool(prefs().get("replie", false)) and found("PanneauxRail") != null and found("PanneauEffectif_xv") == null, "Colonne rangée en rail, mémorisé")
		table = found("ImmersiveRosterTable")
		check(table != null and table.size.x >= (2248 - Panneaux.RAIL - 18 - 2) * preload("res://ui/immersive08/components.gd").density, "Rail : le tableau reprend la largeur")
		for id in ["xv", "semaine", "groupe"]: check(found("PanneauOnglet_" + id) != null, "Icône du rail · " + id)
		await capture("replie")
	# Le rail rouvre la colonne avec le panneau choisi.
	if await click_id("PanneauOnglet_semaine"):
		check(not bool(prefs().get("replie", true)) and bool(prefs().get("semaine", false)) and found("PanneauJour_0") != null, "Icône SEMAINE -> colonne rouverte, semaine dépliée")
	# Replier les trois panneaux un par un range aussi la colonne.
	for id in ["xv", "semaine", "groupe"]:
		if found("PanneauEffectif_" + id) != null and bool(prefs().get(id, true)): await click_id("PanneauPoignee_" + id)
	check(found("PanneauxRail") != null and bool(prefs().get("replie", false)), "Trois panneaux repliés -> rail")
	await click_id("PanneauOnglet_xv")
	for id in ["semaine", "groupe"]:
		if found("PanneauPoignee_" + id) != null and not bool(prefs().get(id, true)): await click_id("PanneauPoignee_" + id)
	check(not bool(prefs().get("replie", true)) and found("PanneauEffectif_groupe") != null, "Colonne rouverte en entier")

	# Dernier état choisi : la page se rouvre comme le manager l'a laissée (changement d'écran, rechargement, relance).
	for replie in [true, false]:
		await effectif()
		if replie:
			if found("PanneauxReplier") != null: await click_id("PanneauxReplier")
		elif found("PanneauxRail") != null: await click_id("PanneauOnglet_xv")
		var etiquette := "replié" if replie else "déplié"
		check(bool(prefs().get("replie", false)) == replie, "Dernier état noté · " + etiquette)
		app._navigate("Vestiaire")
		await settle(8)
		await effectif()
		check((found("PanneauxRail") != null) == replie and (found("PanneauEffectif_xv") == null) == replie, "Changement d'écran : rouvre " + etiquette)
		check(app._command("import", {"text": FileAccess.get_file_as_string(export)}), "Rechargement de la sauvegarde · " + etiquette)
		await wait_worker()
		await effectif()
		check((found("PanneauxRail") != null) == replie and (found("PanneauEffectif_xv") == null) == replie, "Sauvegarde rechargée : rouvre " + etiquette)
		app.management_ui.erase(Panneaux.CLE)
		await effectif()
		check((found("PanneauxRail") != null) == replie, "Interface remise à zéro : rouvre " + etiquette)
		var relance = load("res://ui/user_preferences.gd").new()
		check(relance.load_profile(str(app.model.meta.dataDir)) and bool(relance.data.get(Panneaux.CLE, {}).get("replie", false)) == replie, "Relance du jeu (fichier des préférences) : rouvre " + etiquette)

	# Entraînement : programme jour par jour du moteur, clic sur la séance -> sa carte.
	app.Immersive.open_training(app)
	await settle(12)
	for i in jours.size(): check(found("TrainingDay_%d" % i) != null, "Entraînement : jour %d" % i)
	await capture("entrainement")
	if await click_id("TrainingDayOpen_%d" % int(programme.get("sessionDay", 0))):
		check(int(app.management_ui.get("immersive_training", {}).get("slot", -1)) == 0, "Jour de séance -> carte Séance collective")

	# Vestiaire : confiance des joueurs, tensions cliquables -> même petite fenêtre.
	app._navigate("Vestiaire")
	await settle(12)
	await capture("vestiaire")
	var carte := found("LockerMetric1")
	check(carte != null and carte.find_children("*", "Label", true, false).any(func(l: Label): return l.text.to_lower() == "confiance des joueurs"), "Vestiaire : confiance des joueurs")
	if await click_id("LockerTensionsOuvrir"):
		check(found("FenetreTensions") != null, "Vestiaire : tensions -> petite fenêtre")
		await escape()
		check(found("FenetreTensions") == null and app.route == "Vestiaire", "Vestiaire : Échap ferme la fenêtre")
	finish()
