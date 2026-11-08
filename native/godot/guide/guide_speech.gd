extends Node
## DisplayServer callbacks belong to this single guide and are released on exit.
signal requested(text: String)
signal started(id: int)
signal ended(id: int)
signal speaking_changed(value: bool)
signal articulation_changed(value: float)
signal status_changed
const ENVELOPE_STEP := 0.04
const ENVELOPE_LIMIT := 8
const MAX_ENVELOPE_SECONDS := 30.0
const MAX_PCM_BYTES := 4 * 1024 * 1024
var voices: Array[Dictionary] = []
var voice_id := ""
var rate := 1.0
var muted := false
var volume := 75
var global_volume := 100
var _system_active := false
var speaking := false
var status_text := "Mode texte · aucune voix française disponible sur ce PC."
var _id := 0
var _active := -1
var _callbacks := false
var player: AudioStreamPlayer
var clips: Dictionary = {}
var _recordings_complete := false
## -1: system voice without PCM; 0/1: closed/open according to the local recording.
var articulation := 0.0
var _envelope := PackedFloat32Array()
var _envelope_cache: Dictionary = {}
var _envelope_order: Array[String] = []
var recording_status := "Voix enregistrée indisponible : repli sur la voix système."
var _voice_folder := "res://guide/assets/voice"
func load_manifest(source: String = "res://guide/assets/voice/manifest.json") -> void:
	stop(); clips.clear(); _voice_folder = source.get_base_dir()
	_recordings_complete = false
	_envelope_cache.clear(); _envelope_order.clear()
	recording_status = "Voix enregistrée indisponible : repli sur la voix système."
	if FileAccess.file_exists(source):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(source))
		if parsed is Dictionary and parsed.get("clips") is Array:
			var current: Dictionary = {}
			var expected_total := 0
			var bundled := source == "res://guide/assets/voice/manifest.json"
			if bundled:
				var content: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
				if content is Dictionary:
					for page: Dictionary in content.get("pages",[]):
						for fragment: Dictionary in page.get("fragments",[]):
							expected_total += 1
							if fragment.get("audioStatus") != "pending": current[str(fragment.id)] = str(fragment.text)
			for clip in parsed.clips:
				if not clip is Dictionary: continue
				var text := str(clip.get("text", "")); var filename := str(clip.get("file", ""))
				# Old WAVs remain archived; only the exact active line can be played.
				if bundled and current.get(str(clip.get("id",""))) != text: continue
				if text.is_empty() or str(clip.get("text_sha256", "")) != text.sha256_text(): continue
				if filename != filename.get_file() or not filename.ends_with(".wav"): continue
				var path := _voice_folder.path_join(filename)
				if not FileAccess.file_exists(path) and not ResourceLoader.exists(path): continue
				if FileAccess.file_exists(path) and clip.has("sha256") and str(clip.sha256).to_lower() != FileAccess.get_sha256(path).to_lower(): continue
				clips[text] = path
			_recordings_complete = bundled and expected_total > 0 and clips.size() == expected_total
			if _recordings_complete: recording_status = "Voix de Gabi enregistrée · " + str(clips.size()) + " bulles locales."
			elif not clips.is_empty(): recording_status = "Voix provisoire de Gabi · " + str(clips.size()) + " bulles locales. Les nouveaux textes utilisent la voix système provisoire si disponible."
			else: recording_status = "Voix enregistrée invalide ou absente : repli sur la voix système."
		else: recording_status = "Manifeste vocal illisible : repli sur la voix système."
	_update_status()
func has_recording(text: String) -> bool:
	return clips.has(text)
