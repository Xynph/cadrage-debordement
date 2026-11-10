extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")

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
	app.timer.stop()
	_check(not app.waiting, "Command completes without indefinite waiting")

func _command(command: String, payload: Dictionary = {}) -> void:
	if command == "begin_match" and not await _publish_press(): return
	app._command(command, payload)
	await _wait()
	if not app.bridge.last_response_ok: print("COMMANDE REFUSÉE : ", command, " · ", app.last_error)

func _publish_press() -> bool:
	var conference: Dictionary = app.model.get("clubLife", {}).get("press", {}).get("conference", {})
	if not conference.get("required", false): return true
	var previous_route: String = app.route
	app._show_press_inbox()
	var controls := ["InboxPressInvitation", "InboxOpenPressInvitation"]
	for question: Dictionary in conference.questions:
		controls.append("PressAnswer_" + str(question.id) + "_r4")
	controls.append("PressSubmit")
	for name: String in controls:
		await process_frame
		var button := app.root_content.find_child(name, true, false) as Button
		var available := button != null and button.is_visible_in_tree() and not button.disabled
		_check(available, "Action de la conférence disponible : " + name)
		if not available: return false
		button.pressed.emit()
	await _wait()
	var published: bool = app.bridge.last_response_ok and not app.model.clubLife.press.conference.required
	_check(published, "Le courrier de presse a été publié")
	if published: app._navigate(previous_route)
	return published

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
	await ContextualFlow.skip_talk(app, self, "pre", _check)
	if not app.model.live is Dictionary:
		_check(false, "A real match starts for the decision regression")
		return
	app._command("save")
	app.pause_menu()
	var dialogs := _dialogs()
	_check(dialogs.is_empty() and app.contextual_director.active() and not app.last_error.is_empty(), "Busy pause refusal stays in immersion without opening a career modal")
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
	_check(dialogs.is_empty() and app.contextual_director.active() and not app.last_error.is_empty(), "Saturated menu pause also refuses inside immersion without a career modal")
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
	_check(app.route == "Match" and app.contextual_director.match_immersed() and not app.root_content.is_visible_in_tree(), "Successful live-match import restores its authoritative immersive route")
	app._navigate("Match")
	await _command("pause", {"paused":false})
	app.bridge.stop()
	app.pause_menu()
	dialogs = _dialogs()
	_check(not app.waiting and dialogs.size() == 1 and dialogs[0].visible and dialogs[0].title == "Votre décision n'a pas été appliquée" and app.last_error.contains("fermé"), "Synchronous closed-transport refusal also prevents a second career modal")

