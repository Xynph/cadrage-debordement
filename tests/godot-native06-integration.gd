extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
class Reception extends "res://qa_runner.gd":
	func _ready() -> void: pass
var app: Control
var qa: Node
var failures: Array[String] = []
var checks := 0
var directory := OS.get_environment("CD_NATIVE06_ARTIFACTS")
var cues: Array[String] = []
var received: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	for i in 8: await process_frame
func ask(command: String, payload: Dictionary = {}, allow_refusal: bool = false) -> void:
	app._command(command,payload)
	var deadline := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and (allow_refusal or app.bridge.last_response_ok), "Vrai worker : " + command)
	app.timer.stop(); await settle()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec() + 20000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty() and app.soundscape_ready and app.sound_profile_loaded,"Vrai shell, worker, gestionnaire et profil sonore raccordés")
	app.timer.stop()
	app.soundscape.cue_played.connect(func(id: String):
		cues.append(id)
		if id.begins_with("stadium-"): received.append(app.last_command))
	await ask("new_career",{"mode":"fiction","club":0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	qa = Reception.new(); qa.app = app; root.add_child(qa)
	await qa._native06_reception()
	await persistence_refusals()
	await event_routing()
	await finish()
func persistence_refusals() -> void:
	app._navigate("Bureau"); await settle()
	await qa._key_action(app.root_content.find_child("OpenCoachNotebook",true,false))
	var popup: AcceptDialog = app.get_node("CoachNotebook")
	var editor: TextEdit = popup.find_child("CoachNoteText",true,false)
	var draft := "Mon brouillon après refus disque 😀"
	editor.text = draft; editor.text_changed.emit()
	var data_dir: String = str(app.model.meta.dataDir)
	var career_path := data_dir.path_join("donnees.json")
	var before := FileAccess.get_file_as_bytes(career_path)
	var temporary: String = data_dir.path_join("donnees-precedentes.json")
	var preserved := temporary + ".fixture-original"
	var has_backup := FileAccess.file_exists(temporary)
	var original_backup := FileAccess.get_file_as_bytes(temporary) if has_backup else PackedByteArray()
	if has_backup: check(DirAccess.rename_absolute(temporary, preserved) == OK,"Original secondaire mis à l’abri")
	check(temporary.begins_with(OS.get_environment("CD_GODOT_DATA_DIR")),"Fixture strictement dans le profil jetable")
	check(DirAccess.make_dir_absolute(temporary) == OK,"Refus disque réel préparé")
	await qa._key_action(popup.find_child("CoachNoteSave",true,false)); await qa._wait(); await settle()
	check(not app.bridge.last_response_ok and is_instance_valid(popup) and editor.text == draft,"Refus réel conserve l’éditeur et son brouillon")
	check(FileAccess.get_file_as_bytes(career_path) == before,"Refus carnet conserve chaque octet et le RNG")
	check(str(popup.find_child("CoachNoteStatus",true,false).text).contains("Non enregistré"),"Refus visible dans le carnet")
	check(cues.has("ui-error"),"Erreur worker confirmée sonorisée")
	check(DirAccess.remove_absolute(temporary) == OK,"Fixture refus disque levée")
	if has_backup:
		check(DirAccess.rename_absolute(preserved, temporary) == OK,"Original secondaire remis en place")
		check(FileAccess.get_file_as_bytes(temporary) == original_backup,"Secondaire restauré octet pour octet")
	await qa._key_action(popup.find_child("CoachNoteSave",true,false)); await qa._wait(); await settle()
	check(app.bridge.last_response_ok and app.model.clubLife.coachNotebook.entries.any(func(row): return row.target == "career" and row.text == draft),"Réessai réel sauvegarde le brouillon exact")
	popup.hide(); popup.queue_free(); await settle()
	app.settings(); await settle()
	var dialog: AcceptDialog = app.get_node("PreferencesDialog")
	dialog.find_child("PreferencesTabs",true,false).current_tab = 1; await settle()
	var volume: SpinBox = dialog.find_child("PreferencesInterfaceVolume",true,false)
	var old_value: int = int(volume.value)
	var sound_file := data_dir.path_join("sound.json")
	var sound_before := FileAccess.get_file_as_bytes(sound_file)
	var blocker := sound_file + ".tmp"
	check(DirAccess.make_dir_absolute(blocker) == OK,"Refus sound.json réel préparé")
	var last_error: String = app.last_error
	volume.value = 12; await settle()
	var reason: Label = dialog.find_child("PreferencesError",true,false)
	check(int(volume.value) == old_value and app.soundscape.preferences.get_value("interface_volume") == old_value,"Refus sonore restaure la valeur active et affichée")
	check(reason.visible and not reason.text.is_empty() and is_instance_valid(dialog),"Refus sonore visible sans détruire les options")
	# La refonte immersive adapte la largeur ; mesurer la visibilité réelle,
	# sans réimposer les dimensions de l'ancien dialogue.
	var original_size := root.size
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution; await settle()
		var window_rect := Rect2(Vector2(dialog.position),Vector2(dialog.size))
		var client_rect := Rect2(Vector2.ZERO,Vector2(dialog.size))
		var scroll: ScrollContainer = reason.get_parent().get_parent()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(window_rect),"Refus sonore : fenêtre entière à " + str(resolution))
		check(dialog.get_ok_button().is_visible_in_tree() and client_rect.encloses(dialog.get_ok_button().get_global_rect()),"Refus sonore : fermeture entière à " + str(resolution))
		check(reason.is_visible_in_tree() and client_rect.encloses(reason.get_global_rect()) and scroll.get_global_rect().encloses(reason.get_global_rect()),"Refus sonore : erreur entière sans défilement à " + str(resolution))
	root.size = original_size; await settle()
	check(app.last_error == last_error and not app._settled_status_text().begins_with("ACTION NON EFFECTUÉE"),"Refus sonore distinct d’une décision métier échouée")
	check(FileAccess.get_file_as_bytes(sound_file) == sound_before,"Refus sonore conserve tous les octets")
	DirAccess.remove_absolute(blocker)
	volume.value = 37; await settle()
	check(app.soundscape.preferences.get_value("interface_volume") == 37 and not reason.visible,"Réessai sonore efface son erreur locale")
	dialog.hide(); dialog.queue_free(); await settle()
	await ask("export")
	var exported: String = app.model.meta.exportText
	await qa._key_action(app.root_content.find_child("OpenCoachNotebook",true,false))
	popup = app.get_node("CoachNotebook")
	editor = popup.find_child("CoachNoteText",true,false); editor.text = "Brouillon à abandonner à l’import"; editor.text_changed.emit()
	await ask("import",{"text":exported})
	check(not is_instance_valid(popup),"Import confirmé ferme l’ancien éditeur et son brouillon")
	await ask("new_career",{"mode":"fiction","club":0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(app.model.clubLife.coachNotebook.entries.is_empty(),"Nouvelle carrière du même club ne reprend aucune note")
func event_routing() -> void:
	var baseline_text := FileAccess.get_file_as_string(directory.path_join("fixture-before.json"))
	await ask("import",{"text":baseline_text})
	app._navigate("Match"); await settle()
	var model: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("fixture-event.json")))
	model.meta.dataDir = app.model.meta.dataDir
	# Restoring raw state selects its latest event; use the actual prior display
	# projection to initialise the observer before testing the next animated tick.
	var displayed_before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("fixture-before-model.json")))
	displayed_before.meta.dataDir = app.model.meta.dataDir
	app.soundscape.observe_model(displayed_before, app.route, "import", app._match_visible())
	var original := model.duplicate(true)
	var path: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(path)
	await create_timer(.4).timeout
	var previous := received.size()
	app.last_command = "tick"; app.bridge.last_response_ok = true
	app.queued_action = {"command":"snapshot","payload":{}}
	app._receive_model(model)
	check(received.size() == previous + 1 and received.back() == "tick", "L’événement réel est reçu sous tick avant l’action mémorisée")
	check(app.last_command == "snapshot" and app.waiting,"La commande mémorisée part seulement après observation sonore")
	await qa._wait(); app.timer.stop(); await settle()
	check(model == original and FileAccess.get_file_as_bytes(path) == bytes,"Projection sonore et snapshot conservent modèle source, carrière et RNG")
	await ask("import",{"text":baseline_text})
	app._navigate("Match"); await settle()
	app.pause_menu(); await qa._wait(); await settle()
	var menu: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.visible and child.title == "Votre carrière": menu = child
	check(menu != null and app.model.live.paused,"Le menu réel met le direct en pause")
	if menu != null: menu.custom_action.emit("settings")
	await settle()
	var options: AcceptDialog = app.get_node_or_null("PreferencesDialog")
	check(options != null and options.visible,"Sous-menu Paramètres réel ouvert")
	if options != null: options.hide(); options.queue_free()
	app._navigate("Bureau"); await settle()
	check(app.route == "Match" and app.contextual_director.match_immersed(),"Navigation gestion refusée pendant le match immersif")
	app.match_screen.hide()
	app.soundscape.observe_model(displayed_before, app.route, "import", app._match_visible())
	app.soundscape.refresh_visibility(app.route,app._match_visible())
	await create_timer(.4).timeout
	previous = received.size()
	app.last_command = "tick"; app.bridge.last_response_ok = true
	app._receive_model(model.duplicate(true))
	check(received.size() == previous and not app.soundscape._active,"Événement du Match masqué consommé silencieusement")
	app.match_screen.show()
	app._navigate("Match"); await settle()
	app.last_command = "snapshot"; app._receive_model(model.duplicate(true))
	check(received.size() == previous,"Menu, sous-menu et retour au direct sans cri de reprise")
	app.match_screen.hide()
	check(not app._match_visible(),"Match masqué est réellement invisible malgré la route")
	app.soundscape.refresh_visibility(app.route,app._match_visible())
	check(not app.soundscape._active,"Ambiance arrêtée quand le vrai panneau est masqué")
	app.match_screen.show()
	await ask("snapshot")
func finish() -> void:
	checks += qa.checks; failures.append_array(qa.failures)
	app.closing = true; app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	app.soundscape.dispose(); app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0,"Worker possédé arrêté")
	qa.queue_free(); app.queue_free(); await create_timer(.3).timeout
	var result := {"checks":checks,"failures":failures,"native_display":DisplayServer.get_name(),"audio_driver":AudioServer.get_driver_name(),"physical_audio_tested":false}
	var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")); file.close()
	print("Raccordements06 : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
