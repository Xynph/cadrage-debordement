extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}, target: String = "") -> void:
	app._command(id, payload, target)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Commande réelle " + id)
	await settle()
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var file := OS.get_environment("CD_GUIDE_INTEGRATION_CAPTURES").path_join(id + ".png")
	check(root.get_texture().get_image().save_png(file) == OK, "Capture raccord " + id)
func menu_button() -> Button:
	for control in app.root_content.find_children("*", "Button", true, false):
		if control.text == "MENU & SAUVEGARDES": return control
	return null
func coach_geometry(context: String) -> void:
	var menu := menu_button()
	if menu == null: return
	check(not menu.get_global_rect().intersects(app.coach.get_global_rect()), "Coach hors du menu bas après " + context + " / " + str(root.size.x))
	check(app.coach.get_global_rect().position.x >= app.workspace_inset.get_global_rect().position.x, "Coach dans l'espace de travail après " + context)
func menu_input(mouse: bool) -> void:
	var menu := menu_button()
	check(menu != null and menu.is_visible_in_tree() and not menu.disabled, "Menu bas visible et actif")
	if menu == null: return
	check(menu.get_global_rect().end.y <= app.size.y, "Menu bas dans la fenêtre")
	if mouse:
		var point := menu.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
		# Rectangles use logical viewport coordinates, also when canvas_items stretches.
		root.push_input(motion, true); await process_frame
		for pressed in [true, false]:
			var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
			event.position = point; event.global_position = point; event.pressed = pressed
			root.push_input(event, true); await process_frame
	else:
		menu.grab_focus(); await process_frame
		check(menu.has_focus(), "Focus clavier du menu bas")
		for pressed in [true, false]:
			var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = pressed
			Input.parse_input_event(event); await process_frame
	await settle()
	check(app.get_children().any(func(child): return child is AcceptDialog and child.visible and child.title == "Votre carrière"), "Menu bas ouvert par " + ("souris" if mouse else "Entrée") + " / " + str(root.size.x))
	app._clear_dialogs(); await settle()
func ordinary_routes() -> void:
	# No open_help between the render under test and geometry / input assertions.
	app.coach.close()
	app._navigate("Accueil"); await settle()
	await command("snapshot")
	for control in app.root_content.find_children("*", "Button", true, false):
		if control.text == "REPRENDRE LA CARRIÈRE  →": control.pressed.emit(); break
	await settle()
	check(app.route == "Bureau", "Reprise réelle depuis l'accueil")
	coach_geometry("reprise")
	await capture("bureau-coach-compact-" + str(root.size.x))
	await menu_input(true)
	app._navigate("Effectif"); await settle()
	coach_geometry("navigation compacte")
	await menu_input(false)
	app._navigate("Bureau"); await command("snapshot")
	coach_geometry("snapshot compact")
	app.coach.open_tour(); await settle()
	app.coach.profile.data.step = "effectif"
	app.coach.refresh()
	app.coach._go(); await settle()
	check(app.route == "Effectif", "Navigation réelle par le guide")
	coach_geometry("navigation guide développé")
	await menu_input(true)
	app.coach.open_help(); await settle()
	app._navigate("Bureau"); await settle()
	check(app.coach.expanded, "Coach réellement développé après navigation")
	coach_geometry("navigation développée")
	await capture("bureau-coach-developpe-" + str(root.size.x))
	await menu_input(false)
	app.coach.open_help(); await settle()
	check(app.coach.expanded, "Coach ouvert avant la commande snapshot")
	await command("snapshot")
	check(not app.coach.expanded, "La garde de commande replie volontairement le coach")
	coach_geometry("snapshot replié")
	await capture("bureau-coach-apres-snapshot-" + str(root.size.x))
	app.coach.close(); await settle()
func visible_paint_overlaps(control: Control) -> bool:
	for node in app.coach.find_children("*", "Control", true, false):
		if node.is_visible_in_tree() and (str(node.name) == "GuideSpeechBalloon" or node == app.coach.portrait or node is BaseButton):
			if node.get_global_rect().intersects(control.get_global_rect()): return true
	return false
