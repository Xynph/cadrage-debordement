extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
var directory := OS.get_environment("CD_EPCR_UI_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	for i in 10: await process_frame
func ask(command: String, payload: Dictionary = {}) -> void:
	app._command(command,payload)
	var deadline := Time.get_ticks_msec()+20000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Vrai worker : " + command)
	app.timer.stop(); await settle()
func press(control: Control) -> void:
	check(is_instance_valid(control),"Commande clavier présente")
	if not is_instance_valid(control): return
	check(control.is_visible_in_tree(),"Commande visible : " + str(control.name))
	control.grab_focus(); await settle()
	check(control.has_focus(),"Focus clavier : " + str(control.name))
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != app:
		if ancestor is ScrollContainer:
			check(ancestor.get_global_rect().grow(1).encloses(control.get_global_rect()),"Commande entière dans le défilement : " + str(control.name))
		ancestor = ancestor.get_parent()
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	var deadline:=Time.get_ticks_msec()+20000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec()<deadline:await process_frame
	app.timer.stop()
	await ask("new_career",{"mode":"world","club":0})
	await ask("export")
	var exported: String=app.model.meta.exportText
	var career_file: String=str(app.model.meta.dataDir).path_join("donnees.json")
	var disk := FileAccess.get_file_as_bytes(career_file)
	app._navigate("Effectif");await settle()
	await press(app.root_content.find_child("OpenEpcrPreparation",true,false))
	var dialog: AcceptDialog=app.get_node_or_null("EpcrPreparationDialog")
	check(dialog!=null and dialog.visible,"Le bouton de l’effectif ouvre le vrai brouillon Europe")
	if dialog==null: await finish();return
	var count: Label=dialog.find_child("EpcrPreparationCount",true,false)
	var verify: Button=dialog.find_child("EpcrVerify",true,false)
	check(dialog.choices.size()>42,"L’effectif réel permet de vérifier le dépassement de 42")
	check(dialog.selected.size()==dialog.choices.size(),"La liste proposée conserve tous les joueurs, sans suppression cachée")
	await press(verify)
	await wait_preview(dialog)
	check(is_instance_valid(dialog) and dialog.visible,"Le dialogue survit à la réponse et au rendu du modèle")
	check(dialog.preview.registration.status=="invalid","Le dépassement de 42 est refusé par le vrai validateur")
	check(str(dialog.find_child("EpcrPreparationNotice",true,false).text).contains("ne vaut pas inscription officielle"),"Aucune fausse inscription officielle annoncée")
	var original_error: String = app.last_error
	app.last_error = "Décision antérieure à vérifier"
	var previous_error: String = app.last_error
	var receipts_before: Array = app.decision_feedback.receipts().duplicate(true)
	var draft_before: Dictionary = dialog.selected.duplicate(true)
	var original_id: String = dialog.choices[0].get_meta("player_id")
	dialog.choices[0].set_meta("player_id","foreign-review-id")
	dialog.selected.erase(original_id);dialog.selected["foreign-review-id"] = true
	var rejected_draft: Dictionary = dialog.selected.duplicate(true)
	await press(verify);await wait_refusal(dialog)
	check(is_instance_valid(dialog) and dialog.visible and dialog.selected==rejected_draft,"Un vrai refus worker conserve dialogue et sélection")
	check(dialog.result.text.contains("identifiants uniques de votre effectif"),"Le refus réel est présenté dans le brouillon")
	check(app.last_error==previous_error and not app.connection_error,"Le refus consultatif ne crée pas une erreur métier")
	dialog.choices[0].set_meta("player_id",original_id);dialog.selected=draft_before.duplicate(true)
	await press(verify);await wait_preview(dialog)
	check(dialog.preview.registration.status=="invalid","Réessai réussi après correction de l’identifiant")
	# This refusal returns default IDs identical to the request. It must not be
	# consumed as a successful preview before command_failed is delivered.
	var own_competition: String = dialog.preview.competitionId
	dialog.preview.competitionId="challenge"
	await press(verify);await wait_refusal(dialog)
	check(dialog.result.text.contains("ne participe pas à cette coupe"),"Un modèle de refus avec mêmes IDs ne produit aucun faux rapport")
	check(dialog.selected==draft_before and app.last_error==previous_error,"Second refus préserve le brouillon et le statut métier")
	dialog.preview.competitionId=own_competition
	await press(verify);await wait_preview(dialog)
	check(app.last_error==previous_error,"Un succès de consultation n’efface pas l’erreur métier antérieure")
	check(app.decision_feedback.receipts()==receipts_before,"Les consultations ne créent aucun reçu de décision métier")
	app.last_error=original_error
	await press(dialog.choices[0])
	check(dialog.selected.size()==dialog.choices.size()-1 and count.text.begins_with(str(dialog.selected.size())),"Le clavier retire réellement un joueur et actualise le compteur")
	check(dialog.result.text.contains("relancez"),"Un brouillon modifié invalide le rapport précédent")
	await press(dialog.find_child("EpcrSelectNone",true,false))
	await press(verify); await wait_preview(dialog)
	check(dialog.selected.is_empty() and dialog.preview.registeredIds.is_empty(),"Le choix vide est transmis sans réinscription implicite")
	check(dialog.preview.registration.status=="invalid" and dialog.preview.teamSheet.status=="invalid","Liste et feuille affichent les refus du worker")
	check(not dialog.result.text.is_empty(),"Les raisons sont lisibles dans le dialogue")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=resolution;await settle();await create_timer(.2).timeout;await settle()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"Fenêtre entière : "+str(resolution))
		check(Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(dialog.get_ok_button().get_global_rect()),"Fermeture entière : "+str(resolution))
		check(dialog.selected.is_empty(),"Redimensionnement conserve le brouillon : "+str(resolution))
	await press(dialog.get_ok_button());await settle()
	check(not is_instance_valid(dialog),"Fermer au clavier détruit le brouillon")
	root.size=Vector2i(1920,1080);await settle();await create_timer(.2).timeout
	app._navigate("Effectif");await settle()
	check(app.root_content.find_child("ImmersiveRosterTable",true,false)!=null,"La seconde ouverture utilise le canevas Effectif grand écran")
	await press(app.root_content.find_child("OpenEpcrPreparation",true,false))
	dialog=app.get_node_or_null("EpcrPreparationDialog")
	check(dialog!=null and dialog.selected.size()==dialog.choices.size(),"Réouverture propose de nouveau tout l’effectif sans reprendre la liste vidée")
	check(dialog.result.text.contains("relancez"),"La réouverture ne reprend pas un ancien verdict")
	var sheet: Array=app.model.lineup+app.model.reserves
	for choice: CheckButton in dialog.choices: choice.button_pressed=choice.get_meta("player_id") in sheet
	await press(dialog.verify);await wait_preview(dialog)
	check(dialog.preview.registration.status=="unknown" and dialog.preview.teamSheet.status=="unknown","Les qualifications non certifiées restent inconnues pour une liste de 23")
	check(dialog.result.text.contains("À confirmer"),"Le rapport présente les informations manquantes du validateur")
	await press(dialog.get_ok_button());await settle()
	await ask("export")
	check(app.model.meta.exportText==exported,"La consultation et les choix conservent chaque champ de carrière")
	check(FileAccess.get_file_as_bytes(career_file)==disk,"La consultation conserve disque, horloge et RNG")
	app._navigate("Effectif");await settle()
	await press(app.root_content.find_child("OpenEpcrPreparation",true,false))
	dialog=app.get_node_or_null("EpcrPreparationDialog")
	var disconnected_draft: Dictionary = dialog.selected.duplicate(true)
	app.bridge.stop()
	var stop_deadline := Time.get_ticks_msec()+3000
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<stop_deadline: await process_frame
	await settle()
	await press(dialog.verify);await settle()
	check(is_instance_valid(dialog) and dialog.visible and dialog.selected==disconnected_draft,"La panne réelle du transport conserve le brouillon")
	check(app.connection_error and not app.last_error.is_empty(),"Le moteur réellement fermé reste signalé globalement")
	check(not dialog.result.text.is_empty() and not dialog.pending,"La panne termine la consultation avec une raison locale")
	check(FileAccess.get_file_as_bytes(career_file)==disk,"La panne et les refus ne modifient pas le profil")
	dialog.hide();dialog.queue_free();await settle()
	await finish()
func wait_preview(dialog: AcceptDialog) -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while (app.waiting or dialog.pending) and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.waiting and not dialog.pending and app.bridge.last_response_ok,"Le vrai worker a répondu à epcr_preview")
	await settle()
func wait_refusal(dialog: AcceptDialog) -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while (app.waiting or dialog.pending) and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.waiting and not dialog.pending and not app.bridge.last_response_ok,"Le vrai worker a refusé epcr_preview")
	await settle()
func finish() -> void:
	app.closing=true;app.timer.stop()
	if is_instance_valid(app.coach):app.coach.destroy()
	app.soundscape.dispose();app.bridge.stop()
	var deadline:=Time.get_ticks_msec()+2500
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline:await process_frame
	check(app.bridge.child_pid<=0,"Worker possédé arrêté")
	app.queue_free();await create_timer(.3).timeout
	var file:=FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	print("Préparation EPCR UI : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
