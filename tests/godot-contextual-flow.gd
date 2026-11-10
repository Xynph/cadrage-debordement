extends SceneTree
# Run against the staged native project and an empty CD_GODOT_DATA_DIR. Every
# career/match transition below goes through main._command and the real worker.
const G = preload("res://ui/game_skin.gd")
var app: Control
var director: Node
var failures: Array[String] = []
var checks := 0
var directory := OS.get_environment("CD_CONTEXTUAL_ARTIFACTS")

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("CONTEXTUAL FAIL: " + message)

func settle() -> void:
	for i in 10: await process_frame

func wait_command(command: String, refusal: bool = false) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting, "Worker answered " + command)
	check(bool(app.bridge.last_response_ok) != refusal, "Real worker response " + command)
	app.timer.stop()
	await settle()
	app.timer.stop()

func ask(command: String, payload: Dictionary = {}, refusal: bool = false) -> void:
	app._command(command, payload)
	await wait_command(command, refusal)

func talk() -> Dictionary:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return value if value is Dictionary else {}

func viewport_check(container_name: String) -> void:
	var container: SubViewportContainer = director.view.find_child(container_name, true, false)
	check(container != null, container_name + " is a rendered SubViewportContainer")
	if container == null: return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	check(container.get_global_rect().position.distance_to(screen.position) < 1.0 and container.size.distance_to(screen.size) < 1.0, container_name + " covers application at " + str(root.size))
	check(container.stretch, "Native viewport follows resolution")
	check(container.get_child_count() > 0 and container.get_child(0) is SubViewport, "Actual native viewport exists")
	if container.get_child_count() > 0 and container.get_child(0) is SubViewport:
		var viewport: SubViewport = container.get_child(0)
		check(viewport.size == root.size, "Native viewport pixels follow application")

func immersive_check(kind: String) -> void:
	check(director.active() and director.kind == kind, "Contextual director displays " + kind)
	check(not app.root_content.is_visible_in_tree(), "Career management shell hidden during " + kind)
	check(not app.coach.is_visible_in_tree(), "Career coach hidden during " + kind)
	check(director.overlay.get_global_rect().size.distance_to(Vector2(root.size)) < 1.0, "Immersion covers full application")
	for dialog in app.find_children("*", "AcceptDialog", true, false):
		check(not dialog.visible, "No global modal obscures contextual " + kind)

func locker_check(phase: String) -> void:
	check(talk().get("phase") == phase, "Real career phase " + phase)
	immersive_check("locker")
	viewport_check("ContextualRoomViewport")
	var grid: GridContainer = director.view.find_child("TalkDeclarations", true, false)
	check(grid != null and grid.get_child_count() == 6, phase + " has exactly six declaration buttons")
	if grid != null:
		var offered: Array = talk().get("options", []).map(func(option: Dictionary): return str(option.id))
		for button in grid.get_children():
			check(button is Button and str(button.get_meta("choice_id", "")) in offered, "Button is a permitted original declaration")
			check(button.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "Declaration is visible at " + str(root.size))
	var cards: Array[Node] = []
	for button in director.view.find_children("*", "Button", true, false):
		if button.has_meta("participant_id"): cards.append(button)
	var ids: Array = talk().get("participants", []).map(func(player: Dictionary): return str(player.id))
	check(cards.size() == 23 and ids.size() == 23, "All actual 15 starters and 8 substitutes are represented")
	var found: Array[String] = []
	for card in cards:
		var id := str(card.get_meta("participant_id"))
		check(id in ids and not id in found, "Card belongs to one actual match participant")
		found.append(id)
		var player: Dictionary = {}
		for candidate: Dictionary in app.model.get("squad", []):
			if str(candidate.id) == id: player = candidate
		check(not player.is_empty(), "Participant resolves current squad identity")
		var number := 0
		for participant: Dictionary in talk().get("participants", []):
			if str(participant.id) == id: number = int(participant.number)
		var expected_position := str(player.get("pos", ""))
		if number >= 1 and number <= 15:
			for slot: Dictionary in app.model.get("selection", {}).get("slots", []):
				if int(slot.slot) == number - 1: expected_position = str(slot.label)
			if number in [6, 7] and expected_position == "Troisième ligne": expected_position = "Troisième ligne aile"
		var position_label: Label = card.find_child("ParticipantPosition", true, false)
		check(position_label != null and position_label.text == expected_position and not expected_position.is_empty(), "Jersey role for starter or actual primary position for substitute " + id)
		if position_label != null:
			check(position_label.is_visible_in_tree() and card.get_global_rect().encloses(position_label.get_global_rect()), "Position is visibly contained in the actual player card")
			var name_label: Label
			for label in card.find_children("*", "Label", true, false):
				if not str(player.get("name", "")).is_empty() and str(label.text).contains(str(player.name)): name_label = label
			check(name_label != null and position_label.get_global_rect().position.y > name_label.get_global_rect().position.y, "Actual position is displayed below the player name")
		var portrait: TextureRect = card.find_child("ParticipantPortrait", true, false)
		check(portrait != null and portrait.texture != null, "Actual participant has a visible portrait")
		if portrait != null and not player.is_empty():
			var expected := G.portrait(int(player.get("portraitIndex", 0)), 40, player)
			check(portrait.texture == expected.texture or portrait.texture.get_image().get_data() == expected.texture.get_image().get_data(), "Portrait is resolved using the same actual player ID")
			expected.free()
		check(card.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(card.get_global_rect()), "Participant remains on screen at " + str(root.size))
	# Tone is supplied by the selected declaration, never a second control.
	for control in director.view.find_children("*", "OptionButton", true, false):
		check(false, "No independent tone selector in the talk: " + str(control.name))