func priority_controls() -> void:
	app._navigate("Match"); await settle()
	await command("begin_match"); await command("delegate")
	for resolution in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = resolution; DisplayServer.window_set_size(resolution); await settle()
		app.coach.open_help(); await settle()
		var finish: Button
		for button in app.root_content.find_children("*", "Button", true, false):
			if str(button.text).contains("VALIDER LA JOURNÉE"): finish = button
		check(finish != null and not finish.disabled, "Validation finale réelle présente")
		if finish != null: check(not visible_paint_overlaps(finish), "Bulle, portrait et boutons hors validation finale / " + str(resolution.x))
		await capture("coach-resultat-validation-" + str(resolution.x))
	# Real click on the finish action while the coach is open.
	var finish: Button
	for button in app.root_content.find_children("*", "Button", true, false):
		if str(button.text).contains("VALIDER LA JOURNÉE"): finish = button
	if finish != null:
		var point := finish.get_global_rect().get_center()
		for pressed in [true,false]:
			var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.global_position = point; event.pressed = pressed
			root.push_input(event,true); await process_frame
		var deadline := Time.get_ticks_msec() + 30000
		while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
		await settle(); check(app._live().is_empty(), "Validation de la journée accessible à la souris avec Gabi ouvert")
	await command("begin_match"); await command("delegate"); app.coach.open_help(); await settle()
	finish = null
	for button in app.root_content.find_children("*", "Button", true, false):
		if str(button.text).contains("VALIDER LA JOURNÉE"): finish = button
	if finish != null:
		finish.grab_focus(); await process_frame
		for pressed in [true,false]:
			var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = pressed
			Input.parse_input_event(event); await process_frame
		var deadline := Time.get_ticks_msec() + 30000
		while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
		await settle(); check(app._live().is_empty(), "Validation de la journée accessible au clavier avec Gabi ouvert")
	app._navigate("Formation"); await settle(); app.coach.open_help(); await settle()
	for button in app.root_content.find_children("*", "Button", true, false):
		if str(button.text) == "PREMIER CONTRAT PRO" and button.get_global_rect().intersects(app.body_scroll.get_global_rect()):
			check(not visible_paint_overlaps(button), "Promotion visible hors de la peinture du coach")
	await capture("coach-formation-commandes-1920")
	app.coach.close(); await settle()
func market_keyboard() -> void:
	app._navigate("Recrutement"); await settle()
	for expected in ["MarketDirection", "MarketReset"]:
		var candidate: Button
		for control in app.body.find_children("*", "Button", true, false):
			if (expected == "MarketDirection" and ("Croissant" in control.text or "Décroissant" in control.text)) or (expected == "MarketReset" and control.text == "Réinitialiser"):
				candidate = control; break
		check(candidate != null, "Commande du marché présente " + expected)
		if candidate == null: continue
		candidate.grab_focus(); await settle()
		var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = true
		Input.parse_input_event(event); await process_frame
		event = InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = false
		Input.parse_input_event(event); await settle()
		var focused := root.gui_get_focus_owner()
		check(focused != null and str(focused.name) == expected, "Focus conservé après Entrée " + expected)
func profile_error() -> void:
	DisplayServer.window_set_size(Vector2i(1280,800))
	app._navigate("Match"); await settle()
	var filename: String = str(app.model.meta.dataDir).path_join("guide.json")
	var held := filename + ".reception-avant"
	check(DirAccess.rename_absolute(filename, held) == OK, "Préférences de réception préservées")
	check(DirAccess.make_dir_absolute(filename) == OK, "Échec réel préparé au chemin du guide")
	app.coach.open_help(); await settle()
	var error_label: Label = app.coach.find_child("GuideError", true, false)
	check(error_label != null and error_label.is_visible_in_tree() and not app.coach.profile.last_error.is_empty(), "Erreur réelle visible sans Options")
	check(app.coach.reserved_height_changed != null and app.coach.mouse_filter == Control.MOUSE_FILTER_IGNORE and app.coach.find_child("GuideError", true, false).is_visible_in_tree(), "Erreur visible sans bloquer l’espace autour du coach")
	await capture("coach-erreur-integre-1280")
	app.coach.disable(); await settle()
	check(app.coach.visible and not app.coach.expanded and not app.coach.speech.speaking, "Désactivation non persistée explique sa portée de session")
	check(error_label.is_visible_in_tree(), "Erreur reste accessible après désactivation")
	await capture("coach-erreur-desactivation-integree-1280")
	check(DirAccess.remove_absolute(filename) == OK, "Obstacle temporaire retiré")
	check(DirAccess.rename_absolute(held, filename) == OK, "Fichier de préférences conservé puis restauré")
	app.coach.open_help(); await settle()
	check(app.coach.profile.last_error.is_empty(), "Reprise d'écriture explicite après restauration du disque")
	app.coach.close(); await settle()
