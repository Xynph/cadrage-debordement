extends SceneTree
## Formations des phases arrêtées (match_formations.gd) : mêlée 3-4-1 liée des deux paquets,
## sortie de mêlée, alignement de touche, saut du modèle d'origine.
## Coordonnées : scènes de test écrites comme celles du moteur (dist/match2d.js matchScene),
## pas des mesures d'un vrai match.

const Formations = preload("res://match_formations.gd")

## 19 novembre 2026 : mêlée en vue TV, film 1280 x 720. Part de la largeur de l'image entre les pieds
## extrêmes des seize avants (6 m ; corps compris, les paquets en prennent environ 1,15 fois plus) :
## autour de la moitié de l'image, ni petite tache (un quart au film d'avant) ni gros plan coupé.
const PAQUET_PART := Vector2(0.4, 0.62)
## Ballon de l'introduction visible : aucun buste, cou ou tête d'un joueur plus proche de la caméra
## que lui à moins de MASQUE_BUSTE m (demi-largeur d'épaules), mesuré à l'écran à la distance du ballon.
const MASQUE_BUSTE := 0.2
const MASQUE_OS := ["Abdomen", "Torso", "Neck", "Head"]
## Demi et ballon de l'introduction dans l'image, à CADRE_MARGE de ses bords au moins.
const CADRE_MARGE := 0.06

var failures: Array[String] = []
var metrics := {}


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


## Centre de la tête d'un joueur : l'os « Head » est à la base du crâne ; le centre est 9 cm plus
## loin dans l'axe cou -> tête (crâne de 0,2 m environ sur le modèle calibré à 1,9 m).
func head_centre(view, id: String) -> Vector3:
	var rig: Skeleton3D = view._actors[id].rig
	var head := rig.to_global(rig.get_bone_global_pose(rig.find_bone("Head")).origin)
	var neck := rig.to_global(rig.get_bone_global_pose(rig.find_bone("Neck")).origin)
	return head + (head - neck).normalized() * 0.09


## Bustes et têtes (capsules de la sonde des contacts du match filmé) : [os, os d'arrivée ou longueur, rayon].
const BUSTES := [["Hips", "Abdomen", 0.13], ["Abdomen", "Torso", 0.14], ["Torso", "Neck", 0.14], ["Head", 0.22, 0.1]]
const BUST_OVERLAP_MAX := 0.08
## Corps entier (bras et jambes compris, rayons de la sonde des contacts du match filmé).
const CORPS := BUSTES + [["UpperLeg.L", "LowerLeg.L", 0.08], ["UpperLeg.R", "LowerLeg.R", 0.08], ["LowerLeg.L", "Foot.L", 0.06],
	["LowerLeg.R", "Foot.R", 0.06], ["UpperArm.L", "LowerArm.L", 0.06], ["UpperArm.R", "LowerArm.R", 0.06], ["LowerArm.L", "Palm.L", 0.05],
	["LowerArm.R", "Palm.R", 0.05]]


static func _busts(rig: Skeleton3D, liste: Array = BUSTES) -> Array:
	var g := rig.global_transform
	var out: Array = []
	for v: Array in liste:
		var a := g * rig.get_bone_global_pose(rig.find_bone(v[0]))
		var b: Vector3 = (g * rig.get_bone_global_pose(rig.find_bone(v[1]))).origin if v[1] is String else a.origin + a.basis.y.normalized() * float(v[1])
		out.append([a.origin, b, float(v[2])])
	return out


