extends SceneTree
## Captures des gestes de rugby (touche portée, ballon porté, essai aplati).
## Outil manuel, non lancé par la CI : il rejoue dans la vraie vue de match la
## séquence extraite du moteur par tests/godot-match-gestes-scenes.cjs
## (tests/fixtures/match-gestes-sequence.json), au rythme du direct : une scène
## toutes les 0,32 s, suspendue tant que la vue présente un geste.
##
##   godot --path native/godot --script ../../tests/godot-match-gestes-capture.gd
##   CD_MATCH_GESTES_PROOF  : dossier absolu des images et de report.json (requis)
##   CD_MATCH_GESTES_SIZE   : "1280x720" par défaut
##   CD_MATCH_GESTES_CAMERA : "action" (défaut), "tv" ou "tactical"
##   CD_MATCH_GESTES_EVERY  : une image enregistrée toutes les N images simulées (3 par défaut, soit 10 par seconde)
##   CD_MATCH_GESTES_ZOOM   : hauteur visible en mètres (outil de contrôle, pas un réglage du jeu)
##   CD_MATCH_GESTES_OFF=1  : même séquence sans les gestes, pour comparer

const View = preload("res://match_view.gd")
const STEP := 1.0 / 30.0
const TICK := 0.32

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var proof := OS.get_environment("CD_MATCH_GESTES_PROOF")
	if proof.is_empty() or not proof.is_absolute_path() or DirAccess.make_dir_recursive_absolute(proof) != OK:
		push_error("CD_MATCH_GESTES_PROOF doit désigner un dossier absolu accessible.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Captures impossibles en --headless : lancer avec un affichage (Windows, X11 ou Xvfb).")
		quit(2)
		return
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/fixtures/match-gestes-sequence.json"))
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary or not parsed.get("frames") is Array:
		push_error("Séquence du moteur illisible.")
		quit(2)
		return
	var frames: Array = parsed.frames
	var size_text := OS.get_environment("CD_MATCH_GESTES_SIZE")
	var parts := (size_text if not size_text.is_empty() else "1280x720").split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var every := maxi(1, int(OS.get_environment("CD_MATCH_GESTES_EVERY")) if not OS.get_environment("CD_MATCH_GESTES_EVERY").is_empty() else 3)
	var zoom := float(OS.get_environment("CD_MATCH_GESTES_ZOOM"))
	root.title = "Gestes de rugby"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	root.content_scale_size = size
	var view: NativeMatchView = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(OS.get_environment("CD_MATCH_GESTES_OFF") != "1")
	var camera := OS.get_environment("CD_MATCH_GESTES_CAMERA")
	view.set_camera(camera if not camera.is_empty() else "action")
	view.set_live_cadence(1)
	var events: Array = []
	var index := 0
	var since := TICK
	var clock := 0.0
	var step := 0
	var tail := 0.0
	var report := {"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"size": [size.x, size.y], "club": parsed.get("club"), "images": [], "scenes": []}
	var started := Time.get_ticks_msec()
	var render_usec := 0
	while tail < 1.2 and clock < 40.0:
		since += STEP
		if index < frames.size() and since >= TICK and not view.is_presenting_extended_pass():
			var frame: Dictionary = frames[index]
			events.append_array(frame.events)
			view.apply_frame({"scene": frame.scene, "teams": frame.teams, "events": events, "paused": false})
			report.scenes.append({"time": snappedf(clock, 0.01), "kind": frame.scene.kind, "text": frame.events[0].text if not frame.events.is_empty() else ""})
			print("SCENE ", snappedf(clock, 0.01), " ", frame.scene.kind)
			index += 1
			since = 0.0
		if index >= frames.size() and not view.is_presenting_extended_pass():
			tail += STEP
		view._process(STEP)
		if zoom > 0.0:
			view._camera.size = zoom
		clock += STEP
		step += 1
		if step % every != 0:
			continue
		var before := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		render_usec += Time.get_ticks_usec() - before
		var image := root.get_texture().get_image()
		var gestes: RefCounted = view._gestes
		var phase := str(gestes.phase) if gestes else ""
		var name := "g-%04d.jpg" % (step / every)
		if image.save_jpg(proof.path_join(name), 0.86) != OK:
			push_error("Écriture impossible : " + name)
			quit(1)
			return
		report.images.append({"file": name, "time": snappedf(clock, 0.01), "phase": phase, "phase_time": snappedf(float(gestes.time), 0.01) if gestes else 0.0})
	report["seconds_simulated"] = snappedf(clock, 0.01)
	report["wall_ms"] = Time.get_ticks_msec() - started
	report["render_ms_per_image"] = snappedf(render_usec / 1000.0 / maxi(1, report.images.size()), 0.1)
	var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MATCH_GESTES_CAPTURE ", JSON.stringify({"images": report.images.size(), "seconds": report.seconds_simulated, "driver": report.driver}))
	quit(0)