func run() -> void:
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	var has_coach: bool = app.get_property_list().any(func(p): return p.name == "coach")
	check(has_coach, "Le coach est raccordé dans la vraie application")
	if has_coach:
		check(is_instance_valid(app.coach), "Une instance native de coach")
		check(app.coach.portrait.texture is AtlasTexture and app.coach.portrait.texture.atlas != null, "Atlas original réellement chargé")
		app.coach.speech.set_muted(true)
		for resolution in [Vector2i(1280,800), Vector2i(1440,900), Vector2i(1920,1080)]:
			root.size = resolution
			DisplayServer.window_set_size(resolution); await settle()
			app._navigate("Création"); await settle()
			await command("new_career", {"mode":"common", "club":29}, "Bureau")
			coach_geometry("création")
		await command("export")
		var initial: String = app.model.meta.exportText
		var filename: String = str(app.model.meta.dataDir).path_join("donnees.json")
		var initial_hash := FileAccess.get_sha256(filename)
		await market_keyboard()
		for resolution in [Vector2i(1280,800), Vector2i(1440,900), Vector2i(1920,1080)]:
			root.size = resolution
			DisplayServer.window_set_size(resolution); await settle()
			await ordinary_routes()
			for route in ["Bureau","Effectif","Composition","Préparation","Recrutement","Finances","Club","Calendrier","Classements","Match","Accueil","Création","Packs","Staff","Formation"]:
				app._navigate(route); await settle()
				coach_geometry("navigation ordinaire " + route)
				app.coach.open_help(); await settle()
				check(app.coach.expanded, "Aide ouverte " + route)
				check(app.coach.get_global_rect().end.y <= app.size.y + 1, "Guide dans la fenêtre " + route)
				check(app.coach.get_global_rect().position.x >= 0, "Guide horizontal " + route)
				var scroll: ScrollContainer = app.entry_scroll if route in ["Accueil","Création","Packs"] else app.body_scroll
				check(is_instance_valid(scroll) and scroll.follow_focus, "Corps défilable " + route)
				if is_instance_valid(scroll):
					check(app.root_content.offset_bottom == 0 and app.coach.get_global_rect().size.x <= 500 and app.coach.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bulle libre sans panneau interceptant la page " + route)
				await capture(route.to_lower() + "-" + str(resolution.x))
				app.coach.close(); await settle()
		await profile_error()
		await command("export")
		check(app.model.meta.exportText == initial, "Visites et tailles sans mutation de carrière/RNG exporté")
		check(FileAccess.get_sha256(filename) == initial_hash, "Visites sans écriture du profil sportif")
		await priority_controls()
		app._navigate("Match"); await settle()
		await command("begin_match")
		app.coach.open_help(); await settle()
		check(not app.coach.expanded, "Pas d'aide développée pendant le direct")
		await command("pause", {"paused":true})
		app.coach.open_help(); await settle()
		check(app.coach.expanded, "Aide explicitement ouverte en pause")
		app.confirm("Vérification", "Dialogue réel de réception", func(): pass)
		await settle()
		check(not app.coach.expanded and not app.coach.speech.speaking, "Dialogue prioritaire et parole arrêtée")
		app._clear_dialogs(); await settle()
		app.coach.disable(); await settle()
		check(not app.coach.visible, "Désactivation persistée sans erreur")
		app.settings(); await settle()
		var dialogs := app.find_children("*", "AcceptDialog", false, false)
		var settings: AcceptDialog
		for dialog in dialogs:
			if dialog.visible: settings = dialog
		check(settings != null, "Paramètres disponibles")
		if settings != null: settings.custom_action.emit("coach")
		await settle()
		check(app.coach.visible and app.coach.expanded, "Réactivation depuis les paramètres")
	print("RACCORD COACH : %d contrôles ; %d échec(s)" % [checks, failures.size()])
	app.closing = true; app.timer.stop()
	if has_coach and is_instance_valid(app.coach): app.coach.destroy()
	app.bridge.stop()
	deadline = Time.get_ticks_msec() + 3000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	app.queue_free(); await settle()
	quit(0 if failures.is_empty() else 1)
