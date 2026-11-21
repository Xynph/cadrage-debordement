extends SceneTree
## Réglage « Conférences ordinaires : y aller / envoyer l'adjoint » dans les Paramètres (vrai Godot + vrai worker,
## carrière Monde « world-champ », club 102). Le choix n'existait que dans la salle de presse : ici il doit être
## visible dans les Paramètres, envoyer la commande press_policy, se refléter dans le modèle ; avec l'adjoint, l'après-match
## est tenu par Gabi dès la validation du résultat, sans arrêt de « Continuer » (les grands moments restent obligatoires).
## Calendrier de presse façon FM (18/11/2026) : la seule conférence ordinaire de base est l'après-match ; la rentrée
## (grand moment) s'ouvre le lundi de la semaine du 1er match.
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

## Joue le 1er match (ou le suivant) jusqu'à la validation du résultat : l'après-match, conférence ordinaire, s'ouvre alors.
func reach_ordinary() -> bool:
	if not await Flow.play_to_result(app, self, check): return false
	var conference: Dictionary = press().get("conference", {})
	return conference.get("available", false) and not conference.get("moment") is Dictionary and str(press().get("context", {}).get("slot", "")) == "apres"

## Courrier de la conférence en attente dans la Réception : ouvre le message et rend le bouton de réglage (ou null).
func open_press_mail() -> Button:
	app._reset_reception()
	app.management_ui.reception = {"folder":0, "category":"Tous", "selected":"", "oldest_first":false, "marks":{}, "scroll":0}
	app._navigate("Réception", false)
	await settle(6)
	check(app.Immersive.Reception.open_next_unread(app), "Réception : le courrier de la conférence s'ouvre")
	await settle(8)
	check(app.root_content.find_child("InboxOpenPressInvitation", true, false) != null, "Réception : « Ouvrir la conférence » présent")
	return app.root_content.find_child("InboxPressPolicy", true, false) as Button
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
	# Rien à la création de la carrière ; l'arrivée s'ouvre le lundi de la semaine du 1er match. C'est un grand moment :
	# elle reste obligatoire en personne.
	check(not press().get("conference", {}).get("available", false), "Aucune conférence à la création de la carrière")
	var arrived: bool = await Flow.reach_press_conference(app, self, check)
	check(arrived, "La conférence d'arrivée s'ouvre en avançant (" + today() + ")")
	if not arrived: return finish()
	var arrival: Dictionary = press().get("conference", {})
	check(arrival.get("moment") is Dictionary, "Conférence d'arrivée : grand moment")
	var moment_mail := await open_press_mail()
	check(moment_mail == null, "Réception : pas de bascule sur un grand moment (arrivée)")
	check(app.root_content.find_child("InboxOpenPressInvitation", true, false) != null, "Réception : l'arrivée reste à ouvrir en personne")
	var answers: Array[Dictionary] = []
	for question: Dictionary in arrival.get("questions", []):
		answers.append({"questionId": question.id, "answerId": question.answers[0].id})
	await command("press_conference", {"context": press().context, "invitationId": arrival.invitationId, "answers": answers})
	await Flow.settle_club_meetings(app, self, check)
	# 1. Avant : avec « y aller », l'après-match du 1er match reste à tenir en personne (rien ne le délègue).
	check(await reach_ordinary(), "Réglage « y aller » : l'après-match est une conférence ordinaire à tenir (" + today() + ")")
	if press().get("conference", {}).get("invitationId") == null: return finish()
	# 1 bis. Le courrier de la conférence ordinaire propose la bascule (sans toucher à la conférence en cours).
	var invitation_id = press().get("conference", {}).get("invitationId")
	var toggle := await open_press_mail()
	check(toggle != null and toggle.is_visible_in_tree(), "Réception : bascule présente sur une conférence ordinaire (après-match)")
	if toggle != null:
		check(toggle.text == "Les prochaines fois, envoyer Gabi aux conférences ordinaires", "Réception : libellé « envoyer Gabi » (« %s »)" % toggle.text)
		check(toggle.tooltip_text.contains("médias −2") and toggle.tooltip_text.contains("relation −1"), "Réception : infobulle du coût")
		await settle(240) # laisse l'annonce « Rendez-vous obligatoire » se retirer
		await capture("courrier-conference-adjoint")
		toggle.pressed.emit()
		await settle(2)
		await wait_idle()
		check(app.bridge.last_response_ok, "Worker réel · press_policy (courrier) · " + app.last_error)
		check(press().get("policy", {}).get("ordinary") == "adjoint", "Courrier : le modèle passe à « adjoint »")
		check(press().get("conference", {}).get("invitationId") == invitation_id and press().get("conference", {}).get("available", false), "Courrier : la conférence en cours reste à traiter")
		var inverse := app.root_content.find_child("InboxPressPolicy", true, false) as Button
		check(inverse != null and inverse.text == "Les prochaines fois, y aller moi-même", "Courrier : libellé inversé (« %s »)" % (inverse.text if inverse != null else "absent"))
		if inverse != null:
			inverse.pressed.emit()
			await settle(2)
			await wait_idle()
			check(press().get("policy", {}).get("ordinary") == "moi", "Courrier : retour à « y aller moi-même »")
			var back := app.root_content.find_child("InboxPressPolicy", true, false) as Button
			check(back != null and back.text.begins_with("Les prochaines fois, envoyer Gabi"), "Courrier : libellé de départ rétabli")

	# 2. Le choix est visible dans les Paramètres.
	var dialog: AcceptDialog = Preferences.open(app, app.user_preferences)
	check(dialog != null, "Paramètres ouverts")
	if dialog == null: return finish()
	await settle(8)
	var stay := dialog.find_child("PreferencesPressPolicy_moi", true, false) as Button
	var send := dialog.find_child("PreferencesPressPolicy_adjoint", true, false) as Button
	check(stay != null and stay.is_visible_in_tree() and stay.text == "Y aller", "Paramètres : option « Y aller » visible")
	check(send != null and send.is_visible_in_tree() and send.text == "Envoyer l’adjoint", "Paramètres : option « Envoyer l’adjoint » visible")
	var notice := dialog.find_child("PreferencesPressNotice", true, false) as Button
	check(notice != null and notice.tooltip_text.contains("grands rendez-vous"), "Paramètres : explication des grands rendez-vous (infobulle du « i »)")
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
	var notice_after := dialog.find_child("PreferencesPressNotice", true, false) as Button
	check(notice_after != null and notice_after.tooltip_text.contains("Gabi répond à la presse lors des conférences ordinaires"), "Paramètres : explication de l'adjoint (infobulle du « i »)")
	await capture("reglage-conferences")
	dialog.queue_free()
	await settle(4)
	# 4. L'après-match déjà ouvert reste à traiter : on le confie à Gabi. Avec le réglage « adjoint », l'après-match suivant
	#    est tenu par Gabi dès la validation du résultat, et « Continuer » ne s'arrête plus sur une conférence ordinaire.
	var open_conference: Dictionary = press().get("conference", {})
	if open_conference.get("available", false):
		await command("press_delegate", {"context": press().context, "invitationId": open_conference.invitationId})
	await Flow.settle_club_meetings(app, self, check)
	var delegated := 0
	var ordinary_stops := 0
	var played: bool = await Flow.play_to_result(app, self, check)
	check(played, "Le match suivant est joué jusqu'au résultat (" + today() + ")")
	var after_match: Dictionary = press().get("lastOutcome", {}) if played else {}
	var crisis: bool = press().get("conference", {}).get("moment") is Dictionary
	if played and crisis:
		# Série de défaites : la crise est un grand moment, tenu en personne même avec l'adjoint (jamais délégué).
		var rescue: Dictionary = press().get("conference", {})
		var rescue_answers: Array[Dictionary] = []
		for question: Dictionary in rescue.get("questions", []):
			rescue_answers.append({"questionId": question.id, "answerId": question.answers[0].id})
		await command("press_conference", {"context": press().context, "invitationId": rescue.invitationId, "answers": rescue_answers})
	elif played:
		check(not press().get("conference", {}).get("available", false), "Avec l'adjoint : plus d'après-match à tenir après le résultat")
		check(after_match.get("delegated", false) and str(after_match.get("context", {}).get("slot", "")) == "apres", "Avec l'adjoint : une conférence ordinaire tenue par Gabi dès le résultat")
		delegated += 1
	await Flow.settle_club_meetings(app, self, check)
	for attempt in 6:
		if not await command(Progression.CONTINUE_COMMAND, {"fromDate": today()}): break
		var advance: Dictionary = app.model.get("meta", {}).get("advanceUntilEvent", {})
		delegated += int(advance.get("pressDelegated", 0))
		var conference: Dictionary = press().get("conference", {})
		if conference.get("available", false) and not conference.get("moment") is Dictionary: ordinary_stops += 1; break
		if app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false): break
		await Flow.settle_club_meetings(app, self, check)
	check(ordinary_stops == 0, "Avec l'adjoint : Continuer ne s'arrête plus sur une conférence ordinaire")
	check(delegated >= 1 or crisis, "Avec l'adjoint : une conférence ordinaire tenue par Gabi sans arrêt (%d)" % delegated)
	finish()

func finish() -> void:
	if failures.is_empty(): print("Réglage conférences Godot · %d contrôles réussis" % checks)
	else: printerr("Réglage conférences Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)