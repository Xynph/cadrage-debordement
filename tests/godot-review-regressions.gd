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
	if node is OptionButton: return node
	for child in node.get_children():
		var found := _speed(child)
		if found != null: return found
	return null

func _run() -> void:
	var mode := OS.get_environment("CD_GODOT_REGRESSION")
	var profile := OS.get_environment("CD_GODOT_DATA_DIR")
	if mode == "disk":
		DirAccess.make_dir_recursive_absolute(profile.path_join("PrototypeGodot/donnees.tmp"))
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
	if mode!="recovery":await _command("new_career",{"club":0})
	if mode=="recovery":
		var original:=FileAccess.get_file_as_bytes(profile.path_join("PrototypeGodot/donnees.json"))
		_check(app.model.get("meta",{}).get("recoveryRequired",false),"Corrupt profile exposes explicit recovery")
		var recover:Button=null
		for button in _buttons(app.root_content):
			if button.text=="NOUVELLE CARRIÈRE":_check(button.disabled,"Creation is locked before recovery")
			if button.text=="RÉCUPÉRER LE PROFIL":recover=button
		_check(recover!=null,"Recovery action exists")
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
			for button in _buttons(app.root_content):
				if button.text.begins_with("PRENDRE LES RÊNES"):button.pressed.emit();break
			await _wait()
			_check(app.model.club!=null,"Explicit new career works after recovery")
			_check(FileAccess.get_file_as_bytes(backup)==original,"New career preserves recovery backup")
	elif mode == "disk":
		await _delay(500)
		_check(errors == 1, "Permanent first-write refusal emits exactly one error (observed %s)" % errors)
		_check(app.model.get("club") == null and not app.waiting, "Failed creation leaves stable empty career")
		_check(not FileAccess.file_exists(profile.path_join("PrototypeGodot/donnees.json")), "Failure does not persist a career")
		DirAccess.remove_absolute(profile.path_join("PrototypeGodot/donnees.tmp"))
		_dismiss_errors()
		app._navigate("Création")
		var retry: Button = null
		for button in _buttons(app.root_content):
			if button.text.begins_with("PRENDRE LES RÊNES"): retry = button
		_check(retry != null, "Explicit club creation retry available")
		if retry != null:
			retry.pressed.emit()
			await _wait()
			_check(app.model.get("club") != null, "Explicit retry creates career after disk repair")
	elif mode == "ui":
		app._navigate("Match")
		var speed := _speed(app.body)
		speed.select(2)
		speed.item_selected.emit(2)
		app._navigate("Effectif")
		app._navigate("Match")
		_check(_speed(app.body).selected == 2 and app.tick_steps == 12, "Cadence remains visually and actually x12 after navigation")
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
	elif mode == "limits":
		for text in ["a".repeat(5 * 1024 * 1024 + 1), "\"".repeat(4 * 1024 * 1024), "é".repeat(3 * 1024 * 1024)]:
			var path := profile.path_join("oversized.json")
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(text)
			file.close()
			app.import_mode = true
			app._file_selected(path)
			for child in app.get_children():
				if child is ConfirmationDialog and child.visible: child.confirmed.emit();break
			_check(not app.waiting and app.last_error.to_lower().contains("volumineux"), "UI rejects inadmissible UTF8/JSON import before transport")
			# RED must not enqueue more requests on an already stranded reader.
			if app.waiting: break
			_dismiss_errors()
		if not app.waiting:
			await _command("snapshot")
			_check(app.model.club != null, "Snapshot works after local import refusal")
	elif mode == "null-response":
		# Fault injection bypasses send's local guard to exercise the actual worker
		# protocol's id:null response and its native transport lifecycle.
		app.bridge._mutex.lock()
		app.bridge._queue.append({"id": 999999, "command": "import", "payload": {"text": "a".repeat(7 * 1024 * 1024)}})
		app.bridge._mutex.unlock()
		app.bridge._wake.post()
		await _delay(1500)
		var prior_errors := errors
		_dismiss_errors()
		app.bridge.send("snapshot")
		await _delay(100)
		_check(app.bridge.child_pid <= 0 and app.bridge._stopping, "id:null rejection terminates owned worker and reader")
		_check(errors > prior_errors, "Further commands fail immediately after terminal response")
	var pid: int = app.bridge.child_pid
	app.bridge.stop()
	var close_deadline := Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < close_deadline: await process_frame
	_check(app.bridge.child_pid <= 0 and (pid <= 0 or not OS.is_process_running(pid)), "Owned child closes within bounded deadline")
	print(JSON.stringify({"mode": mode, "passed": failures.is_empty(), "checks": checks, "failures": failures, "errors": errors, "error_messages": error_messages}))
	quit(0 if failures.is_empty() else 1)
