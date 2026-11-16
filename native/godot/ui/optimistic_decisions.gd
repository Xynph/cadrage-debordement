extends RefCounted
## Décisions optimistes (lot 23, réactivité de l'interface) : une bascule ou une sélection simple s'affiche dès le clic,
## avant la réponse du moteur. Le modèle confirmé reste celui du pont (`bridge.model`) : la retouche est une copie
## (copie superficielle le long du chemin modifié, rien d'autre n'est copié). Réponse acceptée : le modèle du moteur
## remplace la retouche. Refus : le modèle confirmé revient tel quel, l'écran est redessiné et la fenêtre de refus
## habituelle s'affiche.
##
## Seules les décisions dont l'effet visible est une seule valeur connue d'avance figurent ici ; le moteur reste seul
## juge (aucune règle du jeu n'est recopiée : une valeur refusée par le moteur est simplement annulée).
##
## Exemple : `var edits := Optimistic.edits("set_tactics", {"attack":"large", "defense":"equilibre"}, model)`
## puis `model = Optimistic.apply(model, edits)`.

## Retouches [chemin, valeur] prévues pour `command`, ou [] si la décision n'est pas optimiste.
static func edits(command: String, payload: Dictionary, model: Dictionary) -> Array:
	match command:
		"set_tactics":
			# En match, le direct (model.live) porte ses propres consignes : pas d'affichage anticipé.
			if model.get("live") is Dictionary: return []
			var tactics: Variant = model.get("tactics")
			if not tactics is Dictionary: return []
			var result: Array = []
			for key: String in ["attack", "defense"]:
				if payload.has(key) and tactics.has(key) and payload[key] is String: result.append([["tactics", key], payload[key]])
			return result
		"set_collective_focus":
			return _leaf(model, ["decisions", "training", "collective", "selected"], payload.get("focus"))
		"set_opponent_level":
			return _leaf(model, ["decisions", "difficulty", "selected"], payload.get("level"))
		"set_delegation":
			var key := str(payload.get("key", ""))
			if key.is_empty() or not payload.get("enabled") is bool or not _node(model, ["decisions", "delegation"]) is Dictionary: return []
			return [[["decisions", "delegation", key], payload.enabled]]
		"press_policy":
			return _leaf(model, ["clubLife", "press", "policy", "ordinary"], payload.get("ordinary"))
		"club_follow":
			var followed: Variant = _node(model, ["clubLife", "clubSheet", "followed"])
			if not followed is Array or not payload.get("follow") is bool or not (payload.get("club") is int or payload.get("club") is float): return []
			var club := int(payload.club)
			# Même ordre que le moteur (club-sheet.cjs) : retiré, puis ajouté en fin de liste.
			var next: Array = followed.filter(func(id: Variant) -> bool: return not ((id is int or id is float) and int(id) == club))
			if payload.follow: next.append(float(club))
			return [[["clubLife", "clubSheet", "followed"], next]]
	return []

## Copie de `model` avec les retouches ; `model` lui-même n'est jamais modifié.
static func apply(model: Dictionary, changes: Array) -> Dictionary:
	var result := model
	for change: Array in changes: result = _with(result, change[0], 0, change[1])
	return result

## Vrai si `model` porte déjà toutes les retouches (décision en file déjà affichée).
static func applied(model: Dictionary, changes: Array) -> bool:
	for change: Array in changes:
		var path: Array = change[0]
		var parent: Variant = _node(model, path.slice(0, path.size() - 1))
		if not parent is Dictionary or not parent.has(path[-1]) or str(parent[path[-1]]) != str(change[1]): return false
	return true

## Mêmes chemins retouchés (une décision en file peut remplacer la précédente seulement dans ce cas).
static func same_paths(first: Array, second: Array) -> bool:
	if first.size() != second.size(): return false
	for i in first.size():
		if str(first[i][0]) != str(second[i][0]): return false
	return true

static func _leaf(model: Dictionary, path: Array, value: Variant) -> Array:
	if value == null or value is Dictionary or value is Array: return []
	var parent: Variant = _node(model, path.slice(0, path.size() - 1))
	if not parent is Dictionary or not parent.has(path[-1]): return []
	return [[path, value]]

static func _node(model: Dictionary, path: Array) -> Variant:
	var node: Variant = model
	for key: Variant in path:
		if not node is Dictionary or not node.has(key): return null
		node = node[key]
	return node

static func _with(node: Dictionary, path: Array, index: int, value: Variant) -> Dictionary:
	var copy := node.duplicate()
	var key: Variant = path[index]
	if index == path.size() - 1:
		copy[key] = value
		return copy
	var child: Variant = node.get(key)
	if not child is Dictionary: return node
	copy[key] = _with(child, path, index + 1, value)
	return copy
