extends SceneTree
## Chute physique au plaquage (match_chute_physique.gd) : un plaquage des pistes du chorégraphe,
## filmé et mesuré (outil manuel, lancé avec --fixed-fps 30 --disable-vsync).
##   CHUTE_PISTES    fichier {cas:[{entree, pistes}]} (tools/chute-physique/pistes.cjs)
##   CHUTE_SORTIE    dossier des images et de mesure-<mode>.json
##   CHUTE_MODE      « mesure » (aucune image : temps de chaque image) ou « images »
##   CHUTE_INSTANTS  secondes de pistes à capturer, séparées par des virgules (mode images)
##   CHUTE_CAMERA    « proche » (au-dessus de l'épaule) ou « ras » (au ras de la pelouse)
##   CHUTE_SANS=1    animation seule (comparaison) : la chute physique est coupée
## Mesures sur la fenêtre du plaquage (-0,1 s à +1,3 s) : hauteur minimale des os des deux joueurs
## (haut de la tête compris), interpénétration des bustes et têtes, écart ballon-mains du porteur,
## temps par image ; racines relevées (identiques avec et sans chute).

const View = preload("res://match_view.gd")
const EXCLUS := ["Bone", "PoleTarget.L", "PoleTarget.R"]
## Volumes du haut du corps (os de départ, os d'arrivée ou longueur, rayon) pour l'interpénétration.
const VOLUMES := [["Abdomen", "Neck", 0.16], ["Head", 0.22, 0.1]]


## Caméra posée après la vue (priorité haute) : elle suit la RACINE du porteur plaqué, identique
## avec et sans chute, donc même plan.
class Camera extends Node:
	var view
	var id := ""
	var mode := "proche"
	func _process(_delta: float) -> void:
		if not view._actors.has(id):
			return
		var p: Vector3 = (view._actors[id].node as Node3D).position
		var cam: Camera3D = view._camera
		if mode == "ras":
			cam.fov = 40.0
			cam.global_transform = Transform3D(Basis.IDENTITY, p + Vector3(0.6, 0.09, 4.4)).looking_at(p + Vector3(0.0, 0.25, 0.0), Vector3.UP)
		else:
			cam.fov = 30.0
			cam.global_transform = Transform3D(Basis.IDENTITY, p + Vector3(1.6, 1.7, 4.6)).looking_at(p + Vector3(0.0, 0.55, 0.0), Vector3.UP)


func _initialize() -> void:
	call_deferred("run")


func start_frame(entree: Dictionary) -> Dictionary:
	var players: Array = []
	for p: Dictionary in entree.joueurs:
		players.append({"id": str(p.id), "side": int(p.side), "slot": int(p.slot), "x": float(p.x), "y": float(p.y),
			"featured": str(p.id) == str(entree.get("porteur", ""))})
	var scene := {"kind": "reception", "key": "[0,\"chute\",\"capture\"]", "possession": int(entree.possession), "team": int(entree.possession),
		"players": players, "ball": entree.ballon, "origin": entree.ballon}
	return {"scene": scene, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}], "events": [], "paused": false}


static func plus_bas(rig: Skeleton3D) -> Array:
	var g := rig.global_transform
	var bas := INF
	var nom_bas := ""
	for i in rig.get_bone_count():
		var nom := rig.get_bone_name(i)
		if nom in EXCLUS:
			continue
		var pose := g * rig.get_bone_global_pose(i)
		var y := pose.origin.y
		if nom == "Head":
			y = minf(y, (pose.origin + pose.basis.y.normalized() * 0.2).y)
		if y < bas:
			bas = y
			nom_bas = nom
	return [bas, nom_bas]


static func segments(rig: Skeleton3D) -> Array:
	var g := rig.global_transform
	var liste: Array = []
	for v: Array in VOLUMES:
		var a := g * rig.get_bone_global_pose(rig.find_bone(v[0]))
		var b: Vector3 = (g * rig.get_bone_global_pose(rig.find_bone(v[1]))).origin if v[1] is String else a.origin + a.basis.y.normalized() * float(v[1])
		liste.append([a.origin, b, float(v[2])])
	return liste


## Interpénétration (m) : plus grand recouvrement entre les volumes du haut du corps des deux joueurs.
static func penetration(r1: Skeleton3D, r2: Skeleton3D) -> float:
	var pire := -INF
	for s1: Array in segments(r1):
		for s2: Array in segments(r2):
			var r := Geometry3D.get_closest_points_between_segments(s1[0], s1[1], s2[0], s2[1])
			pire = maxf(pire, float(s1[2]) + float(s2[2]) - (r[0] as Vector3).distance_to(r[1]))
	return pire


