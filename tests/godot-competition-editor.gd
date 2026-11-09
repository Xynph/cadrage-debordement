extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
var directory := OS.get_environment("CD_EDITOR_UI_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	for i in range(10): await process_frame
func wait_response() -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting,"réponse worker reçue")
	await settle()
func ask(command: String, payload: Dictionary = {}) -> void:
	app._command(command,payload)
	await wait_response()
	check(app.bridge.last_response_ok,"commande worker : " + command)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 20000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await ask("new_career",{"mode":"world","club":0})
	await ask("export")
	var original_career: String = app.model.meta.exportText
	var career_file: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(career_file)
	var dialog: AcceptDialog = load("res://ui/competition_editor_view.gd").open(app)
	await settle()
	dialog._generate()
	await wait_response()
	check(is_instance_valid(dialog) and dialog.visible,"succès conserve le vrai dialogue")
	check(not dialog.validated_text.is_empty(),"génération par vrai worker")
	check(dialog.round_choice.item_count == 6,"six journées en aller-retour")
	check(dialog.fixture_output.text.contains("—"),"aperçu rencontres affiché")
	var original: String = dialog.validated_text
	var broken_path := directory.path_join("broken-calendar.json")
	var broken := FileAccess.open(broken_path,FileAccess.WRITE)
	broken.store_string("{invalide")
	broken.close()
	dialog._choose_import()
	for child in dialog.get_children():
		if child is FileDialog: child.file_selected.emit(broken_path)
	await settle()
	check(dialog.export_button.disabled and dialog.copy_button.disabled,"import JSON malformé invalide ancien export et copie")
	check(dialog.json_input.text == "{invalide","import JSON malformé conservé")
	dialog.json_input.text = "{invalide"
	dialog._validate()
	check(dialog.json_input.text == "{invalide","brouillon invalide conservé")
	check(dialog.export_button.disabled,"export invalide désactivé")
	dialog.json_input.text = original
	dialog._validate()
	await wait_response()
	check(dialog.validated_text == original,"validation après correction")
	var doc: Dictionary = JSON.parse_string(original)
	doc.fixtures[0].homeId = doc.fixtures[0].awayId
	dialog.json_input.text = JSON.stringify(doc)
	var rejected: String = dialog.json_input.text
	dialog._validate()
	await wait_response()
	check(not app.bridge.last_response_ok,"refus du vrai worker")
	check(is_instance_valid(dialog) and dialog.visible,"refus conserve dialogue visible")
	check(dialog.json_input.text == rejected,"refus moteur conserve brouillon")
	check(dialog.message.text.contains("conservé"),"erreur moteur visible")
	dialog.json_input.text = original
	dialog._validate()
	await wait_response()
	var destination := directory.path_join("calendar.json")
	dialog._export_to(destination)
	check(FileAccess.file_exists(destination),"export réellement écrit")
	var file := FileAccess.open(destination,FileAccess.READ)
	check(file.get_as_text() == original,"export exact")
	file.close()
	dialog.json_input.text = "{}"
	dialog._choose_import()
	for child in dialog.get_children():
		if child is FileDialog: child.file_selected.emit(destination)
	await wait_response()
	check(dialog.validated_text == original,"import disque revérifié par worker")
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		await settle()
		check(dialog.size.x <= size.x and dialog.size.y <= size.y,"dialogue contenu dans fenêtre")
	dialog.queue_free()
	await settle()
	await ask("export")
	check(app.model.meta.exportText == original_career,"carrière exportée inchangée")
	check(FileAccess.get_file_as_bytes(career_file) == bytes,"disque avec RNG/horloge inchangé")
	await finish()
func finish() -> void:
	var report := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures}))
	report.close()
	app.bridge.stop()
	app.queue_free()
	await settle()
	print(str(checks) + " contrôles UI calendrier")
	quit(0 if failures.is_empty() else 1)
