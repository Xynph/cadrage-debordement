extends SceneTree
## Ambiance sonore : bus Musique, musique douce du Bureau coupée en match, foule selon le camp qui marque.
## Captures (rendu graphique, vrai jeu) : CD_AMBIANCE_CAPTURE=<dossier> ; l'onglet Son des paramètres est photographié
## avec « Musique » cochée puis décochée (« Musique pendant les matchs » grisée). Sans la variable, rien ne change.

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
	app.settings()
	await settle(24)
	var dialog: AcceptDialog = app.find_child("PreferencesDialog", true, false)
	check(dialog != null, "Paramètres ouverts")
	if dialog != null:
		var tabs: TabContainer = dialog.find_child("PreferencesTabs", true, false)
		tabs.current_tab = 1
		await settle(12)
		var music_on := dialog.find_child("PreferencesMusicOn", true, false) as CheckBox
		var in_match := dialog.find_child("PreferencesMusicInMatch", true, false) as CheckBox
		var match_sounds := dialog.find_child("PreferencesMatchSounds", true, false) as CheckBox
		var volume := dialog.find_child("PreferencesMusicVolume", true, false) as SpinBox
		check(music_on != null and in_match != null and match_sounds != null and volume != null, "Trois cases et volume Musique présents")
		if music_on != null and in_match != null and match_sounds != null:
			print("DIAG audio : musique=", music_on.button_pressed, " en_match=", in_match.button_pressed, " grisee=", in_match.disabled, " sons=", match_sounds.button_pressed, " volume=", volume.value)
			check(music_on.button_pressed and not in_match.disabled, "Case Musique cochée : « pendant les matchs » disponible")
			await capture("parametres-audio-musique-cochee")
			music_on.button_pressed = false
			await settle(12)
			check(not music_on.button_pressed and in_match.disabled, "Case Musique décochée : « pendant les matchs » grisée")
			await capture("parametres-audio-musique-decochee")
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

## Attend sur l'horloge murale (Time.get_ticks_msec), la même que l'anti-rebond de la régie :
## un create_timer suit le temps simulé, qui peut avancer moins vite que le mur sur un runner lent.
func wait_ms(ms: int) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await process_frame

## Fait avancer le fondu de la musique de « seconds » secondes simulées.
func step_music(audio: Node, seconds: float) -> void:
	for i in int(seconds / 0.1):
		audio._update_music(0.1)

