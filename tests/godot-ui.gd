extends SceneTree

# Explicit development entry point; the exported app uses the same fixed runner.
func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		printerr("Disposable CD_GODOT_DATA_DIR required")
		quit(2)
		return
	OS.set_environment("CD_GODOT_SELF_TEST", "1")
	call_deferred("_start")

func _start() -> void:
	root.add_child(load("res://main.tscn").instantiate())
