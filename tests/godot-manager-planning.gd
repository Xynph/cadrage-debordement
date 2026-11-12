extends SceneTree

class Host extends Control:
	signal model_changed(model: Dictionary)
	var model: Dictionary
	var bridge: Node
	var calls: Array = []
	func _command(command: String, payload: Dictionary) -> void:
		calls.append({"command":command,"payload":payload})

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not FileAccess.file_exists("res://ui/manager_planning.gd"):
		push_error("Atelier du manager absent")
		quit(1)
		return
	var host := Host.new()
	host.model = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_MANAGER_PLANNING_MODEL")))
	host.bridge = host
	root.add_child(host)
	root.size = Vector2i(1280, 720)
	var before := JSON.stringify(host.model)
	var panel = load("res://ui/manager_planning.gd").open(host)
	await process_frame
	await process_frame
	assert(panel.find_child("PlannerFixture", true, false) != null)
	assert((panel.find_child("PlannerPlayer", true, false) as OptionButton).item_count > 1)
	assert(host.calls.is_empty())
	var save := panel.find_child("PlannerSaveLineup", true, false) as Button
	save.pressed.emit()
	assert(host.calls.size() == 1 and host.calls[0].command == "manager_plan_lineup")
	assert(host.calls[0].payload.has("fixtureId"))
	panel.tabs.current_tab = 1
	await process_frame
	await process_frame
	assert(panel.find_child("PlannerScenarioAdd", true, false) != null)
	assert(panel.find_child("PlannerHorizon", true, false) != null)
	panel.tabs.current_tab = 2
	await process_frame
	await process_frame
	var goal := panel.find_child("PlannerSaveGoal", true, false) as Button
	goal.pressed.emit()
	assert(host.calls[-1].command == "manager_plan_goal")
	assert(JSON.stringify(host.model) == before)
	assert(panel.size.x <= root.size.x and panel.size.y <= root.size.y)
	print("Atelier manager Godot : trois parcours, commandes d’intention et lecture pure PASS")
	panel.queue_free()
	host.queue_free()
	await process_frame
	quit(0)
