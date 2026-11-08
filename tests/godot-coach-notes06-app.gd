extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);printerr(message)
func settle() -> void:
	for i in 8: await process_frame
func wait_response() -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(),"Réponse bornée du vrai moteur")
	await settle()
func run() -> void:
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate();root.add_child(app)
	await wait_response()
	app._command("new_career", {"mode":"fiction","club":0});await wait_response()
	check(app.bridge.last_response_ok,"Carrière temporaire native créée")
	var view = load("res://ui/coach_notes_view.gd")
	if view == null or not view.can_instantiate(): check(false,"Vue du carnet compilable");finish();return
	var popup: AcceptDialog = view.open(app)
	await settle()
	var editor: TextEdit = popup.find_child("CoachNoteText",true,false)
	var save: Button = popup.find_child("CoachNoteSave",true,false)
	var text := "Mon projet & mes choix <calmes> 😀\nAucun résultat promis."
	editor.text = text;editor.text_changed.emit()
	var file: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_file_as_bytes(file)
	var blocked: String = str(app.model.meta.dataDir).path_join("donnees.tmp")
	check(blocked.begins_with(OS.get_environment("CD_GODOT_DATA_DIR")),"Fixture disque dans le seul profil temporaire")
	check(DirAccess.make_dir_absolute(blocked) == OK,"Échec d’écriture réel préparé")
	save.pressed.emit();await wait_response()
	check(not app.bridge.last_response_ok,"Refus disque réel reçu")
	check(FileAccess.get_file_as_bytes(file) == before,"Sauvegarde disque précédente préservée")
	check(is_instance_valid(popup) and is_instance_valid(editor),"Le vrai main ne détruit pas le carnet lors du refus")
	check(DirAccess.remove_absolute(blocked) == OK,"Fixture refus disque levée")
	if not is_instance_valid(popup) or not is_instance_valid(editor): finish();return
	check(editor.text == text,"Brouillon Unicode conservé après vrai refus du worker")
	var status: Label = popup.find_child("CoachNoteStatus",true,false)
	check(status.text.contains("Non enregistré"),"Motif local reçu dans le vrai popup")
	save.pressed.emit();await wait_response()
	check(app.bridge.last_response_ok and status.text.contains("Enregistré"),"Réessai confirmé par le vrai reçu métier")
	check(app.model.clubLife.coachNotebook.entries[0].text == text,"Note exacte dans la projection native")
	popup.queue_free();await settle()
	popup = view.open(app);await settle()
	editor = popup.find_child("CoachNoteText",true,false)
	check(editor.text == text,"Réouverture reçoit le texte enregistré")
	app._command("new_career", {"mode":"fiction","club":0});await wait_response()
	check(app.model.clubLife.coachNotebook.entries.is_empty(),"Nouvelle carrière du même club sans ancienne note")
	check(not is_instance_valid(popup),"Éditeur fermé sur changement de carrière")
	finish()
func finish() -> void:
	app.queue_free()
	print("Carnet06 vraie app/worker headless : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
