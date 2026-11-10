extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Content = preload("res://guide/guide_content.gd")
var app: Control
var guide: Control
var checks := 0
var failures: Array[String] = []
var metrics: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for i in 6: await process_frame
func wait_model() -> void:
	var until := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Moteur réel disponible")
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_GUIDE_CAPTURES").path_join(id + ".png")) == OK, "Capture réelle " + id)
func click(control: Control, fraction: float = 0.5) -> void:
	var rect := control.get_global_rect()
	var pos := rect.position + Vector2(rect.size.x * fraction,rect.size.y * .5)
	var motion := InputEventMouseMotion.new(); motion.position = pos; motion.global_position = pos
	root.push_input(motion,true); await process_frame
	var event := InputEventMouseButton.new(); event.position = pos; event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; root.push_input(event,true); await process_frame
	event = InputEventMouseButton.new(); event.position = pos; event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = false; root.push_input(event,true); await settle()
func key(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.keycode = code; event.pressed = false; Input.parse_input_event(event); await settle()
func contained(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1).encloses(inner)
func geometry(id: String) -> void:
	await settle()
	var rect: Rect2 = guide.get_global_rect()
	check(guide.expanded, "Conseil visible : " + id)
	if not guide.expanded: return
	check(rect.size.x <= 420, "Largeur courte <=420 : " + id)
	check(contained(Rect2(Vector2.ZERO,app.size),rect), "Guide entier dans l'app : " + id)
	check(rect.position.y >= app.size.y * .55, "Guide reste en bas, loin des titres : " + id)
	var balloon: Control = guide.find_child("GuideSpeechBalloon",true,false)
	var scroll: ScrollContainer = guide.find_child("GuideTextScroll",true,false)
	check(balloon.size.x <= 302 and guide.portrait.size.x <= 112, "Bulle et portrait compacts : " + id)
	check(guide.bubble.get_theme_font_size("font_size") >= 15, "Texte à 15 unités au moins : " + id)
	check(scroll.size.y + 1 >= guide.bubble.get_minimum_size().y, "Fragment intégral sans scroll : " + id)
	check(contained(rect,balloon.get_global_rect()), "Bulle non coupée : " + id)
	for p in balloon.get_tail_points():
		check(p.x > scroll.position.x + scroll.size.x, "Pointe hors de la zone du texte : " + id)
	for name in ["GuideClose","GuideReplay","GuideStop","GuideOptions","GuideNext"]:
		var button: Button = guide.find_child(name,true,false)
		check(button.is_visible_in_tree() and contained(rect,button.get_global_rect()), "Commande entière " + name + " : " + id)
	check(guide.mouse_filter == Control.MOUSE_FILTER_IGNORE and balloon.mouse_filter == Control.MOUSE_FILTER_IGNORE and guide.bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bulle traversable : " + id)
	var before: Vector2 = guide.position
	for i in 4: guide._avoid_primary_controls()
	check(guide.position == before, "Position stable sans rebond : " + id)
	check(not guide._covers_priority(guide._priority_rects()), "Commandes principales dégagées : " + id)
	for name in ["OfficePrimaryAction","PreparationMatch"]:
		var principal: Control = app.root_content.find_child(name,true,false)
		if is_instance_valid(principal) and principal.is_visible_in_tree():
			var clipped := principal.get_global_rect().intersection(Rect2(Vector2.ZERO,app.size))
			if clipped.has_area():
				for painted in guide._painted_controls(): check(not painted.get_global_rect().intersects(clipped),"Action métier indépendante dégagée : "+name+id)
	metrics.append({"case":id,"app":str(app.size),"guide":str(rect),"balloon":str(balloon.size),"text":guide.bubble.text,"textHeight":guide.bubble.get_minimum_size().y,"readHeight":scroll.size.y})
func run() -> void:
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop()
	app._command("new_career",{"club":0,"mode":"common"}); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	guide = load("res://guide/coach_guide.gd").new(); app.add_child(guide); guide.setup(app); guide.speech.set_muted(true)
	if OS.get_environment("CD_GUIDE_LAYOUT_CASE") == "dock":
		await dock_cases(); await finish(); return
	var disk_path: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var career_before := FileAccess.get_file_as_bytes(disk_path)
	var original_scale: Vector2i = root.content_scale_size
	for resolution in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = resolution
		if OS.get_environment("CD_GUIDE_LAYOUT_MODE") == "native": root.content_scale_size = resolution
		else: root.content_scale_size = original_scale
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		await settle()
		for route in ["Bureau","Préparation","Composition"]:
			guide.close(); app._navigate(route); await settle()
			var page := Content.for_route(route,app.model)
			guide.profile.data.seen.erase(page)
			guide.consider_context(route,app.model,"snapshot",true)
			var id := str(resolution.x) + "-" + page
			await geometry(id)
			if (OS.get_environment("CD_GUIDE_LAYOUT_MODE") == "stretch" and resolution.x == 1280 and route == "Bureau") or (OS.get_environment("CD_GUIDE_LAYOUT_MODE") == "native" and ((resolution.x == 1440 and route == "Bureau") or (resolution.x == 1280 and route == "Préparation"))): await capture(id)
		# The longest real fragment, not synthetic repeated content.
		var longest: Dictionary = {}
		for page_id in Content.CONTEXT_PAGES:
			for f in Content.fragments(page_id):
				if str(f.text).length() > str(longest.get("text","")).length(): longest = f
		if longest.is_empty():
			for f in Content.fragments("bienvenue"):
				if str(f.text).length() > str(longest.get("text","")).length(): longest = f
		guide.close(); app._navigate("Bureau"); await settle(); guide._show_context("bienvenue",longest)
		await geometry(str(resolution.x)+"-longest")
		if OS.get_environment("CD_GUIDE_LAYOUT_MODE") == "native" and resolution.x == 1280: await capture("1280-longest")
		guide._settings_open = true; guide._layout(); await settle()
		check(contained(Rect2(Vector2.ZERO,app.size),guide._settings_panel.get_global_rect()),"Panneau options entier dans la fenêtre : "+str(resolution.x))
		check(not guide._settings_panel.get_global_rect().intersects(guide._expanded.get_global_rect()),"Options ne peignent pas sur la bulle : "+str(resolution.x))
		print("OPTIONS ",resolution," guide=",guide.get_global_rect()," panel=",guide._settings_panel.get_global_rect()," optionsMin=",guide._options.get_minimum_size()," noticeMin=",guide._notice.get_minimum_size())
		for name in ["GuideVoice","GuideSpeed","GuideMute","GuideDisable"]:
			var control: Control = guide.find_child(name,true,false)
			check(contained(guide.get_global_rect(),control.get_global_rect()), "Options entières : "+name+str(resolution.x))
		if OS.get_environment("CD_GUIDE_LAYOUT_MODE") == "native" and resolution.x == 1280: await capture("1280-options")
		guide._settings_open = false; guide._layout(); await settle()
		var close_button: Button = guide.find_child("GuideClose",true,false)
		close_button.grab_focus(); await key(KEY_ENTER)
		check(not guide.expanded,"Réduction par activation clavier : "+str(resolution.x))
		var help: Button = guide.find_child("GuideHelp",true,false)
		await click(help)
		check(guide.expanded and guide.mode == "screen","Aide ouverte par vrai clic souris : "+str(resolution.x))
		if OS.get_environment("CD_GUIDE_LAYOUT_MODE") == "native" and resolution.x == 1920: await capture("1920-help")
		guide.close()
	# An invitation must not consume advice that cannot be painted anywhere.
	app._navigate("Bureau"); await settle(); guide.profile.data.seen.erase("bureau")
	var obstacle := Button.new(); obstacle.text = "CONFIRMER LE CHOIX"; app.root_content.add_child(obstacle)
	obstacle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	obstacle.global_position = Vector2(220,app.size.y * .4); obstacle.size = Vector2(app.size.x - 220,app.size.y * .6)
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 24000
	var pcm := PackedByteArray(); pcm.resize(4800); wav.data = pcm
	var fixture := OS.get_environment("CD_GODOT_DATA_DIR").path_join("voice-fixture"); DirAccess.make_dir_recursive_absolute(fixture)
	check(wav.save_to_wav(fixture.path_join("silence.wav")) == OK,"WAV de réception locale créé")
	var tip: String = Content.fragments("bureau")[0].text
	var manifest := FileAccess.open(fixture.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"clips":[{"id":"layout-bureau","text":tip,"text_sha256":tip.sha256_text(),"file":"silence.wav"}]})); manifest.close()
	guide.speech.load_manifest(fixture.path_join("manifest.json")); guide.speech.volume = 0; guide.speech.set_muted(false)
	var requests: Array[String] = []; guide.speech.requested.connect(func(text: String):requests.append(text))
	guide.consider_context("Bureau",app.model,"snapshot",true); await settle()
	check(not guide.expanded and "bureau" not in guide.profile.data.seen,"Aucun espace : invitation sans consommer la visite")
	check(requests.is_empty(),"Aucun espace : aucune parole demandée pour un conseil caché")
	check(guide.find_child("GuideHelp",true,false).text.contains("conseil"),"Invitation explicite au conseil en attente")
	obstacle.queue_free(); await settle()
	guide.consider_context("Bureau",app.model,"snapshot",true)
	check(not guide.expanded,"Un snapshot ne répète pas une tentative automatique différée")
	app.last_error = "Erreur UI de réception"; await click(guide.find_child("GuideHelp",true,false))
	check(not guide.expanded and "bureau" not in guide.profile.data.seen,"Invitation conserve la garde erreur UI et la visite disponible")
	app.last_error = ""
	if guide.expanded: guide.close()
	await click(guide.find_child("GuideHelp",true,false))
	check(guide.expanded and guide.mode == "context" and "bureau" in guide.profile.data.seen,"Invitation rouvre le même contexte et marque alors la visite")
	check(requests == [tip],"Réouverture : voix demandée une seule fois pour le texte affiché")
	guide.speech.set_muted(true); guide.close()
	obstacle = Button.new(); obstacle.text = "CONFIRMER LE CHOIX"; app.root_content.add_child(obstacle)
	obstacle.global_position = Vector2(220,app.size.y * .4); obstacle.size = Vector2(app.size.x - 220,app.size.y * .6)
	guide.profile.data.seen.erase("bureau"); guide.consider_context("Bureau",app.model,"snapshot",true); await settle()
	app.model.meta.week += 1; guide.refresh()
	check(not guide.find_child("GuideHelp",true,false).text.contains("conseil"),"Changement de contexte carrière invalide un conseil différé du même écran")
	app.model.meta.week -= 1; obstacle.queue_free(); await settle()
	# Actual refusal to write remains readable, including when reduced.
	var blocker := OS.get_environment("CD_GODOT_DATA_DIR").path_join("guide-blocker")
	var deny := FileAccess.open(blocker,FileAccess.WRITE); deny.store_string("obstacle"); deny.close()
	guide.profile.directory = blocker; guide.open_help(); await settle()
	check(not guide.profile.last_error.is_empty() and guide._error_panel.is_visible_in_tree(),"Refus disque réel visible")
	check(contained(guide.get_global_rect(),guide._error.get_global_rect()),"Erreur entièrement contenue développée")
	guide.close(); await settle()
	check(contained(guide.get_global_rect(),guide._error.get_global_rect()),"Erreur entièrement contenue réduite")
	check(career_before == FileAccess.get_file_as_bytes(disk_path), "Layout ne modifie pas les octets carrière/RNG")
	var file := FileAccess.open(OS.get_environment("CD_GUIDE_CAPTURES").path_join("metrics.json"),FileAccess.WRITE); file.store_string(JSON.stringify(metrics,"\t")); file.close()
	await finish()