## Plus forte pénétration (m) entre les bustes et têtes de deux joueurs.
func busts_overlap(view, a: String, b: String, liste: Array = BUSTES) -> float:
	var worst := -INF
	for s1: Array in _busts(view._actors[a].rig, liste):
		for s2: Array in _busts(view._actors[b].rig, liste):
			var r := Geometry3D.get_closest_points_between_segments(s1[0], s1[1], s2[0], s2[1])
			worst = maxf(worst, float(s1[2]) + float(s2[2]) - (r[0] as Vector3).distance_to(r[1]))
	return worst


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
	# Premières lignes face à face, de part et d'autre du ballon ; épaule contre épaule (2,4 m entre les pieds).
	for slot in 3:
		var a: Vector2 = f.places["s0_%d" % slot]
		var b: Vector2 = f.places["s1_%d" % slot]
		check(a.x < 60.0 and b.x > 60.0, "Front row %d: each pack on its own side of the ball" % (slot + 1))
		check(absf((b.x - a.x) - 2.4) < 0.01, "Front row %d: feet 2.4 m apart, shoulder to shoulder" % (slot + 1))
	# Pilier gauche contre pilier droit adverse, tête à l'extérieur de la sienne (loi 19).
	var ecart: float = 2.0 * Formations.DECALAGE_TETES
	check(absf((f.places.s1_2.y - f.places.s0_0.y) - ecart) < 0.01 and absf((f.places.s1_0.y - f.places.s0_2.y) - ecart) < 0.01, "Looseheads bind outside the opposing tighthead")
	# Têtes emboîtées : les six têtes alternent d'un paquet à l'autre, jamais deux partenaires côte à côte,
	# et deux têtes adverses voisines sont à plus de deux rayons de tête l'une de l'autre.
	var front: Array = []
	for side in 2:
		for slot in 3:
			front.append({"side": side, "y": (f.places["s%d_%d" % [side, slot]] as Vector2).y})
	front.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	var alternate := true
	var closest := INF
	for i in range(1, front.size()):
		alternate = alternate and front[i].side != front[i - 1].side
		closest = minf(closest, float(front[i].y) - float(front[i - 1].y))
	check(alternate, "Front-row heads alternate between the two packs")
	check(closest > 2.0 * Formations.TETE_RAYON, "Neighbouring opposing heads are more than two head radii apart (%.2f m)" % closest)
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
	check(demi.distance_to(Vector2(60.0, 35.0)) < 2.0, "The put-in scrum-half stands at the tunnel (%.2f m)" % demi.distance_to(Vector2(60.0, 35.0)))
	# Côté de la caméra TV (touche proche, y croissants), pour les deux équipes : le ballon tenu bas
	# n'est jamais caché derrière les deux paquets (19/11/2026).
	check(demi.y > 35.0, "He feeds from the camera side")
	var bord := -INF
	for side in 2:
		for slot in 3: bord = maxf(bord, (f.places["s%d_%d" % [side, slot]] as Vector2).y)
	# Hors du paquet : à l'extérieur des premières lignes de son côté.
	check(demi.y > bord + 0.6, "The scrum-half crouches outside the front rows")
	# Le ballon tenu devant lui (BALLON_DEVANT, vers le tunnel) arrive à l'entrée du tunnel.
	var ballon := demi + Vector2(sin(float(f.caps.s0_8)), cos(float(f.caps.s0_8))) * Formations.BALLON_DEVANT
	# 19 novembre 2026 : demi décalé vers son paquet, ballon ramené de BALLON_TUNNEL m au plus vers la
	# ligne du tunnel (x = 60) : sur le côté du demi, pas sous son buste (vu de la caméra TV).
	ballon.x = move_toward(ballon.x, 60.0, Formations.BALLON_TUNNEL)
	check(demi.x < 60.0 - 0.25 and absf(ballon.x - 60.0) < 0.1 and absf(ballon.x - demi.x) >= 0.25, "The scrum-half stands beside the tunnel, ball on the tunnel line beside him (demi %.2f, ball %.2f)" % [demi.x, ballon.x])
	check(ballon.distance_to(Vector2(60.0, 35.0)) < 1.4 and ballon.y > bord + 0.3, "The ball is held at the mouth of the tunnel (%.2f m from the mark)" % ballon.distance_to(Vector2(60.0, 35.0)))
	var autre: Dictionary = Formations.calculer(scrum(60.0, 1))
	check(str(autre.roles.get("s1_8", "")) == "demi_intro" and (autre.places.s1_8 as Vector2).y > bord + 0.6 and absf(angle_difference(float(autre.caps.s1_8), float(f.caps.s0_8))) < 0.01, "The other team also feeds from the camera side, facing the tunnel")
	check(f.roles.s1_8 == "demi_adverse" and (f.places.s1_8 as Vector2).x > 60.0, "The opposing scrum-half stays on his side of the ball")
	# Demi adverse hors du paquet : nettement à l'extérieur de tous les avants (pas un avant à demi debout).
	var dehors := INF
	for side in 2:
		for slot in 8:
			dehors = minf(dehors, absf((f.places.s1_8 as Vector2).y - 35.0) - absf((f.places["s%d_%d" % [side, slot]] as Vector2).y - 35.0))
	check(dehors >= Formations.DEMI_HORS_PAQUET - 0.01 and f.postures.s1_8 == "aguets", "The opposing scrum-half stands clear outside both packs (%.2f m)" % dehors)
	# Arrières derrière la ligne de hors-jeu (5 m derrière les pieds du n° 8).
	var limite: float = Formations.MELEE[7].x + Formations.PIEDS_N8 + Formations.HORS_JEU
	var near := scrum(60.0, 0)
	for player: Dictionary in near.players:
		if player.id == "s1_9": player.x = 62.0
	var g: Dictionary = Formations.calculer(near)
	check((g.places.s1_9 as Vector2).x >= 60.0 + limite - 0.01, "A back too close is put back behind the scrum offside line")
	check(not g.places.has("s0_12"), "Backs already onside keep the engine's place")
	metrics.front_rows_gap_m = 2.4
	metrics.front_heads_lateral_gap_m = snappedf(closest, 0.001)
	metrics.demi_tunnel_m = snappedf(demi.distance_to(Vector2(60.0, 35.0)), 0.01)


