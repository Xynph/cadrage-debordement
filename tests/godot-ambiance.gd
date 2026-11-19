extends SceneTree
## Ambiance sonore : bus Interface et Stade, sons de match, foule selon le camp qui marque.
## Captures (rendu graphique, vrai jeu) : CD_AMBIANCE_CAPTURE=<dossier> ; l'onglet Son des paramètres est photographié.
## Sans la variable, rien ne change.

var failures: Array[String] = []
var checks := 0
var proof := OS.get_environment("CD_AMBIANCE_PROOF")
var moods: Array[String] = []
var cues: Array[String] = []

var capture_dir := OS.get_environment("CD_AMBIANCE_CAPTURE")

func _initialize() -> void:
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		call_deferred("run_capture")
		return
	call_deferred("run")

func settle(frames: int = 12) -> void:
	await create_timer(.4).timeout
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle(16)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)

func run_capture() -> void:
	create_timer(300.0).timeout.connect(func():
		printerr("FAIL: délai dépassé (300 s)")
		quit(1))
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(root.size)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await settle()
	check(not app.model.is_empty(), "Jeu chargé (accueil sans carrière)")
	check(app.soundscape != null and app.soundscape_ready, "Gestionnaire sonore prêt")
	app.preferences_window()
	await settle(24)
	var dialog: AcceptDialog = app.find_child("PreferencesDialog", true, false)
	check(dialog != null, "Paramètres ouverts")
	if dialog != null:
		var tabs: TabContainer = dialog.find_child("PreferencesTabs", true, false)
		tabs.current_tab = 1
		await settle(12)
		var match_sounds := dialog.find_child("PreferencesMatchSounds", true, false) as CheckBox
		check(match_sounds != null or dialog.find_child("PreferencesInterfaceVolume", true, false) != null, "Réglages sonores présents")
		await capture("parametres-audio")
		tabs.current_tab = tabs.get_tab_count() - 1
		await settle(12)
		check(dialog.find_child("PreferencesShortcuts", true, false) != null, "Onglet Raccourcis clavier présent")
		await capture("parametres-raccourcis")
	print("AMBIANCE CAPTURES : %d vérifications, %d échec(s)" % [checks, failures.size()])
	app.closing = true
	app.bridge.stop()
	quit(1 if not failures.is_empty() else 0)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()

## Horloge de jeu injectée dans la régie : l'anti-rebond ne dépend plus du temps réel.
var clock_ms := [0]

func advance_ms(ms: int) -> void:
	clock_ms[0] += ms

