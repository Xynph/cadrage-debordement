extends SceneTree
## Ouverture du jeu (native/godot/intro/) sur le vrai jeu et le vrai moteur.
## CD_INTRO_PHASE = premier (1er lancement : séquence complète, touche sans effet sur les cartes, phrase mémorisée),
## second (même profil : séquence complète, une touche passe chaque carte, autre phrase),
## ancien (profil portant encore intro=short : séquence complète quand même, clé ignorée), court (raccourci de test : titre seul), qa (profil de test sans CD_GODOT_INTRO : aucune introduction)
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
	var memo_path := profile.path_join("PrototypeGodot").path_join("intro-memo.json")
	var earlier: Variant = JSON.parse_string(FileAccess.get_file_as_string(memo_path)) if FileAccess.file_exists(memo_path) else null
	var earlier_phrase := int(earlier.get("derniere_phrase", -1)) if earlier is Dictionary else -1
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
		if phase != "court":
			# Tout premier lancement sans cache : les shaders de Gabi et des cartes se compilaient en plein prologue (9 i/s).
			check(sequence.get_node_or_null("IntroPrechauffage") != null and sequence._warming, "Shaders de Gabi et des cartes préchauffés dès la première image, horloges retenues")
			await until(func(): return not sequence._warming, 5.0)
			check(not sequence._warming and sequence.current.is_processing(), "Préchauffage terminé : carte 1 en marche")
		watch_overlap()
		if phase == "film":
			for moment in [["prologue", 3.2, "v3-1-prologue"], ["stade", 4.5, "v3-2-stade"], ["titre", 2.6, "v3-3-titre-revelation"]]:
				await shoot(sequence, moment[0], moment[1], moment[2])
			await until(func(): return sequence.engine_ready, 60.0)
			await shoot(sequence, "titre", float(sequence.current._time) + 2.0, "v3-3-titre-pret")
			check(sequence.shown == ["prologue", "stade", "titre"], "Film : prologue, stade, titre sans toucher au clavier (%s)" % [sequence.shown])
			check(watched_frames > 0 and overlaps == 0, "Fondus : aucun texte de deux cartes visible à la fois (%d images en fondu, %d chevauchements)" % [watched_frames, overlaps])
			await finish(); return
		if phase != "court":
			check(phase == "premier" or earlier_phrase >= 0, "Deuxième lancement : phrase du premier retrouvée dans le mémo (%d)" % earlier_phrase)
			check(sequence.current_id() == "prologue", "Carte 1 : prologue")
			await wait(1.2)
			await capture("intro-1-prologue")
			# Recette du 17/11 : l'interlettrage entier (Label) avançait par sauts de 12 px, lus comme des FPS faibles.
			# La phrase doit se resserrer à chaque image, sans palier.
			var phrase := sequence.current.find_child("IntroProloguePhrase", true, false) as Control
			var serrages: Array[float] = []
			for i in 6:
				var t: Variant = phrase.get("tracking") if phrase != null else null
				serrages.append(float(t) if t != null else float((phrase.get_meta("variation") as FontVariation).spacing_glyph) if phrase != null and phrase.has_meta("variation") else 0.0)
				await process_frame
			var baisses := 0
			for i in range(1, serrages.size()): if serrages[i] < serrages[i - 1]: baisses += 1
			# La première image après la capture peut ne pas avoir avancé l'horloge : 4 baisses sur 5 au moins.
			check(baisses >= 4, "Prologue : interlettrage resserré à chaque image, sans palier (%s)" % [serrages])
			check(sequence.current_id() == "prologue", "Carte 1 tenue tant qu'on ne la passe pas")
			await wait(0.3)
			await press()
			check(sequence.first_run == (phase == "premier"), "Premier lancement détecté par l'absence de mémo (%s)" % phase)
			if phase == "premier":
				check(sequence.current_id() == "prologue", "1er lancement : une touche ne passe pas la carte 1 (prologue)")
				await until(func(): return sequence.current_id() == "stade", 15.0)
				check(sequence.current_id() == "stade", "1er lancement : le prologue se termine seul, carte 2 (stade)")
			else:
				await until(func(): return sequence.current_id() == "stade", 2.0)
				check(sequence.current_id() == "stade", "Lancements suivants : une touche passe la carte 1 (prologue)")
			var stade: Control = sequence.current
			var look: ShaderMaterial = stade.picture.material
			check(look.shader.resource_path.ends_with("canvas_intro_stade.gdshader") and look.get_shader_parameter("image") != null and look.get_shader_parameter("depth_map") != null, "Stade : illustration animée par le shader (image + profondeur), pas la vue 3D du match")
			check(not str(stade.phrase.get("texte", "")).is_empty(), "Phrase d'ambiance tirée de intro.json")
			var memo: Variant = JSON.parse_string(FileAccess.get_file_as_string(memo_path))
			if phase == "second": check(stade.phrase_index != earlier_phrase, "Deuxième lancement : phrase du stade différente de la première (%d puis %d)" % [earlier_phrase, stade.phrase_index])
			check(memo is Dictionary and int(memo.get("derniere_phrase", -2)) == stade.phrase_index, "Index de la phrase mémorisé dans le profil (%s)" % [memo])
			var raw := FileAccess.get_file_as_string("res://intro/intro.json").to_lower()
			check(not raw.contains("cadrage") and not raw.contains("débordement") and not raw.contains("presente"), "Ouverture : aucun nom d'éditeur abandonné dans intro.json")
			var phrases: Array = sequence.card_data("stade").phrases
			var complete := true
			for entry in phrases: complete = complete and not str(entry.get("texte", "")).is_empty() and not str(entry.get("surtitre", "")).is_empty()
			check(phrases.size() >= 10 and complete, "Phrases d'ambiance : au moins 10, toutes complètes (%d)" % phrases.size())
			var repeats := 0
			var seen := {}
			var previous_index := -1
			var rng := RandomNumberGenerator.new()
			rng.seed = 27
			for _i in 400:
				var drawn: int = sequence.get_script().next_phrase(phrases.size(), previous_index, rng.randf())
				if drawn == previous_index or drawn < 0 or drawn >= phrases.size(): repeats += 1
				seen[drawn] = true
				previous_index = drawn
			for edge in [0.0, 0.999999]:
				for last in phrases.size(): if sequence.get_script().next_phrase(phrases.size(), last, edge) == last: repeats += 1
			check(repeats == 0 and seen.size() == phrases.size(), "Tirage des phrases : jamais deux fois de suite la même, toutes accessibles (%d répétitions, %d/%d vues)" % [repeats, seen.size(), phrases.size()])
			await wait(2.6)
			await capture("intro-2-stade")
			check(sequence.current_id() == "stade" or sequence.engine_ready, "Carte 2 tenue tant que le moteur démarre")
			await press()
			if phase == "premier":
				check(sequence.current_id() == "stade", "1er lancement : une touche ne passe pas la carte 2 (stade)")
				await until(func(): return sequence.current_id() == "titre", 30.0)
				check(sequence.current_id() == "titre", "1er lancement : le stade se termine seul, écran titre")
			else:
				await until(func(): return sequence.current_id() == "titre", 2.0)
				check(sequence.current_id() == "titre", "Lancements suivants : une touche passe la carte 2 (stade)")
			check(sequence.shown == ["prologue", "stade", "titre"], "Ordre des cartes : prologue, stade, titre (%s)" % [sequence.shown])
			var titre: Control = sequence.current
			check(titre._prompt.text.begins_with("APPUIE"), "Invitation au tutoiement (« Appuie »)")
			check(titre.get_node_or_null("IntroPlan/IntroConseil") == null, "Écran titre épuré : pas de bloc de conseil")
			await wait(1.4)
			if not sequence.engine_ready:
				await capture("intro-3-titre-chargement")
				await press()
				check(is_instance_valid(sequence) and sequence.current_id() == "titre", "Moteur pas prêt : une touche ne quitte pas l'écran titre")
		if phase == "court":
			check(sequence.title_only and sequence.shown == ["titre"], "Raccourci de test CD_GODOT_INTRO_MODE=courte : titre seul (%s)" % [sequence.shown])
		await until(func(): return sequence.engine_ready, 60.0)
		check(sequence.engine_ready and not app.waiting, "Moteur prêt pendant l'écran titre")
		await wait(0.9)
		await wait(2.0)
		check(sequence.current.ready_shown and sequence.current._prompt.visible and sequence.current._prompt.modulate.a > 0.3, "Invitation à continuer une fois le moteur prêt et le logo révélé")
		await capture("intro-3-titre-pret" if phase != "ancien" else "intro-court-titre")
		var ready_ms := Time.get_ticks_msec() - started
		print("INTRO moteur prêt + titre : %d ms" % ready_ms)
		await wait(0.3)
		await press()
		await wait(0.9)
		check(intro() == null, "Une touche ouvre le menu principal")
		check(overlaps == 0, "Fondus : aucun texte de deux cartes visible à la fois (%d images en fondu, %d chevauchements)" % [watched_frames, overlaps])
		check(app.route == "Accueil" and app.get_node_or_null("IntroSequence") == null, "Menu principal existant affiché")
		await capture("intro-4-menu" if phase != "ancien" else "intro-court-menu")
		if true:
			var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("PrototypeGodot").path_join("interface.json"))) if FileAccess.file_exists(profile.path_join("PrototypeGodot").path_join("interface.json")) else {}
			check(not (saved is Dictionary and saved.get("intro") == "short" and phase not in ["ancien", "court"]), "Le profil n'est jamais modifié par l'introduction (aucune clé « intro » écrite)")
	finish()

func finish() -> void:
	print("INTRO %d contrôles, %d échecs" % [checks, failures.size()])
	if is_instance_valid(app): app.request_quit()
	await wait(0.5)
	quit(1 if not failures.is_empty() else 0)
