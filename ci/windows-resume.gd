extends SceneTree
# External QA main loop loaded by the actual exported EXE, never by an editor.
# Initial export is pure. The save probe and mandatory meetings are declared
# separately before real navigation and native viewport captures.
var app: Control
var failures: Array[String] = []
var checks := 0
var output := OS.get_environment("CD_GODOT_RESUME_OUTPUT")
var profile := OS.get_environment("CD_GODOT_DATA_DIR")
var engine_pid := -1
var events := {"starts":0,"ends":0}
var report := {"mode":"resume","before":{},"first_mutations":[],"mandatory_meetings":[],"graphics":{"passed":false,"window":[],"captures":[]}}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func wait_ready() -> bool:
	var deadline := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	app.timer.stop()
	var ok: bool = not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok
	check(ok, "Actual packaged worker responds: " + app.last_error)
	return ok

func ask(command: String, payload: Dictionary = {}, mutation := false) -> bool:
	if mutation: report.first_mutations.append({"command":command,"payload":payload.duplicate(true)})
	check(app._command(command, payload), "Public command accepted: " + command)
	return await wait_ready()

func citations(state: Dictionary) -> Dictionary:
	var result := {}
	for key: String in ["pressConference","pressPeople","pressRelations"]:
		if state.has(key): result[key] = state[key]
	return result

func meeting_check(ok: bool, message: String) -> void:
	check(ok, message)
	var prefix := "Préparation explicite du rendez-vous : "
	if message.begins_with(prefix):
		report.first_mutations.append({"command":message.trim_prefix(prefix),"via":"qa_runner.settle_club_meetings","accepted":ok})

func resize_native() -> void:
	# Normal application windows maximize themselves. Fixed-size QA deliberately
	# detaches only those window callbacks; all production UI/layout still runs.
	var maximize := Callable(app, "_keep_filled_display")
	for signal_: Signal in [root.size_changed, root.focus_entered]:
		if signal_.is_connected(maximize): signal_.disconnect(maximize)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await create_timer(0.3).timeout
	root.size = Vector2i(2560,1440)
	DisplayServer.window_set_size(Vector2i(2560,1440))
	await create_timer(0.5).timeout
	for frame in 8: await process_frame
	check(root.size == Vector2i(2560,1440) and DisplayServer.window_get_size() == root.size, "Real native window is 2560x1440")
	report.graphics.window = [root.size.x, root.size.y]
	report.graphics.window_policy = "Fixed QA window; normal maximization callbacks detached after loading"

func capture(name_: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(2560,1440), "Native capture dimensions: " + name_)
	if image == null: return
	var sum := 0.0
	var squares := 0.0
	var count := 0
	for y in range(0,image.get_height(),17):
		for x in range(0,image.get_width(),19):
			var color := image.get_pixel(x,y)
			var value := (color.r + color.g + color.b) * 85.0
			sum += value
			squares += value * value
			count += 1
	var variance: float = squares / maxi(1,count) - pow(sum / maxi(1,count),2)
	check(variance > 2.0, "Capture contains rendered detail: " + name_)
	var path := output.path_join(name_ + ".png")
	check(image.save_png(path) == OK, "Saved actual capture: " + name_)
	report.graphics.captures.append({"path":path,"sha256":FileAccess.get_sha256(path),"width":image.get_width(),"height":image.get_height(),"variance":variance})

func runtime_information() -> void:
	var details := {"platform":OS.get_name(),"executable":OS.get_executable_path(),"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"audio_driver":AudioServer.get_driver_name(),"pid":OS.get_process_id(),"engine_pid":engine_pid,"data_dir":profile}
	report.runtime_info = details
	var dialog := AcceptDialog.new()
	dialog.title = "Runtime info · Windows package QA"
	var label := Label.new()
	label.text = JSON.stringify(details,"  ")
	label.add_theme_font_size_override("font_size",23)
	dialog.add_child(label)
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(1800,1100))
	await capture("05-runtime-info-2560")
	dialog.hide()
	dialog.queue_free()

