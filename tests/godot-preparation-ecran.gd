extends SceneTree
## Écran « Préparation » (dossier adverse, revue DA du 19/11/2026) : tout ce qui a l'air cliquable change d'écran ou de
## sous-page, aucune petite fenêtre ouverte par un clic (hors « Préparer la suite » et « La reprise », partagées),
## aucun or hors Continuer, remarque de l'adjoint lue dans le staff. Carrière world-champ préparée par le .cjs.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
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
	for i in 12: await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)
func named(id: String) -> Control: return app.body.find_child(id, true, false)

## Fenêtres visibles (AcceptDialog, popup, Window) sous la racine, hors fenêtre principale.
func open_windows() -> Array[String]:
	var found: Array[String] = []
	for node: Node in root.find_children("*", "Window", true, false):
		if (node as Window).visible: found.append(str(node.name))
	return found

func reset() -> void:
	app._clear_dialogs()
	app.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""],"sub":""}
	app._navigate("Bureau")
	await settle()
	app._navigate("Préparation")
	await settle()

## Presse la commande et renvoie un résumé « route|onglet|sous-page » après le clic.
func press(button: Button) -> String:
	button.pressed.emit()
	await settle()
	var prep: Dictionary = app.management_ui.get("preparation", {})
	return "%s|%s|%s" % [app.route, str(prep.get("tab", 0)), str(prep.get("sub", ""))]

func gold_used(node: Node) -> int:
	var count := 0
	for control: Node in node.find_children("*", "Control", true, false):
		if control is Label:
			var color: Color = control.get_theme_color("font_color")
			if color.is_equal_approx(Charte.OR) or color.is_equal_approx(Charte.OR_VIF): count += 1
		for style_name: String in ["panel", "normal", "hover", "pressed", "focus"]:
			var style := (control as Control).get_theme_stylebox(style_name) as StyleBoxFlat
			if style != null and (style.bg_color.is_equal_approx(Charte.OR) or style.bg_color.is_equal_approx(Charte.OR_VIF) or style.border_color.is_equal_approx(Charte.OR)): count += 1
	return count

