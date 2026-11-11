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
	check(speech_requests == 0 and speech_starts == 0, "Silence : aucune demande ni début de parole")
	print("READER HISTORY : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null and app.bridge != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Projection initiale du vrai worker")
	if app.model.is_empty(): await finish(); return
	app.timer.stop()
	app.coach.speech.set_muted(true)
	app.coach.speech.requested.connect(func(_line: String): speech_requests += 1)
	app.coach.speech.started.connect(func(_id: int): speech_starts += 1)
	nav = app.navigation_controller
	if not await command("new_career", {"mode":"world-champ", "club":29}): await finish(); return
	if not await Flow.settle_club_meetings(app, self, check): await finish(); return
	if not await Flow.prepare_match_day(app, self, check): await finish(); return
	await command("auto_lineup")
	await command("begin_match")
	await Flow.skip_talk(app, self, "pre", check)
	await command("delegate")
	if app.model.get("clubLife", {}).get("matchTalks", {}).get("scene") is Dictionary:
		await Flow.skip_talk(app, self, "post", check)
	elif app.model.get("live") is Dictionary:
		await command("finish_round")
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
	await command("export")
	var before: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	var save_path := str(app.model.meta.dataDir).path_join("donnees.json")
	var saved := FileAccess.get_file_as_bytes(save_path)
	var requests: int = app.bridge._next_id
	var club_id := str(historical.home.id)
	check(nav.open_entity({"kind":"club", "id":club_id}), "Ouverture du club de la rencontre historique")
	await settle()
	var club := named("CompetitionClubDetails") as AcceptDialog
	check(club != null and str(club.get_meta("entity_id", "")) == club_id, "Lecteur du vrai club rendu")
	if club == null: await finish(); return
	var club_instance: int = club.get_instance_id()
	var result_button := club.find_child("ClubResult_" + str(historical.id).validate_node_name(), true, false) as Button
	check(result_button != null, "Score historique rendu comme véritable lien dans le club")
	if result_button == null: await finish(); return
	var club_scroll := scroll_of(club)
	if club_scroll != null: club_scroll.ensure_control_visible(result_button)
	await activate(result_button)
	var detail := named("CompetitionFixtureDetails") as AcceptDialog
	check(detail != null and detail.visible and str(detail.get_meta("entity_id", "")) == str(historical.id), "Le vrai score ouvre la bonne rencontre")
	check(is_instance_valid(club) and not club.visible and nav.is_suspended_reader(club) and str(club.name).begins_with("_NavigationReader_"), "Club conservé caché au même endroit sous nom privé")
	check(visible_readers() == 1, "Un seul lecteur visible, aucun doublon")
	if detail == null: await finish(); return
	await activate(detail.get_ok_button())
	check(is_instance_valid(club) and club.visible and club.get_instance_id() == club_instance and club.name == "CompetitionClubDetails", "FERMER rencontre restitue l’instance et le nom exacts du club")
	check(result_button.has_focus(), "Le focus revient au score historique initial")
	await activate(result_button)
	detail = named("CompetitionFixtureDetails") as AcceptDialog
	var return_club := detail.find_child("FixtureClub_home", true, false) as Button
	await activate(return_club)
	check(is_instance_valid(club) and club.visible and club.get_instance_id() == club_instance and visible_readers() == 1, "Lien vers le club ancêtre réutilise son lecteur sans doublon")
	await activate(result_button)
	detail = named("CompetitionFixtureDetails") as AcceptDialog
	var detail_instance: int = detail.get_instance_id()
	var date_button := detail.find_child("FixtureCalendarDate", true, false) as Button
	check(date_button != null, "La date historique est un vrai lien vers le calendrier")
	var detail_scroll := scroll_of(detail)
	if detail_scroll != null and date_button != null: detail_scroll.ensure_control_visible(date_button)
	await settle()
	var offset: int = detail_scroll.scroll_vertical if detail_scroll != null else 0
	await activate(date_button)
	check(app.route == "Calendrier" and app.management_ui.calendar_reading.selected == str(historical.date), "La date cible le calendrier réellement projeté")
	check(is_instance_valid(detail) and not detail.visible and nav.is_suspended_reader(detail), "Rencontre suspendue pendant la consultation du calendrier")
	nav._travel(-1)
	await settle()
	check(is_instance_valid(detail) and detail.visible and detail.get_instance_id() == detail_instance and detail.name == "CompetitionFixtureDetails", "Précédent depuis le calendrier restitue exactement le lecteur de rencontre")
	check(date_button.has_focus() and (detail_scroll == null or detail_scroll.scroll_vertical == offset), "Retour conserve le focus de la date et le scroll réel du lecteur")
	var confirmation := ConfirmationDialog.new()
	confirmation.name = "ReaderHistoryBusinessConfirmation"
	app.add_child(confirmation)
	confirmation.popup_centered(Vector2i(420, 200))
	await settle()
	var private_count: int = nav._readers.size()
	check(not nav.open_entity({"kind":"player", "id":str(app.model.squad[0].id)}, detail), "Autre confirmation visible : lien refusé avant suspension")
	check(detail.visible and confirmation.visible and nav._readers.size() == private_count, "Refus garde le lecteur, la confirmation et le registre intacts")
	confirmation.queue_free()
	await settle()
	check(app.bridge._next_id == requests, "Tous les liens et retours sont sans commande worker")
	check(saved == FileAccess.get_file_as_bytes(save_path), "Sauvegarde strictement identique après consultations et retours")
	await command("export")
	check(before == JSON.parse_string(app.model.meta.exportText).state, "État sportif et RNG exportés strictement inchangés")
	check(nav._readers.is_empty() and not is_instance_valid(club) and not is_instance_valid(detail), "Nouvelle réponse worker invalide et libère toute la chaîne de lecteurs")
	nav._travel(-1)
	await settle()
	check(visible_readers() == 0, "L’historique ne ressuscite aucun lecteur d’une ancienne projection")
	await finish()
