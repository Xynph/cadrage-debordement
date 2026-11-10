extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
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
func click(button: BaseButton) -> void:
	check(button != null and not button.disabled, "Commande disponible")
	if button == null or button.disabled: return
	button.grab_focus()
	await settle()
	check(button.has_focus(), "Focus clavier")
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	button.get_viewport().push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		button.get_viewport().push_input(event, true)
		await process_frame
	await settle()
func confirm_dialog() -> void:
	var dialog: ConfirmationDialog
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible: dialog = child
	check(dialog != null, "Confirmation du coût visible")
	if dialog != null:
		dialog.get_ok_button().grab_focus()
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.pressed = pressed
			dialog.push_input(key, true)
			await process_frame
		await settle()
	await wait_model()
func tabs() -> TabContainer:
	return app.body.find_children("*", "TabContainer", true, false)[0]
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
	app._navigate("Stratégie")
	await settle()
	tabs().current_tab = 1
	await settle()
	await click(app.body.find_child("BoardPriority_finances", true, false))
	await wait_model()
	check(app.model.clubLife.clubStrategy.board.priority == "finances", "Priorité enregistrée depuis le contrôle réel")
	tabs().current_tab = 1
	await settle()
	await click(app.body.find_child("BoardObjectiveAdd", true, false))
	await wait_model()
	check(app.model.clubLife.clubStrategy.board.objectives.size() == 1, "Jalon enregistré")
	tabs().current_tab = 0
	await settle()
	var before: float = app.model.finance.cash
	var offer: Button = app.body.find_child("club_sponsor_sign_avance", true, false)
	var scroller: ScrollContainer = tabs().get_child(0)
	scroller.ensure_control_visible(offer)
	await settle()
	await click(offer)
	await confirm_dialog()
	check(app.model.finance.cash == before + 120000, "Signature réelle et avance unique : " + app.last_error)
	tabs().current_tab = 2
	await settle()
	var action: Button = app.body.find_child("club_fans_community_ecoles", true, false)
	scroller = tabs().get_child(2)
	scroller.ensure_control_visible(action)
	await settle()
	before = app.model.finance.cash
	await click(action)
	await confirm_dialog()
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
