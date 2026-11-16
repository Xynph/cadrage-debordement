extends RefCounted
## Chargement progressif des portraits des longues listes (effectif, staff).
##
## Construire une liste ne décode plus 60 visages : chaque case est créée vide,
## puis remplie ici par petites tranches (budget par image), les lignes visibles
## d'abord. Les visages remplis restent en cache (regen_portrait.gd, game_skin.gd) :
## la visite suivante est immédiate. `flush()` termine tout d'un coup (tests, captures).
const G = preload("res://ui/game_skin.gd")
## Temps maximal consacré aux portraits dans une image (µs) : de quoi rester sous 16 ms par image.
const BUDGET_USEC := 5000
const MAX_ATTEMPTS := 6

static var _queue: Array = []
static var _running := false

static func request(rect: TextureRect, index: int, player: Dictionary) -> void:
	rect.set_meta("portrait_pending", {"index": index, "player": player, "attempts": 0})
	_queue.append(rect)
	if not _running: _pump()

## Nombre de portraits encore en attente (diagnostic et tests).
static func pending() -> int:
	return _queue.size()

## Remplit tout de suite chaque portrait encore en attente.
static func flush() -> void:
	while not _queue.is_empty():
		_fill(_queue.pop_front())

static func _fill(rect: Variant) -> void:
	if not is_instance_valid(rect) or not rect.has_meta("portrait_pending"): return
	var request: Dictionary = rect.get_meta("portrait_pending")
	rect.remove_meta("portrait_pending")
	var before: String = rect.tooltip_text
	G.fill_portrait(rect, int(request.index), request.player)
	# Le texte de survol de la ligne reprend celui du portrait (« Image du pack indisponible · … »).
	var host: Node = rect.get_parent()
	if host is Button and rect.tooltip_text != before:
		host.tooltip_text = host.tooltip_text.replace("\n" + before, "\n" + rect.tooltip_text)

static func _on_screen(rect: Control, window: Rect2) -> bool:
	return rect.is_visible_in_tree() and rect.get_global_rect().intersects(window)

static func _next_index(window: Rect2) -> int:
	var fallback := -1
	for i in _queue.size():
		var rect: Variant = _queue[i]
		if not is_instance_valid(rect) or not rect.has_meta("portrait_pending"): return i
		if not rect.is_inside_tree():
			var request: Dictionary = rect.get_meta("portrait_pending")
			request.attempts = int(request.attempts) + 1
			if request.attempts > MAX_ATTEMPTS: return i
			continue
		if _on_screen(rect, window): return i
		if fallback < 0: fallback = i
	return fallback

static func _pump() -> void:
	_running = true
	var tree := Engine.get_main_loop() as SceneTree
	while not _queue.is_empty():
		await tree.process_frame
		var started := Time.get_ticks_usec()
		var window := Rect2(Vector2.ZERO, Vector2(tree.root.size))
		while not _queue.is_empty() and Time.get_ticks_usec() - started < BUDGET_USEC:
			var index := _next_index(window)
			if index < 0: break
			var rect: Variant = _queue[index]
			_queue.remove_at(index)
			_fill(rect)
	_running = false
