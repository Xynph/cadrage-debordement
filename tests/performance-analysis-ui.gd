extends SceneTree
var failures: Array[String] = []
var checks := 0
class Host extends Control:
	var model: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func text(node: Node) -> String:
	var result: String = str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): result += text(child)
	return result
func run() -> void:
	var view: Script = load("res://ui/performance_analysis_view.gd")
	var model: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_PERFORMANCE_MODEL")))
	var before := JSON.stringify(model)
	for size: Vector2i in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = size
		var host := Host.new()
		host.model = model
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		host.add_child(scroll)
		var panel: Control = view.build(host)
		scroll.add_child(panel)
		for i in 4: await process_frame
		check(text(panel).contains("5 rencontres"), "Cinq rencontres " + str(size))
		check(text(panel).contains("couverture 5 / 5 rencontres"), "Couverture réelle " + str(size))
		check(text(panel).contains("Trois dernières / deux précédentes"), "Comparaison descriptive " + str(size))
		check(panel.get_combined_minimum_size().x <= size.x, "Pas de débordement horizontal " + str(size))
		check(JSON.stringify(model) == before, "Modèle immuable " + str(size))
		host.queue_free()
		await process_frame
	var empty := Host.new()
	empty.model = {"clubLife":{"performanceAnalysis":{"available":true,"summary":{"played":0}}}}
	var empty_panel: Control = view.build(empty)
	check(text(empty_panel).contains("Aucune rencontre conservée"), "État vide explicite")
	empty_panel.free()
	empty.model = {}
	var unavailable: Control = view.build(empty)
	check(text(unavailable).contains("indisponibles"), "Ancien moteur explicite")
	unavailable.free()
	empty.free()
	print("Analyses Godot : ", checks, " contrôles, ", failures.size(), " échecs.")
	quit(0 if failures.is_empty() else 1)
