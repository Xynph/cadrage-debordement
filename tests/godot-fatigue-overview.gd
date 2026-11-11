extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Fatigue = preload("res://ui/immersive08/fatigue_overview.gd")
const Watch = preload("res://ui/management_state.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL: ", label)

func settle() -> void:
	for frame in 8: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	await settle()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok, "Réponse du vrai moteur : " + str(app.last_error))

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_engine()

func press(id: String) -> void:
	var button := app.find_child(id, true, false) as Button
	check(button != null and not button.disabled and button.is_visible_in_tree(), "Action accessible : " + id)
	if button != null and not button.disabled: button.pressed.emit()
	await settle()

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(2560, 1440), "Capture native 1440p")
	var file := OS.get_environment("CD_FATIGUE_OUTPUT").path_join(id + ".png")
	check(image.save_png(file) == OK, "Capture : " + id)
	captures.append(file)

func scrolling_case(scroll_name: String, row_pattern: String, row_type: String, header_name: String) -> void:
	var scroll := app.find_child(scroll_name, true, false) as ScrollContainer
	var header := app.find_child(header_name, true, false) as Button
	var rows := app.find_children(row_pattern, row_type, true, false)
	check(rows.size() == app.model.squad.size(), "Effectif complet sans pagination : " + scroll_name)
	var ids := {}
	for row in rows: ids[str(row.get_meta("player_id"))] = true
	check(ids.size() == app.model.squad.size(), "Tous les identifiants sans limite ni doublon : " + scroll_name)
	var header_y := header.global_position.y
	var first_y: float = rows[0].global_position.y
	var panel_y: float = scroll.get_parent().global_position.y
	var point := scroll.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	root.push_input(motion, true)
	for index in 4:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.position = point; event.global_position = point
		event.pressed = true; event.factor = 3.0
		root.push_input(event, true)
		await process_frame
	await settle()
	check(scroll.scroll_vertical > 0 and rows[0].global_position.y < first_y, "La molette fait défiler les lignes : " + scroll_name)
	check(header.global_position.y == header_y and scroll.get_parent().global_position.y == panel_y, "En-tête et panneau fixes pendant le défilement : " + scroll_name)
	scroll.scroll_vertical = 0
	await settle()

func projection_cases() -> void:
	var players: Array = [
		{"id":"healthy", "condition":95, "physicalLoad":0, "injury":0},
		{"id":"old-load", "condition":95, "physicalLoad":55, "injury":0},
		{"id":"condition", "condition":75, "physicalLoad":0, "injury":0},
		{"id":"injured", "condition":95, "physicalLoad":0, "injury":2},
		{"id":"suspended", "condition":95, "physicalLoad":0, "injury":0, "suspension":2},
		{"id":"called", "condition":95, "physicalLoad":0, "injury":0},
	]
	var fixture := {"squad":players,"international":{"availability":{"players":[{"id":"called","returnDate":"2027-03-21"}]}}}
	var before := JSON.stringify(fixture)
	var data := Fatigue.overview(fixture)
	check(data.rows.size() == 6 and data.counts.watched == 1, "Surveillance commune : condition 75 retenue, ancienne charge 55 écartée")
	check(data.counts.injured == 1 and data.counts.suspended == 1 and data.counts.called == 1, "Blessure, suspension projetée et sélection distinctes")
	check(data.counts.suspension_unknown == 5, "Une suspension absente reste non renseignée")
	for filter in ["À ménager", "Blessés", "Suspendus", "En sélection"]:
		check(Fatigue.overview(fixture, filter).rows.size() == 1, "Filtre exact : " + filter)
	var called: Dictionary = Fatigue.overview(fixture, "En sélection").rows[0]
	check(not called.injured and not called.suspended and str(called.reasons[0]).contains("21/03/2027"), "Sélection sans fausse blessure ou suspension, retour projeté lisible")
	check(Watch.watch_reason({"physicalLoad":69.9,"condition":80}).is_empty(), "Borne sous 70 et condition 80 sans alerte")
	check(not Watch.watch_reason({"physicalLoad":70,"condition":80}).is_empty(), "Charge 70 sous surveillance")
	check(not Watch.watch_reason({"physicalLoad":0,"condition":79.9}).is_empty(), "Condition sous 80 sous surveillance")
	check(JSON.stringify(fixture) == before, "Filtres et tri sans mutation de la projection")
	sort_cases()

