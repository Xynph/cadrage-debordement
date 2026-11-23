extends SceneTree
## Tactique › Phases arrêtées en combinaisons (idée FM27 n° 21, choix B de Léo du 23/11/2026), vrai jeu (carrière Monde
## importée) : combinaisons à gauche, schéma au centre, étapes à droite ; un clic sur une combinaison, un choix ou
## « + Nouvelle » s'applique tout de suite dans le moteur (aucun bouton Valider) ; touche, mêlée, pénalité, renvoi,
## attaque et défense ; plus de pastille « Moteur » ; pastille de joueur -> fiche ; pastille d'en-tête -> phase.
## CD_COMBI_CAPTURES=<dossier> (+ CD_COMBI_TAILLE=LxH) : final-touche/melee/penalite/defense-<L>.png.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const K = preload("res://ui/immersive08/tactics_combinaisons.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_COMBI_CAPTURES")
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
	await wait_worker()
	return true

func appliquer_taille() -> void:
	if captures.is_empty() or Vector2i(root.get_texture().get_size()) == taille: return
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.borderless = true
	root.size = taille
	DisplayServer.window_set_size(taille)
	await create_timer(0.5).timeout

func capture(nom: String) -> void:
	if captures.is_empty(): return
	await appliquer_taille()
	if is_instance_valid(app.coach):
		if app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
		app.coach.close()
	# Souris hors de l'écran : pas de survol ni de carte joueur sur la capture.
	var loin := InputEventMouseMotion.new(); loin.position = Vector2(-50, -50); loin.global_position = loin.position
	Input.parse_input_event(loin)
	await settle(20)
	await create_timer(1.0).timeout
	var image := root.get_texture().get_image()
	if image != null: image.save_png(captures.path_join("final-%s-%d.png" % [nom, taille.x]))

func compter(noeud: Node, mots: Array) -> int:
	var n := 0
	if noeud is Button:
		var t := ((noeud as Button).text + " " + (noeud as Button).tooltip_text + " " + str((noeud as Button).accessibility_name)).to_lower()
		for mot: String in mots: if mot in t: n += 1
	for enfant in noeud.get_children(): n += compter(enfant, mots)
	return n

func donnees(cle: String) -> Dictionary:
	return app.model.get("clubLife", {}).get("playbook", {}).get("combinaisons", {}).get(cle, {})

func ouvrir_phases() -> void:
	app._clear_dialogs()
	app._navigate("Composition")
	await settle(8)
	load("res://ui/immersive08/tactics_onglets.gd").choisir_onglet(app, 2)
	await settle(12)

