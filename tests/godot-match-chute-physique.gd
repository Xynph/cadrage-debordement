extends SceneTree
## Chute physique au plaquage (match_chute_physique.gd) et plancher (match_plancher.gd) : le même
## plaquage joué deux fois, avec et sans chute. Racines identiques, aucun os sous la pelouse,
## buste du plaqué réellement différent pendant la chute puis rendu à l'animation, corps physiques
## rangés après. Coordonnées de test, jamais un vrai match.

const EXCLUS := ["Bone", "PoleTarget.L", "PoleTarget.R"]

var failures: Array[String] = []
var metrics := {}


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _initialize() -> void:
	call_deferred("run")


## Même progression que tests/godot-match-contacts.gd : porteur « c », défense alignée devant.
func carry(key: String, depuis: float, x: float, ligne: float, avance: float = 1.0) -> Dictionary:
	var players: Array = [{"id": "c", "side": 0, "featured": true, "x": lerpf(depuis, x, avance), "y": 35.0}]
	for i in 5:
		players.append({"id": "a%d" % i, "side": 0, "featured": false, "x": lerpf(depuis, x, avance) - 3.0 - i * 1.5, "y": 27.0 + i * 4.0})
		players.append({"id": "d%d" % i, "side": 1, "featured": false, "x": ligne + (i % 2) * 2.0, "y": 25.0 + i * 5.0})
	return {"scene": {"key": key, "kind": "carry", "possession": 0, "players": players,
		"origin": {"x": depuis, "y": 35.0}, "ball": {"x": x, "y": 35.0}}}


static func plus_bas(rig: Skeleton3D) -> float:
	var g := rig.global_transform
	var bas := INF
	for i in rig.get_bone_count():
		if rig.get_bone_name(i) in EXCLUS:
			continue
		var pose := g * rig.get_bone_global_pose(i)
		bas = minf(bas, pose.origin.y)
		if rig.get_bone_name(i) == "Head":
			bas = minf(bas, (pose.origin + pose.basis.y.normalized() * 0.2).y)
	return bas


## Joue le plaquage ; rend, image par image, les racines, le buste du porteur et l'os le plus bas.
func jouer(avec_chute: bool) -> Dictionary:
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	view._chute_physique.actif = avec_chute
	view.apply_frame(carry("depart", 40.0, 40.0, 62.0))
	view._process(3.0)
	var images: Array = []
	var bas := INF
	var contact := -1
	var actifs_max := 0
	var mouvement := 15.0 / 6.5
	for frame in 60 * 6:
		var t := frame / 60.0
		if frame % 12 == 0 and t <= mouvement + 0.2:
			view.apply_frame(carry("course", 40.0, 55.0, 62.0, clampf(t / mouvement, 0.0, 1.0)))
		view._process(1.0 / 60.0)
		await physics_frame
		if contact < 0 and view._impacts.plaquages > 0:
			contact = frame
		actifs_max = maxi(actifs_max, view._chute_physique.actifs().size())
		var racines := {}
		for id: String in view._actors:
			var p: Vector3 = (view._actors[id].node as Node3D).position
			racines[id] = p
			bas = minf(bas, plus_bas(view._actors[id].rig))
		var rig: Skeleton3D = view._actors.c.rig
		images.append({"racines": racines, "buste": rig.get_bone_global_pose(rig.find_bone("Torso")).basis.get_rotation_quaternion()})
	var rangés := true
	for r: Dictionary in view._chute_physique._reserve:
		for groupe in ["corps"]:
			for nom: String in r[groupe]:
				var corps: RigidBody3D = r[groupe][nom]
				rangés = rangés and corps.freeze and corps.collision_layer == 0
	var resultat := {"images": images, "bas": bas, "contact": contact, "declenchements": view._chute_physique.declenchements,
		"actifs_fin": view._chute_physique.actifs().size(), "actifs_max": actifs_max, "ranges": rangés,
		"reserve": view._chute_physique._reserve.size(), "ruptures": view._chute_physique.ruptures}
	# Plancher : un joueur enfoncé d'un mètre (pose forcée) est remonté, puis rendu tel quel.
	var entry: Dictionary = view._actors.a0
	var model: Node3D = entry.model
	var y0 := model.position.y
	model.position.y = y0 - 1.0
	view._plancher.poser("a0", entry)
	resultat["plancher_bas"] = plus_bas(entry.rig)
	view._plancher.restaurer("a0", entry)
	resultat["plancher_rendu"] = is_equal_approx(model.position.y, y0 - 1.0)
	model.position.y = y0
	view.queue_free()
	await process_frame
	return resultat


func run() -> void:
	var avec: Dictionary = await jouer(true)
	var sans: Dictionary = await jouer(false)
	check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "Jolt Physics is the 3D physics engine")
	check(avec.contact >= 0 and sans.contact == avec.contact, "The same tackle happens at the same frame with and without the fall (%d / %d)" % [avec.contact, sans.contact])
	check(avec.declenchements == 1 and sans.declenchements == 0, "The physical fall starts once, only when enabled (%d / %d)" % [avec.declenchements, sans.declenchements])
	check(avec.reserve == 3, "Physical skeletons are prepared in advance (%d)" % avec.reserve)
	check(avec.ruptures == 0, "The physical chain never breaks (%d)" % avec.ruptures)
	var ecart_racine := 0.0
	var ecart_buste := 0.0
	var ecart_fin := 0.0
	for i in mini(avec.images.size(), sans.images.size()):
		for id: String in avec.images[i].racines:
			ecart_racine = maxf(ecart_racine, (avec.images[i].racines[id] as Vector3).distance_to(sans.images[i].racines[id]))
		var angle := rad_to_deg((avec.images[i].buste as Quaternion).angle_to(sans.images[i].buste))
		if i > avec.contact and i <= avec.contact + 60:
			ecart_buste = maxf(ecart_buste, angle)
		elif i > avec.contact + 75:
			ecart_fin = maxf(ecart_fin, angle)
	metrics.ecart_racine_m = ecart_racine
	metrics.ecart_buste_deg = snappedf(ecart_buste, 0.1)
	metrics.ecart_apres_deg = snappedf(ecart_fin, 0.01)
	metrics.os_plus_bas_m = [snappedf(avec.bas, 0.001), snappedf(sans.bas, 0.001)]
	check(ecart_racine < 0.00001, "Roots stay on their trajectories (%.6f m)" % ecart_racine)
	check(ecart_buste > 2.0, "The tackled carrier's chest reacts physically during the fall (%.1f°)" % ecart_buste)
	check(ecart_fin < 0.5, "The chest is back on the animation after the fall (%.2f°)" % ecart_fin)
	check(avec.bas >= 0.0 and sans.bas >= 0.0, "No bone goes under the grass (%.3f m / %.3f m)" % [avec.bas, sans.bas])
	check(avec.actifs_max == 1 and avec.actifs_fin == 0 and avec.ranges, "Physical bodies are put away after the fall")
	check(avec.plancher_bas >= 0.0 and avec.plancher_rendu, "The floor lifts a sunk player and restores the pose (%.3f m)" % avec.plancher_bas)
	print("MATCH_CHUTE_PHYSIQUE_CHECKS ", JSON.stringify({"failures": failures, "metrics": metrics}))
	quit(1 if not failures.is_empty() else 0)
