extends SceneTree

var failures: Array[String] = []
var checks := 0
var proof := OS.get_environment("CD_SOUNDS_PROOF")
var cues: Array[String] = []
var event_keys: Array = []

func _initialize() -> void:
	call_deferred("run")

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

func run() -> void:
	check(ResourceLoader.exists("res://audio/soundscape.gd") and ResourceLoader.exists("res://audio/sound_preferences.gd"), "Modules sonores présents")
	if not failures.is_empty():
		quit(1)
		return
	await profile_cases()
	# Atomic OS.execute calls block one frame. Drain that accumulated frame delta
	# before measuring a real-time audio completion; do not lengthen the timeout.
	await process_frame
	await process_frame
	await sound_cases()
	print("SOUNDS_DUMMY_CHECKS ", JSON.stringify({"checks": checks, "failures": failures, "driver": AudioServer.get_driver_name()}))
	write(proof.path_join("report.json"), JSON.stringify({"checks": checks, "failures": failures, "driver": AudioServer.get_driver_name(), "cues": cues}, "  "))
	quit(0 if failures.is_empty() else 1)

func profile_cases() -> void:
	var script: Script = load("res://audio/sound_preferences.gd")
	var profile = script.new()
	check(not profile.set_value("interface_volume", 10) and not profile.last_error.is_empty(), "Écriture sans profil refusée visiblement")
	check(not profile.load_profile("relatif"), "Profil relatif refusé sans repli")
	var directory := proof.path_join("profil Émile été")
	check(profile.load_profile(directory), "Dossier neuf Unicode chargé")
	check(profile.data == {"version": 1, "interface_volume": 35, "stadium_volume": 25}, "Valeurs initiales exactes et indépendantes")
	check(not FileAccess.file_exists(directory.path_join("sound.json")), "Lecture absente ne crée pas de réglages")
	var changes := [0]
	profile.changed.connect(func(): changes[0] += 1)
	check(profile.set_value("interface_volume", 40) and profile.set_value("stadium_volume", 20), "Deux volumes persistés via remplacement atomique")
	check(changes[0] == 2, "Notification seulement après deux écritures réussies")
	var original := FileAccess.get_file_as_bytes(directory.path_join("sound.json"))
	var restart = script.new()
	check(restart.load_profile(directory) and restart.get_value("interface_volume") == 40 and restart.get_value("stadium_volume") == 20, "Redémarrage retrouve les deux volumes Unicode")
	for item in [["interface_volume", -1], ["stadium_volume", 101], ["interface_volume", 2.5], ["stadium_volume", true], ["interface_volume", "20"], ["version", 2], ["unknown", 0]]:
		check(not profile.set_value(item[0], item[1]) and not profile.last_error.is_empty(), "Réglage invalide refusé : " + str(item))
		check(FileAccess.get_file_as_bytes(directory.path_join("sound.json")) == original and changes[0] == 2, "Refus conserve octets, mémoire et notifications")
	var temporary := directory.path_join("sound.json.tmp")
	DirAccess.make_dir_absolute(temporary)
	check(not profile.set_value("interface_volume", 11) and not profile.last_error.is_empty(), "Temporaire occupé par un dossier refusé")
	check(profile.get_value("interface_volume") == 40 and FileAccess.get_file_as_bytes(directory.path_join("sound.json")) == original, "Temporaire bloqué conserve octets et réglage actif")
	DirAccess.remove_absolute(temporary)
	write(temporary, "interruption")
	check(restart.load_profile(directory) and restart.get_value("interface_volume") == 40, "Un temporaire tronqué ne remplace pas l'original au redémarrage")
	check(restart.set_value("stadium_volume", 21) and not FileAccess.file_exists(temporary), "Reprise remplace un temporaire incomplet sans repli")
	var runtime := OS.get_environment("CD_NODE_EXECUTABLE")
	original = FileAccess.get_file_as_bytes(directory.path_join("sound.json"))
	OS.set_environment("CD_NODE_EXECUTABLE", proof.path_join("runtime absent.exe"))
	check(not restart.set_value("stadium_volume", 1) and not restart.last_error.is_empty(), "Runtime atomique absent refusé visiblement")
	check(restart.get_value("stadium_volume") == 21 and FileAccess.get_file_as_bytes(directory.path_join("sound.json")) == original, "Runtime absent conserve mémoire et octets")
	OS.set_environment("CD_NODE_EXECUTABLE", runtime)
	var bads := ["{", '{"version":2,"interface_volume":35,"stadium_volume":25}', '{"version":1,"interface_volume":35,"stadium_volume":25,"volume":75}', '{"version":1,"interface_volume":3.5,"stadium_volume":25}', '{"version":1,"interface_volume":35}', " ".repeat(4097)]
	for index in bads.size():
		var folder := proof.path_join("invalide-" + str(index))
		DirAccess.make_dir_recursive_absolute(folder)
		write(folder.path_join("sound.json"), bads[index])
		var rejected = script.new()
		check(not rejected.load_profile(folder) and not rejected.last_error.is_empty(), "Fichier invalide conservé : " + str(index))
		check(not rejected.set_value("interface_volume", 0) and FileAccess.get_file_as_string(folder.path_join("sound.json")) == bads[index], "Fichier refusé protégé contre la réécriture : " + str(index))
	var readonly = script.new()
	check(readonly.load_profile(proof.path_join("readonly")), "Fichier readonly lisible")
	if OS.get_environment("CD_SOUNDS_READONLY") == "1":
		var readonly_bytes := FileAccess.get_file_as_bytes(proof.path_join("readonly/sound.json"))
		check(not readonly.set_value("interface_volume", 90) and not readonly.last_error.is_empty(), "Vrai attribut Windows readonly refuse le remplacement")
		check(readonly.get_value("interface_volume") == 35 and FileAccess.get_file_as_bytes(proof.path_join("readonly/sound.json")) == readonly_bytes, "Readonly conserve mémoire et octets")
	else:
		print("Readonly Windows non applicable sur cet OS ; aucun succès Windows revendiqué.")
	check(not FileAccess.file_exists(directory.path_join("interface.json")), "Préférences UI v1 non créées ni modifiées")

