extends SceneTree
var failures: Array[String] = []
var checks := 0
var app: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	root.gui_embed_subwindows = true
	var script: Script = load("res://ui/decision_feedback.gd")
	var feedback: RefCounted = script.new()
	var host := Control.new(); root.add_child(host); feedback.setup(host)
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_FEEDBACK_CASES")))
	for index in cases.size():
		var c: Dictionary = cases[index]
		var size_before: int = feedback.receipts().size()
		var old_text: String = feedback.status_text()
		var before_json := JSON.stringify(c.before); var after_json := JSON.stringify(c.after)
		feedback.begin(c.command,c.payload,c.before if c.before is Dictionary else {})
		feedback.complete(c.command,c.ok,c.after)
		var receipts: Array = feedback.receipts()
		check(JSON.stringify(c.before) == before_json and JSON.stringify(c.after) == after_json,"Lecture pure " + c.command)
		if c.command in ["new_career","import"] and c.ok:
			check(receipts.is_empty() and feedback.status_text().is_empty(),"Reset carrière réussi " + c.command)
		elif not c.receipt:
			check(receipts.size() == size_before and feedback.status_text() == old_text,"Aucun faux reçu " + c.command)
		else:
			check(receipts.size() == mini(10,size_before+1),"Vrai reçu " + c.command)
			var receipt: Dictionary = receipts.back()
			for metric in ["cash","wage"]:
				check(receipt.before[metric] == c.before.finance[metric] and receipt.after[metric] == c.after.finance[metric],"Vrai avant/après " + metric)
			check(receipt.before.morale == c.before.meta.morale and receipt.after.morale == c.after.meta.morale,"Vrai avant/après moral")
			if c.command == "extend_contract":
				check(receipt.text.contains(c.after.meta.negotiation.message),"Message exact négociation")
				check(receipt.title.contains("signé") == (c.after.meta.negotiation.status == "signed"),"Contre-offre distincte de signature")
		feedback.complete(c.command,c.ok,c.after)
		check(feedback.receipts().size() == receipts.size(),"Complete idempotent " + c.command)
	# Capture annulée/absence de commande : aucune décision créée.
	feedback.begin("train",{},cases[0].after); feedback.complete("train",false,cases[0].after)
	check(feedback.receipts().is_empty(),"Annulation sans reçu")
	feedback.begin("set_tactics",cases[14].payload,cases[14].before)
	feedback.complete("tick",true,cases[14].before)
	feedback.complete("set_tactics",true,cases[14].after)
	check(feedback.receipts().size() == 1,"Réponse étrangère ne consomme pas capture")
	var copy: Array = feedback.receipts(); copy.clear(); check(feedback.receipts().size() == 1,"Historique exposé sans accès en écriture")
	# Projection limite explicite : identité résolue par ID, pas par nom ou index.
	var sample: Dictionary = cases[1].before.duplicate(true)
	sample.squad[0].name = "Ancien nom"
	sample.squad[1].name = "Identité du pack"
	var target: String = sample.squad[1].id
	var projected := sample.duplicate(true); projected.squad[1].loadPlan = "repos" if sample.squad[1].loadPlan != "repos" else "intense"
	feedback.begin("set_player_load",{"playerId":target,"mode":projected.squad[1].loadPlan},sample)
	feedback.complete("set_player_load",true,projected)
	check(feedback.receipts().back().text.contains("Identité du pack") and not feedback.receipts().back().text.contains("Ancien nom"),"Nom du pack lié à l’ID exact")
	var missing := {"clubLife":{"clubStrategy":{"finance":{"facility":null}}}}
	feedback.begin("club_facility_upgrade",{},missing); feedback.complete("club_facility_upgrade",true,missing)
	check(feedback.receipts().size() == 2,"Devis absent sans erreur ni effet inventé")
	# Dix vrais reçus du worker : l'ouverture seule ne prouve pas leur lecture au clavier.
	feedback.reset()
	for c: Dictionary in cases:
		if c.command == "set_tactics" and c.receipt:
			feedback.begin(c.command,c.payload,c.before)
			feedback.complete(c.command,c.ok,c.after)
	check(feedback.receipts().size() == 10,"Dix vrais reçus pour la réception clavier longue")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = resolution
		var button: Button = feedback.control(); host.add_child(button)
		button.grab_focus(); await process_frame
		check(button.has_focus(),"Bouton accessible au clavier " + str(resolution))
		for pressed in [true,false]:
			var key := InputEventKey.new(); key.keycode = KEY_ENTER; key.physical_keycode = KEY_ENTER; key.pressed = pressed
			root.push_input(key,true); await process_frame
		var dialog: AcceptDialog = host.get_node_or_null("DecisionFeedbackDialog")
		check(dialog != null and dialog.visible,"Dialogue volontaire " + str(resolution))
		if dialog:
			check(dialog.size.x <= resolution.x and dialog.size.y <= resolution.y,"Dialogue dans fenêtre " + str(resolution))
			check(dialog.get_node("DecisionFeedbackScroll").get_child(0).get_child(0).text.contains("cette session"),"Limite session visible")
			var scroll: ScrollContainer = dialog.get_node("DecisionFeedbackScroll")
			var oldest: Label = scroll.get_child(0).get_child(10)
			check(oldest.get_global_rect().position.y >= scroll.get_global_rect().end.y,"Plus ancien reçu initialement hors champ")
			await press_key(KEY_TAB)
			check(scroll.get_v_scroll_bar().has_focus(),"Tab atteint la lecture de l’historique")
			await press_key(KEY_PAGEDOWN)
			check(scroll.scroll_vertical > 0,"Tab puis Page suivante défile réellement " + str(resolution))
			for page in 20: await press_key(KEY_PAGEDOWN)
			check(scroll.get_global_rect().encloses(oldest.get_global_rect()),"Plus ancien reçu entièrement lisible au clavier " + str(resolution))
			check(oldest.text == feedback.receipts()[0].title + "\n" + feedback.receipts()[0].text,"Texte du plus ancien reçu réel atteint")
			var bottom := scroll.scroll_vertical
			await press_key(KEY_PAGEUP)
			check(scroll.scroll_vertical < bottom,"Page précédente remonte réellement")
			await press_key(KEY_HOME)
			check(scroll.scroll_vertical == 0,"Début revient au reçu le plus récent")
			await press_key(KEY_END)
			check(scroll.get_global_rect().encloses(oldest.get_global_rect()),"Fin rend le plus ancien reçu lisible")
			await press_key(KEY_TAB)
			check(dialog.get_ok_button().has_focus(),"Tab revient à FERMER après lecture")
			await press_key(KEY_ENTER)
			check(host.get_node_or_null("DecisionFeedbackDialog") == null,"Fermeture clavier après défilement")
		host.remove_child(button); button.queue_free(); await process_frame
	var blocker := ConfirmationDialog.new(); host.add_child(blocker); blocker.popup_centered()
	var button: Button = feedback.control(); host.add_child(button); button.pressed.emit(); await process_frame
	check(host.get_node_or_null("DecisionFeedbackDialog") == null and blocker.visible,"Confirmation existante prioritaire")
	blocker.hide(); blocker.queue_free(); feedback.reset(); check(feedback.receipts().is_empty(),"Reset explicite")
	host.queue_free(); await process_frame
	await run_main()
	var file := FileAccess.open(OS.get_environment("CD_FEEDBACK_ARTIFACTS").path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  ")); file.close()
	print("RETOURS DÉCISIONS : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for i in 4: await process_frame
func press_key(keycode: Key) -> void:
	for pressed in [true,false]:
		var key := InputEventKey.new(); key.keycode = keycode; key.physical_keycode = keycode; key.pressed = pressed
		root.push_input(key,true); await process_frame
	await settle()
func close_dialogs() -> void:
	for child in app.get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await settle()
func capture_main(label: String) -> void:
	if OS.get_environment("CD_FEEDBACK_GRAPHICS") != "1": return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.save_png(OS.get_environment("CD_FEEDBACK_ARTIFACTS").path_join(label+".png")) == OK,"Capture " + label)
	var metadata := FileAccess.open(OS.get_environment("CD_FEEDBACK_ARTIFACTS").path_join(label+".json"),FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"windowPhysical":[root.size.x,root.size.y],"imagePixels":[picture.get_width(),picture.get_height()],"canvasLogical":[app.size.x,app.size.y],"status":app.status.text})); metadata.close()
