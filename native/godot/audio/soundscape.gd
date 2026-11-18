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
## Sifflets de foule et bruits de match (scripts/build-native-crowd.cjs), hors ASSETS : l'ensemble figé
## des six sons d'origine reste inchangé.
const EXTRA := {"crowd-whistle": "crowd-whistle.wav", "crowd-groan": "crowd-groan.wav", "crowd-applause": "crowd-applause.wav",
	"crowd-murmur": "crowd-murmur.wav", "referee-whistle": "referee-whistle.wav", "referee-whistle-long": "referee-whistle-long.wav",
	"impact-tackle": "impact-tackle.wav", "impact-scrum": "impact-scrum.wav", "kick-pock": "kick-pock.wav"}
## Bruits de match hors foule (bus Stade) : gain relatif, anti-rebond en temps de jeu (ms), écarts aléatoires
## de hauteur et de volume (± part) pour que deux plaquages ne sonnent jamais à l'identique.
const EFFECTS := {
	"referee-whistle": {"gain": 0.8, "cooldown": 700, "pitch": 0.03, "volume": 0.08},
	"referee-whistle-long": {"gain": 0.85, "cooldown": 3000, "pitch": 0.0, "volume": 0.0},
	"impact-tackle": {"gain": 0.85, "cooldown": 250, "pitch": 0.12, "volume": 0.2},
	"impact-scrum": {"gain": 1.0, "cooldown": 1500, "pitch": 0.06, "volume": 0.12},
	"kick-pock": {"gain": 0.9, "cooldown": 250, "pitch": 0.08, "volume": 0.15},
}
## Fait de match montré → bruits : [identifiant, délai en ms de jeu]. « kick » : frappe de balle
## (tir au but, transformation, renvoi, jeu au pied) ; « tackle » : fin d'une course plaquée ;
## « break »/« end » : mi-temps et fin du match.
const EFFECTS_FOR := {
	"kickoff": [["referee-whistle", 0], ["kick-pock", 450]],
	"kick": [["kick-pock", 0]], "drop22": [["kick-pock", 0]], "goalLine": [["kick-pock", 0]],
	"penalty": [["referee-whistle", 0]], "hand-fault": [["referee-whistle", 0]],
	"card": [["referee-whistle", 0]], "ingoal": [["referee-whistle", 0]], "try": [["referee-whistle", 200]],
	"scrum": [["impact-scrum", 450]], "tackle": [["impact-tackle", 0]], "turnover": [["impact-tackle", 0]],
	"break": [["referee-whistle-long", 0]], "end": [["referee-whistle-long", 0]],
}
## Rumeur qui monte : fait de jeu courant ou de conquête à moins de MURMUR_RANGE mètres de la ligne
## adverse du camp en possession. Les faits listés dans MURMUR_KEEP ne la changent pas.
const MURMUR_KINDS := ["carry", "setpiece-win", "lineout", "scrum", "reception"]
const MURMUR_KEEP := ["tackle"]
const MURMUR_RANGE := 22.0
const MURMUR_GAIN := 0.7
## Sans nouveau fait près de la ligne pendant ce temps de jeu, la rumeur retombe d'elle-même.
const MURMUR_HOLD_MS := 6000
## Essai à domicile : les applaudissements prennent le relais de la clameur, en fondu.
const HOME_TRY_TAIL_MS := 1200
const BREAK_APPLAUSE_MS := 900
## Bruits de match joués (arbitre, impacts, ballon, rumeur) : à part de cue_played, réservé à la foule et à l'interface.
signal effect_played(id: String)
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
## Réaction précédente qui s'efface en fondu quand une nouvelle la remplace (jamais de coupure sèche).
var _reaction_out: AudioStreamPlayer
var _reaction_out_gain := 0.0
var _whistle: AudioStreamPlayer
var _impacts: Array[AudioStreamPlayer] = []
var _impact_next := 0
var _murmur: AudioStreamPlayer
var _murmur_gain := 0.0
var _murmur_target := 0.0
var _murmur_since := 0
var _effect_last: Dictionary = {}
## Bruits différés : [{at, id, crowd, mood, live}] en temps de jeu.
var _pending: Array[Dictionary] = []
## Hasard des seules variations de hauteur/volume : graine fixe, jamais le RNG du jeu.
var _rng := RandomNumberGenerator.new()
## Dernier état « mi-temps / fin » vu par le direct d'origine (hors temps forts).
var _last_stop := "?"
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
const REACTION_PRIORITY := {"stadium-try": 4, "stadium-goal": 3, "stadium-miss": 2, "crowd-whistle": 1, "crowd-groan": 1, "crowd-applause": 1}
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
	_reaction_out = _player("StadiumReactionFade", "Stade")
	_whistle = _player("RefereeWhistle", "Stade")
	_impacts = [_player("MatchImpactA", "Stade"), _player("MatchImpactB", "Stade")]
	_murmur = _player("CrowdMurmur", "Stade")
	var murmur_stream := (_streams["crowd-murmur"] as AudioStreamWAV).duplicate() as AudioStreamWAV
	murmur_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	murmur_stream.loop_begin = 0
	murmur_stream.loop_end = murmur_stream.data.size() / (4 if murmur_stream.stereo else 2)
	_murmur.stream = murmur_stream
	_rng.seed = 272730
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
	if not _profile_ready or preferences.get_value("stadium_volume") == 0 or not preferences.get_flag("match_sounds"):
		_bed.stop()
		_bed_gain = 0.0
		_stop_match_sounds()