func capture(name: String) -> void:
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(directory.path_join(name + ".png")) == OK, "Saved actual rendered career screenshot " + name)

func actor_positions(stage: Node3D) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var players := stage.get_node_or_null("Players")
	if players != null:
		for player in players.get_children():
			if player is Node3D: positions.append(player.position)
	return positions

func reach(phase: String) -> void:
	for batch in 40:
		await ask("tick", {"steps":120})
		if not talk().is_empty():
			check(talk().get("phase") == phase, "Batched real match stops at " + phase)
			return
	check(false, "Real match did not reach " + phase)

func run() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		printerr("Contextual QA requires an explicit disposable CD_GODOT_DATA_DIR")
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Real main scene connected to owned worker")
	app.timer.stop()
	# Production intentionally maximizes normal desktop windows. Detach that
	# presentation callback in this QA host so requested resolution tests measure
	# the actual client area rather than a silently re-maximized desktop.
	var maximize := Callable(app, "_keep_filled_display")
	if root.size_changed.is_connected(maximize): root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize): root.focus_entered.disconnect(maximize)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await settle()
	check(root.size == Vector2i(1280,720), "Actual initial client area is exactly 1280x720")
	await ask("new_career", {"mode":"common", "club":29})
	director = app.find_child("ContextualDirector", true, false)
	check(director != null, "Production contextual director installed")
	if director == null:
		await finish()
		return
	# The office is entered from an actual invitation, and a read cannot create it.
	var entries: Array = app.model.clubLife.sceneInvitations.invitations
	check(not entries.is_empty(), "New career has a contextual invitation")
	if not entries.is_empty():
		app._navigate("Réception")
		await settle()
		var invitations: Node = app.root_content.find_child("ContextualInvitations", true, false)
		check(invitations != null, "Actual Reception exposes the factual invitation entrypoint")
		var buttons: Array[Node] = invitations.find_children("*", "Button", true, false) if invitations != null else []
		check(buttons.size() == entries.size(), "Reception has one open button per actual pending invitation")
		if not buttons.is_empty(): buttons[0].pressed.emit()
		else: director.open_invitation(str(entries[0].id))
		await wait_command("scene_invitation_open")
		immersive_check("conversation")
		await capture("office-real-career")
		await ask("scene_invitation_close", {"id":entries[0].id, "dismiss":true})
	# Visiting training is pure: it uses actual condition/load and does not train.
	await ask("export")
	var prior: String = app.model.meta.exportText
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		app.Immersive.open_training(app)
		await settle()
		check(root.size == resolution, "Actual training client area matches requested " + str(resolution))
		var observe: Button = app.root_content.find_child("ContextualObserveTraining", true, false)
		check(observe != null and observe.is_visible_in_tree(), "Actual training route exposes Observe at " + str(resolution))
		if observe != null: observe.pressed.emit()
		else: director.open_training()
		await settle()
		immersive_check("training")
		await capture("training-before-session-" + str(resolution.x))
		director.close_training()
	root.size = Vector2i(1280,720)
	await ask("export")
	check(app.model.meta.exportText == prior, "Observing preparation gives no training or morale gain")
	await ask("train")
	await ask("auto_lineup")
	await ask("begin_match")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = resolution
		await settle()
		check(root.size == resolution, "Actual locker client area matches requested " + str(resolution))
		locker_check("pre")
		await capture("pre-" + str(resolution.x))
	root.size = Vector2i(1280,720)
	await settle()
	# A rejected public command remains visible inside the immersive surface.
	await ask("pause", {"paused":false}, true)
	immersive_check("locker")
	check(director.error_label.is_visible_in_tree() and not director.error_label.text.is_empty(), "Worker refusal is visible in contextual scene")
	check(talk().get("phase") == "pre", "Refusal leaves original talk active")
	await ask("snapshot")
	var option: Dictionary = talk().options[0]
	director.view._select_choice(option)
	director.view._toggle_player(talk().participants[0].id)
	var pronounce: Button = director.view.find_child("TalkPronounce", true, false)
	check(pronounce != null and not pronounce.disabled, "Preview and real selected recipient enable Prononcer")
	if pronounce != null: pronounce.pressed.emit()
	check(app.waiting and app.last_command == "match_talk_decide", "Prononcer uses public command bookkeeping")
	var disabled_while_waiting := true
	for button in director.overlay.find_children("*", "BaseButton", true, false):
		if not button.disabled: disabled_while_waiting = false
	check(disabled_while_waiting, "Contextual decisions disabled while real worker is pending")
	await wait_command("match_talk_decide")
	check(talk().decision.choiceId == option.id and talk().decision.playerIds.size() == 1, "Real decision records offered choice and actual selected player")
	await capture("pre-decision")
	director.view._continue()
	await wait_command("match_talk_continue")
	immersive_check("live")
	viewport_check("LiveMatchViewport")
	var stage: Node3D = director.view.stage
	check(stage != null and stage.get_script().resource_path == "res://match_view.gd", "Live match uses the production moving NativeMatchView")
	if stage != null:
		var club_crest := G.crest(app.model.club)
		var expected_texture: Texture2D = club_crest.texture if club_crest is TextureRect else null
		check(stage._club_crest == expected_texture, "Production stadium resolves the actual active club crest")
		var branding: MultiMeshInstance3D = stage.get_node_or_null("ManagedClubCrests")
		check(branding != null and branding.visible == (expected_texture != null), "Missing active crest leaves neutral stadium fascia")
		if branding != null: check(branding.material_override.albedo_texture == expected_texture, "Stadium fascia uses the active club identity")
		var advertisements := stage.find_children("*", "Label3D", true, false)
		check(advertisements.size() == 16, "All sixteen Oval Legacy advertising boards remain present")
		for label in advertisements:
			check(str(label.text) == "OVAL LEGACY 27", "Advertising boards retain Oval Legacy 27")
		club_crest.free()
	var original_scene := JSON.stringify(app.model.live.scene)
	var original_positions: Array[Vector3] = actor_positions(stage) if stage != null else []
	await ask("tick", {"steps":6})
	check(JSON.stringify(app.model.live.scene) != original_scene, "Actual match presentation advances through worker ticks")
	if stage != null: check(stage.get_node_or_null("Players") != null and stage.get_node("Players").get_child_count() >= 30, "Production pitch has actual moving athlete actors")
	await create_timer(0.7).timeout
	app.timer.stop()
	if stage != null: check(actor_positions(stage) != original_positions, "Production athlete positions move after actual worker events")
	await capture("match-live")
	await reach("half")
	locker_check("half")
	check(app.model.live.atBreak, "Talk opens on real atBreak boundary")
	await capture("half")
	director.view._continue(true)
	await wait_command("match_talk_continue")
	await reach("post")
	locker_check("post")
	check(app.model.live.finished, "Debrief precedes validation of actual finished match")
	await ask("finish_round", {}, true)
	immersive_check("locker")
	check(director.error_label.is_visible_in_tree(), "Cannot bypass debrief with global finish")
	await capture("post")
	director.view._continue(true)
	await wait_command("match_talk_continue")
	check(app.model.live == null and not director.active(), "Post-match continue commits round and leaves immersion")
	check(app.root_content.is_visible_in_tree(), "Management returns after final match validation")
	await finish()

func finish() -> void:
	app.closing = true
	app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	if is_instance_valid(app.soundscape): app.soundscape.dispose()
	app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 3000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Owned worker closes")
	var report := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"real_worker":true,"sporting_rules_changed":false}
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	print("CONTEXTUAL_FLOW ", JSON.stringify(report))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
