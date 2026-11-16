extends SceneTree
## Temps d'ouverture des écrans lourds (Effectif, Staff, Club, Finances, Recrutement) en carrière Monde réelle.
## Chaque écran est ouvert plusieurs fois ; l'écran d'accueil sert de témoin du châssis commun. Imprime
## CD_OUVERTURE (JSON) et un tableau. Garde-fou large : la médiane doit rester sous BUDGET_MS.
const Flow = preload("helpers/contextual_flow.gd")
const ROUTES := ["Bureau", "Effectif", "Club", "Finances", "Recrutement", "Staff"]
const SIZES := [Vector2i(1920, 1080), Vector2i(1600, 900)]
const OPENINGS := 7
const BUDGET_MS := 600.0
var app: Control
var checks := 0
var failures: Array[String] = []
var times := {}
var nodes := {}
var first := {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle() -> void:
	for frame in 8: await process_frame

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children(): total += count_nodes(child)
	return total

func median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 0}), "Carrière Monde créée")
	until = Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	var all := {}
	var table := ""
	for size: Vector2i in SIZES:
		root.size = size
		await settle()
		times = {}
		nodes = {}
		first = {}
		for route in ROUTES: times[route] = []
		for round in OPENINGS + 1:
			for route in ROUTES:
				var started := Time.get_ticks_usec()
				app._navigate(route)
				var elapsed := (Time.get_ticks_usec() - started) / 1000.0
				await settle()
				if round == 0:
					first[route] = elapsed # première ouverture à froid, hors médiane
					continue
				times[route].append(elapsed)
				nodes[route] = count_nodes(app.body)
		var report := {}
		table += "\nFenêtre %dx%d\n| Écran | 1re ouverture (ms) | Médiane (ms) | Min (ms) | Max (ms) | Nœuds |\n| --- | --- | --- | --- | --- | --- |\n" % [size.x, size.y]
		for route in ROUTES:
			var list: Array = times[route]
			var mid := median(list)
			report[route] = {"mediane": snappedf(mid, 0.1), "min": snappedf(list.min(), 0.1), "max": snappedf(list.max(), 0.1), "noeuds": nodes[route], "premiere": snappedf(first[route], 0.1), "ouvertures": list}
			table += "| %s | %.0f | %.0f | %.0f | %.0f | %d |\n" % [route, first[route], mid, list.min(), list.max(), nodes[route]]
			check(mid < BUDGET_MS, "%dx%d %s : médiane %.0f ms, budget %.0f ms" % [size.x, size.y, route, mid, BUDGET_MS])
		all["%dx%d" % [size.x, size.y]] = report
	print("CD_OUVERTURE ", JSON.stringify(all))
	print(table)
	print("OUVERTURE ECRANS : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
