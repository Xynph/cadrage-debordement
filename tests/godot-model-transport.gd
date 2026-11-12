extends SceneTree

func _initialize() -> void:
	var source := "res://model_transport.gd"
	if not FileAccess.file_exists(source):
		push_error("Récepteur différentiel absent")
		quit(1)
		return
	var receiver = load(source).new()
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_TRANSPORT_CASES")))
	for item: Dictionary in cases:
		var result: Dictionary = receiver.accept(item.response)
		if result.get("model") != item.expected:
			push_error("Modèle reconstruit différent")
			quit(1)
			return
	print("Transport Godot : modèle complet, deltas, suppressions et refus PASS")
	quit(0)
