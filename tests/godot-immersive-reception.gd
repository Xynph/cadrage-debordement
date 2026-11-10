extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var directory := OS.get_environment("CD_RECEPTION_UI_ARTIFACTS")
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
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 20000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await ask("new_career",{"mode":"world","club":0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await ask("export")
	var saved: String = app.model.meta.exportText
	var profile: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(profile)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		app.management_ui.immersive08_club_tab = "history"
		app.management_ui.club_tab = 1
		app._navigate("Club"); await settle()
		var analysis: Node = app.root_content.find_child("PerformanceAnalysis",true,false)
		check(analysis != null,"Analyses accessibles via Club/Histoire Monde " + str(resolution))
		if analysis != null: check(analysis.is_visible_in_tree(),"Panneau analyses réellement visible")
		app._navigate("Staff"); await settle()
		var mentor: Button = app.root_content.find_child("StaffMentoringOpen",true,false)
		check(mentor != null,"Entrée mentorat dans vraie route Staff")
		if mentor != null:
			mentor.pressed.emit(); await settle()
			check(app.get_node_or_null("StaffMentoringOverview") != null,"Dialogue mentorat ouvert")
		app._clear_dialogs(); await settle()
		app._navigate("Formation"); await settle()
		var youth: Button = app.root_content.find_child("OpenYouthDevelopment",true,false)
		check(youth != null,"Entrée suivi des jeunes dans Formation")
		if youth != null:
			youth.pressed.emit(); await settle()
			check(app.find_child("YouthReviewFilter",true,false) != null,"Bilan jeunes ouvert")
		app._clear_dialogs(); await settle()
		app._navigate("Packs"); await settle()
		var editor: Button
		for button in app.root_content.find_children("*","Button",true,false):
			if "CALENDRIER" in button.text.to_upper(): editor = button
		check(editor != null,"Entrée atelier dans vraie route Packs")
		if editor != null:
			editor.pressed.emit(); await settle()
			check(app.get_node_or_null("CompetitionEditorDialog") != null,"Atelier ouvert depuis Packs")
		app._clear_dialogs(); await settle()
	await ask("export")
	check(app.model.meta.exportText == saved,"Réception sans mutation de carrière/RNG")
	check(FileAccess.get_file_as_bytes(profile) == bytes,"Réception sans mutation disque")
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report)); file.close()
	print("Réception immersive : %d contrôles, %d échecs" % [checks,failures.size()])
	app.bridge.stop(); app.queue_free(); await settle()
	quit(0 if failures.is_empty() else 1)
