extends SceneTree
## Parcours réaliste mesuré (CD_GODOT_TIMING=1) : carrière, navigation entre
## écrans, décisions courantes et passages de jour. Imprime CD_MESURE en JSON.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var navigation: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle() -> void:
	for frame in 4: await process_frame

func command(id: String, payload: Dictionary = {}) -> bool:
	if not app._command(id, payload):
		check(false, "Commande acceptée · " + id)
		return false
	var until := Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func navigate(target: String) -> void:
	var started := Time.get_ticks_usec()
	app._navigate(target)
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	navigation.append({"route": target, "rendu_ms": elapsed})
	await settle()

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "common", "club": 0})
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	var rounds := int(OS.get_environment("CD_MESURE_TOURS")) if OS.has_environment("CD_MESURE_TOURS") else 2
	for round in rounds:
		for target in ["Bureau", "Effectif", "Composition", "Préparation", "Calendrier", "Classements", "Club", "Finances", "Recrutement", "Staff", "Réception"]:
			await navigate(target)
		var tactics: Dictionary = app.model.get("tactics", {})
		var attacks: Array = tactics.get("attacks", [])
		if not attacks.is_empty():
			await command("set_tactics", {"attack": attacks[(round + 1) % attacks.size()].id, "defense": tactics.get("defense")})
		var squad: Array = app.model.get("squad", [])
		if squad.size() > 4:
			await command("set_player_load", {"playerId": squad[4].id, "mode": "repos" if round % 2 == 0 else "normal"})
		await command("auto_lineup")
		var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
		if cadence.get("canAdvance", false):
			await command("advance_day", {"fromDate": app.model.meta.calendarToday})
			await Flow.settle_club_meetings(app, self, check)
	print("CD_MESURE ", JSON.stringify({"commandes": app.timing_log, "navigation": navigation}))
	print("CHARGEMENT MESURE : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
