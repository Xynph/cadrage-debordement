extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
var journal: Control
var proof := OS.get_environment("CD_ACTION_REVIEW_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload)
	var deadline := Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Commande "+id)
	await settle()
func key(control: Control) -> void:
	control.grab_focus()
	await settle()
	check(control.has_focus(),"Focus clavier "+str(control.name))
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ENTER
		event.pressed=down
		Input.parse_input_event(event)
		await process_frame
	await settle()
func run() -> void:
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("live.json"))})
	app.timer.stop()
	app._navigate("Match")
	await settle()
	# Le direct est la vue contextuelle du match : le journal s'ouvre dans son tiroir.
	var director: Node = app.contextual_director
	var surface: Node = director.view if is_instance_valid(director) and director.active() and director.kind == "live" else null
	check(surface != null and surface.has_method("_toggle_drawer"), "Direct contextuel ouvert")
	if surface != null and surface.drawer_tab != "Journal":
		surface._toggle_drawer("Journal")
	await settle()
	journal=surface.journal if surface != null else null
	check(journal!=null,"Journal présent")
	var model_before := JSON.stringify(app.model)
	var disk_path := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var disk_before := FileAccess.get_file_as_bytes(disk_path)
	var original: Dictionary = app.model.live.duplicate(true)
	check(journal.review!=null and not journal.review.disabled,"Entrée Relire raccordée")
	await key(journal.review)
	var dialog: AcceptDialog = journal.find_child("MatchActionReview",true,false)
	check(dialog!=null and dialog.visible,"Ouverture réelle par clavier")
	if dialog!=null:
		check(dialog.events==original.events,"Faits réels du worker copiés sans changement")
		check(dialog.selection.size()==original.events.size(),"Tous les événements consultables")
		var last: int = dialog.index
		if last>0:
			await key(dialog.previous)
			check(dialog.index==last-1,"Navigation arrière clavier")
			await key(dialog.next)
			check(dialog.index==last,"Navigation avant clavier")
		var frozen := JSON.stringify(dialog.events)
		journal.update_frame({"events":[],"teams":[]})
		check(JSON.stringify(dialog.events)==frozen,"Instantané figé quand le direct évolue")
		check(journal.review.disabled,"Entrée désactivée si journal vide")
		await key(dialog.keys_only)
		check(dialog.selection.all(func(i): return dialog.events[i] is Dictionary and dialog.events[i].get("scene",{}).get("kind","") in dialog.KEY_KINDS),"Moments clés issus des métadonnées")
		for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size=resolution
			DisplayServer.window_set_size(resolution)
			await settle()
			check(dialog.size.x<=resolution.x and dialog.size.y<=resolution.y,"Fenêtre de relecture contenue "+str(resolution))
			check(dialog.get_ok_button().is_visible_in_tree(),"Fermer visible "+str(resolution))
			if OS.get_environment("CD_ACTION_REVIEW_GRAPHICS")=="1":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(proof.path_join("review-%dx%d.png" % [resolution.x,resolution.y]))
		await key(dialog.get_ok_button())
		await settle()
		check(not is_instance_valid(dialog),"Fermeture libère le lecteur")
	journal.update_frame({"teams":[],"events":["Essai ancien non typé",{"min":12,"text":"Faux essai textuel","scene":{"kind":"message","from":{"x":-10,"y":30},"to":{"x":20,"y":30}}},{"min":15,"text":"Essai réel","scene":{"kind":"try","score":[5,0],"team":0,"from":{"x":95,"y":30},"to":{"x":100,"y":32}}}]})
	await settle()
	await key(journal.review)
	dialog=journal.find_child("MatchActionReview",true,false)
	check(dialog.pitch.from=={"x":95,"y":30} and dialog.pitch.to=={"x":100,"y":32},"Positions enregistrées exactes")
	await key(dialog.previous)
	check(dialog.pitch.from==null and dialog.coordinates.text=="Position non renseignée.","Coordonnée hors terrain non inventée")
	await key(dialog.previous)
	check(dialog.heading.text.contains("Minute non renseignée") and dialog.heading.text.contains("Type non renseigné"),"Faits anciens sans métadonnées explicites")
	await key(dialog.keys_only)
	check(dialog.selection.size()==1 and dialog.action.text=="Essai réel","Texte ancien non classé comme essai")
	check(JSON.stringify(app.model)==model_before,"Aucune mutation du modèle/horloge/RNG de carrière")
	check(FileAccess.get_file_as_bytes(disk_path)==disk_before,"Profil disque strictement inchangé")
	await key(dialog.get_ok_button())
	journal.update_frame({"teams":[],"events":["Essai ancien non typé"]})
	await settle()
	await key(journal.review)
	dialog=journal.find_child("MatchActionReview",true,false)
	await key(dialog.keys_only)
	check(dialog.selection.is_empty() and dialog.heading.text.contains("Aucun moment clé"),"Filtre vide explicite")
	check(dialog.previous.disabled and dialog.next.disabled,"Aucune navigation impossible")
	app.management_ui = {}
	journal.update_frame(original)
	await settle()
	check(not is_instance_valid(dialog),"Changement de contexte ferme les faits de l’ancienne carrière")
	await key(journal.review)
	dialog=journal.find_child("MatchActionReview",true,false)
	# Pendant le direct, le match garde la main (immersion) : la navigation est refusée et la
	# relecture reste celle du match en cours, jusqu'à sa fermeture.
	app._navigate("Bureau")
	await settle()
	check(app.route == "Match" and is_instance_valid(dialog) and dialog.events == original.events, "Navigation refusée pendant le direct, relecture du match conservée")
	if is_instance_valid(dialog):
		await key(dialog.get_ok_button())
		await settle()
	check(not is_instance_valid(dialog),"Fermeture libère la relecture")
	FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("Action review: %d checks, %d failures" % [checks,failures.size()])
	app.bridge.stop()
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
