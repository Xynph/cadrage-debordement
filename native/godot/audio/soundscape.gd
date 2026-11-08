extends Node
## Sons originaux de présentation : jamais une observation ou une décision moteur.
signal cue_played(id: String)
signal error_changed(message: String)
const Preferences = preload("res://audio/sound_preferences.gd")
const ASSETS := {
	"ui-tap": "ui-tap.wav", "ui-error": "ui-error.wav", "stadium-bed": "stadium-bed.wav",
	"stadium-try": "stadium-try.wav", "stadium-goal": "stadium-goal.wav", "stadium-miss": "stadium-miss.wav"
}
static var _bus_users := 0
static var _created_buses: Array[String] = []
static var _app_owners: Dictionary = {}
var preferences := Preferences.new()
var last_error := ""
var _app: Control
var _streams: Dictionary = {}
var _ui: AudioStreamPlayer
var _bed: AudioStreamPlayer
var _reaction: AudioStreamPlayer
var _registered := false
var _profile_ready := false
var _active := false
var _live_active := false
var _voice_active := false
var _bed_gain := 0.0
var _reaction_gain := 0.0
var _last_ui_ms := -1000
var _last_error_ms := -1000
var _last_reaction_ms := -1000
var _signature := ""
var _history: Array[String] = []
var _seen: Dictionary = {}
var _cursor := -1

func setup(app: Control) -> bool:
	if _registered:
		return true if app == _app else _fail("Ce gestionnaire sonore est déjà raccordé à un autre écran.")
	if not is_instance_valid(app) or not is_inside_tree() or not app.is_inside_tree():
		return _fail("Ajouter le gestionnaire sonore à l'arbre avant setup(app).")
	var app_id := app.get_instance_id()
	if _app_owners.has(app_id) and _app_owners[app_id].get_ref() != null:
		return _fail("Un gestionnaire sonore est déjà actif pour cet écran.")
	_app = app
	for id in ASSETS:
		var path := "res://audio/assets/" + str(ASSETS[id])
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else ResourceLoader.load(path) as AudioStreamWAV
		if stream == null:
			return _fail("Son local illisible : " + str(ASSETS[id]) + ". Aucun son de remplacement.")
		_streams[id] = stream
	if _bus_users == 0:
		_created_buses.clear()
		for label in ["Interface", "Stade"]:
			var index := AudioServer.get_bus_index(label)
			if index < 0:
				AudioServer.add_bus()
				index = AudioServer.bus_count - 1
				AudioServer.set_bus_name(index, label)
				_created_buses.append(label)
			AudioServer.set_bus_send(index, "Master")
	_bus_users += 1
	_registered = true
	_app_owners[app_id] = weakref(self)
	_ui = _player("InterfaceSound", "Interface")
	_bed = _player("StadiumBed", "Stade")
	_reaction = _player("StadiumReaction", "Stade")
	var bed_stream := (_streams["stadium-bed"] as AudioStreamWAV).duplicate() as AudioStreamWAV
	bed_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bed_stream.loop_begin = 0
	bed_stream.loop_end = bed_stream.data.size() / (4 if bed_stream.stereo else 2)
	_bed.stream = bed_stream
	preferences.changed.connect(apply_preferences)
	preferences.error_changed.connect(_preference_error)
	apply_preferences()
	if is_inside_tree():
		get_tree().node_added.connect(_node_added)
		_wire_tree(_app)
	return true

