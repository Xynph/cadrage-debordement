extends SceneTree
const Flow = preload("helpers/contextual_flow.gd")
const Reading = preload("res://ui/management_state.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var speech_requests := 0
var speech_starts := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL: ", label)
func settle() -> void:
	for frame in 8: await process_frame
func named(id: String) -> Node: return app.find_child(id, true, false)
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id, payload), "Commande publique de préparation : " + id)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and app.bridge.last_response_ok, "Réponse du vrai worker : " + id)
	await settle()
func activate(button: Button) -> void:
	check(button != null and button.is_visible_in_tree() and not button.disabled, "Bouton réellement rendu et accessible")
	if button == null: return
	button.grab_focus()
	await settle()
	for down in [true, false]:
		var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = down
		button.get_viewport().push_input(event, true)
		await process_frame
	await settle()
func finish() -> void:
	check(speech_requests == 0 and speech_starts == 0 and int(app.coach.speech._id) == 0, "Silence : zéro demande et début de parole")
	print("PROFILE READING : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null and app.bridge != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.set_muted(true)
	app.coach.speech.requested.connect(func(_line: String): speech_requests += 1)
	app.coach.speech.started.connect(func(_id: int): speech_starts += 1)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Projection réelle initiale")
	if app.model.is_empty(): finish(); return
	app.timer.stop()
	await command("new_career", {"mode":"common", "club":0})
	if not await Flow.settle_club_meetings(app, self, check): finish(); return
	app._navigate("Effectif"); await settle()
	await command("export")
	var before: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	var path := str(app.model.meta.dataDir).path_join("donnees.json")
	var saved := FileAccess.get_file_as_bytes(path)
	var requests: int = app.bridge._next_id
	var target: Dictionary = app.model.squad[0]
	var search := named("RosterSearch") as LineEdit
	check(search != null, "Champ de recherche de la vraie liste")
	if search == null: finish(); return
	search.text = "___aucun_joueur___"; search.text_changed.emit(search.text)
	await settle()
	await activate(named("Sort_Nom"))
	await activate(named("Sort_Nom"))
	search = named("RosterSearch") as LineEdit
	search.grab_focus(); search.caret_column = 7; search.select(2, 6)
	await settle()
	Reading.remember(app)
	var roster: Dictionary = app.management_ui.roster.duplicate(true)
	check(Reading.players(app.model.squad, roster, int(app.model.meta.season)).is_empty(), "Le filtre réel exclut bien le joueur cible")
	check(app.navigation_controller.open_entity({"kind":"player", "id":str(target.id), "section":"contract"}), "Fiche complète ciblée malgré l’exclusion de la liste")
	await settle()
	check(named("ImmersivePlayerFull") != null and named("ProfilePlayerName").text == str(target.name).to_upper() and app.selected_player == str(target.id), "La fiche montre le bon identifiant et le bon nom hors filtre")
	check(app.management_ui.immersive_player_tab == 3 and app.management_ui.roster == roster, "L’onglet contrat n’altère aucune clé de lecture de la liste")
	await activate(named("PlayerBackToSquad"))
	search = named("RosterSearch") as LineEdit
	check(search != null and search.text == roster.search and app.management_ui.roster.sort == roster.sort and app.management_ui.roster.descending == roster.descending, "Retour natif : recherche et tri conservés")
	check(search != null and search.has_focus() and search.caret_column == 7 and search.get_selection_from_column() == 2 and search.get_selection_to_column() == 6, "Retour natif : focus, curseur et sélection de saisie conservés")
	check(app.selected_player == str(target.id) and not app.get_meta("immersive08_full_player", false), "Retour natif : même joueur sélectionné, sortie de la fiche complète")
	if search == null: finish(); return
	search.text = ""; search.text_changed.emit("")
	await settle()
	var surface := named("SquadScroll") as ScrollContainer
	check(surface != null and surface.get_v_scroll_bar().max_value > surface.get_v_scroll_bar().page, "La vraie liste complète peut défiler")
	if surface == null: finish(); return
	surface.scroll_vertical = mini(120, int(surface.get_v_scroll_bar().max_value - surface.get_v_scroll_bar().page))
	await settle()
	var offset: int = surface.scroll_vertical
	check(offset > 0, "Scroll non nul réellement atteint avant consultation")
	Reading.remember(app)
	var sort_before: String = app.management_ui.roster.sort
	var descending_before: bool = app.management_ui.roster.descending
	check(app.navigation_controller.open_entity({"kind":"player", "id":str(target.id)}), "Deuxième fiche complète depuis la liste défilée")
	await settle()
	await activate(named("PlayerBackToSquad"))
	surface = named("SquadScroll") as ScrollContainer
	check(surface != null and surface.scroll_vertical == offset and app.management_ui.roster.sort == sort_before and app.management_ui.roster.descending == descending_before, "Retour natif : scroll non nul et tri exacts préservés")
	search = named("RosterSearch") as LineEdit
	search.text = "___aucun_joueur___"; search.text_changed.emit(search.text)
	await settle()
	check(app.navigation_controller.open_entity({"kind":"player", "id":str(target.id), "section":"roster"}), "Consultation explicite de ligne toujours disponible")
	await settle()
	check(not app.get_meta("immersive08_full_player", false) and app.management_ui.roster.search.is_empty() and app.management_ui.roster.sort == "Poste", "Seule la demande explicite de ligne réinitialise la liste pour révéler la cible")
	var rows := app.find_children("SquadPlayer*", "Button", true, false)
	check(rows.any(func(row: Button): return str(row.get_meta("player_id", "")) == str(target.id)), "La ligne demandée reste réellement rendue après remise à zéro explicite")
	check(app.bridge._next_id == requests and saved == FileAccess.get_file_as_bytes(path), "Consultations et retours : zéro commande et sauvegarde identique")
	await command("export")
	check(before == JSON.parse_string(app.model.meta.exportText).state, "État sportif et RNG strictement inchangés")
	finish()
