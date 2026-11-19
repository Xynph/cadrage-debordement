extends SceneTree
## Real career/navigation plus an explicitly controlled UI fixture for call-up states.
var app: Control
var checks := 0
var failures: Array[String] = []
var viewport_size := Vector2i(1920, 1080)
const Availability = preload("res://ui/international_availability.gd")

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func settle() -> void:
	for index in 8: await process_frame

func ready_for_input() -> bool:
	var until := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and app.last_error.is_empty() and Time.get_ticks_msec() < until:
		await process_frame
	await settle()
	return not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok

## Part de la hauteur visible laissée vide sous le dernier élément peint d'une page
## (conteneurs de mise en page exclus : ils s'étirent sans rien dessiner ; les panneaux comptent).
func void_ratio(page: Control) -> float:
	if page == null or not is_instance_valid(app.body_scroll): return 1.0
	var viewport: Rect2 = app.body_scroll.get_global_rect()
	var bottom: float = viewport.position.y
	for node: Node in page.find_children("*", "Control", true, false):
		var control := node as Control
		if (control is Container and not control is PanelContainer) or not control.is_visible_in_tree() or control.size.y <= 0: continue
		bottom = maxf(bottom, control.get_global_rect().end.y)
	return maxf(0.0, viewport.end.y - bottom) / maxf(1.0, viewport.size.y)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var file := OS.get_environment("CD_INTERNATIONAL_AVAILABILITY_OUTPUT").path_join(name + ".png")
	var image := root.get_texture().get_image()
	check(image.get_size() == viewport_size, "Définition native de la capture " + name)
	check(image.save_png(file) == OK, "Capture " + name)

