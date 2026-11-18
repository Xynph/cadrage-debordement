extends Node
## Sons originaux de présentation : jamais une observation ou une décision moteur.
signal cue_played(id: String)
signal error_changed(message: String)
## Couleur de la foule (« joie », « deception », « sifflets ») : s'ajoute à cue_played, qui garde les mêmes identifiants.
signal crowd_mood(mood: String)
const Preferences = preload("res://audio/sound_preferences.gd")
const ASSETS := {
	"ui-tap": "ui-tap.wav", "ui-error": "ui-error.wav", "stadium-bed": "stadium-bed.wav",
	"stadium-try": "stadium-try.wav", "stadium-goal": "stadium-goal.wav", "stadium-miss": "stadium-miss.wav"
}
## Sifflets de foule (scripts/build-native-crowd.cjs), hors ASSETS : l'ensemble figé des six sons d'origine reste inchangé.
const EXTRA := {"crowd-whistle": "crowd-whistle.wav"}
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
## Match en temps forts : la vue rejoue un instant déjà simulé.
var _presenting := false
var _shown := false
var _voice_active := false
var _bed_gain := 0.0
var _reaction_gain := 0.0
var _reaction_scale := 1.0
var _last_ui_ms := -1000
var _last_error_ms := -1000
var _last_reaction_ms := -1000
var _last_reaction_priority := 0
## Temps de jeu (ms) cumulé par _process : suit le rythme du direct (ralenti, image lente) et se fige
## quand l'arbre est en pause. Remplaçable par une horloge fournie (tests) : Callable sans argument, en ms.
var _game_ms := 0
var game_clock := Callable()
## Deux réactions plus proches que cela (temps de jeu) : la plus importante gagne.
const REACTION_WINDOW_MS := 350
## Importance d'une réaction : essai > transformation > tentative manquée > sifflets de pénalité.
const REACTION_PRIORITY := {"stadium-try": 4, "stadium-goal": 3, "stadium-miss": 2, "crowd-whistle": 1}
## Clameur (19/11/2026) : une seconde couche de l'ambiance, plus aiguë, dont le gain suit l'intensité
## de la foule (match_foule.gd) : rumeur au repos, enfle dans les 22 mètres, explose à l'essai, retombe.
## La couche d'ambiance d'origine (_bed) garde exactement son gain.
const Foule = preload("res://match_foule.gd")
const CLAMEUR_PITCH := 1.18
## Sifflet de l'arbitre à chaque arrêt de jeu : joué seulement si ce son existe dans les ressources.
## Aucun n'existe au 19/11/2026 (crowd-whistle.wav est un sifflet de foule) : l'arrêt est alors
## seulement noté dans la trace (« arret-sans-sifflet »).
const SIFFLET_ARBITRE := "res://audio/assets/referee-whistle.wav"
const TRACE_MAX := 64
var _clameur: AudioStreamPlayer
var _sifflet: AudioStreamPlayer
var _clameur_gain := 0.0
## Foule suivie : celle de la vue 3D (régie des temps forts, suivre_foule) ; sinon celle du direct
## d'origine, nourrie par observe_model.
var _foule_vue: Foule
var _foule_direct: Foule = Foule.new()
## Sons décidés depuis la dernière lecture (etat_foule) : réactions et arrêts, même son coupé
## (le match filmé tourne sans son).
var _trace_sons: Array[String] = []
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
	for table in [ASSETS, EXTRA]:
		for id in table:
			var path := "res://audio/assets/" + str(table[id])
			var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else ResourceLoader.load(path) as AudioStreamWAV
			if stream == null:
				return _fail("Son local illisible : " + str(table[id]) + ". Aucun son de remplacement.")
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
	_clameur = _player("StadiumClameur", "Stade")
	_clameur.stream = bed_stream
	_clameur.pitch_scale = CLAMEUR_PITCH
	_clameur.volume_db = -80.0
	_sifflet = _player("RefereeWhistle", "Stade")
	if ResourceLoader.exists(SIFFLET_ARBITRE) or FileAccess.file_exists(SIFFLET_ARBITRE):
		var sifflet: AudioStreamWAV = AudioStreamWAV.load_from_file(SIFFLET_ARBITRE) if FileAccess.file_exists(SIFFLET_ARBITRE) else ResourceLoader.load(SIFFLET_ARBITRE) as AudioStreamWAV
		if sifflet != null:
			_streams["referee-whistle"] = sifflet
	_brancher_foule(_foule_direct)
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
	if not _profile_ready or preferences.get_value("stadium_volume") == 0 or not preferences.get_flag("match_sounds"):
		_bed.stop()
		_reaction.stop()
		_clameur.stop()
		_sifflet.stop()
		_bed_gain = 0.0
		_reaction_gain = 0.0
		_clameur_gain = 0.0

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
	_shown = route == "Match" and live_visible
	_active = _shown and (_live_active or _presenting)

