extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
# Production main scene and exported worker only. Persistent meeting decisions
# must be accepted before the corresponding full-screen scene can continue.
var app: Control
var director: Node
var failures: Array[String] = []
var checks := 0
var directory := OS.get_environment("CD_THREE_ROOMS_ARTIFACTS")
var fixtures := OS.get_environment("CD_THREE_ROOMS_FIXTURES")

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("THREE ROOMS FAIL: " + message)

func settle() -> void:
	for i in 8: await process_frame

func wait_command(command: String, refusal: bool = false) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting, "Real worker answered " + command)
	check(bool(app.bridge.last_response_ok) != refusal, "Production response for " + command)
	app.timer.stop()
	await settle()
	app.timer.stop()

func ask(command: String, payload: Dictionary = {}, refusal: bool = false) -> void:
	app._command(command, payload)
	await wait_command(command, refusal)

func prepare_match_day() -> bool:
	for day in 40:
		if not await ContextualFlow.settle_club_meetings(app, self, check): return false
		var cadence: Dictionary = app.model.meta.get("calendarCadence", {})
		if cadence.is_empty() or cadence.get("matchReady", false):
			check(app.model.get("next") is Dictionary, "Actual fixture exists on the permitted kickoff day")
			return app.model.get("next") is Dictionary
		check(cadence.get("canAdvance", false), "Actual calendar permits the next preparation day")
		if not cadence.get("canAdvance", false): return false
		await ask("advance_day", {"fromDate":app.model.meta.calendarToday})
		if not app.bridge.last_response_ok: return false
	check(false, "Actual calendar reaches kickoff within forty preparation days")
	return false

func start_app() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Actual main scene is connected to its owned worker")
	app.timer.stop()
	var maximize := Callable(app, "_keep_filled_display")
	if root.size_changed.is_connected(maximize): root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize): root.focus_entered.disconnect(maximize)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await settle()
	check(root.size == Vector2i(1280,720), "Actual client area is exactly 1280x720")
	director = app.find_child("ContextualDirector", true, false)
	check(director != null, "Production contextual director is installed")

func stop_app() -> void:
	if not is_instance_valid(app): return
	app.closing = true
	app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	if is_instance_valid(app.soundscape): app.soundscape.dispose()
	app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 3500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Owned production worker is stopped and released")
	app.queue_free()
	await process_frame
	await process_frame

func checkpoint() -> Dictionary:
	await ask("export")
	return {"text":str(app.model.meta.exportText), "bytes":FileAccess.get_file_as_bytes(str(app.model.meta.dataDir).path_join("donnees.json"))}

func same_checkpoint(before: Dictionary, message: String) -> void:
	var after := await checkpoint()
	check(after.text == before.text, message + " preserves state, receipts, RNG and clock")
	check(after.bytes == before.bytes, message + " preserves every saved byte")

func saved_state() -> Dictionary:
	await ask("export")
	return JSON.parse_string(str(app.model.meta.exportText)).state

func fixture_text(name: String) -> String:
	return FileAccess.get_file_as_string(fixtures.path_join(name + ".json"))

func meeting() -> Dictionary:
	var value: Variant = app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene")
	return value if value is Dictionary else {}

func player(id: String) -> Dictionary:
	for person: Dictionary in app.model.get("squad", []):
		if str(person.id) == id: return person
	return {}

func medical_row(id: String) -> Dictionary:
	for person: Dictionary in app.model.get("clubLife", {}).get("clubSupport", {}).get("medical", {}).get("players", []):
		if str(person.id) == id: return person
	return {}

func refused(command: String, payload: Dictionary = {}) -> void:
	var before := await checkpoint()
	await ask(command, payload, true)
	check(director.error_label.is_visible_in_tree() and not director.error_label.text.is_empty(), "Refusal is visible inside the mandatory room")
	no_global_modal()
	await same_checkpoint(before,"Refused " + command)

func pending_guards(kind: String) -> void:
	var id := str(meeting().id)
	var before := await checkpoint()
	director.close_room()
	app._navigate("Effectif")
	director.open_training()
	await settle()
	check(director.active() and director.kind == kind and str(meeting().id) == id, "Navigation, close and another room cannot bypass " + kind)
	await same_checkpoint(before,"Attempted local scene bypass")
	await refused("club_meeting_continue",{"meetingId":id})
	await refused("club_meeting_continue",{"meetingId":id,"completed":true})
	await refused("begin_match")
	await refused("tick",{"steps":1})
	if kind != "medical": await refused("train")
	else: await refused("club_board_priority",{"context":app.model.clubLife.clubStrategy.context,"key":"finances"})