func sort_cases() -> void:
	var players := [
		{"id":"b","name":"Zèbre","pos":"Pilier droit","condition":91,"physicalLoad":72,"minutes":200,"injury":2,"suspension":2,"loadPlan":"repos"},
		{"id":"a2","name":"Alpha","pos":"Ailier","condition":65,"physicalLoad":10,"minutes":10,"injury":0,"suspension":0,"loadPlan":"collective"},
		{"id":"a","name":"Alpha","pos":"Ailier","condition":65,"physicalLoad":10,"minutes":10,"injury":0,"suspension":0,"loadPlan":"collective"},
		{"id":"0-unknown"},
	]
	var model := {"squad":players}
	var before := JSON.stringify(model)
	for key in Fatigue.SORT_KEYS:
		if key == "selection": continue
		var text_status: bool = key in ["injury", "suspension", "loadPlan"]
		for descending in [false, true]:
			var ids: Array = Fatigue.overview(model, "Tout l’effectif", key, descending).rows.map(func(row: Dictionary): return row.player.id)
			var expected := ["b", "a", "a2", "0-unknown"] if (text_status and not descending) or (not text_status and descending) else ["a", "a2", "b", "0-unknown"]
			check(ids == expected, "Deux sens, égalité stable et inconnu dernier : " + key + " / " + str(descending))
	for descending in [false, true]:
		var unknowns: Array = Fatigue.overview(model, "Tout l’effectif", "selection", descending).rows.map(func(row: Dictionary): return row.player.id)
		check(unknowns == ["0-unknown", "a", "a2", "b"], "Sélections toutes inconnues : départage stable par ID")
	model.international = {"availability":{"players":[{"id":"b","returnDate":"2027-03-21"}]}}
	for descending in [false, true]:
		var ids: Array = Fatigue.overview(model, "Tout l’effectif", "selection", descending).rows.map(func(row: Dictionary): return row.player.id)
		check(ids == (["b", "0-unknown", "a", "a2"] if descending else ["0-unknown", "a", "a2", "b"]), "Sélection triée selon le texte visible dans les deux sens")
	model.erase("international")
	check(JSON.stringify(model) == before, "Trier ne modifie aucune valeur de l’effectif source")

