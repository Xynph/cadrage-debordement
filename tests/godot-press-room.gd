extends SceneTree
# Component QA: real worker projections, with decisions intercepted by a stub.
# Receipt fixtures below exercise rendering only; full-flow QA executes effects.
const View = preload("res://ui/contextual/press_room_view.gd")
const Bridge = preload("res://engine_bridge.gd")
const G = preload("res://ui/carnet_skin.gd")
class Host extends Control:
	var model: Dictionary = {}
	var waiting := false
	var last_error := ""
class StubDirector extends Node:
	var app: Control
	var commands: Array = []
	var continuations := 0
	func command(id: String, payload: Dictionary = {}) -> void:
		commands.append({"command":id,"payload":payload.duplicate(true)})
		app.waiting = true
	func close_room() -> void: continuations += 1
var host: Host
var director: StubDirector
var bridge: Node
var view: Control
var checks := 0
var failures: Array[String] = []
var profile := OS.get_environment("CD_GODOT_DATA_DIR")
var artifacts := OS.get_environment("CD_PRESS_ROOM_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL ", message)
func settle() -> void:
	for frame in 5: await process_frame
func receive(value: Dictionary) -> void:
	host.model = value
	host.waiting = false
func request(id: String, payload: Dictionary = {}) -> void:
	host.waiting = true
	bridge.send(id, payload)
	var deadline := Time.get_ticks_msec() + 30000
	while host.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.waiting and bridge.last_response_ok, "real worker " + id)
func capture(name_: String) -> void:
	if artifacts.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(artifacts)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(artifacts.path_join(name_ + ".png")) == OK, "capture " + name_)
func all_within(node: Node) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	for name_: String in ["PressPublish", "PressPrevious", "PressNext", "PressReturn"]:
		var control: Control = node.find_child(name_, true, false)
		if control != null: check(screen.encloses(control.get_global_rect()), name_ + " fits " + str(root.size))
