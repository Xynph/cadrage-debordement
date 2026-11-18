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
	app.settings()
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

## Avance l'horloge de jeu puis laisse passer une image : les bruits différés partent.
func tick_ms(ms: int) -> void:
	advance_ms(ms)
	await process_frame

## Bruits de match (18/11/2026) : chaque fait montré déclenche les bons identifiants, avec délais et anti-rebond.
func match_noises(audio) -> void:
	var effects: Array[String] = []
	audio.effect_played.connect(func(id: String): effects.append(id))
	await tick_ms(5000)
	effects.clear()
	# Coup d'envoi : sifflet tout de suite, frappe du ballon 450 ms plus tard.
	audio.play_shown("kickoff", 0)
	check(effects == ["referee-whistle"], "Coup d'envoi : coup de sifflet immédiat " + str(effects))
	await tick_ms(300)
	check(effects == ["referee-whistle"], "Coup d'envoi : pas encore de frappe à 300 ms")
	await tick_ms(200)
	check(effects == ["referee-whistle", "kick-pock"], "Coup d'envoi : frappe du ballon après le sifflet " + str(effects))
	# Pénalité : sifflet de l'arbitre ; un second sifflet trop proche n'est pas empilé.
	await tick_ms(1000)
	effects.clear()
	check(not audio.play_shown("penalty", 0) and effects == ["referee-whistle"], "Pénalité pour le domicile : sifflet d'arbitre, pas de sifflets de foule")
	await tick_ms(300)
	audio.play_shown("hand-fault", 1)
	check(effects == ["referee-whistle"], "Deux sifflets à 300 ms : un seul joué")
	await tick_ms(500)
	var crowd_before: int = cues.size()
	check(audio.play_shown("hand-fault", 0) and effects.back() == "referee-whistle" and cues.back() == "crowd-groan" and moods.back() == "deception", "En-avant du domicile : sifflet et « oooh »")
	check(audio._reaction.stream == audio._streams["crowd-groan"], "« Oooh » : le son déçu est joué")
	# Plaquages : anti-rebond court, hauteur variée d'un coup à l'autre.
	await tick_ms(1000)
	effects.clear()
	var pitches: Array[float] = []
	for n in 4:
		audio.play_shown("tackle")
		var player: AudioStreamPlayer = audio._impacts[(audio._impact_next + audio._impacts.size() - 1) % audio._impacts.size()]
		pitches.append(player.pitch_scale)
		await tick_ms(100)
	check(effects == ["impact-tackle", "impact-tackle"], "Plaquages toutes les 100 ms : anti-rebond de 250 ms, pas de rafale " + str(effects))
	check(abs(pitches[0] - pitches[3]) > 0.0001 and pitches.all(func(p: float): return absf(p - 1.0) <= 0.12), "Plaquages : hauteur légèrement variée " + str(pitches))
	# Mêlée : impact du pack à l'engagement, après la mise en place.
	await tick_ms(1000)
	effects.clear()
	audio.play_shown("scrum", 0, 50.0)
	await tick_ms(500)
	check(effects == ["impact-scrum"], "Mêlée : impact du pack à l'engagement " + str(effects))
	# Tirs : frappe ; manqué du domicile = « oooh », de l'adversaire = soulagement.
	await tick_ms(1000)
	effects.clear()
	audio.play_shown("kick", 1)
	check(effects == ["kick-pock"], "Jeu au pied : « pock » du ballon")
	check(audio._crowd_cue("miss", 0).mood == "deception" and audio._crowd_cue("miss", 1).mood == "joie", "Tir manqué : déception à domicile, soulagement contre l'adversaire")
	check(audio._crowd_cue("turnover", 0).id == "crowd-applause" and audio._crowd_cue("turnover", 1).is_empty(), "Ballon récupéré par le domicile : applaudissements")
	# Rumeur : monte près de la ligne, pas au milieu du terrain, retombe au jeu au pied.
	await tick_ms(1000)
	effects.clear()
	audio.play_shown("carry", 0, 40.0)
	check(audio._murmur_target == 0.0 and effects.is_empty(), "Course au milieu du terrain : pas de rumeur")
	audio.play_shown("carry", 0, 5.0)
	check(audio._murmur_target > 0.8 and effects == ["crowd-murmur"], "Attaque à 5 m de la ligne : la rumeur monte")
	audio.play_shown("tackle")
	audio.play_shown("setpiece-win", 0, 3.0)
	check(effects.count("crowd-murmur") == 1 and audio._murmur_target > 0.8, "Rumeur déjà là : pas relancée, le plaquage ne la coupe pas")
	for n in 4: await process_frame
	check(audio._murmur.playing and audio._murmur_gain > 0.0, "Rumeur en lecture, en fondu entrant")
	audio.play_shown("kick", 0)
	check(audio._murmur_target == 0.0, "Ballon dégagé au pied : la rumeur retombe")
	# Essai à domicile : clameur puis applaudissements en relais ; essai adverse : pas de relais.
	await tick_ms(2000)
	var before_try: int = cues.size()
	check(audio.play_shown("try", 0), "Essai à domicile : clameur")
	await tick_ms(1300)
	check(cues.slice(before_try) == ["stadium-try", "crowd-applause"], "Essai à domicile : applaudissements en relais " + str(cues.slice(before_try)))
	check(audio._reaction_out.playing and audio._reaction.stream == audio._streams["crowd-applause"], "La clameur s'efface en fondu sous les applaudissements, sans coupure")
	await tick_ms(2000)
	before_try = cues.size()
	audio.play_shown("try", 1)
	await tick_ms(1300)
	check(cues.slice(before_try) == ["stadium-try"], "Essai adverse : pas d'applaudissements")
	# Mi-temps : direct arrêté mais Match affiché → long coup de sifflet, puis applaudissements.
	await tick_ms(4000)
	effects.clear()
	before_try = cues.size()
	audio.set_presenting(false)
	audio._live_active = false
	audio.refresh_visibility("Match", true)
	audio.play_shown("break")
	check(effects == ["referee-whistle-long"], "Mi-temps : long coup de sifflet " + str(effects))
	await tick_ms(1000)
	check(cues.slice(before_try) == ["crowd-applause"], "Mi-temps : applaudissements après le sifflet")
	# Match masqué, sons décochés : rien.
	await tick_ms(4000)
	effects.clear()
	audio.refresh_visibility("Bureau", false)
	audio.play_shown("end")
	audio.play_shown("kickoff")
	await tick_ms(1000)
	check(effects.is_empty(), "Match masqué : ni arbitre ni ballon")
	audio.refresh_visibility("Match", true)
	audio.set_presenting(true)
	check(audio.preferences.set_value("match_sounds", false), "Sons de match décochés")
	audio.play_shown("kickoff")
	audio.play_shown("tackle")
	check(effects.is_empty() and not audio._murmur.playing, "Sons de match décochés : aucun bruit de match")
	check(audio.preferences.set_value("match_sounds", true), "Sons de match recochés")
	# Direct d'origine (sans temps forts) : le passage à la mi-temps siffle, l'ouverture d'un match déjà arrêté non.
	await tick_ms(4000)
	effects.clear()
	var live := {"pair": [0, 1], "paused": false, "finished": false, "atBreak": false, "events": [], "scene": {}}
	var model := {"club": {"id": 0}, "meta": {"dataDir": "x", "season": 1, "round": 0, "phase": "league", "mode": "world-champ"}, "live": live}
	audio.observe_model(model, "Match", "tick", true)
	var stopped: Dictionary = model.duplicate(true)
	stopped.live.atBreak = true
	audio.observe_model(stopped, "Match", "tick", true)
	check(effects == ["referee-whistle-long"], "Direct d'origine : long sifflet à la mi-temps " + str(effects))
	await tick_ms(4000)
	effects.clear()
	audio.observe_model({}, "Match", "snapshot", true)
	audio.observe_model(stopped, "Match", "tick", true)
	check(effects.is_empty(), "Match rouvert déjà à la mi-temps : silence")
	audio.observe_model({}, "Match", "snapshot", true)
	await tick_ms(4000)

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
	await match_noises(audio)
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
	for player in audio.players():
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
