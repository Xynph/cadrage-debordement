extends SceneTree
## Écrans de chargement (décision de Léo, 16/11/2026) : seuls les vrais chargements ont un panneau animé, tout le
## reste (décisions, menus) est instantané. Godot réel + worker réel, carrière Monde (world-champ, club 102, veille
## du premier match), sauvegarde automatique « chaque jour ».
##   1. Ouverture du jeu : panneau « Ouverture du bureau du manager… » jusqu'au premier modèle.
##   2. Création de carrière : panneau « Création de la carrière… », bouton « Création en cours… ».
##   3. Menus et décisions : navigation et fiche d'un club sans panneau ni voile.
##   4. Continuer : panneau de progression ; la sauvegarde (après la réponse) est montrée par la disquette, jamais par
##      la carte ; le moteur signale son début et sa fin (persist_changed).
##   5. Coup d'envoi : panneau posé, opaque et dessiné avant la construction de la scène 3D du match.
## CD_ECRANS_CAPTURE=<préfixe de chemin> : captures PNG (≤ 1280 px de large, rendu fenêtré requis).
const Main = preload("res://main.gd")
const Progression = preload("res://ui/career_progression.gd")
const Flow = preload("helpers/contextual_flow.gd")
const MATCH_VIEW_SCRIPT := "res://match_view.gd"
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_prefix := OS.get_environment("CD_ECRANS_CAPTURE")
var captured: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames := 4) -> void:
	for frame in frames: await process_frame

func overlay() -> Control:
	return app.command_wait_overlay

func status_text() -> String:
	return str(overlay().get_node("CommandWaitFrame/CommandWaitStatus").text)

## Capture de l'image affichée (mode fenêtré seulement), réduite à 1280 px de large.
func capture(name: String) -> void:
	if capture_prefix.is_empty() or captured.has(name): return
	captured[name] = true
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		check(false, "Capture impossible : " + name)
		return
	if image.get_width() > 1280: image.resize(1280, roundi(image.get_height() * 1280.0 / image.get_width()), Image.INTERPOLATE_LANCZOS)
	check(image.save_png(capture_prefix + name + ".png") == OK, "Capture écrite : " + name)

## Attend la fin de la commande en cours ; renvoie {panel, blocked, ms} observés pendant l'attente.
func wait_idle(capture_name := "", limit_ms := 240000) -> Dictionary:
	var start := Time.get_ticks_msec()
	var seen := {"panel": false, "blocked": false}
	while app.waiting and Time.get_ticks_msec() < start + limit_ms:
		if overlay().blocks_input(): seen.blocked = true
		if overlay().panel_visible():
			seen.panel = true
			if not capture_name.is_empty() and overlay()._shown_for > 0.35: await capture(capture_name)
		await process_frame
	seen["ms"] = Time.get_ticks_msec() - start
	app.timer.stop()
	await settle()
	return seen

func command(id: String, payload: Dictionary = {}) -> bool:
	if not app._command(id, payload):
		check(false, "Commande acceptée · " + id)
		return false
	await wait_idle()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func rules() -> void:
	# Seuls les vrais chargements ont un panneau ; décisions et menus jamais.
	for heavy: String in ["new_career", "import", "begin_match", "advance_day", Progression.CONTINUE_COMMAND]:
		check(Main.shows_wait_panel(heavy), "Vrai chargement avec panneau : " + heavy)
	for light: String in ["club_sheet", "promote_cover", "league_detail_set", "set_tactics", "set_lineup", "auto_lineup"]:
		check(not Main.shows_wait_panel(light), "Décision ou menu sans panneau : " + light)
	# Fréquence de la sauvegarde complète : même règle que native/engine/action-journal.cjs `due`.
	check(Progression.autosave_due("jour", "2026-07-13", "2026-07-14"), "Chaque jour : nouvelle date")
	check(not Progression.autosave_due("jour", "2026-07-13", "2026-07-13"), "Chaque jour : même date")
	check(not Progression.autosave_due("semaine", "2026-07-13", "2026-07-19"), "Chaque semaine : du lundi au dimanche")
	check(Progression.autosave_due("semaine", "2026-07-19", "2026-07-20"), "Chaque semaine : nouveau lundi")
	check(not Progression.autosave_due("mois", "2026-07-01", "2026-07-31"), "Chaque mois : même mois")
	check(Progression.autosave_due("mois", "2026-07-31", "2026-08-01"), "Chaque mois : mois suivant")
	check(Progression.shift_day("2026-12-31", 1) == "2027-01-01", "Lendemain au changement d'année")

