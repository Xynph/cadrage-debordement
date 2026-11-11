extends SceneTree
## Capture d'un match en temps forts (CD_MATCH_TEMPS_FORTS=1) : la vraie interface, le
## vrai moteur, du coup d'envoi au coup de sifflet final. Outil manuel, lancé par
## tests/godot-match-temps-forts-capture.cjs (variables décrites dans ce fichier).
## Le script passe les causeries, relance le match à la mi-temps et après un arrêt sur
## carton, enregistre une image JPEG toutes les N images affichées et écrit report.json.

var app: Control
var proof := OS.get_environment("CD_MATCH_TEMPS_FORTS_PROOF")

func _initialize() -> void:
	call_deferred("run")

func number(name: String, fallback: int) -> int:
	var value := OS.get_environment(name)
	return int(value) if value.is_valid_int() and int(value) >= 0 else fallback

func surface() -> Control:
	var director: Node = app.contextual_director
	return director.view if director.active() and director.kind == "live" else null

func fail(message: String) -> void:
	push_error(message)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	quit(2)

func run() -> void:
	if proof.is_empty() or not proof.is_absolute_path() or DirAccess.make_dir_recursive_absolute(proof) != OK:
		push_error("CD_MATCH_TEMPS_FORTS_PROOF doit désigner un dossier absolu accessible.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Captures impossibles en --headless : lancer avec un affichage (Windows, X11 ou Xvfb).")
		quit(2)
		return
	var parts := OS.get_environment("CD_MATCH_TEMPS_FORTS_SIZE").split("x")
	var size := Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 and int(parts[0]) >= 640 and int(parts[1]) >= 360 else Vector2i(1280, 720)
	var every := maxi(1, number("CD_MATCH_TEMPS_FORTS_EVERY", 5))
	var maximum := maxi(1, number("CD_MATCH_TEMPS_FORTS_MAX", 2400))
	var last_minute := number("CD_MATCH_TEMPS_FORTS_MINUTES", 0)
	Engine.max_fps = 30
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	root.content_scale_size = size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	if not app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_MATCH_TEMPS_FORTS_SAVE"))}):
		fail("Import du match refusé.")
		return
	deadline = Time.get_ticks_msec() + 120000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	for i in 8: await process_frame
	var view := surface()
	if view == null or view.regie == null or not view.temps_forts_actifs():
		fail("Le direct en temps forts ne s'est pas ouvert : " + str(app.last_error))
		return
	var report := {"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"size": [size.x, size.y], "niveau": view.regie.niveau, "horloge": view.regie.horloge, "vitesse": view.regie.vitesse, "every": every,
		"gestes": OS.get_environment("CD_MATCH_GESTES") == "1", "images": [], "suivi": [], "tronque": false}
	var regies: Array = []
	var started := Time.get_ticks_msec()
	var frame := 0
	var hold := 0.0
	var ending := 0.0
	var previous := started
	var limit_ms := number("CD_MATCH_TEMPS_FORTS_LIMITE", 2400) * 1000
	var render_usec := 0
	while true:
		await process_frame
		frame += 1
		var now := Time.get_ticks_msec()
		var delta := (now - previous) / 1000.0
		previous = now
		var live: Dictionary = app.model.live if app.model.get("live") is Dictionary else {}
		view = surface()
		var regie: Node = view.regie if view != null else null
		if regie != null and not regies.has(regie): regies.append(regie)
		var talk: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		var state := "causerie"
		if regie != null: state = ["intermediaire", "temps_fort", "attente"][regie.etat]
		if regie != null and not regie.arret.is_empty(): state = "arret"
		if live.is_empty(): state = "fin"
		# Ce qu'un joueur ferait : passer la causerie, relancer après la mi-temps ou un carton.
		if app.waiting or not str(app.last_error).is_empty(): hold = 0.0
		elif talk is Dictionary:
			hold += delta
			if hold >= 2.0:
				hold = 0.0
				app._command("match_talk_continue", {"key": talk.key, "phase": talk.phase, "skip": true})
		elif regie != null and live.get("paused", false) and not live.get("finished", false) and regie.etat != regie.JEU:
			hold += delta
			if hold >= 3.0:
				hold = 0.0
				app._command("pause", {"paused": false})
		else: hold = 0.0
		var over: bool = live.is_empty() or live.get("finished", false) or (last_minute > 0 and int(live.get("minute", 0)) >= last_minute)
		if over and (regie == null or regie.etat != regie.JEU): ending += delta
		if ending >= 3.0 or now - started > limit_ms: break
		if frame % every != 0: continue
		if report.images.size() >= maximum:
			report.tronque = true
			continue
		var before := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var name := "tf-%05d.jpg" % (report.images.size() + 1)
		if image == null or image.save_jpg(proof.path_join(name), 0.85) != OK:
			fail("Écriture impossible : " + name)
			return
		render_usec += Time.get_ticks_usec() - before
		report.images.append({"file": name, "ms": now - started, "etat": state, "horloge": view.clock.text if view != null else "", "score": view.score.text if view != null else ""})
	for played: Node in regies:
		if is_instance_valid(played): report.suivi.append_array(played.suivi)
	var final_live: Dictionary = app.model.live if app.model.get("live") is Dictionary else {}
	report["score"] = final_live.get("score", [0, 0])
	report["termine"] = final_live.get("finished", false)
	report["minute"] = final_live.get("minute", 0)
	report["temps_forts"] = report.suivi.filter(func(entry: Dictionary): return entry.evenement == "temps_fort" and not entry.get("suite", false)).size()
	report["secondes_en_temps_fort"] = snappedf(report.suivi.reduce(func(total: float, entry: Dictionary): return total + float(entry.get("duree_reelle", 0.0)), 0.0), 0.1)
	report["duree_s"] = snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.1)
	report["images_par_seconde"] = snappedf(report.images.size() / maxf(0.001, report.duree_s), 0.01)
	report["rendu_ms_par_image"] = snappedf(render_usec / 1000.0 / maxi(1, report.images.size()), 0.1)
	var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MATCH_TEMPS_FORTS_CAPTURE ", JSON.stringify({"images": report.images.size(), "secondes": report.duree_s, "temps_forts": report.temps_forts, "driver": report.driver}))
	app.closing = true
	app.bridge.stop()
	quit(0)
