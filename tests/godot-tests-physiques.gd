extends SceneTree
## Tests physiques avant le match (idée FM27 n° 36, choix A de Léo du 23/11/2026), vrai jeu (carrière Monde importée avec
## des titulaires revenus de blessure, tools/ecrans-filmes/preparer-carriere.cjs --reprises) :
## - avant-match : lien « Tests physiques » de la tuile Ta feuille → sous-page en liste (visage, blessure, corps face /
##   dos, test réussi ou échoué, minutes conseillées sur 80′, forme) ; aucun bouton Confirmer ;
## - un clic sur une ligne ouvre la fiche du joueur sur l'onglet Blessures (historique : date, zone, durée) ;
## - Réception : message du médecin avec la liste des tests sous sa lettre ; son bouton ouvre la sous-page.
## CD_TP_CAPTURES=<dossier> (+ CD_TP_TAILLE=LxH) : final-<L>.png (sous-page), final-fiche-blessures-<L>.png,
## final-message-medecin-<L>.png. Imprime TESTS_PHYSIQUES <n> controles, <m> echec(s).
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Tests = preload("res://ui/immersive08/tests_physiques.gd")
const ClubMail = preload("res://ui/club_mail.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_TP_CAPTURES")
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
	var loin := InputEventMouseMotion.new(); loin.position = Vector2(-50, -50); loin.global_position = loin.position
	Input.parse_input_event(loin)
	await settle(20)
	await create_timer(1.0).timeout
	var image := root.get_texture().get_image()
	var fichier := ("final-%d.png" % taille.x) if nom.is_empty() else ("final-%s-%d.png" % [nom, taille.x])
	if image != null: image.save_png(captures.path_join(fichier))

## Boutons de validation interdits (un clic choisit et valide).
func confirmations(noeud: Node) -> int:
	var n := 0
	if noeud is Button and noeud.is_visible_in_tree():
		var t := ((noeud as Button).text + " " + (noeud as Button).tooltip_text).to_lower()
		if "confirmer" in t or "valider" in t: n += 1
	for enfant in noeud.get_children(): n += confirmations(enfant)
	return n

func ouvrir_sous_page() -> Control:
	app._clear_dialogs()
	app.management_ui["avant_page"] = ""
	app._navigate("Match")
	await wait_worker()
	await settle(12)
	# L'avant-match peut se reconstruire (taille de fenêtre, retour du moteur) : lien relu à chaque essai.
	for essai in 4:
		await create_timer(0.3).timeout
		await settle(8)
		var lien := found("MatchTestsPhysiques") as BaseButton
		if essai == 0: check(lien != null and lien.is_visible_in_tree(), "Lien Tests physiques sur la tuile Ta feuille")
		if lien == null or lien.is_queued_for_deletion(): continue
		lien.pressed.emit()
		await wait_worker()
		await settle(12)
		if found("TestsPhysiquesPage") != null: break
	if found("TestsPhysiquesPage") == null: printerr("DEBUG page=", app.management_ui.get("avant_page", ""), " waiting=", app.waiting, " route=", app.route, " next=", app.model.get("next") is Dictionary)
	return found("TestsPhysiquesPage")