func check_scrum_exit() -> void:
	var f: Dictionary = Formations.calculer(scrum(60.0, 1))
	var avant := {"type": "melee", "centre": f.centre, "introduit": f.introduit}
	var sortie: Dictionary = Formations.calculer(scrum(60.0, 1, "setpiece-win", "sortie", "s1_7"), avant)
	check(sortie.type == "sortie_melee", "The ball won right after a scrum keeps the packs bound for a moment")
	# 25/11/2026 (Léo) : le n° 8 qui se détache contourne sa mêlée par le flanc, hors des deux paquets.
	check(str(sortie.roles.get("s1_7", "")) == "n8_sortie", "The engine's carrier (number 8) leaves the scrum with the ball")
	var flanc: Vector2 = sortie.places.get("s1_7", Vector2.ZERO)
	check(absf(flanc.y - sortie.centre.y) >= Formations.CONTOUR_COTE.y - 0.01, "The number 8 goes round his scrum, outside both packs (%.2f m from its axis)" % absf(flanc.y - sortie.centre.y))
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
	# Têtes des premières lignes : jamais l'une dans l'autre (plus de deux rayons de tête entre deux
	# têtes adverses), mesuré sur les os des modèles penchés.
	var heads := {}
	for side in 2:
		for slot in 3:
			heads["s%d_%d" % [side, slot]] = head_centre(view, "s%d_%d" % [side, slot])
	var head_gap := INF
	for a in 3:
		for b in 3:
			head_gap = minf(head_gap, (heads["s0_%d" % a] as Vector3).distance_to(heads["s1_%d" % b]))
	check(head_gap > 2.0 * Formations.TETE_RAYON, "Opposing front-row heads never interpenetrate (%.3f m apart, %.2f m needed)" % [head_gap, 2.0 * Formations.TETE_RAYON])
	var head_height := 0.0
	for id: String in heads:
		head_height = maxf(head_height, (heads[id] as Vector3).y)
	check(head_height < 1.3, "Front-row heads are down at scrum height (%.2f m at most)" % head_height)
	# Tout le paquet, des deux côtés : buste incliné et tête basse (aucun avant à demi debout).
	var pack_head := 0.0
	var upright := ""
	for side in 2:
		for slot in 8:
			var id := "s%d_%d" % [side, slot]
			var h: float = head_centre(view, id).y
			pack_head = maxf(pack_head, h)
			if h >= 1.35 or (view._actors[id].model as Node3D).rotation.x <= 0.4 or formations.posture_de(id)[0] not in ["premiere_ligne", "poussee"]:
				upright += " %s (%.2f m)" % [id, h]
	check(upright.is_empty(), "Every forward of both packs is bent over, head low (%.2f m at most);%s" % [pack_head, upright])
	# Liés, jamais fondus : entre deux avants de la mêlée formée, aucun buste ni tête dans un autre.
	var pack_fondu := 0.0
	for a in 16:
		for b in range(a + 1, 16):
			pack_fondu = maxf(pack_fondu, busts_overlap(view, "s%d_%d" % [a / 8, a % 8], "s%d_%d" % [b / 8, b % 8]))
	check(pack_fondu <= BUST_OVERLAP_MAX, "Bound scrum: no bust or head inside another (%.3f m, %.2f m allowed)" % [pack_fondu, BUST_OVERLAP_MAX])
	metrics.scrum_bust_overlap_m = snappedf(pack_fondu, 0.001)
	metrics.scrum_pack_head_max_m = snappedf(pack_head, 0.01)
	metrics.scrum_head_gap_m = snappedf(head_gap, 0.001)
	metrics.scrum_head_height_m = snappedf(head_height, 0.01)
	# Introduction : le demi accroupi tient le ballon bas, à hauteur de genoux, à l'entrée du tunnel.
	var rig: Skeleton3D = demi.rig
	var hips := 0.0
	var knees := 0.0
	for leg in ["L", "R"]:
		hips += rig.to_global(rig.get_bone_global_pose(rig.find_bone("UpperLeg." + leg)).origin).y * 0.5
		knees += rig.to_global(rig.get_bone_global_pose(rig.find_bone("LowerLeg." + leg)).origin).y * 0.5
	var ball: Vector3 = view._ball.global_position
	check(view._carrier_id == "s0_8" and view._formations.tient_ballon("s0_8"), "The put-in scrum-half holds the ball himself")
	check(hips < 0.65, "The put-in scrum-half is crouched (hips %.2f m high)" % hips)
	check(ball.y < 0.65 and absf(ball.y - clampf(knees, Formations.BALLON_BAS_MIN, Formations.BALLON_BAS_MAX)) < 0.12, "The ball is held low, at knee height (ball %.2f m, knees %.2f m)" % [ball.y, knees])
	check(Vector2(ball.x - 10.0, ball.z).length() < 1.5, "The ball is held at the tunnel (%.2f m from the mark)" % Vector2(ball.x - 10.0, ball.z).length())
	# 19 novembre 2026 : ballon sur la ligne du tunnel, sur le côté du demi (pas sous son buste).
	var demi_x: float = (demi.node as Node3D).position.x
	check(absf(ball.x - 10.0) < 0.15 and absf(ball.x - demi_x) >= 0.25, "The ball is on the tunnel line, beside the scrum-half (ball x %.2f, scrum-half x %.2f)" % [ball.x - 10.0, demi_x - 10.0])
	var grip := 0.0
	for hand in ["Palm.L", "Palm.R"]:
		grip = maxf(grip, rig.to_global(rig.get_bone_global_pose(rig.find_bone(hand)).origin).distance_to(ball))
	check(grip < 0.3, "Both hands are on the ball (%.2f m)" % grip)
	metrics.intro_ball_height_m = snappedf(ball.y, 0.01)
	metrics.intro_knees_m = snappedf(knees, 0.01)
	metrics.intro_hips_m = snappedf(hips, 0.01)
	metrics.scrum_place_error_m = snappedf(worst, 0.001)
	metrics.scrum_lowest_foot_m = snappedf(lowest_foot, 0.001)
	# Ballon gagné : les paquets restent liés SORTIE s, puis rejoignent les places de la scène.
	var sortie := scrum(60.0, 0, "setpiece-win", "sortie", "s0_7")
	view.apply_frame({"scene": sortie})
	# 25/11/2026 (Léo : liés, jamais fondus) : à la sortie, ni le demi qui ramasse ni le demi adverse
	# ne traversent un paquet penché (buste ou tête dans un buste ou une tête), image par image.
	var demi_fondu := 0.0
	for frame in 180:
		view._process(1.0 / 60.0)
		if frame == 29:
			check((view._actors.s1_0.model as Node3D).rotation.x > 0.4, "Packs stay bound while the ball comes out")
		for demi_id in ["s0_8", "s1_8"]:
			for side in 2:
				for slot in 8:
					demi_fondu = maxf(demi_fondu, busts_overlap(view, demi_id, "s%d_%d" % [side, slot]))
	check(demi_fondu <= BUST_OVERLAP_MAX, "Scrum exit: no scrum-half walks through a bound pack (%.3f m bust overlap, %.2f m allowed)" % [demi_fondu, BUST_OVERLAP_MAX])
	metrics.exit_half_bust_overlap_m = snappedf(demi_fondu, 0.001)
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