func check_continue(name: String, completed: bool) -> void:
	var button: BaseButton = director.view.find_child(name,true,false)
	check(button != null if completed else button == null or button.disabled, "Continue is unavailable until the authoritative decision is completed")
	if button != null:
		check(button.disabled != completed,"Continue reflects authoritative completion")
		assert_visible_action(name)

func restart_meeting(id: String, completed: bool) -> void:
	var before := await checkpoint()
	await ask("save")
	var saved := await checkpoint()
	check(JSON.parse_string(before.text).state == JSON.parse_string(saved.text).state,"Saving the scene does not invent a decision")
	await stop_app()
	await start_app()
	check(str(meeting().get("id","")) == id and bool(meeting().get("completed",false)) == completed,"Actual worker restart restores pending/completed meeting exactly")
	await same_checkpoint(saved,"Worker restart")

func capture_room(kind: String, continue_name: String) -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = resolution
		await settle()
		room_check(kind,resolution)
		assert_visible_action(continue_name)
		await capture(kind + "-" + str(resolution.x))
	root.size = Vector2i(1280,720)
	await settle()

func answer_press() -> Dictionary:
	var data: Dictionary = app.model.clubLife.press
	var answers: Array = []
	for index in data.conference.questions.size():
		var question: Dictionary = data.conference.questions[index]
		check(not str(question.journalist.id).is_empty() and not str(question.journalist.name).is_empty(),"Question has its actual projected journalist")
		director.view._select_question(index)
		await settle()
		check(str(director.view.question_label.text).contains(str(question.question)),"Current full question is the real worker projection")
		var answer: Dictionary = question.answers[0]
		press_button("PressAnswer_" + str(question.id) + "_" + str(answer.id))
		answers.append({"questionId":question.id,"answerId":answer.id})
	check(director.view.choices.size() == data.conference.questions.size(),"Every real question has one permitted answer")
	return {"context":data.context.duplicate(true),"answers":answers,"invitationId":data.conference.invitationId}

func visible_confirmation() -> ConfirmationDialog:
	for dialog in app.find_children("*","ConfirmationDialog",true,false):
		if dialog.visible: return dialog
	return null

func open_press_mail(invitation_id: String, completed: bool = false) -> bool:
	if app.route == "Accueil":
		var resume: Button = app.root_content.find_child("EntryResume", true, false)
		check(resume != null and resume.is_visible_in_tree() and not resume.disabled, "A saved career has a visible Resume action")
		if resume == null or resume.disabled or not resume.is_visible_in_tree(): return false
		resume.pressed.emit()
		await settle()
	var inbox_visible: bool = app.route == "Réception" and not director.active() and app.root_content.is_visible_in_tree()
	check(inbox_visible, "A pending or published press appointment leaves Réception visible until its mail is opened")
	if not inbox_visible: return false
	app._navigate("Presse")
	await settle()
	check(app.route == "Réception" and not director.active(), "Direct navigation to Presse cannot bypass its mail")
	check(app.body.find_child("InboxOpenPressInvitation", true, false) == null, "The conference action is absent before opening the mail")
	var mail: Button
	for row: Button in app.body.find_children("*", "Button", true, false):
		if row.get_meta("message_id", "") == invitation_id:
			mail = row
			break
	check(mail != null and mail.is_visible_in_tree() and not mail.disabled, "Réception contains the exact persisted press mail")
	if mail == null or mail.disabled or not mail.is_visible_in_tree(): return false
	mail.pressed.emit()
	await settle()
	check(app.route == "Réception" and not director.active(), "Reading the press mail still leaves Réception visible")
	var action: Button = app.body.find_child("InboxOpenPressInvitation", true, false)
	check(action != null and action.is_visible_in_tree() and not action.disabled, "Reading the press mail exposes its enabled conference action")
	if action == null or action.disabled or not action.is_visible_in_tree(): return false
	action.pressed.emit()
	await settle()
	var opened: bool = director.active() and director.kind == "press"
	check(opened and app.route == "Réception", "Only the mail action opens the press room over Réception")
	if opened: check_continue("PressReturn", completed)
	return opened

