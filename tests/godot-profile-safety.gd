extends SceneTree
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
func enter() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 90000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok, "Commande moteur : " + id + " " + str(app.last_error))
func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("new_career", {"mode":"common", "club":0})
	await command("new_career", {"mode":"common", "club":1})
	check(app.model.meta.profileSafety.entries.size() == 1, "Copie durable créée par le moteur")
	var file: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(file)
	app.pause_menu()
	await settle()
	var entry := app.find_child("ProfileSafetyOpen", true, false) as Button
	check(entry != null and entry.is_visible_in_tree(), "Copies accessibles depuis le vrai menu Carrière")
	if entry == null:
		await app._close(1)
		return
	entry.grab_focus()
	await enter()
	var view := app.get_node_or_null("ProfileSafety") as AcceptDialog
	await settle()
	check(view != null, "Entrée sur le menu ouvre la gestion des copies")
	if view == null:
		await app._close(1)
		return
	check(view.visible and view.title.contains("Copies de sécurité"), "Dialogue rendu et titré")
	check(view.find_child("ProfileSafetyQuota", true, false).text.contains("1 / 8"), "Quota disponible visible")
	var id: String = app.model.meta.profileSafety.entries[0].id
	var restore: Button = view.find_child("ProfileSafetyRestore_" + id, true, false)
	check(restore != null and not restore.disabled, "Reprise disponible sur la bonne copie")
	restore.grab_focus()
	await settle()
	check(restore.has_focus(), "Reprise accessible au clavier")
	await enter()
	await settle()
	var confirmation: ConfirmationDialog = view.find_child("ProfileSafetyConfirm", true, false)
	check(confirmation != null and confirmation.visible and confirmation.dialog_text.contains("conservée"), "Confirmation explicite et conséquence annoncée")
	check(FileAccess.get_sha256(file) == before, "Consultation et confirmation n'écrivent pas la carrière")
	confirmation.canceled.emit()
	await settle()
	check(FileAccess.get_sha256(file) == before and not app.waiting, "Annulation sans commande ni écriture")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.save_png(OS.get_environment("CD_SAFETY_OUTPUT").path_join("copies-securite.png")) == OK, "Capture des copies de sécurité")
	restore.pressed.emit()
	await settle()
	confirmation = view.find_child("ProfileSafetyConfirm", true, false)
	confirmation.confirmed.emit()
	deadline = Time.get_ticks_msec() + 90000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(app.bridge.last_response_ok and app.model.club.id == 0, "La confirmation reprend réellement Toulouse")
	check(app.route == "Réception", "Une reprise par copie ouvre la Réception de la carrière restaurée")
	check(app.model.meta.profileSafetyReceipt.command == "restore_checkpoint", "Reçu de restauration exact")
	view = load("res://ui/profile_safety_view.gd").open(app)
	await settle()
	var removed_id: String = app.model.meta.profileSafety.entries[0].id
	var remove: Button = view.find_child("ProfileSafetyRemove_" + removed_id, true, false)
	before = FileAccess.get_sha256(file)
	remove.pressed.emit()
	await settle()
	confirmation = view.find_child("ProfileSafetyConfirm", true, false)
	check(confirmation != null and confirmation.dialog_text.contains("définitive"), "Suppression explicite avec avertissement")
	confirmation.confirmed.emit()
	deadline = Time.get_ticks_msec() + 90000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(app.bridge.last_response_ok and not app.model.meta.profileSafety.entries.any(func(entry): return entry.id == removed_id), "Seule la copie choisie est supprimée")
	check(FileAccess.get_sha256(file) == before, "Supprimer une copie préserve le profil actuel")
	var report := FileAccess.open(OS.get_environment("CD_SAFETY_OUTPUT").path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}, "  "))
	report.close()
	print("COPIES DE SÉCURITÉ : %d contrôles ; %d échec(s)" % [checks, failures.size()])
	await app._close(0 if failures.is_empty() else 1)
