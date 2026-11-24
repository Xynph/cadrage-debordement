extends SceneTree
## Feuille incomplète : appeler un espoir du centre ou jouer à 22 (décision de Léo, 14/11/2026), dans le vrai jeu et le
## vrai moteur (carrière Monde, club de Nationale, pilier gauche de remplacement introuvable le jour du match).
##  1. écran Match : « Vérifier la feuille » signale la feuille incomplète, le coup d'envoi ouvre « Feuille incomplète »
##     avec les deux choix, le premier (espoir : nom, âge, poste, note) coché par défaut, « Jouer à 22 » ensuite ;
##  2. composition : le bouton « Appeler un espoir » est présent, il ouvre la même fenêtre sans coup d'envoi ;
##  3. appel confirmé : le jeune est sur la feuille (n° 17), la feuille est valide, la carte Match le dit ;
##  4. coup d'envoi : match à 23 avec le jeune ; « Jouer à 22 » reste jouable (autre partie).
## Sauvegarde préparée par le vrai moteur : CD_ESPOIR_SAUVEGARDE. Captures : CD_ESPOIR_CAPTURE=<préfixe de chemin>.
const Espoir = preload("res://ui/espoir_appel.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Rooms = preload("res://qa_runner.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_prefix := OS.get_environment("CD_ESPOIR_CAPTURE")

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames: int = 12) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.4).timeout
	for i in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var deadline := Time.get_ticks_msec() + 180000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Vraie réponse du moteur : " + str(app.last_error))
	await settle()

func capture(name: String) -> void:
	await settle(16)
	if DisplayServer.get_name() == "headless" or capture_prefix.is_empty(): return
	check(root.get_texture().get_image().save_png(capture_prefix + name + ".png") == OK, "Capture " + name)

func bouton_texte(texte: String) -> Button:
	for node: Node in app.find_children("*", "Button", true, false):
		var b := node as Button
		if b != null and b.is_visible_in_tree() and b.text == texte: return b
	return null

func importer() -> void:
	app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_ESPOIR_SAUVEGARDE"))})
	await wait_engine()
	app.timer.stop()

