extends RefCounted
## Rafraîchissement par écran (suite de #770). Après une réponse du moteur, l'écran affiché n'est redessiné que s'il
## lit une section changée (`engine_bridge.last_changes`). La correspondance section → écrans est une donnée
## (`res://ui/screen_refresh.json`), pas une règle écrite dans chaque écran.
##
## Rendu complet, sans exception :
## - section absente de la table (inconnue), sous-section retirée, réponse complète du moteur ;
## - écran construit pendant une attente (`app.waiting` vrai au rendu : boutons grisés, textes d'attente) ou avec une
##   autre erreur, un autre voyant d'alerte, un autre jour, un autre écran, ou remplacé depuis ;
## - écrans de `toujours_complet` (accueil, création, packs, match).
## Le modèle n'est jamais modifié ici.
##
## Exemple :
## `var choix := ScreenRefresh.plan(route, stamp_au_rendu, stamp_actuel, bridge.last_changes, bridge.last_full_model)`
## puis `if choix == ScreenRefresh.FULL: _render(false)`.

const TABLE_PATH := "res://ui/screen_refresh.json"
## Écran redessiné entièrement.
const FULL := "complet"
## Écran gardé tel quel : aucune section qu'il lit n'a changé.
const NONE := "aucun"
## Sections découpées en sous-sections par le moteur (native/engine/model-delta.cjs) et par le pont.
const NESTED := ["clubLife", "meta", "staff", "decisions", "live"]
## Tous les écrans (valeur possible de « ecrans »).
const EVERY_SCREEN := "*"
## Éléments de l'état d'un écran comparés entre son rendu et la réponse (voir `stamp`).
const STAMP_KEYS := ["content", "route", "waiting", "day", "error", "connection_error", "status_error", "storage_error"]

static var _loaded: Dictionary = {}

## Table lue une fois : {"sections": {id: {"ecrans": [...]}}, "toujours_complet": [...]}. Fichier illisible : table
## vide, donc toujours le rendu complet.
static func table() -> Dictionary:
	if _loaded.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
		_loaded = parsed if parsed is Dictionary and parsed.get("sections") is Dictionary else {"sections": {}, "toujours_complet": []}
	return _loaded

## État de l'écran affiché, à noter à chaque rendu complet et à comparer à la réponse suivante.
## `content` : identifiant de l'arbre affiché (0 sans écran) ; `day` : date de carrière du modèle ; `status_error` :
## voyant d'alerte de la barre latérale (stockage, journal de sauvegarde, réglages), dessiné au rendu.
## `storage_error` : voyant « Stockage à vérifier » seul (écriture), distinct des refus de décision.
## Exemple : `ScreenRefresh.stamp(root_content.get_instance_id(), route, waiting, model, last_error, connection_error, _status_has_error(), _storage_has_error())`.
static func stamp(content: int, route: String, waiting: bool, model: Dictionary, error: String, connection_error: bool, status_error: bool = false, storage_error: bool = false) -> Dictionary:
	var meta: Variant = model.get("meta")
	var day := ""
	if meta is Dictionary: day = str(meta.get("calendarToday", meta.get("date", "")))
	return {"content": content, "route": route, "waiting": waiting, "day": day, "error": error, "connection_error": connection_error, "status_error": status_error, "storage_error": storage_error}

## Identifiants des sections d'un relevé du pont : "tactics" pour une section entière, "clubLife.press" pour une
## sous-section. Sous-section retirée (relevé vide pour la section) : la section entière, inconnue de la table.
## Exemple : `section_ids({"meta": {"week": true}, "squad": true})` → `["meta.week", "squad"]`.
static func section_ids(changes: Dictionary) -> Array:
	var ids: Array = []
	for key: Variant in changes:
		var value: Variant = changes[key]
		if value is Dictionary and not value.is_empty():
			for name: Variant in value: ids.append("%s.%s" % [key, name])
		else: ids.append(str(key))
	return ids

## Identifiants des sections touchées par des retouches optimistes ([[chemin, valeur], ...], optimistic_decisions.gd).
## Exemple : `edit_ids([[["decisions", "training", "collective", "selected"], "conquete"]])` → `["decisions.training"]`.
static func edit_ids(edits: Array) -> Array:
	var ids: Array = []
	for change: Variant in edits:
		var path: Variant = change[0] if change is Array and not change.is_empty() else null
		if not (path is Array) or path.is_empty(): return [""] # Retouche illisible : section inconnue.
		var id := str(path[0])
		if path.size() >= 2 and id in NESTED: id += "." + str(path[1])
		ids.append(id)
	return ids

## Vrai si l'écran `route` lit l'une de ces sections, ou si l'une d'elles est inconnue de la table.
## `sections` vide : celles de la table.
static func concerns(route: String, ids: Array, sections: Dictionary = {}) -> bool:
	if sections.is_empty(): sections = table().get("sections", {})
	for id: Variant in ids:
		var entry: Variant = sections.get(id)
		if not (entry is Dictionary and entry.get("ecrans") is Array): return true
		var screens: Array = entry["ecrans"]
		if screens.has(route) or screens.has(EVERY_SCREEN): return true
	return false

## Choix après une réponse acceptée : FULL ou NONE. `rendered` : état noté au dernier rendu complet ; `now` : même
## état à la réception (`stamp`). Toute différence (écran remplacé, autre écran, attente, jour, erreur) : FULL.
## `data` vide : la table du jeu.
static func plan(route: String, rendered: Dictionary, now: Dictionary, changes: Dictionary, full_model: bool, data: Dictionary = {}) -> String:
	if data.is_empty(): data = table()
	if full_model or rendered.is_empty() or int(rendered.get("content", 0)) == 0: return FULL
	if route in data.get("toujours_complet", []): return FULL
	for key: String in STAMP_KEYS:
		if rendered.get(key) != now.get(key): return FULL
	var ids := section_ids(changes)
	if ids.is_empty(): return NONE
	var sections: Dictionary = data.get("sections", {})
	# Table vide ou illisible : `concerns` relirait celle du jeu ; aucune section n'est connue, rendu complet.
	if sections.is_empty(): return FULL
	return FULL if concerns(route, ids, sections) else NONE
