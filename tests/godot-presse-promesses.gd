extends SceneTree
## Promesses publiques dans le vrai jeu (Godot réel + worker réel, carrière Monde au 13 juillet 2026) :
## conférence d'arrivée (ouverte le lundi de la semaine du 1er match, atteinte en avançant : rien à la création), question d'objectif facultative (vraisemblance et réactions affichées, second clic = annuler),
## publication avec la promesse, bilan, bandeau des promesses en cours, puis suivi sur l'écran Club (Objectifs).
## CD_PRESSE_CAPTURES=<dossier> : captures 1920×1080 (rendu fenêtré requis).
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_PRESSE_CAPTURES")

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

func view() -> Control:
	var director: Node = app.contextual_director
	return director.view if director.active() and director.kind == "press" else null

func node(id: String) -> Node:
	var room := view()
	return room.find_child(id, true, false) if room != null else null

func click(id: String) -> bool:
	var target := node(id) as BaseButton
	check(target != null and target.is_visible_in_tree() and not target.disabled, "Bouton actif : " + id)
	if target == null or target.disabled: return false
	target.pressed.emit()
	await settle()
	if app.waiting: await wait_idle()
	return true

func capture(name_: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(captures)
	await settle(30)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.save_png(captures.path_join(name_ + ".png")) == OK, "Capture " + name_)

## Ouvre la salle comme le fait l'action du courrier de presse en Réception.
func open_room() -> bool:
	var invitation := str(press().get("conference", {}).get("invitationId", ""))
	check(not invitation.is_empty(), "Invitation de presse en attente")
	app.set_meta("press_mail_origin", invitation)
	app.contextual_director.sync()
	await settle(8)
	check(view() != null, "Salle de presse ouverte")
	return view() != null

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
	check(not press().get("conference", {}).get("available", false), "Aucune conférence à la création de la carrière")
	var arrived: bool = await Flow.reach_press_conference(app, self, check)
	check(arrived, "La conférence d'arrivée s'ouvre en avançant (" + str(app.model.get("meta", {}).get("calendarToday", "")) + ")")
	if not arrived: return finish()
	var conference: Dictionary = press().get("conference", {})
	var offer: Variant = conference.get("promise")
	check(offer is Dictionary and not offer.get("options", []).is_empty(), "Question d'objectif proposée à l'arrivée")
	if not offer is Dictionary or not await open_room(): return finish()
	check(node("PressPromiseOffer") != null, "Encadré « Objectif public » dans la salle")
	var choice: Dictionary = offer.options[0]
	for option: Dictionary in offer.options:
		if option.get("kind") == "home_wins": choice = option; break
	var id := "PressPromise_" + str(choice.id).replace(":", "_")
	var button := node(id) as Button
	var puce := node("PressPromiseChip_" + str(choice.id).replace(":", "_"))
	check(button != null and puce != null and puce.find_children("*", "Label", true, false).any(func(l: Label): return l.text == str(choice.label)), "Objectif proposé en pastille cliquable")
	check(button != null and not button.tooltip_text.contains("Supporters"), "Aucune réaction annoncée avant de répondre (Léo, 23/11/2026)")
	check(node("PressPromise_refuse") != null, "Refuser de promettre est possible")
	await click(id)
	check(view().promise_choice == str(choice.id), "Objectif retenu")
	check(str((node("PressPromiseSummary") as Label).text).begins_with("Annonce"), "Résumé de l'annonce")
	await click(id)
	check(view().promise_choice == "", "Second clic : objectif annulé")
	await click(id)
	await capture("promesse-choix")
	var questions: Array = conference.get("questions", [])
	for index in questions.size():
		var shown: Dictionary = questions[view().question_index]
		await click("PressAnswer_%s_%s" % [shown.id, "r1"])
	await settle(8)
	var promises: Dictionary = app.model.get("clubLife", {}).get("pressPromises", {})
	check(promises.get("active", []).size() == 1 and str(promises.active[0].kind) == "home_wins", "Promesse enregistrée par le moteur")
	check(node("PressPromiseAnnounced") != null, "Bilan : promesse publique et réactions")
	check(node("PressPromiseBanner") != null, "Bandeau des promesses en cours")
	await capture("promesse-bilan")
	await click("PressReturn")
	await wait_idle()
	# D'autres rendez-vous obligatoires du club (bilan du conseil…) peuvent suivre la conférence : on les referme comme le fait le joueur.
	for guard in 6:
		if not app.contextual_director.active_meeting(): break
		var queued: Dictionary = app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene", {})
		if not queued.get("completed", false): app.contextual_director.command("club_meeting_ack", {"meetingId": queued.get("id")})
		await wait_idle()
		app.contextual_director.close_room()
		await wait_idle()
	app._navigate("Club")
	await wait_idle()
	var row: Label = null
	var club_until := Time.get_ticks_msec() + 10000
	while row == null and Time.get_ticks_msec() < club_until:
		await settle(6)
		row = app.find_child("ClubPromise1", true, false) as Label
	var diag := "route=%s objectifs=%s actives=%d texte=%s rdv=%s attente=%s erreur=%s scene=%s" % [app.route, str(app.find_child("ClubObjectives", true, false) != null), app.model.get("clubLife", {}).get("pressPromises", {}).get("active", []).size(), "absent" if row == null else row.text, str(app.contextual_director.active_meeting()), str(app.waiting), str(app.last_error), JSON.stringify(app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene")).left(300)]
	check(row != null and row.text == str(promises.active[0].short), "Écran Club : promesse suivie dans « Objectifs de la saison » · "+diag)
	await capture("promesse-club")
	finish()

func finish() -> void:
	if failures.is_empty(): print("Promesses publiques Godot · %d contrôles réussis" % checks)
	else: printerr("Promesses publiques Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