## Coupe net tout ce qui suit le direct (réactions, arbitre, impacts, rumeur, bruits différés) : réglage
## à zéro, sons de match décochés, gestionnaire libéré.
func _stop_match_sounds() -> void:
	for player in [_reaction, _reaction_out, _whistle, _murmur] + _impacts:
		if is_instance_valid(player):
			player.stop()
	_reaction_gain = 0.0
	_reaction_out_gain = 0.0
	_murmur_gain = 0.0
	_murmur_target = 0.0
	_pending.clear()

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
## « distance » : mètres entre le fait et la ligne d'essai adverse du camp en possession (-1 inconnu) ;
## elle règle la rumeur. Arbitre, impacts et ballon partent aussi d'ici (effect_played) ; le booléen
## rendu ne dit que si la foule a réagi.
func play_shown(kind: String, team: int = -1, distance: float = -1.0) -> bool:
	_update_murmur(kind, distance)
	_play_effects(kind)
	if kind in ["break", "end"]:
		_schedule("crowd-applause", BREAK_APPLAUSE_MS, true, "joie", false)
		return false
	var cue := _crowd_cue(kind, team)
	if cue.is_empty() or not _play_reaction(cue.id, cue.mood):
		return false
	if kind == "try" and cue.mood == "joie":
		_schedule("crowd-applause", HOME_TRY_TAIL_MS, true, "joie")
	return true

## Foule du stade = camp domicile (0). Essai ou transformation à domicile : montée ; adverse : déception ;
## tir manqué : soulagement si l'adversaire tirait, « oooh » si c'était le domicile ;
## pénalité accordée à l'extérieur (donc contre le domicile) : sifflets ; en-avant du domicile : « oooh » ;
## ballon récupéré par le domicile : applaudissements. Renvoie {} sans réaction.
## « team » : camp qui marque, tire, obtient la pénalité, commet l'en-avant ou récupère le ballon.
func _crowd_cue(kind: String, team: int) -> Dictionary:
	match kind:
		"try", "goal":
			return {"id": "stadium-" + kind, "mood": "deception" if team == 1 else "joie"}
		"miss":
			return {"id": "stadium-miss", "mood": "deception" if team == 0 else "joie"}
		"penalty":
			return {"id": "crowd-whistle", "mood": "sifflets"} if team == 1 else {}
		"hand-fault":
			return {"id": "crowd-groan", "mood": "deception"} if team == 0 else {}
		"turnover":
			return {"id": "crowd-applause", "mood": "joie"} if team == 0 else {}
	return {}

## Sons de match permis : direct visible et actif (ou, pour la mi-temps et la fin, Match seulement affiché).
func _match_audible(live_only: bool = true) -> bool:
	return _registered and (_active if live_only else _shown) and _profile_ready and preferences.get_value("stadium_volume") > 0 and preferences.get_flag("match_sounds")

func _play_effects(kind: String) -> void:
	for item: Array in EFFECTS_FOR.get(kind, []):
		if int(item[1]) <= 0:
			_play_effect(str(item[0]), kind not in ["break", "end"])
		else:
			_schedule(str(item[0]), int(item[1]), false, "", kind not in ["break", "end"])

