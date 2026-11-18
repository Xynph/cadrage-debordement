extends SceneTree
## Formations des phases arrêtées (match_formations.gd) : mêlée 3-4-1 liée des deux paquets,
## sortie de mêlée, alignement de touche, saut du modèle d'origine.
## Coordonnées : scènes de test écrites comme celles du moteur (dist/match2d.js matchScene),
## pas des mesures d'un vrai match.

const Formations = preload("res://match_formations.gd")

var failures: Array[String] = []
var metrics := {}


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _initialize() -> void:
	call_deferred("run")


## Mêlée du moteur : grille des avants espacés de 2 à 3 m, arrières à 13 m et plus (matchScene).
func scrum(bx: float, possession: int, kind: String = "scrum", key: String = "melee", featured: String = "") -> Dictionary:
	var players: Array = []
	for side in 2:
		var dir := 1.0 if possession == 0 else -1.0
		var attack := side == possession
		for slot in 15:
			var x := bx + (-dir if attack else dir) * (13.0 + (slot - 8) * 2.8)
			var y := 7.0 + (slot - 8) * 9.3
			if slot < 8:
				x = bx + (-1.0 if side == 0 else 1.0) * (1.5 + slot % 3 * 2.1)
				y = 35.0 + (floorf(slot / 3.0) - 1.0) * 2.7
			var id := "s%d_%d" % [side, slot]
			players.append({"id": id, "side": side, "slot": slot, "x": x, "y": y, "featured": id == featured})
	return {"key": key, "kind": kind, "possession": possession, "players": players,
		"ball": {"x": bx, "y": 35.0}, "origin": {"x": bx, "y": 35.0}}


## Touche du moteur (lineoutSpot) : lanceur sur la ligne, rangées à 0,5 m de part et d'autre.
func lineout(mark: float, team: int) -> Dictionary:
	var players: Array = []
	for side in 2:
		var back := -1.0 if side == 0 else 1.0
		for slot in 15:
			var x := mark + back * (13.0 + (slot - 8) * 2.8)
			var y := 7.0 + (slot - 8) * 9.3
			if slot == 1:
				x = mark + (0.0 if side == team else back * 2.0)
				y = 0.0 if side == team else 3.0
			elif slot < 8:
				x = mark + back * 0.5
				y = 5.5 + (slot - 1 if slot > 0 else 0) * 1.5
			elif slot == 8:
				x = mark + back * 2.5
				y = 10.0
			players.append({"id": "t%d_%d" % [side, slot], "side": side, "slot": slot, "x": x, "y": y, "featured": false})
	return {"key": "touche", "kind": "lineout", "possession": team, "players": players,
		"ball": {"x": mark, "y": 0.0}, "origin": {"x": mark, "y": 0.0}}


