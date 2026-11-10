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
		await verify_club()
	await finish()

func fixture(id: String, date: String, away: String, result: Variant = null) -> Dictionary:
	return {"id":id, "date":date, "homeId":"FRA", "awayId":away, "result":result}

func edition(id: String, title: String, year: int, fixtures: Array) -> Dictionary:
	return {"id":id, "name":title, "year":year, "fixtures":fixtures, "tables":[{"pool":null,"rows":[{"teamId":"FRA","rank":1,"played":1,"points":4}]}]}

func choose(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)
	await settle()

func verify_club() -> void:
	app._command("new_career", {"mode":"world-champ", "nationalRole":"nation", "nation":"FRA"})
	if not await ready_for_input(): return
	var today: String = app.model.meta.calendarToday
	var played := fixture("today", today, "FIJ", {"home":42, "away":12})
	var next := fixture("next", "2026-08-30", "ENG")
	var games: Array = [fixture("historic", "2026-08-01", "WAL"), played, next]
	for day in range(1, 16):
		games.append(fixture("future-"+str(day), "2026-09-%02d" % day, "IRE"))
	var international: Dictionary = app.model.international
	international.editions = [
		edition("six-nations-2025", "Six Nations 2025", 2025, []),
		edition("six-nations-2026", "Six Nations 2026", 2026, games),
		edition("autumn-2026", "Tournoi d’automne", 2026, []),
		edition("six-nations-2027", "Six Nations 2027", 2027, []),
	]
	international.currentManagedFixture = null
	international.nextManagedFixture = next
	app.management_ui.international_section = "editions"
	if not await click("Nav_Sélections"): return
	var years := app.find_child("InternationalEditionYear", true, false) as OptionButton
	if not check(years != null, "Filtre des années disponible"): return
	check(years.item_count == 3 and years.get_item_text(years.selected) == "2026", "L’année simulée est sélectionnée")
	var editions := app.find_child("InternationalEdition", true, false) as OptionButton
	check(editions != null and editions.item_count == 2 and editions.get_item_text(1).contains("2026"), "Seulement les éditions de l’année, avec année explicite")
	await capture("01-competitions-2026")
	var mode := app.find_child("InternationalEditionMode", true, false) as OptionButton
	if not check(mode != null, "Classement et Rencontres disponibles"): return
	await choose(mode, 1)
	var rows := app.find_children("InternationalFixture_*", "Label", true, false)
	check(rows.size() == 10, "Dix rencontres maximum sur la première page")
	if not await click("InternationalFixtureNext"): return
	rows = app.find_children("InternationalFixture_*", "Label", true, false)
	check(rows.size() == 8, "Le solde des rencontres est accessible sur la page suivante")
	await capture("02-rencontres-page2")
	years = app.find_child("InternationalEditionYear", true, false) as OptionButton
	await choose(years, 2)
	editions = app.find_child("InternationalEdition", true, false) as OptionButton
	check(editions != null and editions.item_count == 1 and editions.get_item_text(0).contains("2027"), "Changer d’année isole les éditions de 2027")
	await capture("03-competitions-2027")
	if not await click("ImmersiveCalendarDate"): return
	var current := app.find_child("InternationalTodayFixture", true, false) as Label
	var following := app.find_child("InternationalNextFixture", true, false) as Label
	check(current != null and current.text.contains("Fidji") and current.text.contains("42"), "Le calendrier garde le résultat du jour")
	check(following != null and following.text.contains("Angleterre"), "Le calendrier affiche la prochaine échéance")
	if not await click("InternationalCalendarCompetitions"): return
	check(app.route == "Sélections", "Le calendrier renvoie aux archives de compétitions")
	if not await click("ImmersiveCalendarDate"): return
	await capture("04-calendrier-proche")
	await verify_host()

func verify_host() -> void:
	var host_edition := edition("qa-tournament-2027", "Tournoi de recette", 2027, [])
	host_edition.host = {"countries":[
			{"id":"NZL","name":"Nouvelle-Zélande","capital":"Wellington","details":["Accueil du groupe A."]},
			{"id":"AUS","name":"Australie","capital":"Canberra","details":[]}],
		"finalCountry":"AUS", "city":"Sydney", "stadium":"Stade du Parc",
		"opens":"2027-10-01", "ends":"2027-11-13", "announcementDate":"2026-08-17"}
	app.model.international.editions.append(host_edition)
	var event := {"id":"host/" + str(host_edition.id), "kind":"international_host",
		"title":"Annonce du pays hôte", "body":"Consultez les informations d’accueil du tournoi.",
		"date":"2026-08-17", "action":"international"}
	app.model.international.mail.push_front(event)
	app.management_ui.international_editions = {"year":2025,"edition":"six-nations-2025","mode":0}
	app._reset_reception("international:" + event.id)
	app._navigate("Réception", false)
	await settle()
	var action := control("InboxOpenInternational")
	if not check(action != null and action.text.contains("accueil") and action.text.contains("2027"), "Le courrier ouvre l’accueil de 2027"): return
	await capture("05-courrier-hote")
	if not await click("InboxOpenInternational"): return
	var filter := app.find_child("InternationalEditionYear", true, false) as OptionButton
	var editions := app.find_child("InternationalEdition", true, false) as OptionButton
	var mode := app.find_child("InternationalEditionMode", true, false) as OptionButton
	check(app.route == "Sélections" and filter.get_item_text(filter.selected) == "2027",
		"Le courrier remplace l’ancien filtre d’année")
	check(editions.get_item_text(editions.selected) == "Tournoi de recette · 2027",
		"Le courrier sélectionne l’édition exacte parmi les éditions 2027")
	check(mode.get_item_text(mode.selected) == "Accueil", "La fiche Accueil s’ouvre directement")
	var card := app.find_child("InternationalHostDetails", true, false) as Control
	if not check(card != null and card.is_visible_in_tree(), "La fiche hôte est visible"): return
	var labels: Array[String] = []
	for label: Label in card.find_children("*", "Label", true, false):
		labels.append(label.text)
	var text := "\n".join(labels)
	check(text.contains("Nouvelle-Zélande") and text.contains("Wellington") and text.contains("Accueil du groupe A."),
		"Pays, capitale et détail d’accueil")
	check(text.contains("Australie") and text.contains("Sydney") and text.contains("Stade du Parc"),
		"Pays, ville et stade de la finale")
	check(text.contains("01/10/2027") and text.contains("13/11/2027") and text.contains("17/08/2026"),
		"Ouverture, clôture et date d’annonce")
	check(not text.contains("estim") and not text.contains("déterminer") and not text.contains("<null>"),
		"Présentation sans marque d’estimation ni valeur fictive de remplacement")
	await capture("06-accueil-edition")

func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"display":DisplayServer.get_name(), "checks":checks,
			"failures":failures, "captures":evidence}, "  "))
		file.close()
	print("RECETTE VISUELLE : ", checks, " contrôles ; ", failures.size(), " échecs")
	await app._close(0 if failures.is_empty() else 1)