func run() -> void:
	create_timer(900.0).timeout.connect(func():
		failures.append("délai dépassé (900 s)")
		fin())
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	app.timer.stop()
	app._command("new_career", {"mode": "world-champ", "club": 7})
	await wait_engine()
	app.timer.stop()
	if not await Rooms.settle_club_meetings(app, self, check):
		fin()
		return
	await importer()
	check(app.model.get("club") is Dictionary and str(app.model.get("meta", {}).get("mode")) == "world", "Carrière Monde importée (feuille incomplète)")
	var offre := Espoir.offer(app.model)
	check(not offre.is_empty(), "Le moteur propose un espoir pour la place vide")
	check(P.reduced_bench_number(app.model) == 17, "Le match à 22 reste offert (n° 17)")
	if offre.is_empty(): fin(); return
	var propose: Dictionary = offre.slots[0].candidates[0]
	var attendu := "Appeler un espoir : " + Espoir.describe(propose, app.model)
	# Note au poste en lettre (décision de Léo du 24/11/2026) : jamais le chiffre du moteur.
	check(attendu.ends_with(" au poste") and not attendu.contains("note %d" % int(propose.get("note", -1))) and not attendu.contains(", note "), "Espoir : note au poste en lettre, sans chiffre : " + attendu)
	print("ESPOIR proposé : ", attendu)

	# 1. Écran Match : les deux choix, défaut sur l'espoir.
	app._navigate("Match")
	await settle(40)
	var statut := app.find_child("MatchOpenSheetStatus", true, false) as Button
	check(statut != null and statut.is_visible_in_tree() and statut.text.begins_with("Feuille incomplète"), "L'avant-match annonce la feuille incomplète")
	var coup := bouton_texte("COUP D'ENVOI")
	check(coup != null and not coup.disabled, "Bouton « COUP D'ENVOI » actif (feuille incomplète)")
	if coup == null: fin(); return
	coup.pressed.emit()
	await settle(30)
	# Plus de fenêtre : sous-page de l'avant-match (décision de Léo du 19/11/2026).
	check(app.get_node_or_null("FeuilleIncompleteDialog") == null, "Aucune fenêtre au coup d'envoi")
	var page := app.find_child("FeuilleIncompletePage", true, false) as Control
	check(page != null and page.is_visible_in_tree(), "La page « Feuille incomplète » s'ouvre")
	if page == null: fin(); return
	var choix_espoir := page.find_child("FeuilleChoix_espoir0", true, false) as CheckBox
	var choix_22 := page.find_child("FeuilleChoix_a22", true, false) as CheckBox
	check(choix_espoir != null and choix_espoir.button_pressed, "« Appeler un espoir » coché par défaut")
	check(choix_espoir != null and choix_espoir.text.begins_with(attendu), "Libellé : nom, âge, poste, note : " + (choix_espoir.text if choix_espoir != null else ""))
	check(choix_22 != null and choix_22.text == "Jouer à 22" and not choix_22.button_pressed, "« Jouer à 22 » proposé en second")
	await capture("feuille-espoir")
	(page.find_child("FeuilleIncompleteCancel", true, false) as Button).pressed.emit()
	await settle(10)
	check(app.find_child("FeuilleIncompletePage", true, false) == null, "« Annuler » referme la page : retour à l'avant-match")

	# 2. Composition : lien « Appeler un espoir » → sous-page de la Composition (jamais une fenêtre, sans coup d'envoi).
	app._navigate("Composition")
	await settle(40)
	# La pastille « LineupCallEspoir » porte son bouton plat « LineupCallEspoirLien » (Pieces.pastille, en-tête visuel #1143).
	var appel := app.find_child("LineupCallEspoirLien", true, false) as Button
	check(appel != null and appel.is_visible_in_tree(), "Composition : lien « Appeler un espoir »")
	if appel == null: fin(); return
	await capture("composition-espoir")
	appel.pressed.emit()
	await settle(30)
	var sous_page := app.find_child("CompositionSubpage_espoir", true, false)
	var confirmer := app.find_child("LineupEspoirConfirm", true, false) as Button
	check(sous_page != null and confirmer != null and not confirmer.disabled and app.get_node_or_null("FeuilleIncompleteDialog") == null, "Composition : sous-page d'appel, sans fenêtre")
	check(sous_page != null and sous_page.find_child("FeuilleChoix_a22", true, false) == null, "Composition : pas de « Jouer à 22 » (il se choisit au coup d'envoi)")
	if confirmer == null: fin(); return
	await capture("composition-espoir-sous-page")
	confirmer.pressed.emit()
	await wait_engine()
	check(app.model.get("selection", {}).get("valid", false), "Après l'appel, la feuille est valide")
	var sur_feuille := false
	for s: Dictionary in app.model.selection.slots:
		if s.get("slot") == 16 and s.get("playerId") == propose.id: sur_feuille = true
	check(sur_feuille, "Le jeune appelé occupe la place n° 17")
	check(P.reduced_bench_number(app.model) == 0 and Espoir.offer(app.model).is_empty(), "Plus de feuille à 22 ni d'offre")

	# 3. Coup d'envoi : match à 23 avec le jeune (rendez-vous du club éventuels réglés d'abord).
	await Rooms.settle_club_meetings(app, self, check)
	app._navigate("Match")
	await settle(40)
	await capture("feuille-complete")
	coup = bouton_texte("COUP D'ENVOI")
	check(coup != null and not coup.disabled, "Coup d'envoi direct")
	if coup == null: fin(); return
	coup.pressed.emit()
	await wait_engine()
	var live: Variant = app.model.get("live")
	check(live is Dictionary and not live.is_empty(), "Match lancé")
	check(live is Dictionary and int(live.get("nominationSize", 23)) == 23, "Match à 23 avec le jeune")
	fin()

func fin() -> void:
	print("FEUILLE ESPOIR %d controles, %d echec%s" % [checks, failures.size(), "s" if failures.size() > 1 else ""])
	app.closing = true
	app.bridge.stop()
	quit(1 if failures.size() > 0 else 0)