func press_flow() -> bool:
	await ask("new_career",{"mode":"common","club":29})
	check(meeting().get("kind") == "press" and not meeting().completed,"New career records its real press appointment")
	var id := str(meeting().id)
	var invitation_id := str(app.model.clubLife.press.conference.invitationId)
	if not await open_press_mail(invitation_id): return false
	await capture_room("press","PressPublish")
	var before := await checkpoint()
	await ask("snapshot")
	await same_checkpoint(before,"Viewing/reading the press room")
	await pending_guards("press")
	await refused("club_meeting_ack",{"meetingId":id})
	await restart_meeting(id,false)
	if not await open_press_mail(invitation_id): return false
	var original := await checkpoint()
	var payload := await answer_press()
	await same_checkpoint(original,"Selecting local press answers")
	var stale: Dictionary = payload.duplicate(true)
	stale.context.week = int(stale.context.week) + 1
	await refused("press_conference",stale)
	check(director.view.choices.size() == payload.answers.size(),"Worker refusal preserves the prepared answers")
	press_button("PressPublish")
	check(app.waiting and app.last_command == "press_conference","Publish uses actual public command bookkeeping")
	var all_disabled := true
	for control in director.overlay.find_children("*","BaseButton",true,false):
		if control.has_meta("contextual_enabled") and not control.disabled: all_disabled = false
	check(all_disabled,"Conference actions disable while the real worker is pending")
	await wait_command("press_conference")
	check(str(meeting().id) == id and meeting().completed,"Accepted conference authoritatively completes the persisted press appointment")
	check(app.model.clubLife.press.lastOutcome.context == payload.context,"Outcome is from this real career context")
	var history_size: int = app.model.clubLife.press.history.size()
	check_continue("PressReturn",true)
	await refused("press_conference",payload)
	await restart_meeting(id,true)
	if not await open_press_mail(invitation_id,true): return false
	check(app.model.clubLife.press.history.size() == history_size,"Completed restart does not replay any journalist answer")
	press_button("PressReturn")
	await wait_command("club_meeting_continue")
	check(meeting().get("kind") == "board" and str(meeting().get("id")) != id,"Continue advances to the next actual initial board appointment")
	await refused("club_meeting_continue",{"meetingId":id})
	return true

func board_flow() -> void:
	check(meeting().get("kind") == "board" and not meeting().completed,"Board appointment is automatically required")
	var id := str(meeting().id)
	check_continue("BoardRoomClose",false)
	await capture_room("board","BoardRoomClose")
	await pending_guards("board")
	await restart_meeting(id,false)
	var strategy: Dictionary = app.model.clubLife.clubStrategy
	var project: Dictionary = {}
	for offer: Dictionary in strategy.board.projectOptions:
		if not offer.used and float(strategy.finance.cash) >= float(offer.cost): project = offer; break
	check(not project.is_empty(),"A real offered board project is affordable from the actual club cash")
	if project.is_empty(): return
	var before := await checkpoint()
	press_button("BoardProject_" + str(project.id))
	await settle()
	var dialog := visible_confirmation()
	check(dialog != null and not app.waiting,"Project displays the real cost confirmation before mutation")
	await same_checkpoint(before,"Unconfirmed board quote")
	if dialog != null: dialog.canceled.emit()
	await settle()
	await same_checkpoint(before,"Cancelled board project")
	check(not meeting().completed,"Cancelling a cost cannot complete a mandatory decision")
	press_button("BoardProject_" + str(project.id))
	await settle()
	dialog = visible_confirmation()
	check(dialog != null,"The concrete project quote can be reviewed again")
	if dialog != null: dialog.confirmed.emit()
	await wait_command("club_board_project")
	check(float(app.model.finance.cash) == float(strategy.finance.cash) - float(project.cost),"Only the actual confirmed project cost is debited")
	check(meeting().completed and str(meeting().id) == id,"Accepted board decision completes its authoritative appointment")
	check(app.model.clubLife.clubStrategy.board.projects.any(func(row: Dictionary): return row.kind == project.id),"Real project is present in the career record")
	await refused("club_board_project",{"context":strategy.context,"kind":project.id,"confirmed":true})
	await restart_meeting(id,true)
	press_button("BoardRoomClose")
	await wait_command("club_meeting_continue")
	check(meeting().is_empty(),"All introductory decisions are completed and continued")
	# A second real, validated pending board save exercises the priority path.
	await ask("import",{"text":fixture_text("board")})
	check(meeting().get("kind") == "board","Imported actual pending board appointment resumes automatically")
	var key := "finances" if app.model.clubLife.clubStrategy.board.priority != "finances" else "performance"
	press_button("BoardPriority_" + key)
	await wait_command("club_board_priority")
	check(app.model.clubLife.clubStrategy.board.priority == key and meeting().completed,"Actual priority command is a completed decision, without client acknowledgement")
	press_button("BoardRoomClose")
	await wait_command("club_meeting_continue")