func run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("import", {"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await reset()
	var dossier := named("PreparationDossier")
	check(dossier != null and dossier.is_visible_in_tree(), "Dossier adverse affiché")
	for id in ["PreparationDanger", "PreparationComparison", "PreparationRecommendation", "PreparationRecent", "PreparationThreats"]:
		check(named(id) != null, "Panneau présent : " + id)
	# Leur XV probable arrive par la lecture seule « club_sheet » : on attend la reconstruction.
	for i in 240:
		if not app.find_children("PreparationTheirXIName_*", "Button", true, false).is_empty(): break
		await process_frame
	check(app.find_children("PreparationTheirXIName_*", "Button", true, false).size() == 15, "Leur XV probable : quinze noms cliquables")
	var adjoint := {}
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		for member: Dictionary in team.get("members", []):
			if str(member.get("role", "")) == "assistant" and adjoint.is_empty(): adjoint = member
	# Tableau détaillé de leur XV : sous-page avec la colonne « remarque de ton adjoint » et le nom de l'adjoint lu dans le staff.
	var tableau := named("PreparationTheirXIAll") as Button
	check(tableau != null, "Lien vers le tableau détaillé de leur XV")
	if tableau != null:
		if not adjoint.is_empty(): check(tableau.text.contains(str(adjoint.get("name", ""))), "Le nom de l'adjoint est lu dans le staff du club, jamais figé")
		var ouverture := await press(tableau)
		check(ouverture == "Préparation|0|xv" and named("PreparationTheirXITable") != null and open_windows().is_empty(), "Tableau détaillé : sous-page, pas une fenêtre (%s)" % ouverture)
		for i in 240:
			if not app.find_children("PreparationTheirXIName_*", "Button", true, false).is_empty(): break
			await process_frame
		check(app.find_children("PreparationTheirXIName_*", "Button", true, false).size() == 15, "Tableau détaillé : quinze noms cliquables")
		if not adjoint.is_empty(): check(named("PreparationAdjointLink") != null, "Lien vers la fiche de l'adjoint")
		await press(named("PreparationSubBack") as Button)
	await reset()
	check(gold_used(named("PreparationDossier")) == 0 and gold_used(named("PreparationTabs")) == 0, "Aucun or dans l'écran (réservé à Continuer)")
	var sector_buttons := app.find_children("PreparationSector_*", "Button", true, false)
	check(sector_buttons.size() >= 1, "Chaque secteur du rapport de force est cliquable")
	var windows_before := open_windows()
	# Rapport de force : chaque ligne change d'écran ou d'onglet.
	for i in sector_buttons.size():
		await reset()
		var button := app.find_children("PreparationSector_*", "Button", true, false)[i] as Button
		var nom := str(button.name)
		var summary := await press(button)
		check(summary != "Préparation|0|", "Ligne du rapport de force « %s » mène ailleurs (%s)" % [nom, summary])
		check(open_windows() == windows_before, "Aucune fenêtre ouverte par « %s » : %s" % [nom, str(open_windows())])
	# Repères : chaque ligne agit sans fenêtre.
	await reset()
	var briefing_ids: Array[String] = []
	for button: Node in app.find_children("PreparationBriefing_*", "Button", true, false): briefing_ids.append(str(button.name))
	check(not briefing_ids.is_empty(), "Repères « À faire avant le match » cliquables")
	for id in briefing_ids:
		await reset()
		var button := named(id) as Button
		if button == null: continue
		var summary := await press(button)
		check(summary != "Préparation|0|" or id == "PreparationBriefing_live", "Repère « %s » mène ailleurs (%s)" % [id, summary])
		check(open_windows() == windows_before, "Aucune fenêtre ouverte par « %s » : %s" % [id, str(open_windows())])
	# Sous-pages : conseils et repères, retour, historique Précédent.
	await reset()
	var conseils := await press(named("OpenOppositionDossier") as Button)
	check(conseils == "Préparation|0|conseils" and named("PreparationAdvice") != null and open_windows() == windows_before, "Conseils détaillés : sous-page, pas une fenêtre")
	check(gold_used(named("PreparationDossier")) == 0, "Aucun or dans les conseils")
	var retour := await press(named("PreparationSubBack") as Button)
	check(retour == "Préparation|0|" and named("PreparationComparison") != null, "Retour au dossier adverse")
	var reperes := await press(named("PreparationBriefingAll") as Button)
	check(reperes == "Préparation|0|reperes" and named("PreparationAllChecks") != null and open_windows() == windows_before, "Tous les repères : sous-page, pas une fenêtre")
	app.navigation_controller._travel(-1)
	await settle()
	check(str(app.management_ui.preparation.get("sub", "")) == "" and named("PreparationComparison") != null, "Précédent revient du sous-écran au dossier")
	# Noms : joueurs surveillés, XV adverse, clubs -> un écran, jamais une fenêtre.
	var noms: Array[String] = []
	for pattern in ["PreparationThreatName*", "PreparationTheirXIName_1", "PreparationOpponentLink", "PreparationFormClub", "PreparationContextClubOpponent"]:
		for button: Node in app.find_children(pattern, "Button", true, false): noms.append(str(button.name))
	check(noms.size() >= 3, "Noms cliquables : joueurs, XV adverse, clubs (%d)" % noms.size())
	for id in noms:
		await reset()
		var button := named(id) as Button
		if button == null or button.disabled: continue
		var avant: String = app.route
		var summary := await press(button)
		check(app.route != "Préparation" or avant != app.route, "Nom « %s » ouvre un écran (%s)" % [id, summary])
		check(open_windows() == windows_before, "Aucune fenêtre ouverte par « %s » : %s" % [id, str(open_windows())])
	# Consignes : or interdit aussi, et onglet Entraînement atteignable.
	await reset()
	await press(named("PreparationTabConsignes") as Button)
	check(gold_used(named("PreparationConsignes")) == 0 and gold_used(named("PreparationTabs")) == 0, "Aucun or dans les consignes")
	if not DisplayServer.get_name() == "headless" and not proof.is_empty():
		await reset()
		await settle()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(proof.path_join("preparation-1920.png")) == OK, "Capture du dossier")
	print("PREPARATION_ECRAN ", JSON.stringify({"controles":checks, "failures":failures}))
	app.closing = true
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
