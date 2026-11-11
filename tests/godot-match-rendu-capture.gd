extends SceneTree
## Une passe de capture du rendu du match (outil manuel, non lancé par la CI).
## Piloté par tests/godot-match-rendu-capture.cjs, qui lance une passe par
## rendu (actuel / moderne), niveau, ambiance, caméra et taille.
##
## Rejoue dans la vraie vue de match la séquence du moteur
## (tests/fixtures/match-gestes-sequence.json : touche, ballon porté, essai), au
## rythme du direct comme tests/godot-match-gestes-capture.gd, gestes activés.
## L'image est rendue dans un SubViewport de taille exacte (indépendante de
## l'écran), avec le MSAA 2x du jeu, puis enregistrée en JPEG numérotés.
##
## Variables (toutes fournies par le script node) :
##   CD_MATCH_RENDU_SORTIE   dossier absolu de la passe (images + report.json)
##   CD_MATCH_RENDU_SEQUENCE chemin absolu de la séquence du moteur
##   CD_MATCH_RENDU_ATTENDU  méthode de rendu exigée (gl_compatibility ou forward_plus)
##   CD_MATCH_RENDU_PASSE    nom de la passe (rapport)
##   CD_MATCH_RENDU_TAILLE   « 1280x720 »
##   CD_MATCH_RENDU_CAMERA   tv | action | tactical
##   CD_MATCH_RENDU_QUALITE  economy | balanced | detail
##   CD_MATCH_RENDU_AMBIANCE jour | soir
##   CD_MATCH_RENDU_EVERY    une image toutes les N images simulées (3 = 10 par seconde)
##   CD_MATCH_RENDU_MESURE   images rendues sans relecture pour la mesure finale (120)
##   CD_MATCH_RENDU_CONTINU  1 (défaut) : chaque pas simulé est rendu, comme en jeu,
##                           ce qui rend fiable le temps GPU par image ; 0 : seules
##                           les images enregistrées sont rendues (machine lente)

const View = preload("res://match_view.gd")
const Rendu = preload("res://match_rendu.gd")
const STEP := 1.0 / 30.0
const TICK := 0.32

var report := {}
var proof := ""


func _initialize() -> void:
	call_deferred("run")


func fail(code: int, message: String) -> void:
	push_error(message)
	print("MATCH_RENDU_ECHEC ", message)
	report["erreur"] = message
	if not proof.is_empty():
		var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	quit(code)


func stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {"n": sorted.size(), "moyenne": snappedf(total / sorted.size(), 0.001),
		"mediane": snappedf(sorted[sorted.size() / 2], 0.001),
		"p95": snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], 0.001),
		"max": snappedf(sorted[-1], 0.001)}


func _sample(rid: RID, gpu: Array[float], cpu: Array[float]) -> void:
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	if gpu_ms > 0.0:
		gpu.append(gpu_ms)
	if cpu_ms > 0.0:
		cpu.append(cpu_ms)


func env(name: String, fallback: String) -> String:
	var value := OS.get_environment(name)
	return value if not value.is_empty() else fallback