func _schedule(id: String, delay_ms: int, crowd: bool, mood: String = "", live_only: bool = true) -> void:
	if not _match_audible(live_only):
		return
	_pending.append({"at": _game_time_ms() + delay_ms, "id": id, "crowd": crowd, "mood": mood, "live": live_only})

## Un bruit de match : anti-rebond par identifiant (temps de jeu), petite variation de hauteur et de volume.
func _play_effect(id: String, live_only: bool = true) -> bool:
	if not _match_audible(live_only) or not EFFECTS.has(id):
		return false
	var spec: Dictionary = EFFECTS[id]
	var now := _game_time_ms()
	if _effect_last.has(id) and now - int(_effect_last[id]) < int(spec.cooldown):
		return false
	_effect_last[id] = now
	var player: AudioStreamPlayer = _whistle
	if not id.begins_with("referee-"):
		player = _impacts[_impact_next]
		_impact_next = (_impact_next + 1) % _impacts.size()
	player.stop()
	player.stream = _streams[id]
	player.pitch_scale = 1.0 + _rng.randf_range(-float(spec.pitch), float(spec.pitch))
	var gain := float(spec.gain) * (1.0 + _rng.randf_range(-float(spec.volume), float(spec.volume))) * (0.6 if _voice_active else 1.0)
	player.volume_db = linear_to_db(gain)
	player.play()
	effect_played.emit(id)
	return true

## Rumeur : monte quand l'attaque approche de la ligne adverse, retombe sur tout autre fait (le
## coup de sifflet, l'essai, le jeu au pied) ; la clameur ou l'« oooh » prennent le relais en fondu.
func _update_murmur(kind: String, distance: float) -> void:
	if kind in MURMUR_KEEP:
		return
	if kind in MURMUR_KINDS and distance >= 0.0 and distance <= MURMUR_RANGE:
		if not _match_audible():
			return
		if _murmur_target <= 0.0:
			effect_played.emit("crowd-murmur")
		_murmur_target = lerpf(0.45, 1.0, 1.0 - distance / MURMUR_RANGE)
		_murmur_since = _game_time_ms()
	else:
		_murmur_target = 0.0

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
	# La mi-temps et la fin se jouent direct arrêté : seul l'affichage de Match compte pour elles.
	var shown_enabled := _match_audible(false)
	_reaction_gain = move_toward(_reaction_gain, (0.55 if _voice_active else 1.0) * _reaction_scale if shown_enabled else 0.0, delta / 0.12)
	_reaction.volume_db = linear_to_db(_reaction_gain) if _reaction_gain > 0.0 else -80.0
	if not shown_enabled and _reaction_gain == 0.0:
		_reaction.stop()
	# Réaction remplacée : elle s'efface en un quart de seconde sous la nouvelle.
	_reaction_out_gain = move_toward(_reaction_out_gain, 0.0, delta / 0.25)
	_reaction_out.volume_db = linear_to_db(_reaction_out_gain) if _reaction_out_gain > 0.0 else -80.0
	if _reaction_out_gain == 0.0 and _reaction_out.playing:
		_reaction_out.stop()
	if not shown_enabled:
		_pending.clear()
		for player in [_whistle] + _impacts:
			player.stop()
	var now := _game_time_ms()
	var due: Array[Dictionary] = []
	for item in _pending:
		if int(item.at) <= now:
			due.append(item)
	for item in due:
		_pending.erase(item)
		if item.crowd:
			_play_reaction(str(item.id), str(item.mood), bool(item.live))
		else:
			_play_effect(str(item.id), bool(item.live))
	# Rumeur : monte en 1,6 s, retombe en 0,6 s ; elle s'éteint seule sans nouveau fait près de la ligne.
	if not enabled or now - _murmur_since > MURMUR_HOLD_MS:
		_murmur_target = 0.0
	_murmur_gain = move_toward(_murmur_gain, _murmur_target, delta / (1.6 if _murmur_target > _murmur_gain else 0.6))
	if _murmur_gain > 0.0 and not _murmur.playing:
		_murmur.play()
	_murmur.pitch_scale = 0.96 + 0.1 * _murmur_gain
	_murmur.volume_db = linear_to_db(_murmur_gain * MURMUR_GAIN * (0.5 if _voice_active else 1.0)) if _murmur_gain > 0.0 else -80.0
	if _murmur_gain == 0.0 and _murmur.playing:
		_murmur.stop()

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
	refresh_visibility(route, live_visible)
	if live.is_empty():
		_signature = ""
		_history.clear()
		_seen.clear()
		_cursor = -1
		_last_stop = "?"
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
	var fact: Dictionary = {}
	# Direct d'origine seulement : en temps forts, la régie sonne ce qu'elle montre.
	var original_live := response_ok and command == "tick" and not live.get("direct") is Dictionary
	if current >= 0:
		var key := str(current) + ":" + history[current]
		# En temps forts, le moteur a une minute d'avance sur l'écran : la régie déclenche
		# elle-même la réaction quand l'action est montrée (play_shown).
		if not reset and forward and not _seen.has(key) and original_live and _active:
			cue = _crowd_cue_for(events[current])
			if events[current] is Dictionary and events[current].get("scene") is Dictionary:
				fact = events[current].scene
		# Consume even while paused, muted, invisible, imported, resumed or sought.
		for index in current + 1:
			_seen[str(index) + ":" + history[index]] = true
	_signature = signature
	_history = history
	_cursor = current
	if not fact.is_empty():
		var kind := str(fact.get("kind", ""))
		_update_murmur(kind, scene_distance(fact))
		# Le direct d'origine n'a pas d'instant de frappe : le ballon part avec le résultat.
		_play_effects("kick" if kind in ["goal", "miss"] else kind)
	if not cue.is_empty():
		_play_reaction(cue.id, cue.mood)
	# Mi-temps et fin du direct d'origine : long coup de sifflet au passage, jamais à l'ouverture.
	var stop := "end" if live.get("finished", false) else ("break" if live.get("atBreak", false) else "")
	if not reset and original_live and _last_stop == "" and not stop.is_empty():
		play_shown(stop)
	_last_stop = stop

