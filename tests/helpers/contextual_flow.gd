extends RefCounted

# Exercise the public continuation with the worker's actual scene identity.
static func skip_talk(app: Control, tree: SceneTree, expected_phase: String, check: Callable) -> void:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	var scene: Dictionary = value if value is Dictionary else {}
	check.call(scene.get("phase") == expected_phase and scene.get("options", []).size() == 6, "Causerie réelle à six choix : " + expected_phase)
	if scene.get("phase") != expected_phase: return
	check.call(app._command("match_talk_continue", {"key":scene.key, "phase":scene.phase, "skip":true}), "Passer explicitement la causerie : " + expected_phase)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await tree.process_frame
	app.timer.stop()
	check.call(not app.waiting and app.bridge.last_response_ok, "Continuation contextuelle acceptée : " + expected_phase)
	check.call(app.model.get("clubLife", {}).get("matchTalks", {}).get("scene") == null, "Causerie traitée sans contourner sa garde")

# Call only at a declared setup/advance boundary, after assertions about the
# meeting under test. The bundled QA helper uses the actual public worker API.
static func settle_club_meetings(app: Control, tree: SceneTree, check: Callable, stop_before_kind: String = "") -> bool:
	# Rendez-vous du club d'abord : tant que l'un d'eux attend (conférence de presse d'arrivée d'une carrière
	# démarrée à la reprise du club), le moteur refuse aussi `reprise_decide` (recette native du 16/11/2026).
	var Runner = preload("res://qa_runner.gd")
	if not await Runner.settle_club_meetings(app, tree, check, stop_before_kind): return false
	if app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene") is Dictionary: return true
	var due: Variant = app.model.get("clubLife", {}).get("reprise", {}).get("due", [])
	var decided: bool = due is Array and not due.is_empty()
	if not await settle_reprise_decisions(app, tree, check): return false
	return await Runner.settle_club_meetings(app, tree, check, stop_before_kind) if decided else true

# « Doit répondre » de la pré-saison (reprise.cjs, clubLife.reprise.due) : « Continuer » ne repart pas sans réponse.
# Les suites qui ne testent pas ces décisions les confient à Gabi par la commande publique et referment
# « La reprise » ouverte par l'arrêt.
static func settle_reprise_decisions(app: Control, tree: SceneTree, check: Callable) -> bool:
	var due: Variant = app.model.get("clubLife", {}).get("reprise", {}).get("due", [])
	for key: Variant in (due as Array).duplicate() if due is Array else []:
		if not await _progression_command(app, tree, check, "reprise_decide", {"decision": str(key), "option": "staff"}): return false
	var dialog := app.get_node_or_null("RepriseDialog")
	if dialog != null:
		dialog.queue_free()
		await tree.process_frame
	return true

# Setup boundaries for careers using the public daily calendar. These helpers
# never manufacture a fixture/date or bypass a meeting/match guard.
# La saison Monde compte plusieurs semaines de préparation avant le premier match du club : la boucle
# s'arrête au jour de match (`matchReady`) ; le plafond n'est qu'une garde contre une boucle sans fin.
const MAX_PREPARATION_DAYS := 150
static func prepare_match_day(app: Control, tree: SceneTree, check: Callable) -> bool:
	for day in MAX_PREPARATION_DAYS:
		if not await settle_club_meetings(app, tree, check): return false
		var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
		if cadence.is_empty() or cadence.get("matchReady", false):
			var ready: bool = app.model.get("next") is Dictionary
			check.call(ready, "Calendrier réel : rencontre disponible le jour du coup d’envoi")
			return ready
		var can_advance: bool = cadence.get("canAdvance", false)
		check.call(can_advance, "Calendrier réel : prochaine journée de préparation autorisée")
		if not can_advance: return false
		if not await _progression_command(app, tree, check, "advance_day", {"fromDate":app.model.meta.calendarToday}): return false
	check.call(false, "Calendrier réel : coup d’envoi non atteint dans les " + str(MAX_PREPARATION_DAYS) + " jours de préparation")
	return false

