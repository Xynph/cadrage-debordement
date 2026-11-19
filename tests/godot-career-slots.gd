extends SceneTree
## « Mes carrières » dans la vraie application : deux carrières Monde, bascule, suppression confirmée.
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)
func settle() -> void:
	for frame in 8: await process_frame
func wait_engine() -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_engine()
	check(not app.waiting and app.bridge.last_response_ok, "Commande moteur : " + id + " " + str(app.last_error))
func view() -> AcceptDialog:
	return app.get_node_or_null("CareerSlots") as AcceptDialog
func press(name: String) -> bool:
	var button := app.find_child(name, true, false) as Button
	if button == null or button.disabled or not button.is_visible_in_tree(): return false
	button.pressed.emit()
	return true
func club_name() -> String:
	return str(app.model.get("club", {}).get("name", ""))
func finish() -> void:
	var output := OS.get_environment("CD_SLOTS_OUTPUT")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures}))
	file.close()
	print("career-slots godot : %d contrôles, %d échecs" % [checks, failures.size()])
	await app._close(0 if failures.is_empty() else 1)

func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("new_career", {"mode":"world-champ", "club":0})
	var first := club_name()
	check(not first.is_empty(), "Première carrière créée")
	# Accueil : « Mes carrières » à côté de « Nouvelle carrière ».
	app._navigate("Accueil")
	await settle()
	check(app.find_child("EntryCareerSlots", true, false) != null, "Accueil : bouton Mes carrières")
	# Menu de la carrière : « Mes carrières ».
	app.pause_menu()
	await settle()
	var menu := app.get_node_or_null("ImmersivePauseMenu") as AcceptDialog
	var listed := false
	if menu != null:
		for button in menu.find_children("*", "Button", true, false): listed = listed or (button as Button).text == "Mes carrières"
		menu.queue_free()
	check(listed, "Menu de la carrière : Mes carrières")
	app.open_career_slots()
	await wait_engine()
	var dialog := view()
	check(dialog != null and dialog.visible, "Mes carrières s’ouvre")
	if dialog == null:
		await finish()
		return
	check(dialog.position.x >= 0 and dialog.position.y >= 0 and dialog.position.x + dialog.size.x <= root.size.x and dialog.position.y + dialog.size.y <= root.size.y, "Dialogue entièrement à l’écran")
	check(app.bridge.career_slots.get("active", {}).get("club", "") == first, "Carrière en cours listée")
	# Nouvelle carrière : la première est rangée, pas remplacée.
	check(press("CareerSlotsNew"), "Bouton Nouvelle carrière actif")
	await wait_engine()
	check(view() == null or view().is_queued_for_deletion(), "Dialogue fermé après la nouvelle carrière")
	check(not app._has_career() and app.route == "Création", "Choix du club ouvert, aucune carrière en cours")
	check(app.bridge.career_slots.get("saved", []).size() == 1, "Première carrière rangée")
	await command("new_career", {"mode":"world-champ", "club":1})
	var second := club_name()
	check(not second.is_empty() and second != first, "Seconde carrière créée")
	app.open_career_slots()
	await wait_engine()
	var saved: Array = app.bridge.career_slots.get("saved", [])
	check(saved.size() == 1 and str(saved[0].get("club", "")) == first, "Première carrière proposée à l’ouverture")
	if saved.is_empty():
		await finish()
		return
	var first_id := str(saved[0].id)
	check(press("CareerSlotsOpen_" + first_id), "Bouton Ouvrir actif")
	await wait_engine()
	check(club_name() == first, "Première carrière rouverte")
	app.open_career_slots()
	await wait_engine()
	saved = app.bridge.career_slots.get("saved", [])
	check(saved.size() == 1 and str(saved[0].get("club", "")) == second, "Seconde carrière rangée à son tour")
	if saved.is_empty():
		await finish()
		return
	check(press("CareerSlotsRemove_" + str(saved[0].id)), "Bouton Supprimer actif")
	await settle()
	var confirm := view().get_node_or_null("CareerSlotsConfirm") as ConfirmationDialog if view() != null else null
	check(confirm != null and confirm.visible, "Suppression : confirmation demandée")
	check(app.bridge.career_slots.get("saved", []).size() == 1, "Rien supprimé avant confirmation")
	if confirm != null:
		confirm.confirmed.emit()
		await wait_engine()
	check(app.bridge.career_slots.get("saved", []).is_empty(), "Carrière supprimée après confirmation")
	check(club_name() == first, "Carrière en cours intacte")
	await finish()