## Mètres entre le fait et la ligne d'essai adverse du camp en possession ; -1 si le fait ne le dit pas.
static func scene_distance(fact: Dictionary) -> float:
	var possession: Variant = fact.get("possession", -1)
	var to: Variant = fact.get("to")
	if not typeof(possession) in [TYPE_INT, TYPE_FLOAT] or not int(possession) in [0, 1] or not to is Dictionary:
		return -1.0
	var x: Variant = to.get("x")
	if not typeof(x) in [TYPE_INT, TYPE_FLOAT]:
		return -1.0
	return 100.0 - float(x) if int(possession) == 0 else float(x)

func _play_reaction(id: String, mood: String = "joie", live_only: bool = true) -> bool:
	if not _match_audible(live_only):
		return false
	var now := _game_time_ms()
	var priority: int = REACTION_PRIORITY.get(id, 1)
	# Anti-rebond en temps de jeu. Dans la fenêtre, seule une réaction strictement plus importante
	# remplace celle en cours ; une réaction rejetée ne change pas le repère (résultat indépendant de l'ordre).
	if now - _last_reaction_ms < REACTION_WINDOW_MS and priority <= _last_reaction_priority:
		return false
	_last_reaction_ms = now
	_last_reaction_priority = priority
	# Une réaction nouvelle remplace la suite prévue (applaudissements après un essai, par exemple).
	_pending.assign(_pending.filter(func(item: Dictionary) -> bool: return not item.crowd))
	# La réaction en cours s'efface en fondu sous la nouvelle au lieu d'être coupée.
	if _reaction.playing:
		var previous := _reaction
		_reaction_out.stop()
		_reaction = _reaction_out
		_reaction_out = previous
		_reaction_out_gain = _reaction_gain
	_reaction.stop()
	# Déception : un « oooh » qui retombe, un peu plus grave et plus bas.
	_reaction.stream = _streams["crowd-groan" if mood == "deception" else id]
	_reaction.pitch_scale = 0.92 if mood == "deception" else 1.0
	_reaction_scale = 0.75 if mood == "deception" else 1.0
	_reaction_gain = (0.55 if _voice_active else 1.0) * _reaction_scale
	_reaction.volume_db = linear_to_db(_reaction_gain)
	_reaction.play()
	crowd_mood.emit(mood)
	cue_played.emit(id)
	return true

## Tous les lecteurs du gestionnaire (tests : suivre la libération des lectures en cours).
func players() -> Array:
	return [_ui, _bed, _reaction, _reaction_out, _whistle, _murmur] + _impacts

func dispose() -> void:
	if not _registered:
		return
	_registered = false
	if is_instance_valid(_app):
		_app_owners.erase(_app.get_instance_id())
	if is_inside_tree() and get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.disconnect(_node_added)
	_pending.clear()
	for node in players():
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
