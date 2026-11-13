extends SceneTree

class NativeKeyWitness extends Node:
	var entries: Array[Dictionary] = []
	func _input(event: InputEvent) -> void:
		record_event(event,"scene-input")
	func record_event(event: InputEvent, origin: String) -> void:
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_LEFT, KEY_ALT]:
				entries.append({"origin":origin,"ticks_ms":Time.get_ticks_msec(),"keycode":int(key.keycode),"physical_keycode":int(key.physical_keycode),"pressed":key.pressed,"echo":key.echo,"alt":key.alt_pressed,"device":key.device})

const Club = preload("res://ui/immersive08/club_canvas.gd")
var app: Control
var score: Button
var source_scroll: ScrollContainer
var detail: Window
var witness: NativeKeyWitness
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var checks: int = 0
var requested: int = 0
var started: int = 0
var output: String = OS.get_environment("CD_NATIVE_OS_OUTPUT")
var fixture_id: String = "s1-elite-league-0-0"
var source_sha: String = "37e085b687b4e9a603085beaa50fecf9d6cace22"
var phase: String = "starting"
var finishing: bool = false
var begun_ms: int = 0
var baseline: Dictionary = {}
var provenance: Dictionary = {}
var phase_history: Array[Dictionary] = []
var scroll_before: int = 0
var score_instance: int = 0
var save_path: String = ""
var archive_identity: Dictionary = {}

func _initialize() -> void:
	begun_ms = Time.get_ticks_msec()
	var source_metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("/workspace/work/native-os-input/provenance.json"))
	if source_metadata is Dictionary: provenance = source_metadata
	if output.is_empty(): output = "/workspace/work/native-os-input/evidence"
	DirAccess.make_dir_recursive_absolute(output)
	var watchdog: SceneTreeTimer = create_timer(145.0)
	watchdog.timeout.connect(_on_timeout)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _on_timeout() -> void:
	if finishing: return
	check(false, "Délai interne 145 s atteint en phase " + phase)
	finish()

func settle() -> void:
	for frame: int in 10: await process_frame

func current_snapshot() -> Dictionary:
	var saved: Dictionary = {}
	if not save_path.is_empty() and FileAccess.file_exists(save_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary: saved = parsed
	var focus: Control = root.gui_get_focus_owner()
	return {"profile_sha256":FileAccess.get_sha256(save_path) if not save_path.is_empty() else "", "saved_seed":saved.get("seed"),"saved_clock":saved.get("clock"),"bridge_next_id":int(app.bridge._next_id) if is_instance_valid(app) else -1,"model_sha256":JSON.stringify(app.model).sha256_text() if is_instance_valid(app) else "","route":str(app.route) if is_instance_valid(app) else "","focus_name":str(focus.name) if is_instance_valid(focus) else "","focus_instance":focus.get_instance_id() if is_instance_valid(focus) else 0,"score_instance":score.get_instance_id() if is_instance_valid(score) else 0,"score_focused":score.has_focus() if is_instance_valid(score) else false,"scroll_y":source_scroll.scroll_vertical if is_instance_valid(source_scroll) else -1,"requested":requested,"started":started,"speech_id":int(app.coach.speech._id) if is_instance_valid(app) and is_instance_valid(app.coach) else -1}

func write_phase(next_phase: String) -> void:
	phase = next_phase
	phase_history.append({"phase":phase,"elapsed_ms":Time.get_ticks_msec()-begun_ms})
	var state: Dictionary = {"phase":phase,"source_sha":source_sha,"fixture_id":fixture_id,"elapsed_ms":Time.get_ticks_msec()-begun_ms,"checks":checks,"failures":failures,"baseline":baseline,"provenance":provenance,"archive_identity":archive_identity,"phase_history":phase_history,"current":current_snapshot(),"captures":captures,"native_key_events":witness.entries if is_instance_valid(witness) else []}
	var f: FileAccess = FileAccess.open(output.path_join("state.json"),FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state,"  "))
		f.close()
	print("NATIVE_OS_PHASE ",phase)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	check(picture.get_size()==Vector2i(2560,1440),"Capture native 2560×1440 · " + name)
	var path: String = output.path_join(name+".png")
	check(picture.save_png(path)==OK,"Capture PNG enregistrée · " + name)
	captures.append({"file":path,"sha256":FileAccess.get_sha256(path),"width":picture.get_width(),"height":picture.get_height()})

func check_baseline(label: String) -> void:
	var now: Dictionary = current_snapshot()
	for key: String in ["profile_sha256","saved_seed","saved_clock","bridge_next_id","model_sha256"]:
		check(now.get(key)==baseline.get(key),label+" inchangé · "+key)
	check(requested==0 and started==0 and int(app.coach.speech._id)==0,label+" parole requested/started/id nuls")

