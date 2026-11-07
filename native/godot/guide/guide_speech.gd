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
var speaking := false
var status_text := "Mode texte · aucune voix française disponible sur ce PC."
var _id := 0
var _active := -1
var _callbacks := false
func setup(preferred: String, speed: float, quiet: bool) -> void:
	rate = clampf(speed, 0.5, 2.0); muted = quiet
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
	status_changed.emit()
func speak(text: String) -> void:
	stop()
	if muted or voice_id.is_empty() or text.is_empty(): return
	_id += 1; _active = _id
	requested.emit(text)
	DisplayServer.tts_speak(text, voice_id, 75, 1.0, rate, _active, true)
func stop() -> void:
	_active = -1
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