func run() -> void:
	projection_cases()
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	if app.model.is_empty(): quit(1); return
	app.timer.stop()
	await command("new_career", {"mode":"common", "club":29})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app.coach.close()
	var filename: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var unchanged := FileAccess.get_sha256(filename)
	var player: Dictionary = app.model.squad[0]
	var original_plans := {}
	for person: Dictionary in app.model.squad: original_plans[person.id] = person.loadPlan
	var requests: int = app.bridge._next_id
	app.Immersive.open_training(app)
	await settle()
	await press("TrainingTab4")
	check(app.find_child("FatigueTable", true, false) != null, "Tableau fatigue raccordé à Entraînement")
	await press("FatigueFilter4")
	var scroll := app.find_child("FatigueScroll", true, false) as ScrollContainer
	var visible_rows := 0
	for row in app.find_children("FatigueRow_*", "Control", true, false):
		if row.get_global_rect().intersection(scroll.get_global_rect()).size.y >= 28:
			visible_rows += 1
	check(visible_rows >= 20, "Au moins vingt joueurs visibles dans le tableau dense à 1440p")
	await scrolling_case("FatigueScroll", "FatigueRow_*", "Control", "FatigueSort_name")
	for key in Fatigue.SORT_KEYS:
		for descending in [false, true]:
			await press("FatigueSort_" + key)
			var header := app.find_child("FatigueSort_" + key, true, false) as Button
			check(header.text.ends_with("↓" if descending else "↑"), "Flèche du tri fatigue : " + key)
			check(app.management_ui.immersive_training.fatigue_filter == "Tout l’effectif", "Filtre fatigue conservé pendant le tri")
			var rows := app.find_children("FatigueRow_*", "Control", true, false)
			var expected: Array = Fatigue.overview(app.model, "Tout l’effectif", key, descending).rows
			check(rows[0].get_meta("player_id") == expected[0].player.id, "Ordre réellement rendu après tri fatigue")
	await press("TrainingTab2")
	await scrolling_case("TrainingIndividualsScroll", "TrainingIndividual_*", "Button", "TrainingIndividualSort_name")
	for key in ["name", "pos", "condition", "physicalLoad", "loadPlan"]:
		for descending in [false, true]:
			await press("TrainingIndividualSort_" + key)
			var header := app.find_child("TrainingIndividualSort_" + key, true, false) as Button
			check(header.text.ends_with("↓" if descending else "↑"), "Flèche du tri individuel : " + key)
			var rows := app.find_children("TrainingIndividual_*", "Button", true, false)
			var expected := Fatigue.sorted_players(app.model.squad, key, descending)
			check(rows[0].get_meta("player_id") == expected[0].id, "Ordre réellement rendu après tri individuel")
	await press("TrainingTab4")
	check(app.bridge._next_id == requests and FileAccess.get_sha256(filename) == unchanged, "Tous les tris des deux tableaux : aucune commande ni écriture sportive")
	var row_id := "FatigueAdjust_" + Fatigue.identifier(str(player.id))
	var adjust := app.find_child(row_id, true, false) as Button
	check(adjust != null and adjust.get_meta("player_id") == player.id, "Action liée au bon identifiant réel")
	await press(row_id)
	await press("FatiguePlan_repos")
	var confirmation: ConfirmationDialog
	for dialog in app.find_children("*", "ConfirmationDialog", true, false):
		if dialog.visible: confirmation = dialog
	check(confirmation != null and confirmation.dialog_text.contains(str(player.name)), "Confirmation explicite nomme le bon joueur")
	check(app.bridge._next_id == requests and FileAccess.get_sha256(filename) == unchanged, "Lecture et proposition non confirmée : zéro commande et zéro écriture sportive")
	await capture("fatigue-confirmation-individuelle-1440")
	if confirmation != null: confirmation.canceled.emit()
	await settle()
	check(app.bridge._next_id == requests, "Annuler conserve le profil sans requête")
	await press(row_id)
	await press("FatiguePlan_repos")
	confirmation = null
	for dialog in app.find_children("*", "ConfirmationDialog", true, false):
		if dialog.visible: confirmation = dialog
	if confirmation != null: confirmation.confirmed.emit()
	await wait_engine()
	check(app.bridge._next_id == requests + 1 and app.last_command == "set_player_load", "Une seule commande au clic confirmé")
	for person: Dictionary in app.model.squad:
		check(person.loadPlan == ("repos" if person.id == player.id else original_plans[person.id]), "Plan du bon joueur uniquement : " + str(person.id))
	check(not app.model.meta.trained, "Changer le plan ne lance pas la séance")
	await capture("fatigue-carriere-reelle-1440")
	# Read-only UI fixture to make all availability categories visually reviewable.
	var original: Dictionary = app.model.duplicate(true)
	var profile_hash := FileAccess.get_sha256(filename)
	app.model.squad[0].condition = 75
	app.model.squad[0].physicalLoad = 82
	app.model.squad[1].injury = 2
	app.model.squad[2].suspension = 1
	app.model.international = {"availability":{"players":[{"id":app.model.squad[3].id,"returnDate":"2027-03-21"}]}}
	app.management_ui.immersive_training.fatigue_filter = "Tout l’effectif"
	app._render()
	await settle()
	await capture("fatigue-projection-de-recette-1440")
	check(FileAccess.get_sha256(filename) == profile_hash, "Projection UI illustrative sans écriture du vrai profil")
	var table := app.find_child("FatigueTable", true, false)
	for label: Label in table.find_children("*", "Label", true, false):
		check(label.get_theme_font_size("font_size") >= 16, "Texte dense au moins 16 px à 1440p")
	app.model = original
	app.model.meta.trained = true
	check(not Fatigue.load_blocker(app).is_empty(), "Séance effectuée : plan verrouillé avec motif")
	app.model.meta.trained = false
	app.model.meta.phase = "ended"
	check(not Fatigue.load_blocker(app).is_empty(), "Fin de saison : plan verrouillé avec motif")
	var file := FileAccess.open(OS.get_environment("CD_FATIGUE_OUTPUT").path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"display":DisplayServer.get_name(),"note":"La capture fatigue-projection-de-recette-1440 injecte uniquement la projection UI ; le profil moteur reste intact."}, "  "))
	file.close()
	print("FATIGUE : %d contrôles ; %d échecs" % [checks, failures.size()])
	await app._close(0 if failures.is_empty() else 1)
