extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var checks := 0
var room_viewport: SubViewport
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 3: await process_frame
func response(label: String) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and app.bridge.last_response_ok,"Vrai moteur : " + label + " · " + app.last_error)
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	print("SDK_COMMAND native-press-ui ",id)
	check(app._command(id,payload),"Commande publique : " + id)
	await response(id)
func activate(id: String) -> void:
	var control := app.find_child(id,true,false) as Button
	check(control != null and control.is_visible_in_tree() and not control.disabled,"Contrôle presse visible : " + id)
	if control == null or control.disabled: return
	control.grab_focus(); await settle()
	check(control.has_focus(),"Focus clavier : " + id)
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode = KEY_SPACE; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func reveal(control: Control, label: String) -> void:
	check(control != null and control.is_visible_in_tree(),"Contrôle présent pour la géométrie : "+label)
	if control == null: return
	var button := control as BaseButton
	if button == null or not button.disabled: control.grab_focus()
	var ancestor := control.get_parent()
	var scrolls: Array[ScrollContainer] = []
	while ancestor != null:
		if ancestor is ScrollContainer:
			scrolls.append(ancestor)
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	# Container layout and deferred focus scrolling each need a frame.
	await process_frame
	await process_frame
	check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(control.get_global_rect()),"Rectangle cliquable entier dans la fenêtre : "+label+" · "+str(root.size)+" · "+str(control.get_global_rect()))
	for scroll in scrolls:
		check(scroll.get_global_rect().grow(2).encloses(control.get_global_rect()),"Défilement révèle le contrôle entier : "+label)
func texts(node: Node) -> String:
	var result: String = str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += texts(child)
	return result