func run() -> void:
	var dossier := OS.get_environment("CHUTE_SORTIE")
	var mode := OS.get_environment("CHUTE_MODE")
	var donnees: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CHUTE_PISTES")))
	if dossier.is_empty() or not donnees is Dictionary:
		push_error("CHUTE_SORTIE et CHUTE_PISTES requis")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(dossier)
	var instants: Array[float] = []
	for s in OS.get_environment("CHUTE_INSTANTS").split(",", false):
		instants.append(float(s))
	var cas: Dictionary = donnees.cas[0]
	var pistes: Dictionary = cas.pistes
	var plaquage: Dictionary = {}
	for e: Dictionary in pistes.get("evenements", []):
		if str(e.get("type", "")) == "plaquage" and float(e.get("t", 0.0)) >= 1.0:
			plaquage = e
			break
	var porteur := str(plaquage.get("porteur", ""))
	var plaqueur := str(plaquage.get("plaqueur", ""))
	var view = View.new()
	root.add_child(view)
	view.set_gestes(true)
	view.set_live_cadence(1)
	view.set_gestes(false)
	if OS.get_environment("CHUTE_SANS") == "1":
		view._chute_physique.actif = false
	var camera := Camera.new()
	camera.view = view
	camera.id = porteur
	camera.mode = OS.get_environment("CHUTE_CAMERA") if not OS.get_environment("CHUTE_CAMERA").is_empty() else "proche"
	camera.process_priority = 1000
	root.add_child(camera)
	await process_frame
	view.apply_frame(start_frame(cas.entree))
	for i in 2:
		await process_frame
	if not view.jouer_choregraphie(pistes):
		push_error("pistes refusées")
		quit(1)
		return
	var t_plaquage := float(plaquage.get("t", -10.0))
	var mesure := {"source": str(cas.get("titre", "")), "chute": view._chute_physique.actif, "moteur": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"plaquage": plaquage, "images": 0, "fenetre": 0, "us_total": 0, "us_fenetre": 0, "max_us_fenetre": 0, "max_us_hors": 0,
		"sol_min": INF, "sol_os": "", "penetration_max": -INF, "ballon_mains_max": 0.0, "ballon_mains": {}, "captures": [], "racines": {}}
	var precedent := Time.get_ticks_usec()
	var prochain := 0
	var vues := 0
	while view.choregraphie_active() and not view.choregraphie_finie():
		await process_frame
		var maintenant := Time.get_ticks_usec()
		var us := maintenant - precedent
		var t: float = view.choregraphie_temps()
		mesure.images += 1
		mesure.us_total += us
		vues += 1
		if t >= t_plaquage - 0.1 and t <= t_plaquage + 1.3:
			mesure.fenetre += 1
			mesure.us_fenetre += us
			mesure.max_us_fenetre = maxi(int(mesure.max_us_fenetre), us)
			for id in [porteur, plaqueur]:
				if not view._actors.has(id):
					continue
				var p: Vector3 = view._actors[id].node.position
				mesure.racines["%s@%.3f" % [id, t]] = [snappedf(p.x, 0.0001), snappedf(p.z, 0.0001), snappedf(view._actors[id].node.rotation.y, 0.0001)]
				var bas := plus_bas(view._actors[id].rig)
				if float(bas[0]) < float(mesure.sol_min):
					mesure.sol_min = bas[0]
					mesure.sol_os = "%s %s à %.2f s" % [id, bas[1], t]
			if view._actors.has(porteur) and view._actors.has(plaqueur):
				mesure.penetration_max = maxf(float(mesure.penetration_max), penetration(view._actors[porteur].rig, view._actors[plaqueur].rig))
				if view._ball_attached and view._carrier_id == porteur:
					var rig: Skeleton3D = view._actors[porteur].rig
					var g := rig.global_transform
					var mains := INF
					for nom in ["Palm.L", "Palm.R"]:
						mains = minf(mains, (g * rig.get_bone_global_pose(rig.find_bone(nom))).origin.distance_to(view._ball.global_position))
					mesure.ballon_mains_max = maxf(float(mesure.ballon_mains_max), mains)
					mesure.ballon_mains["%.3f" % t] = snappedf(mains, 0.001)
		elif vues > 30:
			# Hors de la fenêtre (après la première seconde, chargements passés).
			mesure.max_us_hors = maxi(int(mesure.max_us_hors), us)
		if mode == "images" and prochain < instants.size() and t >= instants[prochain]:
			var image := root.get_texture().get_image()
			var nom := "t%05.2f.png" % instants[prochain]
			image.save_png(dossier.path_join(nom))
			mesure.captures.append(nom)
			prochain += 1
			# Le temps d'écriture ne compte pas dans la mesure.
			maintenant = Time.get_ticks_usec()
		precedent = maintenant
	mesure["declenchements"] = view._chute_physique.declenchements
	mesure["butoirs"] = view._chute_physique.butoirs
	mesure["ips_moyen"] = mesure.images * 1000000.0 / maxf(1.0, float(mesure.us_total))
	mesure["ips_fenetre"] = mesure.fenetre * 1000000.0 / maxf(1.0, float(mesure.us_fenetre))
	var f := FileAccess.open(dossier.path_join("mesure-%s.json" % mode), FileAccess.WRITE)
	f.store_string(JSON.stringify(mesure))
	f.close()
	var court := {}
	mesure["ruptures"] = view._chute_physique.ruptures
	for k in ["chute", "ips_fenetre", "max_us_fenetre", "max_us_hors", "sol_min", "sol_os", "penetration_max", "ballon_mains_max", "declenchements", "butoirs", "ruptures", "moteur"]:
		court[k] = mesure[k]
	print("CHUTE_PHYSIQUE ", mode, " ", JSON.stringify(court))
	quit(0)
