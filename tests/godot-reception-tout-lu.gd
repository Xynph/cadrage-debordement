extends SceneTree
## Réception : « Tout marquer comme lu » (carrière Monde world-champ, départ « veille »).
## Marque lus uniquement les courriers d'information du filtre affiché ; les courriers qui attendent
## une réponse restent non lus et visibles ; état d'interface, aucune commande moteur.
## Captures (fenêtre réelle seulement) : CD_RECEPTION_CAPTURES=<dossier> -> reception-tout-lu-{avant,apres}.png.
## Imprime une ligne TOUTLU {checks, failures}.
const Flow = preload("helpers/contextual_flow.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const Reading = preload("res://ui/immersive08/reception_reading.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_RECEPTION_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_engine()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(captures)
	var image := root.get_viewport().get_texture().get_image()
	check(image.save_png(captures.path_join("reception-tout-lu-" + name + ".png")) == OK, "Capture " + name)

func counts() -> Dictionary:
	var state: Dictionary = app.Immersive.Reception._state(app)
	var info_unread := 0
	var todo_unread := 0
	var todo_ids: Array[String] = []
	var all_unread := 0
	for message: Dictionary in app.Immersive.Reception._messages(app):
		var read: bool = state.marks.get(message.id, {}).get("read", false)
		if read: continue
		all_unread += 1
		# Invitations de presse et avis de calendrier en attente, courriers de sélection : jamais marqués en bloc.
		var priority: bool = message.get("press_invitation", {}).get("status") == "pending" or message.get("calendar_notice", {}).get("status") == "pending" or message.has("international_event")
		if Reading.status(message, app.model).key == "info" and not priority: info_unread += 1
		else: todo_unread += 1; todo_ids.append(str(message.id))
	return {"info":info_unread, "todo":todo_unread, "todo_ids":todo_ids, "unread":all_unread}

func row_ids() -> Array:
	var ids := []
	for node in app.root_content.find_children("*", "Button", true, false):
		if node.has_meta("message_id"): ids.append(str(node.get_meta("message_id")))
	return ids

func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await Flow.settle_club_meetings(app, self, check)
	# Quelques jours de calendrier jusqu'à un courrier du club qui attend une réponse.
	for day in 6:
		var waiting := false
		for item: Dictionary in ClubMail.mails(app.model):
			if ClubMail.awaiting(app.model, item): waiting = true
		if waiting: break
		await command("advance_day", {"fromDate": app.model.meta.calendarToday})
		await Flow.settle_club_meetings(app, self, check)
	app._reset_reception()
	app.management_ui.reception.marks = {}
	app._navigate("Réception", false)
	await settle()
	var sequence: int = app.bridge._next_id
	var before := counts()
	check(before.info >= 2, "Avant : plusieurs informations non lues (%d)" % before.info)
	check(before.todo >= 1, "Avant : au moins un courrier à action non lu (%d)" % before.todo)
	var button := app.root_content.find_child("InboxMarkAllRead", true, false) as Button
	check(button != null, "Bouton « Tout marquer comme lu » présent")
	if button == null: return finish()
	check(not button.disabled, "Bouton actif tant que des informations sont non lues")
	check(button.text.contains("(%d)" % before.info), "Compteur du bouton : %d (« %s »)" % [before.info, button.text])
	check(not button.tooltip_text.is_empty(), "Infobulle présente")
	await capture("avant")
	button.pressed.emit()
	await settle()
	var after := counts()
	check(after.info == 0, "Après : toutes les informations sont lues (%d restantes)" % after.info)
	check(after.todo == before.todo and after.todo_ids == before.todo_ids, "Après : les courriers à action restent non lus")
	var visible := row_ids()
	for id: String in after.todo_ids: check(id in visible, "Courrier à action toujours visible : " + id.left(12))
	var again := app.root_content.find_child("InboxMarkAllRead", true, false) as Button
	check(again != null and again.disabled, "Bouton désactivé ensuite")
	check(again != null and not again.tooltip_text.is_empty() and not again.text.contains("("), "Désactivé : infobulle, pas de compteur")
	check(app.bridge._next_id == sequence, "Aucune commande moteur")
	await capture("apres")
	# Le filtre « Informations » ne contient plus rien à marquer ; « À faire » ne marque jamais de décision.
	app.Immersive.Reception.mark_all_read(app, app.Immersive.Reception._messages(app))
	check(counts().todo == before.todo, "Marquer sur tout le courrier ne touche pas aux décisions")
	finish()

func finish() -> void:
	print("TOUTLU ", JSON.stringify({"checks": checks, "failures": failures}))
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
