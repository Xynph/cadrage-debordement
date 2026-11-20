extends SceneTree
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var nav: Node
var failures: Array[String] = []
var checks := 0
var speech_requests := 0
var speech_starts := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 10: await process_frame
func command(id: String, payload: Dictionary = {}) -> bool:
	var accepted: bool = app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(accepted and not app.waiting and app.bridge.last_response_ok, "Préparation publique : " + id + " · " + app.last_error)
	await settle()
	return accepted and not app.waiting and app.bridge.last_response_ok
func named(id: String) -> Node: return app.find_child(id, true, false)
func activate(button: Button) -> void:
	check(button != null and button.is_visible_in_tree() and not button.disabled, "Lien réel visible et activable au clavier")
	if button == null: return
	button.grab_focus()
	await settle()
	check(button.has_focus(), "Focus clavier sur le vrai lien : " + str(button.name))
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		button.get_viewport().push_input(event, true)
		await process_frame
	await settle()
func visible_readers() -> int:
	var count := 0
	for child: Node in app.get_children():
		if child is Window and child.visible and child.get_meta("navigation_read_only", false) and not child.is_queued_for_deletion(): count += 1
	return count
func scroll_of(window: Window) -> ScrollContainer:
	var surfaces := window.find_children("*", "ScrollContainer", true, false)
	return surfaces[0] if not surfaces.is_empty() else null
