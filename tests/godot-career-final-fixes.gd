extends SceneTree

var app: Control
var fixtures: Dictionary
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty() or OS.get_environment("CD_GODOT_FIXTURES").is_empty():
		quit(2)
		return
	fixtures = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_GODOT_FIXTURES")))
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _wait() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	_check(not app.waiting, "Native command completes")

func _command(command: String, payload: Dictionary = {}) -> void:
	print("SDK_COMMAND godot-career-final-fixes ",command)
	app._command(command, payload)
	await _wait()
	_check(app.last_error.is_empty(), "Native command accepted: " + command)

func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(_buttons(child))
	return result

func _button(node: Node, text: String) -> Button:
	for button in _buttons(node):
		if button.text == text: return button
	return null

func _labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	if node is Label: result.append(node)
	for child in node.get_children(): result.append_array(_labels(child))
	return result

func _pick_slot(slot: int) -> bool:
	var surface: Control = app.match_screen
	if surface.drawer_tab != "Banc" or not surface.drawer.visible: surface._toggle_drawer("Banc")
	var buttons := _buttons(surface.drawer_body).filter(func(button: Button): return str(button.get_meta("match_bench_focus", "")).begins_with("sortant:"))
	_check(buttons.size() == 15, "Les quinze postes réels restent sélectionnables, y compris les postes vacants")
	for button: Button in buttons:
		if button.get_meta("match_bench_focus") == "sortant:%d" % slot:
			button.pressed.emit()
			return true
	return false

func _incoming_permissions(slot: int) -> void:
	var live: Dictionary = app.model.live
	var allowed: Array = live.substitutions[slot].inIds
	for player in live.reserves:
		if not player is Dictionary: continue
		var button := _button(app.match_screen.drawer_body, player.name)
		_check(button != null and button.disabled == (player.id not in allowed), "Entrant permission follows native slot: " + player.name)

func _bench() -> void:
	await _command("import", {"text":fixtures.before20.text})
	app._navigate("Match")
	var panel: Node = app.match_screen
	_check(panel.has_method("_toggle_drawer"), "Le banc appartient au direct contextuel actuel")
	panel._toggle_drawer("Banc")
	if _pick_slot(8): _incoming_permissions(8)
	await _command("import", {"text":fixtures.after20.text})
	panel = app.match_screen
	if _pick_slot(8):
		_incoming_permissions(8)
		var incoming: String = app.model.live.substitutions[8].inIds[0]
		var name: String = ""
		for player in app.model.live.reserves:
			if player is Dictionary and player.id == incoming: name = player.name
		var button := _button(panel.drawer_body, name)
		button.grab_focus()
		await _command("snapshot")
		_check(_button(panel.drawer_body, name) == button and button.has_focus(), "Unchanged bench keeps actual controls and focus")
		await _command("pause", {"paused":false})
		# Depuis #587 le direct peut se remettre en pause de lui-même sur un temps fort (minute 21 ici) : la permission suit alors
		# l’état réel du match (désactivée seulement tant qu'il tourne), ce que le tiroir du banc doit refléter.
		_check(_button(panel.drawer_body, name).disabled == (not bool(app.model.live.get("paused", false))), "Running match disables selected vacant entrant · paused=" + str(app.model.live.get("paused")) + " finished=" + str(app.model.live.get("finished")) + " minute=" + str(app.model.live.get("minute")))
		await _command("pause", {"paused":true})
		_check(not _button(panel.drawer_body, name).disabled and panel.drawer_tab == "Banc", "Pause restores selected vacant slot permission and tab")
		_button(panel.drawer_body, name).pressed.emit()
		await _wait()
		_check(app.last_error.is_empty() and app.model.live.lineup[8] is Dictionary and app.model.live.lineup[8].id == incoming, "Vacant bench button sends a successful real native change")
	await _command("import", {"text":fixtures.twoVacancies.text})
	panel = app.match_screen
	if _pick_slot(6):
		_incoming_permissions(6)
		var incoming: String = app.model.live.substitutions[6].inIds[0]
		var name: String = ""
		for player in app.model.live.reserves:
			if player is Dictionary and player.id == incoming: name = player.name
		_button(panel.drawer_body, name).pressed.emit()
		await _wait()
		_check(app.last_error.is_empty() and app.model.live.lineup[5] == null and app.model.live.lineup[6] is Dictionary and app.model.live.lineup[6].id == incoming, "Second vacancy is filled through the UI without changing the first")