func run() -> void:
	rules()
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)

	# 1. Ouverture du jeu.
	check(overlay().blocks_input() and status_text() == Main.STARTUP_WAIT_MESSAGE, "Ouverture : panneau d'attente armé (« %s »)" % status_text())
	var start := Time.get_ticks_msec()
	var startup_panel := false
	while app.model.is_empty() and Time.get_ticks_msec() < start + 120000:
		if overlay().panel_visible():
			startup_panel = true
			if overlay()._shown_for > 0.35: await capture("01-ouverture")
		await process_frame
	var startup_ms := Time.get_ticks_msec() - start
	app.timer.stop()
	check(not app.model.is_empty(), "Ouverture : premier modèle reçu")
	check(startup_ms < 800 or startup_panel, "Ouverture longue (%d ms) : panneau affiché" % startup_ms)
	await settle(30)
	check(not overlay().blocks_input(), "Ouverture : panneau retiré au premier modèle")
	print("CD_ECRANS ouverture ", startup_ms, " ms, panneau ", startup_panel)

	# Sauvegarde automatique chaque jour (Réglages) : le moteur lit interface.json dans le même profil.
	check(app.user_preferences.set_value("autosave", "jour"), "Réglage : sauvegarde automatique chaque jour")

	# 2. Création de carrière.
	check(app._command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}), "Création demandée")
	check(overlay().blocks_input() and status_text() == "Création de la carrière…", "Création : panneau armé (« %s »)" % status_text())
	var creation := await wait_idle("02-creation")
	check(app.bridge.last_response_ok and app.model.get("club") is Dictionary, "Création : carrière Monde créée · " + app.last_error)
	check(int(creation.ms) < 800 or creation.panel, "Création longue (%d ms) : panneau affiché" % creation.ms)
	print("CD_ECRANS creation ", creation.ms, " ms, panneau ", creation.panel)
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()

	# 3. Menus et décisions : instantanés.
	for target: String in ["Effectif", "Calendrier", "Club", "Bureau"]:
		app._navigate(target)
		check(not app.waiting and not overlay().blocks_input(), "Menu sans panneau : " + target)
		await settle(2)
	var next: Variant = app.model.get("next")
	if next is Dictionary and next.get("home") is Dictionary and next.get("away") is Dictionary:
		var own := int(app.model.club.get("id", -1))
		var other := int(next.away.get("id", -1)) if int(next.home.get("id", -1)) == own else int(next.home.get("id", -1))
		check(app._command("club_sheet", {"club": other}), "Fiche d'un club demandée")
		var sheet := await wait_idle()
		check(app.bridge.last_response_ok, "Fiche d'un club rendue · " + app.last_error)
		check(not sheet.panel and not sheet.blocked, "Fiche d'un club : ni panneau ni voile (%d ms)" % sheet.ms)
	else: check(false, "Prochaine rencontre connue à la veille du match")
	var tactics: Dictionary = app.model.get("tactics", {})
	var attacks: Array = tactics.get("attacks", [])
	if attacks.size() > 1:
		var other_attack: Variant = attacks.filter(func(o): return o.get("id") != tactics.get("attack"))[0].get("id")
		check(app._command("set_tactics", {"attack": other_attack, "defense": tactics.get("defense")}), "Consigne demandée")
		var decision := await wait_idle()
		check(not decision.panel and not decision.blocked, "Décision : ni panneau ni voile (%d ms)" % decision.ms)
	app._navigate("Bureau")
	await settle(4)

	# 4. Continuer jusqu'au jour du match, sauvegarde automatique comprise.
	var persist_states: Array[String] = []
	var progress_panel: Control = app.continue_progress
	var on_persist := func(state: String, _message: String): persist_states.append(state)
	app.bridge.persist_changed.connect(on_persist)
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
	if cadence.get("canAdvance", false) and not cadence.get("matchReady", false):
		check(app._command(Progression.CONTINUE_COMMAND, {"fromDate": today}), "Continuer demandé")
		await settle(2)
		check(progress_panel.visible and progress_panel.running, "Continuer : panneau de progression affiché")
		var start_continue := Time.get_ticks_msec()
		while app.waiting and Time.get_ticks_msec() < start_continue + 240000:
			await process_frame
		app.timer.stop()
		await settle()
		check(app.bridge.last_response_ok, "Continuer accepté · " + app.last_error)
		var autosave: Variant = app.model.get("meta", {}).get("autosave")
		check(autosave is Dictionary and autosave.get("saved", false) and str(autosave.get("lastSave", "")) == str(app.model.meta.get("calendarToday", "")), "Profil sauvegardé à l'arrêt : " + str(autosave))
	else: check(false, "Veille du match : Continuer disponible (%s)" % str(cadence))
	# La sauvegarde de la clôture suit la réponse : début et fin signalés par le moteur, disquette visible puis cachée.
	var wait_persist := Time.get_ticks_msec()
	while not persist_states.has("done") and Time.get_ticks_msec() < wait_persist + 30000: await process_frame
	check(persist_states.size() >= 2 and persist_states[0] == "started" and persist_states.has("done") and not persist_states.has("failed"), "Sauvegarde en arrière-plan : début puis fin signalés (%s)" % str(persist_states))
	app.save_indicator.min_shown = 0.2
	var wait_hidden := Time.get_ticks_msec()
	while app.save_indicator.shown() and Time.get_ticks_msec() < wait_hidden + 5000: await process_frame
	check(not app.save_indicator.shown(), "Sauvegarde terminée : disquette cachée")
	app.bridge.persist_changed.disconnect(on_persist)
	# « Jour suivant » est sauvegardé après la réponse : le panneau ne la nomme plus (la disquette la montre).
	check(not app.autosave_expected("advance_day"), "Jour suivant : pas de sauvegarde annoncée dans le panneau")
	check(app.autosave_expected("next_season"), "Nouvelle saison : sauvegarde toujours annoncée (écrite avant la réponse)")

	# 5. Coup d'envoi.
	if not await Flow.prepare_match_day(app, self, check):
		finish()
		return
	if not app.model.get("selection", {}).get("valid", true): await command("auto_lineup")
	var kickoff := {"checked": false, "panel": false, "opaque": false, "text": "", "built_before": false, "built": false}
	var on_node := func(node: Node):
		var script: Variant = node.get_script()
		if script is Script and script.resource_path == MATCH_VIEW_SCRIPT and not kickoff.built:
			kickoff.built = true
			kickoff.panel = overlay().panel_visible()
			kickoff.opaque = is_equal_approx(overlay()._alpha, 1.0)
			kickoff.text = status_text()
	node_added.connect(on_node)
	# Une image après la réponse, avant la construction de la scène 3D : le panneau est déjà dessiné.
	var on_model := func(_value: Dictionary):
		if kickoff.checked or not app._opens_live_view(_value): return
		kickoff.checked = true
		await process_frame
		kickoff.built_before = kickoff.built
		check(overlay().panel_visible(), "Coup d'envoi : panneau dessiné avant la scène 3D")
		await capture("04-coup-envoi")
	app.bridge.model_changed.connect(on_model)
	check(app._command("begin_match"), "Coup d'envoi demandé")
	await wait_idle()
	for step in 4:
		var talk: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if not talk is Dictionary or kickoff.built: break
		await Flow.skip_talk(app, self, str(talk.get("phase", "")), check)
		await settle(4)
	app.timer.stop()
	node_added.disconnect(on_node)
	app.bridge.model_changed.disconnect(on_model)
	check(kickoff.built, "Coup d'envoi : scène 3D du match construite")
	check(kickoff.checked and not kickoff.built_before, "Coup d'envoi : une image dessinée avant la construction")
	check(kickoff.panel and kickoff.opaque and kickoff.text == Main.LIVE_VIEW_WAIT_MESSAGE, "Coup d'envoi : panneau opaque « %s » pendant la construction" % kickoff.text)
	await settle(30)
	check(not overlay().blocks_input(), "Coup d'envoi : panneau retiré une fois le match affiché")
	if not capture_prefix.is_empty():
		await settle(20)
		await capture("05-match")
	finish()

func finish() -> void:
	print("Écrans de chargement Godot · %d contrôles réussis" % (checks - failures.size()) if failures.is_empty() else "Écrans de chargement Godot · %d échec(s) sur %d contrôles" % [failures.size(), checks])
	app.bridge.stop()
	await settle(10)
	quit(0 if failures.is_empty() else 1)