func has_complete_recordings() -> bool:
	return _recordings_complete

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
	if not clips.is_empty(): status_text = ("Voix de Gabi · " if _recordings_complete else "Voix provisoire de Gabi · ") + ("muette" if muted else "prête")
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
			_envelope = _recording_envelope(path, stream)
			_set_articulation(0.0 if not _envelope.is_empty() else -1.0, true)
			player.volume_db = linear_to_db(float(clampi(volume,0,100)) / 100.0) if volume > 0 else -80.0
			requested.emit(text); player.play(); _started(_active); return
		_recordings_complete = false
		recording_status = "Clip local illisible : repli sur la voix système."; _update_status()
	if voice_id.is_empty(): return
	_id += 1; _active = _id
	_set_articulation(-1.0)
	requested.emit(text)
	_system_active = true
	_speak_system(text, roundi(float(clampi(volume, 0, 100)) * global_volume / 100.0), _active)
func _speak_system(text: String, gain: int, id: int) -> void:
	DisplayServer.tts_speak(text, voice_id, gain, 1.0, rate, id, true)
func _stop_system() -> void:
	DisplayServer.tts_stop()

func _recording_envelope(path: String, stream: AudioStreamWAV) -> PackedFloat32Array:
	if _envelope_cache.has(path): return _envelope_cache[path]
	# Sample PCM once per recording, never in the frame loop. Unsupported or
	# oversized streams keep the existing cosmetic cadence instead of stalling UI.
	var envelope := PackedFloat32Array()
	if stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.get_length() <= MAX_ENVELOPE_SECONDS:
		var pcm := stream.data
		if pcm.size() <= MAX_PCM_BYTES and stream.mix_rate > 0:
			var channels := 2 if stream.stereo else 1
			var frames := int(pcm.size() / (2 * channels))
			var window := maxi(1, roundi(stream.mix_rate * ENVELOPE_STEP))
			for start in range(0, frames, window):
				var sum_squares := 0.0; var samples := 0
				for frame in range(start, mini(start + window, frames), 8):
					for channel in channels:
						var value := float(pcm.decode_s16((frame * channels + channel) * 2)) / 32768.0
						sum_squares += value * value; samples += 1
				envelope.append(sqrt(sum_squares / maxf(1.0, samples)))
	if _envelope_order.size() >= ENVELOPE_LIMIT:
		_envelope_cache.erase(_envelope_order.pop_front())
	_envelope_order.append(path); _envelope_cache[path] = envelope
	return envelope

func _process(_delta: float) -> void:
	if not speaking or _envelope.is_empty() or not is_instance_valid(player) or not player.playing: return
	# Playback position is in source seconds, so changing pitch/debit also moves
	# the mouth at the correct point. Account for the current audio mixing block.
	var source_time := maxf(0.0, player.get_playback_position() + (AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()) * player.pitch_scale)
	var index := int(source_time / ENVELOPE_STEP)
	_set_articulation(1.0 if index < _envelope.size() and _envelope[index] >= 0.018 else 0.0)

func _set_articulation(value: float, force: bool = false) -> void:
	if articulation == value and not force: return
	articulation = value; articulation_changed.emit(value)
func set_global_volume(value: int) -> void:
	var next := clampi(value, 0, 100)
	if next == global_volume: return
	# System TTS bypasses Master and cannot change gain during an utterance.
	# Stop the old gain immediately; the visible bubble can be replayed normally.
	if _system_active: stop()
	global_volume = next
func stop() -> void:
	_active = -1
	_envelope = PackedFloat32Array(); _set_articulation(0.0)
	if is_instance_valid(player): player.stop()
	if _callbacks or _system_active: _stop_system()
	_system_active = false
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
	_envelope = PackedFloat32Array(); _set_articulation(0.0)
	_active = -1; _system_active = false; speaking = false; speaking_changed.emit(false); ended.emit(id)
func _exit_tree() -> void:
	stop()
	if _callbacks:
		for event in [DisplayServer.TTS_UTTERANCE_STARTED,DisplayServer.TTS_UTTERANCE_ENDED,DisplayServer.TTS_UTTERANCE_CANCELED]:
			DisplayServer.tts_set_utterance_callback(event, Callable())
	_callbacks = false