func dock_cases() -> void:
	# A real tactical command creates the real session receipt and N10 button.
	var attack: String = app.model.tactics.attacks[1].id
	var defense: String = app.model.tactics.defenses[1].id
	app._command("set_tactics",{"attack":attack,"defense":defense}); await wait_model(); await settle()
	check(app.bridge.last_response_ok and not app.decision_feedback.receipts().is_empty(),"Vrai reçu tactique N10 disponible")
	var disk_path: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_file_as_bytes(disk_path)
	# An important tip after a notice must fit between real offer rows, even in
	# the old square headless fixture, without climbing into the page header.
	root.size = Vector2i(1440,1440); root.content_scale_size = Vector2i(1440,1440)
	app._navigate("Recrutement"); await settle()
	var tip: String = Content.fragment("decision-contrat").text
	var voice_dir := OS.get_environment("CD_GODOT_DATA_DIR").path_join("dock-important-voice"); DirAccess.make_dir_recursive_absolute(voice_dir)
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 24000
	var pcm := PackedByteArray(); pcm.resize(4800); wav.data = pcm; check(wav.save_to_wav(voice_dir.path_join("silence.wav")) == OK,"WAV local de réception conseil important")
	var manifest := FileAccess.open(voice_dir.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"clips":[{"id":"dock-important","text":tip,"text_sha256":tip.sha256_text(),"file":"silence.wav"}]})); manifest.close()
	guide.speech.load_manifest(voice_dir.path_join("manifest.json")); guide.speech.volume = 0; guide.speech.set_muted(false)
	var requested: Array[String] = []; var on_requested := func(text: String):requested.append(text)
	guide.speech.requested.connect(on_requested)
	var facts: Dictionary = app.model.duplicate(true); facts.meta.negotiation = {"status":"signed","playerId":"dock-layout-only"}
	var notice := ConfirmationDialog.new(); app.add_child(notice); notice.popup_centered(); await settle()
	guide.consider_context("Recrutement",facts,"recruit",true)
	check(not guide.expanded and requested.is_empty(),"Notice prioritaire sans parole cachée")
	notice.hide(); notice.queue_free(); await process_frame
	guide.consider_context("Recrutement",facts,"snapshot",true); await settle()
	check(guide.expanded and guide.bubble.text == tip,"Conseil important réellement lisible après la notice")
	check(requested == [tip],"Parole exacte du conseil important demandée une seule fois")
	check(contained(Rect2(Vector2.ZERO,app.size),guide.get_global_rect()) and guide.position.y >= app.size.y*.55,"Conseil important dans la zone basse, loin des titres")
	check(not guide._covers_priority(guide._priority_rects()),"Conseil important sans masquer les offres")
	var stable := guide.position
	for i in 4: guide._avoid_primary_controls()
	check(guide.position == stable,"Position basse stable entre les commandes principales")
	guide.close(); guide.speech.set_muted(true); guide.speech.requested.disconnect(on_requested)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = resolution
		root.content_scale_size = Vector2i(mini(resolution.x,1600),mini(resolution.y,900))
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		app._navigate("Bureau"); await settle(); guide.close(); await settle()
		var dock: Control = app.root_content.find_child("CoachCompactDock",true,false)
		var target: Button = app.root_content.find_child("DecisionFeedbackButton",true,false)
		check(is_instance_valid(dock),"Emplacement Gabi fourni par le vrai footer : "+str(resolution))
		check(target != null and not target.disabled,"N10 activé : "+str(resolution))
		if target == null: continue
		if resolution.x in [1280,1920]: await capture("dock-"+str(resolution.x)+"-compact")
		for part in [.25,.5,.75]:
			await click(target,part)
			var receipt: AcceptDialog = app.get_node_or_null("DecisionFeedbackDialog")
			check(receipt != null and receipt.visible,"Vrai clic N10 à "+str(part)+" : "+str(resolution))
			check(not guide.expanded,"Clic N10 ne déclenche jamais Gabi : "+str(part)+str(resolution))
			if receipt != null and resolution.x == 1600 and part == .5: await capture("dock-1600-N10-modal")
			if receipt != null: receipt.hide(); receipt.queue_free()
			guide.close(); await settle()
		for name in ["GuideHelp","GuideTour"]:
			var button: Button = guide.find_child(name,true,false)
			if dock != null: check(contained(dock.get_global_rect(),button.get_global_rect()),"Vrai contrôle dans son proxy : "+name+str(resolution))
			check(not button.get_global_rect().intersects(target.get_global_rect()),"Gabi hors de N10 : "+name+str(resolution))
			await click(button)
			check(guide.expanded and guide.mode == ("screen" if name == "GuideHelp" else "tour"),"Vrai clic indépendant : "+name+str(resolution))
			check(app.get_node_or_null("DecisionFeedbackDialog") == null,"Gabi ne déclenche pas N10 : "+name)
			await settle()
			if dock != null: check(guide.get_global_rect().end.y <= dock.get_parent().get_global_rect().position.y,"Bulle au-dessus du footer : "+name+str(resolution))
			guide._settings_open = true; guide._layout(); await settle()
			if dock != null: check(guide.get_global_rect().end.y <= dock.get_parent().get_global_rect().position.y,"Options au-dessus du footer : "+name+str(resolution))
			guide._settings_open = false; guide.close(); await settle()
		app.model.meta.saveError = true
		app.status.text = app._settled_status_text()
		guide.open_help(); guide._settings_open = true; guide._layout(); await settle()
		check(app.status.text.begins_with("DERNIÈRE SAUVEGARDE IMPOSSIBLE"),"Statut erreur de sauvegarde prioritaire")
		var status_width: float = app.status.get_theme_font("font").get_string_size(app.status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,app.status.get_theme_font_size("font_size")).x
		check(status_width <= app.status.size.x,"Erreur footer entièrement lisible sans ellipse : "+str(resolution))
		if resolution.x == 1280: await capture("dock-1280-options-saveError")
		for painted in guide._painted_controls():
			check(not painted.get_global_rect().intersects(app.status.get_global_rect()),"Erreur footer hors peinture Gabi : "+str(resolution))
		app.model.meta.saveError = false; app.status.text = app._settled_status_text()
		guide._settings_open = false; guide.close(); await settle()
		var modal := ConfirmationDialog.new(); app.add_child(modal); modal.popup_centered(); await settle(); guide.refresh()
		check(guide.find_child("GuideHelp",true,false).disabled and guide.find_child("GuideTour",true,false).disabled,"Modale conserve les gardes des contrôles dockés")
		modal.hide(); modal.queue_free(); await settle(); guide.refresh()
		check(app.root_content.offset_bottom == 0,"Aucune bande supplémentaire réservée")
		guide.disable(); await settle()
		if dock != null: check(not dock.visible,"Désactivation libère la largeur du proxy")
		guide.open_help(); await settle(); guide.close(); await settle()
		if dock != null:
			check(dock.visible,"Réactivation restitue les contrôles dockés")
			dock.name = "LegacyGuideSlot"; guide._layout(); await settle()
			check(contained(Rect2(Vector2.ZERO,app.size),guide.get_global_rect()),"Ancien écran sans dock reste utilisable")
			dock.name = "CoachCompactDock"; guide._layout(); await settle()
			check(contained(dock.get_global_rect(),guide.find_child("GuideHelp",true,false).get_global_rect()),"Retour du proxy sans reparentage")
		var original_directory: String = guide.profile.directory
		var blocker: String = original_directory.path_join("dock-write-blocker")
		var file := FileAccess.open(blocker,FileAccess.WRITE); file.store_string("obstacle"); file.close()
		guide.profile.directory = blocker; guide.open_help(); guide._settings_open = true; guide._layout(); await settle()
		check(not guide.profile.last_error.is_empty() and guide._error_panel.is_visible_in_tree(),"Vraie erreur guide visible au-dessus du footer")
		if dock != null: check(guide._error_panel.get_global_rect().end.y <= dock.get_parent().get_global_rect().position.y,"Erreur guide développée ne masque pas le footer")
		guide._settings_open = false; guide.close(); await settle()
		if dock != null:
			check(guide._error_panel.get_global_rect().end.y <= dock.get_parent().get_global_rect().position.y,"Erreur guide repliée ne masque pas le footer")
			check(contained(dock.get_global_rect(),guide.find_child("GuideHelp",true,false).get_global_rect()),"Erreur guide garde les vrais contrôles dans le proxy")
		guide.profile.directory = original_directory; check(guide._save(),"Fin du refus disque explicite sans repli"); await settle()
		metrics.append({"case":"dock-"+str(resolution.x),"dock":str(dock.get_global_rect()) if dock != null else "absent","N10":str(target.get_global_rect()),"help":str(guide.find_child("GuideHelp",true,false).get_global_rect()),"tour":str(guide.find_child("GuideTour",true,false).get_global_rect())})
	check(before == FileAccess.get_file_as_bytes(disk_path),"Clics et footer ne modifient pas les octets carrière")
	var file := FileAccess.open(OS.get_environment("CD_GUIDE_CAPTURES").path_join("metrics.json"),FileAccess.WRITE); file.store_string(JSON.stringify(metrics,"\t")); file.close()

func finish() -> void:
	guide.destroy(); await process_frame; app.bridge.stop()
	var until := Time.get_ticks_msec() + 4000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < until: await process_frame
	app.queue_free(); await settle()
	print("GABI LAYOUT : ",checks," contrôles ; ",failures.size()," échec(s)"); quit(0 if failures.is_empty() else 1)