func finish() -> void:
	check(speech_requests == 0 and speech_starts == 0 and int(app.coach.speech._id) == 0, "Silence : aucune demande ni début de parole")
	print("READER HISTORY : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null and app.bridge != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
func prepare_public_checkpoint() -> bool:
	if not await command("new_career", {"mode":"world-champ", "club":29}): return false
	if not await Flow.settle_club_meetings(app, self, check): return false
	if not await Flow.prepare_match_day(app, self, check): return false
	await command("auto_lineup")
	await command("begin_match")
	await Flow.skip_talk(app, self, "pre", check)
	await command("delegate")
	if app.model.get("clubLife", {}).get("matchTalks", {}).get("scene") is Dictionary:
		await Flow.skip_talk(app, self, "post", check)
	elif app.model.get("live") is Dictionary:
		await command("finish_round")
	if not await Flow.settle_club_meetings(app, self, check): return false
	# A confirmed result is visible in the calendar before weekly archival.
	# Finish the real public week before requiring a ClubResult archive link.
	var completed_week: int = app.model.meta.week
	if not await Flow.finish_match_week(app, self, check, completed_week): return false
	return true
func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.coach.speech.set_muted(true)
	app.coach.speech.requested.connect(func(_line: String): speech_requests += 1)
	app.coach.speech.started.connect(func(_id: int): speech_starts += 1)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Projection initiale du vrai worker")
	if app.model.is_empty(): await finish(); return
	app.timer.stop()
	nav = app.navigation_controller
	if OS.get_environment("CD_READER_HISTORY_COPIED") != "1":
		if not await prepare_public_checkpoint(): await finish(); return
	else:
		# Carrière Monde préparée par les commandes publiques du moteur (Node, tests/helpers/analysis-club-public-prepare.cjs) :
		# la préparation jour par jour est trop longue en rendu logiciel dans le budget de la suite.
		check(app.model.get("club") is Dictionary, "Carrière préparée chargée sans créer une autre carrière")
		if not await Flow.settle_club_meetings(app, self, check): await finish(); return
	app._navigate("Bureau")
	await settle()
	var historical: Dictionary = {}
	for fixture: Dictionary in app.model.get("calendar", []):
		if fixture.get("played", false) and fixture.get("score") is Array:
			historical = fixture
			break
	check(not historical.is_empty(), "Rencontre historique réellement produite par le moteur")
	if historical.is_empty(): await finish(); return
	var archived: Array = app.model.get("history", []).filter(func(result: Dictionary):
		return str(result.get("fixtureId", "")) == str(historical.id) and result.get("pair", []) == [historical.home.id, historical.away.id] and result.get("score", []) == historical.score)
	check(archived.size() == 1, "Clôture hebdomadaire : résultat archivé réel de la même rencontre, paire et score")
	if archived.size() != 1: await finish(); return
	await command("export")
	var before: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	var save_path := str(app.model.meta.dataDir).path_join("donnees.json")
	var saved := FileAccess.get_file_as_bytes(save_path)
	var requests: int = app.bridge._next_id
	# Rencontre : sous-page de Classements (décision de Léo du 19/11/2026 : plus de petite fenêtre), avec retour et historique
	# Précédent / Suivant. Un nom de club ouvre la page « Fiche club » (lecture moteur `club_sheet`, sans changement d'état).
	check(nav.open_entity({"kind":"fixture", "id":str(historical.id)}), "Ouverture de la rencontre historique")
	await settle()
	var detail := named("CompetitionFixtureDetails")
	check(detail != null and str(detail.get_meta("entity_id", "")) == str(historical.id) and not detail is Window, "Page de la vraie rencontre rendue (aucune fenêtre)")
	if detail == null: await finish(); return
	check(app.route == "Classements" and visible_readers() == 0, "La rencontre s'ouvre dans l'écran Classements, sans lecteur par-dessus")
	var own_home: bool = str(historical.home.id) == str(app.model.club.id)
	var club_id := str(historical.away.id if own_home else historical.home.id)
	var club_link := detail.find_child("FixtureClub_away" if own_home else "FixtureClub_home", true, false) as Button
	check(club_link != null and str(club_link.get_meta("entity_id", "")) == club_id, "Club adverse rendu comme véritable lien dans la rencontre")
	if club_link == null: await finish(); return
	await activate(club_link)
	var deadline_sheet := Time.get_ticks_msec() + 30000
	while (app.waiting or named("ClubSheetLoading") != null) and Time.get_ticks_msec() < deadline_sheet: await process_frame
	await settle()
	check(app.route == "Fiche club" and int(app.management_ui.club_sheet.id) == int(club_id) and named("FicheClub") != null, "Le lien du club ouvre la fiche du bon club")
	check(visible_readers() == 0, "Aucun lecteur visible par-dessus la fiche du club")
	nav._travel(-1)
	await settle()
	detail = named("CompetitionFixtureDetails")
	check(app.route == "Classements" and detail != null and str(detail.get_meta("entity_id", "")) == str(historical.id), "Précédent depuis la fiche du club restitue la rencontre")
	# La fiche est une lecture moteur : le décompte des commandes repart d'ici.
	requests = app.bridge._next_id
	var date_button := detail.find_child("FixtureCalendarDate", true, false) as Button if detail != null else null
	check(date_button != null, "La date historique est un vrai lien vers le calendrier")
	if date_button == null: await finish(); return
	await activate(date_button)
	check(app.route == "Calendrier" and app.management_ui.calendar_reading.selected == str(historical.date), "La date cible le calendrier réellement projeté")
	nav._travel(-1)
	await settle()
	detail = named("CompetitionFixtureDetails")
	check(app.route == "Classements" and detail != null and str(detail.get_meta("entity_id", "")) == str(historical.id), "Précédent depuis le calendrier restitue la page de la rencontre")
	check(visible_readers() == 0, "Aucune fenêtre ne s'ouvre pendant la navigation de la rencontre")
	check(app.bridge._next_id == requests, "Tous les liens et retours sont sans commande worker")
	check(saved == FileAccess.get_file_as_bytes(save_path), "Sauvegarde strictement identique après consultations et retours")
	await command("export")
	check(before == JSON.parse_string(app.model.meta.exportText).state, "État sportif et RNG exportés strictement inchangés")
	check(nav._readers.is_empty(), "Aucun lecteur suspendu : la rencontre est une page de l'historique")
	var contexts := 0
	for child: Node in app.get_children():
		if child.has_meta("reading_dialog"): contexts += 1
	check(contexts == 0 and app.find_children("_NavigationReader_*", "Window", true, false).is_empty(), "Aucun contexte de consultation ni fenêtre suspendue")
	await finish()