func command(id: String, payload: Dictionary = {}, expected: bool = true) -> void:
	app._command(id,payload)
	var until := Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	check(not app.waiting and app.bridge.last_response_ok == expected,"Main/worker réel " + id)
	await settle()
func run_main() -> void:
	ProjectSettings.set_setting("native_engine/worker_path",OS.get_environment("CD_FEEDBACK_WORKER"))
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	check(not app.model.is_empty(),"Vrai main connecté au worker")
	if app.model.is_empty(): app.bridge.stop(); app.queue_free(); return
	app.timer.stop()
	await command("new_career",{"club":0,"mode":"common"})
	app._navigate("Bureau"); await settle()
	check(app.decision_feedback.receipts().is_empty(),"Main nouvelle carrière remet reçus à zéro")
	var before: Dictionary = app.model.finance.duplicate(true)
	var context: Dictionary = app.model.clubLife.clubSupport.context
	app._command("staff_meeting",{"context":context,"plan":"cohesion"})
	check(not app._command("train",{"mode":"normal"}),"Refus local d’une deuxième action en vol")
	while app.waiting: await process_frame
	await settle(); await close_dialogs()
	check(app.decision_feedback.receipts().size() == 1 and app.decision_feedback.receipts()[0].command == "staff_meeting","Refus local ne consomme pas la capture staff")
	check(app.decision_feedback.receipts()[0].before.cash == before.cash,"Avant financier du main exact")
	check(app.status.text == app.decision_feedback.status_text(),"Footer connecté au vrai reçu")
	var player: Dictionary = {}
	for p: Dictionary in app.model.squad:
		if p.renewal.available: player = p; break
	await command("extend_contract",{"playerId":player.id,"salary":1000,"years":player.renewal.minYears,"confirmed":true})
	check(app.decision_feedback.receipts().back().title == "Contre-offre reçue","Main contre-offre non présentée comme signature")
	await close_dialogs()
	var negotiation: Dictionary = app.model.meta.negotiation
	await command("extend_contract",{"playerId":player.id,"salary":int(negotiation.salary),"years":int(negotiation.years),"confirmed":true})
	check(app.decision_feedback.receipts().back().title == "Contrat signé","Main vraie signature")
	await close_dialogs()
	if OS.get_environment("CD_FEEDBACK_GRAPHICS") == "1":
		for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size = resolution; await settle()
			await capture_main("decisions-footer-%d" % resolution.x)
			var history_button: Button = app.find_child("DecisionFeedbackButton",true,false)
			history_button.pressed.emit(); await settle()
			await capture_main("decisions-historique-%d" % resolution.x)
			await close_dialogs()
	var count: int = app.decision_feedback.receipts().size()
	await command("import",{"text":"invalid"},false)
	check(app.decision_feedback.receipts().size() == count and app.status.text.begins_with("ACTION NON EFFECTUÉE"),"Import refusé conserve reçus et erreur prioritaire")
	await close_dialogs()
	var blocker_path: String = str(app.model.meta.dataDir).path_join("donnees-precedentes.json")
	var preserved := blocker_path + ".fixture-original"
	var has_backup := FileAccess.file_exists(blocker_path)
	var original_backup := FileAccess.get_file_as_bytes(blocker_path) if has_backup else PackedByteArray()
	if has_backup: check(DirAccess.rename_absolute(blocker_path, preserved) == OK,"Original secondaire mis à l’abri")
	var primary := str(app.model.meta.dataDir).path_join("donnees.json")
	var before_refusal := FileAccess.get_file_as_bytes(primary)
	check(blocker_path.begins_with(OS.get_environment("CD_GODOT_DATA_DIR")) and DirAccess.make_dir_absolute(blocker_path) == OK,"Blocage disque réellement installé")
	var attack: String = app.model.tactics.attacks[1].id
	await command("set_tactics",{"attack":attack,"defense":app.model.tactics.defense},false)
	check(app.decision_feedback.receipts().size() == count and app.status.text.begins_with("ACTION NON EFFECTUÉE"),"Erreur disque ne crée aucun faux succès")
	check(FileAccess.get_file_as_bytes(primary) == before_refusal,"Sauvegarde intacte après le refus")
	check(DirAccess.remove_absolute(blocker_path) == OK,"Fixture refus disque levée")
	if has_backup:
		check(DirAccess.rename_absolute(preserved, blocker_path) == OK,"Original secondaire remis en place")
		check(FileAccess.get_file_as_bytes(blocker_path) == original_backup,"Secondaire restauré octet pour octet")
	await close_dialogs()
	await command("export")
	check(not app.model.meta.saveError or app.status.text.to_lower().contains("sauvegarde"),"Erreur sauvegarde persistante prioritaire après lecture réussie")
	var exported: String = app.model.meta.exportText
	var disk_path := OS.get_environment("CD_GODOT_DATA_DIR").path_join("PrototypeGodot/donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk_path)
	var button: Button = app.find_child("DecisionFeedbackButton",true,false)
	check(button != null and not button.disabled,"Bouton d’historique du main activé")
	button.grab_focus(); await settle()
	for pressed in [true,false]:
		var key := InputEventKey.new(); key.keycode = KEY_ENTER; key.physical_keycode = KEY_ENTER; key.pressed = pressed
		root.push_input(key,true); await process_frame
	check(app.get_node_or_null("DecisionFeedbackDialog") != null,"Vrai historique ouvert au clavier")
	await close_dialogs()
	await command("export")
	check(app.model.meta.exportText == exported and FileAccess.get_file_as_bytes(disk_path) == bytes,"Vrai historique sans effet S/RNG/disque")
	await command("save")
	app.user_preferences.last_error = "refus de réglages pour la réception"
	check(app._settled_status_text().contains("refus de réglages"),"Erreur locale des préférences prioritaire")
	app.user_preferences.last_error = ""
	await command("import",{"text":exported})
	check(app.decision_feedback.receipts().is_empty(),"Main import réussi remet historique à zéro")
	await command("begin_match")
	await command("pause",{"paused":true})
	app._navigate("Match"); await settle()
	app._command("tick",{"steps":1})
	var queued: bool = app._command("set_tactics",{"attack":attack,"defense":app.model.tactics.defense})
	check(queued and not app.queued_action.is_empty(),"Vraie décision mise en file après tick")
	until = Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	await settle()
	check(app.bridge.last_response_ok and app.decision_feedback.receipts().size() == 1 and app.decision_feedback.receipts()[0].command == "set_tactics","Capture prise après tick, au vrai envoi")
	button = app.find_child("DecisionFeedbackButton",true,false)
	check(button != null and not button.disabled,"Premier reçu en match active bouton sans reconstruire la page")
	app.bridge.stop(); app.queue_free(); await settle()