func run() -> void:
	var directory := proof.path_join("profil")
	DirAccess.make_dir_recursive_absolute(directory)
	# Ancien fichier d'avant l'abandon de la musique : les champs de musique sont ignorés.
	write(directory.path_join("sound.json"), '{"version":1,"interface_volume":35,"stadium_volume":25,"music_volume":30,"music_on":true,"music_in_match":false,"match_sounds":true}')
	var app := Control.new()
	root.add_child(app)
	var audio = load("res://audio/soundscape.gd").new()
	app.add_child(audio)
	check(audio.setup(app), "Setup du gestionnaire sonore")
	check(audio.load_profile(directory) and audio.preferences.data == {"version": 1, "interface_volume": 35, "stadium_volume": 25, "match_sounds": true}, "Ancien sound.json avec champs de musique accepté, champs ignorés")
	var master := AudioServer.get_bus_index("Master")
	for label in ["Interface", "Stade"]:
		var index := AudioServer.get_bus_index(label)
		check(index > 0 and AudioServer.get_bus_send(index) == "Master", "Bus " + label + " présent, enfant de Master")
	check(AudioServer.get_bus_index("Musique") < 0, "Aucun bus Musique")
	check(not audio.preferences.set_value("music_volume", 45) and not audio.preferences.set_value("music_on", true), "Les réglages de musique n'existent plus")
	audio.last_error = ""
	check(audio.preferences.set_value("stadium_volume", 25) and not FileAccess.get_file_as_string(directory.path_join("sound.json")).contains("music"), "Réécriture : plus aucun champ de musique")

	# Cases à cocher.
	var prefs = audio.preferences
	check(prefs.get_flag("match_sounds"), "Valeur par défaut : sons de match oui")
	check(not prefs.set_value("match_sounds", "oui") and not prefs.set_value("match_sounds", 1), "Une case n'accepte qu'un oui ou non")
	audio.last_error = ""
	audio.refresh_visibility("Match", true)
	# Sons de match.
	audio.set_presenting(true)
	advance_ms(450)
	check(prefs.set_value("match_sounds", false) and not audio._bed.playing and not audio._reaction.playing, "Décocher « Sons de match » coupe l'ambiance du stade")
	check(not audio.play_shown("try", 0) and not audio.play_shown("penalty", 1), "Sons de match décochés : ni foule ni sifflets")
	audio.refresh_visibility("Bureau", false)
	audio.set_presenting(false)
	check(prefs.set_value("match_sounds", true), "Sons de match recochés")
	# La case survit à un rechargement.
	var reloaded = load("res://audio/sound_preferences.gd").new()
	check(reloaded.load_profile(directory) and reloaded.get_flag("match_sounds"), "Case relue au redémarrage")

	# Foule : camp domicile = 0.
	audio.cue_played.connect(func(id: String): cues.append(id))
	audio.crowd_mood.connect(func(mood: String): moods.append(mood))
	check(audio._crowd_cue("try", 0) == {"id": "stadium-try", "mood": "joie"}, "Essai à domicile : montée")
	check(audio._crowd_cue("try", 1) == {"id": "stadium-try", "mood": "deception"}, "Essai adverse : déception")
	check(audio._crowd_cue("penalty", 1) == {"id": "crowd-whistle", "mood": "sifflets"}, "Pénalité accordée à l'extérieur : sifflets")
	check(audio._crowd_cue("penalty", 0).is_empty() and audio._crowd_cue("scrum", 1).is_empty(), "Pénalité pour le domicile ou autre fait : rien")
	audio.game_clock = func(): return clock_ms[0]
	audio.refresh_visibility("Match", true)
	audio.set_presenting(true)
	advance_ms(450)
	# Règle d'anti-rebond (350 ms de jeu) : la plus importante gagne, un rejet ne décale pas le repère.
	check(audio.play_shown("penalty", 1), "Sifflets joués")
	advance_ms(100)
	check(audio.play_shown("try", 0) and moods.back() == "joie", "Essai à 100 ms des sifflets : l'essai prend le dessus")
	advance_ms(100)
	check(not audio.play_shown("penalty", 1) and not audio.play_shown("try", 1), "Sifflets ou même importance dans la fenêtre : ignorés")
	advance_ms(260)
	check(audio.play_shown("try", 1) and moods.back() == "deception", "360 ms après l'essai (le rejet n'a pas décalé le repère) : déception adverse jouée")
	advance_ms(349)
	check(not audio.play_shown("penalty", 1), "349 ms : encore dans la fenêtre")
	advance_ms(1)
	check(audio.play_shown("penalty", 1), "350 ms : fenêtre close")
	advance_ms(450)
	for round in 5:
		check(audio.play_shown("try", 0) and moods.back() == "joie", "Réaction jouée : joie (tour %d)" % round)
		advance_ms(450)
		check(audio.play_shown("try", 1) and moods.back() == "deception" and audio._reaction.pitch_scale < 1.0, "Réaction jouée : déception, plus grave (tour %d)" % round)
		advance_ms(450)
		check(audio.play_shown("penalty", 1) and moods.back() == "sifflets" and cues.back() == "crowd-whistle", "Réaction jouée : sifflets (tour %d)" % round)
		advance_ms(450)
		check(not audio.play_shown("penalty", 0), "Pénalité pour le domicile : pas de sifflets (tour %d)" % round)
	# Même chemin via le journal moteur.
	var scene_try := {"kind": "try", "team": 1, "to": [1, 2]}
	var event := {"min": 12, "text": "Essai adverse", "scene": scene_try}
	var model := {"club": {"id": 0}, "meta": {"dataDir": directory, "season": 1, "round": 0, "phase": "league", "mode": "world-champ"},
		"live": {"pair": [0, 1], "paused": false, "finished": false, "atBreak": false, "events": [], "scene": {}}}
	audio.observe_model(model, "Match", "snapshot", true)
	advance_ms(450)
	check(audio._crowd_cue_for(event) == {"id": "stadium-try", "mood": "deception"}, "Journal moteur : essai de l'extérieur lu comme déception")

	# Les lecteurs encore en lecture ont un objet de lecture libéré de façon asynchrone par le mixeur :
	# on le suit pour que rien ne reste vivant à la sortie.
	var pending: Array[WeakRef] = []
	for player in [audio._ui, audio._bed, audio._reaction]:
		if player.playing:
			pending.append(weakref(player.get_stream_playback()))
	reloaded = null
	audio.dispose()
	check(AudioServer.get_bus_index("Interface") < 0, "Dispose retire les bus créés")
	check(AudioServer.get_bus_volume_linear(master) >= 0.0, "Master intact")
	app.queue_free()
	await process_frame
	var drain_deadline := Time.get_ticks_msec() + 500
	for playback in pending:
		while playback.get_ref() != null and Time.get_ticks_msec() < drain_deadline:
			await process_frame
	cues.clear()
	moods.clear()
	await process_frame
	print("Ambiance : %d vérifications, %d échec(s)" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
