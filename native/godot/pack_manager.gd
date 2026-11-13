extends Node
## Native file picker and commands. The worker alone validates and installs packs.
var app: Control
var scope := "creation"
var creation_mode := "auto"
var return_route := "Création"
var source_path := ""
var inspected_mode := ""
var picker: FileDialog

func _ready() -> void:
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.zip ; Pack d’identités Oval Legacy 27"])
	picker.file_selected.connect(inspect)
	add_child(picker)

func mode(target_scope: String = "") -> String:
	var effective_scope := scope if target_scope.is_empty() else target_scope
	var meta: Dictionary = app.model.get("meta", {})
	if effective_scope == "career":
		return str(meta.get("edition", "world")) if meta.get("mode") == "world" else "common"
	# Mode unique Monde : le joueur crée toujours une carrière du Monde complet. Les autres éditions
	# ne servent qu'aux recettes, avec un moteur lancé en anciens modes (CD_MODES_HERITES=1).
	if creation_mode == "auto" and not meta.get("legacyModes", false): return "world-champ"
	if creation_mode in ["auto", "world-champ"] and not meta.get("champCatalogue", []).is_empty(): return "world-champ"
	if creation_mode in ["auto", "world-nationale", "world-champ"] and not meta.get("nationaleCatalogue", []).is_empty(): return "world-nationale"
	if creation_mode in ["auto", "world-japan", "world-nationale", "world-champ"] and not meta.get("japanCatalogue", []).is_empty(): return "world-japan"
	if creation_mode in ["auto", "world-pacific", "world-japan", "world-nationale", "world-champ"] and not meta.get("pacificCatalogue", []).is_empty(): return "world-pacific"
	return "world" if creation_mode in ["auto", "world", "world-pacific", "world-japan", "world-nationale", "world-champ"] and not meta.get("worldCatalogue", []).is_empty() else "common"

func creation_catalogue() -> Array:
	var key: String = {
		"world-champ": "champCatalogue", "world-nationale": "nationaleCatalogue",
		"world-japan": "japanCatalogue", "world-pacific": "pacificCatalogue",
		"world": "worldCatalogue",
	}.get(mode("creation"), "legacyCatalogue")
	return app.model.get("meta", {}).get(key, app.catalogue)

func competition(id: String, target_scope: String = "") -> Dictionary:
	var meta: Dictionary = app.model.get("meta", {})
	var effective := scope if target_scope.is_empty() else target_scope
	var identities: Dictionary = meta.get("competitionIdentities", {})
	if effective == "creation":
		identities = meta.get("creationCompetitions", {}).get(mode("creation"), {})
	return identities.get(id, {})

func database(target_scope: String = "") -> Dictionary:
	var meta: Dictionary = app.model.get("meta", {})
	if mode(target_scope) == "world-champ": return meta.get("champDatabase", {})
	if mode(target_scope) == "world-nationale": return meta.get("nationaleDatabase", {})
	if mode(target_scope) == "world-japan": return meta.get("japanDatabase", {})
	if mode(target_scope) == "world-pacific": return meta.get("pacificDatabase", {})
	if mode(target_scope) == "world": return meta.get("worldDatabase", {})
	if meta.has("legacyDatabase"): return meta.legacyDatabase
	if meta.get("mode") != "world": return meta.get("database", {})
	return {}

func _matches_edition(pack: Dictionary, target_scope: String = "") -> bool:
	var database_id := str(database(target_scope).get("id", ""))
	return not database_id.is_empty() and str(pack.get("databaseId", "")) == database_id

func installed(target_scope: String = "") -> Array:
	return app.model.get("packs", {}).get("installed", []).filter(func(pack: Dictionary): return _matches_edition(pack, target_scope))

func selected_id(target_scope: String = "") -> String:
	var effective_scope := scope if target_scope.is_empty() else target_scope
	var packs: Dictionary = app.model.get("packs", {})
	if effective_scope == "career": return str(packs.get("career", "base"))
	var key := str({"world-champ":"champPackCreation", "world-nationale":"nationalePackCreation", "world-japan":"japanPackCreation", "world-pacific":"pacificPackCreation", "world":"worldPackCreation"}.get(mode("creation"), "legacyPackCreation"))
	return str(app.model.get("meta", {}).get(key, packs.get("creation", "base")))

func preview() -> Dictionary:
	var value: Variant = app.model.get("packs", {}).get("preview")
	if value is Dictionary and not source_path.is_empty() and inspected_mode == mode() and _matches_edition(value):
		return value
	return {}

func open(target_scope: String) -> void:
	if app.waiting:
		app._refuse_action("Une décision est en cours. Ouvrez les packs après sa réponse.")
		return
	scope = target_scope
	return_route = app.route
	if _match_running():
		app._command("pause", {"paused":true}, "Packs")
	else:
		app._navigate("Packs")

func _match_running() -> bool:
	var live: Dictionary = app._live()
	return not live.is_empty() and not live.get("paused", false) and not live.get("finished", false)

func choose_creation_file() -> void:
	if not app.waiting and _match_running():
		app._command("pause", {"paused": true})
		while app.waiting: await get_tree().process_frame
		if app.route != "Création" or _match_running(): return
	choose_file()

func choose_file() -> void:
	if app.waiting:
		app._refuse_action("Attendez la fin de l’analyse en cours.")
		return
	picker.current_file = ""
	picker.popup_centered_ratio(0.7)

func inspect(path: String) -> void:
	if app.waiting:
		app._refuse_action("Une analyse est déjà en cours. Réessayez après sa réponse.")
		return
	if app.route == "Création":
		open("creation")
		if app.route != "Packs": return
	source_path = path
	inspected_mode = mode()
	app._command("pack_inspect", {"path":path,"mode":inspected_mode})

func install() -> void:
	var inspected := preview()
	if inspected.is_empty(): return
	app._command("pack_install", {"path":source_path,"digest":inspected.get("digest", "")})

func select(id: String, target_scope: String = "") -> void:
	var effective_scope := scope if target_scope.is_empty() else target_scope
	app._command("pack_select", {"id":id,"scope":effective_scope,"mode":mode(effective_scope)})

func back() -> void:
	if app.waiting:
		app._refuse_action("L’opération n’est pas terminée. Attendez sa réponse.")
		return
	app._navigate(return_route)