# Result confirmation and weekly closure are distinct. Supply the week captured
# before finish_round so historical weekly careers remain covered too.
static func finish_match_week(app: Control, tree: SceneTree, check: Callable, previous_week: int) -> bool:
	for day in 7:
		if not await settle_club_meetings(app, tree, check): return false
		if int(app.model.get("meta", {}).get("week", -1)) != previous_week: return true
		var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
		var can_advance: bool = cadence.get("canAdvance", false)
		check.call(can_advance, "Calendrier réel : journée restante autorisée après confirmation du résultat")
		if not can_advance: return false
		if not await _progression_command(app, tree, check, "advance_day", {"fromDate":app.model.meta.calendarToday}): return false
	if not await settle_club_meetings(app, tree, check): return false
	var closed: bool = int(app.model.get("meta", {}).get("week", -1)) != previous_week
	check.call(closed, "Calendrier réel : semaine clôturée dans les sept journées restantes")
	return closed

static func _progression_command(app: Control, tree: SceneTree, check: Callable, command: String, payload: Dictionary) -> bool:
	print("SDK_CALENDAR_COMMAND ", command, " ", payload)
	var accepted: bool = app._command(command, payload)
	check.call(accepted, "Progression publique du calendrier : " + command)
	if not accepted: return false
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await tree.process_frame
	app.timer.stop()
	var ok: bool = not app.waiting and app.bridge.last_response_ok
	check.call(ok, "Réponse réelle du calendrier : " + command + " · " + str(app.last_error))
	return ok

# --- Calendrier de presse façon FM (décision du 18/11/2026) --------------------------------------------------------
# Plus de conférence à la création de la carrière ni chaque lundi : la rentrée (« Arrivée au club » dans une première
# saison) s'ouvre le lundi de la semaine du 1er match ; l'après-match s'ouvre dès la validation du résultat.

# Commande publique avec une attente longue (l'avance « Continuer » peut simuler plusieurs semaines de préparation).
static func command_wait(app: Control, tree: SceneTree, check: Callable, command: String, payload: Dictionary = {}, limit_ms: int = 300000) -> bool:
	var accepted: bool = app._command(command, payload)
	check.call(accepted, "Commande acceptée · " + command)
	if not accepted: return false
	var deadline := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < deadline: await tree.process_frame
	app.timer.stop()
	for frame in 5: await tree.process_frame
	var ok: bool = not app.waiting and app.bridge.last_response_ok
	check.call(ok, "Worker réel · " + command + " · " + str(app.last_error))
	return ok

# Avance avec « Continuer » (advance_until_event), décisions de la reprise et rendez-vous hors presse réglés, jusqu'à ce
# qu'une conférence de presse soit ouverte (la rentrée, depuis la création de la carrière). La conférence reste à tenir.
static func reach_press_conference(app: Control, tree: SceneTree, check: Callable, attempts: int = 40) -> bool:
	for attempt in attempts:
		if not await settle_club_meetings(app, tree, check, "press"): return false
		if app.model.get("clubLife", {}).get("press", {}).get("conference", {}).get("available", false): return true
		var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
		if cadence.get("matchReady", false):
			check.call(false, "Jour de match atteint sans conférence ouverte (" + str(app.model.get("meta", {}).get("calendarToday", "")) + ")")
			return false
		if not await command_wait(app, tree, check, "advance_until_event", {"fromDate": str(app.model.get("meta", {}).get("calendarToday", ""))}): return false
	return false

# Joue le prochain match du manager (délégué) jusqu'à la validation du résultat : l'après-match est alors ouvert
# (clubLife.press.context.slot == "apres"). Les autres rendez-vous du club sont réglés en chemin.
static func play_to_result(app: Control, tree: SceneTree, check: Callable) -> bool:
	if not await prepare_match_day(app, tree, check): return false
	if not await command_wait(app, tree, check, "auto_lineup"): return false
	if not await command_wait(app, tree, check, "begin_match"): return false
	await _skip_scene_talk(app, tree, check)
	if not await command_wait(app, tree, check, "delegate"): return false
	await _skip_scene_talk(app, tree, check)
	if app.model.get("live") is Dictionary:
		if not await command_wait(app, tree, check, "finish_round"): return false
		await _skip_scene_talk(app, tree, check)
	return true

static func _skip_scene_talk(app: Control, tree: SceneTree, check: Callable) -> void:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	if value is Dictionary: await skip_talk(app, tree, str(value.get("phase", "")), check)