func jeu() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await appliquer_taille()
	var export := OS.get_environment("CD_COMBI_EXPORT")
	check(not export.is_empty() and app._command("import", {"text": FileAccess.get_file_as_string(export)}), "Carrière de test importée")
	await wait_worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	app.coach.close()
	if not captures.is_empty():
		await ouvrir_phases()
		await create_timer(2.5).timeout
		if app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
		app.coach.close()
	await ouvrir_phases()
	check(found("TacticsTabTitle") != null and found("TacticsTabOpenFull") != null, "Onglet Phases arrêtées de la Tactique")
	# Touche en attaque : combinaisons enregistrées d'abord, schéma au centre, étapes à droite.
	var liste := found("CombiListeB")
	var cadre := found("CombiTerrainCadre")
	var etapes := found("CombiEtapes")
	check(liste != null and cadre != null and etapes != null and liste.get_global_rect().end.x <= cadre.get_global_rect().position.x and cadre.get_global_rect().end.x <= etapes.get_global_rect().position.x, "Combinaisons, schéma, étapes de gauche à droite")
	check(found("CombiLigneB0") != null and found("CombiLigneB1") != null, "Combinaisons enregistrées en lignes")
	check(app.find_children("CombiMoteur_*", "", true, false).is_empty(), "Plus aucune pastille « Moteur »")
	check(compter(app.root_content, ["valider", "confirmer"]) == 0, "Aucun bouton Valider / Confirmer")
	check(found("CombiBarre0") != null, "Effet sur le match en barres")
	# Clic sur une combinaison : appliquée dans le moteur.
	if await click_id("CombiLigneB1"):
		check(int(donnees("lineout_attaque").get("active", -1)) == 1, "Clic sur « Maul des 22 » : combinaison appliquée")
		check(str(app.model.clubLife.playbook.setPieces[1].get("selected", "")) == "maul", "Ancien carnet suivi : ballon porté")
	await capture("touche")
	# Clic sur un choix : appliqué.
	if await click_id("CombiPivot_cible_fond"):
		var d := donnees("lineout_attaque")
		check(str(d.liste[int(d.active)].choix.get("cible", "")) == "fond", "Clic sur « Fond » : choix appliqué")
	var avant := int(donnees("lineout_attaque").get("liste", []).size())
	if await click_id("CombiAjout"):
		var d := donnees("lineout_attaque")
		check(d.liste.size() == avant + 1 and int(d.active) == avant, "« + Nouvelle » : combinaison ajoutée et active")
	# Mêlée : 8 qui part.
	if await click_id("CombiPhase_scrum"):
		check(str(K.etat(app).phase) == "scrum" and found("CombiPivot_sortie_huit") != null, "Mêlée : choix « 8 qui part »")
		await click_id("CombiLigneB3")
		var d := donnees("scrum_attaque")
		check(str(d.liste[int(d.active)].choix.get("sortie", "")) == "huit", "Combinaison « 8 qui part » appliquée")
		await capture("melee")
	# Pénalité réglée avant le match, par zone.
	if await click_id("CombiPhase_penalty"):
		check(found("CombiPivot_pres_melee") != null and found("CombiPivot_loin_poteaux") != null, "Pénalité : zones et choix (but, touche, mêlée, vite)")
		await click_id("CombiPivot_pres_melee")
		var d := donnees("penalty_attaque")
		check(str(d.liste[int(d.active)].choix.get("pres", "")) == "melee", "Mêlée dans leurs 22 appliquée")
		await capture("penalite")
	# Défense : contre en touche.
	if await click_id("CombiScenario_defense"):
		await click_id("CombiPhase_lineout")
		check(str(K.etat(app).scenario) == "defense" and found("CombiPivot_contre_maul") != null, "Défense en touche : choix du contre")
		await click_id("CombiLigneB1")
		var d := donnees("lineout_defense")
		check(str(d.liste[int(d.active)].choix.get("contre", "")) == "devant", "« Contre devant » appliqué")
		await capture("defense")
	# Pastille d'en-tête -> phase en attaque.
	if await click_id("TacticsTabPhase_kickoff"):
		check(str(K.etat(app).phase) == "kickoff" and str(K.etat(app).scenario) == "attaque", "Pastille Renvoi : phase ouverte")
	# Pastille de joueur sur le schéma -> fiche du joueur.
	var jetons := app.find_children("CombiJetonLien_*", "Button", true, false)
	check(not jetons.is_empty(), "Joueurs sur le schéma")
	if not jetons.is_empty():
		(jetons[0] as Button).pressed.emit()
		await settle(12)
		check(not str(app.selected_player).is_empty(), "Pastille de joueur -> fiche")

func run() -> void:
	var t := OS.get_environment("CD_COMBI_TAILLE").split("x")
	if t.size() == 2: taille = Vector2i(int(t[0]), int(t[1]))
	if not captures.is_empty():
		root.mode = Window.MODE_WINDOWED
		root.borderless = true
		DisplayServer.window_set_size(taille)
	root.size = taille
	if not OS.get_environment("CD_COMBI_EXPORT").is_empty(): await jeu()
	print("COMBINAISONS %d controles, %d echec" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
