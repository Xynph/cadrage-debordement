extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)
func settle() -> void:
	for i in 5: await process_frame
func wait_model() -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse du moteur : " + app.last_error)
	await settle()
	return not app.waiting and not app.model.is_empty()
## Clic gauche réel (survol, appui, relâche) au point `point` de la fenêtre.
func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()
func click(button: BaseButton) -> void:
	check(button != null and not button.disabled, "Commande disponible")
	if button == null or button.disabled: return
	button.grab_focus()
	await settle()
	check(button.has_focus(), "Focus clavier")
	await click_at(button.get_global_rect().get_center())
## Confirmation EN PLACE (confirmation_en_place.gd) : le bloc s'ouvre dans la page, sans petite fenêtre ; le second clic
## sur « Confirmer » envoie la commande. `accept` faux : « Annuler » referme le bloc sans rien envoyer.
func confirm_in_place(accept: bool = true) -> void:
	for child in app.get_children():
		check(not (child is ConfirmationDialog and child.visible), "Aucune petite fenêtre de confirmation")
	var block := app.find_child("ClubConfirmation", true, false) as Control
	check(block != null and block.is_visible_in_tree(), "Confirmation en place visible")
	if block == null: return
	var ok := block.find_child("ClubConfirmationOk", true, false) as Button
	var cancel := block.find_child("ClubConfirmationAnnuler", true, false) as Button
	check(ok != null and cancel != null, "Confirmer et Annuler présents")
	await scroll_to(cancel if not accept else ok)
	await click(ok if accept else cancel)
	check(not is_instance_valid(block) or not block.is_inside_tree(), "Bloc de confirmation refermé")
	if accept: await wait_model()
func scroll_to(control: Control) -> void:
	if control == null: return
	var node := control.get_parent()
	while node != null and not node is ScrollContainer: node = node.get_parent()
	if node != null: (node as ScrollContainer).ensure_control_visible(control)
	await settle()
func tabs() -> TabContainer:
	return app.body.find_children("*", "TabContainer", true, false)[0]
func open_tab(index: int) -> void:
	app._navigate("Stratégie")
	await settle()
	tabs().current_tab = index
	await settle()
func find(name: String) -> Control:
	return app.body.find_child(name, true, false) as Control
## Lien d'écran : un clic sur le chiffre ou la jauge ouvre `route`.
func check_link(tab: int, name: String, route: String) -> void:
	await open_tab(tab)
	var zone := find(name)
	check(zone != null, "Lien présent : " + name)
	if zone == null: return
	await scroll_to(zone)
	await click_at(zone.get_global_rect().get_center())
	check(app.route == route, "%s ouvre %s (écran : %s)" % [name, route, app.route])
## Petite fenêtre visuelle : un clic l'ouvre, Échap (mécanisme commun) la referme.
func check_window(tab: int, name: String, window: String) -> void:
	await open_tab(tab)
	var zone := find(name)
	check(zone != null, "Repère présent : " + name)
	if zone == null: return
	await scroll_to(zone)
	await click_at(zone.get_global_rect().get_center())
	var opened := PetiteFenetre.ouverte(self)
	check(opened != null and str(opened.name) == window, "%s ouvre la petite fenêtre %s" % [name, window])
	check(opened != null and opened.find_children("*", "Label", true, false).size() > 0, "Petite fenêtre garnie : " + window)
	check(PetiteFenetre.fermer_derniere(self), "Échap referme " + window)
	await settle()
	check(PetiteFenetre.ouverte(self) == null, "Plus de petite fenêtre ouverte après " + window)