func run() -> void:
	root.size = Vector2i(2560,1440)
	DisplayServer.window_set_size(root.size)
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	app = scene.instantiate() as Control
	root.add_child(app)
	witness = NativeKeyWitness.new()
	root.add_child(witness)
	root.window_input.connect(witness.record_event.bind("root-window-input"))
	check(is_instance_valid(app.coach) and is_instance_valid(app.coach.speech),"Gabi réel présent avec signaux observables")
	if not is_instance_valid(app.coach): finish(); return
	app.coach.speech.requested.connect(func(_text: String): requested += 1)
	app.coach.speech.started.connect(func(_id: int): started += 1)
	app.coach.speech.set_muted(true)
	var until_ms: int = Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<until_ms and not finishing:
		await process_frame
	if finishing: return
	check(not app.waiting and not app.model.is_empty(),"Profil public copié chargé sans commande de préparation")
	if app.waiting or app.model.is_empty(): finish(); return
	app.timer.stop()
	app.management_ui[Club.KEY] = "history"
	app._navigate("Club")
	await settle()
	if finishing: return
	score = app.find_child("PerformanceMatchScore_"+fixture_id.validate_node_name(),true,false) as Button
	source_scroll = app.find_child("ClubMemoryScroll",true,false) as ScrollContainer
	check(score!=null and source_scroll!=null,"Vrai score et liste d’archive présents")
	if score==null or source_scroll==null: finish(); return
	var archived: Array = app.model.get("history",[]).filter(func(item: Dictionary) -> bool: return str(item.get("fixtureId",""))==fixture_id)
	var exact_score: bool = false
	archive_identity = {"matching_rows":archived.size()}
	if archived.size()==1:
		var actual_score: Variant = archived[0].get("score")
		archive_identity.score = actual_score
		if actual_score is Array and actual_score.size()==2:
			archive_identity.score_types = [typeof(actual_score[0]),typeof(actual_score[1])]
			if (actual_score[0] is int or actual_score[0] is float) and (actual_score[1] is int or actual_score[1] is float):
				exact_score = actual_score[0]==15 and actual_score[1]==20
	check(archived.size()==1 and exact_score,"Archive réelle unique et score numérique exact 15–20 conservé")
	check(str(score.get_meta("entity_kind",""))=="fixture" and str(score.get_meta("entity_id",""))==fixture_id,"Score cible la fixture exacte")
	score.grab_focus()
	await settle()
	save_path = str(app.model.meta.dataDir).path_join("donnees.json")
	check(FileAccess.file_exists(save_path),"Sauvegarde de la copie présente")
	check(app.route=="Club" and score.has_focus(),"Page source et focus clavier prêts")
	check(not app.navigation_controller._blocked(),"Navigation initiale autorisée")
	baseline = current_snapshot()
	score_instance = score.get_instance_id()
	scroll_before = source_scroll.scroll_vertical
	check_baseline("Baseline")
	await capture("ready-2560")
	write_phase("ready")
	while not finishing:
		detail = app.find_child("CompetitionFixtureDetails",true,false) as Window
		if is_instance_valid(detail) and detail.visible: break
		await process_frame
	if finishing: return
	detail.window_input.connect(witness.record_event.bind("modal-window-input"))
	await settle()
	check(str(detail.get_meta("entity_id",""))==fixture_id,"Return OS ouvre la fixture exacte")
	check(witness.entries.any(func(item: Dictionary) -> bool: return item.pressed and not item.echo and int(item.keycode) in [KEY_ENTER,KEY_KP_ENTER]),"Événement Return observé depuis le viewport natif")
	check_baseline("Après Return")
	await capture("modal-2560")
	write_phase("modal")
	while not finishing and is_instance_valid(detail) and detail.visible: await process_frame
	if finishing: return
	await settle()
	check(not is_instance_valid(detail) or not detail.visible,"Alt+Left OS ferme ou masque le lecteur")
	check(not app.navigation_controller._blocked(),"Garde libérée après Back OS")
	check(app.route=="Club" and app.management_ui.get(Club.KEY,"")=="history","Même page Club/Histoire après Back")
	check(is_instance_valid(score) and score.get_instance_id()==score_instance and score.is_visible_in_tree() and score.has_focus(),"Même score source et focus restitué")
	check(is_instance_valid(source_scroll) and source_scroll.scroll_vertical==scroll_before,"Défilement exact de la source conservé")
	check(witness.entries.any(func(item: Dictionary) -> bool: return item.pressed and not item.echo and int(item.keycode)==KEY_LEFT and item.alt),"Événement Alt+Left observé depuis le viewport natif")
	check_baseline("Après Back")
	await capture("returned-2560")
	write_phase("returned")
	finish()

func finish() -> void:
	if finishing: return
	finishing = true
	check(captures.size()==3,"Trois captures natives réellement obtenues")
	if is_instance_valid(app) and not baseline.is_empty(): check_baseline("Clôture")
	write_phase("finished" if failures.is_empty() else "failed")
	var report: Dictionary = {"source_sha":source_sha,"fixture_id":fixture_id,"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-begun_ms,"baseline":baseline,"after":current_snapshot(),"provenance":provenance,"archive_identity":archive_identity,"phase_history":phase_history,"captures":captures,"native_key_events":witness.entries if is_instance_valid(witness) else [],"input_source":"X11 events supplied externally; this probe never injects inputs or calls navigation history directly.","sdk_launched_by":"root only"}
	var f: FileAccess = FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f!=null:
		f.store_string(JSON.stringify(report,"  "))
		f.close()
	if is_instance_valid(app): app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