func medical_flow() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixtures.path_join("meta.json")))
	var patient := str(meta.patientId)
	await ask("import",{"text":fixture_text("medical")})
	check(meeting().is_empty(),"Legacy import without the optional meeting namespace is not mutated by a read")
	var imported := await checkpoint()
	await ask("snapshot")
	await same_checkpoint(imported,"Reading imported availability facts")
	await ask("auto_lineup")
	check(meeting().get("kind") == "medical" and str(meeting().get("playerId")) == patient,"An actual management mutation schedules the factual injured player")
	var id := str(meeting().id)
	check(not meeting().ackAllowed and not meeting().completed,"Available injured case requires an actual medical protocol")
	await capture_room("medical","MedicalClose")
	await pending_guards("medical")
	await restart_meeting(id,false)
	await refused("club_meeting_ack",{"meetingId":id})
	var picker: OptionButton = director.view.find_child("MedicalPlayerPicker",true,false)
	check(picker != null and picker.disabled,"The assigned patient cannot be switched away to bypass the meeting")
	var portrait: TextureRect = director.view.find_child("MedicalPlayerPortrait",true,false)
	check(portrait != null and str(portrait.get_meta("person_id")) == patient,"Medical portrait belongs to the actual assigned player")
	var before_player := player(patient).duplicate(true)
	var before := await checkpoint()
	press_button("MedicalProtocol_prudent")
	await same_checkpoint(before,"Previewing the allowed medical protocol")
	press_button("MedicalConfirmProtocol")
	await wait_command("medical_protocol")
	check(medical_row(patient).protocol == "prudent" and meeting().completed,"Real protocol confirmation completes the correct patient's appointment")
	check(player(patient).injury == before_player.injury and player(patient).condition == before_player.condition and player(patient).physicalLoad == before_player.physicalLoad,"Confirming a protocol does not invent immediate recovery or conditioning")
	await restart_meeting(id,true)
	press_button("MedicalClose")
	await wait_command("club_meeting_continue")
	# Training is a real mutation; it supplies a read-only medical follow-up.
	await ask("import",{"text":fixture_text("medical")})
	await ask("train",{"mode":"repos"})
	check(meeting().get("kind") == "medical" and meeting().ackAllowed,"Actual completed training schedules a read-only factual medical follow-up")
	check(not app.model.clubLife.clubSupport.medical.available,"Worker medical decision flags are unavailable after real training")
	var confirm: Button = director.view.find_child("MedicalConfirmProtocol",true,false)
	check(confirm == null or confirm.disabled,"Protocol cannot be changed when actual medical flags forbid it")
	id = str(meeting().id)
	await refused("medical_protocol",{"context":app.model.clubLife.clubSupport.context,"id":patient,"protocol":"standard"})
	var readonly := await checkpoint()
	press_button("MedicalAcknowledge")
	await wait_command("club_meeting_ack")
	check(meeting().completed,"Explicit acknowledgement completes the actual read-only follow-up")
	var acknowledged := await saved_state()
	var prior: Dictionary = JSON.parse_string(readonly.text).state
	check(acknowledged.clubs == prior.clubs,"Acknowledging facts gives no injury, condition or load gain")
	press_button("MedicalClose")
	await wait_command("club_meeting_continue")
	# A recorded return stage allows acknowledging the actual current plan.
	await ask("import",{"text":fixture_text("return")})
	await ask("auto_lineup")
	check(meeting().get("kind") == "medical" and meeting().ackAllowed and medical_row(patient).stage == "reprise","Actual recorded return stage supports its explicit current-plan acknowledgement")
	var return_player := player(patient).duplicate(true)
	press_button("MedicalLoad_repos")
	await wait_command("set_player_load")
	check(player(patient).loadPlan == "repos" and not meeting().completed,"Actual reprise load choice is applied but does not bypass the required conversation acknowledgement")
	check(player(patient).injury == return_player.injury and player(patient).condition == return_player.condition and player(patient).physicalLoad == return_player.physicalLoad,"Changing a return load plan alone gives no physical recovery gain")
	await refused("club_meeting_continue",{"meetingId":meeting().id})
	press_button("MedicalAcknowledge")
	await wait_command("club_meeting_ack")
	check(meeting().completed,"Return plan acknowledgement is persisted by the worker")
	press_button("MedicalClose")
	await wait_command("club_meeting_continue")

