extends SceneTree
class SpeechSpy extends "res://guide/guide_speech.gd":
	var system_requests: Array[Dictionary] = []
	var system_stops := 0
	func _speak_system(text: String, gain: int, id: int) -> void:
		system_requests.append({"text":text,"gain":gain,"id":id})
	func _stop_system() -> void:
		system_stops += 1
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var speech = SpeechSpy.new(); root.add_child(speech)
	check(speech.has_method("load_manifest"), "Lecture locale des fragments disponible")
	if not speech.has_method("load_manifest"): quit(1); return
	speech.setup("",1.25,false)
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	check(content.pages.size() == 25 and load("res://guide/guide_content.gd").TOUR.size() == 15, "25 pages et 15 identifiants historiques conservés")
	var seen: Dictionary = {}; var count_fragments := 0; var recorded := 0; var pending := 0
	var first_recorded := ""
	for page in content.pages:
		for fragment in page.fragments:
			count_fragments += 1
			check(not seen.has(fragment.id) and str(fragment.text).length() <= 181, "Fragment unique et court " + str(fragment.id))
			seen[fragment.id] = true
			if fragment.get("audioStatus") == "pending":
				pending += 1
				check(not speech.has_recording(str(fragment.text)), "Nouvelle bulle en attente explicite, sans ancienne prise substituée " + str(fragment.id))
			else:
				recorded += 1
				check(speech.has_recording(str(fragment.text)), "Clip livré pour le texte exact " + str(fragment.id))
				if first_recorded.is_empty(): first_recorded = str(fragment.text)
	check(count_fragments == 74 and recorded == 74 and pending == 0 and speech.clips.size() == recorded, "Les 74 répliques finales ont chacune une prise locale exacte, sans attente masquée")
	check(speech._lip_tracks.size() == recorded, "Chaque prise exacte a une piste de lèvres validée")
	check(speech.has_method("has_complete_recordings"), "La disponibilité distingue une voix complète d'un lot partiel")
	if speech.has_method("has_complete_recordings"):
		check(speech.has_complete_recordings() == (pending == 0), "La voix complète exige réellement chaque texte courant")
		if pending == 0: check(not speech.status_text.contains("provisoire") and not speech.status_text.contains("nouveaux textes"), "Une voix complète ne promet pas un repli pour des prises absentes")
	check(not speech.has_recording("La base anonymisée permet de jouer tout de suite. Et si tu remplaces une carrière, lis bien la confirmation : on ne range pas une histoire sans savoir où on la met."), "Une ancienne prise exclue ne reste pas disponible dans le lecteur")
	check(speech.status_text.contains("Gabi") and not speech.status_text.contains("Mode texte"), "Disponibilité de la voix enregistrée annoncée correctement")
	speech.volume = 0; speech.speak(first_recorded)
	check(speech.player.playing and speech.player.stream.get_length() > 0.5, "Vrai clip Gabi livré effectivement lu")
	check(not speech._lip_track.is_empty() and speech._envelope.is_empty(), "Le WAV exact utilise sa piste de lèvres")
	speech.stop()
	check(speech._lip_track.is_empty() and speech.articulation == 0.0 and speech._rounding == 0.0, "Arrêter le WAV remet les lèvres au repos")
	var folder := OS.get_environment("CD_GUIDE_VOICE_TEST_DIR")
	if folder.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 24000
	var pcm := PackedByteArray(); pcm.resize(4800); wav.data = pcm
	check(wav.save_to_wav(folder.path_join("essai.wav")) == OK, "WAV local de réception")
	var exact := "Une bulle, une voix."
	var clip := {"id":"essai","text":exact,"text_sha256":exact.sha256_text(),"file":"essai.wav"}
	var file := FileAccess.open(folder.path_join("manifest.json"), FileAccess.WRITE)
	var bad: Dictionary = clip.duplicate(); bad.text = "Mauvais hash"
	var traversal: Dictionary = clip.duplicate(); traversal.text = "Traversée"; traversal.text_sha256 = str(traversal.text).sha256_text(); traversal.file = "../essai.wav"
	file.store_string(JSON.stringify({"clips":[clip,bad,traversal]})); file.close()
	speech.load_manifest(folder.path_join("manifest.json"))
	check(speech.clips.size() == 1 and speech.has_recording(exact) and not speech.has_recording(exact + " suite"), "Texte exact et SHA requis, traversée refusée")
	var starts: Array[int] = []; var ends: Array[int] = []; var requests: Array[String] = []
	speech.started.connect(func(id: int): starts.append(id)); speech.ended.connect(func(id: int): ends.append(id))
	speech.requested.connect(func(text: String): requests.append(text))
	speech.speak(exact)
	check(speech.player.playing and speech.speaking and speech.player.pitch_scale == 1.25, "Lecture locale réelle avec débit")
	var deadline := Time.get_ticks_msec() + 3000
	while ends.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(starts.size() == 1 and ends == starts and requests == [exact] and not speech.speaking, "Signaux réels début et fin pour le même texte")
	speech.speak(exact); speech.stop()
	check(not speech.speaking and not speech.player.playing, "Stop coupe le clip")
	speech.set_muted(true); var count := requests.size(); speech.speak(exact)
	check(not speech.player.playing and requests.size() == count, "Muet sans parole locale")
	speech.load_manifest(folder.path_join("absent.json"))
	check(speech.clips.is_empty() and speech.status_text.contains("repli"), "Repli système annoncé quand clips absents")
	check(speech.has_method("set_global_volume"), "Le gain global doit aussi atteindre le repli TTS hors Master")
	if speech.has_method("set_global_volume"):
		speech.set_muted(false); speech.volume = 75; speech.voice_id = "spy-fr"
		for item in [[0,0],[40,30],[100,75]]:
			speech.set_global_volume(item[0]); speech.speak("Texte pending sans enregistrement")
			check(speech.system_requests[-1].gain == item[1], "Argument réel TTS au volume global " + str(item[0]))
			speech._started(speech._active)
			check(speech.speaking, "La parole système garde ses signaux sans produire de son")
		var stop_count: int = speech.system_stops
		speech.set_global_volume(0)
		check(speech.system_stops == stop_count + 1 and not speech.speaking, "Changer le gain coupe immédiatement la phrase système en cours")
		speech.set_global_volume(40); speech.speak("Phrase suivante")
		check(speech.system_requests[-1].gain == 30, "La prochaine phrase applique le nouveau gain")
		speech.set_muted(true); var request_count: int = speech.system_requests.size()
		speech.set_global_volume(100); speech.speak("Muet persistant")
		check(speech.muted and speech.system_requests.size() == request_count, "Le gain global ne désactive jamais le mute propre à Gabi")
		speech.set_muted(false); speech.load_manifest(folder.path_join("manifest.json"))
		for gain in [0,40,100]:
			AudioServer.set_bus_volume_linear(0,float(gain)/100.0)
			speech.set_global_volume(gain); speech.speak(exact)
			check(speech.player.playing and is_equal_approx(db_to_linear(speech.player.volume_db),0.75), "WAV conserve son gain propre sans double gain global " + str(gain))
			check(speech.system_requests.size() == request_count, "WAV exact sans repli TTS")
			speech.stop()
	var silent := SpeechSpy.new(); root.add_child(silent)
	silent.setup("spy-fr", 1.25, false, false)
	check(silent.muted and silent.player == null and silent.voices.is_empty() and silent.clips.is_empty()
		and silent._lip_tracks.is_empty(), "Gabi silencieux sans lecteur, manifeste, pistes de lèvres ni TTS")
	var silent_requests: Array[String] = []
	silent.requested.connect(func(text: String): silent_requests.append(text))
	silent.set_muted(false); silent.configure("spy-fr", 1.5); silent.set_global_volume(100)
	silent.load_manifest(folder.path_join("manifest.json")); silent.speak(exact)
	silent.voice_id = "spy-fr"; silent.speak("Secours système")
	check(silent.muted and not silent.speaking and silent.player == null and silent.clips.is_empty() and
		silent_requests.is_empty() and silent.system_requests.is_empty() and silent.system_stops == 0,
		"Le verrou audio résiste aux réglages, au chargement de WAV et au secours système")
	silent.queue_free()
	await check_articulation(folder)
	speech.player.stream = null; speech.queue_free(); speech = null; wav = null; file = null; await create_timer(0.2).timeout
	print("COACH VOIX LOCALE : %d contrôles ; %d échec(s)" % [checks, failures.size()])
	call_deferred("quit", 0 if failures.is_empty() else 1)