## Mêlée du moteur décalée en largeur de `dy` m (y de la scène ; y croissants vers la caméra TV).
func scrum_at(bx: float, dy: float, possession: int, kind: String, key: String, featured: String = "") -> Dictionary:
	var scene := scrum(bx, possession, kind, key, featured)
	for player: Dictionary in scene.players:
		player.y = clampf(float(player.y) + dy, 2.0, 68.0)
	scene.ball.y = float(scene.ball.y) + dy
	scene.origin.y = float(scene.origin.y) + dy
	return scene


## Angles de la caméra courante (degrés) : [inclinaison de l'axe sous l'horizon, plongée du bas de l'image].
func camera_angles(view) -> Vector2:
	var camera: Camera3D = view._camera
	# La caméra regarde vers -basis.z : l'axe plonge de asin(basis.z.y) sous l'horizon.
	var inclinaison := rad_to_deg(asin(clampf(camera.global_basis.z.y, -1.0, 1.0)))
	return Vector2(inclinaison, inclinaison + camera.fov * 0.5)


## Ballon caché à la caméra courante (19 novembre 2026) : premier joueur plus proche de la caméra que
## le ballon dont un os du buste (MASQUE_OS) tombe à l'écran à moins de MASQUE_BUSTE m du ballon
## (écart converti en mètres à la distance du ballon) ; "" si le ballon est dégagé.
func masque_ballon(view) -> String:
	var camera: Camera3D = view._camera
	var ball: Vector3 = view._ball.global_position
	var loin := camera.global_position.distance_to(ball)
	var ecran: Vector2 = camera.unproject_position(ball)
	# Pixels par mètre à la distance du ballon (champ vertical de la caméra, image de 720 px).
	var par_metre: float = float(view.get_viewport().get_visible_rect().size.y) / (2.0 * loin * tan(deg_to_rad(camera.fov * 0.5)))
	for id: String in view._actors:
		var rig: Skeleton3D = view._actors[id].rig
		if not is_instance_valid(rig):
			continue
		for nom_os: String in MASQUE_OS:
			var index := rig.find_bone(nom_os)
			if index < 0:
				continue
			var point := rig.to_global(rig.get_bone_global_pose(index).origin)
			if camera.global_position.distance_to(point) >= loin:
				continue
			var ecart := camera.unproject_position(point).distance_to(ecran) / par_metre
			if ecart < MASQUE_BUSTE:
				return "%s %s (%.2f m)" % [id, nom_os, ecart]
	return ""