func check_scrum_formation() -> void:
	var f: Dictionary = Formations.calculer(scrum(60.0, 0))
	check(f.type == "melee", "A scrum scene gives a scrum formation")
	var pack := 0
	for id: String in f.roles:
		if f.roles[id] == "pack": pack += 1
	check(pack == 16, "Both packs are bound in the scrum (%d forwards)" % pack)
	# Premières lignes face à face, de part et d'autre du ballon ; tête contre tête (2,3 m entre les pieds).
	for slot in 3:
		var a: Vector2 = f.places["s0_%d" % slot]
		var b: Vector2 = f.places["s1_%d" % slot]
		check(a.x < 60.0 and b.x > 60.0, "Front row %d: each pack on its own side of the ball" % (slot + 1))
		check(absf((b.x - a.x) - 2.3) < 0.01, "Front row %d: feet 2.3 m apart, heads together" % (slot + 1))
	# Pilier gauche contre pilier droit adverse (loi 19).
	check(is_equal_approx(f.places.s0_0.y, f.places.s1_2.y) and is_equal_approx(f.places.s0_2.y, f.places.s1_0.y), "Looseheads face tightheads")
	# 3-4-1 : trois devant, quatre liés derrière, le n° 8 au fond, tous à moins de 1,3 m du suivant.
	for side in 2:
		var s := 1.0 if side == 0 else -1.0
		var depth := func(slot: int) -> float: return (60.0 - (f.places["s%d_%d" % [side, slot]] as Vector2).x) * s
		check(depth.call(3) > depth.call(1) and depth.call(5) > depth.call(1) and depth.call(7) > depth.call(4), "Side %d: 3-4-1 rows" % side)
		check(absf(depth.call(7)) < 3.5, "Side %d: the number 8 binds within 3.5 m of the ball" % side)
		check(is_equal_approx(float(f.caps["s%d_0" % side]), atan2(s, 0.0)), "Side %d: forwards face the opposing pack" % side)
		check(f.postures["s%d_0" % side] == "premiere_ligne" and f.postures["s%d_7" % side] == "poussee", "Side %d: bound pushing postures" % side)
	# Demi qui introduit : au tunnel, accroupi, tourné vers le tunnel ; demi adverse de son côté du ballon.
	var demi: Vector2 = f.places.s0_8
	check(f.roles.s0_8 == "demi_intro" and f.postures.s0_8 == "introduction", "The put-in scrum-half introduces")
	check(demi.distance_to(Vector2(60.0, 35.0)) < 1.6, "The put-in scrum-half stands at the tunnel (%.2f m)" % demi.distance_to(Vector2(60.0, 35.0)))
	check(demi.y < 35.0, "He feeds from his loosehead side")
	check(f.roles.s1_8 == "demi_adverse" and (f.places.s1_8 as Vector2).x > 60.0, "The opposing scrum-half stays on his side of the ball")
	# Arrières derrière la ligne de hors-jeu (5 m derrière les pieds du n° 8).
	var limite: float = Formations.MELEE[7].x + Formations.PIEDS_N8 + Formations.HORS_JEU
	var near := scrum(60.0, 0)
	for player: Dictionary in near.players:
		if player.id == "s1_9": player.x = 62.0
	var g: Dictionary = Formations.calculer(near)
	check((g.places.s1_9 as Vector2).x >= 60.0 + limite - 0.01, "A back too close is put back behind the scrum offside line")
	check(not g.places.has("s0_12"), "Backs already onside keep the engine's place")
	metrics.front_rows_gap_m = 2.3
	metrics.demi_tunnel_m = snappedf(demi.distance_to(Vector2(60.0, 35.0)), 0.01)


func check_scrum_exit() -> void:
	var f: Dictionary = Formations.calculer(scrum(60.0, 1))
	var avant := {"type": "melee", "centre": f.centre, "introduit": f.introduit}
	var sortie: Dictionary = Formations.calculer(scrum(60.0, 1, "setpiece-win", "sortie", "s1_7"), avant)
	check(sortie.type == "sortie_melee", "The ball won right after a scrum keeps the packs bound for a moment")
	check(not sortie.places.has("s1_7"), "The engine's carrier (number 8) leaves the scrum with the ball")
	check(sortie.places.has("s0_0") and sortie.places.has("s1_0"), "Both packs stay in the scrum while the ball comes out")
	var loin := scrum(30.0, 1, "setpiece-win", "ailleurs")
	check(Formations.calculer(loin, avant).type == "", "A set piece won elsewhere is not a scrum exit")
	check(Formations.calculer(scrum(60.0, 1, "setpiece-win", "sans"), {}).type == "", "No scrum before: no scrum exit")


func check_lineout() -> void:
	var f: Dictionary = Formations.calculer(lineout(40.0, 0))
	check(f.type == "touche", "A lineout scene gives a lineout formation")
	check(f.roles.t0_1 == "lanceur" and is_equal_approx(float(f.caps.t0_1), 0.0), "The hooker throws from the touchline, facing the field")
	check(f.roles.t1_1 != "lanceur", "The opposing hooker is not the thrower")
	check(f.roles.t0_4 == "sauteur", "A lock of the throwing side is the jumper")
	for id in ["t0_0", "t0_3", "t1_5", "t1_7"]:
		check(f.roles[id] in ["alignement", "sauteur"] and is_equal_approx(absf(float(f.caps[id])), PI), "%s lines up facing the touchline" % id)
	check(f.places.is_empty(), "Lineout places stay the engine's (rows 1 m apart, law 18)")


