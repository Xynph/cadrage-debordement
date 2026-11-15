extends SceneTree
## Temps ressenti en carrière Monde, Godot réel + worker réel (CD_GODOT_TIMING=1).
## Profil existant (CD_GODOT_DATA_DIR) ou nouvelle carrière Monde. Mesure : navigation entre écrans, ouverture de
## la fiche joueur, décisions courantes (consignes, composition, « Suivre le conseil » de Gabi = set_lineup),
## match délégué le jour de match, passage des jours jusqu'à la semaine suivante.
## Imprime une ligne CD_MESURE en JSON : par commande moteur_ms (calcul + transfert), analyse_ms (lecture JSON et
## reconstruction différentielle sur le fil d'E/S), file_ms (attente du fil principal), rendu_ms (écran), total_ms.
## Outil de mesure (docs/fluidite-commandes-20261114.md), lancé à la main ; aucun seuil ici.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var rendus: Array[Dictionary] = []

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
	var until := Time.get_ticks_msec() + 120000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func mesurer_rendu(etiquette: String, action: Callable) -> void:
	var started := Time.get_ticks_usec()
	action.call()
	rendus.append({"ecran": etiquette, "rendu_ms": (Time.get_ticks_usec() - started) / 1000.0})
	await settle()

## Causeries d'avant, de mi-temps ou d'après-match : passées explicitement (commande publique).
func passer_causeries() -> void:
	for essai in 3:
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if not scene is Dictionary: return
		if not await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true}): return

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	if not app.model.get("meta", {}).get("hasCareer", false):
		await command("new_career", {"mode": "world-champ", "club": 102, "start": "club"})
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	for tour in 2:
		for target in ["Bureau", "Effectif", "Composition", "Calendrier", "Classements", "Club", "Finances", "Recrutement", "Staff"]:
			await mesurer_rendu(target, func(): app._navigate(target))
		var squad: Array = app.model.get("squad", [])
		if not squad.is_empty():
			await mesurer_rendu("Effectif", func(): app._navigate("Effectif"))
			await mesurer_rendu("Fiche joueur", func():
				app.selected_player = str(squad[tour % squad.size()].id)
				app.set_meta("immersive08_full_player", true)
				app._render())
		var tactics: Dictionary = app.model.get("tactics", {})
		var attacks: Array = tactics.get("attacks", [])
		if attacks.size() > 1:
			await command("set_tactics", {"attack": attacks[(tour + 1) % attacks.size()].id, "defense": tactics.get("defense")})
		await command("auto_lineup")
		# « Suivre le conseil » de Gabi sur la composition : un set_lineup par changement (ici, remettre le n° 15 à sa place).
		var lineup: Array = app.model.get("selection", {}).get("lineup", [])
		if lineup.size() > 14 and lineup[14] is Dictionary and lineup[14].get("id") != null:
			await command("set_lineup", {"playerId": str(lineup[14].id), "slot": 14})
	# Jour de match : match délégué, puis jours jusqu'à la semaine suivante.
	var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
	if cadence.get("matchReady", false) and app.model.get("next") is Dictionary:
		if not app.model.get("selection", {}).get("valid", true): await command("auto_lineup")
		if await command("begin_match"):
			await passer_causeries()
			if app.model.get("live") is Dictionary and not app.model.live.is_empty(): await command("delegate")
			await passer_causeries()
			if app.model.get("live") is Dictionary and not app.model.live.is_empty(): await command("finish_round")
			await passer_causeries()
	var semaine = app.model.get("meta", {}).get("week")
	for jour in 9:
		await Flow.settle_club_meetings(app, self, check)
		cadence = app.model.get("meta", {}).get("calendarCadence", {})
		if not cadence.get("canAdvance", false) or (cadence.get("matchReady", false) and jour > 0): break
		await command("advance_day", {"fromDate": app.model.meta.calendarToday})
		if app.model.get("meta", {}).get("week") != semaine: break
	print("CD_MESURE ", JSON.stringify({"commandes": app.timing_log, "rendus": rendus}))
	print("FLUIDITE MONDE MESURE : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