func run() -> void:
	if profile.is_empty() or not profile.is_absolute_path():
		printerr("Press QA requires an explicit disposable CD_GODOT_DATA_DIR")
		quit(2); return
	var existing := DirAccess.open(profile)
	if existing != null:
		existing.include_hidden = true
		if not existing.get_files().is_empty() or not existing.get_directories().is_empty():
			printerr("Press QA refuses a non-empty profile")
			quit(2); return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	host = Host.new()
	host.theme = G.T.make()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	bridge = Bridge.new()
	root.add_child(bridge)
	bridge.model_changed.connect(receive)
	bridge.command_failed.connect(func(message: String): host.last_error = message; host.waiting = false)
	host.waiting = true
	bridge.start(profile)
	var deadline := Time.get_ticks_msec() + 30000
	while host.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.model.is_empty(), "real career worker connected")
	if host.model.is_empty(): finish(); return
	await request("new_career", {"mode":"common","club":29})
	var career: Dictionary = host.model.duplicate(true)
	var source: Dictionary = career.get("clubLife", {}).get("press", {})
	check(source.get("conference", {}).get("available", false), "actual conference available")
	var questions: Array = source.get("conference", {}).get("questions", [])
	check(questions.size() >= 2 and questions.size() <= 4, "actual server count is two to four questions")
	if questions.is_empty(): finish(); return
	var saved_path := str(career.get("meta", {}).get("dataDir", profile)).path_join("donnees.json")
	var saved_before := FileAccess.get_file_as_bytes(saved_path)
	check(not saved_before.is_empty(), "actual career persisted before opening room")
	var before := JSON.stringify(career)
	director = StubDirector.new()
	director.app = host
	host.add_child(director)
	view = View.new()
	view.director = director
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(view)
	var metadata := {"meetingId":"test:real-model-press","completed":false,"ackAllowed":false}
	view.update_frame(career, metadata)
	await settle()
	check(director.commands.is_empty() and JSON.stringify(career) == before, "opening press room is pure")
	check(FileAccess.get_file_as_bytes(saved_path) == saved_before, "opening does not write career save")
	check(view.find_child("PressReturn", true, false) == null, "mandatory interview has no premature exit")
	var viewport: SubViewportContainer = view.find_child("ContextualRoomViewport", true, false)
	check(viewport != null and viewport.stretch and viewport.get_child(0).own_world_3d, "native press world and stretched viewport")
	check(view.room != null and view.room.find_child("PressRoomCamera", true, false) != null, "actual 3D press set and camera")
	check(view.room.get_meta("identity").get("name") == G.club_name(career.club), "3D room uses actual active club identity")
	check(view.room.get_meta("primary_color") == Color(G.identity(career.club).get("color", "#596368")), "3D room uses actual club palette")
	var crest := G.crest(career.club, 256)
	var expected_texture: Texture2D = crest.texture if crest is TextureRect else null
	check(view.room.crest_texture == expected_texture, "physical crest uses production resolver or stays blank")
	crest.free()
	var world_id: int = view.room.get_instance_id()
	for resolution in [Vector2i(1280,720), Vector2i(1600,900)]:
		root.size = resolution
		await settle()
		check(root.size == resolution and viewport.size == Vector2(resolution), "exact full viewport at " + str(resolution))
		all_within(view)
		for index in questions.size():
			view._select_question(index)
			await settle()
			var question: Dictionary = questions[index]
			check(view.question_label.text == question.question, "actual question text retained")
			check(view.find_child("PressJournalistName", true, false).text == question.journalist.name, "actual reporter name retained")
			check(view.find_child("PressJournalistSource", true, false).text.contains(question.journalist.outlet), "actual outlet retained")
			var badge := view.find_child("PressJournalistInitials", true, false)
			check(badge.find_children("*", "TextureRect", true, false).is_empty(), "initial badge adds no invented journalist photograph")
			var answers := view.find_child("PressAnswers", true, false).find_children("*", "Button", true, false)
			check(answers.size() == question.answers.size() and answers.size() == 5, "exactly the five authoritative answers")
			for answer: Dictionary in question.answers:
				var button: Button = view.find_child("PressAnswer_" + str(question.id) + "_" + str(answer.id), true, false)
				check(button != null and button.text == answer.text, "permitted answer text and ID retained")
			check(view.find_children("*", "OptionButton", true, false).is_empty(), "no independent tone selector")
		await capture("press-room-" + str(resolution.x))
	view._select_question(0)
	var first: Dictionary = questions[0]
	view._choose_answer(str(first.id), str(first.answers[1].id))
	var selected: Dictionary = view.choices.duplicate(true)
	# Conférence rapide : un clic retient la réponse et affiche la question suivante sans réponse.
	check(view.question_index == 1, "one click answers and shows the next question")
	var question_node: Label = view.question_label
	view.update_frame(career.duplicate(true), metadata)
	check(view.choices == selected and view.question_label == question_node and view.question_index == 1, "snapshot preserves draft and focused question controls")
	check(view.room.get_instance_id() == world_id, "snapshots and question navigation preserve native 3D world")
	check(director.commands.is_empty() and FileAccess.get_file_as_bytes(saved_path) == saved_before, "drafting changes no career facts or save")
	view._publish()
	check(director.commands.is_empty(), "partial answers cannot publish")
	for question: Dictionary in questions: view._choose_answer(str(question.id), str(question.answers[1].id))
	check(not view.publish_button.disabled, "all actual questions enable publication")
	check(view.find_child("PressReturn", true, false) == null, "complete local draft still cannot exit")
	view._publish()
	view._publish()
	check(director.commands.size() == 1, "publication creates exactly one command while waiting")
	var sent: Dictionary = director.commands[0]
	check(sent.command == "press_conference" and sent.payload.context == source.context, "existing command and authoritative context")
	check(source.conference.invitationId is String and sent.payload.get("invitationId")==source.conference.invitationId,"La publication transmet l’invitation obligatoire de la carrière")
	check(sent.payload.answers.size() == questions.size() and not sent.payload.has("tone"), "complete ordered answers and no tone parameter")
	for index in questions.size():
		check(sent.payload.answers[index] == {"questionId":questions[index].id,"answerId":questions[index].answers[1].id}, "actual question order preserved in payload")
	for button in view.find_children("*", "BaseButton", true, false): check(button.disabled, "in-flight request disables repeated input")
	host.waiting = false
	host.last_error = "Refus serveur de la préparation périmée"
	view.update_frame(career, metadata)
	check(view.choices.size() == questions.size() and not view.publish_button.disabled, "server refusal preserves draft and enables retry")
	check(not host.last_error.is_empty(), "component does not erase the director's visible server error")
	# Controlled response fixture: receipt rendering is tested separately from
	# the real domain effects exercised by godot-three-rooms-flow.gd.
	var response := career.duplicate(true)
	var result: Dictionary = response.clubLife.press
	result.conference.available = false
	result.conference.questions = []
	result.conference.reason = "Conférence déjà réalisée cette semaine."
	var metrics: Dictionary = source.metrics.duplicate(true)
	var deltas := {}
	for metric: String in metrics: deltas[metric] = 0
	result.lastOutcome = {"context":source.context.duplicate(true),"before":metrics.duplicate(true),"after":metrics.duplicate(true),"delta":deltas,"exchanges":[]}
	result.history = questions.map(func(question: Dictionary): return {"id":question.id,"season":source.context.season,"week":source.context.week,"club":source.context.club,"question":question.question,"answer":question.answers[1].text,"journalist":question.journalist.duplicate(true)})
	view.update_frame(response, metadata)
	await settle()
	check(view.find_child("PressReturn", true, false) == null, "receipt alone never unlocks an incomplete persisted meeting")
	metadata.completed = true
	view.update_frame(response, metadata)
	await settle()
	var continuation: Button = view.find_child("PressReturn", true, false)
	check(continuation != null and not continuation.disabled, "authoritative completed meeting enables Continue")
	check(view.find_child("PressPublish", true, false) == null, "published conference is read only")
	var count := director.commands.size()
	view._publish()
	check(director.commands.size() == count, "receipt cannot publish a second command")
	all_within(view)
	continuation.pressed.emit()
	check(director.continuations == 1, "Continue uses director's server-validated meeting transition")
	var next_week := career.duplicate(true)
	next_week.clubLife.press.context.week += 1
	var next_context: Dictionary = next_week.clubLife.press.context
	next_week.clubLife.press.conference.invitationId = "press-v1:%d:%d:%d" % [next_context.season,next_context.week,next_context.club]
	metadata.completed = false
	metadata.meetingId = "test:next-week-press"
	view.update_frame(next_week, metadata)
	check(view.choices.is_empty() and view.find_child("PressReturn", true, false) == null, "new context discards old draft and prior completion")
	check(FileAccess.get_file_as_bytes(saved_path) == saved_before, "component fixtures never mutate real worker save")
	finish()

func finish() -> void:
	if is_instance_valid(bridge): bridge.stop()
	if is_instance_valid(host): host.queue_free()
	await settle()
	print("PRESS_ROOM_CHECKS ", JSON.stringify({"checks":checks,"failures":failures,"real_projection":true,"commands_stubbed":true}))
	quit(0 if failures.is_empty() else 1)