func check_view(view: Node3D) -> void:
	view.apply_frame({"scene": scrum(60.0, 0)})
	for frame in 300:
		view._process(1.0 / 60.0)
	var formations = view._formations
	var worst := 0.0
	var bent := 0
	var lowest_foot := INF
	for side in 2:
		for slot in 8:
			var id := "s%d_%d" % [side, slot]
			var entry: Dictionary = view._actors[id]
			var p: Vector2 = formations.formation.places[id]
			var at: Vector3 = (entry.node as Node3D).position
			worst = maxf(worst, Vector2(at.x, at.z).distance_to(Vector2(p.x - 50.0, p.y - 35.0)))
			var posture: Array = formations.posture_de(id)
			if posture[1] >= 0.99 and (entry.model as Node3D).rotation.x > 0.4:
				bent += 1
			check(absf(angle_difference((entry.node as Node3D).rotation.y, float(formations.formation.caps[id]))) < 0.05, "%s faces the opposing pack" % id)
			var rig: Skeleton3D = entry.rig
			for leg in ["L", "R"]:
				lowest_foot = minf(lowest_foot, rig.to_global(rig.get_bone_global_pose(rig.find_bone("Foot." + leg)).origin).y)
	check(worst < 0.05, "Every forward reaches his scrum place (%.2f m)" % worst)
	check(bent == 16, "All sixteen forwards are bound and bent over (%d)" % bent)
	check(lowest_foot > -0.03, "Bound forwards keep their feet on the grass (%.3f m)" % lowest_foot)
	var demi: Dictionary = view._actors.s0_8
	check((demi.model as Node3D).rotation.x > 0.2, "The put-in scrum-half crouches at the tunnel")
	metrics.scrum_place_error_m = snappedf(worst, 0.001)
	metrics.scrum_lowest_foot_m = snappedf(lowest_foot, 0.001)
	# Ballon gagné : les paquets restent liés SORTIE s, puis rejoignent les places de la scène.
	var sortie := scrum(60.0, 0, "setpiece-win", "sortie", "s0_7")
	view.apply_frame({"scene": sortie})
	view._process(Formations.SORTIE * 0.5)
	check((view._actors.s1_0.model as Node3D).rotation.x > 0.4, "Packs stay bound while the ball comes out")
	for frame in 150:
		view._process(1.0 / 60.0)
	var moteur: Vector3 = view._world(sortie.players.filter(func(p: Dictionary) -> bool: return p.id == "s1_0")[0])
	check((view._actors.s1_0.target as Vector3).is_equal_approx(moteur), "After the exit, forwards head for their engine places")
	for frame in 60:
		view._process(1.0 / 60.0)
	check(absf((view._actors.s1_0.model as Node3D).rotation.x) < 0.01, "Unbound forwards stand up again")
	# Phase ordinaire : aucune posture ni place imposée.
	var jeu := scrum(60.0, 0, "carry", "jeu", "s0_12")
	view.apply_frame({"scene": jeu})
	check(not view._formations.active(), "Open play has no set-piece formation")
	# Saut du modèle d'origine (touche).
	check(view.jouer_clip_natif("s0_4", "Man_Jump", 0.19, -1.0, false, 0.4), "The original model's jump clip can be played")
	view._process(1.0 / 60.0)
	var animation: AnimationPlayer = view._actors.s0_4.animation
	check(str(animation.current_animation).ends_with("Man_Jump"), "The jumper plays Man_Jump")
	check(not view.jouer_clip_natif("s0_4", "Clip_Inconnu"), "An unknown clip is refused")


func run() -> void:
	check_scrum_formation()
	check_scrum_exit()
	check_lineout()
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	check_view(view)
	print("MATCH_FORMATIONS_METRICS ", JSON.stringify(metrics))
	if failures.is_empty():
		print("MATCH_FORMATIONS_OK")
	quit(0 if failures.is_empty() else 1)
