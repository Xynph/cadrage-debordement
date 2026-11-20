extends SceneTree
## Page « Préparer l'Europe » (écran, jamais une fenêtre) : brouillon consultatif, validation par le vrai moteur,
## contraintes EPCR (plafond de 42, qualifications non certifiées), refus et panne sans effet sur la carrière.
## La page est reconstruite à chaque rendu : l'état vit dans `management_ui.europe`, le test relit la page à chaque étape.
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var directory := OS.get_environment("CD_EPCR_UI_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	for i in 10: await process_frame
func dlg() -> Control:
	return app.find_child("EpcrPreparationDialog", true, false)
func windows(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(windows(child))
	return found
func ask(command: String, payload: Dictionary = {}) -> void:
	app._command(command, payload)
	var deadline := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Vrai worker : " + command)
	app.timer.stop(); await settle()
func press(control: Control) -> void:
	check(is_instance_valid(control), "Commande clavier présente")
	if not is_instance_valid(control): return
	check(control.is_visible_in_tree(), "Commande visible : " + str(control.name))
	control.grab_focus(); await settle()
	check(control.has_focus(), "Focus clavier : " + str(control.name))
	for down in [true, false]:
		var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
## Attend la fin de la consultation (la page peut avoir été reconstruite entre-temps).
func wait_consultation() -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while (app.waiting or (dlg() != null and dlg().pending)) and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
func open_page() -> void:
	await press(app.root_content.find_child("OpenEpcrPreparation", true, false))
func leave_page() -> void:
	await press(app.find_child("EuropeRetour", true, false))
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec() + 20000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Moteur prêt")
	app.timer.stop()
	await ask("new_career", {"mode": "world", "club": 0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await ask("export")
	var exported: String = app.model.meta.exportText
	var career_file: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var disk := FileAccess.get_file_as_bytes(career_file)
	app._navigate("Effectif"); await settle()

	# Ouverture : une page, pas une fenêtre ; tout l'effectif proposé.
	await open_page()
	var page := dlg()
	check(page != null and app.route == "Préparation Europe" and windows(app).is_empty(), "« Préparer l’Europe → » ouvre un écran, aucune fenêtre")
	if page == null: await finish(); return
	check(page.choices.size() > 42, "L’effectif réel permet de vérifier le dépassement de 42")
	check(page.selected.size() == page.choices.size(), "La liste proposée conserve tous les joueurs, sans suppression cachée")
	check(str(page.find_child("EpcrPreparationNotice", true, false).text).contains("ne vaut pas inscription officielle"), "Aucune fausse inscription officielle annoncée")

	# Plafond de 42 : refusé par le vrai validateur ; la page survit à la réponse et au rendu du modèle.
	await press(dlg().verify); await wait_consultation()
	page = dlg()
	check(page != null and app.bridge.last_response_ok and page.preview.registration.status == "invalid", "Le dépassement de 42 est refusé par le vrai validateur")
	var original_error: String = app.last_error
	app.last_error = "Décision antérieure à vérifier"
	var previous_error: String = app.last_error
	var receipts_before: Array = app.decision_feedback.receipts().duplicate(true)

	# Refus du worker (identifiant étranger) : brouillon conservé, rapport local, aucune erreur métier.
	var original_id: String = page.choices[0].get_meta("player_id")
	page.choices[0].set_meta("player_id", "foreign-review-id")
	page.selected.erase(original_id); page.selected["foreign-review-id"] = true
	page.etat.selected = page.selected.duplicate()
	await press(dlg().verify); await wait_consultation()
	page = dlg()
	check(page != null and app.route == "Préparation Europe" and not page.selected.has(original_id), "Un vrai refus worker conserve l’écran et la sélection")
	check(page.result.text.contains("identifiants uniques de ton effectif"), "Le refus réel est présenté dans le brouillon")
	check(app.last_error == previous_error and not app.connection_error, "Le refus consultatif ne crée pas une erreur métier")

	# Réessai après correction, puis coupe qui ne correspond pas.
	page.choices[0].set_pressed(true); await settle()
	page = dlg()
	check(page.selected.has(original_id), "Le joueur retiré peut être remis")
	await press(dlg().verify); await wait_consultation()
	page = dlg()
	check(page.preview.registration.status == "invalid", "Réessai réussi après correction de l’identifiant")
	var own_competition: String = page.preview.competitionId
	page.etat.preview.competitionId = "challenge"
	await press(dlg().verify); await wait_consultation()
	page = dlg()
	check(page.result.text.contains("ne participe pas à cette coupe"), "Un modèle de refus avec mêmes IDs ne produit aucun faux rapport")
	check(app.last_error == previous_error, "Second refus préserve le statut métier")
	page.etat.preview.competitionId = own_competition
	await press(dlg().verify); await wait_consultation()
	check(app.last_error == previous_error, "Un succès de consultation n’efface pas l’erreur métier antérieure")
	check(app.decision_feedback.receipts() == receipts_before, "Les consultations ne créent aucun reçu de décision métier")

	# Quitter la page pendant une consultation : le refus tardif n'est ni une erreur globale ni un reçu.
	page = dlg()
	page.choices[0].set_meta("player_id", "foreign-closed-draft")
	page.selected.erase(original_id); page.selected["foreign-closed-draft"] = true
	var previous_status: String = app._settled_status_text()
	page._verify()
	check(app.waiting and page.pending, "Requête réelle en attente avant de quitter la page")
	app._navigate("Effectif")
	var closed_deadline := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < closed_deadline: await process_frame
	await settle()
	check(not app.waiting and not app.bridge.last_response_ok and dlg() == null, "Le vrai refus arrive après avoir quitté la page")
	check(app.last_error == previous_error and app._settled_status_text() == previous_status and not app.connection_error, "Le refus d’un brouillon quitté ne crée aucune erreur globale ou métier")
	check(app.decision_feedback.receipts() == receipts_before, "Le refus après départ ne crée aucun reçu métier")
	check(FileAccess.get_file_as_bytes(career_file) == disk, "Quitter en attente et son refus conservent le profil exact")
	var unexpected := 0
	for child in app.get_children():
		if child is AcceptDialog and child.visible: unexpected += 1
	check(unexpected == 0, "Aucune fenêtre d’erreur pour le brouillon quitté")
	app.last_error = original_error

	# Réouverture : brouillon propre, jamais un ancien verdict ; le clavier retire un joueur.
	await open_page()
	page = dlg()
	check(page != null and page.selected.size() == page.choices.size(), "La nouvelle ouverture repart d’un brouillon propre après le refus")
	check(not page.result.text.contains("Liste :"), "La réouverture ne reprend pas un ancien verdict")
	await press(page.choices[0]); page = dlg()
	check(page.selected.size() == page.choices.size() - 1 and page.count.text.begins_with(str(page.selected.size())), "Le clavier retire réellement un joueur et actualise le compteur")
	check(page.result.text.contains("relance la vérification"), "Un brouillon modifié invalide le rapport précédent")

	# Liste vide, puis feuille de 23 : les qualifications non certifiées restent inconnues.
	await press(page.find_child("EpcrSelectNone", true, false)); page = dlg()
	await press(dlg().verify); await wait_consultation()
	page = dlg()
	check(page.selected.is_empty() and page.preview.registeredIds.is_empty(), "Le choix vide est transmis sans réinscription implicite")
	check(page.preview.registration.status == "invalid" and page.preview.teamSheet.status == "invalid", "Liste et feuille affichent les refus du worker")
	check(not page.result.text.is_empty(), "Les raisons sont lisibles sur la page")
	var sheet: Array = app.model.lineup + app.model.reserves
	for choice: CheckButton in page.choices: choice.button_pressed = choice.get_meta("player_id") in sheet
	await settle(); page = dlg()
	await press(dlg().verify); await wait_consultation()
	page = dlg()
	check(page.preview.registration.status == "unknown" and page.preview.teamSheet.status == "unknown", "Les qualifications non certifiées restent inconnues pour une liste de 23")
	check(page.result.text.contains("À confirmer"), "Le rapport présente les informations manquantes du validateur")
	for resolution in [Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = resolution; await settle(); await create_timer(.2).timeout; await settle()
		var retour := app.find_child("EuropeRetour", true, false) as Control
		check(app.route == "Préparation Europe" and retour != null and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(retour.get_global_rect()), "Page entière, jamais une fenêtre : " + str(resolution))
		check(dlg().selected.size() == dlg().etat.selected.size(), "Redimensionnement conserve le brouillon : " + str(resolution))
	root.size = Vector2i(1920, 1080); await settle()
	await leave_page()
	check(app.route == "Effectif" and dlg() == null, "Retour de la page détruit l’écran européen")
	await ask("export")
	check(app.model.meta.exportText == exported, "La consultation et les choix conservent chaque champ de carrière")
	check(FileAccess.get_file_as_bytes(career_file) == disk, "La consultation conserve disque, horloge et RNG")

	# Panne du transport : le brouillon reste, la raison est locale, l'erreur du moteur reste globale.
	app._navigate("Effectif"); await settle()
	await open_page()
	page = dlg()
	var draft: int = page.selected.size()
	app.bridge.stop()
	var stop_deadline := Time.get_ticks_msec() + 3000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < stop_deadline: await process_frame
	await settle()
	var after_stop := FileAccess.get_file_as_bytes(career_file)
	await press(dlg().verify); await settle()
	page = dlg()
	check(page != null and app.route == "Préparation Europe" and page.selected.size() == draft, "La panne réelle du transport conserve le brouillon")
	check(app.connection_error and not app.last_error.is_empty(), "Le moteur réellement fermé reste signalé globalement")
	check(not page.result.text.is_empty() and not page.pending, "La panne termine la consultation avec une raison locale")
	check(FileAccess.get_file_as_bytes(career_file) == after_stop, "La panne et les refus ne modifient pas le profil (arrêt du moteur exclu)")
	await finish()
func finish() -> void:
	app.closing = true; app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	app.soundscape.dispose(); app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Worker possédé arrêté")
	app.queue_free(); await create_timer(.3).timeout
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  ")); file.close()
	print("Préparation EPCR UI : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