func priorities_and_context() -> void:
	await ask("import",{"text":fixture_text("board")})
	var prior_id := str(meeting().id)
	await ask("new_career",{"mode":"common","club":28})
	check(meeting().get("kind") == "press" and int(meeting().context.club) == 28 and str(meeting().id) != prior_id,"New career invalidates the previous club's appointment and records its own conversation")
	check(app.route == "Réception" and not director.active(),"Changing clubs requires opening the new press mail")
	await ask("import",{"text":fixture_text("baseline")})
	check(meeting().is_empty() and not director.active(),"Import restores exactly the saved completed meetings without an old ghost room")
	# Current-match priority is tested with a real pending pre-match scene.
	await ask("train",{"mode":"repos"})
	check(meeting().is_empty(),"Completed same-context meeting receipts are not re-created by training")
	if not await prepare_match_day(): return
	await ask("auto_lineup")
	if not await ContextualFlow.settle_club_meetings(app, self, check): return
	await ask("begin_match")
	check(director.kind == "locker" and app.model.clubLife.matchTalks.scene.phase == "pre","Actual match talk remains above all three management rooms")
	var before := await checkpoint()
	for kind in ["press","medical","board"]: director.open_room(kind)
	await settle()
	check(director.kind == "locker" and not app.root_content.is_visible_in_tree(),"No room navigation can replace the real match immersion")
	await same_checkpoint(before,"Room attempts during real match")

func press_button(name: String) -> void:
	var button: BaseButton = director.view.find_child(name, true, false)
	check(button != null and not button.disabled and button.is_visible_in_tree(), "Current scene exposes enabled " + name)
	if button != null and not button.disabled: button.pressed.emit()

func no_global_modal() -> void:
	for dialog in app.find_children("*", "AcceptDialog", true, false):
		check(not dialog.visible, "A global modal cannot obscure the contextual conversation")

func room_check(kind: String, resolution: Vector2i) -> void:
	check(root.size == resolution, "Actual client area equals requested " + str(resolution))
	check(director.active() and director.kind == kind, "Active full-screen meeting is " + kind)
	check(not app.root_content.is_visible_in_tree(), "Management shell hidden during " + kind)
	check(not app.coach.is_visible_in_tree(), "Coach hidden during " + kind)
	check(director.overlay.get_global_rect().size.distance_to(Vector2(resolution)) < 1.0, "Meeting covers the full application")
	var container: SubViewportContainer = director.view.find_child("ContextualRoomViewport", true, false)
	check(container != null and container.stretch, "Meeting renders an actual native room viewport")
	if container != null:
		check(container.get_global_rect().position.distance_to(Vector2.ZERO) < 1.0 and container.size.distance_to(Vector2(resolution)) < 1.0, "3D room covers the full client area")
		var viewport: SubViewport = container.get_child(0)
		check(viewport.size == resolution and viewport.get_child_count() > 0, "3D pixels and geometry follow actual client resolution")
		var room: Node3D = viewport.get_child(0)
		check(room != null and room.get_child_count() > 10, "Room is actual native geometry, not a still image")
		check(room.get("club").get("name", "") == app.model.club.get("presentation", {}).get("name", app.model.club.get("name", "")), "Physical room resolves the current club identity")
	no_global_modal()

func assert_visible_action(name: String) -> void:
	var button: BaseButton = director.view.find_child(name, true, false)
	check(button != null and button.is_visible_in_tree(), "Meeting action remains visible: " + name)
	if button != null:
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()), "Meeting action fits without leaving the application: " + name)

func capture(name: String) -> void:
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == root.size, "Capture has the exact tested client dimensions")
	check(image.save_png(directory.path_join(name + ".png")) == OK, "Saved real rendered meeting " + name)

func finish() -> void:
	await stop_app()
	var report := {"checks":checks,"failures":failures,"real_worker":true,"display":DisplayServer.get_name(),"invented_sporting_results":false}
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	print("THREE_ROOMS_FLOW ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty() or fixtures.is_empty():
		printerr("Three-room QA requires explicit disposable career and validated fixture paths")
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	await start_app()
	if director == null:
		await finish()
		return
	if not await press_flow():
		await finish()
		return
	await board_flow()
	await medical_flow()
	await priorities_and_context()
	await finish()
