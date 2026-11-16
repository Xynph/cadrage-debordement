extends CanvasLayer
## Ouverture du jeu : enchaîne les cartes d'introduction (intro.json) au-dessus du menu
## principal pendant que le moteur démarre. Chaque carte vit dans son propre script
## (carte_<id>.gd) et ne connaît que ses données ; ce chef d'orchestre gère l'ordre,
## les fondus enchaînés (jamais d'écran noir), le passage par touche ou clic et la
## disponibilité du moteur. Désactivée en QA et en test (voir enabled()).
signal finished

const C = preload("res://ui/immersive08/components.gd")
const DATA_PATH := "res://intro/intro.json"
const CARTES := {
	"presente": preload("res://intro/carte_presente.gd"),
	"stade": preload("res://intro/carte_stade.gd"),
	"titre": preload("res://intro/carte_titre.gd"),
}
const MODES := ["complete", "short"]

var app: Control
var data: Dictionary = {}
## « complete » ou « short » (réglage Introduction, ou premier lancement).
var mode := "complete"
## Premier lancement : aucun réglage Introduction n'est encore enregistré.
var first_run := false
var reduced_motion := false
## Gain de l'ambiance du stade (volume global × ambiance du stade, réglages du profil).
var stadium_gain := 0.25
var engine_ready := false
var order: Array = []
## Cartes effectivement montrées, dans l'ordre (contrôle des tests).
var shown: Array[String] = []
var index := -1
var current: Control
## Carte précédente, encore visible pendant le fondu enchaîné (contrôle des tests).
var previous: Control
var _root: Control
var _since_change := 0.0
var _remaining := 0.0
var _elapsed := 0.0
var _closing := false

## L'introduction ne tourne que dans une vraie partie : jamais en QA, en test ni sans écran.
## CD_GODOT_INTRO=1 la force (tests de l'introduction), CD_GODOT_INTRO=0 la coupe.
static func enabled() -> bool:
	var forced := OS.get_environment("CD_GODOT_INTRO")
	if forced == "0": return false
	if forced == "1": return true
	if DisplayServer.get_name() == "headless": return false
	for variable in ["CD_GODOT_DATA_DIR", "CD_GODOT_SELF_TEST", "CD_GODOT_IMMERSIVE_SELF_TEST", "CD_GODOT_GUIDE_MODULE_TEST"]:
		if not OS.get_environment(variable).is_empty(): return false
	return true

## Lit le profil sans attendre le moteur : réglage Introduction, mode calme et volumes.
## Fichier absent ou sans réglage Introduction : premier lancement, séquence complète.
static func read_profile(root: String) -> Dictionary:
	# Même dossier que le moteur (native/engine/worker.cjs) : <dossier>/PrototypeGodot, sauf s'il y est déjà.
	var directory := root if root.get_file() == "PrototypeGodot" else root.path_join("PrototypeGodot")
	var result := {"mode": "complete", "first": true, "reduced_motion": false, "gain": 0.75 * 0.25}
	var interface := _json(directory.path_join("interface.json"))
	if FileAccess.file_exists(directory.path_join("interface.json")) and interface.is_empty():
		result.mode = "short"; result.first = false # Fichier illisible : rien d'imposé au joueur.
	if interface.has("intro"):
		result.first = false
		result.mode = "complete" if interface.intro == "complete" else "short"
	result.reduced_motion = interface.get("reduced_motion", false) == true
	var volume := float(interface.get("volume", 75)) if typeof(interface.get("volume", 75)) in [TYPE_INT, TYPE_FLOAT] else 75.0
	var sound := _json(directory.path_join("sound.json"))
	var stadium := float(sound.get("stadium_volume", 25)) if typeof(sound.get("stadium_volume", 25)) in [TYPE_INT, TYPE_FLOAT] else 25.0
	result.gain = clampf(volume / 100.0, 0.0, 1.0) * clampf(stadium / 100.0, 0.0, 1.0)
	return result

static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}

## Monte la séquence au-dessus de l'application. Le moteur est déjà lancé par main.gd.
func setup(host: Control, profile_directory: String) -> void:
	app = host
	name = "IntroSequence"
	layer = 90
	data = load_data()
	var profile := read_profile(profile_directory)
	var forced_mode := OS.get_environment("CD_GODOT_INTRO_MODE")
	mode = forced_mode if forced_mode in MODES else str(profile.mode)
	first_run = bool(profile.first) and forced_mode.is_empty()
	reduced_motion = bool(profile.reduced_motion)
	stadium_gain = float(profile.gain)
	order = (data.get("sequence_complete" if mode == "complete" else "sequence_courte", ["titre"]) as Array).filter(func(id): return CARTES.has(str(id)))
	if order.is_empty(): order = ["titre"]
	_root = Control.new()
	_root.name = "IntroRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var ground := ColorRect.new()
	ground.name = "IntroGround"
	ground.color = C.BG
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(ground)
	if is_instance_valid(app) and app.get("bridge") != null:
		app.bridge.model_changed.connect(_on_model)
		app.bridge.command_failed.connect(_on_failed)
	_goto(0)