func run() -> void:
	check(OS.get_environment("CD_GODOT_SELF_TEST") == "0", "Fresh self-test is disabled during resume")
	check(OS.get_name() == "Windows" and not OS.has_feature("editor"), "The real exported Windows EXE owns resume")
	check(profile.is_absolute_path() and output.is_absolute_path(), "Explicit external QA profile/output required")
	check(DisplayServer.get_name() == "Windows", "Native Windows graphics required; headless is not graphical proof")
	if not failures.is_empty(): await finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	var file := profile.path_join("donnees.json")
	check(FileAccess.file_exists(file), "Fresh run produced an existing profile")
	if not failures.is_empty(): await finish(); return
	var original_bytes := FileAccess.get_file_as_bytes(file)
	var original_hash := FileAccess.get_sha256(file)
	var stored: Variant = JSON.parse_string(original_bytes.get_string_from_utf8())
	check(stored is Dictionary and stored.get("store",{}).get("bdt-v1") is String and stored.has("seed"), "Valid persisted career and RNG")
	if not failures.is_empty(): await finish(); return
	var original_state: Dictionary = JSON.parse_string(stored.store["bdt-v1"])
	check(int(original_state.get("season",0)) >= 2, "Fresh receipt reached season two")
	var fresh_file := OS.get_environment("CD_GODOT_FRESH_REPORT")
	check(fresh_file.is_absolute_path() and FileAccess.file_exists(fresh_file), "Exact fresh receipt supplied for literal quote comparison")
	if not failures.is_empty(): await finish(); return
	var fresh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fresh_file))
	var literals: Array = fresh.get("press_literals",[])
	check(literals.size() >= 2, "Fresh run contains nonempty selected literal statements")
	var press_matches := literals.size() >= 2
	var qa_script: Script = load("res://qa_runner.gd")
	for proof: Dictionary in literals:
		var actual: Dictionary = qa_script._find_literal(original_state.get("pressConference",{}).get("history",[]), proof.expected)
		press_matches = press_matches and actual == proof.expected and actual == proof.archived
	check(press_matches, "Restart preserves the exact selected question, answer, journalist and context")
	var scene: PackedScene = load("res://main.tscn")
	check(scene != null, "Packaged main.tscn loads from the exported resources")
	if scene == null: await finish(); return
	app = scene.instantiate()
	root.add_child(app)
	current_scene = app
	check(is_instance_valid(app.coach) and is_instance_valid(app.coach.speech), "Real visual Gabi exists")
	if is_instance_valid(app.coach) and is_instance_valid(app.coach.speech):
		app.coach.speech.started.connect(func(_id: int): events.starts += 1)
		app.coach.speech.ended.connect(func(_id: int): events.ends += 1)
		check(app.coach.speech.player == null and app.coach.speech.voices.is_empty(), "No Gabi audio player or system voice allocated")
	if not await wait_ready(): await finish(); return
	engine_pid = app.bridge.child_pid
	if not await ask("export"): await finish(); return
	var exported: Dictionary = JSON.parse_string(app.model.meta.exportText)
	var after_read: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	report.before = {"state_matches":exported.get("state") == original_state,"citations_match":citations(exported.get("state",{})) == citations(original_state),"profile_bytes_match":FileAccess.get_file_as_bytes(file) == original_bytes,"rng_file_unchanged":after_read.get("seed") == stored.seed,"seed_loaded":stored.seed,"clock_loaded":stored.get("clock"),"profile_sha256_loaded":original_hash}
	report.before.citations_sha256_loaded = JSON.stringify(citations(original_state)).sha256_text()
	report.before.citations_sha256_exported = JSON.stringify(citations(exported.get("state",{}))).sha256_text()
	report.before.press_literals_match = press_matches
	check(report.before.state_matches and report.before.citations_match and report.before.profile_bytes_match and report.before.rng_file_unchanged, "Pure loaded state, citations, profile bytes and durable RNG match before mutations")
	if not failures.is_empty(): await finish(); return
	# First declared mutation: persist the live runtime cursor after the pure
	# comparison, without inventing private RNG visibility in export/snapshot.
	if not await ask("save",{},true): await finish(); return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	report.save_probe = {"rng_matches_loaded":saved.get("seed") == stored.seed,"seed_saved":saved.get("seed"),"clock_after":saved.get("clock"),"state_matches":JSON.parse_string(saved.store["bdt-v1"]) == original_state,"profile_sha256_after":FileAccess.get_sha256(file)}
	check(report.save_probe.rng_matches_loaded and report.save_probe.state_matches, "Declared save probe preserves runtime RNG and loaded simulation; clock recorded separately")
	if not failures.is_empty(): await finish(); return
	var meetings: Dictionary = app.model.get("clubLife",{}).get("clubMeetings",{})
	if meetings.get("scene") is Dictionary: report.mandatory_meetings.append(meetings.scene.duplicate(true))
	for queued: Dictionary in meetings.get("queue",[]): report.mandatory_meetings.append(queued.duplicate(true))
	var qa: Script = load("res://qa_runner.gd")
	if not await qa.settle_club_meetings(app,self,meeting_check): await finish(); return
	await resize_native()
	for pair: Array in [["Réception","01-reception-2560"],["Effectif","02-effectif-2560"],["Calendrier","03-calendrier-2560"],["Finances","04-finances-2560"]]:
		app._navigate(pair[0])
		check(app.route == pair[0], "Actual navigation reaches " + pair[0])
		await capture(pair[1])
	await runtime_information()
	report.graphics.passed = failures.is_empty()
	await finish()

func finish() -> void:
	var player_present := false
	if is_instance_valid(app):
		app.closing = true
		app.timer.stop()
		if is_instance_valid(app.coach) and is_instance_valid(app.coach.speech):
			player_present = is_instance_valid(app.coach.speech.player)
			check(not player_present and not app.coach.speech.speaking and events.starts == 0 and events.ends == 0, "Gabi remains silent with no allocated player")
			app.coach.destroy()
			await process_frame
			check(events.starts == 0 and events.ends == 0, "Gabi produces no voice event during destruction")
		if is_instance_valid(app.soundscape): app.soundscape.dispose()
		app.bridge.stop()
		var deadline := Time.get_ticks_msec() + 5000
		while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
		check(app.bridge.child_pid <= 0, "Owned packaged Node shut down")
	report.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures,"platform":OS.get_name(),"native_display":DisplayServer.get_name(),"audio_driver":AudioServer.get_driver_name(),"executable":OS.get_executable_path(),"pid":OS.get_process_id(),"engine_pid":engine_pid,"data_dir":profile,"season":app.model.get("meta",{}).get("season",0) if is_instance_valid(app) else 0,"coach":{"starts":events.starts,"ends":events.ends,"voice_available":false,"player_present":player_present}},true)
	if output.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(output)
		var handle := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		if handle != null: handle.store_string(JSON.stringify(report,"\t")); handle.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