func run() -> void:
	var directory := proof.path_join("profil")
	DirAccess.make_dir_recursive_absolute(directory)
	# Fichier d'avant la musique : accepté, volume musique par défaut.
	write(directory.path_join("sound.json"), '{"version":1,"interface_volume":35,"stadium_volume":25}')
	var app := Control.new()
	root.add_child(app)
	var audio = load("res://audio/soundscape.gd").new()
	app.add_child(audio)
	check(audio.setup(app), "Setup du gestionnaire sonore")
	check(audio.load_profile(directory) and audio.preferences.get_value("music_volume") == 30, "Ancien sound.json sans musique accepté, volume musique 30")
	var master := AudioServer.get_bus_index("Master")
	for label in ["Interface", "Stade", "Musique"]:
		var index := AudioServer.get_bus_index(label)
		check(index > 0 and AudioServer.get_bus_send(index) == "Master", "Bus " + label + " présent, enfant de Master")
	var music_bus := AudioServer.get_bus_index("Musique")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(music_bus), 0.30), "Volume musique appliqué au bus Musique")
	check(audio.preferences.set_value("music_volume", 45) and is_equal_approx(AudioServer.get_bus_volume_linear(music_bus), 0.45), "Réglage musique persisté et appliqué")

	# Sans fichier de musique : silence, aucune erreur.
	audio.refresh_visibility("Bureau", false)
	step_music(audio, 3.0)
	check(not audio._music.playing and audio.last_error.is_empty(), "Aucun morceau fourni : silence sans erreur")

	# Morceaux branchés (le son de stade sert de maquette) : Bureau puis menu.
	var stream: AudioStream = audio._streams["stadium-bed"]
	audio.set_music_stream("bureau", stream)
	audio.set_music_stream("menus", stream.duplicate())
	audio.refresh_visibility("Bureau", false)
	step_music(audio, 3.0)
	check(audio._music.playing and audio._music_slot == "bureau" and audio._music_gain > 0.99, "Musique du Bureau lancée avec fondu")
	audio.refresh_visibility("Effectif", false)
	step_music(audio, 0.5)
	check(audio._music.playing and audio._music_gain < 1.0 and audio._music_slot == "bureau", "Changement d'écran : fondu sortant avant le morceau suivant")
	step_music(audio, 3.0)
	check(audio._music_slot == "menus" and audio._music.playing and audio._music_gain > 0.99, "Menus : morceau des menus en fondu entrant")
	# Pas pendant le match.
	audio.refresh_visibility("Match", true)
	step_music(audio, 3.0)
	check(not audio._music.playing and audio._music_gain == 0.0, "Route Match : musique coupée")
	audio.refresh_visibility("Bureau", false)
	step_music(audio, 3.0)
	check(audio._music.playing, "Retour au Bureau : musique reprise")
	audio._live_active = true
	step_music(audio, 3.0)
	check(not audio._music.playing, "Direct en cours (même hors écran Match) : musique coupée")
	audio._live_active = false
	# Intro : blocage explicite.
	audio.set_music_blocked("intro", true)
	step_music(audio, 3.0)
	check(not audio._music.playing, "Intro active : musique bloquée")
	audio.set_music_blocked("intro", false)
	step_music(audio, 3.0)
	check(audio._music.playing, "Intro finie : musique libérée")
	audio.refresh_visibility("Accueil", false)
	step_music(audio, 3.0)
	check(not audio._music.playing, "Écran d'accueil (intro) : pas de musique")
	audio.refresh_visibility("Bureau", false)
	step_music(audio, 3.0)
	check(audio._music.playing and audio.preferences.set_value("music_volume", 0) and AudioServer.is_bus_mute(music_bus) and not audio._music.playing, "Volume musique zéro mute le bus et coupe le lecteur")
	check(audio.preferences.set_value("music_volume", 30) and not AudioServer.is_bus_mute(music_bus), "Volume musique restauré")

	# Cases à cocher.
	var prefs = audio.preferences
	check(prefs.get_flag("music_on") and not prefs.get_flag("music_in_match") and prefs.get_flag("match_sounds"), "Valeurs par défaut des cases : musique oui, musique en match non, sons de match oui")
	check(prefs.set_value("music_on", false) and not audio._music.playing, "Décocher « Musique » coupe la musique aussitôt")
	step_music(audio, 3.0)
	check(not audio._music.playing and audio._music_gain == 0.0, "Musique décochée : silence au Bureau")
	check(prefs.set_value("music_on", true), "Musique recochée")
	step_music(audio, 3.0)
	check(audio._music.playing, "Musique recochée : elle reprend")
	check(not prefs.set_value("music_on", "oui") and not prefs.set_value("match_sounds", 1), "Une case n'accepte qu'un oui ou non")
	audio.last_error = ""
	audio.refresh_visibility("Match", true)
	step_music(audio, 3.0)
	check(not audio._music.playing, "Musique en match décochée : coupée sur l'écran Match")
	check(prefs.set_value("music_in_match", true), "Musique pendant les matchs cochée")
	step_music(audio, 3.0)
	check(audio._music.playing, "Musique pendant les matchs cochée : elle continue sur l'écran Match")
	audio._live_active = true
	step_music(audio, 3.0)
	check(audio._music.playing, "Musique pendant les matchs cochée : elle continue pendant le direct")
	check(prefs.set_value("music_on", false), "Musique décochée avec musique en match cochée")
	step_music(audio, 3.0)
	check(not audio._music.playing, "Musique décochée : même la musique de match se coupe")
	audio._live_active = false
	check(prefs.set_value("music_on", true) and prefs.set_value("music_in_match", false), "Retour aux réglages par défaut")
	# Sons de match.
	audio.set_presenting(true)
	await wait_ms(450)
	check(prefs.set_value("match_sounds", false) and not audio._bed.playing and not audio._reaction.playing, "Décocher « Sons de match » coupe l'ambiance du stade")
	check(not audio.play_shown("try", 0) and not audio.play_shown("penalty", 1), "Sons de match décochés : ni foule ni sifflets")
	step_music(audio, 3.0)
	audio.refresh_visibility("Bureau", false)
	audio.set_presenting(false)
	step_music(audio, 3.0)
	check(audio._music.playing, "Sons de match décochés : la musique n'est pas touchée")
	check(prefs.set_value("match_sounds", true), "Sons de match recochés")
	# Les cases survivent à un rechargement.
	check(prefs.set_value("music_in_match", true), "Case enregistrée")
	var reloaded = load("res://audio/sound_preferences.gd").new()
	check(reloaded.load_profile(directory) and reloaded.get_flag("music_in_match") and reloaded.get_flag("music_on") and reloaded.get_flag("match_sounds"), "Cases relues au redémarrage")
	check(prefs.set_value("music_in_match", false), "Case remise par défaut")

	# Foule : camp domicile = 0.
	audio.cue_played.connect(func(id: String): cues.append(id))
	audio.crowd_mood.connect(func(mood: String): moods.append(mood))
	check(audio._crowd_cue("try", 0) == {"id": "stadium-try", "mood": "joie"}, "Essai à domicile : montée")
	check(audio._crowd_cue("try", 1) == {"id": "stadium-try", "mood": "deception"}, "Essai adverse : déception")
	check(audio._crowd_cue("penalty", 1) == {"id": "crowd-whistle", "mood": "sifflets"}, "Pénalité accordée à l'extérieur : sifflets")
	check(audio._crowd_cue("penalty", 0).is_empty() and audio._crowd_cue("scrum", 1).is_empty(), "Pénalité pour le domicile ou autre fait : rien")
	audio.refresh_visibility("Match", true)
	audio.set_presenting(true)
	for round in 5:
		check(audio.play_shown("try", 0) and moods.back() == "joie", "Réaction jouée : joie (tour %d)" % round)
		await wait_ms(450)
		check(audio.play_shown("try", 1) and moods.back() == "deception" and audio._reaction.pitch_scale < 1.0, "Réaction jouée : déception, plus grave (tour %d)" % round)
		await wait_ms(450)
		check(audio.play_shown("penalty", 1) and moods.back() == "sifflets" and cues.back() == "crowd-whistle", "Réaction jouée : sifflets (tour %d)" % round)
		await wait_ms(450)
		check(not audio.play_shown("penalty", 0), "Pénalité pour le domicile : pas de sifflets (tour %d)" % round)
	# Même chemin via le journal moteur.
	var scene_try := {"kind": "try", "team": 1, "to": [1, 2]}
	var event := {"min": 12, "text": "Essai adverse", "scene": scene_try}
	var model := {"club": {"id": 0}, "meta": {"dataDir": directory, "season": 1, "round": 0, "phase": "league", "mode": "world-champ"},
		"live": {"pair": [0, 1], "paused": false, "finished": false, "atBreak": false, "events": [], "scene": {}}}
	audio.observe_model(model, "Match", "snapshot", true)
	await wait_ms(450)
	check(audio._crowd_cue_for(event) == {"id": "stadium-try", "mood": "deception"}, "Journal moteur : essai de l'extérieur lu comme déception")

	check(not audio.preferences.set_value("music_volume", 101), "Volume musique hors 0..100 refusé")
	# Les lecteurs encore en lecture ont un objet de lecture libéré de façon asynchrone par le mixeur :
	# on le suit pour que rien ne reste vivant à la sortie.
	var pending: Array[WeakRef] = []
	for player in [audio._ui, audio._bed, audio._reaction, audio._music]:
		if player.playing:
			pending.append(weakref(player.get_stream_playback()))
	stream = null
	reloaded = null
	audio.dispose()
	check(AudioServer.get_bus_index("Musique") < 0 and AudioServer.get_bus_index("Interface") < 0, "Dispose retire les bus créés")
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
