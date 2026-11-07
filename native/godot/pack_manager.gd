extends Node
## Native file picker and commands. The worker alone validates and installs packs.
var app: Control
var scope := "creation"
var return_route := "Création"
var source_path := ""
var picker: FileDialog

func _ready() -> void:
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.zip ; Pack d’identités Oval Legacy"])
	picker.file_selected.connect(inspect)
	add_child(picker)

func open(target_scope: String) -> void:
	if app.waiting:
		app._refuse_action("Une décision est en cours. Ouvrez les packs après sa réponse.")
		return
	scope = target_scope
	return_route = app.route
	if not app._live().is_empty() and not app._live().get("paused", false) and not app._live().get("finished", false):
		app._command("pause", {"paused":true}, "Packs")
	else:
		app._navigate("Packs")

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
	source_path = path
	app._command("pack_inspect", {"path":path})

func install() -> void:
	var preview: Dictionary = app.model.get("packs", {}).get("preview", {})
	if preview.is_empty() or source_path.is_empty(): return
	app._command("pack_install", {"path":source_path,"digest":preview.get("digest", "")})

func select(id: String) -> void:
	app._command("pack_select", {"id":id,"scope":scope})

func back() -> void:
	if app.waiting:
		app._refuse_action("L’opération n’est pas terminée. Attendez sa réponse.")
		return
	app._navigate(return_route)