func run() -> void:
	var dimension := OS.get_environment("QA_RESOLUTION").split("x")
	viewport_size = Vector2i(int(dimension[0]), int(dimension[1])) if dimension.size() == 2 else Vector2i(1920, 1080)
	root.size = viewport_size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	check(await ready_for_input(), "Démarrage du vrai moteur")
	app.timer.stop()
	app._command("new_career", {"mode":"world-champ", "club":102})
	check(await ready_for_input(), "Création d’une carrière club")
	if app.model.is_empty() or not app.bridge.last_response_ok:
		await app._close(1)
		return
	if DisplayServer.get_name() != "headless":
		if root.size_changed.is_connected(app._keep_filled_display): root.size_changed.disconnect(app._keep_filled_display)
		if root.focus_entered.is_connected(app._keep_filled_display): root.focus_entered.disconnect(app._keep_filled_display)
		root.mode = Window.MODE_WINDOWED
		root.size = viewport_size
		await settle()
	check(app.model.get("international", {}).has("availability"), "Projection réelle des disponibilités exposée")
	# Presse façon FM (18/11/2026) : plus de conférence à la création ; le rendez-vous d'accueil de la direction
	# s'ouvre aussitôt. Il est réglé ici comme le ferait le manager avant d'aller au calendrier.
	for index in 6:
		var scene: Variant = app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene")
		if not scene is Dictionary: break
		if not scene.get("completed", false) and scene.get("ackAllowed", false):
			app._command("club_meeting_ack", {"meetingId":scene.get("id")})
			check(await ready_for_input(), "Rendez-vous d'accueil lu")
			scene = app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene")
		if scene is Dictionary and scene.get("completed", false):
			app._command("club_meeting_continue", {"meetingId":scene.get("id")})
			check(await ready_for_input(), "Rendez-vous d'accueil terminé")
		else: break
	app._navigate("Calendrier")
	await settle()
	var summary := app.find_child("InternationalAvailabilityOpen", true, false) as Button
	check(summary != null, "Calendrier club relié au suivi international")
	if summary != null: summary.pressed.emit()
	await settle()
	check(app.route == "Sélections" and app.management_ui.international_section == "availability", "Le calendrier ouvre le bon onglet")
	await capture("international-disponibilites-reelles-" + str(root.size.x))
	# Sélections vivantes : en-tête illustré, chiffres clés, calendrier international ; aucun grand vide, titre lisible.
	var hero_title := app.find_child("InternationalHeroTitle", true, false) as Label
	check(hero_title != null and hero_title.is_visible_in_tree() and not hero_title.text.is_empty(), "Sélections · titre de l’en-tête visible")
	check(app.heading != null and app.heading.is_visible_in_tree(), "Sélections · titre de la page visible")
	var hero_photo := app.find_child("InternationalHeroPhoto", true, false) as TextureRect
	check(hero_photo != null and hero_photo.texture != null, "Sélections · photo de la banque d’images")
	for id: String in ["InternationalFigureCalled", "InternationalFigureReturn", "InternationalFigureEditions", "InternationalFigureJobs", "InternationalUpcoming", "InternationalNationLinks"]:
		var block := app.find_child(id, true, false) as Control
		check(block != null and block.is_visible_in_tree(), "Sélections · bloc visible " + id)
	var selections_void := void_ratio(app.find_child("InternationalSelections", true, false) as Control)
	check(selections_void <= .30, "Sélections sans vide > 30 %% de la hauteur (%d %%)" % roundi(selections_void * 100))
	var profile: String = app.model.meta.dataDir.path_join("donnees.json")
	var before := FileAccess.get_sha256(profile)
	var own: Array = app.model.squad
	check(own.size() >= 2, "Effectif réel disponible pour les liens de fiche")
	if own.size() < 2:
		await app._close(1)
		return
	var first: Dictionary = own[0]
	var second: Dictionary = own[1]
	app.model.meta.calendarToday = "2027-01-31"
	if app.model.get("calendarPlanning") is Dictionary: app.model.calendarPlanning.today = "2027-01-31"
	app.model.international.availability = {
		"date":"2027-01-31", "clubManaged":true,"absentCount":1,"nextReturn":"2027-02-08","horizonDate":"2027-05-01",
		"positions":[{"position":first.pos,"total":1,"available":0,"called":1,"injured":0}],
		"players":[{"id":first.id,"name":first.name,"pos":first.pos,"nation":"FRA","nationName":"France","competitionId":"six-nations-2027","competitionName":"Tournoi des Six Nations 2027","from":"2027-01-31","through":"2027-02-07","returnDate":"2027-02-08"}],
		"returned":[{"id":second.id,"name":second.name,"pos":second.pos,"nation":"FRA","nationName":"France","competitionName":"Rassemblement de recette","from":"2027-01-20","through":"2027-01-29","returnDate":"2027-01-30"}],
		"windows":[{"competitionId":"six-nations-2027","competitionName":"Tournoi des Six Nations 2027","from":"2027-02-20","through":"2027-03-01","nations":[{"id":"FRA","name":"France"}]}]
	}
	app._navigate("Sélections")
	await settle()
	var coverage := app.find_child("InternationalPositionCoverage", true, false) as Control
	check(coverage != null and coverage.is_visible_in_tree(), "Poste exposé visible dans l’onglet")
	var player_button := app.find_child("InternationalAbsencePlayer_" + str(first.id).replace(":", "_"), true, false) as Button
	check(player_button != null, "Action vers la fiche du joueur convoqué")
	await capture("international-absences-controlees-" + str(root.size.x))
	if player_button != null:
		player_button.grab_focus()
		check(player_button.has_focus(), "Lien de fiche accessible au clavier")
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await settle()
	check(app.route == "Effectif" and app.selected_player == first.id, "Entrée ouvre la bonne fiche réelle")
	Availability.open(app)
	await settle()
	var lineup := app.find_child("InternationalAvailabilityLineup", true, false) as Button
	check(lineup != null, "Accès à la composition disponible")
	if lineup != null: lineup.pressed.emit()
	await settle()
	check(app.route == "Composition", "Le suivi conduit à la composition")
	check(before == FileAccess.get_sha256(profile), "Consultation et liens sans écriture sportive")
	print("DISPONIBILITÉS INTERNATIONALES : %d contrôles ; %d échecs" % [checks, failures.size()])
	var output := OS.get_environment("CD_INTERNATIONAL_AVAILABILITY_OUTPUT")
	if not output.is_empty():
		var report := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"fixture":"real career then explicitly controlled UI projection"}, "  "))
		report.close()
	await app._close(0 if failures.is_empty() else 1)
