extends Node
## DisplayServer callbacks belong to this single guide and are released on exit.
signal requested(text: String)
signal started(id: int)
signal ended(id: int)
signal speaking_changed(value: bool)
signal status_changed
var voices: Array[Dictionary] = []
var voice_id := ""
var rate := 1.0
var muted := false
var volume := 75
var speaking := false
var status_text := "Mode texte · aucune voix française disponible sur ce PC."
var _id := 0
var _active := -1
var _callbacks := false
var player: AudioStreamPlayer
var clips: Dictionary = {}
var recording_status := "Voix enregistrée indisponible : repli sur la voix système."
var _voice_folder := "res://guide/assets/voice"
func load_manifest(source: String = "res://guide/assets/voice/manifest.json") -> void:
	stop(); clips.clear(); _voice_folder = source.get_base_dir()
	recording_status = "Voix enregistrée indisponible : repli sur la voix système."
	if FileAccess.file_exists(source):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(source))
		if parsed is Dictionary and parsed.get("clips") is Array:
			for clip in parsed.clips:
				if not clip is Dictionary: continue
				var text := str(clip.get("text", "")); var filename := str(clip.get("file", ""))
				if text.is_empty() or str(clip.get("text_sha256", "")) != text.sha256_text(): continue
				if filename != filename.get_file() or not filename.ends_with(".wav"): continue
				var path := _voice_folder.path_join(filename)
				if not FileAccess.file_exists(path) and not ResourceLoader.exists(path): continue
				if FileAccess.file_exists(path) and clip.has("sha256") and str(clip.sha256).to_lower() != FileAccess.get_sha256(path).to_lower(): continue
				clips[text] = path
			if not clips.is_empty(): recording_status = "Voix provisoire de Gabi · " + str(clips.size()) + " bulles locales. Les nouveaux textes utilisent la voix système provisoire si disponible."
			else: recording_status = "Voix enregistrée invalide ou absente : repli sur la voix système."
		else: recording_status = "Manifeste vocal illisible : repli sur la voix système."
	_update_status()
func has_recording(text: String) -> bool:
	return clips.has(text)

func setup(preferred: String, speed: float, quiet: bool) -> void:
	rate = clampf(speed, 0.5, 2.0); muted = quiet
	player = AudioStreamPlayer.new(); player.name = "GabiRecordedVoice"; add_child(player)
	player.finished.connect(func():
		if _active >= 0: _ended(_active)
	)
	load_manifest()
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		for voice: Dictionary in DisplayServer.tts_get_voices():
			if str(voice.get("language", "")).to_lower().replace("_", "-").begins_with("fr"):
				voices.append(voice)
	if not voices.is_empty():
		voice_id = str(voices[0].id)
		if preferred.is_empty():
			for voice in voices:
				if str(voice.get("name", "")).to_lower().contains("paul"): voice_id = str(voice.id)
		for voice in voices:
			if str(voice.id) == preferred: voice_id = preferred
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED, _started)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _ended)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _ended)
		_callbacks = true
	_update_status()
func _update_status() -> void:
	status_text = "Mode texte · aucune voix française disponible sur ce PC."
	if not voice_id.is_empty(): status_text = "Voix système provisoire · " + ("muette" if muted else "prête")
	if not clips.is_empty(): status_text = "Voix provisoire de Gabi · " + ("muette" if muted else "prête")
	status_text += "\n" + recording_status
	status_changed.emit()
func speak(text: String) -> void:
	stop()
	if muted or text.is_empty(): return
	if has_recording(text) and is_instance_valid(player):
		var path: String = str(clips[text])
		# PCK exports remap WAV sources to imported AudioStreamWAV resources.
		var stream: AudioStreamWAV = ResourceLoader.load(path) as AudioStreamWAV if ResourceLoader.exists(path) else AudioStreamWAV.load_from_file(path)
		if stream != null:
			_id += 1; _active = _id
			player.stream = stream; player.pitch_scale = rate
			player.volume_db = linear_to_db(float(clampi(volume,0,100)) / 100.0) if volume > 0 else -80.0
			requested.emit(text); player.play(); _started(_active); return
		recording_status = "Clip local illisible : repli sur la voix système."; _update_status()
	if voice_id.is_empty(): return
	_id += 1; _active = _id
	requested.emit(text)
	DisplayServer.tts_speak(text, voice_id, clampi(volume, 0, 100), 1.0, rate, _active, true)
func stop() -> void:
	_active = -1
	if is_instance_valid(player): player.stop()
	if _callbacks: DisplayServer.tts_stop()
	if speaking: speaking = false; speaking_changed.emit(false)
func set_muted(value: bool) -> void:
	stop(); muted = value; _update_status()
func configure(voice: String, speed: float) -> void:
	stop()
	if voices.any(func(item): return str(item.id) == voice): voice_id = voice
	rate = clampf(speed, 0.5, 2.0)
	_update_status()
func _started(id: int) -> void:
	if id != _active: return
	speaking = true; speaking_changed.emit(true); started.emit(id)
func _ended(id: int) -> void:
	if id != _active: return
	_active = -1; speaking = false; speaking_changed.emit(false); ended.emit(id)
func _exit_tree() -> void:
	stop()
	if _callbacks:
		for event in [DisplayServer.TTS_UTTERANCE_STARTED,DisplayServer.TTS_UTTERANCE_ENDED,DisplayServer.TTS_UTTERANCE_CANCELED]:
			DisplayServer.tts_set_utterance_callback(event, Callable())
	_callbacks = false