func capture(label: String) -> void:
	if OS.get_environment("CD_STRATEGY_GRAPHICS") != "1": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CD_STRATEGY_ARTIFACTS").path_join(label + ".png"))
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if not await wait_model():
		finish()
		return
	app._command("new_career", {"mode":"common", "club":29}, "Stratégie")
	if not await wait_model():
		finish()
		return
	await ContextualFlow.settle_club_meetings(app, self, check)
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		app._navigate("Stratégie")
		await settle()
		check(root.size == resolution, "Fenêtre demandée " + str(resolution))
		check(app.size.is_equal_approx(app.get_viewport_rect().size), "L’application occupe toute la fenêtre")
		check(app.body_scroll.size.x >= app.size.x - 300, "Surface de lecture utile")
		check(app.body.find_child("CarnetStrategie", true, false) != null, "Stratégie rendue")
		for index in 3:
			tabs().current_tab = index
			await settle()
			check(tabs().size.x <= app.body_scroll.size.x + 2, "Largeur utile du contenu")
			await capture("strategie-%d-%d" % [resolution.x,index])
	root.size = Vector2i(1280,720)
	# Libellés lisibles : prix accentués, jalon du conseil en clair.
	await open_tab(2)
	check(find("FansPrice_equilibree") != null and (find("FansPrice_equilibree") as Button).text.begins_with("Équilibrée"), "Prix « Équilibrée » accentué")
	# Chiffres et jauge : chacun ouvre son écran.
	for link: Array in [[0, "DirectionLien_Tresorerie", "Finances"], [0, "DirectionLien_Salaires", "Finances"], [0, "DirectionLien_Projection", "Finances"], [0, "DirectionLien_Semaines", "Calendrier"], [0, "DirectionLien_Releve", "Formation"], [1, "DirectionLien_Disponibles", "Effectif"], [1, "DirectionLien_Condition", "Effectif"], [1, "DirectionLien_Jauge", "Effectif"]]:
		await check_link(link[0], link[1], link[2])
	# Repères sans écran dédié : petite fenêtre visuelle, refermée par Échap.
	for window: Array in [[1, "DirectionLien_Organisation", "DirectionFenetreOrganisation"], [2, "DirectionLien_Sentiment", "DirectionFenetrePublic"], [2, "DirectionLien_Affluence", "DirectionFenetrePublic"], [2, "DirectionLien_Abonnes", "DirectionFenetrePublic"]]:
		await check_window(window[0], window[1], window[2])
	# Cap du club depuis la pilule réelle.
	await open_tab(1)
	await click(find("BoardPriority_finances") as Button)
	await wait_model()
	check(app.model.clubLife.clubStrategy.board.priority == "finances", "Priorité enregistrée depuis le contrôle réel")
	await open_tab(1)
	await click(find("BoardObjectiveAdd") as Button)
	await wait_model()
	check(app.model.clubLife.clubStrategy.board.objectives.size() == 1, "Jalon enregistré")
	await open_tab(1)
	var goal: Dictionary = app.model.clubLife.clubStrategy.board.objectives[0]
	var goal_labels: Array = app.body.find_children("*", "Label", true, false).filter(func(l: Label): return l.text.ends_with("· S%d" % int(goal.deadline)))
	check(not goal_labels.is_empty() and not (goal_labels[0] as Label).text.contains(str(goal.type) + " ·"), "Jalon lisible (pas de « %s »)" % goal.type)
	# Une tuile d'offre agit comme sa pilule : la confirmation s'ouvre en place, Annuler ne débite rien.
	await open_tab(1)
	var before: float = app.model.finance.cash
	var project := find("club_board_project_video") as Button
	check(project != null and not project.disabled, "Pilule « Analyse vidéo » disponible")
	if project != null:
		var tile := project.get_parent().get_parent().get_parent() as Control
		await scroll_to(tile)
		await click_at(tile.get_global_rect().position + Vector2(24, 24))
		await confirm_in_place(false)
		check(app.model.finance.cash == before, "Annuler ne débite rien")
	# Un clic sur un cran de la règle de la relève ouvre la même confirmation que sa pilule.
	await open_tab(0)
	var ruler := find("StrategieRegleReleve")
	check(ruler != null, "Règle de la relève présente")
	if ruler != null:
		var notch := -1
		for i in 3:
			var pill := ruler.find_child("club_academy_investment_%d" % [0, 4000, 12000][i], false, false) as Button
			if pill != null and not pill.disabled and notch < 0: notch = i
		check(notch >= 0, "Un cran de la relève est disponible")
		if notch >= 0:
			await scroll_to(ruler)
			await click_at(ruler.get_global_rect().position + ruler.call("centre_cran", notch))
			await confirm_in_place(false)
	# Signature réelle depuis la pilule, confirmée en place.
	await open_tab(0)
	before = app.model.finance.cash
	var offer := find("club_sponsor_sign_avance") as Button
	await scroll_to(offer)
	await click(offer)
	await confirm_in_place()
	check(app.model.finance.cash == before + 120000, "Signature réelle et avance unique : " + app.last_error)
	# Action locale depuis la tuile entière, confirmée en place.
	await open_tab(2)
	var action := find("club_fans_community_ecoles") as Button
	before = app.model.finance.cash
	if action != null:
		var card := action.get_parent().get_parent().get_parent() as Control
		await scroll_to(card)
		await click_at(card.get_global_rect().position + Vector2(24, 24))
		await confirm_in_place()
	check(app.model.finance.cash == before - 1500, "Action locale débitée une seule fois : " + app.last_error)
	await capture("strategie-action-locale")
	finish()
func finish() -> void:
	var report := FileAccess.open(OS.get_environment("CD_STRATEGY_ARTIFACTS").path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	report.close()
	if is_instance_valid(app):
		app.closing = true
		app.timer.stop()
		app.bridge.stop()
	print("STRATEGIE UI : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
