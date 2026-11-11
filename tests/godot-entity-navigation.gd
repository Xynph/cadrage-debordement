extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Link = preload("res://ui/entity_link.gd")
var app: Control
var checks := 0
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

func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
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
	check(not nav.open_entity({"kind":"menu", "route":"Presse"}), "La presse ne s’ouvre pas par une route générique")
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
	check(not is_instance_valid(source) and app.route == "Recrutement", "Fenêtre consultation fermée seulement après succès")
	var link := Link.button(app, "Nom connu", {"kind":"player", "id":player_id}, "EntityNavigationLink")
	app.root_content.add_child(link)
	check(link.focus_mode == Control.FOCUS_ALL and link.accessibility_name.contains("Nom connu") and link.get_meta("entity_id") == player_id, "Lien clavier et libellé accessible partagent le même ID")
	link.queue_free()
	check(app.last_command == previous_command, "Toutes les ouvertures restent sans commande worker")
	check(saved == FileAccess.get_file_as_bytes(save_path), "Sauvegarde sportive inchangée octet pour octet")
	await command("export")
	check(before == JSON.parse_string(app.model.meta.exportText).state, "État sportif et RNG exportés strictement inchangés")
	print("ENTITY NAVIGATION : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
