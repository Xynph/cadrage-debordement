extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_PREPARATION_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
func settle() -> void:
	for i in 10: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse worker bornée")
	app.timer.stop()
	await settle()
func named(id: String) -> Control: return app.body.find_child(id, true, false)
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
func keyboard(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Commande réellement visible au clavier")
	if control == null: return
	control.grab_focus()
	await settle()
	check(control.has_focus(), "Focus " + str(control.name))
	await key(KEY_ENTER)
	await worker()
func mouse(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Commande réellement visible à la souris")
	if control == null: return
	app.body_scroll.ensure_control_visible(control)
	await settle()
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await worker()
## Section d'un sous-onglet de la Préparation riche (shell.gd, RICH_FROM_720P) : l'Entraînement ouvre son propre gabarit.
func section(id: String) -> Control:
	return named("ImmersiveTraining") if id == "Entrainement" else named("Preparation" + id)
func shown(control: Control) -> bool:
	return control != null and control.is_visible_in_tree()
func tab(id: String) -> void:
	# Depuis l'Entraînement, le retour au dossier redonne la barre d'onglets de la Préparation.
	if named("PreparationTab" + id) == null and named("TrainingBackToPreparation") != null:
		await keyboard(named("TrainingBackToPreparation"))
	await keyboard(named("PreparationTab" + id))
	check(shown(section(id)), "Sous-onglet visible " + id)
	var visible := 0
	for section_id in ["Dossier", "Consignes", "Entrainement"]:
		if shown(section(section_id)): visible += 1
	check(visible == 1 and app.management_ui.preparation.tab == ["Dossier", "Consignes", "Entrainement"].find(id), "Un seul onglet et une seule section actifs")
	if id != "Entrainement":
		var selected := 0
		for tab_id in ["Dossier", "Consignes", "Entrainement"]:
			if named("PreparationTab" + tab_id).button_pressed: selected += 1
		check(selected == 1, "Un seul onglet enfoncé")
## Ouvre une fenêtre de l'Entraînement par son repère de semaine puis l'action de la séance sélectionnée.
func training_slot(slot: int) -> void:
	await keyboard(named("TrainingStep" + str(slot)))
	await keyboard(named("TrainingEditSelected"))
## Part de la hauteur visible laissée vide sous le dernier élément peint de la section
## (conteneurs de mise en page exclus : ils s'étirent sans rien dessiner ; les panneaux comptent).
func void_ratio(section: Control) -> float:
	var viewport: Rect2 = app.body_scroll.get_global_rect()
	var bottom: float = viewport.position.y
	for node: Node in section.find_children("*", "Control", true, false):
		var control := node as Control
		if (control is Container and not control is PanelContainer) or not control.is_visible_in_tree() or control.size.y <= 0: continue
		bottom = maxf(bottom, control.get_global_rect().end.y)
	return maxf(0.0, viewport.end.y - bottom) / maxf(1.0, viewport.size.y)
## Nom de club long dans la colonne de gauche : deux lignes au plus, taille réduite, jamais tronqué.
func club_title_fits() -> void:
	var D = load("res://ui/immersive08/primitives.gd")
	var holder := Control.new()
	root.add_child(holder)
	for title in ["RUGBY CLUB DES DEUX VALLÉES ATLANTIQUE", "UNION SPORTIVE DU PLATEAU", "XV"]:
		var label: Label = D.fit_title(D.text(holder, 124, 331, title, 23, Color.WHITE, 700, 222, HORIZONTAL_ALIGNMENT_CENTER), 222, 46)
		var size: int = label.get_meta("fit_title_size")
		var font: Font = label.get_theme_font("font")
		var lines: int = D.title_lines(font, title, size, label.size.x)
		check(lines <= 2 and lines == int(label.get_meta("fit_title_lines")), "Nom du club sur deux lignes au plus : " + title)
		check(font.get_height(size) * lines <= label.size.y + 1.0, "Nom du club entier, sans points de suspension : " + title)
	holder.queue_free()
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(proof.path_join(id + ".png")) == OK, "Capture " + id)
func run() -> void:
	# Headless starts with a 64x64 viewport unless the recipe sets it explicitly.
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("import", {"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Préparation")
	await settle()
	check(named("PreparationTabDossier") != null, "Trois vrais sous-onglets de préparation")
	if named("PreparationTabDossier") != null: await cases()
	var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	file.close()
	app.closing = true
	app.bridge.stop()
	print("Préparation : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
func cases() -> void:
	print("PREPARATION_INITIAL ", root.size, " / ", app.size)
	club_title_fits()
	await command("export")
	var before: String = app.model.meta.exportText
	var disk_path := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk_path)
	check(not bytes.is_empty(), "Profil réel pour invariant sauvegarde/RNG")
	await tab("Dossier")
	await key(KEY_RIGHT)
	check(shown(named("PreparationConsignes")) and named("PreparationTabConsignes").has_focus(), "Flèche droite : onglet et focus suivent")
	await key(KEY_RIGHT)
	check(shown(named("ImmersiveTraining")) and app.management_ui.preparation.tab == 2, "Flèche droite : entraînement accessible")
	# L'Entraînement a son propre gabarit : on revient aux consignes par la Préparation.
	await tab("Consignes")
	named("PreparationTabConsignes").grab_focus()
	await settle()
	# La barre d'onglets porte aussi les raccourcis du chapitre (préparer la suite, Composition, Plan de jeu, match) :
	# Tab les traverse avant d'atteindre les consignes (dix pressions au plus).
	var focus: Control = null
	for pression in 10:
		await key(KEY_TAB)
		focus = app.get_viewport().gui_get_focus_owner()
		if focus != null and str(focus.name).begins_with("PreparationAttack_"): break
	check(focus != null and str(focus.name).begins_with("PreparationAttack_") and focus.is_visible_in_tree(), "Tab atteint les vraies consignes visibles")
	await mouse(named("PreparationTabDossier"))
	check(shown(named("PreparationDossier")), "Sélection d’onglet à la souris")
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		for id in ["Dossier", "Consignes", "Entrainement"]:
			await tab(id)
			check(app.body_scroll.get_global_rect().end.y <= app.size.y + 1, "CareerWorkspace borné " + str(resolution))
			check(named("ImmersivePreparation" if id != "Entrainement" else "ImmersiveTraining") != null, "Gabarit riche de la Préparation " + id + " " + str(resolution))
			var empty := void_ratio(section(id))
			check(empty <= 0.30, "Préparation sans vide > 30 %% de la hauteur (%s %s : %d %%)" % [id, resolution, roundi(empty * 100)])
			check(app.heading != null and app.heading.is_visible_in_tree() and not app.heading.text.strip_edges().is_empty(), "Titre de la page visible " + str(resolution))
			if named("CarnetPreparation") != null:
				check(named("PreparationBanner") != null and named("PreparationBanner").is_visible_in_tree(), "Bannière de la page visible " + str(resolution))
				if id == "Dossier":
					# Le bas du Dossier porte des repères utiles ; la photo du club n'est plus qu'une bannière basse.
					var board := named("PreparationWeekBoard")
					check(board != null and board.is_visible_in_tree(), "Repères de la semaine visibles sous le dossier " + str(resolution))
					check(named("PreparationFiller_city") == null, "Plus de grande photo de remplissage dans le Dossier " + str(resolution))
					var strip := named("PreparationStrip_city")
					var viewport_height: float = app.body_scroll.get_global_rect().size.y
					check(strip != null and strip.get_global_rect().size.y <= viewport_height * .15, "Photo du club réduite à une bannière (%s : %d px)" % [resolution, roundi(strip.get_global_rect().size.y) if strip != null else -1])
					if board != null and strip != null:
						check(board.get_global_rect().size.y >= strip.get_global_rect().size.y * 2.0, "Les repères occupent plus de place que la photo " + str(resolution))
					check(named("PreparationStaffNotes") != null and named("PreparationSquadPulse") != null, "Repères du staff et état du XV présents " + str(resolution))
			var chapter_rows := 0
			for row: Node in app.root_content.find_children("ChapterSubnavigation", "", true, false):
				if (row as Control).is_visible_in_tree(): chapter_rows += 1
			check(chapter_rows == 0, "Une seule barre d’onglets sur la Préparation " + str(resolution))
			if id == "Consignes":
				for list_id in ["PreparationAttackScroll", "PreparationDefenseScroll"]:
					var list: ScrollContainer = named(list_id)
					check(list.size.y >= 190, "190 unités de lecture conservées " + list_id)
					check(list.get_global_rect().end.x <= app.size.x + 1, "Liste sans débordement horizontal")
			print("PREPARATION_GEOMETRY ", JSON.stringify({"window":root.size,"canvas":app.size,"tab":id,"workspace":app.body_scroll.get_global_rect(),"section":section(id).get_global_rect()}))
			if resolution.x == 1280: await capture("preparation-1280-" + id.to_lower())
		await tab("Entrainement")
		# Le jour de match reste à un clic : « Continuer » du bandeau et le repère « Jour de match » de la semaine.
		var match_button := app.find_child("ImmersiveContinue", true, false) as Control
		check(match_button != null and Rect2(Vector2.ZERO, app.size).grow(1).encloses(match_button.get_global_rect()), "Match visible dès ouverture Entraînement " + str(resolution))
		var match_step := named("TrainingStep11")
		check(match_step != null, "Repère Jour de match présent " + str(resolution))
		if match_step != null:
			match_step.grab_focus()
			await settle()
			check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(match_step.get_global_rect()), "Accès au match par focus/scroll " + str(resolution))
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	await settle()
	await tab("Consignes")
	var attack_scroll: ScrollContainer = named("PreparationAttackScroll")
	attack_scroll.scroll_vertical = 100
	await settle()
	var scroll_before := attack_scroll.scroll_vertical
	var scroll_bar := attack_scroll.get_v_scroll_bar()
	if ProjectSettings.get_setting("display/window/stretch/mode") == "disabled":
		check(scroll_before > 0, "720p 1:1 : mémoire testée sur un défilement tactique réellement non nul")
	else:
		check(scroll_before > 0 or scroll_bar.max_value <= scroll_bar.page, "Stretch : position réelle ou liste entièrement visible")
	app._render()
	await settle()
	check(named("PreparationConsignes").is_visible_in_tree(), "Rebuild conserve le sous-onglet")
	check(named("PreparationAttackScroll").scroll_vertical == scroll_before, "Rebuild conserve le scroll tactique")
	app._navigate("Bureau")
	await settle()
	app._navigate("Préparation")
	await settle()
	check(named("PreparationConsignes").is_visible_in_tree(), "Navigation conserve le sous-onglet")
	check(named("PreparationAttackScroll").scroll_vertical == scroll_before, "Navigation conserve le scroll tactique")
	await tab("Dossier")
	await mouse(named("OpenOppositionDossier"))
	var dossier := app.find_child("OppositionDossier", true, false)
	check(dossier != null and dossier.visible, "Vrai dossier ouvert à la souris")
	app._clear_dialogs()
	await settle()
	check(FileAccess.get_file_as_bytes(disk_path) == bytes, "Consultation : octets profil inchangés")
	await command("export")
	check(app.model.meta.exportText == before, "Consultation : S et RNG/export identiques")
	await command("new_career", {"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Préparation")
	await settle()
	check(named("PreparationDossier").is_visible_in_tree(), "Nouvelle carrière remet l’onglet Dossier")
	await tab("Consignes")
	var option: Dictionary = app.model.tactics.attacks.filter(func(o):return o.id != app.model.tactics.attack)[0]
	var defense: String = app.model.tactics.defense
	var target_id := "PreparationAttack_" + str(option.id)
	var target: Button = named(target_id)
	await keyboard(target)
	check(app.model.tactics.attack == option.id and app.model.tactics.defense == defense, "Consigne exacte via le vrai clavier, défense conservée")
	check(named("PreparationConsignes").is_visible_in_tree() and named(target_id).has_focus(), "Commande : onglet et focus conservés après rebuild")
	await tab("Entrainement")
	# Entraînement riche : préparation spécifique (repère 1) et niveau adverse (repère 9) se choisissent dans leur fenêtre.
	var selected_values: Array[String] = []
	for pair in [["CollectiveFocus", "set_collective_focus", 1, app.model.decisions.training.collective], ["OpponentLevel", "set_opponent_level", 9, app.model.decisions.difficulty]]:
		await training_slot(pair[2])
		var dialog := app.find_child("TrainingChoices", true, false) as AcceptDialog
		check(dialog != null and dialog.visible, "Fenêtre de choix ouverte " + pair[0])
		var source: Dictionary = pair[3]
		var options: Array = source.get("options", [])
		var wanted := ""
		for option_entry: Dictionary in options:
			if str(option_entry.id) != str(source.get("selected", "")):
				wanted = str(option_entry.id)
				break
		selected_values.append(wanted)
		var choice: Button = dialog.find_child(pair[0] + "_" + wanted, true, false) as Button if dialog != null else null
		check(choice != null and not choice.disabled, "Choix disponible " + pair[0])
		if choice == null: continue
		choice.pressed.emit()
		await worker()
		check(str((app.model.decisions.training.collective if pair[2] == 1 else app.model.decisions.difficulty).selected) == wanted, "Choix sportif persistant " + pair[1])
		check(shown(named("ImmersiveTraining")), "Entraînement conservé après commande " + pair[0])
	check(selected_values.size() == 2 and str(app.model.decisions.training.collective.selected) == selected_values[0] and str(app.model.decisions.difficulty.selected) == selected_values[1], "Projection worker confirme les deux paramètres exacts")
	# « Effectuer la séance » demande la charge : la fenêtre propose les vraies charges.
	await keyboard(named("TrainingValidateWeek"))
	var session := app.find_child("TrainingSessionDialog", true, false) as AcceptDialog
	var normal: Button = session.find_child("PreparationTrain_normal", true, false) as Button if session != null else null
	check(normal != null, "Charge normale proposée")
	if normal != null:
		normal.pressed.emit()
		await worker()
	check(app.model.meta.trained, "Entraînement réel exécuté")
	check(shown(named("ImmersiveTraining")) and app.management_ui.preparation.tab == 2, "Entraînement : onglet conservé")
	await command("export")
	var saved: String = app.model.meta.exportText
	await command("import", {"text":saved})
	app._navigate("Préparation")
	await settle()
	check(named("PreparationDossier").is_visible_in_tree(), "Import remet l’onglet Dossier")
	await tab("Consignes")
	check(app.model.tactics.attack == option.id, "Import conserve la vraie consigne")
	await tab("Entrainement")
	check(app.model.meta.trained and named("TrainingValidateWeek").disabled, "Import conserve la séance, sans répétition")
	check(str(app.model.decisions.training.collective.selected) == selected_values[0] and str(app.model.decisions.difficulty.selected) == selected_values[1], "Import conserve les deux paramètres sportifs")
	await training_slot(11)
	check(app.route == "Match", "Accès réel au match")
	for i in 3:
		app._navigate("Préparation")
		app._navigate("Bureau")
	await settle()
	check(app.route == "Bureau", "Navigation rapide avant restauration différée sans erreur")
	var retiring: Control = load("res://ui/preparation_view.gd").build(app)
	app.body.add_child(retiring)
	retiring._restore()
	app.body.remove_child(retiring)
	# Exercise both a deferred call that has not started and one already awaiting.
	retiring._restore()
	await settle()
	retiring.queue_free()
	await settle()
	check(app.route == "Bureau", "Retrait de vue avant et pendant await sans accès à un arbre absent")
