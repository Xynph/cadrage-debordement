extends SceneTree

var checks := 0
var failures: Array[String] = []
var app: Control

func settle() -> void:
	for i in 8: await process_frame

func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse du vrai moteur")
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Commande native : " + id + " " + app.last_error)

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(OS.get_environment("CD_IMMERSIVE_ARTIFACTS").path_join(id + ".png")) == OK, "Capture native : " + id)

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); printerr("FAIL: " + message)

func run() -> void:
	check(ResourceLoader.exists("res://ui/immersive08/components.gd"), "Composants natifs de la DA approuvée disponibles")
	if not failures.is_empty():
		print("immersive08 : ", checks, " contrôles, ", failures.size(), " échecs")
		quit(1)
		return
	var kit: GDScript = load("res://ui/immersive08/components.gd")
	var card: Control = kit.card("TITRE RÉEL", Vector2(600, 400))
	root.add_child(card)
	await process_frame
	check(card is PanelContainer, "Tuile native indépendante")
	check(card.find_child("CardTitle", true, false).text == "TITRE RÉEL", "Titre éditable, pas texte dans une image")
	var button: Button = kit.button("Décider", func(): card.set_meta("action", true), true)
	card.get_meta("content").add_child(button)
	button.pressed.emit()
	check(card.get_meta("action", false), "Bouton fonctionnel")
	check(button.focus_mode == Control.FOCUS_ALL, "Action accessible au clavier")
	var photo: Control = kit.photo("office-hero", Vector2(400, 280))
	card.get_meta("content").add_child(photo)
	check(photo is TextureRect and photo.texture != null, "Illustration décodée par Godot")
	check(photo.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Illustration ne bloque pas les actions")
	for id in ["brand", "tactics-briefing", "training-session", "stadium", "academy-training", "trophy", "scouting", "hospitality", "forest", "player-hero", "recruit-profile", "mail-staff"]:
		var texture: Texture2D = kit.texture(id)
		check(texture != null and texture.get_width() > 0, "Texture native : " + id)
	card.queue_free()
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("new_career", {"club":0, "mode":"fiction"})
	app._navigate("Bureau")
	await settle()
	var output := FileAccess.open(OS.get_environment("CD_IMMERSIVE_ARTIFACTS").path_join("model.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(app.model))
	output.close()
	check(ResourceLoader.exists("res://ui/immersive08/shell.gd"), "Shell immersif natif disponible")
	if ResourceLoader.exists("res://ui/immersive08/shell.gd"):
		var shell: GDScript = load("res://ui/immersive08/shell.gd")
		await command("export")
		var before: String = app.model.meta.exportText
		var disk := str(app.model.meta.dataDir).path_join("donnees.json")
		var bytes := FileAccess.get_file_as_bytes(disk)
		check(shell.render(app), "Rendu natif du Bureau pris en charge")
		await settle()
		for id in ["ImmersiveShell", "ImmersiveSidebar", "ImmersiveTopbar", "OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]:
			check(app.find_child(id, true, false) != null, "Élément réel : " + id)
		check(app.size.x >= 2500, "2560p exploités sans agrandir un canvas 1600p")
		for id in ["OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]:
			var tile: Control = app.find_child(id, true, false)
			if tile == null: continue
			check(tile.get_global_rect().end.x <= app.size.x + 1, "Tuile dans la largeur : " + id)
			check(tile.size.x >= 300, "Largeur utile en 1440p : " + id)
			check(tile.get_global_rect().end.y <= app.body_scroll.get_global_rect().end.y + 1, "Tuile entièrement visible en 1440p : " + id)
		check(app.find_child("Art_office_hero", true, false) != null, "Image originale présente dans le Bureau réel")
		await capture("01-bureau-2560x1440")
		app._navigate("Effectif")
		shell.render(app)
		await settle()
		var roster: Control = app.find_child("ImmersiveRosterTable", true, false)
		check(roster != null, "Table Effectif dense de la référence 1440p")
		if roster != null:
			var list: VBoxContainer = app.find_child("ImmersiveRosterRows", true, false)
			check(list.get_child_count() == app.model.squad.size(), "Tous les joueurs restent consultables")
			for id in ["RosterColumnSalary", "RosterColumnFatigue", "RosterColumnPotential", "PlayerDossier", "OpenPlayerFull", "OfferRenewal", "OpenComparison"]:
				check(app.find_child(id, true, false) != null, "Fonction Effectif : " + id)
			var selected_before: String = app.selected_player
			var target: Dictionary = app.model.squad[1]
			var search: LineEdit = app.find_child("RosterSearch", true, false)
			search.text = str(target.name)
			search.text_changed.emit(search.text)
			await settle()
			check(list.get_child_count() == 1, "Recherche réelle réduit la liste")
			check(app.selected_player == selected_before, "Filtrer conserve le dossier lu")
			var person: Button = list.get_child(0)
			person.pressed.emit()
			await settle()
			check(app.selected_player == str(target.id), "Sélection exacte par ID")
			check(str(app.find_child("PlayerDossier", true, false).get_meta("player_id", "")) == str(target.id), "Dossier actualisé sans changer la carrière")
			search.text = ""
			search.text_changed.emit("")
			await settle()
			check(list.get_child_count() == app.model.squad.size(), "Effacer la recherche retrouve le groupe complet")
			await capture("02-effectif-2560x1440")
		for pair in [["OfficePreparationAction", "Préparation"], ["OfficeSquadAction", "Effectif"], ["OfficeStandingsAction", "Classements"], ["OfficeCalendarAction", "Calendrier"]]:
			app._navigate("Bureau")
			shell.render(app)
			await settle()
			var action: Button = app.find_child(pair[0], true, false)
			check(action != null, "Action réelle : " + pair[0])
			if action != null:
				action.pressed.emit()
				await settle()
				check(app.route == pair[1], "Navigation : " + pair[0])
		await command("export")
		check(before == app.model.meta.exportText, "Rendu et navigation préservent état et RNG")
		check(bytes == FileAccess.get_file_as_bytes(disk), "Rendu et navigation ne modifient aucun octet du profil")
	app.queue_free()
	await settle()
	print("immersive08 : ", checks, " contrôles, ", failures.size(), " échecs")
	quit(0 if failures.is_empty() else 1)
