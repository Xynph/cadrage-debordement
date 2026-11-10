extends SceneTree

# Real native UI/worker regressions. Every invocation requires a fresh profile.
var app: Control
var failures: Array[String] = []
var checks := 0
var errors := 0
var error_messages: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		quit(2)
		return
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func _delay(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until: await process_frame

func _wait() -> void:
	var until := Time.get_ticks_msec() + 15000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	_check(not app.waiting, "Command completes without indefinite waiting")

func _command(command: String, payload: Dictionary = {}) -> void:
	app._command(command, payload)
	await _wait()
	if not app.bridge.last_response_ok: print("COMMANDE REFUSÉE : ", command, " · ", app.last_error)

func _dismiss_errors() -> void:
	for child in app.get_children():
		if child is AcceptDialog and child != app.file_dialog:
			child.hide()
			child.queue_free()

func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(_buttons(child))
	return result

func _speed(node: Node) -> OptionButton:
	if node is OptionButton and node.is_visible_in_tree() and node.item_count == 3 and node.get_item_text(2) == "Cadence ×12":
		return node
	for child in node.get_children():
		var found := _speed(child)
		if found != null: return found
	return null

func _confirm() -> void:
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible:
			child.confirmed.emit()
			return

func _named_button(node: Node, text: String) -> Button:
	for button in _buttons(node):
		if button.text == text: return button
	return null

func _import_text(text: String) -> void:
	var path := OS.get_environment("CD_GODOT_DATA_DIR").path_join("decision-import.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	app.import_mode = true
	app._file_selected(path)
	_confirm()

func _dialogs() -> Array[AcceptDialog]:
	var result: Array[AcceptDialog] = []
	for child in app.get_children():
		if child is AcceptDialog and child != app.file_dialog and not child.is_queued_for_deletion(): result.append(child)
	return result

func _decisions() -> void:
	app._navigate("Bureau")
	app._command("save")
	app.create_career(1)
	_confirm()
	_check(app.waiting and app.last_command == "save" and app.queued_action.is_empty(), "Business command refuses a second decision without clearing the active command")
	_check(not app.last_error.is_empty() and app.status.text.contains("NON EFFECTUÉE"), "Business refusal is visible immediately")
	_check(app.pending_route.is_empty(), "Refused creation cannot install a pending route")
	await _wait()
	_check(int(app.model.club.id) == 0, "Refused creation is never executed later")
	_dismiss_errors()
	app._navigate("Match")
	await _command("begin_match")
	app._command("save")
	app.pause_menu()
	var dialogs := _dialogs()
	_check(dialogs.size() == 1 and dialogs[0].visible and dialogs[0].title == "Votre décision n'a pas été appliquée", "Busy pause menu keeps only the explanatory refusal dialog")
	_check(app.waiting and app.last_command == "save" and app.queued_action.is_empty(), "Refused menu pause preserves the in-flight save")
	_check(not app.last_error.is_empty() and not app.model.live.paused, "Refused menu pause explicitly explains the still-running match")
	await _wait()
	_dismiss_errors()
	app.pause_menu()
	await _wait()
	dialogs = _dialogs()
	_check(app.model.live.paused and dialogs.size() == 1 and dialogs[0].visible and dialogs[0].title == "Votre carrière", "Menu retry pauses the real match and shows one usable career menu")
	_dismiss_errors()
	await _command("pause", {"paused":false})
	app._command("tick", {"steps":1})
	app._command("save")
	var saved_queue: Dictionary = app.queued_action.duplicate(true)
	app.pause_menu()
	dialogs = _dialogs()
	_check(app.waiting and app.last_command == "tick" and app.queued_action == saved_queue and saved_queue.get("command") == "save", "Refused menu pause preserves an action already accepted behind the tick")
	_check(dialogs.size() == 1 and dialogs[0].visible and dialogs[0].title == "Votre décision n'a pas été appliquée", "Saturated menu pause also keeps one explanatory dialog")
	await _wait()
	_check(not app.model.live.paused, "Rejected saturated menu pause is not applied later")
	_dismiss_errors()
	app._command("tick", {"steps":1})
	app._command("pause", {"paused":true})
	var accepted: Dictionary = app.queued_action.duplicate(true)
	_check(accepted.get("command") == "pause", "One human action is accepted behind a tick")
	app._command("save")
	_check(app.waiting and app.last_command == "tick" and app.queued_action == accepted, "Saturated queue preserves the tick and its accepted action")
	_check(not app.last_error.is_empty() and app.status.text.contains("NON EFFECTUÉE"), "Saturated queue refuses the next action visibly")
	await _wait()
	_check(app.model.live.paused, "Accepted pause executes after the tick")
	_dismiss_errors()
	await _command("pause", {"paused":false})
	var responses: Array = []
	var observer := func(_value: Dictionary): responses.append(app.route)
	app.bridge.model_changed.connect(observer)
	app._command("tick", {"steps":1})
	_import_text("{}")
	_check(app.route == "Match" and app.pending_route.is_empty(), "Queued import does not install navigation before dispatch")
	await _wait()
	app.bridge.model_changed.disconnect(observer)
	_check(responses.size() >= 2 and responses[0] == "Match", "Prior tick response cannot consume the queued import route")
	_check(app.route == "Match" and app.pending_route.is_empty() and not app.last_error.is_empty(), "Refused queued import keeps the current route and clears only its pending navigation")
	_dismiss_errors()
	await _command("export")
	var exported: String = app.model.meta.exportText
	_import_text(exported)
	_check(app.route == "Match", "Accepted import waits for its own response before navigation")
	await _wait()
	_check(app.route == "Bureau", "Successful import applies its own target route")
	app._navigate("Match")
	await _command("pause", {"paused":false})
	app.bridge.stop()
	app.pause_menu()
	dialogs = _dialogs()
	_check(not app.waiting and dialogs.size() == 1 and dialogs[0].visible and dialogs[0].title == "Votre décision n'a pas été appliquée" and app.last_error.contains("fermé"), "Synchronous closed-transport refusal also prevents a second career modal")

func _tactics() -> void:
	app._navigate("Préparation")
	var tactics: Dictionary = app.model.tactics
	var attack: Dictionary = {}
	var defense: Dictionary = {}
	for option in tactics.attacks:
		if option.id != tactics.attack: attack = option; break
	for option in tactics.defenses:
		if option.id != tactics.defense: defense = option; break
	var attack_button := _named_button(app.body, str(attack.label).to_upper())
	var defense_button := _named_button(app.body, str(defense.label).to_upper())
	_check(attack_button != null and defense_button != null, "Both tactical axes expose a real alternative")
	attack_button.pressed.emit()
	defense_button.pressed.emit()
	_check(app.waiting and app.queued_action.is_empty() and not app.last_error.is_empty(), "Rapid second tactical axis is explicitly refused until the first acknowledgement")
	await _wait()
	_check(app.model.tactics.attack == attack.id and app.model.tactics.defense == tactics.defense, "Refused old tactical payload cannot overwrite either axis")
	_dismiss_errors()
	defense_button = _named_button(app.body, str(defense.label).to_upper())
	defense_button.pressed.emit()
	await _wait()
	_check(app.model.tactics.attack == attack.id and app.model.tactics.defense == defense.id, "Fresh defense decision preserves the acknowledged attack")

func _bench() -> void:
	app._navigate("Match")
	var panel: Node = app.match_screen
	var viewport: Node = app.match_view.get_parent()
	var initial_date: String = app.header_date.text
	await _command("begin_match")
	await _command("pause", {"paused":true})
	var option: Dictionary = {}
	for choice in app.model.live.substitutions:
		if not choice.inIds.is_empty(): option = choice; break
	_check(not option.is_empty(), "Real match offers a qualified substitution")
	if option.is_empty(): return
	var incoming: Dictionary = {}
	for player in app.model.live.reserves:
		if player.id == option.inIds[0]: incoming = player; break
	panel.tab = "Banc"
	panel.selected_slot = int(option.slot)
	panel.presence_key = ""
	app._update_match()
	_check(not _named_button(panel.side, incoming.name).disabled, "Paused bench enables a permitted entrant")
	await _command("pause", {"paused":false})
	_check(_named_button(panel.side, incoming.name).disabled, "Resume disables entrant without a tab or selection click")
	var stable_button := _named_button(panel.side, incoming.name)
	await _command("tick", {"steps":1})
	_check(_named_button(panel.side, incoming.name) == stable_button, "Unchanged running bench retains controls across ticks")
	await _command("pause", {"paused":true})
	_check(not _named_button(panel.side, incoming.name).disabled, "Pause re-enables entrant without a tab or selection click")
	_check(panel.tab == "Banc" and panel.selected_slot == int(option.slot), "Pause and resume retain the bench tab and selected outgoing position")
	# Permission-only projection change, keeping actual players and pause unchanged.
	var actual: Dictionary = app.model
	var restricted: Dictionary = actual.duplicate(true)
	restricted.live.substitutions = []
	panel.update_frame(restricted)
	_check(_named_button(panel.side, incoming.name).disabled, "Permission-only change immediately disables the entrant")
	panel.update_frame(actual)
	_check(not _named_button(panel.side, incoming.name).disabled, "Restored permission re-enables the entrant")
	await _command("delegate")
	_check(_named_button(panel.side, incoming.name).disabled, "Finished match disables entrant without another selection")
	_check(panel.tab == "Banc" and panel.selected_slot == int(option.slot), "Finish retains bench context")
	await _command("finish_round")
	var first_date: String = app.header_date.text
	_check(app.header_date.is_visible_in_tree() and first_date != initial_date and first_date.contains("JOURNÉE 2") and int(app.model.meta.week) == 1, "First round validation refreshes the header date in Match")
	await _command("auto_lineup")
	if not app.model.selection.valid: await _command("promote_cover", {"confirmed":true})
	await _command("begin_match")
	await _command("delegate")
	await _command("finish_round")
	_check(app.header_date.is_visible_in_tree() and app.header_date.text != first_date and app.header_date.text.contains("JOURNÉE 3") and int(app.model.meta.week) == 2, "Second round validation refreshes the date again")
	_check(app.match_screen == panel and app.match_view.get_parent() == viewport, "Both date changes retain the actual match SubViewport")

func _modal() -> void:
	app._navigate("Recrutement")
	for dimensions in [Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = dimensions
		for i in 5: await process_frame
		app.SquadViews.contract(app, app.model.market[0], true)
		for i in 5: await process_frame
		for child in app.get_children():
			if child is ConfirmationDialog and child.visible:
				var client := Rect2(Vector2.ZERO, root.get_visible_rect().size)
				var rect := Rect2(Vector2(child.position),Vector2(child.size))
				_check(client.encloses(rect), "Contract dialog fits client at " + str(dimensions))
				for button in [child.get_ok_button(),child.get_cancel_button()]:
					button.grab_focus()
					_check(button.has_focus(), "Contract keyboard focus reaches confirmation/cancel")
					var button_rect := Rect2(Vector2(child.position) + button.get_global_rect().position,button.size)
					_check(button.is_visible_in_tree() and client.encloses(button_rect), "Contract confirmation/cancel is visible inside client at " + str(dimensions))
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OS.get_environment("CD_GODOT_DATA_DIR").path_join("contract-" + str(dimensions.x) + ".png"))
		_dismiss_errors()
		await process_frame
		for kind in ["notice", "confirmation", "recovery", "credits", "settings", "menu"]:
			match kind:
				"notice": app.notice("Information", "Une décision est déjà en cours. Cette nouvelle action n'a pas été retenue ; réessayez après sa réponse.")
				"confirmation": app.confirm("Confirmer", "La carrière importée remplacera celle du profil. Le moteur la vérifiera avant de l'appliquer.", func(): pass)
				"recovery": app.recover_profile()
				"credits": app._credits()
				"settings": app.settings()
				"menu": app.pause_menu()
			for i in 5: await process_frame
			_dialog_bounds(kind + " " + str(dimensions))
			_dismiss_errors()
			await process_frame

func _dialog_bounds(context: String) -> void:
	var client := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for child in app.get_children():
		if child is AcceptDialog and child.visible and child != app.file_dialog:
			_check(client.encloses(Rect2(Vector2(child.position),Vector2(child.size))), context + " dialog fits the client")
			var text: Label = child.get_label()
			_check(text.get_minimum_size().x <= text.size.x + 1, context + " message fits its label width")
			for button in child.find_children("*", "Button", true, false):
				if button.is_visible_in_tree():
					_check(client.encloses(Rect2(Vector2(child.position) + button.get_global_rect().position,button.size)), context + " action button fits the client")

func _scroll_focus(scroll: ScrollContainer, context: String) -> void:
	scroll.scroll_vertical = 0
	for i in 5: await process_frame
	var target: Button = null
	for button in _buttons(scroll):
		if not button.disabled: target = button
	_check(target != null, context + " has an accessible focus target")
	if target == null: return
	target.grab_focus()
	for i in 5: await process_frame
	_check(target.has_focus() and scroll.get_global_rect().encloses(target.get_global_rect()), context + " scrolls its offscreen focused action into view")
	var previous := target.find_prev_valid_focus()
	_check(previous != null, context + " has a keyboard traversal predecessor")
	if previous != null:
		previous.grab_focus()
		for i in 5: await process_frame
		_check(previous.has_focus(), context + " keyboard traversal changes focus")

func _focus() -> void:
	app._navigate("Effectif")
	for i in 5: await process_frame
	var list := app.body.find_child("SquadScroll", true, false) as ScrollContainer
	var profile := app.body.find_child("ProfileScroll", true, false) as ScrollContainer
	_check(list != null and profile != null and list != profile and list.is_visible_in_tree() and profile.is_visible_in_tree(), "Squad list and player profile each have their own scroll viewport")
	for scroll in [list, profile]:
		if scroll != null: await _scroll_focus(scroll, "Squad/profile")
	app._navigate("Match")
	await _command("begin_match")
	await _command("pause", {"paused":true})
	var panel: Node = app.match_screen
	panel.tab = "Banc"
	panel.selected_slot = int(app.model.live.substitutions[0].slot)
	panel.presence_key = ""
	app._update_match()
	for i in 5: await process_frame
	await _scroll_focus(panel.side.get_parent(), "Bench")

func _run() -> void:
	var mode := OS.get_environment("CD_GODOT_REGRESSION")
	var profile := OS.get_environment("CD_GODOT_DATA_DIR")
	if DisplayServer.get_name() == "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
	if mode == "disk":
		profile = profile.path_join("profil-au-chemin-explicite-et-suffisamment-long-pour-verifier-la-lisibilite-de-lerreur")
		OS.set_environment("CD_GODOT_DATA_DIR", profile)
	if mode=="recovery":
		DirAccess.make_dir_recursive_absolute(profile.path_join("PrototypeGodot"))
		var corrupt:=FileAccess.open(profile.path_join("PrototypeGodot/donnees.json"),FileAccess.WRITE)
		corrupt.store_string("Profil endommagé — octets à conserver\n{broken")
		corrupt.close()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.bridge.command_failed.connect(func(message: String): errors += 1; error_messages.append(message))
	app.timer.stop()
	var deadline := Time.get_ticks_msec() + 15000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	await _wait()
	_check(app.model.get("club")==null and app.route=="Accueil","Fresh profile remains on menu without automatic creation")
	var first_write := str(app.model.get("meta",{}).get("dataDir","")).path_join("donnees.json")
	if mode == "disk":
		_check(first_write.replace("\\", "/").simplify_path().to_lower().begins_with(profile.replace("\\", "/").simplify_path().to_lower() + "/") and not FileAccess.file_exists(first_write) and DirAccess.make_dir_absolute(first_write) == OK, "First-write blocker placed after opening the isolated profile")
	if mode!="recovery":await _command("new_career",{"club":0})
	if mode=="recovery":
		var original:=FileAccess.get_file_as_bytes(profile.path_join("PrototypeGodot/donnees.json"))
		_check(app.model.get("meta",{}).get("recoveryRequired",false),"Corrupt profile exposes explicit recovery")
		var creation := app.root_content.find_child("EntryNewCareer", true, false) as Button
		var recover := app.root_content.find_child("EntryRecover", true, false) as Button
		_check(creation!=null and creation.disabled,"Creation is locked before recovery")
		_check(recover!=null and not recover.disabled,"Recovery action exists and is usable")
		if recover!=null:
			recover.pressed.emit()
			_check(FileAccess.get_file_as_bytes(profile.path_join("PrototypeGodot/donnees.json"))==original,"Recovery does not write before confirmation")
			for child in app.get_children():
				if child is ConfirmationDialog and child.visible:child.confirmed.emit();break
			await _wait()
			var backup:String=app.model.meta.get("recoveryBackup","")
			_check(not backup.is_empty() and FileAccess.get_file_as_bytes(backup)==original,"Recovery keeps exact original bytes in backup")
			_check(app.model.club==null and not app.model.meta.get("recoveryRequired",true),"Recovery returns usable menu without creating career")
			_dismiss_errors()
			app._navigate("Création")
			var club_choice := app.find_child("CreationClub0", true, false) as Button
			if club_choice != null: club_choice.pressed.emit()
			var start := app.root_content.find_child("CreationStart", true, false) as Button
			if start != null: start.pressed.emit()
			await _wait()
			_check(app.model.club!=null,"Explicit new career works after recovery")
			_check(FileAccess.get_file_as_bytes(backup)==original,"New career preserves recovery backup")
	elif mode == "disk":
		await _delay(500)
		_dialog_bounds("Real EISDIR failure")
		_check(errors == 1, "Permanent first-write refusal emits exactly one error (observed %s)" % errors)
		_check(app.model.get("club") == null and not app.waiting, "Failed creation leaves stable empty career")
		_check(not FileAccess.file_exists(first_write), "Failure does not persist a career")
		_check(DirAccess.remove_absolute(first_write) == OK, "First-write blocker removed")
		_dismiss_errors()
		app._navigate("Création")
		var club_choice := app.find_child("CreationClub0", true, false) as Button
		if club_choice != null: club_choice.pressed.emit()
		var retry := app.root_content.find_child("CreationStart", true, false) as Button
		_check(retry != null, "Explicit club creation retry available")
		if retry != null:
			retry.pressed.emit()
			await _wait()
			_check(app.model.get("club") != null, "Explicit retry creates career after disk repair")
	elif mode == "ui":
		app._navigate("Match")
		var speed := _speed(app.body)
		_check(speed != null and not speed.disabled, "Match cadence offers an enabled x12 action")
		if speed != null and not speed.disabled:
			speed.select(2)
			speed.item_selected.emit(2)
		app._navigate("Effectif")
		app._navigate("Match")
		var restored_speed := _speed(app.body)
		_check(restored_speed != null and restored_speed.selected == 2 and app.tick_steps == 12, "Cadence remains visually and actually x12 after navigation")
		await _command("begin_match")
		await _command("delegate")
		_check(app.pause_button.disabled, "Finished match disables pause")
		var page: Node = app.match_page
		app.match_finish.pressed.emit()
		await _wait()
		_check(app.match_page == page, "Round transition retains same Match panel")
		_check(not app.pause_button.disabled, "Next kickoff enabled without navigation")
		# Repair the actual 23 after match injuries before testing the next kickoff.
		await _command("auto_lineup")
		var legal:bool=app.model.get("selection",{}).get("valid",false)
		if not app.pause_button.disabled:
			app.pause_button.pressed.emit()
			await _wait()
			_check((app.model.live != null and app.model.meta.round == 1) if legal else (app.model.live==null and not app.last_error.is_empty()), "Second kickoff starts or gives the real selection refusal")
			_dismiss_errors()
		var actual: Dictionary = app.model
		app.model = actual.duplicate(true)
		app.model.live = null
		app.model.next = null
		app.model.meta.phase = "league"
		app._update_match()
		_check(app.pause_button.disabled and not app.match_finish.disabled, "Round without fixture offers round validation only")
		app.model.meta.phase = "ended"
		app._update_match()
		_check(app.pause_button.disabled and app.match_finish.disabled and app.match_clock.text.contains("SAISON"), "Ended season clearly closes both match actions")
		app.model = actual
	elif mode == "decisions": await _decisions()
	elif mode == "tactics": await _tactics()
	elif mode == "bench": await _bench()
	elif mode == "modal": await _modal()
	elif mode == "focus": await _focus()
	elif mode == "limits":
		var maximum := NativeEngineBridge.IMPORT_LIMIT_BYTES
		var save_path: String = str(app.model.meta.dataDir).path_join("donnees.json")
		var before := FileAccess.get_file_as_bytes(save_path)
		var route_before: String = app.route
		for fixture: Array in [["ASCII", "a".repeat(maximum + 1)], ["UTF-8", "é".repeat(floori(maximum / 2.0) + 1)]]:
			var path := profile.path_join("oversized.json")
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(fixture[1])
			file.close()
			_check(FileAccess.get_file_as_bytes(path).size() > maximum, "%s fixture exceeds the byte cap" % fixture[0])
			var request_before: int = app.bridge._next_id
			app.import_mode = true
			app._file_selected(path)
			var confirmation := _dialogs().any(func(dialog: AcceptDialog): return dialog is ConfirmationDialog and dialog.visible)
			_check(not confirmation and not app.waiting and app.bridge._next_id == request_before and app.last_error.to_lower().contains("volumineux"), "%s over-limit import is refused before confirmation and transport" % fixture[0])
			_dismiss_errors()
		await _command("export")
		var valid_export: String = app.model.meta.get("exportText", "")
		_check(not valid_export.is_empty(), "A complete native export is available for the NUL fixture")
		var terminated := valid_export.to_utf8_buffer()
		terminated.append(0)
		terminated.append_array("suffixe non JSON".to_utf8_buffer())
		var worker_before: int = app.bridge.child_pid
		for fixture: Array in [["C0", ("{" + String.chr(1) + "}").to_utf8_buffer()], ["NUL après un export valide", terminated]]:
			var control_path := profile.path_join("caractere-de-controle.json")
			var control_file := FileAccess.open(control_path, FileAccess.WRITE)
			control_file.store_buffer(fixture[1])
			control_file.close()
			var request_before: int = app.bridge._next_id
			app.open_file(true)
			app.file_dialog.file_selected.emit(control_path)
			var confirmation := _dialogs().any(func(dialog: AcceptDialog): return dialog is ConfirmationDialog and dialog.visible)
			_check(not confirmation and not app.waiting and app.bridge._next_id == request_before and app.last_error.contains("caractère de contrôle"), "%s est refusé avant le transport" % fixture[0])
			_check(worker_before > 0 and app.bridge.child_pid == worker_before and OS.is_process_running(worker_before), "Malformed file does not stop the owned worker")
			_dismiss_errors()
		# Below the byte cap, malformed JSON is checked by the worker after confirmation.
		for text in ["a".repeat(5 * 1024 * 1024 + 1), "\"".repeat(4 * 1024 * 1024), "é".repeat(3 * 1024 * 1024)]:
			var error_before := errors
			_import_text(text)
			_check(app.waiting and app.last_command == "import", "In-limit malformed import reaches the worker after confirmation")
			await _wait()
			_check(errors == error_before + 1 and not app.bridge.last_response_ok and app.last_error.contains("JSON"), "Worker returns a correlated JSON rejection")
			_dismiss_errors()
		await _command("snapshot")
		_check(app.bridge.last_response_ok and app.model.club != null and app.route == route_before and app.pending_route.is_empty(), "Snapshot and navigation survive rejected imports")
		_check(not before.is_empty() and FileAccess.get_file_as_bytes(save_path) == before, "Rejected imports preserve the profile bytes")
	elif mode == "null-response":
		# A non-import request exceeds both editions' ordinary wire cap.
		var child_pid: int = app.bridge.child_pid
		var request := {"id": 999999, "command": "snapshot", "payload": {"text": "a".repeat(NativeEngineBridge.REQUEST_LIMIT_BYTES + 1)}}
		app.bridge._mutex.lock()
		app.bridge._queue.append(request)
		app.bridge._mutex.unlock()
		app.bridge._wake.post()
		var terminal_deadline := Time.get_ticks_msec() + 5000
		while app.bridge.child_pid > 0 and Time.get_ticks_msec() < terminal_deadline: await process_frame
		_check(error_messages.any(func(message: String): return message.contains("Message trop volumineux")), "Actual worker rejects the oversized protocol message")
		_check(child_pid > 0 and not OS.is_process_running(child_pid) and app.bridge.child_pid <= 0 and app.bridge._stopping, "id:null rejection terminates owned worker and reader")
		var prior_errors := errors
		_dismiss_errors()
		app.bridge.send("snapshot")
		_check(errors > prior_errors, "Further commands fail immediately after terminal response")
	var pid: int = app.bridge.child_pid
	app.closing = true
	app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	if is_instance_valid(app.soundscape): app.soundscape.dispose()
	app.bridge.stop()
	var close_deadline := Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < close_deadline: await process_frame
	_check(app.bridge.child_pid <= 0 and (pid <= 0 or not OS.is_process_running(pid)), "Owned child closes within bounded deadline")
	app.queue_free()
	for i in 3: await process_frame
	print(JSON.stringify({"mode": mode, "passed": failures.is_empty(), "checks": checks, "failures": failures, "errors": errors, "error_messages": error_messages}))
	quit(0 if failures.is_empty() else 1)