## Match en temps forts : le stade s'entend pendant un temps fort rejoué, même si le
## moteur est déjà à la mi-temps ou au coup de sifflet final.
func set_presenting(value: bool) -> void:
	_presenting = value
	_active = _shown and (_live_active or _presenting)

## Match en temps forts : la réaction du stade part quand l'action est à l'écran.
## « team » : camp (0 domicile, 1 extérieur) qui marque, tire ou obtient la pénalité ; -1 si inconnu (réaction neutre).
func play_shown(kind: String, team: int = -1) -> bool:
	var cue := _crowd_cue(kind, team)
	if not cue.is_empty():
		_tracer(cue.id)
	return not cue.is_empty() and _play_reaction(cue.id, cue.mood)

## Foule de la vue 3D (match_view.gd `foule`) : l'intensité de la clameur et les sifflets d'arrêt
## suivent alors les images montrées. null : retour à la foule du direct d'origine.
func suivre_foule(foule: Foule) -> void:
	if foule == _foule_vue:
		return
	# Une foule qui n'est plus suivie peut encore émettre : _arret_de_jeu l'ignore.
	_foule_vue = foule
	if foule != null:
		_brancher_foule(foule)

func _brancher_foule(foule: Foule) -> void:
	var reaction := _arret_de_jeu.bind(foule)
	if not foule.arret.is_connected(reaction):
		foule.arret.connect(reaction)

## Foule qui pilote le son : celle de la vue quand une régie l'a confiée, sinon celle du direct.
func foule_active() -> Foule:
	return _foule_vue if _foule_vue != null else _foule_direct

func _arret_de_jeu(_kind: String, foule: Foule) -> void:
	if foule != foule_active():
		return
	if not _streams.has("referee-whistle"):
		_tracer("arret-sans-sifflet")
		return
	_tracer("sifflet-arbitre")
	if not _registered or not _active or not _profile_ready or preferences.get_value("stadium_volume") == 0 or not preferences.get_flag("match_sounds"):
		return
	_sifflet.stop()
	_sifflet.stream = _streams["referee-whistle"]
	_sifflet.volume_db = linear_to_db(0.55 if _voice_active else 0.8)
	_sifflet.play()
	cue_played.emit("referee-whistle")

func _tracer(id: String) -> void:
	_trace_sons.append(id)
	if _trace_sons.size() > TRACE_MAX:
		_trace_sons.remove_at(0)

## Trace vérifiable (match filmé) : intensité de la foule (0 à 1), part du public debout (en %),
## sons décidés depuis la lecture précédente (vidés si `vider`), gain de la clameur.
func etat_foule(vider: bool = true) -> Dictionary:
	var etat := foule_active().etat()
	etat["sons"] = _trace_sons.duplicate()
	etat["clameur"] = snappedf(_clameur_gain, 0.001)
	if vider:
		_trace_sons.clear()
	return etat

## Gain visé de la clameur pour une intensité : nul à la rumeur du repos, plein à l'essai.
static func gain_clameur(intensite: float) -> float:
	return smoothstep(Foule.CALME, Foule.ESSAI, intensite)

## Foule du stade = camp domicile (0). Essai ou transformation à domicile : montée ; adverse : déception ;
## pénalité accordée à l'extérieur (donc contre le domicile) : sifflets. Renvoie {} sans réaction.
func _crowd_cue(kind: String, team: int) -> Dictionary:
	match kind:
		"try", "goal":
			return {"id": "stadium-" + kind, "mood": "deception" if team == 1 else "joie"}
		"miss":
			return {"id": "stadium-miss", "mood": "joie"}
		"penalty":
			return {"id": "crowd-whistle", "mood": "sifflets"} if team == 1 else {}
	return {}

func _game_time_ms() -> int:
	return int(game_clock.call()) if game_clock.is_valid() else _game_ms