func run() -> void:
	if not captures.is_empty():
		var t := OS.get_environment("CD_TP_TAILLE").split("x")
		if t.size() == 2: taille = Vector2i(int(t[0]), int(t[1]))
	root.size = taille
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await appliquer_taille()
	var export := OS.get_environment("CD_TP_EXPORT")
	check(not export.is_empty() and app._command("import", {"text": FileAccess.get_file_as_string(export)}), "Carrière de test importée")
	await wait_worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	app.coach.close()
	var lignes := Tests.lignes(app.model)
	check(lignes.size() >= 3, "Joueurs testés par le moteur : %d" % lignes.size())
	for c: Dictionary in lignes:
		check(int(c.minutes) % 5 == 0 and int(c.minutes) >= 0 and int(c.minutes) <= 80, "Minutes conseillées : " + str(c.minutes))
	for x: Variant in Tests.donnees(app.model).get("joueurs", []):
		check(x is Dictionary and not x.has("tolerance"), "La vraie limite n'est pas montrée")
	# 1. Sous-page de l'avant-match.
	var page := await ouvrir_sous_page()
	check(page != null and page.is_visible_in_tree(), "Sous-page des tests physiques")
	if page == null: return finir()
	for i in range(1, lignes.size() + 1):
		check(found("TestsPhysiquesLigne%d" % i) != null, "Ligne %d" % i)
		check(found("TestsPhysiquesTest%d" % i) != null, "Résultat du test, ligne %d" % i)
		check(found("TestsPhysiquesCorps%dF" % i) != null and found("TestsPhysiquesCorps%dB" % i) != null, "Corps face et dos, ligne %d" % i)
		var mot := found("TestsPhysiquesMinutes%dMot" % i) as Label
		check(mot != null and mot.text == Tests.mot_minutes(int(lignes[i - 1].minutes)), "Minutes conseillées, ligne %d" % i)
		check(found("TestsPhysiquesOuvrir%d" % i) is BaseButton, "Ligne cliquable %d" % i)
	check(confirmations(page) == 0, "Aucun bouton Confirmer ni Valider")
	await capture("")
	# 2. Un clic sur une ligne : fiche du joueur, onglet Blessures.
	var id := str(lignes[0].j.get("id", ""))
	(found("TestsPhysiquesOuvrir1") as BaseButton).pressed.emit()
	await settle(16)
	var fiche := found("ImmersivePlayerFull")
	check(fiche != null and str(fiche.get_meta("player_id", "")) == id, "La ligne ouvre la fiche du joueur")
	var histo := found("PlayerInjuryHistory")
	check(histo != null and histo.is_visible_in_tree(), "Fiche : onglet Blessures ouvert")
	check(found("FicheBlessuresLigne1") != null and found("FicheBlessuresDate1") != null and found("FicheBlessuresZone1") != null and found("FicheBlessuresDuree1") != null, "Historique : date, zone, durée")
	check(found("PlayerReturnTest") != null and found("FicheBlessuresTestResultat") != null, "Fiche : dernier test de reprise")
	check(found("FullPlayerTab6") is BaseButton, "Onglet Blessures dans la barre d'onglets")
	await capture("fiche-blessures")
	app.management_ui["immersive_player_tab"] = 0
	# 3. Réception : message du médecin, liste des tests sous la lettre.
	var mail_id := ""
	for m: Dictionary in ClubMail.mails(app.model):
		if str(m.get("type", "")) == "tests_reprise": mail_id = str(m.id)
	check(not mail_id.is_empty(), "Message du médecin dans la Réception")
	if not mail_id.is_empty():
		app._reset_reception(mail_id)
		app._navigate("Réception", false)
		await settle(16)
		var bloc := found("TestsPhysiquesMail")
		check(bloc != null and bloc.is_visible_in_tree(), "Liste des tests sous la lettre du médecin")
		check(found("TestsPhysiquesMailLigne%d" % lignes.size()) != null, "Une ligne par joueur testé")
		check(found("TestsPhysiquesMailMinutes1Mot") != null and found("TestsPhysiquesMailTest1") != null, "Résultat et minutes dans le message")
		await capture("message-medecin")
		var ouvrir := found("InboxClubMailOpen") as BaseButton
		check(ouvrir != null and "Tests physiques" in ouvrir.text, "Bouton du message vers les tests")
		if ouvrir != null:
			ouvrir.pressed.emit()
			await settle(16)
			check(app.route == "Match" and found("TestsPhysiquesPage") != null, "Le message ouvre la sous-page des tests")
	finir()

func finir() -> void:
	print("TESTS_PHYSIQUES %d controles, %d echec(s)" % [checks, failures.size()])
	for f: String in failures: print("FAIL ", f)
	quit(0 if failures.is_empty() else 1)