func _player(label: String, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = bus
	add_child(player)
	return player

func _fail(message: String) -> bool:
	last_error = message
	error_changed.emit(message)
	return false

func _preference_error(message: String) -> void:
	last_error = message
	error_changed.emit(message)

func load_profile(directory: String) -> bool:
	_profile_ready = preferences.load_profile(directory)
	apply_preferences()
	return _profile_ready

func apply_preferences() -> void:
	if not _registered:
		return
	for item in [["Interface", "interface_volume"], ["Stade", "stadium_volume"]]:
		var index := AudioServer.get_bus_index(item[0])
		if index < 0:
			_fail("Bus sonore disparu : " + str(item[0]))
			continue
		var value := preferences.get_value(item[1]) if _profile_ready else 0
		AudioServer.set_bus_volume_linear(index, float(value) / 100.0)
		AudioServer.set_bus_mute(index, value == 0)
	if not _profile_ready or preferences.get_value("interface_volume") == 0:
		_ui.stop()
	if not _profile_ready or preferences.get_value("stadium_volume") == 0:
		_bed.stop()
		_reaction.stop()
		_bed_gain = 0.0
		_reaction_gain = 0.0

func _node_added(node: Node) -> void:
	if node is BaseButton:
		call_deferred("_wire_button", node)

func _wire_tree(node: Node) -> void:
	if node == null:
		return
	if node is BaseButton:
		_wire_button(node)
	for child in node.get_children():
		_wire_tree(child)

func _wire_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or not is_instance_valid(_app) or not _app.is_ancestor_of(button):
		return
	var parent: Node = button
	while parent != _app and parent != null:
		if parent is LineEdit or parent is TextEdit or parent is Slider or parent is ScrollBar or parent is SpinBox:
			return
		var script: Script = parent.get_script()
		if script != null and script.resource_path.begins_with("res://guide/"):
			return
		if parent.name in ["CoachGuide", "Gabi", "CoachPortrait"]:
			return
		parent = parent.get_parent()
	var callback := _button_pressed.bind(button)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
		play_interface()

func play_interface() -> bool:
	return _play_ui("ui-tap")

func notify_error() -> bool:
	return _play_ui("ui-error")

func _play_ui(id: String) -> bool:
	if not _registered or not _profile_ready or preferences.get_value("interface_volume") == 0:
		return false
	var now := Time.get_ticks_msec()
	if id == "ui-error":
		if now - _last_error_ms < 150:
			return false
		_last_error_ms = now
	else:
		if now - _last_ui_ms < 60:
			return false
		_last_ui_ms = now
	_ui.stop()
	_ui.stream = _streams[id]
	_ui.play()
	cue_played.emit(id)
	return true

func set_voice_active(value: bool) -> void:
	# Atténue seulement le stade : aucun gain/état de Gabi ni de Master modifié.
	_voice_active = value

func refresh_visibility(route: String, live_visible: bool) -> void:
	_active = route == "Match" and live_visible and _live_active

func _process(delta: float) -> void:
	if not _registered:
		return
	var enabled := _active and _profile_ready and preferences.get_value("stadium_volume") > 0
	var desired := (0.35 if _voice_active else 1.0) if enabled else 0.0
	_bed_gain = move_toward(_bed_gain, desired, delta / 0.22)
	if enabled and not _bed.playing:
		_bed.play()
	_bed.volume_db = linear_to_db(_bed_gain) if _bed_gain > 0.0 else -80.0
	if not enabled and _bed_gain == 0.0:
		_bed.stop()
	_reaction_gain = move_toward(_reaction_gain, (0.55 if _voice_active else 1.0) if enabled else 0.0, delta / 0.12)
	_reaction.volume_db = linear_to_db(_reaction_gain) if _reaction_gain > 0.0 else -80.0
	if not enabled and _reaction_gain == 0.0:
		_reaction.stop()

func _match_signature(model: Dictionary, live: Dictionary) -> String:
	var meta: Dictionary = model.get("meta", {})
	var club: Dictionary = model.get("club", {}) if model.get("club") is Dictionary else {}
	return JSON.stringify([meta.get("dataDir"), meta.get("mode"), meta.get("season"), meta.get("round"), meta.get("phase"), club.get("id"), live.get("pair")])

func _displayed_index(live: Dictionary, events: Array) -> int:
	var scene: Dictionary = live.get("scene", {})
	var identity: Variant = JSON.parse_string(str(scene.get("key", "")))
	if not identity is Array or identity.size() != 4:
		return -1
	# The adapter key names an actual displayed event, not a prose classification.
	for index in events.size():
		var event: Variant = events[index]
		if not event is Dictionary or not event.get("scene") is Dictionary:
			continue
		var fact: Dictionary = event.scene
		if [event.get("min"), event.get("text"), fact.get("kind"), fact.get("to")] == identity:
			return index
	return -1

func _reaction_for(event: Variant) -> String:
	if not event is Dictionary or not event.get("scene") is Dictionary:
		return ""
	return {"try": "stadium-try", "goal": "stadium-goal", "miss": "stadium-miss"}.get(str(event.scene.get("kind", "")), "")

func observe_model(model: Dictionary, route: String, command: String = "snapshot", live_visible: bool = false, response_ok: bool = true) -> void:
	var live: Dictionary = model.get("live", {}) if model.get("live") is Dictionary else {}
	_live_active = not live.is_empty() and not live.get("paused", false) and not live.get("atBreak", false) and not live.get("finished", false)
	refresh_visibility(route, live_visible)
	if live.is_empty():
		_signature = ""
		_history.clear()
		_seen.clear()
		_cursor = -1
		return
	var events: Array = live.get("events", []) if live.get("events") is Array else []
	var signature := _match_signature(model, live)
	var history: Array[String] = []
	for event in events:
		history.append(JSON.stringify(event).sha256_text())
	var reset := signature != _signature or (response_ok and command in ["new_career", "import", "recover_profile", "load", "reset"])
	if not reset:
		if history.size() < _history.size():
			reset = true
		else:
			for index in _history.size():
				if history[index] != _history[index]:
					reset = true
					break
	var current := _displayed_index(live, events)
	if reset:
		_seen.clear()
		_cursor = current
	var forward := current > _cursor
	var cue := ""
	if current >= 0:
		var key := str(current) + ":" + history[current]
		if not reset and forward and not _seen.has(key) and response_ok and command == "tick" and _active:
			cue = _reaction_for(events[current])
		# Consume even while paused, muted, invisible, imported, resumed or sought.
		for index in current + 1:
			_seen[str(index) + ":" + history[index]] = true
	_signature = signature
	_history = history
	_cursor = current
	if not cue.is_empty():
		_play_reaction(cue)

func _play_reaction(id: String) -> bool:
	if not _registered or not _active or not _profile_ready or preferences.get_value("stadium_volume") == 0:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_reaction_ms < 350:
		return false
	_last_reaction_ms = now
	_reaction.stop()
	_reaction.stream = _streams[id]
	_reaction_gain = 0.55 if _voice_active else 1.0
	_reaction.volume_db = linear_to_db(_reaction_gain)
	_reaction.play()
	cue_played.emit(id)
	return true

func dispose() -> void:
	if not _registered:
		return
	_registered = false
	if is_instance_valid(_app):
		_app_owners.erase(_app.get_instance_id())
	if is_inside_tree() and get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.disconnect(_node_added)
	for node in [_ui, _bed, _reaction]:
		if is_instance_valid(node):
			node.stop()
			node.stream = null
			node.queue_free()
	_streams.clear()
	if preferences.changed.is_connected(apply_preferences):
		preferences.changed.disconnect(apply_preferences)
	if preferences.error_changed.is_connected(_preference_error):
		preferences.error_changed.disconnect(_preference_error)
	_bus_users = maxi(0, _bus_users - 1)
	if _bus_users == 0:
		for label in _created_buses:
			var index := AudioServer.get_bus_index(label)
			if index > 0:
				AudioServer.remove_bus(index)
		_created_buses.clear()

func _exit_tree() -> void:
	dispose()