func _process(delta: float) -> void:
	_game_ms += int(delta * 1000.0)
	if not _registered:
		return
	var enabled := _active and _profile_ready and preferences.get_value("stadium_volume") > 0 and preferences.get_flag("match_sounds")
	var desired := (0.35 if _voice_active else 1.0) if enabled else 0.0
	_bed_gain = move_toward(_bed_gain, desired, delta / 0.22)
	if enabled and not _bed.playing:
		_bed.play()
	_bed.volume_db = linear_to_db(_bed_gain) if _bed_gain > 0.0 else -80.0
	if not enabled and _bed_gain == 0.0:
		_bed.stop()
	_reaction_gain = move_toward(_reaction_gain, (0.55 if _voice_active else 1.0) * _reaction_scale if enabled else 0.0, delta / 0.12)
	_reaction.volume_db = linear_to_db(_reaction_gain) if _reaction_gain > 0.0 else -80.0
	if not enabled and _reaction_gain == 0.0:
		_reaction.stop()
	# La foule du direct d'origine avance ici ; celle de la vue avance avec la vue (match_view.gd).
	if _foule_vue == null:
		_foule_direct.avancer(delta)
	var clameur := gain_clameur(foule_active().intensite) * (0.45 if _voice_active else 0.85) if enabled else 0.0
	# Suit l'intensité (déjà lissée) ; coupe franche quand le stade se tait.
	_clameur_gain = move_toward(_clameur_gain, clameur, delta / 0.25)
	if enabled and _clameur_gain > 0.0 and not _clameur.playing:
		_clameur.play()
	_clameur.volume_db = linear_to_db(_clameur_gain) if _clameur_gain > 0.0 else -80.0
	if _clameur_gain == 0.0 and _clameur.playing:
		_clameur.stop()

func _match_signature(model: Dictionary, live: Dictionary) -> String:
	var meta: Dictionary = model.get("meta", {})
	var club: Dictionary = model.get("club", {}) if model.get("club") is Dictionary else {}
	return JSON.stringify([meta.get("dataDir"), meta.get("mode"), meta.get("season"), meta.get("round"), meta.get("phase"), club.get("id"), live.get("pair")])

func _displayed_index(live: Dictionary, events: Array) -> int:
	var scene: Dictionary = live.get("scene", {})
	var key := str(scene.get("key", ""))
	if key.is_empty():
		return -1
	var identity: Variant = JSON.parse_string(key)
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

func _crowd_cue_for(event: Variant) -> Dictionary:
	if not event is Dictionary or not event.get("scene") is Dictionary:
		return {}
	var fact: Dictionary = event.scene
	var team = fact.get("team", -1)
	return _crowd_cue(str(fact.get("kind", "")), int(team) if typeof(team) in [TYPE_INT, TYPE_FLOAT] else -1)

func observe_model(model: Dictionary, route: String, command: String = "snapshot", live_visible: bool = false, response_ok: bool = true) -> void:
	var live: Dictionary = model.get("live", {}) if model.get("live") is Dictionary else {}
	_live_active = not live.is_empty() and not live.get("paused", false) and not live.get("atBreak", false) and not live.get("finished", false)
	if live.is_empty(): _presenting = false
	# Foule : celle de la vue est oubliée hors match ; le direct d'origine nourrit la sienne.
	if live.is_empty(): suivre_foule(null)
	elif not live.get("direct") is Dictionary: _foule_direct.observer(live)
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
	var cue: Dictionary = {}
	if current >= 0:
		var key := str(current) + ":" + history[current]
		# En temps forts, le moteur a une minute d'avance sur l'écran : la régie déclenche
		# elle-même la réaction quand l'action est montrée (play_shown).
		if not reset and forward and not _seen.has(key) and response_ok and command == "tick" and _active and not live.get("direct") is Dictionary:
			cue = _crowd_cue_for(events[current])
		# Consume even while paused, muted, invisible, imported, resumed or sought.
		for index in current + 1:
			_seen[str(index) + ":" + history[index]] = true
	_signature = signature
	_history = history
	_cursor = current
	if not cue.is_empty():
		_tracer(cue.id)
		_play_reaction(cue.id, cue.mood)

func _play_reaction(id: String, mood: String = "joie") -> bool:
	if not _registered or not _active or not _profile_ready or preferences.get_value("stadium_volume") == 0 or not preferences.get_flag("match_sounds"):
		return false
	var now := _game_time_ms()
	var priority: int = REACTION_PRIORITY.get(id, 1)
	# Anti-rebond en temps de jeu. Dans la fenêtre, seule une réaction strictement plus importante
	# remplace celle en cours ; une réaction rejetée ne change pas le repère (résultat indépendant de l'ordre).
	if now - _last_reaction_ms < REACTION_WINDOW_MS and priority <= _last_reaction_priority:
		return false
	_last_reaction_ms = now
	_last_reaction_priority = priority
	_reaction.stop()
	# Déception : le même souffle que la tentative manquée, plus grave et plus bas.
	_reaction.stream = _streams["stadium-miss" if mood == "deception" else id]
	_reaction.pitch_scale = 0.8 if mood == "deception" else 1.0
	_reaction_scale = 0.75 if mood == "deception" else 1.0
	_reaction_gain = (0.55 if _voice_active else 1.0) * _reaction_scale
	_reaction.volume_db = linear_to_db(_reaction_gain)
	_reaction.play()
	crowd_mood.emit(mood)
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
	for node in [_ui, _bed, _reaction, _clameur, _sifflet]:
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
