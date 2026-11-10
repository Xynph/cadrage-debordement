extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_PREPARATION_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
func settle() -> void:
	for i in 10: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse worker bornée")
	app.timer.stop()
	await settle()
func named(id: String) -> Control: return app.body.find_child(id, true, false)
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
func keyboard(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Commande réellement visible au clavier")
	if control == null: return
	control.grab_focus()
	await settle()
	check(control.has_focus(), "Focus " + str(control.name))
	await key(KEY_ENTER)
	await worker()
func mouse(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Commande réellement visible à la souris")
	if control == null: return
	app.body_scroll.ensure_control_visible(control)
	await settle()
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await worker()
func tab(id: String) -> void:
	await keyboard(named("PreparationTab" + id))
	check(named("Preparation" + id).is_visible_in_tree(), "Sous-onglet visible " + id)
	var visible := 0
	var selected := 0
	for section_id in ["Dossier", "Consignes", "Entrainement"]:
		if named("Preparation" + section_id).is_visible_in_tree(): visible += 1
		if named("PreparationTab" + section_id).button_pressed: selected += 1
	check(visible == 1 and selected == 1, "Un seul onglet et une seule section actifs")
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(proof.path_join(id + ".png")) == OK, "Capture " + id)
func run() -> void:
	# Headless starts with a 64x64 viewport unless the recipe sets it explicitly.
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("import", {"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Préparation")
	await settle()
	check(named("PreparationTabDossier") != null, "Trois vrais sous-onglets de préparation")
	if named("PreparationTabDossier") != null: await cases()
	var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	file.close()
	app.closing = true
	app.bridge.stop()
	print("Préparation : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
func cases() -> void:
	print("PREPARATION_INITIAL ", root.size, " / ", app.size)
	await command("export")
	var before: String = app.model.meta.exportText
	var disk_path := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk_path)
	check(not bytes.is_empty(), "Profil réel pour invariant sauvegarde/RNG")
	await tab("Dossier")
	await key(KEY_RIGHT)
	check(named("PreparationConsignes").is_visible_in_tree() and named("PreparationTabConsignes").has_focus(), "Flèche droite : onglet et focus suivent")
	await key(KEY_RIGHT)
	check(named("PreparationEntrainement").is_visible_in_tree(), "Flèche droite : entraînement accessible")
	await key(KEY_LEFT)
	await key(KEY_TAB)
	await key(KEY_TAB)
	var focus := app.get_viewport().gui_get_focus_owner()
	check(focus != null and str(focus.name).begins_with("PreparationAttack_") and focus.is_visible_in_tree(), "Tab atteint les vraies consignes visibles")
	await mouse(named("PreparationTabDossier"))
	check(named("PreparationDossier").is_visible_in_tree(), "Sélection d’onglet à la souris")
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		for id in ["Dossier", "Consignes", "Entrainement"]:
			await tab(id)
			check(app.body_scroll.get_global_rect().end.y <= app.size.y + 1, "CareerWorkspace borné " + str(resolution))
			if id == "Consignes":
				for list_id in ["PreparationAttackScroll", "PreparationDefenseScroll"]:
					var list: ScrollContainer = named(list_id)
					check(list.size.y >= 190, "190 unités de lecture conservées " + list_id)
					check(list.get_global_rect().end.x <= app.size.x + 1, "Liste sans débordement horizontal")
			print("PREPARATION_GEOMETRY ", JSON.stringify({"window":root.size,"canvas":app.size,"tab":id,"workspace":app.body_scroll.get_global_rect(),"section":named("Preparation" + id).get_global_rect()}))
			if resolution.x == 1280: await capture("preparation-1280-" + id.to_lower())
		await tab("Entrainement")
		var match_button := named("PreparationMatch")
		check(app.body_scroll.get_global_rect().encloses(match_button.get_global_rect()), "Match visible dès ouverture Entraînement " + str(resolution))
		match_button.grab_focus()
		await settle()
		check(app.body_scroll.get_global_rect().encloses(match_button.get_global_rect()), "Accès au match par focus/scroll " + str(resolution))
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	await settle()
	await tab("Consignes")
	var attack_scroll: ScrollContainer = named("PreparationAttackScroll")
	attack_scroll.scroll_vertical = 100
	await settle()
	var scroll_before := attack_scroll.scroll_vertical
	var scroll_bar := attack_scroll.get_v_scroll_bar()
	if ProjectSettings.get_setting("display/window/stretch/mode") == "disabled":
		check(scroll_before > 0, "720p 1:1 : mémoire testée sur un défilement tactique réellement non nul")
	else:
		check(scroll_before > 0 or scroll_bar.max_value <= scroll_bar.page, "Stretch : position réelle ou liste entièrement visible")
	app._render()
	await settle()
	check(named("PreparationConsignes").is_visible_in_tree(), "Rebuild conserve le sous-onglet")
	check(named("PreparationAttackScroll").scroll_vertical == scroll_before, "Rebuild conserve le scroll tactique")
	app._navigate("Bureau")
	await settle()
	app._navigate("Préparation")
	await settle()
	check(named("PreparationConsignes").is_visible_in_tree(), "Navigation conserve le sous-onglet")
	check(named("PreparationAttackScroll").scroll_vertical == scroll_before, "Navigation conserve le scroll tactique")
	await tab("Dossier")
	await mouse(named("OpenOppositionDossier"))
	var dossier := app.find_child("OppositionDossier", true, false)
	check(dossier != null and dossier.visible, "Vrai dossier ouvert à la souris")
	app._clear_dialogs()
	await settle()
	check(FileAccess.get_file_as_bytes(disk_path) == bytes, "Consultation : octets profil inchangés")
	await command("export")
	check(app.model.meta.exportText == before, "Consultation : S et RNG/export identiques")
	await command("new_career", {"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Préparation")
	await settle()
	check(named("PreparationDossier").is_visible_in_tree(), "Nouvelle carrière remet l’onglet Dossier")
	await tab("Consignes")
	var option: Dictionary = app.model.tactics.attacks.filter(func(o):return o.id != app.model.tactics.attack)[0]
	var defense: String = app.model.tactics.defense
	var target_id := "PreparationAttack_" + str(option.id)
	var target: Button = named(target_id)
	await keyboard(target)
	check(app.model.tactics.attack == option.id and app.model.tactics.defense == defense, "Consigne exacte via le vrai clavier, défense conservée")
	check(named("PreparationConsignes").is_visible_in_tree() and named(target_id).has_focus(), "Commande : onglet et focus conservés après rebuild")
	await tab("Entrainement")
	var selected_values: Array[String] = []
	for pair in [["CollectiveFocus", "set_collective_focus"], ["OpponentLevel", "set_opponent_level"]]:
		var choice: OptionButton = named(pair[0])
		check(not choice.disabled, "Choix disponible " + pair[0])
		var index := (choice.selected + 1) % choice.item_count
		var selected: String = choice.get_item_metadata(index)
		selected_values.append(selected)
		var initial := choice.selected
		choice.grab_focus()
		await key(KEY_SPACE)
		for i in initial: await key(KEY_UP)
		for i in index: await key(KEY_DOWN)
		await key(KEY_ENTER)
		await worker()
		check(named(pair[0]).get_item_metadata(named(pair[0]).selected) == selected, "Choix sportif persistant " + pair[1])
		check(named(pair[0]).has_focus(), "Focus du choix conservé après commande " + pair[0])
	check(app.model.decisions.training.collective.selected == selected_values[0] and app.model.decisions.difficulty.selected == selected_values[1], "Projection worker confirme les deux paramètres exacts")
	await keyboard(named("PreparationTrain_normal"))
	check(app.model.meta.trained, "Entraînement réel exécuté")
	check(named("PreparationEntrainement").is_visible_in_tree(), "Entraînement : onglet conservé")
	await command("export")
	var saved: String = app.model.meta.exportText
	await command("import", {"text":saved})
	app._navigate("Préparation")
	await settle()
	check(named("PreparationDossier").is_visible_in_tree(), "Import remet l’onglet Dossier")
	await tab("Consignes")
	check(app.model.tactics.attack == option.id, "Import conserve la vraie consigne")
	await tab("Entrainement")
	check(app.model.meta.trained and named("PreparationTrain_normal").disabled, "Import conserve la séance, sans répétition")
	check(app.model.decisions.training.collective.selected == selected_values[0] and app.model.decisions.difficulty.selected == selected_values[1], "Import conserve les deux paramètres sportifs")
	await keyboard(named("PreparationMatch"))
	check(app.route == "Match", "Accès réel au match")
	for i in 3:
		app._navigate("Préparation")
		app._navigate("Bureau")
	await settle()
	check(app.route == "Bureau", "Navigation rapide avant restauration différée sans erreur")
	var retiring: Control = load("res://ui/preparation_view.gd").build(app)
	app.body.add_child(retiring)
	retiring._restore()
	app.body.remove_child(retiring)
	# Exercise both a deferred call that has not started and one already awaiting.
	retiring._restore()
	await settle()
	retiring.queue_free()
	await settle()
	check(app.route == "Bureau", "Retrait de vue avant et pendant await sans accès à un arbre absent")