func _clocks() -> void:
	for pair in [["halftime","MI-TEMPS",true],["resumed","66 min",false],["tactical","66 min",true],["extraStart",str(int(fixtures.extraStart.model.live.minute)) + " min",false],["extraPause",str(int(fixtures.extraPause.model.live.minute)) + " min",true],["extraSecond",str(int(fixtures.extraSecond.model.live.minute)) + " min",false],["finished","TERMINÉ",true]]:
		app.match_screen.update_frame(fixtures[pair[0]].model)
		_check(app.match_screen.clock.text == pair[1], "Actual native clock state " + pair[0] + " displays " + pair[1])
		_check(app.match_screen.stage._paused == pair[2], "Actual renderer motion follows current pause state: " + pair[0])

func _current_office(model: Dictionary) -> void:
	var hero: Node = app.body.find_child("OfficeFixture", true, false)
	_check(hero != null, "Current immersive office emits actual fixture controls")
	if hero == null: return
	var texts: Array[String] = []
	for label in _labels(hero): texts.append(label.text)
	var venue := hero.find_child("OfficeFixtureVenue", true, false) as Label
	var neutral: bool = model.next.neutral
	var location_ok: bool
	if neutral: location_ok = texts.has("NEUTRE")
	elif model.next.home.id == model.club.id: location_ok = texts.has("À DOMICILE")
	else: location_ok = texts.has("EXTÉRIEUR") or texts.has("À L’EXTÉRIEUR")
	_check(location_ok, "Current responsive office emits actual fixture location")
	var explicit_venue: String = str(model.next.get("venue", ""))
	if neutral and explicit_venue.is_empty():
		_check(venue == null, "Unspecified neutral venue never claims the home stadium")
	elif not neutral:
		_check(venue != null and venue.text == str(model.next.home.presentation.stadium), "Current office emits actual home stadium")
	var honest_art := false
	for image in hero.find_children("*", "TextureRect", true, false):
		if image.has_meta("immersive_art"):
			honest_art = image.texture != null and image.tooltip_text == "Vue du club"
	_check(honest_art or hero.find_child("OfficeTerritoryPreviews", true, false) != null, "Current office identifies generic artwork or club territory photographs")

func _offices() -> void:
	for dimensions in [Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = dimensions
		for model in fixtures.offices:
			app.model = model
			app._navigate("Bureau")
			for i in 5: await process_frame
			_current_office(model)
			# Exercise the retained classic renderer separately from the immersive route.
			var classic := VBoxContainer.new()
			root.add_child(classic)
			classic.size = Vector2(dimensions.x, 600)
			preload("res://ui/office_view.gd")._fixture(classic, app)
			for i in 5: await process_frame
			var texts: Array[String] = []
			for label in _labels(classic): texts.append(label.text)
			var text := "\n".join(texts)
			var neutral: bool = model.next.neutral
			var stadium: String = model.next.home.presentation.stadium
			_check(text.contains("Terrain neutre") if neutral else text.contains(stadium), "Office identifies actual venue for " + model.next.phase + " " + model.next.leagueId)
			if neutral:
				_check(not text.contains(stadium) and text.contains("Territoire du club"), "Neutral venue does not claim the home club stadium and identifies the photo")
			var found := false
			for art in classic.find_children("*", "Control", true, false):
				if art.get_meta("photo_kind", "") == "generated": found = true
			_check(found, "The base-game venue preview uses generated territory art")
			var client := Rect2(Vector2.ZERO, root.get_visible_rect().size)
			for label in _labels(classic):
				if label.text.contains("Terrain neutre") or label.text == stadium:
					_check(client.encloses(label.get_global_rect()) and label.get_minimum_size().x <= label.size.x + 1, "Venue caption remains visible at " + str(dimensions))
			classic.queue_free()
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("CD_GODOT_DATA_DIR").path_join("office-%s-%s-%d.png" % [model.next.leagueId,model.next.phase,dimensions.x]))

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.timer.stop()
	var deadline := Time.get_ticks_msec() + 15000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	await _wait()
	await _bench()
	_clocks()
	await _offices()
	var pid: int = app.bridge.child_pid
	app.bridge.stop()
	deadline = Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	# Sous Unix, interroger un enfant déjà récolté fait journaliser une ERREUR au moteur : on lit /proc.
	var worker_gone: bool = not DirAccess.dir_exists_absolute("/proc/%d" % pid) if OS.has_feature("linux") else not OS.is_process_running(pid)
	_check(app.bridge.child_pid <= 0 and worker_gone, "Owned worker closes")
	print(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
