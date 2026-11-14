extends SceneTree
## « Continuer » dans le vrai jeu (Godot réel + worker réel, carrière Monde au 13 juillet 2026).
## Vérifie : bouton principal « Continuer », panneau de progression (date qui défile, « Arrêter »), arrêt sur un
## événement avec son motif, « Arrêter » au milieu d'une avance (carrière sauvegardée), « Jour suivant » (+1 j et
## Ctrl+J) toujours là et d'un seul jour.
## CD_CONTINUER_CAPTURE=<fichier.png> : capture du panneau pendant l'avance (rendu fenêtré requis).
## CD_CONTINUER_MESURE=1 : mesure du 13/07 au jour du premier match, « Continuer » puis « Jour suivant » (long).
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames := 4) -> void:
	for frame in frames: await process_frame

func wait_idle(limit_ms := 240000) -> bool:
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

func today() -> String:
	return str(app.model.get("meta", {}).get("calendarToday", ""))

func button(id: String) -> Button:
	return app.find_child(id, true, false) as Button

## Clic sur « Continuer » ; renvoie le résumé d'arrêt du moteur (meta.advanceUntilEvent).
func continuer(capture := "") -> Dictionary:
	var action := button("ImmersiveContinue")
	check(action != null and action.text == "Continuer" and not action.disabled, "Bouton principal « Continuer » (" + (action.text if action != null else "absent") + ")")
	if action == null: return {}
	var progress = app.continue_progress
	var dates: Array[String] = []
	var seen := func(_p: Dictionary): dates.append(str(progress.sheet_day.text))
	app.bridge.progressed.connect(seen)
	action.pressed.emit()
	await settle(2)
	check(progress.visible and progress.running, "Panneau de progression affiché dès le clic")
	check(progress.card.visible and progress.card.size.x > 200, "Carte de progression présente")
	check(progress.stop_button.visible and not progress.stop_button.disabled, "« Arrêter » disponible pendant l'avance")
	if not capture.is_empty():
		var until := Time.get_ticks_msec() + 30000
		while dates.size() < 2 and app.waiting and Time.get_ticks_msec() < until: await process_frame
		await settle(6)
		var image := root.get_texture().get_image()
		check(image != null and image.save_png(capture) == OK, "Capture du panneau : " + capture)
	await wait_idle()
	app.bridge.progressed.disconnect(seen)
	var info: Variant = app.model.get("meta", {}).get("advanceUntilEvent")
	check(info is Dictionary, "Le moteur dit pourquoi il s'arrête")
	return info if info is Dictionary else {}

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	app._navigate("Bureau")
	await settle()
	check(today() == "2026-07-13", "Carrière au lundi 13 juillet 2026 (" + today() + ")")
	check(button("ImmersiveNextDay") != null, "« Jour suivant » (+1 j) reste dans le bandeau")
	if OS.get_environment("CD_CONTINUER_MESURE") == "1":
		await mesure()
		return finish()
	# 1. Continuer jusqu'au premier événement (reprise de l'entraînement du club, le lundi 20 juillet).
	var started := Time.get_ticks_msec()
	var info := await continuer(OS.get_environment("CD_CONTINUER_CAPTURE"))
	var stop: Dictionary = info.get("stop", {})
	print("CD_CONTINUER premier arrêt : ", JSON.stringify(info), " en ", Time.get_ticks_msec() - started, " ms")
	check(int(info.get("days", 0)) > 1, "Plusieurs jours avancés en un clic")
	check(today() > "2026-07-13" and today() == str(info.get("to", "")), "La date de carrière a avancé jusqu'à l'arrêt")
	check(not str(stop.get("label", "")).is_empty() and stop.get("kind") != "blocage", "Arrêt motivé : " + str(stop.get("label", "")))
	await settle(2)
	check(app.continue_progress.visible and not app.continue_progress.running and app.continue_progress.title.text == str(stop.get("label", "")), "Le panneau affiche le motif d'arrêt")
	check(not app.continue_progress.stop_button.visible, "« Arrêter » disparaît à l'arrêt")
	await create_timer(3.4).timeout
	check(not app.continue_progress.visible, "Le panneau s'efface de lui-même")
	await Flow.settle_club_meetings(app, self, check)
	# 2. « Jour suivant » : un seul jour, par le bouton puis par Ctrl+J.
	app._navigate("Bureau")
	await settle()
	var before := today()
	var single := button("ImmersiveNextDay")
	if single != null:
		single.pressed.emit()
		await wait_idle()
		check(today() == _shift(before, 1), "+1 j avance d'un seul jour (" + before + " → " + today() + ")")
	await Flow.settle_club_meetings(app, self, check)
	before = today()
	var event := InputEventKey.new()
	event.keycode = KEY_J
	event.ctrl_pressed = true
	event.pressed = true
	check(app.navigation_controller.handle_shortcut(event), "Ctrl+J est reconnu")
	await wait_idle()
	check(today() == _shift(before, 1), "Ctrl+J avance d'un seul jour (" + before + " → " + today() + ")")
	await Flow.settle_club_meetings(app, self, check)
	# 3. « Arrêter » au milieu d'une avance : arrêt à la fin du jour en cours, carrière sauvegardée.
	app._navigate("Bureau")
	await settle()
	before = today()
	var action := button("ImmersiveContinue")
	action.pressed.emit()
	var limit := Time.get_ticks_msec() + 60000
	var first_progress := [false]
	var on_progress := func(_p: Dictionary): first_progress[0] = true
	app.bridge.progressed.connect(on_progress)
	while not first_progress[0] and app.waiting and Time.get_ticks_msec() < limit: await process_frame
	app.bridge.progressed.disconnect(on_progress)
	if app.waiting:
		app.continue_progress.stop_button.pressed.emit()
		check(app.continue_progress.stopping and app.continue_progress.stop_button.disabled, "« Arrêter » est pris en compte")
	await wait_idle()
	var stopped: Dictionary = app.model.get("meta", {}).get("advanceUntilEvent", {})
	check(today() > before, "Les jours déjà passés sont gardés après « Arrêter »")
	check(first_progress[0] == false or stopped.get("stop", {}).get("kind") in ["arret", "match", "rendez_vous", "conference", "reprise", "ouverture", "message", "international"], "Arrêt demandé ou événement du même jour : " + JSON.stringify(stopped.get("stop", {})))
	check(not str(app.model.get("meta", {}).get("dataDir", "")).is_empty(), "Profil de carrière présent")
	finish()

func mesure() -> void:
	# Du 13/07 au jour du premier match : rendez-vous réglés par la même aide aux deux passages.
	var t0 := Time.get_ticks_msec()
	var clics := 0
	for i in 60:
		await Flow.settle_club_meetings(app, self, check)
		var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
		if cadence.get("matchReady", false): break
		app._navigate("Bureau")
		await settle()
		await continuer()
		clics += 1
	print("CD_CONTINUER_MESURE apres ", JSON.stringify({"ms": Time.get_ticks_msec() - t0, "clics": clics, "date": today()}))

func _shift(iso: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00") + days * 86400
	return Time.get_datetime_string_from_unix_time(unix).substr(0, 10)

func finish() -> void:
	if failures.is_empty(): print("Continuer Godot · %d contrôles réussis" % checks)
	else: printerr("Continuer Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
