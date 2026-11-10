extends SceneTree

var app: Control
var checks := 0
var failures: Array[String] = []
var viewport_size: Vector2i
var output := OS.get_environment("QA_OUTPUT")
var evidence: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)
	return condition

func settle() -> void:
	await create_timer(0.2).timeout
	for index in 4:
		await process_frame

func ready_for_input() -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	await settle()
	return check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok,
		"Réponse du moteur : " + str(app.last_command) + " " + str(app.last_error))

func control(id: String) -> Button:
	return app.find_child(id, true, false) as Button

func click(id: String) -> bool:
	var button := control(id)
	if not check(button != null and button.is_visible_in_tree() and not button.disabled, "Bouton utilisable : " + id):
		return false
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await settle()
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	if not check(root.get_visible_rect().has_point(point), "Bouton dans la fenêtre : " + id):
		return false
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()
	return true

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == viewport_size and DisplayServer.window_get_size() == viewport_size,
		"Capture native à la définition demandée : " + name)
	check(image.save_png(output.path_join(name + ".png")) == OK, "Capture enregistrée : " + name)
	evidence.append({"image":name, "route":app.route, "date":app.model.meta.get("calendarToday", ""),
		"caption": app.primary_button.text if is_instance_valid(app.primary_button) else "",
		"header":app.header_date.text if is_instance_valid(app.header_date) else ""})

func run() -> void:
	var dimensions := OS.get_environment("QA_RESOLUTION").split("x")
	viewport_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.mode = Window.MODE_WINDOWED
	root.size = viewport_size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await settle()
	root.size = viewport_size
	if await ready_for_input():
		check(DisplayServer.get_name() == "X11", "Vrai rendu X11 distant")
		match OS.get_environment("QA_SCENARIO"):
			"club": await verify_club()
			"nation": await verify_nation()
			"match": await verify_match()
	await finish()

func verify_club() -> void:
	app._command("new_career", {"mode":"world-champ", "club":102})
	if not await ready_for_input(): return
	if not check(app.route == "Réception" and app.model.international.role == "club", "Nouvelle carrière en club depuis Réception"): return
	check(control("Nav_Bureau") != null, "Bureau toujours accessible")
	check(control("InboxOpenPressInvitation") == null, "La conférence nécessite l'ouverture du courrier")
	await capture("01-reception-club")
	if not await click("InboxOpenInternational"): return
	if not check(app.route == "Sélections", "Le courrier d’offres ouvre les sélections"): return
	var tabs := app.find_child("InternationalTabs", true, false) as TabContainer
	check(tabs != null and tabs.current_tab == 2, "Le courrier d’offres mène à l’onglet Offres")
	await capture("02-offres-internationales")
	if not await click("Nav_Réception") or not await click("InboxPressInvitation"): return
	await capture("03-invitation")
	if not await click("InboxOpenPressInvitation"): return
	if not check(app.route == "Presse", "Lien du courrier vers la conférence"): return
	await capture("04-conference")
	for question: Dictionary in app.model.clubLife.press.conference.questions:
		if not await click("PressAnswer_" + str(question.id) + "_r4"): return
	if not await click("PressSubmit") or not await ready_for_input(): return
	check(not app.model.clubLife.press.conference.required and app.model.clubLife.press.lastOutcome is Dictionary, "Publication prise en compte")
	await capture("05-conference-publiee")
	if not await click("PressBackToInvitation"): return
	if not await click("ImmersiveCalendarDate"): return
	await capture("06-calendrier-club")
	if not await click("ImmersiveContinue") or not await ready_for_input(): return
	check(app.model.meta.calendarToday == "2026-08-18" and app.route == "Calendrier", "Jour ordinaire sans nouvelle priorité")
	await capture("07-calendrier-club-lendemain")
	if not await click("Nav_Effectif") or not await click("OpenPlayerFull"): return
	check(app.find_child("FullPlayerHero", true, false) != null, "La fiche complète du joueur est ouverte")
	check(app.find_child("PlayerIdentityFacts", true, false) != null, "La fiche affiche l’identité sportive et les données projetées")
	await capture("08-fiche-joueur")

func verify_nation() -> void:
	if not await click("EntryNewCareer") or not await click("CreationChooseRole"): return
	var dialog := app.get_node_or_null("CreationRoleDialog") as ConfirmationDialog
	var roles := app.find_child("CreationCareerRole", true, false) as OptionButton
	var nations := app.find_child("CreationCareerNation", true, false) as OptionButton
	if not check(dialog != null and roles != null and nations != null, "Dialogue de choix du mandat"): return
	roles.select(2)
	roles.item_selected.emit(2)
	var france := -1
	for index in nations.item_count:
		if nations.get_item_text(index) == "France": france = index
	if not check(france >= 0, "France proposée au choix du mandat"): return
	nations.select(france)
	dialog.confirmed.emit()
	await settle()
	await capture("01-creation-selection")
	if not await click("CreationStart") or not await ready_for_input(): return
	if not check(app.route == "Réception" and app.model.international.role == "nation" and app.model.international.nation == "FRA",
			"La vraie création choisit uniquement la France"): return
	check(control("Nav_Bureau") == null and control("Nav_Effectif") == null, "Le club d’ancrage reste masqué")
	check(control("InboxPressInvitation") == null, "Le courrier du club d’ancrage reste masqué")
	await capture("02-reception-selection")
	if not await click("InboxOpenInternational"): return
	if not check(app.route == "Sélections", "Nomination ouvre l’espace Sélections"): return
	await capture("03-selections-france")
	var tabs := app.find_child("InternationalTabs", true, false) as TabContainer
	if not check(tabs != null, "Onglets de sélection présents"): return
	tabs.current_tab = 1
	await capture("04-competitions-internationales")
	if not await click("ImmersiveCalendarDate"): return
	if not check(app.route == "Calendrier" and app.find_child("InternationalCalendar", true, false) != null,
			"La date ouvre le calendrier de la France"): return
	await capture("05-calendrier-selection")
	if not await click("ImmersiveContinue") or not await ready_for_input(): return
	check(app.model.meta.calendarToday == "2026-08-18", "La carrière de sélectionneur progresse d’un jour")
	await capture("06-calendrier-selection-lendemain")

func verify_match() -> void:
	if not await click("EntryResume"): return
	var fixture: Variant = app.model.international.currentManagedFixture
	if not check(fixture is Dictionary and app.model.international.role == "nation", "Le vrai moteur expose un match jouable"): return
	check(control("ImmersiveContinue").text == "Jouer la sélection", "Jouer la sélection est le bouton principal")
	await capture("01-match-international-pret")
	if not await click("ImmersiveContinue") or not await ready_for_input(): return
	check(app.route == "Réception" and app.model.international.currentManagedFixture == null, "Le match joué retourne au courrier")
	var result := false
	for event: Dictionary in app.model.international.mail:
		if event.kind == "international_result": result = true
	check(result, "Un résultat international est publié en Réception")
	await capture("02-resultat-international")

func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"display":DisplayServer.get_name(), "checks":checks,
			"failures":failures, "captures":evidence}, "  "))
		file.close()
	print("RECETTE VISUELLE : ", checks, " contrôles ; ", failures.size(), " échecs")
	await app._close(0 if failures.is_empty() else 1)
