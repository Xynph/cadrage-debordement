class_name AtomicFile
extends RefCounted
## Remplace un temporaire déjà fermé sans supprimer d'abord l'ancien fichier.
## L'appelant reste propriétaire du nettoyage du temporaire en cas de refus.

static func replace_staged(temporary: String, destination: String) -> String:
	if not temporary.is_absolute_path() or not destination.is_absolute_path():
		return "Les chemins de remplacement doivent être absolus."
	var root := OS.get_executable_path().get_base_dir()
	var node_path := root.path_join("runtime/node.exe")
	var helper_path := root.path_join("engine/atomic-replace.cjs")
	if OS.has_feature("macos") and not OS.has_feature("editor"):
		var contents := root.get_base_dir()
		node_path = contents.path_join("Helpers/node")
		helper_path = contents.path_join("Resources/engine/atomic-replace.cjs")
	if OS.has_feature("editor"):
		helper_path = ProjectSettings.globalize_path("res://../engine/atomic-replace.cjs")
		node_path = str(ProjectSettings.get_setting("native_engine/node_executable", node_path))
		if OS.has_environment("CD_NODE_EXECUTABLE"):
			node_path = OS.get_environment("CD_NODE_EXECUTABLE")
	if not node_path.is_absolute_path() or not FileAccess.file_exists(node_path) or not FileAccess.file_exists(helper_path):
		return "Outil de remplacement embarqué introuvable ; original conservé."
	var output: Array = []
	# Arguments séparés, aucun interpréteur ni contenu de fichier transmis.
	var exit_code := OS.execute(node_path, PackedStringArray([helper_path, temporary, destination]), output, false, false)
	if output.size() != 1 or not output[0] is String or output[0].length() > 1024:
		return "Réponse de l’outil de remplacement absente ou invalide."
	var parser := JSON.new()
	if parser.parse(output[0]) != OK or not parser.data is Dictionary:
		return "Réponse de l’outil de remplacement illisible."
	var result: Dictionary = parser.data
	# JSON numbers/containers cannot be compared to bool in GDScript. A runtime
	# type error here could yield the default empty String, falsely meaning success.
	if not result.get("ok") is bool:
		return "Réponse de l’outil de remplacement invalide : statut non booléen."
	var succeeded: bool = result.ok
	if exit_code == 0 and succeeded and result.size() == 1:
		return ""
	if exit_code == 1 and not succeeded and result.size() == 3:
		if not result.get("code") is String or not result.get("error") is String:
			return "Réponse de l’outil de remplacement invalide : erreur non textuelle."
		var code: String = result.code
		var message: String = result.error
		if not code.is_empty() and code.length() <= 64 and not message.is_empty() and message.length() <= 256:
			return "Remplacement refusé : " + message
	return "L’outil de remplacement n’a pas confirmé l’écriture."
