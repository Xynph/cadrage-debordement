extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var speech = load("res://guide/guide_speech.gd").new(); root.add_child(speech)
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
	check(count_fragments == 74 and recorded == 38 and pending == 36 and speech.clips.size() == recorded, "Couverture mesurée : 38 enregistrements exacts, 36 textes en attente")
	check(speech.status_text.contains("Gabi") and not speech.status_text.contains("Mode texte"), "Disponibilité de la voix enregistrée annoncée correctement")
	speech.volume = 0; speech.speak(first_recorded)
	check(speech.player.playing and speech.player.stream.get_length() > 0.5, "Vrai clip Gabi livré effectivement lu")
	speech.stop()
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
	speech.player.stream = null; speech.queue_free(); speech = null; wav = null; file = null; await create_timer(0.2).timeout
	print("COACH VOIX LOCALE : %d contrôles ; %d échec(s)" % [checks, failures.size()])
	call_deferred("quit", 0 if failures.is_empty() else 1)