func run() -> void:
	proof = OS.get_environment("CD_MATCH_RENDU_SORTIE")
	if proof.is_empty() or not proof.is_absolute_path() or DirAccess.make_dir_recursive_absolute(proof) != OK:
		proof = ""
		fail(2, "CD_MATCH_RENDU_SORTIE doit désigner un dossier absolu accessible.")
		return
	var method := RenderingServer.get_current_rendering_method()
	var expected := env("CD_MATCH_RENDU_ATTENDU", method)
	var parts := env("CD_MATCH_RENDU_TAILLE", "1280x720").split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var camera := env("CD_MATCH_RENDU_CAMERA", "tv")
	var quality := env("CD_MATCH_RENDU_QUALITE", "balanced")
	var ambiance := env("CD_MATCH_RENDU_AMBIANCE", "jour")
	var every := maxi(1, int(env("CD_MATCH_RENDU_EVERY", "3")))
	var measure := maxi(0, int(env("CD_MATCH_RENDU_MESURE", "120")))
	var continuous := env("CD_MATCH_RENDU_CONTINU", "1") != "0"
	report = {"passe": env("CD_MATCH_RENDU_PASSE", ""), "methode_rendu": method, "methode_attendue": expected,
		"pilote": RenderingServer.get_current_rendering_driver_name(), "carte": RenderingServer.get_video_adapter_name(),
		"fabricant": RenderingServer.get_video_adapter_vendor(), "api": RenderingServer.get_video_adapter_api_version(),
		"godot": Engine.get_version_info().string, "systeme": OS.get_name(), "affichage": DisplayServer.get_name(),
		"taille": [size.x, size.y], "camera": camera, "qualite": quality, "ambiance": ambiance,
		"cd_match_rendu": Rendu.choix(), "images": [], "scenes": []}
	if DisplayServer.get_name() == "headless":
		fail(2, "Captures impossibles en --headless : lancer avec un affichage.")
		return
	if method != expected:
		fail(3, "Méthode de rendu active « %s » au lieu de « %s » (pilote %s, carte %s) : %s" % [method, expected,
			report.pilote, report.carte, "Forward+ n'a pas pu s'activer." if expected == "forward_plus" else "rendu inattendu."])
		return
	var source := FileAccess.get_file_as_string(OS.get_environment("CD_MATCH_RENDU_SEQUENCE"))
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary or not parsed.get("frames") is Array:
		fail(2, "Séquence du moteur illisible (CD_MATCH_RENDU_SEQUENCE).")
		return
	var frames: Array = parsed.frames
	report["club"] = parsed.get("club")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.title = "Rendu du match · " + str(report.passe)
	# Rendu hors écran à taille exacte, réglé comme dans le jeu (MSAA 2x, monde propre).
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view: NativeMatchView = View.new()
	view.set_quality(quality)
	view.set_stadium_evening(ambiance == "soir")
	viewport.add_child(view)
	view.set_process(false)
	view.set_gestes(true)
	view.set_camera(camera)
	view.set_live_cadence(1)
	var rendu: RefCounted = view._rendu
	report["rendu_moderne_actif"] = rendu != null
	report["reglages_modernes"] = Rendu.reglages(quality) if rendu else {}
	report["msaa_3d"] = viewport.msaa_3d
	if expected == "forward_plus" and Rendu.choix() != "actuel" and rendu == null:
		fail(3, "Forward+ actif mais le rendu moderne ne s'est pas installé.")
		return
	var rid := viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var events: Array = []
	var index := 0
	var since := TICK
	var clock := 0.0
	var step := 0
	var tail := 0.0
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var started := Time.get_ticks_msec()
	while tail < 1.2 and clock < 60.0:
		since += STEP
		if index < frames.size() and since >= TICK and not view.is_presenting_extended_pass():
			var frame: Dictionary = frames[index]
			events.append_array(frame.events)
			view.apply_frame({"scene": frame.scene, "teams": frame.teams, "events": events, "paused": false})
			report.scenes.append({"time": snappedf(clock, 0.01), "kind": frame.scene.kind})
			index += 1
			since = 0.0
		if index >= frames.size() and not view.is_presenting_extended_pass():
			tail += STEP
		view._process(STEP)
		clock += STEP
		step += 1
		if step % every != 0:
			if continuous:
				await RenderingServer.frame_post_draw
				_sample(rid, gpu, cpu)
			continue
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image == null or image.get_size() != size:
			fail(1, "Image de taille inattendue : %s au lieu de %s." % [str(image.get_size()) if image else "aucune", str(size)])
			return
		var name := "%04d.jpg" % (step / every)
		if image.save_jpg(proof.path_join(name), 0.9) != OK:
			fail(1, "Écriture impossible : " + name)
			return
		var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(rid)
		_sample(rid, gpu, cpu)
		var gestes: RefCounted = view._gestes
		report.images.append({"fichier": name, "temps": snappedf(clock, 0.01), "phase": str(gestes.phase) if gestes else "",
			"gpu_ms": snappedf(gpu_ms, 0.001), "cpu_ms": snappedf(cpu_ms, 0.001)})
	report["secondes_simulees"] = snappedf(clock, 0.01)
	report["duree_ms"] = Time.get_ticks_msec() - started
	report["rendu_continu"] = continuous
	# Temps mesurés par le RenderingServer pour ce SubViewport (les premières
	# images, encore sans mesure, valent 0 et sont écartées).
	report["rendu_gpu_ms_par_image"] = stats(gpu)
	report["rendu_cpu_ms_par_image"] = stats(cpu)
	# Mesure à vide sur la dernière image (sans relecture ni encodage JPEG).
	var still_gpu: Array[float] = []
	var still_cpu: Array[float] = []
	var still_frame: Array[float] = []
	for warmup in mini(measure, 30):
		await RenderingServer.frame_post_draw
	var previous := Time.get_ticks_usec()
	for sample in measure:
		view._process(STEP)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		still_frame.append((now - previous) / 1000.0)
		previous = now
		_sample(rid, still_gpu, still_cpu)
	report["mesure_sans_capture"] = {"gpu_ms": stats(still_gpu), "cpu_ms": stats(still_cpu), "image_ms": stats(still_frame),
		"appels_de_dessin": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"memoire_video_mo": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)}
	var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		fail(1, "Écriture du rapport impossible.")
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MATCH_RENDU_CAPTURE ", JSON.stringify({"passe": report.passe, "images": report.images.size(),
		"methode": method, "pilote": report.pilote, "gpu_ms": report.rendu_gpu_ms_par_image.get("mediane", 0)}))
	quit(0)