func _press_key(code: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	for i in 5: await process_frame

func _activate_focus(button: Button, context: String) -> void:
	var available := button != null and button.is_visible_in_tree() and not button.disabled
	_check(available, context + " exposes a visible enabled keyboard action")
	if not available: return
	_check(root.get_visible_rect().grow(1).encloses(button.get_global_rect()), context + " keeps the real keyboard action inside the visible window")
	button.grab_focus()
	for i in 5: await process_frame
	_check(button.has_focus(), context + " accepts keyboard focus")
	await _press_key(KEY_ENTER)

func _preparation_axis(axis: String, option: Dictionary) -> Button:
	var button := app.body.find_child("Preparation" + axis + "_" + str(option.id), true, false) as Button
	return button if button != null else _named_button(app.body, str(option.label).to_upper())

func _tactics() -> void:
	app._navigate("Préparation")
	var tab := app.body.find_child("PreparationTabConsignes", true, false) as Button
	if tab != null:
		await _activate_focus(tab, "Preparation instructions tab")
		_check(int(app.management_ui.preparation.tab) == 1, "Preparation opens its actual instructions view")
	var tactics: Dictionary = app.model.tactics
	var attack: Dictionary = {}
	var defense: Dictionary = {}
	for option in tactics.attacks:
		if option.id != tactics.attack: attack = option; break
	for option in tactics.defenses:
		if option.id != tactics.defense: defense = option; break
	var attack_button := _preparation_axis("Attack", attack)
	var defense_button := _preparation_axis("Defense", defense)
	var alternatives := attack_button != null and defense_button != null and attack_button.is_visible_in_tree() and defense_button.is_visible_in_tree() and not attack_button.disabled and not defense_button.disabled
	_check(alternatives, "Both tactical axes expose a real visible alternative")
	if not alternatives: return
	attack_button.pressed.emit()
	defense_button.pressed.emit()
	_check(app.waiting and app.queued_action.is_empty() and app.last_error.is_empty(), "Preparation absorbs a second tactic while the first is pending")
	# Bypass the view guard to exercise the separate command-level refusal.
	app._command("set_tactics", {"attack": tactics.attack, "defense": defense.id})
	_check(app.waiting and app.queued_action.is_empty() and not app.last_error.is_empty(), "Rapid second tactical axis is explicitly refused until the first acknowledgement")
	await _wait()
	_check(app.model.tactics.attack == attack.id and app.model.tactics.defense == tactics.defense, "Refused old tactical payload cannot overwrite either axis")
	_dismiss_errors()
	defense_button = _preparation_axis("Defense", defense)
	_check(defense_button != null and defense_button.is_visible_in_tree() and not defense_button.disabled, "Fresh defense choice is visible after the attack acknowledgement")
	if defense_button == null: return
	defense_button.pressed.emit()
	await _wait()
	_check(app.model.tactics.attack == attack.id and app.model.tactics.defense == defense.id, "Fresh defense decision preserves the acknowledged attack")

func _bench_message(panel: Node, name: String) -> String:
	var label := panel.find_child(name, true, false) as Label
	return label.text if label != null and label.is_visible_in_tree() else ""

func _bench() -> void:
	app._navigate("Match")
	var initial_date: String = app.header_date.text
	await _command("begin_match")
	if not app.model.live is Dictionary:
		_check(false, "A real match starts for the bench regression")
		return
	await ContextualFlow.skip_talk(app, self, "pre", _check)
	var panel: Node = app.match_screen
	var viewport_id: int = app.match_view.get_parent().get_instance_id()
	await _command("pause", {"paused":true})
	var option: Dictionary = {}
	for choice in app.model.live.substitutions:
		if not choice.inIds.is_empty(): option = choice; break
	_check(not option.is_empty(), "Real match offers a qualified substitution")
	if option.is_empty(): return
	var incoming: Dictionary = {}
	for player in app.model.live.reserves:
		if player.id == option.inIds[0]: incoming = player; break
	panel._toggle_drawer("Banc")
	panel.selected_slot = int(option.slot)
	panel._drawer_key = ""
	app._update_match()
	_check(not _named_button(panel.drawer_body, incoming.name).disabled, "Paused bench enables a permitted entrant")
	_named_button(panel, "JOURNAL").pressed.emit()
	_check(panel.drawer_tab == "Journal" and panel.drawer.is_visible_in_tree() and _bench_message(panel, "MatchBenchStatus").is_empty(), "Journal hides the bench feedback")
	_named_button(panel, "BANC").pressed.emit()
	_check(panel.selected_slot == int(option.slot) and not _bench_message(panel, "MatchBenchContext").is_empty(), "Returning from the journal restores the selected bench context")
	_named_button(panel, "STATS").pressed.emit()
	_check(panel.drawer_tab == "Stats" and _bench_message(panel, "MatchBenchStatus").is_empty(), "Stats hides the bench feedback")
	_named_button(panel, "BANC").pressed.emit()
	_check(panel.selected_slot == int(option.slot) and not _bench_message(panel, "MatchBenchContext").is_empty(), "Returning from stats restores the selected bench context")
	await _command("pause", {"paused":false})
	_check(_named_button(panel.drawer_body, incoming.name).disabled, "Resume disables entrant without a tab or selection click")
	_check(_bench_message(panel, "MatchBenchStatus").contains("pause"), "Running bench explains the pause requirement")
	var stable_button := _named_button(panel.drawer_body, incoming.name)
	await _command("tick", {"steps":1})
	_check(_named_button(panel.drawer_body, incoming.name) == stable_button, "Unchanged running bench retains controls across ticks")
	await _command("pause", {"paused":true})
	_check(not _named_button(panel.drawer_body, incoming.name).disabled, "Pause re-enables entrant without a tab or selection click")
	_check(panel.drawer_tab == "Banc" and panel.selected_slot == int(option.slot), "Pause and resume retain the bench tab and selected outgoing position")
	# Permission-only projection change, keeping actual players and pause unchanged.
	var actual: Dictionary = app.model
	var restricted: Dictionary = actual.duplicate(true)
	restricted.live.substitutions = []
	var outgoing_name: String = str(actual.live.lineup[int(option.slot)].name)
	var outgoing_button := _named_button(panel.drawer_body, "%d · %s" % [int(option.slot) + 1, outgoing_name])
	outgoing_button.grab_focus()
	panel.update_frame(restricted)
	await process_frame
	await process_frame
	_check(_named_button(panel.drawer_body, incoming.name).disabled, "Permission-only change immediately disables the entrant")
	_check(_bench_message(panel, "MatchBenchStatus").contains("Aucun remplaçant autorisé"), "Blocked bench explains that no replacement is available")
	_check(_bench_message(panel, "MatchBenchContext").contains(outgoing_name), "Blocked bench retains the selected outgoing player's context")
	_check(root.gui_get_focus_owner() == _named_button(panel.drawer_body, "%d · %s" % [int(option.slot) + 1, outgoing_name]), "Permission-only change retains the outgoing button's focus")
	panel.update_frame(actual)
	_check(not _named_button(panel.drawer_body, incoming.name).disabled, "Restored permission re-enables the entrant")
	_check(not _bench_message(panel, "MatchBenchStatus").contains("Aucun remplaçant autorisé"), "Restored permission clears the blocked reason")
	await _command("delegate")
	_check(_named_button(panel.drawer_body, incoming.name).disabled, "Finished match disables entrant without another selection")
	_check(_bench_message(panel, "MatchBenchStatus").contains("Match terminé"), "Finished bench explains that the match is over")
	_check(panel.drawer_tab == "Banc" and panel.selected_slot == int(option.slot), "Finish retains bench context")
	await _command("finish_round")
	await ContextualFlow.settle_club_meetings(app, self, _check)
	var first_date: String = app.header_date.text
	var first_day: String = str(app.model.calendarPlanning.today).get_slice("-", 2)
	_check(app.route == "Réception" and app.header_date.is_visible_in_tree() and first_date != initial_date and first_date.begins_with(first_day + " ") and int(app.model.meta.week) == 1, "First round validation refreshes the date in Reception")
	await _command("auto_lineup")
	if not app.model.selection.valid: await _command("promote_cover", {"confirmed":true})
	app._navigate("Match")
	await _command("begin_match")
	await ContextualFlow.skip_talk(app, self, "pre", _check)
	await _command("delegate")
	await _command("finish_round")
	await ContextualFlow.settle_club_meetings(app, self, _check)
	var second_day: String = str(app.model.calendarPlanning.today).get_slice("-", 2)
	_check(app.route == "Réception" and app.header_date.is_visible_in_tree() and app.header_date.text != first_date and app.header_date.text.begins_with(second_day + " ") and int(app.model.meta.week) == 2, "Second round validation refreshes the date again in Reception")
	_check(app.model.live == null and not app.contextual_director.active() and app.root_content.is_visible_in_tree(), "Both round validations restore management after the immersive match")
	await _command("auto_lineup")
	if not app.model.selection.valid: await _command("promote_cover", {"confirmed":true})
	await _command("begin_match")
	await ContextualFlow.skip_talk(app, self, "pre", _check)
	_check(app.match_view.get_parent().get_instance_id() != viewport_id and app.match_view._actors.size() == 30, "Next fixture creates its actual immersive match viewport and thirty players")

func _modal() -> void:
	app._navigate("Recrutement")
	var formats := [Vector2i(1440,900),Vector2i(1920,1080)]
	if OS.get_environment("QA_RESOLUTION") == "2560x1440": formats = [Vector2i(2560,1440)]
	for dimensions in formats:
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

func _scroll_focus(scroll: ScrollContainer, context: String) -> Button:
	scroll.scroll_vertical = 0
	for i in 5: await process_frame
	var target: Button = null
	for button in _buttons(scroll):
		if not button.disabled and button.is_visible_in_tree(): target = button
	_check(target != null, context + " has an accessible focus target")
	if target == null: return null
	var before_rect := target.get_global_rect()
	var viewport := scroll.get_global_rect()
	var required_scroll := before_rect.position.y < viewport.position.y - 1 or before_rect.end.y > viewport.end.y + 1
	target.grab_focus()
	for i in 5: await process_frame
	var rectangle := target.get_global_rect()
	var vertical_visible := rectangle.position.y >= viewport.position.y - 1 and rectangle.end.y <= viewport.end.y + 1
	_check(target.has_focus() and vertical_visible, context + " keeps the focused action completely visible vertically")
	_check(scroll.scroll_vertical > 0 if required_scroll else vertical_visible, context + " scrolls an initially offscreen action or keeps fitting content visible")
	# A full-width roster row can extend under a horizontal scrollbar. Its real
	# identity text must fit the viewport even when the whole button cannot.
	var identity: Control = target
	var text := target.text
	var player_id := str(target.get_meta("player_id", ""))
	if not player_id.is_empty():
		var matches: Array = app.model.squad.filter(func(player: Dictionary): return str(player.id) == player_id)
		_check(matches.size() == 1, context + " focused row identifies one actual squad player")
		identity = null
		if matches.size() == 1:
			text = str(matches[0].name)
			for label: Label in target.find_children("*", "Label", true, false):
				if label.text == text: identity = label; break
	_check(not text.strip_edges().is_empty() and identity != null and identity.is_visible_in_tree() and viewport.grow(1).encloses(identity.get_global_rect()), context + " exposes its exact player identity or action text inside the viewport")
	print("FOCUS_GEOMETRY ", JSON.stringify({"context":context,"scroll":viewport,"target":rectangle,"before":before_rect,"vertical":scroll.scroll_vertical,"horizontal":scroll.scroll_horizontal,"targetName":target.name,"targetText":text,"playerId":player_id,"identity":identity.get_global_rect() if identity != null else null,"requiredScroll":required_scroll}))
	var previous := target.find_prev_valid_focus()
	_check(previous != null, context + " has a keyboard traversal predecessor")
	if previous != null:
		await _press_key(KEY_TAB, true)
		_check(previous.has_focus() and previous.is_visible_in_tree(), context + " real Shift+Tab changes focus to its visible predecessor")
	return target

func _focus() -> void:
	app._navigate("Effectif")
	for i in 5: await process_frame
	var list := app.body.find_child("SquadScroll", true, false) as ScrollContainer
	var profile := app.body.find_child("ProfileScroll", true, false) as ScrollContainer
	var card := app.body.find_child("SelectedPlayerCard", true, false) as Control
	var open_full := app.body.find_child("OpenPlayerFull", true, false) as Button
	print("FOCUS_SURFACE ", JSON.stringify({"list":list != null,"profile":profile != null,"selectedCard":card != null,"fullAction":open_full != null}))
	_check(list != null and list.is_visible_in_tree(), "The actual squad list has its own visible scroll viewport")
	var row: Button
	if list != null: row = await _scroll_focus(list, "Squad")
	if profile != null:
		_check(profile != list and profile.is_visible_in_tree(), "The historical player profile has its own visible scroll viewport")
		await _scroll_focus(profile, "Profile")
	else:
		_check(card != null and card.is_visible_in_tree() and open_full != null, "The current squad exposes its selected-player card and full-profile action")
		if row == null or card == null or open_full == null: return
		var player_id := str(row.get_meta("player_id", ""))
		await _activate_focus(row, "Actual squad row")
		var matches: Array = app.model.squad.filter(func(player: Dictionary): return str(player.id) == player_id)
		_check(app.selected_player == player_id and matches.size() == 1, "Keyboard activation selects the focused player's exact identity")
		if matches.size() != 1: return
		var player_name := str(matches[0].name)
		open_full = app.body.find_child("OpenPlayerFull", true, false) as Button
		await _activate_focus(open_full, "Open selected player's full profile")
		var full := app.body.find_child("ImmersivePlayerFull", true, false) as Control
		var heading := app.body.find_child("ProfilePlayerName", true, false) as Label
		_check(full != null and full.is_visible_in_tree() and heading != null and heading.text == player_name.to_upper() and heading.is_visible_in_tree(), "The visible full profile retains the selected player's exact name")
		var attributes := app.body.find_child("FullPlayerTab1", true, false) as Button
		await _activate_focus(attributes, "Full-profile attributes tab")
		_check(int(app.management_ui.immersive_player_tab) == 1 and app.selected_player == player_id, "Keyboard navigation reaches the real attributes view without changing player")
		var back := app.body.find_child("PlayerBackToSquad", true, false) as Button
		await _activate_focus(back, "Return from the full profile")
		card = app.body.find_child("SelectedPlayerCard", true, false) as Control
		list = app.body.find_child("SquadScroll", true, false) as ScrollContainer
		_check(card != null and card.is_visible_in_tree() and app.selected_player == player_id and app.body.find_child("ImmersivePlayerFull", true, false) == null, "Returning restores the squad card for the same player")
		_check(list != null and list.is_visible_in_tree() and list.scroll_vertical > 0, "Returning from the full profile restores the inspected squad scroll position")
	app._navigate("Match")
	await _command("begin_match")
	await ContextualFlow.skip_talk(app, self, "pre", _check)
	if not app.model.live is Dictionary:
		_check(false, "A real match starts for the focus regression")
		return
	await _command("pause", {"paused":true})
	var panel: Node = app.match_screen
	panel._toggle_drawer("Banc")
	panel.selected_slot = int(app.model.live.substitutions[0].slot)
	panel._drawer_key = ""
	app._update_match()
	for i in 5: await process_frame
	await _scroll_focus(panel.drawer_body.get_parent(), "Bench")

func _run() -> void:
	var mode := OS.get_environment("CD_GODOT_REGRESSION")
	var profile := OS.get_environment("CD_GODOT_DATA_DIR")
	if DisplayServer.get_name() == "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(2560,1440) if OS.get_environment("QA_RESOLUTION") == "2560x1440" else Vector2i(1280,720)
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
	await ContextualFlow.settle_club_meetings(app, self, _check)
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
		await ContextualFlow.skip_talk(app, self, "pre", _check)
		await _command("delegate")
		if not app.model.live is Dictionary: await app._close(1); return
		_check(app.pause_button.disabled, "Finished match disables pause")
		app.match_finish.pressed.emit()
		await _wait()
		_check(app.route == "Réception", "Round validation returns to Reception")
		if not await ContextualFlow.settle_club_meetings(app, self, _check): await app._close(1); return
		_check(not app.contextual_director.active() and app.root_content.is_visible_in_tree(), "Round transition and its actual meetings restore management")
		app._navigate("Match")
		_check(not app.pause_button.disabled, "Next kickoff enabled without navigation")
		# Repair the actual 23 after match injuries before testing the next kickoff.
		await _command("auto_lineup")
		var legal:bool=app.model.get("selection",{}).get("valid",false)
		if not await _publish_press(): await app._close(1); return
		app._navigate("Match")
		_check(not app.pause_button.disabled, "Next kickoff enabled after opening Match")
		if not app.pause_button.disabled:
			app.pause_button.pressed.emit()
			await _wait()
			_check((app.model.live != null and app.model.meta.round == 1) if legal else (app.model.live==null and not app.last_error.is_empty()), "Second kickoff starts or gives the real selection refusal")
			_dismiss_errors()
			if legal:
				await ContextualFlow.skip_talk(app, self, "pre", _check)
				await _command("delegate")
				await _command("finish_round")
				await ContextualFlow.settle_club_meetings(app, self, _check)
				app._navigate("Match")
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
		_check(child_pid > 0 and app.bridge.child_pid <= 0 and app.bridge._stopping and app.bridge._thread == null and app.bridge._stderr_thread == null and app.bridge._stdio == null and app.bridge._stderr == null, "id:null rejection terminates and releases owned worker, readers and pipes")
		var prior_errors := errors
		_dismiss_errors()
		app.bridge.send("snapshot")
		_check(errors > prior_errors, "Further commands fail immediately after terminal response")
	app.closing = true
	app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	if is_instance_valid(app.soundscape): app.soundscape.dispose()
	app.bridge.stop()
	var close_deadline := Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < close_deadline: await process_frame
	_check(app.bridge.child_pid <= 0 and app.bridge._thread == null and app.bridge._stderr_thread == null and app.bridge._stdio == null and app.bridge._stderr == null, "Owned child, readers and pipes close within bounded deadline")
	app.queue_free()
	for i in 3: await process_frame
	print(JSON.stringify({"mode": mode, "passed": failures.is_empty(), "checks": checks, "failures": failures, "errors": errors, "error_messages": error_messages}))
	quit(0 if failures.is_empty() else 1)