## Point dans l'image, à `marge` de ses bords au moins.
func dans_cadre(view, point: Vector3, marge: float) -> bool:
	var camera: Camera3D = view._camera
	if camera.is_position_behind(point):
		return false
	var p: Vector2 = camera.unproject_position(point) / view.get_viewport().get_visible_rect().size
	return p.x >= marge and p.x <= 1.0 - marge and p.y >= marge and p.y <= 1.0 - marge


## Distance au sol (m) du ballon au joueur le plus proche, et son id.
func nearest_to_ball(view) -> Array:
	var ball: Vector3 = view._ball.global_position
	var best := INF
	var who := ""
	for id: String in view._actors:
		var at: Vector3 = (view._actors[id].node as Node3D).position
		var d := Vector2(at.x - ball.x, at.z - ball.z).length()
		if d < best:
			best = d
			who = id
	return [best, who]


## Mêlée en caméra TV (19/11/2026, match filmé : mêlée en petite tache, ballon seul sur l'herbe à
## 10 m du paquet pendant « conserve sa mêlée et avance ») : au milieu du terrain et près de la touche
## proche (caméra-grue), cadrage serré et jamais plus plongeant que les plafonds TV ; le demi tient le
## ballon côté caméra à l'introduction ; à la sortie, le ballon reste dans les mains d'un joueur, même
## quand le moteur le fait avancer de 8 m vers un arrière éloigné ou sans porteur désigné.
func check_tv_scrum(view) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await process_frame
	var Cadrage = load("res://match_cadrage.gd")
	var cadrage = Cadrage.new(view)
	view.set_cadrage(cadrage)
	view.set_camera("tv")
	var pire := Vector2.ZERO
	var plus_large := 0.0
	var paquet_min := INF
	var paquet_max := 0.0
	var intro_masque := ""
	var intro_hors := ""
	var intro_ecart := 0.0
	var intro_cote := INF
	var sortie_ecart := 0.0
	var sortie_seul := ""
	var sortie_sol := ""
	var n8_fondu := 0.0
	var n8_qui := ""
	var n8_entier := 0.0
	var n8_entier_qui := ""
	var cas := 0
	for dy in [0.0, 23.0]:
		for featured in ["s0_12", "", "s0_7"]:
			cas += 1
			var centre_z: float = dy
			cadrage.regler(true, "scrum")
			cadrage.couper()
			view.apply_frame({"scene": scrum_at(60.0, dy, 0, "scrum", "melee-tv-%d" % cas)})
			for frame in 420:
				view._process(1.0 / 60.0)
				if frame < 240:
					continue
				# Les 3 dernières secondes de la mêlée : demi accroupi au tunnel, ballon en main, côté caméra.
				var angles := camera_angles(view)
				pire = Vector2(maxf(pire.x, angles.x), maxf(pire.y, angles.y))
				plus_large = maxf(plus_large, float(view._camera.size))
				var ball: Vector3 = view._ball.global_position
				var demi: Vector3 = (view._actors.s0_8.node as Node3D).position
				intro_ecart = maxf(intro_ecart, Vector2(ball.x - demi.x, ball.z - demi.z).length())
				intro_cote = minf(intro_cote, ball.z - centre_z)
				# 19 novembre 2026 : demi et ballon dans l'image, ballon jamais caché par un buste.
				var cache := masque_ballon(view)
				if not cache.is_empty() and intro_masque.is_empty():
					intro_masque = "y+%d frame %d: %s" % [int(dy), frame, cache]
				if not (dans_cadre(view, ball, CADRE_MARGE) and dans_cadre(view, demi, CADRE_MARGE) and dans_cadre(view, demi + Vector3.UP * 1.2, CADRE_MARGE)) and intro_hors.is_empty():
					intro_hors = "y+%d frame %d" % [int(dy), frame]
			# Part de la largeur de l'image occupée par les deux paquets (pieds des seize avants).
			var gauche := INF
			var droite := -INF
			for side in 2:
				for slot in 8:
					var x: float = view._camera.unproject_position((view._actors["s%d_%d" % [side, slot]].node as Node3D).position).x
					gauche = minf(gauche, x)
					droite = maxf(droite, x)
			paquet_min = minf(paquet_min, (droite - gauche) / 1280.0)
			paquet_max = maxf(paquet_max, (droite - gauche) / 1280.0)
			# Sortie : le moteur fait « avancer » le ballon de 8 m (point du fait) ; son porteur désigné y
			# est placé (arrière éloigné, aucun, ou n° 8 qui se détache).
			var sortie := scrum_at(60.0, dy, 0, "setpiece-win", "sortie-tv-%d" % cas, featured)
			sortie.ball.x = 68.0
			for player: Dictionary in sortie.players:
				if player.id == featured:
					player.x = 68.0
					player.y = sortie.ball.y
			cadrage.regler(true, "setpiece-win")
			view.apply_frame({"scene": sortie})
			var attendu := "s0_7" if featured == "s0_7" else "s0_8"
			check(view._carrier_id == attendu, "Scrum exit (%s, y+%d): the ball is held by %s, not sent alone to the engine's spot (%s)" % [featured, int(dy), attendu, view._carrier_id])
			for frame in 150:
				view._process(1.0 / 60.0)
				var proche: Array = nearest_to_ball(view)
				# Ballon au sol (hauteur de la marque, 0,23 m) loin de tout joueur : posé seul sur l'herbe.
				if view._ball.global_position.y < 0.28 and float(proche[0]) > 1.0:
					sortie_sol += " %s y+%d frame %d (%.2f m)" % [featured, int(dy), frame, proche[0]]
				# Passé le temps d'une transmission (BLEND_SECONDS), le ballon est dans des mains.
				if frame >= 40 and float(proche[0]) > sortie_ecart:
					sortie_ecart = float(proche[0])
					sortie_seul = "%s y+%d frame %d: %.2f m from %s" % [featured, int(dy), frame, proche[0], proche[1]]
				var angles := camera_angles(view)
				pire = Vector2(maxf(pire.x, angles.x), maxf(pire.y, angles.y))
				# 25/11/2026 (Léo) : le n° 8 qui part 8 m devant avec le ballon contourne les paquets,
				# il ne traverse aucun joueur (buste ou tête dans un buste ou une tête).
				if featured == "s0_7":
					for autre: String in view._actors:
						if autre != "s0_7":
							var p := busts_overlap(view, "s0_7", autre)
							if p > n8_fondu:
								n8_fondu = p
								n8_qui = "y+%d frame %d: %s" % [int(dy), frame, autre]
							# Corps entier, une fois sorti du paquet (0,2 s) : aucun bras ni jambe dans lui.
							var q := busts_overlap(view, "s0_7", autre, CORPS) if frame >= 12 else 0.0
							if q > n8_entier:
								n8_entier = q
								n8_entier_qui = "y+%d frame %d: %s" % [int(dy), frame, autre]
			var porteur: Vector3 = (view._actors[attendu].node as Node3D).position
			var ball: Vector3 = view._ball.global_position
			check(Vector2(ball.x - porteur.x, ball.z - porteur.z).length() < 0.8 and ball.y > 0.5, "Scrum exit (%s, y+%d): the ball is still in %s's hands after the exit (%.2f m, %.2f m high)" % [featured, int(dy), attendu, Vector2(ball.x - porteur.x, ball.z - porteur.z).length(), ball.y])
	var View = load("res://match_view.gd")
	check(pire.x <= View.INCLINAISON_TV_MAX + 0.5, "TV scrum: camera axis no steeper than the TV ceiling (%.1f deg, max %.1f)" % [pire.x, View.INCLINAISON_TV_MAX])
	check(pire.y <= View.PLONGEE_TV_MAX + 0.5, "TV scrum: bottom of the picture no steeper than the TV ceiling (%.1f deg, max %.1f)" % [pire.y, View.PLONGEE_TV_MAX])
	check(sortie_sol.is_empty(), "Scrum exit: the ball never lies alone on the grass;" + sortie_sol)
	check(plus_large <= Cadrage.SERRE_MELEE.tv[1] + 0.01, "TV scrum: tight framing on the pack (%.1f m visible)" % plus_large)
	# 19 novembre 2026 : un quart de la largeur au film (13 m visibles) ; environ la moitié voulue.
	check(paquet_min >= PAQUET_PART.x and paquet_max <= PAQUET_PART.y, "TV scrum: both packs fill about half the picture width (%.2f to %.2f, wanted %.2f to %.2f)" % [paquet_min, paquet_max, PAQUET_PART.x, PAQUET_PART.y])
	check(intro_masque.is_empty(), "Put-in: no body hides the ball from the TV camera (%s)" % intro_masque)
	check(intro_hors.is_empty(), "Put-in: scrum-half and ball inside the TV picture (%s)" % intro_hors)
	check(intro_ecart < 1.0, "Put-in: the ball stays in the scrum-half's hands (%.2f m at most)" % intro_ecart)
	check(intro_cote > 0.5, "Put-in: scrum-half and ball on the TV camera side of the scrum (%.2f m)" % intro_cote)
	check(sortie_ecart < 1.0, "Scrum exit: the ball is never alone on the grass (worst %s)" % sortie_seul)
	check(n8_fondu <= BUST_OVERLAP_MAX, "Scrum exit: the number 8 leaving with the ball walks through nobody (%.3f m bust overlap, %s)" % [n8_fondu, n8_qui])
	metrics.exit_n8_bust_overlap_m = snappedf(n8_fondu, 0.001)
	check(n8_entier <= BUST_OVERLAP_MAX, "Scrum exit: no arm or leg goes into the number 8 once out of the scrum (%.3f m, %s)" % [n8_entier, n8_entier_qui])
	metrics.exit_n8_body_overlap_m = snappedf(n8_entier, 0.001)
	metrics.tv_scrum_axis_deg = snappedf(pire.x, 0.1)
	metrics.tv_scrum_bottom_deg = snappedf(pire.y, 0.1)
	metrics.tv_scrum_size_m = snappedf(plus_large, 0.1)
	metrics.tv_scrum_pack_width = snappedf(paquet_min, 0.01)
	metrics.tv_scrum_pack_width_max = snappedf(paquet_max, 0.01)
	metrics.intro_ball_demi_m = snappedf(intro_ecart, 0.01)
	metrics.exit_ball_nearest_m = snappedf(sortie_ecart, 0.01)
	view.set_cadrage(null)


func run() -> void:
	check_scrum_formation()
	check_scrum_exit()
	check_lineout()
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	check_view(view)
	await check_tv_scrum(view)
	print("MATCH_FORMATIONS_METRICS ", JSON.stringify(metrics))
	if failures.is_empty():
		print("MATCH_FORMATIONS_OK")
	quit(0 if failures.is_empty() else 1)
