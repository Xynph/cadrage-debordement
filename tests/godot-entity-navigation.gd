extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Link = preload("res://ui/entity_link.gd")
var app: Control
var checks := 0
var speech_requests := 0
var speech_starts := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in 6: await process_frame

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Worker réel · " + id)
	await settle()

func back_shortcut() -> void:
	app.get_viewport().gui_release_focus()
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_LEFT; event.alt_pressed = true; event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()

func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach):
		app.coach.speech.set_muted(true)
		app.coach.speech.requested.connect(func(_line: String): speech_requests += 1)
		app.coach.speech.started.connect(func(_id: int): speech_starts += 1)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Projection initiale reçue")
	app.timer.stop()
	await command("new_career", {"club":0, "mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	var nav: Node = app.navigation_controller
	app._navigate("Bureau")
	await settle()
	var player_id := str(app.model.squad[0].id)
	var market_id := str(app.model.market[0].id)
	await command("export")
	var before: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	var save_path := str(app.model.meta.dataDir).path_join("donnees.json")
	var saved := FileAccess.get_file_as_bytes(save_path)
	var previous_command: String = app.last_command
	check(nav.entity_available({"kind":"player", "id":player_id}), "Contrat ID joueur de l’effectif disponible")
	check(nav.entity_available({"kind":"player", "id":market_id}), "Contrat joueur hors club résolu depuis le marché projeté")
	var route: String = app.route
	var reading: Dictionary = app.management_ui.duplicate(true)
	check(not nav.open_entity({"kind":"player", "id":"__absent__"}), "Identifiant inconnu refusé")
	check(not nav.open_entity({"kind":"invented", "id":player_id}), "Type inconnu refusé")
	check(not nav.open_entity({"kind":"menu", "route":"__absente__"}), "Route inconnue refusée")
	check(app.route == route and app.management_ui == reading and app.last_command == previous_command, "Refus sans mutation de lecture ni commande")
	check(nav.open_entity({"kind":"player", "id":player_id, "section":"contract"}), "Fiche contrat ouverte par ID")
	await settle()
	check(app.route == "Effectif" and app.selected_player == player_id and app.get_meta("immersive08_full_player", false) and app.management_ui.immersive_player_tab == 3, "Fiche complète et onglet contrat ciblés")
	app.management_ui.immersive_training = {"tab":2, "fatigue_filter":"Tous", "fatigue_sort":"Charge", "fatigue_descending":true, "fatigue_load_bin":2, "fatigue_scroll":41}
	var training_draft: Dictionary = app.management_ui.immersive_training.duplicate(true)
	app.management_ui.preparation = {"tab":0, "outer":[0,0,0], "attack":1, "defense":2, "focus":["","",""]}
	check(nav.open_entity({"kind":"player", "id":market_id}), "Même contrat joueur ouvre la piste connue hors club")
	await settle()
	check(app.route == "Recrutement" and app.management_ui.market.navigation_id == market_id, "Dossier hors club strictement filtré par ID")
	app.management_ui.immersive_training.fatigue_load_bin = 4
	nav._travel(-1)
	await settle()
	check(app.route == "Effectif" and app.selected_player == player_id and app.management_ui.immersive_player_tab == 3, "Retour rétablit fiche et section précédentes")
	check(app.management_ui.immersive_training == training_draft, "Retour préserve les filtres, tri et brouillon de charge")
	var blocker := AcceptDialog.new()
	blocker.name = "EntityNavigationBusinessDialog"
	app.add_child(blocker)
	blocker.popup_centered(Vector2i(350, 200))
	await settle()
	reading = app.management_ui.duplicate(true)
	check(not nav.open_entity({"kind":"market", "id":market_id}, blocker), "Une fenêtre métier ne peut s’exempter de la garde")
	check(blocker.visible and app.management_ui == reading and app.route == "Effectif", "Fenêtre et brouillon restent intacts après refus")
	await back_shortcut()
	check(blocker.visible and app.management_ui == reading and app.route == "Effectif", "Alt gauche ne ferme pas une fenêtre métier")
	blocker.queue_free()
	await settle()
	var source := AcceptDialog.new()
	source.name = "EntityNavigationReadOnlyDialog"
	source.set_meta("navigation_read_only", true)
	app.add_child(source)
	source.popup_centered(Vector2i(350, 200))
	await settle()
	check(nav.open_entity({"kind":"market", "id":market_id}, source), "Un lien depuis une fenêtre de consultation validée ouvre sa cible")
	await settle()
	check(is_instance_valid(source) and not source.visible and nav.is_suspended_reader(source) and app.route == "Recrutement", "Fenêtre consultation suspendue seulement après succès")
	nav._travel(-1)
	await settle()
	check(is_instance_valid(source) and source.visible and app.route == "Effectif", "Retour restitue la même fenêtre de consultation")
	source.queue_free()
	await settle()
	# Fast real-client regression: no new career or simulated week is required.
	app._navigate("Bureau")
	await settle()
	# Le club ouvre son écran (fiche club ; le club du manager, l'écran « Club ») : plus de lecteur en fenêtre, retour par l'historique.
	check(nav.open_entity({"kind":"club", "id":str(app.model.club.id)}), "Page vers l'écran du club")
	await settle()
	check(app.route == "Club" and not nav._blocked(), "Le club s'ouvre comme un écran, sans fenêtre modale")
	await back_shortcut()
	check(app.route == "Bureau" and not nav._blocked(), "Alt gauche revient à la page d'origine")
	check(nav._page_readers.is_empty(), "Aucun registre de lecteur racine : le club n'est plus une fenêtre")
	check(nav.open_entity({"kind":"club", "id":str(app.model.club.id)}), "Deuxième ouverture du club pour le retour après fiche joueur")
	await settle()
	check(nav.open_entity({"kind":"player", "id":player_id}), "Page → club → fiche joueur par identifiants projetés")
	await settle()
	check(app.route == "Effectif", "La fiche joueur s'ouvre depuis le club")
	await back_shortcut()
	check(app.route == "Club", "Retour joueur restitue l'écran du club")
	await back_shortcut()
	check(app.route == "Bureau" and not nav._blocked(), "Deuxième retour revient à la page d'origine")
	var link := Link.button(app, "Nom connu", {"kind":"player", "id":player_id}, "EntityNavigationLink")
	app.root_content.add_child(link)
	check(link.focus_mode == Control.FOCUS_ALL and link.accessibility_name.contains("Nom connu") and link.get_meta("entity_id") == player_id, "Lien clavier et libellé accessible partagent le même ID")
	link.queue_free()
	check(app.last_command == previous_command, "Toutes les ouvertures restent sans commande worker")
	check(saved == FileAccess.get_file_as_bytes(save_path), "Sauvegarde sportive inchangée octet pour octet")
	await command("export")
	check(before == JSON.parse_string(app.model.meta.exportText).state, "État sportif et RNG exportés strictement inchangés")
	var speech_id := int(app.coach.speech._id) if is_instance_valid(app.coach) else 0
	check(speech_requests == 0 and speech_starts == 0 and speech_id == 0, "Silence : zéro demande, zéro début et identifiant zéro")
	print("ENTITY_SPEECH ", JSON.stringify({"requests":speech_requests,"starts":speech_starts,"id":speech_id}))
	print("ENTITY NAVIGATION : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
