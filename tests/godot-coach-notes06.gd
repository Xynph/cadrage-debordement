extends SceneTree
var failures: Array[String] = []
var checks := 0
class Bridge extends Node:
	signal model_changed(model: Dictionary)
	signal command_failed(message: String)
	var last_response_ok := true
class App extends Control:
	var model: Dictionary
	var bridge := Bridge.new()
	var waiting := false
	var closing := false
	var last_command := ""
	var sent: Array = []
	func _clear_dialogs() -> void:
		for child in get_children():
			if child is AcceptDialog: child.queue_free()
	func _prepare_dialog(d: AcceptDialog, _width: int) -> void: d.theme = load("res://theme.gd").paper()
	func _command(command: String, payload: Dictionary) -> bool:
		last_command = command
		sent.append({"command":command,"payload":payload.duplicate(true)})
		return true
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr(message)
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	var app := App.new()
	app.model = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_COACH_NOTES06_ROOT").path_join("model.json")))
	root.add_child(app);app.add_child(app.bridge)
	var ui = load("res://ui/coach_notes_view.gd")
	if ui == null or not ui.can_instantiate(): check(false,"Script du carnet compilable");quit(1);return
	var popup: AcceptDialog = ui.open(app)
	await settle()
	var editor: TextEdit = popup.find_child("CoachNoteText",true,false)
	var picker: OptionButton = popup.find_child("CoachNoteTarget",true,false)
	var save: Button = popup.find_child("CoachNoteSave",true,false)
	var cancel: Button = popup.find_child("CoachNoteCancel",true,false)
	var status: Label = popup.find_child("CoachNoteStatus",true,false)
	check(editor != null and editor.text.contains("😀"),"Note existante lisible en Unicode")
	check(popup.size.y <= 600 and editor.size.y <= 270,"Popup et éditeur bornés à720p : %s / %s" % [popup.size,editor.size])
	check(app.bridge.model_changed.get_connections().size() == 1,"Connexion unique au modèle")
	check(ui.open(app) == popup,"Réouverture réutilise le popup")
	check(app.bridge.model_changed.get_connections().size() == 1,"Réouverture sans connexion doublée")
	var original := editor.text
	editor.text = "Brouillon & <plan> 😀";editor.text_changed.emit()
	check(not save.disabled,"Brouillon explicite enregistrable")
	ui.open(app);check(editor.text == "Brouillon & <plan> 😀","Réouverture du même dossier conserve le brouillon")
	picker.select(1);picker.item_selected.emit(1);await settle()
	check(editor.text == "Brouillon & <plan> 😀" and picker.selected == 0,"Changement de cible ne perd pas le brouillon")
	cancel.pressed.emit();check(editor.text == original and app.sent.is_empty(),"Annulation sans commande ni sauvegarde")
	editor.text = "😀".repeat(2000);editor.text_changed.emit();check(not save.disabled,"2000points Unicode acceptés")
	editor.text += "a";editor.text_changed.emit();check(save.disabled,"2001points refusés sans troncature silencieuse")
	editor.text = String.chr(0x00a0) + String.chr(0x2003);editor.text_changed.emit();check(save.disabled,"Espaces Unicode seuls ne forment pas une note")
	editor.text = "Projet & <notes> 😀";editor.text_changed.emit();save.pressed.emit()
	check(app.sent.size() == 1 and app.sent[0].payload.text == editor.text,"Commande porte le texte brut exact")
	check(not status.text.contains("Enregistré"),"Pas de succès avant accusé du moteur")
	app.bridge.model_changed.emit(app.model);check(save.disabled,"Autre snapshot ne vaut pas reçu d’écriture")
	app.bridge.last_response_ok = false;app.bridge.model_changed.emit(app.model);app.bridge.command_failed.emit("Disque refusé")
	check(editor.text == "Projet & <notes> 😀" and not save.disabled,"Refus asynchrone conserve le brouillon")
	check(status.text.contains("Disque refusé"),"Motif de refus visible dans le carnet")
	save.pressed.emit()
	var accepted := app.model.duplicate(true)
	accepted.clubLife.coachNotebook.entries[0].text = editor.text
	accepted.meta.coachNote = {"command":"coach_note_save","target":"career","context":accepted.clubLife.coachNotebook.context}
	app.model = accepted;app.bridge.last_response_ok = true;app.bridge.model_changed.emit(accepted)
	check(status.text.contains("Enregistré") and save.disabled,"Seul reçu exact déclare la note enregistrée")
	var missing := -1
	for i in picker.item_count:
		if picker.get_item_metadata(i) == "missing:old-player": missing = i
	check(missing >= 0,"Ancien dossier absent reste accessible")
	if missing >= 0: check(picker.get_item_text(missing) == "Dossier indisponible","Absence sans faux numéro de note ni identité cachée")
	picker.select(missing);picker.item_selected.emit(missing);await settle()
	check(editor.text == "Ancien dossier — garder la note.","Note d’un joueur absent conservée")
	check(status.text.contains("indisponible"),"Aucune identité inventée pour le dossier absent")
	var remove: Button = popup.find_child("CoachNoteRemove",true,false)
	remove.pressed.emit();await settle()
	var confirm: ConfirmationDialog = popup.find_child("CoachNoteDeleteConfirm",true,false)
	check(confirm != null,"Suppression demande confirmation")
	if confirm != null: confirm.canceled.emit()
	await settle();check(app.sent.size() == 2,"Annulation suppression sans commande")
	remove.pressed.emit();await settle()
	confirm = popup.find_child("CoachNoteDeleteConfirm",true,false)
	if confirm != null: confirm.confirmed.emit()
	check(app.sent.size() == 3 and app.sent[2].command == "coach_note_remove" and app.sent[2].payload.confirmed,"Suppression confirmée transmet une seule commande")
	var deleted := app.model.duplicate(true)
	deleted.clubLife.coachNotebook.entries = deleted.clubLife.coachNotebook.entries.filter(func(e: Dictionary) -> bool: return e.target != "missing:old-player")
	deleted.meta.coachNote = {"command":"coach_note_remove","target":"missing:old-player","context":deleted.clubLife.coachNotebook.context}
	app.model = deleted;app.bridge.model_changed.emit(deleted)
	check(status.text.contains("supprimée"),"Suppression annoncée seulement après reçu exact")
	popup.queue_free();await settle()
	check(app.bridge.model_changed.get_connections().is_empty() and app.bridge.command_failed.get_connections().is_empty(),"Node libéré, signaux déconnectés")
	app.queue_free();await settle()
	print("Carnet06 headless : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
