extends SceneTree
var failures: Array[String] = []
var checks := 0
class Host extends Control:
	var model: Dictionary = {}
	var confirmation: Callable
	var sent: Dictionary = {}
	func confirm(_title: String, _text: String, callback: Callable) -> void: confirmation = callback
	func _command(command: String, payload: Dictionary) -> void: sent = {"command":command,"payload":payload}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func all_text(node: Node) -> String:
	var output: String = str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): output += all_text(child)
	return output
func run() -> void:
	var script: Script = load("res://ui/performance_analysis_view.gd")
	var model: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_DEEPEN_ANALYTICS_MODEL")))
	var before := JSON.stringify(model)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = size
		var host := Host.new()
		host.model = model
		root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		host.add_child(scroll)
		var panel: Control = script.build(host)
		scroll.add_child(panel)
		for i in 4: await process_frame
		var picker: OptionButton = panel.find_child("PerformancePlayerChoice",true,false)
		check(picker != null, "Choix du joueur " + str(size))
		check(picker.item_count == model.clubLife.playerMatchHistory.players.size(), "Effectif actuel réel " + str(size))
		var details: Control = panel.find_child("PerformancePlayerDetail",true,false)
		check(all_text(details).contains("minutes connues") and all_text(details).contains("par 80 min"), "Minutes et ratios mesurés " + str(size))
		picker.select(1)
		picker.item_selected.emit(1)
		check(all_text(details).contains(str(model.clubLife.playerMatchHistory.players[1].name)), "Changement du joueur " + str(size))
		check(panel.get_combined_minimum_size().x <= size.x, "Largeur bornée " + str(size))
		check(JSON.stringify(model) == before, "Consultation pure " + str(size))
		host.queue_free()
		await process_frame
	var host := Host.new()
	host.model = model.duplicate(true)
	host.model.clubLife.playerMatchHistory = {"available":true,"enabled":false,"canEnable":true,"context":{"club":0,"season":1,"week":0}}
	root.add_child(host)
	var panel: Control = script.build(host)
	host.add_child(panel)
	var enable: Button = panel.find_child("PlayerMatchHistoryEnable",true,false)
	check(enable != null and not enable.disabled, "Activation explicite disponible")
	enable.pressed.emit()
	check(host.sent.is_empty() and host.confirmation.is_valid(), "Pas d’activation avant confirmation")
	host.confirmation.call()
	check(host.sent.command == "player_match_history_enable" and host.sent.payload.confirmed, "Commande de confirmation contextualisée")
	check(host.sent.payload.context.week == 0, "Contexte du devis conservé")
	host.queue_free()
	await process_frame
	print("Historique individuel Godot : ",checks," contrôles, ",failures.size()," échecs.")
	quit(0 if failures.is_empty() else 1)
