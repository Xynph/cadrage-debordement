extends SceneTree
## Ouverture du jeu (native/godot/intro/) sur le vrai jeu et le vrai moteur.
## CD_INTRO_PHASE = premier (séquence complète, passage par touche, réglage écrit),
## second (même profil : écran titre seul), qa (profil de test sans CD_GODOT_INTRO : aucune introduction)
## ou film (séquence complète sans toucher au clavier, captures à plusieurs instants de chaque carte).
## CD_INTRO_CAPTURES : dossier des captures de chaque carte (facultatif).
## Dans toutes les phases avec introduction, chaque image est contrôlée : jamais les textes de deux cartes à la fois.
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_INTRO_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func until(condition: Callable, limit: float) -> bool:
	var spent := 0.0
	while not condition.call() and spent < limit:
		await process_frame
		spent += 1.0 / 60.0
	return condition.call()

func capture(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(captures)
	image.save_png(captures.path_join(label + ".png"))
	print("CAPTURE ", label, " ", image.get_width(), "x", image.get_height())

func press() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func intro() -> Node:
	return app.get_node_or_null("IntroSequence")

var overlaps := 0
var watched_frames := 0
## Surveille chaque image : textes de la carte qui part et de la carte qui arrive jamais lisibles ensemble.
func watch_overlap() -> void:
	if not process_frame.is_connected(_watch_frame): process_frame.connect(_watch_frame)

func _watch_frame() -> void:
	var sequence := intro() if is_instance_valid(app) else null
	if sequence == null: return
	var a: Control = sequence.previous
	var b: Control = sequence.current
	if is_instance_valid(a) and is_instance_valid(b) and a != b and a.visible:
		watched_frames += 1
		if a.text_alpha() > 0.02 and b.text_alpha() > 0.02: overlaps += 1

## Attend `seconds` secondes de la carte `id` (temps de la carte), puis capture.
func shoot(sequence: Node, id: String, seconds: float, label: String) -> void:
	await until(func(): return sequence.current_id() == id, 30.0)
	await until(func(): return sequence.current.get("_time") != null and float(sequence.current.get("_time")) >= seconds, 30.0)
	await capture(label)

func run() -> void:
	var phase := OS.get_environment("CD_INTRO_PHASE")
	var profile := OS.get_environment("CD_GODOT_DATA_DIR")
	var started := Time.get_ticks_msec()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if phase == "qa":
		check(intro() == null, "Mode QA/test (profil de test, sans CD_GODOT_INTRO) : aucune introduction")
		await until(func(): return not app.waiting, 60.0)
		check(not app.waiting and app.route == "Accueil", "Mode QA : menu principal directement disponible")
	else:
		var sequence := intro()
		check(sequence != null, "Introduction présente au lancement")
		if sequence == null: await finish(); return
		check(sequence.get_node("IntroRoot/IntroGround").color.a == 1.0, "Fond du thème posé dès la première image (pas d'écran noir)")
		watch_overlap()
		if phase == "film":
			for moment in [["presente", 0.35, "v2-1-presente-debut"], ["presente", 1.3, "v2-1-presente-milieu"], ["presente", 2.9, "v2-1-presente-fin"], ["stade", 0.35, "v2-2-stade-fondu"], ["stade", 2.4, "v2-2-stade-milieu"], ["stade", 5.6, "v2-2-stade-fin"], ["titre", 0.45, "v2-3-titre-fondu"], ["titre", 1.4, "v2-3-titre-revelation"]]:
				await shoot(sequence, moment[0], moment[1], moment[2])
			await until(func(): return sequence.engine_ready, 60.0)
			await shoot(sequence, "titre", float(sequence.current._time) + 2.0, "v2-3-titre-pret")
			check(sequence.shown == ["presente", "stade", "titre"], "Film : présente, stade, titre sans toucher au clavier (%s)" % [sequence.shown])
			check(watched_frames > 0 and overlaps == 0, "Fondus : aucun texte de deux cartes visible à la fois (%d images en fondu, %d chevauchements)" % [watched_frames, overlaps])
			await finish(); return
		if phase == "premier":
			check(sequence.mode == "complete" and sequence.first_run, "Premier lancement : séquence complète")
			check(sequence.current_id() == "presente", "Carte 1 : présente")
			await wait(1.2)
			await capture("intro-1-presente")
			check(sequence.current_id() == "presente", "Carte 1 tenue tant qu'on ne la passe pas")
			await wait(0.3)
			await press()
			check(sequence.current_id() == "stade", "Une touche passe à la carte 2 (stade)")
			var stade: Control = sequence.current
			var look: ShaderMaterial = stade.picture.material
			check(look.shader.resource_path.ends_with("canvas_intro_stade.gdshader") and look.get_shader_parameter("image") != null and look.get_shader_parameter("depth_map") != null, "Stade : illustration animée par le shader (image + profondeur), pas la vue 3D du match")
			check(not str(stade.phrase.get("texte", "")).is_empty(), "Phrase d'ambiance tirée de intro.json")
			await wait(2.6)
			await capture("intro-2-stade")
			check(sequence.current_id() == "stade" or sequence.engine_ready, "Carte 2 tenue tant que le moteur démarre")
			await press()
			await until(func(): return sequence.current_id() == "titre", 2.0)
			check(sequence.current_id() == "titre", "Une touche passe à l'écran titre")
			check(sequence.shown == ["presente", "stade", "titre"], "Ordre des cartes : présente, stade, titre (%s)" % [sequence.shown])
			var titre: Control = sequence.current
			check(titre._prompt.text.begins_with("APPUIE"), "Invitation au tutoiement (« Appuie »)")
			check(titre.get_node_or_null("IntroPlan/IntroConseil") == null, "Écran titre épuré : pas de bloc de conseil")
			await wait(1.4)
			if not sequence.engine_ready:
				await capture("intro-3-titre-chargement")
				await press()
				check(is_instance_valid(sequence) and sequence.current_id() == "titre", "Moteur pas prêt : une touche ne quitte pas l'écran titre")
		else:
			check(sequence.mode == "short" and not sequence.first_run, "Deuxième lancement : version courte")
			check(sequence.shown == ["titre"], "Version courte : écran titre seul (%s)" % [sequence.shown])
		await until(func(): return sequence.engine_ready, 60.0)
		check(sequence.engine_ready and not app.waiting, "Moteur prêt pendant l'écran titre")
		await wait(0.9)
		await wait(2.0)
		check(sequence.current.ready_shown and sequence.current._prompt.visible and sequence.current._prompt.modulate.a > 0.3, "Invitation à continuer une fois le moteur prêt et le logo révélé")
		await capture("intro-3-titre-pret" if phase == "premier" else "intro-court-titre")
		var ready_ms := Time.get_ticks_msec() - started
		print("INTRO moteur prêt + titre : %d ms" % ready_ms)
		await wait(0.3)
		await press()
		await wait(0.9)
		check(intro() == null, "Une touche ouvre le menu principal")
		check(overlaps == 0, "Fondus : aucun texte de deux cartes visible à la fois (%d images en fondu, %d chevauchements)" % [watched_frames, overlaps])
		check(app.route == "Accueil" and app.get_node_or_null("IntroSequence") == null, "Menu principal existant affiché")
		await capture("intro-4-menu" if phase == "premier" else "intro-court-menu")
		if phase == "premier":
			var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("PrototypeGodot").path_join("interface.json")))
			check(saved is Dictionary and saved.get("intro") == "short", "Après le premier lancement, le réglage passe à « Courte »")
	finish()

func finish() -> void:
	print("INTRO %d contrôles, %d échecs" % [checks, failures.size()])
	if is_instance_valid(app): app.request_quit()
	await wait(0.5)
	quit(1 if not failures.is_empty() else 0)