func at_position(speech: Node, seconds: float) -> void:
	var limit := Time.get_ticks_msec() + 3000
	while speech.player.playing and speech.player.get_playback_position() < seconds and Time.get_ticks_msec() < limit:
		await process_frame
	await process_frame

func check_articulation(folder: String) -> void:
	var speech = SpeechSpy.new(); root.add_child(speech); speech.setup("",1.0,false)
	check(speech.has_signal("articulation_changed"), "L'articulation doit suivre le PCM, y compris ses silences")
	if not speech.has_signal("articulation_changed"):
		speech.queue_free(); return
	var portrait = load("res://guide/coach_portrait.gd").new(); root.add_child(portrait)
	speech.speaking_changed.connect(portrait.set_speaking)
	speech.articulation_changed.connect(portrait.set_articulation)
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 24000
	var pcm := PackedByteArray(); pcm.resize(24000 * 2 * 1.4)
	for frame in int(pcm.size() / 2):
		var time := float(frame) / 24000.0
		pcm.encode_s16(frame * 2, int(14000.0 * sin(time * TAU * 220.0)) if time >= 0.4 and time < 0.8 else 0)
	wav.data = pcm
	check(wav.save_to_wav(folder.path_join("silence-parole.wav")) == OK, "Fixture réelle silence, parole, silence")
	var text := "La bouche respecte les pauses."
	speech.clips = {text:folder.path_join("silence-parole.wav"),"Une autre bulle.":folder.path_join("essai.wav")}
	speech.speak(text)
	check(portrait.pose_index == portrait._rest, "Un clip commençant par un silence ne produit pas même une frame bouche ouverte au départ")
	await at_position(speech,0.12)
	check(speech.speaking and speech.articulation == 0.0 and portrait.pose_index == portrait._rest, "La bouche reste fermée pendant le silence initial d'un clip en lecture")
	await at_position(speech,0.54)
	check(speech.articulation > 0.0, "La vraie portion PCM parlée ouvre l'articulation")
	var frames: Dictionary = {}
	while speech.player.playing and speech.player.get_playback_position() < 0.75:
		frames[portrait.pose_index] = true; await process_frame
	check(frames.has(portrait._talk) and frames.has(portrait._rest), "Le portrait articule réellement dans la portion parlée")
	await at_position(speech,1.0)
	check(speech.speaking and speech.articulation == 0.0 and portrait.pose_index == portrait._rest, "Le silence intérieur ferme la bouche sans annoncer une fin de phrase")
	speech.rate = 1.5; speech.speak(text)
	await at_position(speech,0.54)
	check(speech.articulation > 0.0 and speech.player.pitch_scale == 1.5, "L'articulation suit la position source au débit accéléré")
	portrait.set_reduced_motion(true)
	check(portrait.pose_index == portrait._rest, "Mouvement réduit garde une pose fermée même sur la parole PCM")
	portrait.set_reduced_motion(false)
	var old_id: int = speech._active
	speech.speak("Une autre bulle."); speech._ended(old_id)
	check(speech._active != old_id and speech.speaking and speech.articulation == 0.0 and portrait.pose_index == portrait._rest, "Un changement rapide de bulle ne conserve ni la bouche ni le callback de l'ancienne phrase")
	speech.stop()
	check(not speech.speaking and speech.articulation == 0.0 and portrait.pose_index == portrait._rest, "Stop ferme la bouche et coupe la lecture")
	speech.set_muted(true); speech.speak(text)
	check(not speech.player.playing and not portrait.speaking and portrait.pose_index == portrait._rest, "Muet ne lance aucune articulation")
	speech.set_muted(false); speech.voice_id = "spy-fr"; speech.speak("Repli système.")
	check(speech.articulation == -1.0, "La voix système garde une animation de secours explicite sans PCM inventé")
	speech._started(speech._active); speech.stop()
	var stereo := AudioStreamWAV.new(); stereo.format = AudioStreamWAV.FORMAT_16_BITS; stereo.mix_rate = 24000; stereo.stereo = true
	var stereo_pcm := PackedByteArray(); stereo_pcm.resize(24000 * 4)
	for frame in 24000:
		stereo_pcm.encode_s16(frame * 4 + 2, int(14000.0 * sin(float(frame) / 24000.0 * TAU * 220.0)))
	stereo.data = stereo_pcm
	var stereo_envelope: PackedFloat32Array = speech._recording_envelope("stereo",stereo)
	check(not stereo_envelope.is_empty() and stereo_envelope[5] > 0.018, "Un canal gauche silencieux ne fait pas disparaître la parole du canal droit")
	var unsupported := AudioStreamWAV.new(); unsupported.format = AudioStreamWAV.FORMAT_8_BITS; unsupported.mix_rate = 24000
	unsupported.data = PackedByteArray([128,128,128,128])
	check(speech._recording_envelope("eight-bit",unsupported).is_empty(), "Un format non PCM16 conserve le secours sans inventer une enveloppe")
	for index in 11:
		var copy_path := folder.path_join("cache-%d.wav" % index)
		wav.save_to_wav(copy_path); speech.clips[text] = copy_path; speech.speak(text)
	check(speech._envelope_cache.size() <= 8, "Onze nouvelles prises ne font pas croître le cache d'enveloppes au-delà de huit")
	speech.load_manifest(folder.path_join("manifest.json"))
	check(speech._envelope_cache.is_empty(), "Recharger le manifeste invalide toutes les anciennes enveloppes")
	speech.stop(); speech.player.stream = null; speech.queue_free(); portrait.queue_free()
