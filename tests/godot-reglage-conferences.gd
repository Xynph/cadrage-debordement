extends SceneTree
## Réglage « Conférences ordinaires : y aller / envoyer l'adjoint » dans les Paramètres (vrai Godot + vrai worker,
## carrière Monde « world-champ », club 102). Le choix n'existait que dans la salle de presse : ici il doit être
## visible dans les Paramètres, envoyer la commande press_policy, se refléter dans le modèle, et « Continuer » ne
## doit plus s'arrêter sur une conférence ordinaire (les grands moments restent obligatoires).
## CD_REGLAGE_CAPTURES=<dossier> : capture du réglage (rendu fenêtré requis).
const Flow = preload("helpers/contextual_flow.gd")
const Progression = preload("res://ui/career_progression.gd")
const Preferences = preload("res://ui/preferences_dialog.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_REGLAGE_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames := 5) -> void:
	for frame in frames: await process_frame

func wait_idle(limit_ms := 300000) -> bool:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
	return not app.waiting

func command(id: String, payload: Dictionary = {}) -> bool:
	if not app._command(id, payload):
		check(false, "Commande acceptée · " + id)
		return false
	await wait_idle()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func press() -> Dictionary:
	return app.model.get("clubLife", {}).get("press", {})

func today() -> String:
	return str(app.model.get("meta", {}).get("calendarToday", ""))

func capture(name_: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(captures)
	await settle(30)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.save_png(captures.path_join(name_ + ".png")) == OK, "Capture " + name_)

## Avance « Continuer » jusqu'à une conférence ordinaire ouverte (Continuer s'arrête dessus tant que l'adjoint n'est pas choisi).
func reach_ordinary() -> bool:
	for attempt in 12:
		await Flow.settle_club_meetings(app, self, check, "press")
		var conference: Dictionary = press().get("conference", {})
		if conference.get("available", false) and not conference.get("moment") is Dictionary: return true
		if not await command(Progression.CONTINUE_COMMAND, {"fromDate": today()}): return false
		if app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false): return false
	return false

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	if is_instance_valid(app.coach): app.coach.close()
	check(press().get("policy", {}).get("ordinary") == "moi", "Réglage de départ : y aller")
	# L'arrivée est un grand moment : elle reste obligatoire en personne.
	var arrival: Dictionary = press().get("conference", {})
	check(arrival.get("moment") is Dictionary, "Conférence d'arrivée : grand moment")
	var answers: Array[Dictionary] = []
	for question: Dictionary in arrival.get("questions", []):
		answers.append({"questionId": question.id, "answerId": question.answers[0].id})
	await command("press_conference", {"context": press().context, "invitationId": arrival.invitationId, "answers": answers})
	await Flow.settle_club_meetings(app, self, check)
	# 1. Avant : Continuer s'arrête sur la conférence ordinaire de la semaine.
	check(await reach_ordinary(), "Réglage « y aller » : Continuer s'arrête sur une conférence ordinaire (" + today() + ")")
	if press().get("conference", {}).get("invitationId") == null: return finish()
	# 2. Le choix est visible dans les Paramètres.
	var dialog: AcceptDialog = Preferences.open(app, app.user_preferences)
	check(dialog != null, "Paramètres ouverts")
	if dialog == null: return finish()
	await settle(8)
	var stay := dialog.find_child("PreferencesPressPolicy_moi", true, false) as Button
	var send := dialog.find_child("PreferencesPressPolicy_adjoint", true, false) as Button
	check(stay != null and stay.is_visible_in_tree() and stay.text == "Y aller", "Paramètres : option « Y aller » visible")
	check(send != null and send.is_visible_in_tree() and send.text == "Envoyer l’adjoint", "Paramètres : option « Envoyer l’adjoint » visible")
	var notice := dialog.find_child("PreferencesPressNotice", true, false) as Label
	check(notice != null and notice.text.contains("grands rendez-vous"), "Paramètres : explication des grands rendez-vous")
	check(stay != null and stay.tooltip_text == "Réglage actuel.", "Paramètres : « Y aller » est l'option cochée")
	var scroller := dialog.find_child("PreferencesPressSection", true, false)
	if scroller != null:
		var viewport := scroller.get_parent()
		while viewport != null and not viewport is ScrollContainer: viewport = viewport.get_parent()
		if viewport != null: (viewport as ScrollContainer).ensure_control_visible(scroller)
	await settle(6)
	# 3. Un clic envoie press_policy ; le modèle et l'affichage le reflètent (permis pendant le rendez-vous).
	print("CD_REGLAGE avant clic : waiting=", app.waiting, " dernière commande=", app.last_command)
	await wait_idle()
	if send != null:
		send.pressed.emit()
		await settle(3)
		await wait_idle()
	print("CD_REGLAGE après clic : dialogue valide=", is_instance_valid(dialog), " erreur=", app.last_error, " politique=", press().get("policy", {}))
	for child in app.get_children():
		if child is AcceptDialog: print("CD_REGLAGE dialogue ", child.name, " ", child.dialog_text)
	if not is_instance_valid(dialog):
		check(false, "Les Paramètres restent ouverts après le choix")
		return finish()
	check(app.bridge.last_response_ok, "Worker réel · press_policy · " + app.last_error)
	check(press().get("policy", {}).get("ordinary") == "adjoint", "Modèle : réglage « envoyer l'adjoint » enregistré")
	var send_after := dialog.find_child("PreferencesPressPolicy_adjoint", true, false) as Button
	check(send_after != null and send_after.tooltip_text == "Réglage actuel.", "Paramètres : l'adjoint est maintenant l'option cochée")
	var notice_after := dialog.find_child("PreferencesPressNotice", true, false) as Label
	check(notice_after != null and notice_after.text.contains("Gabi répond à la presse lors des conférences ordinaires"), "Paramètres : explication de l'adjoint")
	await capture("reglage-conferences")
	dialog.queue_free()
	await settle(4)
	# 4. La conférence déjà ouverte reste à traiter : on la confie à Gabi, puis Continuer ne s'arrête plus sur l'ordinaire.
	var open_conference: Dictionary = press().get("conference", {})
	if open_conference.get("available", false):
		await command("press_delegate", {"context": press().context, "invitationId": open_conference.invitationId})
	await Flow.settle_club_meetings(app, self, check)
	var delegated := 0
	var ordinary_stops := 0
	for attempt in 12:
		await Flow.settle_club_meetings(app, self, check, "press")
		if not await command(Progression.CONTINUE_COMMAND, {"fromDate": today()}): break
		var advance: Dictionary = app.model.get("meta", {}).get("advanceUntilEvent", {})
		delegated += int(advance.get("pressDelegated", 0))
		var conference: Dictionary = press().get("conference", {})
		if conference.get("available", false) and not conference.get("moment") is Dictionary: ordinary_stops += 1; break
		if delegated >= 1 or app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false): break
	check(ordinary_stops == 0, "Avec l'adjoint : Continuer ne s'arrête plus sur une conférence ordinaire")
	check(delegated >= 1, "Avec l'adjoint : une conférence ordinaire tenue par Gabi pendant l'avance (%d)" % delegated)
	finish()

func finish() -> void:
	if failures.is_empty(): print("Réglage conférences Godot · %d contrôles réussis" % checks)
	else: printerr("Réglage conférences Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)