func event_model(events: Array, index: int, paused: bool = false) -> Dictionary:
	var event: Dictionary = events[index]
	var fact: Dictionary = event.get("scene", {})
	return {"club": {"id": 0}, "meta": {"dataDir": proof.path_join("career"), "season": 1, "round": 0, "phase": "league", "mode": "fictional14"},
		"live": {"pair": [0, 1], "paused": paused, "finished": false, "atBreak": false, "events": events.slice(0, index + 1),
			"scene": {"kind": fact.get("kind", ""), "key": event_keys[index]}}}

func sound_cases() -> void:
	check(AudioServer.get_driver_name() == "Dummy", "Driver Dummy explicite ; aucune écoute physique prétendue")
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(master, 0.42)
	AudioServer.set_bus_mute(master, true)
	var app := Control.new()
	root.add_child(app)
	var button := Button.new()
	app.add_child(button)
	var disabled := Button.new()
	disabled.disabled = true
	app.add_child(disabled)
	var guide := Control.new()
	guide.name = "Gabi"
	app.add_child(guide)
	var guide_button := Button.new()
	guide.add_child(guide_button)
	var field := LineEdit.new()
	app.add_child(field)
	var field_button := Button.new()
	field.add_child(field_button)
	var slider := HSlider.new()
	app.add_child(slider)
	var slider_button := Button.new()
	slider.add_child(slider_button)
	var audio = load("res://audio/soundscape.gd").new()
	app.add_child(audio)
	check(audio.setup(app) and audio.setup(app), "Setup idempotent")
	check(audio.load_profile(proof.path_join("audio-profile")), "Profil sonore chargé par le gestionnaire")
	audio.cue_played.connect(func(id): cues.append(id))
	var interface_bus := AudioServer.get_bus_index("Interface")
	var stadium_bus := AudioServer.get_bus_index("Stade")
	check(interface_bus > 0 and stadium_bus > 0 and AudioServer.get_bus_send(interface_bus) == "Master" and AudioServer.get_bus_send(stadium_bus) == "Master", "Deux bus enfants de Master")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(interface_bus), 0.35) and is_equal_approx(AudioServer.get_bus_volume_linear(stadium_bus), 0.25), "Deux gains appliqués une seule fois")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(master), 0.42) and AudioServer.is_bus_mute(master), "Gain et mute Master préservés")
	check(cues.is_empty(), "Connexion des contrôles sans son")
	# Asset loading/setup also happened synchronously. Start timed playback in a
	# fresh steady frame, not a frame carrying the preceding disk operations.
	await process_frame
	await process_frame
	button.pressed.emit()
	check(cues == ["ui-tap"], "Un vrai signal pressed déclenche un seul son")
	check(audio.notify_error() and cues.back() == "ui-error", "Erreur confirmée peut remplacer immédiatement le clic qui l'a déclenchée")
	check(not audio.notify_error(), "Erreur identique immédiate ne produit pas de rafale")
	var completed := [false]
	audio._ui.finished.connect(func(): completed[0] = true)
	await create_timer(0.25).timeout
	check(completed[0] and not audio._ui.playing, "Lecture WAV effectivement terminée sous Dummy")
	disabled.pressed.emit()
	guide_button.pressed.emit()
	field.text_changed.emit("texte")
	slider.value_changed.emit(20)
	field_button.pressed.emit()
	slider_button.pressed.emit()
	check(cues.size() == 2, "Boutons désactivés, Gabi, saisie et curseurs silencieux")
	check(audio.notify_error() and cues.back() == "ui-error", "Erreur confirmée possède son effet discret")
	await create_timer(0.1).timeout
	check(audio.preferences.set_value("interface_volume", 0) and AudioServer.is_bus_mute(interface_bus), "Volume UI zéro mute réellement son bus")
	check(not audio.play_interface() and not audio._ui.playing, "Volume UI zéro ne lance aucun son")
	check(audio.preferences.set_value("interface_volume", 35), "Volume UI restauré")
	var events: Array = JSON.parse_string(FileAccess.get_file_as_string(proof.path_join("engine-events.json")))
	event_keys = JSON.parse_string(FileAccess.get_file_as_string(proof.path_join("engine-keys.json")))
	var reaction_index := -1
	for index in range(1, events.size()):
		if not audio._reaction_for(events[index]).is_empty():
			reaction_index = index
			break
	check(reaction_index > 0, "Fixture réellement issue du moteur avec réaction typée")
	if reaction_index < 1:
		app.queue_free()
		return
	var baseline := event_model(events, reaction_index - 1)
	var live := event_model(events, reaction_index)
	var original := live.duplicate(true)
	var count := cues.size()
	audio.observe_model(baseline, "Match", "snapshot", true)
	check(cues.size() == count, "Première lecture de carrière/instantané sans réaction historique")
	audio.observe_model(live, "Match", "tick", true)
	check(cues.size() == count + 1 and cues.back() == audio._reaction_for(events[reaction_index]), "Nouveau fait moteur visible déclenche la bonne réaction")
	audio.observe_model(live, "Match", "tick", true)
	audio.observe_model(live, "Match", "snapshot", true)
	audio.observe_model(live, "Match", "resume", true)
	audio.refresh_visibility("Match", true)
	check(cues.size() == count + 1, "Même événement, snapshot, reprise et caméra ne rejouent rien")
	await create_timer(0.05).timeout
	check(audio._bed.playing, "Ambiance réservée au direct visible")
	audio.refresh_visibility("Bureau", false)
	await create_timer(0.35).timeout
	check(not audio._bed.playing and not audio._reaction.playing, "Sortie de Match éteint ambiance et réaction par fondu")
	var next := event_model(events, mini(reaction_index + 1, events.size() - 1), true)
	audio.observe_model(next, "Bureau", "tick", false)
	audio.observe_model(next, "Match", "resume", true)
	check(cues.size() == count + 1, "Événement consommé hors route et en pause ne crie pas à la réouverture")
	audio.observe_model(live, "Match", "seek", true)
	audio.observe_model(next, "Match", "tick", true)
	check(cues.size() == count + 1, "Retour arrière puis relecture ne rejouent pas les identités déjà consommées")
	audio.observe_model(live, "Match", "import", true)
	audio.observe_model(live, "Match", "tick", true)
	check(cues.size() == count + 1, "Import réussi initialise son contexte sans rejouer l'essai importé")
	audio.observe_model(live, "Match", "import", true, false)
	check(cues.size() == count + 1 and live == original, "Import refusé ne produit pas de son et préserve le modèle")
	var other := live.duplicate(true)
	other.meta.season = 2
	audio.observe_model(other, "Match", "tick", true)
	check(cues.size() == count + 1, "Nouvelle rencontre initialise sa signature sans faux cri")
	check(audio._reaction_for({"text": "Essai", "type": "try"}).is_empty(), "Texte et ancien type seuls n'inventent pas un événement sonore")
	check(audio.preferences.set_value("stadium_volume", 0) and AudioServer.is_bus_mute(stadium_bus) and not audio._bed.playing and not audio._reaction.playing, "Volume stade zéro coupe tous ses lecteurs")
	audio.observe_model(baseline, "Match", "new_career", true)
	audio.observe_model(live, "Match", "tick", true)
	check(cues.size() == count + 1, "Un nouvel essai au volume zéro est consommé sans lecteur")
	check(audio.preferences.set_value("stadium_volume", 25), "Volume stade restauré")
	audio.observe_model(live, "Match", "snapshot", true)
	check(cues.size() == count + 1, "Sortir du mute ne rejoue aucun essai consommé")
	audio.set_voice_active(true)
	await create_timer(0.3).timeout
	check(is_equal_approx(db_to_linear(audio._bed.volume_db), 0.35) and is_equal_approx(db_to_linear(audio._reaction.volume_db), 0.55), "Voix active atténue seulement les lecteurs stade")
	audio.set_voice_active(false)
	await create_timer(0.3).timeout
	check(is_equal_approx(db_to_linear(audio._bed.volume_db), 1.0), "Fin de voix restaure progressivement le stade")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(master), 0.42) and AudioServer.is_bus_mute(master), "Master reste autoritaire après tous les réglages")
	var bus_count := AudioServer.bus_count
	var duplicate = load("res://audio/soundscape.gd").new()
	app.add_child(duplicate)
	check(not duplicate.setup(app) and not duplicate.last_error.is_empty() and AudioServer.bus_count == bus_count, "Deux gestionnaires du même écran refusés sans doublon audible")
	duplicate.queue_free()
	var second_app := Control.new()
	root.add_child(second_app)
	var second = load("res://audio/soundscape.gd").new()
	second_app.add_child(second)
	check(second.setup(second_app) and AudioServer.bus_count == bus_count, "Deux instances QA partagent exactement deux bus")
	second.dispose()
	check(AudioServer.bus_count == bus_count, "Dispose secondaire conserve les bus de l'instance active")
	second_app.queue_free()
	var pending_playback: WeakRef = weakref(audio._bed.get_stream_playback()) if audio._bed.playing else null
	audio.dispose()
	check(AudioServer.get_bus_index("Interface") < 0 and AudioServer.get_bus_index("Stade") < 0, "Dernier dispose retire ses seuls bus")
	app.queue_free()
	await process_frame
	# Stopped audio is released by the mixer asynchronously. Observe the actual
	# playback object's destruction; a silent mixer need not keep ticking.
	var drain_deadline := Time.get_ticks_msec() + 250
	while pending_playback != null and pending_playback.get_ref() != null and Time.get_ticks_msec() < drain_deadline:
		await process_frame
	check(pending_playback == null or pending_playback.get_ref() == null, "Objet de lecture libéré réellement après dispose")