func render_room(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(is_instance_valid(room_viewport),"Viewport de la vraie salle présent : "+label)
	if not is_instance_valid(room_viewport): return
	# This room is static. Render it initially and at each resize/capture,
	# then cache only its 3D pixels while exercising the live UI. These receipts
	# qualify geometry and inputs; they make no animation or frame-rate claim.
	room_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var rendered := room_viewport.get_texture().get_image()
	check(rendered != null and not rendered.is_empty() and rendered.get_size() == room_viewport.size,"Salle 3D réellement rendue : "+label)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await render_room("capture "+label)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_PRESS_CAPTURES").path_join(label + ".png")) == OK,"Capture " + label)
func run() -> void:
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await response("snapshot initial"); await command("new_career",{"mode":"common","club":29})
	# QA controls the actual client area; production normally maximizes it.
	var maximize:=Callable(app,"_keep_filled_display")
	if root.size_changed.is_connected(maximize):root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize):root.focus_entered.disconnect(maximize)
	root.mode=Window.MODE_WINDOWED

	app._navigate("Bureau"); app._navigate("Presse"); await settle()
	check(app.route == "Bureau","La conférence s’ouvre depuis son courrier")
	app._show_press_inbox(); await settle()
	check(app.find_child("InboxOpenPressInvitation",true,false) == null,"Lire l’invitation avant de rejoindre la conférence")
	await activate("InboxPressInvitation"); await activate("InboxOpenPressInvitation")
	var director: Node = app.contextual_director
	check(director.active() and director.kind == "press","Le courrier ouvre la vraie salle de presse 3D")
	if not director.active() or director.kind != "press": await finish(); return
	check(not app.root_content.is_visible_in_tree(),"La salle prend toute la place de la navigation")
	room_viewport = director.view.room.get_viewport()
	await render_room("ouverture")
	var scene: Dictionary = app.model.clubLife.clubMeetings.scene.duplicate(true)
	check(scene.kind == "press" and not scene.completed,"Rendez-vous réel à terminer")
	var disk := str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	await command("export"); var before: String = app.model.meta.exportText
	var questions: Array = app.model.clubLife.press.conference.questions
	check(questions.size() >= 2 and questions.size() <= 4,"Questions du moteur réellement projetées")
	for dimensions in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(1440,900),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		print("SDK_PRESS_SIZE ",dimensions)
		root.size = dimensions
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(dimensions)
		await settle()
		await render_room("redimensionnement "+str(dimensions))
		var page: Control = director.view
		check(page.name == "ContextualPress" and page.is_visible_in_tree(),"Surface contextuelle visible " + str(dimensions))
		check(page.room != null and page.room.is_inside_tree(),"Salle native 3D présente")
		check(page.find_child("PressReturn",true,false) == null,"Aucune sortie avant publication")
		if dimensions.x == 1280: check(page.publish_button.disabled,"Publication inactive tant que les vraies réponses manquent")
		for index in questions.size():
			var question: Dictionary = questions[index]
			check(page.question_index == index,"Question courante du parcours réel")
			check(page.find_child("PressJournalistName",true,false).text == question.journalist.name,"Nom du journaliste exact")
			check(page.find_child("PressQuestion",true,false).text == question.question,"Question publiée par le moteur")
			check(question.answers.size() == 5,"Cinq réponses réelles disponibles")
			check(page.find_children("*","Label",true,false).any(func(label): return label.text.contains(question.relation.label)),"Relation personnelle publiée visible")
			for answer: Dictionary in question.answers:
				var button := page.find_child("PressAnswer_" + str(question.id) + "_" + str(answer.id),true,false) as Button
				check(button != null and button.text == answer.text and button.tooltip_text.contains(answer.toneLabel) and button.tooltip_text.contains(answer.consequence),"Réponse, ton et conséquence conservés")
				if button != null:
					check(button.custom_minimum_size.y >= 60,"Réponse réellement espacée pour le clavier")
					await reveal(button,str(button.name))
			for control_id in ["PressPrevious","PressNext","PressPublish"]:
				await reveal(page.find_child(control_id,true,false),control_id)
			var id := "PressAnswer_" + str(question.id) + "_r4"
			await activate(id)
			var chosen := page.find_child(id,true,false) as Button
			check(chosen.button_pressed and chosen.has_focus(),"Humour choisi par le vrai clavier")
			check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(chosen.get_global_rect()),"Réponse contenue dans la fenêtre")
			if index < questions.size()-1: await activate("PressNext")
		check(not page.publish_button.disabled,"Publication permise après toutes les réponses")
		await capture("conference-" + str(dimensions.x))
		for index in range(questions.size()-1): await activate("PressPrevious")
		for question: Dictionary in questions: check(page.choices.get(question.id) == "r4","Brouillon conservé après navigation et redimensionnement")
		app._navigate("Bureau"); await settle()
		check(director.active() and director.kind == "press","Rendez-vous obligatoire maintenu pendant la navigation")
	await command("export")
	check(app.model.meta.exportText == before and FileAccess.get_file_as_bytes(disk) == bytes,"Lire et préparer les réponses ne modifie ni état, ni RNG, ni disque")
	await activate("PressPublish"); await response("publication")
	check(not app.model.clubLife.press.conference.available and app.model.clubLife.clubMeetings.scene.completed,"La publication termine la décision du même rendez-vous")
	check(app.model.clubLife.clubMeetings.scene.id == scene.id,"Identité persistante du rendez-vous")
	check(app.model.clubLife.press.history.size() == questions.size() and app.model.clubLife.press.history.all(func(row: Dictionary): return row.answerId == "r4"),"Chaque réponse clavier réellement enregistrée")
	check(app.model.clubLife.press.lastOutcome.delta.morale != 0,"Effet moral réel de la conférence")
	var outcome_text := texts(director.view)
	for row: Dictionary in app.model.clubLife.press.history:
		check(outcome_text.contains(str(row.journalist.name)) and outcome_text.contains(str(row.get("question",row.get("questionText","")))) and outcome_text.contains(str(row.get("answer",row.get("answerText","")))),"Historique publié : journaliste, question et réponse exacts")
	for exchange: Dictionary in app.model.clubLife.press.lastOutcome.exchanges:
		var relation := "relation %+.0f → %+.0f (%+.0f)" % [float(exchange.before),float(exchange.after),float(exchange.delta)]
		check(outcome_text.contains(relation),"Retour individuel exact après publication")
	await capture("conference-publiee")
	await activate("PressReturn"); await response("continuer le rendez-vous")
	check(app.model.clubLife.clubMeetings.receipts.any(func(receipt: Dictionary):return receipt.id==scene.id and receipt.completed),"Le vrai contrôle acquitte le rendez-vous de presse")
	check(not director.active() or director.kind!="press","La salle de presse ferme après son acquittement")
	await ContextualFlow.settle_club_meetings(app,self,check)
	check(not director.active() and app.route=="Réception" and app.model.clubLife.clubMeetings.get("scene")==null,"La Réception revient après les rendez-vous restants du club")
	await finish()
func finish() -> void:
	FileAccess.open(OS.get_environment("CD_PRESS_CAPTURES").path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"render_note":"Salle statique rendue initialement et à chaque résolution/capture ; aucun reçu de fluidité ou d’animation.","resolutions":["1280x720","1366x768","1440x900","1600x900","1920x1080","2560x1440"]},"  "))
	print("PRESSE UI : ",checks," contrôles ; ",failures.size()," échec(s)")
	app.closing = true; app.timer.stop(); app.bridge.stop(); app.queue_free(); await settle()
	quit(0 if failures.is_empty() else 1)
