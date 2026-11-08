extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var until := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Commande native " + id)
	await settle()
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_STAFF_CAPTURES").path_join(id + ".png")) == OK, "Capture " + id)
func contains_text(node: Node, needle: String) -> bool:
	if node is Label and node.text.contains(needle): return true
	for child in node.get_children():
		if contains_text(child, needle): return true
	return false
func menu_geometry() -> void:
	for button in app.root_content.find_children("*", "Button", true, false):
		if button.text == "MENU & SAUVEGARDES": check(button.get_global_rect().end.y <= app.size.y + 1, "Menu principal dans la fenêtre avec nouveaux écrans")
func run() -> void:
	root.size = Vector2i(1440, 900)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await command("snapshot")
	await command("new_career", {"mode":"common", "club":1})
	var pack := OS.get_environment("CD_STAFF_PACK_QA")
	if not pack.is_empty():
		await command("pack_inspect", {"path":pack})
		var preview: Dictionary = app.model.packs.preview
		check(preview.counts.get("staff", 0) >= 400 and preview.counts.get("staffOfficial", 0) >= 300, "Aperçu du vrai pack staff")
		await command("pack_install", {"path":pack, "digest":preview.digest})
		await command("pack_select", {"id":preview.id, "scope":"career"})
		var decoded := 0
		for team: Dictionary in app.model.staff.teams:
			for person: Dictionary in team.members:
				if str(person.get("portraitPath", "")).is_empty(): continue
				var photo := Image.new()
				check(photo.load(person.portraitPath) == OK, "Portrait staff réellement décodable " + str(person.id))
				decoded += 1
		check(decoded == int(preview.counts.staffOfficial), "Tous les portraits officiels du staff reçus")
	await command("export")
	var before: String = app.model.meta.exportText
	var file: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(file)
	for size in [Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = size; await settle()
		app._navigate("Staff"); await settle(); menu_geometry()
		check(app.body.find_child("CarnetStaff", true, false) != null, "Écran staff natif")
		var choice: OptionButton = app.body.find_child("StaffClub", true, false)
		check(choice != null and choice.item_count == 30, "Les trente staffs sont consultables")
		for club_id in [0, 1, 27, 29]:
			choice = app.body.find_child("StaffClub", true, false)
			choice.select(club_id); choice.item_selected.emit(club_id); await settle()
			check(app.selected_staff_club == club_id, "Choix réel du staff " + str(club_id))
			var expected: int = app.model.staff.teams[club_id].members.size()
			check(expected > 0 and app.body.find_child("StaffCount", true, false).text.begins_with("%d / %d" % [expected, expected]), "Tous les membres documentés apparaissent sans recherche")
			if club_id == 1 and not pack.is_empty():
				check(not app.body.find_children("*", "TextureRect", true, false).is_empty(), "Photographies du vrai staff affichées")
				await capture("staff-portraits-" + str(size.x))
		await capture("staff-" + str(size.x))
		app._navigate("Formation"); await settle(); menu_geometry()
		check(app.body.find_child("CarnetDevelopment", true, false) != null, "Écran formation natif")
		check(contains_text(app.body, "15"), "Quinze espoirs réels au centre de simulation")
		await capture("formation-" + str(size.x))
		app._navigate("Préparation"); await settle()
		var dossier: Button = app.body.find_child("OpenOppositionDossier", true, false)
		check(dossier != null and not dossier.disabled, "Accès au dossier adverse")
		dossier.pressed.emit(); await settle()
		var dialog: AcceptDialog = app.find_child("OppositionDossier", true, false)
		check(dialog != null and dialog.visible and contains_text(dialog, "Joueurs pressentis"), "Vrai dossier avec menaces et limites")
		check(dialog.get_visible_rect().size.y <= app.size.y + 2, "Dossier dans la fenêtre")
		await capture("dossier-" + str(size.x))
		app._clear_dialogs(); await settle()
		check(app.body.find_child("CollectiveFocus", true, false) != null, "Préparation spécifique disponible")
		check(app.body.find_child("OpponentLevel", true, false) != null, "Choix du comportement adverse")
		app._navigate("Recrutement"); await settle()
		var needs: Button = app.body.find_child("OpenRecruitmentNeeds", true, false)
		check(needs != null, "Besoins et missions accessibles")
		needs.pressed.emit(); await settle()
		dialog = app.find_child("RecruitmentNeeds", true, false)
		check(dialog != null and dialog.visible and dialog.find_child("CreateScoutMission", true, false) != null, "Missions et besoins réels dans le carnet")
		app._clear_dialogs(); await settle()
	await command("export")
	check(app.model.meta.exportText == before and bytes == FileAccess.get_file_as_bytes(file), "Navigation des quatre nouveaux parcours sans mutation état/RNG/disque")
	app._navigate("Staff"); await settle()
	var delegated: CheckBox = app.body.find_child("DelegateLineup", true, false)
	check(delegated != null and not delegated.disabled, "Délégation sélection active")
	delegated.button_pressed = true; await settle()
	while app.waiting: await process_frame
	check(app.model.decisions.delegation.lineup, "Contrôle UI réellement transmis au moteur")
	app._navigate("Formation"); await settle()
	var promote: Button
	for button: Button in app.body.find_children("*", "Button", true, false):
		if button.has_meta("promote_id"): promote = button; break
	check(promote != null and not promote.disabled, "Promotion disponible au centre")
	var old_count: int = app.model.squad.size()
	var old_wage: float = app.model.finance.wage
	promote.pressed.emit(); await settle()
	var confirmation: ConfirmationDialog
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible: confirmation = child; break
	check(confirmation != null, "Promotion exige confirmation du salaire")
	if confirmation != null: confirmation.confirmed.emit()
	await settle()
	while app.waiting: await process_frame
	check(app.model.squad.size() == old_count + 1 and app.model.finance.wage == old_wage + 2000, "Promotion UI : identité, groupe et salaire effectifs")
	await capture("formation-promue")
	var output := {"checks":checks, "failures":failures, "privatePack":not pack.is_empty()}
	var report := FileAccess.open(OS.get_environment("CD_STAFF_CAPTURES").path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(output, "  ")); report.close()
	app.closing = true; app.timer.stop(); app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 5000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Moteur de réception arrêté sans orphelin")
	app.queue_free(); await settle()
	print("STAFF/DÉCISIONS : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
