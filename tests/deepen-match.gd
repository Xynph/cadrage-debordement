extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
var journal: Control
var proof := OS.get_environment("CD_DEEPEN_MATCH_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	print("SDK_COMMAND deepen-match ",id)
	var accepted: bool=app._command(id,payload)
	check(accepted,"Commande publique acceptée : "+id)
	if not accepted:return
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
	check(app.contextual_director.active() and app.contextual_director.kind == "live", "Le vrai direct contextuel est affiché")
	if app.match_screen.drawer_tab != "Journal" or not app.match_screen.drawer.visible: app.match_screen._toggle_drawer("Journal")
	await settle()
	journal=app.match_screen.find_child("MatchJournal",true,false)
	if OS.get_environment("CD_DEEPEN_MATCH_GRAPHICS")=="1":
		# This recipe receives the UI, not the already tested 3D animation layer.
		app.match_screen.stage.get_viewport().render_target_update_mode=SubViewport.UPDATE_ONCE
		await settle()
		app.match_screen.stage.get_viewport().render_target_update_mode=SubViewport.UPDATE_DISABLED
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
		check("timeline" in dialog and "phase_choice" in dialog and "kind_choice" in dialog,"Index chronologique, séquences et filtres disponibles")
		if not "timeline" in dialog:
			app.bridge.stop()
			quit(1)
			return
		await cases(dialog,original,model_before,disk_path,disk_before)
	FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("Action review: %d checks, %d failures" % [checks,failures.size()])
	app.bridge.stop()
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func cases(dialog: AcceptDialog, original: Dictionary, model_before: String, disk_path: String, disk_before: PackedByteArray) -> void:
	check(dialog.timeline.item_count==original.events.size(),"Chronologie issue de tous les faits réels")
	check(dialog.phases.size()>0,"Séquences dérivées des plans réels")
	var frozen := JSON.stringify(dialog.events)
	await command("pause",{"paused":false})
	app.timer.stop()
	await command("tick",{"steps":1})
	app.timer.stop()
	await command("pause",{"paused":true})
	app.timer.stop()
	check(is_instance_valid(dialog) and JSON.stringify(dialog.events)==frozen,"Ticks réels concurrents : lecteur figé sans rewind")
	model_before=JSON.stringify(app.model)
	disk_before=FileAccess.get_file_as_bytes(disk_path)
	var d := original.duplicate(true)
	d.events.append({"min":99,"text":"Nouveau fait live","scene":{"kind":"end"}})
	journal.update_frame(d)
	check(JSON.stringify(dialog.events)==frozen,"Le direct ne remplace pas la chronologie figée")
	await key(dialog.get_ok_button())
	var projected := original.duplicate(true)
	projected.events=[
		{"min":2,"text":"Point de départ","scene":{"kind":"carry","team":0,"period":1,"plans":{"attack":["conquete","pied"],"defence":["equilibre","agressive"]},"score":[0,0],"from":{"x":30,"y":20},"to":{"x":35,"y":21}}},
		{"min":5,"text":"Essai avec le premier plan","scene":{"kind":"try","team":0,"period":1,"plans":{"attack":["conquete","pied"],"defence":["equilibre","agressive"]},"score":[5,0],"from":{"x":95,"y":20},"to":{"x":100,"y":21}}},
		{"min":8,"text":"Changement attesté","scene":{"kind":"tactic","team":0,"period":1,"plans":{"attack":["pied","pied"],"defence":["equilibre","agressive"]},"score":[5,0]}},
		{"min":9,"text":"Pénalité ensuite","scene":{"kind":"penalty","team":1,"period":1,"plans":{"attack":["pied","pied"],"defence":["equilibre","agressive"]},"score":[5,0]}},
		{"min":10,"text":"Fait sans position ni plans","scene":{"kind":"message"}},
		"Essai ancien non typé"
	]
	journal.update_frame(projected)
	await settle()
	# Direct row activation opens the matching filtered index, not the last fact.
	var caption: Control = journal.rows.get_child(1).get_child(0)
	await key(caption)
	dialog=journal.find_child("MatchActionReview",true,false)
	check(dialog!=null and dialog.events[dialog.selection[dialog.index]].min==5,"Le fait du journal ouvre la bonne action")
	check(dialog.pitch.to=={"x":100,"y":21},"Le terrain montre la destination exacte du fait choisi")
	check(dialog.phases.size()==3,"Deux plans attestés puis séquence inconnue")
	dialog.phase_choice.select(1)
	dialog.phase_choice.item_selected.emit(1)
	await settle()
	check(dialog.selection==[0,1],"Première séquence limitée aux faits du plan source")
	check(dialog.phase_summary.text.contains("0 — 0") and dialog.phase_summary.text.contains("5 — 0"),"Bilan début et fin issus des scores enregistrés")
	check(dialog.phase_summary.text.contains("ne prouve pas"),"Aucune causalité tactique inventée")
	await key(dialog.show_summary)
	check(dialog.phase_summary.visible,"Bilan de séquence ouvert au clavier")
	check(dialog.content_scroll.get_global_rect().encloses(dialog.phase_summary.get_global_rect()),"Bilan de séquence entièrement révélé après sa mise en page")
	await key(dialog.show_summary)
	check(not dialog.phase_summary.visible,"Bilan repliable pour retrouver le terrain")
	dialog.phase_choice.select(0)
	dialog.phase_choice.item_selected.emit(0)
	dialog.kind_choice.select(1)
	dialog.kind_choice.item_selected.emit(1)
	await settle()
	check(dialog.selection==[2],"Filtre Consignes fondé sur kind, pas sur le texte")
	dialog.kind_choice.select(0)
	dialog.kind_choice.item_selected.emit(0)
	dialog.timeline.select(4)
	dialog.timeline.item_selected.emit(4)
	await settle()
	check(dialog.index==4 and dialog.pitch.from==null,"Choix chronologique et position inconnue explicite")
	check(dialog.phase_summary.text.contains("non renseign"),"Plans absents explicites")
	dialog.timeline.select(1)
	dialog.timeline.item_selected.emit(1)
	await settle()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		check(dialog.size.x<=resolution.x and dialog.size.y<=resolution.y,"Lecteur contenu "+str(resolution))
		check(dialog.get_ok_button().is_visible_in_tree(),"Fermer reste accessible "+str(resolution))
		await key(dialog.show_pitch)
		await settle()
		check(dialog.content_scroll.get_global_rect().encloses(dialog.pitch.get_global_rect()),"Action vers terrain : schéma entièrement visible "+str(resolution))
		if OS.get_environment("CD_DEEPEN_MATCH_GRAPHICS")=="1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(proof.path_join("deepen-%dx%d.png" % [resolution.x,resolution.y]))
	check(JSON.stringify(app.model)==model_before,"Consultation sans mutation de carrière/horloge")
	check(FileAccess.get_file_as_bytes(disk_path)==disk_before,"Profil disque inchangé")
	await key(dialog.get_ok_button())
	journal.update_frame(projected)
	await settle()
	journal.scroll.scroll_vertical=0
	await settle()
	await click(journal.rows.get_child(0).get_child(0))
	dialog=journal.find_child("MatchActionReview",true,false)
	check(dialog!=null and dialog.events[dialog.selection[dialog.index]].min==2,"Clic souris du fait vers la bonne position")
	app.bridge.stop()
	var deadline := Time.get_ticks_msec()+10000
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline: await process_frame
	check(app.bridge.child_pid<=0,"Worker réellement arrêté")
	app._command("snapshot")
	await settle()
	check(app.connection_error and not app.last_error.is_empty(),"Panne du moteur reste visible")
	check(is_instance_valid(dialog),"Panne du moteur conserve la copie locale")
	app.reconnect()
	deadline=Time.get_ticks_msec()+30000
	while (app.waiting or app.bridge.child_pid<=0 or not app.bridge.last_response_ok) and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	app.timer.stop()
	check(not app.waiting and app.bridge.child_pid>0 and app.bridge.last_response_ok,"Reconnexion au vrai profil après réception du snapshot")
	app._clear_dialogs()
	if is_instance_valid(dialog):
		check(dialog.events==projected.events,"Reconnexion ne réécrit pas la relecture locale")
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("live.json"))})
	app.timer.stop()
	check(not is_instance_valid(dialog),"Import réel ferme les faits de l’ancien contexte")
	if app.match_screen.drawer_tab != "Journal" or not app.match_screen.drawer.visible: app.match_screen._toggle_drawer("Journal")
	journal=app.match_screen.find_child("MatchJournal",true,false)
	await key(journal.review)
	dialog=journal.find_child("MatchActionReview",true,false)
	await command("new_career",{"mode":"fiction","club":1})
	app.timer.stop()
	await settle()
	check(not is_instance_valid(dialog),"Nouvelle carrière réelle abandonne l’ancienne relecture")

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		Input.parse_input_event(event)
		await process_frame
	await settle()
