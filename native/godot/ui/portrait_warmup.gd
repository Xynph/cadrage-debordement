extends RefCounted
## Préchauffage des portraits de l'effectif du manager, en tâche de fond.
##
## À froid, chaque portrait coûte ~10 ms (photo du pack décodée et réduite, ou base du visage composé
## extraite de sa planche et sa composition) : la 1re Composition (23 portraits) gelait ~1/4 s, l'Effectif
## et la Préparation payaient le même prix. Après la réception d'une carrière (création, reprise, effectif
## changé), on remplit ici les mêmes caches que fill_portrait (game_skin.gd, regen_portrait.gd), sans créer
## de nœud, par petites tranches (budget par image) et seulement quand l'interface est au repos :
## ni commande moteur en attente, ni match en direct, ni introduction, ni chargement progressif en cours.
## Les joueurs de la feuille de match passent d'abord (Composition), puis le reste de l'effectif.
## Exemple : `PortraitWarmup.schedule(app)` après chaque modèle reçu (main.gd) ; `pending()` pour les tests.
const G = preload("res://ui/game_skin.gd")
const PortraitLoader = preload("res://ui/portrait_loader.gd")
## Temps maximal consacré au préchauffage dans une image (µs). Un portrait au moins par image au repos.
const BUDGET_USEC := 4000
## Écrans où l'on ne prend aucune image : match en direct, accueil, création de carrière.
const BUSY_ROUTES := ["Match", "Accueil", "Création"]

static var _queue: Array = []
static var _signature := ""
static var _running := false
static var _app: WeakRef
## Mesures (diagnostic et tests) : portraits fabriqués et plus longue étape d'un seul portrait (µs).
static var warmed := 0
static var longest_step_usec := 0

## Programme le préchauffage si l'effectif a changé depuis la dernière fois (joueurs, âges, photos).
## Appel bon marché : rien n'est fabriqué ici, seule une signature de l'effectif est calculée.
static func schedule(app: Control) -> void:
	if not app._has_career() or not app._live().is_empty(): return
	var squad: Variant = app.model.get("squad")
	if not squad is Array or (squad as Array).is_empty(): return
	var signature := _signature_of(squad as Array)
	if signature == _signature: return
	_signature = signature
	_queue = _ordered(app.model, squad as Array)
	_app = weakref(app)
	if not _running: _pump()

## Nombre de portraits encore à examiner (diagnostic et tests).
static func pending() -> int:
	return _queue.size()

## Oublie l'effectif connu et la file (tests).
static func reset() -> void:
	_queue.clear()
	_signature = ""
	warmed = 0
	longest_step_usec = 0

static func _signature_of(squad: Array) -> String:
	var parts := PackedStringArray()
	for person: Variant in squad:
		if not person is Dictionary: continue
		var player: Dictionary = person
		parts.append("%s|%s|%s" % [player.get("id", ""), player.get("age", ""), G._pack_path(player)])
	return ",".join(parts)

## Feuille de match d'abord (ordre des postes), puis le reste de l'effectif dans son ordre.
static func _ordered(model: Dictionary, squad: Array) -> Array:
	var by_id: Dictionary = {}
	for person: Variant in squad:
		if person is Dictionary: by_id[str((person as Dictionary).get("id", ""))] = person
	var result: Array = []
	var taken: Dictionary = {}
	var selection: Variant = model.get("selection")
	var slots: Variant = (selection as Dictionary).get("slots", []) if selection is Dictionary else []
	for assignment: Variant in slots if slots is Array else []:
		if not assignment is Dictionary: continue
		var id := str((assignment as Dictionary).get("playerId", ""))
		if by_id.has(id) and not taken.has(id):
			taken[id] = true
			result.append(by_id[id])
	for person: Variant in squad:
		if not person is Dictionary: continue
		var id := str((person as Dictionary).get("id", ""))
		if taken.has(id): continue
		taken[id] = true
		result.append(person)
	return result

## Interface au repos : aucune commande en attente, pas de direct, pas d'introduction, pas d'écran chargé
## progressivement (portrait_loader.gd a la priorité : ce sont les cases visibles).
static func _idle(app: Control) -> bool:
	if app.waiting or app.closing or not app._live().is_empty(): return false
	if str(app.route) in BUSY_ROUTES: return false
	if PortraitLoader.pending() > 0: return false
	return not app.has_node("IntroSequence")

static func _pump() -> void:
	_running = true
	var tree := Engine.get_main_loop() as SceneTree
	while not _queue.is_empty():
		await tree.process_frame
		var app: Control = null
		if _app != null: app = _app.get_ref() as Control
		if app == null or not is_instance_valid(app) or app.closing or not app.is_inside_tree():
			_queue.clear()
			break
		if not _idle(app): continue
		var started := Time.get_ticks_usec()
		while not _queue.is_empty() and Time.get_ticks_usec() - started < BUDGET_USEC:
			var player: Dictionary = _queue.pop_front()
			if G._portrait_ready(player): continue
			var step := Time.get_ticks_usec()
			G.warm_portrait(player)
			longest_step_usec = maxi(longest_step_usec, Time.get_ticks_usec() - step)
			warmed += 1
	_running = false
