extends SceneTree
const View = preload("res://match_view.gd")
class RegieTemoin extends Node:
	var suivi: Array[Dictionary] = []
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func run() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join("../../tests")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("fixtures/match-gestes-sequence.json")))
	# Le moteur peut désigner n'importe quel poste, dont un arrière qui était marcheur.
	for slot in 15:
		var view = View.new()
		root.add_child(view)
		view.set_process(false)
		view.set_gestes(true)
		view.set_live_cadence(1)
		await process_frame
		var events: Array = []
		var designated := ""
		for i in 5:
			var frame: Dictionary = fixture.frames[i].duplicate(true)
			if i == 4:
				for player: Dictionary in frame.scene.players:
					player.featured = player.side == 1 and player.slot == slot
					if player.featured: designated = player.id
			events.append_array(frame.events)
			view.apply_frame({"scene": frame.scene, "teams": frame.teams, "events": events, "paused": false})
			for step in 200: view._process(1.0 / 30.0)
		var gestes = view._gestes
		check(gestes.phase == "maul", "Transition achevée, poste %d" % slot)
		# Le demi reste hors du maul et utilise le repli existant vers le lanceur.
		check(gestes.carrier == designated or slot == 8, "Porteur conservé, poste %d" % slot)
		check(gestes.cast[gestes.carrier].has("slot") and gestes.cast[gestes.carrier].role == "tail", "Porteur lié en queue, poste %d" % slot)
		var complete := true
		for member: Dictionary in gestes.cast.values():
			complete = complete and member.has("mark" if member.role == "walk" else "slot")
		check(complete and not gestes._frame_points().is_empty(), "Distribution et cadrage cohérents, poste %d" % slot)
		view.free()
	# La sonde garde les tableaux, jamais les instances libérées. Les derniers
	# append après le premier passage sont conservés, sans doublon à chaque image.
	var suivi = load(base.path_join("match-capture-suivi.gd")).new()
	for i in 2:
		var regie := RegieTemoin.new()
		root.add_child(regie)
		regie.suivi.append({"evenement": "temps_fort", "id": i})
		suivi.observe(regie)
		suivi.observe(regie)
		regie.suivi.append({"evenement": "echeance", "id": i})
		regie.queue_free()
		await process_frame
		check(not is_instance_valid(regie), "Régie réellement libérée %d" % i)
	var report := {"suivi": suivi.collect(), "termine": true}
	var file := FileAccess.open("user://match-capture-regression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	var read: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://match-capture-regression.json"))
	check(read.termine and read.suivi.size() == 4, "Rapport écrit et relu après libération des deux scènes")
	check(read.suivi[3].evenement == "echeance", "Dernier ajout conservé après libération")
	print("MATCH_COMPLET_REGRESSION_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
