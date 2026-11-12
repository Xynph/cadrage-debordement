extends SceneTree
## Plans d'arrêt de jeu (coup de sifflet, carton) en temps forts : la caméra rapprochée
## ne cadre jamais l'herbe seule. Défaut vu sur la capture d'un match complet sous
## Windows (75e minute, graine 7) : plusieurs secondes d'image sombre et vide, la caméra
## serrée sur le ballon mort, sans joueur à moins de 9 m. Rejoue ce temps fort tel que le
## moteur l'a projeté (tests/fixtures/match-arret-75.json) avec la vue, les gestes et le
## cadrage des temps forts, et compte les joueurs à l'image à chaque image.

const View = preload("res://match_view.gd")
const Cadrage = preload("res://match_cadrage.gd")
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func visible_players(view) -> int:
	var camera: Camera3D = view._camera
	var screen := Rect2(Vector2.ZERO, Vector2(view.get_viewport().get_visible_rect().size))
	var count := 0
	for id: String in view._actors:
		var spot: Vector3 = (view._actors[id].node as Node3D).position + Vector3.UP
		if not camera.is_position_behind(spot) and screen.has_point(camera.unproject_position(spot)):
			count += 1
	return count


func image(fixture: Dictionary, scene: Dictionary, upto: int, paused: bool) -> Dictionary:
	var events: Array = (fixture.events as Array).slice(0, maxi(0, upto + 1))
	return {"scene": scene, "teams": fixture.teams, "events": events, "paused": paused, "finished": false, "atBreak": false}


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/fixtures/match-arret-75.json")))
	check(fixture is Dictionary and fixture.get("plans") is Array, "Temps fort de la 75e minute lisible")
	if not fixture is Dictionary:
		quit(1)
		return
	var report := {}
	for camera_mode in ["tv", "action"]:
		var view = View.new()
		root.add_child(view)
		view.set_process(false)
		view.set_gestes(true)
		view.set_live_cadence(1)
		await process_frame
		view.set_camera(camera_mode)
		var cadrage: RefCounted = Cadrage.new(view)
		view.set_cadrage(cadrage)
		# Entrée dans le temps fort, comme la régie : position de départ posée, coupe nette.
		cadrage.couper()
		view.apply_frame(image(fixture, fixture.depart, int(fixture.debut) - 1, true))
		view.apply_frame(image(fixture, fixture.depart, int(fixture.debut) - 1, false))
		var fewest := 99
		var by_kind := {}
		for plan: Dictionary in fixture.plans:
			cadrage.regler(true, str(plan.kind), false)
			view.apply_frame(image(fixture, plan.scene, int(plan.index), false))
			var clock := 0.0
			while clock < float(plan.duree):
				view._process(STEP)
				clock += STEP
				var seen := visible_players(view)
				fewest = mini(fewest, seen)
				by_kind[plan.kind] = mini(int(by_kind.get(plan.kind, 99)), seen)
		report[camera_mode] = by_kind
		# Caméra TV : le groupe ; caméra contact (plus serrée par construction) : jamais l'herbe seule.
		var minimum := 4 if camera_mode == "tv" else 2
		check(fewest >= minimum, "Caméra %s : au moins %d joueurs à l'image pendant le coup de sifflet et le carton (%s)" % [camera_mode, minimum, by_kind])
		view.queue_free()
		await process_frame
	print("MATCH_CADRAGE_ARRET ", JSON.stringify(report))
	print("MATCH_CADRAGE_ARRET_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
