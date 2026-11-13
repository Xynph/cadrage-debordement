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
	return await preload("res://qa_runner.gd").settle_club_meetings(app, tree, check, stop_before_kind)

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