func card_data(id: String) -> Dictionary:
	return data.get("cartes", {}).get(id, {})

func current_id() -> String:
	return str(order[index]) if index >= 0 and index < order.size() else ""

func _goto(next: int) -> void:
	if _closing: return
	if next >= order.size():
		finish()
		return
	previous = current
	# La carte qui part est prévenue avant que la suivante ne se construise (l'écran titre reprend le cadre du stade).
	if previous != null and previous.has_method("leave"): previous.leave(float(data.get("garde_texte", 0.3)))
	index = next
	var id := str(order[index])
	var card: Control = CARTES[id].new()
	card.name = "IntroCarte_" + id
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)
	card.configure(self, card_data(id))
	current = card
	shown.append(id)
	_since_change = 0.0
	_elapsed = 0.0
	var spec := card_data(id)
	_remaining = float(spec.get("duree", 0.0))
	if engine_ready: _remaining = minf(_remaining, float(spec.get("duree_moteur_pret", _remaining)))
	if card.has_method("engine_ready") and engine_ready: card.engine_ready()
	if previous == null:
		card.modulate.a = 1.0 # Première carte : posée immédiatement sur le fond du thème.
	else:
		# Fondu enchaîné : les textes de la carte qui part s'effacent d'abord (garde_texte), l'image suivante
		# monte par-dessus ; la carte qui part reste dessous (jamais d'écran noir) le temps d'éteindre son son.
		var outgoing := previous
		var text_out := float(data.get("garde_texte", 0.3))
		card.modulate.a = 0.0
		var crossfade := float(data.get("fondu_entre_cartes", 0.9))
		var linger: float = outgoing.call("linger") if outgoing.has_method("linger") else 0.0
		var fade := create_tween()
		fade.tween_property(card, "modulate:a", 1.0, crossfade).set_delay(text_out * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_callback(func(): if is_instance_valid(outgoing): outgoing.visible = false)
		fade.tween_interval(maxf(linger - crossfade, 0.0))
		fade.tween_callback(func():
			if is_instance_valid(outgoing): outgoing.queue_free()
			if previous == outgoing: previous = null)
	card.begin()

func _process(delta: float) -> void:
	if _closing or current == null: return
	_since_change += delta
	_elapsed += delta
	if current.get("automatic") == true:
		_remaining -= delta
		if _remaining <= 0.0: _goto(index + 1)
	elif not engine_ready and _elapsed > float(data.get("attente_moteur_max", 30.0)):
		_mark_ready() # Le menu affiche lui-même l'état du moteur au-delà de cette attente.

func _input(event: InputEvent) -> void:
	if _closing: return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
	if not pressed: return
	get_viewport().set_input_as_handled()
	skip()

## Passer la carte en cours (touche, clic ou manette). L'écran titre ne se quitte qu'avec un moteur prêt.
func skip() -> void:
	if _closing or current == null or _since_change < float(data.get("garde_touche", 0.15)): return
	if current.get("automatic") == true:
		_goto(index + 1)
	elif engine_ready:
		_goto(index + 1)

func _on_model(_value: Dictionary) -> void:
	_mark_ready()

func _on_failed(_message: String) -> void:
	# Une vraie erreur du moteur doit rester lisible : l'introduction s'efface aussitôt.
	if not engine_ready: finish(0.2)

func _mark_ready() -> void:
	if engine_ready: return
	engine_ready = true
	if current != null:
		var spec := card_data(current_id())
		if spec.has("duree_moteur_pret"): _remaining = minf(_remaining, float(spec.duree_moteur_pret))
		if current.has_method("engine_ready"): current.engine_ready()

## Fondu vers le menu principal (déjà construit dessous), puis retrait de la séquence.
func finish(duration: float = -1.0) -> void:
	if _closing: return
	_closing = true
	if is_instance_valid(app) and app.get("bridge") != null:
		if app.bridge.model_changed.is_connected(_on_model): app.bridge.model_changed.disconnect(_on_model)
		if app.bridge.command_failed.is_connected(_on_failed): app.bridge.command_failed.disconnect(_on_failed)
	if first_run and is_instance_valid(app) and app.get("user_preferences") != null:
		# Premier lancement vu : les suivants passent directement au titre (modifiable dans Paramètres).
		app.user_preferences.set_value("intro", "short")
	if current != null and current.has_method("leave"): current.leave()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, duration if duration >= 0.0 else float(data.get("fondu_vers_menu", 0.5)))
	fade.tween_callback(func():
		finished.emit()
		queue_free())
