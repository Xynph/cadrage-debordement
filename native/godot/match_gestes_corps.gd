extends "res://match_gestes_etat.gd"
## Gestes de rugby : poses procédurales du squelette (touche, ballon porté, essai, après-essai)
## et aides de corps (liaison, poussée, bras, buste, pieds).

## Touche : mains des porteurs posées à PRISE_CUISSE m de l'axe de la cuisse du sauteur, côté porteur
## (rayon de la cuisse 8 cm, plus la main).
const PRISE_CUISSE := 0.15

## Relevé du marqueur (0 allongé, 1 debout).
func _rise() -> float:
	return smoothstep(_celebre_a, _celebre_a + _releve_duree, time) if _releve == carrier and not carrier.is_empty() else 0.0


## Relevé procédural (sans clip) : genoux pliés à mi-chemin.
func _rise_dip(rise: float) -> float:
	return RELEVE_PLIE * sin(rise * PI) if _releve_duree > 0.5 else 0.0


## Debout, le marqueur se tourne vers le terrain (ses partenaires arrivent de ce côté).
func _turn_scorer(heading: float) -> float:
	if _releve != carrier or carrier.is_empty():
		return heading
	return lerp_angle(heading, atan2(-dir, 0.0), smoothstep(_celebre_a + _releve_duree * 0.6, _celebre_a + _releve_duree + 0.8, time))


func _pose_touche() -> void:
	var ball: Node3D = view._ball
	if time < 0.0:
		# Mise en place encore longue : la vue laisse le ballon à la marque ; il est remis au lanceur ensuite.
		ball_from = ball.global_position
		ball_from_basis = ball.global_basis
		return
	var lift := LIFT * smoothstep(FORM + 0.35, FORM + 0.95, time) * (1.0 - smoothstep(DOWN, DOWN + 0.45, time))
	# Saut du modèle d'origine (« Man_Jump », 18/11/2026) sous la levée : appel, jambes groupées,
	# réception. Ralenti (×SAUT_VITESSE) pour que l'appel tombe sur le début de la levée.
	if not awaiting and not _saut_lance and time >= FORM and view.has_method("jouer_clip_natif"):
		_saut_lance = true
		for sauteur: String in jumpers:
			if not sauteur.is_empty() and not view.geste_adapte(sauteur):
				view.jouer_clip_natif(sauteur, "Man_Jump", SAUT_DEBUT, -1.0, false, SAUT_VITESSE)
	_body(jumper, 0.0, lift)
	var jump: Dictionary = view._actors[jumper]
	var pitcher: Dictionary = view._actors[thrower]
	var overhead: Vector3 = jump.node.global_position + jump.node.global_basis * Vector3(0.0, lift + 2.06, 0.14)
	catch_point = jump.node.global_position + jump.node.global_basis * Vector3(0.0, LIFT + 2.06, 0.14)
	# Lanceur : ballon au-dessus de la tête, armé puis lancer droit. Avec la bibliothèque
	# adaptée, le lancer à deux mains du clip, calé pour lâcher le ballon à RELEASE.
	var cle: float = view.instant_geste("lancer") if view.has_method("instant_geste") else 0.0
	if cle > 0.0 and not _lancer_adapte and time >= RELEASE - cle and time < RELEASE:
		_lancer_adapte = view.jouer_geste(thrower, "lancer", time - (RELEASE - cle), cle + 0.9)
	var adapte: bool = _lancer_adapte and view.geste_adapte(thrower, "lancer")
	var wind := clampf(inverse_lerp(FORM, RELEASE, time), 0.0, 1.0)
	var back := lerpf(-0.05, -0.3, minf(wind / 0.6, 1.0))
	if wind > 0.6:
		back = lerpf(-0.3, 0.32, (wind - 0.6) / 0.4)
	var hands: Vector3 = pitcher.node.global_position + pitcher.node.global_basis * Vector3(0.0, 2.03 + 0.07 * maxf(0.0, (wind - 0.6) / 0.4), back)
	var lean := -0.16 * sin(minf(wind / 0.6, 1.0) * PI * 0.5)
	if wind > 0.6:
		lean = lerpf(-0.16, 0.22, (wind - 0.6) / 0.4) * (1.0 - smoothstep(RELEASE + 0.2, RELEASE + 0.7, time))
	if adapte:
		# Les mains du clip portent le ballon : il est tenu entre les paumes, un peu devant.
		var rig: Skeleton3D = pitcher.rig
		var palms := (rig.to_global(rig.get_bone_global_pose(rig.find_bone("Palm.L")).origin) + rig.to_global(rig.get_bone_global_pose(rig.find_bone("Palm.R")).origin)) * 0.5
		hands = palms + pitcher.node.global_basis.z.normalized() * 0.08
	else:
		_bend(thrower, lean)
	if time < RELEASE:
		var given := 1.0 if _ball_ready else smoothstep(0.0, FORM * 0.8, time)
		ball.global_position = ball_from.lerp(hands, given) + Vector3.UP * sin(given * PI) * minf(2.0, ball_from.distance_to(hands) * 0.15)
		ball.global_basis = ball_from_basis.slerp(pitcher.node.global_basis.orthonormalized(), smoothstep(0.0, FORM * 0.8, time))
		if not adapte:
			_hold(thrower, ball.global_position if time > FORM * 0.8 or _ball_ready else hands, 1.0 if _ball_ready else smoothstep(0.2, FORM * 0.8, time))
		release_point = hands
	else:
		var follow: Vector3 = pitcher.node.global_position + pitcher.node.global_basis * Vector3(0.0, 1.85, 0.6)
		if not adapte:
			_hold(thrower, follow, 1.0 - smoothstep(RELEASE + 0.15, RELEASE + 0.6, time))
		if time < CATCH:
			var flight := inverse_lerp(RELEASE, CATCH, time)
			var path := release_point.lerp(catch_point, flight)
			path.y += sin(flight * PI) * 0.4
			var along := (catch_point - release_point).normalized()
			ball.global_position = path
			# Rotation autour du grand axe : le lancer « vissé » de la touche.
			ball.global_basis = Basis(Quaternion(Vector3.RIGHT, along)) * Basis(Vector3.RIGHT, flight * TAU * 2.0)
		else:
			var down := smoothstep(DOWN, TOUCHE_END, time)
			ball.global_position = overhead.lerp(Presentation.ball_anchor(jump.node, jump.rig), down)
			ball.global_basis = jump.node.global_basis.orthonormalized()
	# Sauteur : bras tendus vers le ballon, prise à deux mains.
	var up := smoothstep(FORM + 0.4, FORM + 0.9, time)
	var reach := Presentation.ball_anchor(jump.node, jump.rig).lerp(overhead, up)
	_hold(jumper, ball.global_position if time >= CATCH else reach, up)
	# Bloc adverse : même geste, moins haut et sans le ballon.
	var rival: String = jumpers[1 - side]
	var contest := 0.0
	if not rival.is_empty():
		contest = CONTEST * smoothstep(FORM + 0.43, FORM + 1.0, time) * (1.0 - smoothstep(FORM + 1.3, FORM + 1.7, time))
		_body(rival, 0.0, contest)
		var other: Node3D = view._actors[rival].node
		var top: Vector3 = other.global_position + other.global_basis * Vector3(0.0, contest + 2.0, 0.2)
		var spread := other.global_basis.x.normalized() * 0.2
		_arms(rival, top + spread, top - spread, smoothstep(FORM + 0.5, FORM + 0.9, time) * (1.0 - smoothstep(FORM + 1.35, FORM + 1.7, time)), true)
	for id: String in cast:
		var member: Dictionary = cast[id]
		if member.role not in ["lift_front", "lift_back"] or str(jumpers[member.team]).is_empty():
			continue
		var entry: Dictionary = view._actors[id]
		var actor: Node3D = entry.node
		var own: bool = member.team == side
		var grip := smoothstep(FORM + 0.15, FORM + 0.4, time) * (1.0 - smoothstep(DOWN + 0.3, TOUCHE_END, time) if own else 1.0 - smoothstep(FORM + 1.4, FORM + 1.7, time))
		_bend(id, -0.12 * grip)
		var rig: Skeleton3D = view._actors[jumpers[member.team]].rig
		var points: Array[Vector3] = []
		for leg in ["L", "R"]:
			var hip := rig.to_global(rig.get_bone_global_pose(rig.find_bone("UpperLeg." + leg)).origin)
			var knee := rig.to_global(rig.get_bone_global_pose(rig.find_bone("LowerLeg." + leg)).origin)
			var point := hip.lerp(knee, 0.75 if member.role == "lift_front" else 0.1)
			# 26/11/2026 (sonde des contacts : avant-bras dans la cuisse du sauteur, jusqu'à 17 cm) : les mains
			# se posent sur la cuisse, du côté du porteur, pas dans l'os.
			var vers_porteur := actor.global_position - point
			vers_porteur.y = 0.0
			if vers_porteur.length() > 0.01:
				point += vers_porteur.normalized() * PRISE_CUISSE
			points.append(point)
		if (points[0] - points[1]).dot(actor.global_basis.x) < 0.0:
			points.reverse()
		_arms(id, points[0], points[1], grip, false)


func _pose_maul() -> void:
	var weight := smoothstep(0.15, MAUL_FORM, time)
	for id: String in cast:
		if cast[id].role != "walk":
			var join: float = cast[id].get("join", MAUL_FORM)
			_bind(id, weight if join <= MAUL_FORM else smoothstep(join - 0.55, join, time))
	var ball: Node3D = view._ball
	var from: Dictionary = view._actors[jumper]
	var to: Dictionary = view._actors[carrier]
	var hand_over := smoothstep(0.15, MAUL_FORM, time)
	ball.global_position = Presentation.ball_anchor(from.node, from.rig).lerp(Presentation.ball_anchor(to.node, to.rig), hand_over)
	ball.global_basis = to.node.global_basis.orthonormalized()
	_hold(jumper, ball.global_position, 1.0 - smoothstep(0.3, MAUL_FORM, time))
	_hold(carrier, ball.global_position, smoothstep(0.3, MAUL_FORM, time))


func _pose_maul_try() -> void:
	var ball: Node3D = view._ball
	var push := 1.0 - smoothstep(drive, drive + 0.5, time)
	var joy := smoothstep(drive + 0.25, drive + 0.7, time)
	for id: String in cast:
		if id == carrier or cast[id].role == "walk":
			continue
		_bind(id, push)
		# Après l'essai, la joie de ceux qui restent ou accourent est posée par _pose_apres.
		if joy > 0.0 and cast[id].team == side and not _adapte(id) and cast[id].role not in APRES_ROLES:
			_cheer(id, joy)
	var dive := smoothstep(0.55, 1.0, (time - peel) / dive_seconds) if dive_set else 0.0
	var rise := _rise()
	if dive <= 0.0:
		# Le marqueur quitte sa posture de poussée en douceur avant de se détacher.
		_ease_body(carrier, 0.2, 0.0)
		_push_legs(carrier, 1.0 - smoothstep(peel, peel + 0.35, time) if dive_set else 1.0)
	else:
		var member: Dictionary = cast[carrier]
		_body(carrier, lerpf(float(member.get("lean_now", 0.2)), 1.42, dive) * (1.0 - rise), (lerpf(float(member.get("crouch_now", 0.0)), 0.14, dive) + sin(dive * PI) * 0.3) * (1.0 - rise) - _rise_dip(rise))
	var scorer: Dictionary = view._actors[carrier]
	var anchor := Presentation.ball_anchor(scorer.node, scorer.rig)
	var held := anchor
	if view._actors.has(previous_carrier) and previous_carrier != carrier:
		var giver: Dictionary = view._actors[previous_carrier]
		held = Presentation.ball_anchor(giver.node, giver.rig).lerp(anchor, smoothstep(0.1, 0.5, time))
	ball.global_position = held.lerp(_grounded(), dive * dive)
	ball.global_basis = scorer.node.global_basis.orthonormalized()
	_hold(carrier, ball.global_position, smoothstep(0.2, 0.5, time) * (1.0 - rise))


func _pose_try() -> void:
	var ball: Node3D = view._ball
	var run_time := time - pass_at
	var dive := smoothstep(drive - 0.42, drive, run_time)
	# Relevé du clip adapté : la pose de plongeon s'efface pendant qu'il se redresse (sans clip :
	# relevé procédural, genoux pliés à mi-chemin).
	var rise := _rise()
	_body(carrier, 1.42 * dive * (1.0 - rise), (0.14 * dive + sin(dive * PI) * 0.3) * (1.0 - rise) - _rise_dip(rise))
	var scorer: Dictionary = view._actors[carrier]
	var anchor := Presentation.ball_anchor(scorer.node, scorer.rig)
	if not giver.is_empty() and view._actors.has(giver):
		# Dernière passe : le ballon reste dans les mains du porteur jusqu'à la passe, puis vole
		# en PASS_FLIGHT secondes jusqu'aux mains du marqueur.
		var hands: Dictionary = view._actors[giver]
		var given := Presentation.ball_anchor(hands.node, hands.rig)
		var start := maxf(0.0, pass_at - PASS_FLIGHT)
		var flight := smoothstep(start, pass_at, time)
		var taken_back := smoothstep(0.0, 0.25, time)
		var in_air := given.lerp(anchor, flight) + Vector3.UP * sin(flight * PI) * 0.35
		ball.global_position = ball_from.lerp(in_air, taken_back).lerp(_grounded(), dive * dive)
		ball.global_basis = (hands.node as Node3D).global_basis.orthonormalized().slerp(scorer.node.global_basis.orthonormalized(), flight)
		_hold(giver, given, (1.0 - smoothstep(start, start + 0.12, time)) * smoothstep(0.0, 0.2, time))
		_hold(carrier, ball.global_position, smoothstep(pass_at - 0.12, pass_at + 0.1, time) * (1.0 - rise))
	else:
		var taken := smoothstep(0.0, 0.3, time)
		ball.global_position = ball_from.lerp(anchor, taken).lerp(_grounded(), dive * dive)
		ball.global_basis = ball_from_basis.slerp(scorer.node.global_basis.orthonormalized(), taken)
		_hold(carrier, ball.global_position, smoothstep(0.1, 0.3, time) * (1.0 - rise))
	var joy := smoothstep(drive + 0.3, drive + 0.75, run_time)
	if joy > 0.0:
		for id: String in cheer:
			if view._actors.has(id) and not _adapte(id) and not (cast.has(id) and cast[id].role in APRES_ROLES):
				_cheer(id, joy)


func _grounded() -> Vector3:
	return Vector3(target.x, 0.14, target.z)


## Posture de poussée liée : buste engagé, bras vers le partenaire de devant.
func _bind(id: String, weight: float) -> void:
	var member: Dictionary = cast[id]
	if member.role in ["half", "walk"]:
		return
	var entry: Dictionary = view._actors[id]
	var actor: Node3D = entry.node
	if id == carrier:
		_ease_body(id, 0.2 * weight, 0.0)
		_push_legs(id, weight)
		return
	_ease_body(id, PUSH_PITCH * weight, -CROUCH * weight)
	_push_legs(id, weight)
	_bend(id, 0.3 * weight)
	var chest := Presentation.ball_anchor(actor, entry.rig)
	var forward := actor.global_basis.z.normalized()
	var lateral := actor.global_basis.x.normalized()
	var reach := chest + forward * 0.34 + Vector3.DOWN * 0.06
	_arms(id, reach + lateral * 0.3, reach - lateral * 0.3, weight, false)


## Inclinaison et abaissement amortis : un changement de rôle dans le regroupement ne saute pas.
func _ease_body(id: String, pitch: float, lift: float) -> void:
	var member: Dictionary = cast[id]
	member.lean_now = move_toward(float(member.get("lean_now", member.get("pitch", 0.0))), pitch, 1.2 * _dt)
	member.crouch_now = move_toward(float(member.get("crouch_now", member.get("lift", 0.0))), lift, 0.5 * _dt)
	_body(id, member.lean_now, member.crouch_now)


## Petits pas d'appui du ballon porté : bassin abaissé, pied d'appui planté en
## arrière du bassin, genou fléchi, pas courts réglés sur la distance parcourue.
## Le solveur à deux os existant garde les longueurs du modèle.
func _push_legs(id: String, weight: float) -> void:
	if weight <= 0.0:
		return
	var member: Dictionary = cast[id]
	var entry: Dictionary = view._actors[id]
	var actor: Node3D = entry.node
	var rig: Skeleton3D = entry.rig
	var forward := actor.global_basis.z.normalized()
	var last: Vector3 = member.get("gait_from", actor.global_position)
	if not member.has("gait"):
		# Décalage propre à chaque joueur : les pas ne sont pas synchronisés.
		member.gait = fposmod(float(id.hash() % 1000) * 0.0137, 1.0) * STRIDE_CYCLE
	member.gait = float(member.gait) + (actor.global_position - last).dot(forward)
	member.gait_from = actor.global_position
	_keep(id, entry, LEGS)
	var reach := STANCE * STRIDE_CYCLE
	for leg in ["L", "R"]:
		var sign_ := 1.0 if leg == "L" else -1.0
		var upper := rig.find_bone("UpperLeg." + leg)
		var lower := rig.find_bone("LowerLeg." + leg)
		var foot := rig.find_bone("Foot." + leg)
		if mini(upper, mini(lower, foot)) < 0:
			continue
		var hip := rig.to_global(rig.get_bone_global_pose(upper).origin)
		var knee := rig.to_global(rig.get_bone_global_pose(lower).origin)
		var source := rig.to_global(rig.get_bone_global_pose(foot).origin)
		var length := hip.distance_to(knee) + knee.distance_to(source)
		# Pied posé assez loin derrière le bassin pour pousser, assez près pour fléchir le genou.
		var height := maxf(hip.y - 0.025, 0.1)
		var back := sqrt(maxf(0.0, pow(length * 0.93, 2.0) - height * height))
		var cycle := fposmod(float(member.gait) / STRIDE_CYCLE + (0.0 if leg == "L" else 0.5), 1.0)
		var along := 0.0
		var raise := 0.0
		if cycle < STANCE:
			along = reach * (0.5 - cycle / STANCE)
		else:
			var swing := (cycle - STANCE) / (1.0 - STANCE)
			along = reach * (smoothstep(0.0, 1.0, swing) - 0.5)
			raise = sin(swing * PI) * 0.09
		var hip_local := actor.to_local(hip)
		var planted := actor.to_global(Vector3(sign_ * 0.14, 0.0, hip_local.z - back + along))
		planted.y = 0.025 + raise
		Presentation._solve_leg(rig, leg, source.lerp(planted, minf(weight, 1.0)), forward)


## Fin d'un geste : les pieds ne passent jamais sous la pelouse pendant le relâchement.
func _ground_feet(id: String) -> void:
	var entry: Dictionary = view._actors[id]
	var rig: Skeleton3D = entry.rig
	if not is_instance_valid(rig):
		return
	_keep(id, entry, LEGS)
	for leg in ["L", "R"]:
		var foot := rig.find_bone("Foot." + leg)
		if foot < 0:
			continue
		var source := rig.to_global(rig.get_bone_global_pose(foot).origin)
		if source.y < 0.025:
			Presentation._solve_leg(rig, leg, Vector3(source.x, 0.025, source.z), (entry.node as Node3D).global_basis.z)


func _cheer(id: String, weight: float) -> void:
	var actor: Node3D = view._actors[id].node
	var top := actor.global_position + actor.global_basis * Vector3(0.0, 2.05, 0.05)
	var lateral := actor.global_basis.x.normalized() * 0.34
	_arms(id, top + lateral, top - lateral, weight, true)


## Postures de la scène d'après-essai : joie des partenaires, tête basse des défenseurs, marqueur
## debout qui lève les bras (sans clip).
func _pose_apres() -> void:
	if not _apres:
		return
	for id: String in cast:
		var member: Dictionary = cast[id]
		if member.role not in APRES_ROLES or not view._actors.has(id):
			continue
		var t := float(member.t)
		match member.role:
			"repli":
				if not _adapte(id):
					_tete_basse(id, smoothstep(float(member.wait), float(member.wait) + 0.8, t))
			"replace":
				var joie := float(member.get("joie0", 0.0))
				if joie > 0.05 and not _adapte(id):
					_cheer(id, lerpf(joie, 1.0, smoothstep(0.0, 0.35, t)) * (1.0 - smoothstep(float(member.wait) - 0.4, float(member.wait), t)))
			"felicite":
				var form := float(member.form)
				var pres := t >= form
				if pres and not member.get("joie_lancee", false):
					member.joie_lancee = true
					# Bibliothèque adaptée : joie ou poing levé à l'arrivée.
					var pair := int(member.get("rang", 0)) % 2 == 0
					view.jouer_geste(id, "joie" if pair else "joie_poing", 0.35 if pair else 0.4, 3.2 if pair else 2.4)
				if _adapte(id):
					continue
				# Il accourt bras levés ; arrivé, un sur deux tape dans le dos du marqueur.
				var leve := lerpf(float(member.get("joie0", 0.0)), 1.0, smoothstep(0.0, 0.35, t))
				var tape := smoothstep(form + 0.6, form + 1.0, t) if int(member.get("rang", 0)) % 2 == 1 else 0.0
				if tape > 0.0 and view._actors.has(carrier):
					var dos: Vector3 = (view._actors[carrier].node as Node3D).global_position + Vector3.UP * 1.45
					var actor: Node3D = view._actors[id].node
					var lateral := actor.global_basis.x.normalized() * 0.18
					_arms(id, dos + lateral, dos - lateral, tape, false)
				_cheer(id, leve * (1.0 - tape))
	# Marqueur debout (relevé procédural) : bras levés, puis à hauteur d'épaules quand on le félicite.
	if _releve == carrier and _releve_duree > 0.5 and not _adapte(carrier) and view._actors.has(carrier):
		var debout := _celebre_a + _releve_duree
		_cheer(carrier, smoothstep(debout - 0.1, debout + 0.4, time) * (1.0 - 0.7 * smoothstep(debout + 1.6, debout + 2.2, time)))


## Défenseur qui rentre : buste et tête penchés vers l'avant.
func _tete_basse(id: String, weight: float) -> void:
	if weight <= 0.0:
		return
	_bend(id, TETE_BASSE * weight)
	var entry: Dictionary = view._actors[id]
	var rig: Skeleton3D = entry.rig
	var axis := (rig.global_basis.inverse() * (entry.node as Node3D).global_basis.x).normalized()
	for bone in ["Neck", "Head"]:
		var index := rig.find_bone(bone)
		if index >= 0:
			_keep(id, entry, [bone])
			Presentation._orient(rig, index, Basis(Quaternion(axis, 0.22 * weight)) * rig.get_bone_global_pose(index).basis, 1.0)


func _adapte(id: String) -> bool:
	return view.has_method("geste_adapte") and view.geste_adapte(id)


func _touch(id: String, entry: Dictionary) -> void:
	if not _saved.has(id):
		_saved[id] = {"model": (entry.model as Node3D).transform, "bones": {}, "places": {}}


func _keep(id: String, entry: Dictionary, names: Array) -> void:
	_touch(id, entry)
	var rig: Skeleton3D = entry.rig
	for bone: String in names:
		var index := rig.find_bone(bone)
		if index >= 0 and not _saved[id].bones.has(index):
			_saved[id].bones[index] = rig.get_bone_pose_rotation(index)
			# Les contrôles de pied de ce modèle se déplacent : leur position est rendue aussi.
			_saved[id].places[index] = rig.get_bone_pose_position(index)


func _body(id: String, pitch: float, lift: float) -> void:
	var entry: Dictionary = view._actors[id]
	_touch(id, entry)
	var model: Node3D = entry.model
	model.transform = _saved[id].model
	model.rotation.x = pitch
	model.position.y += lift
	if cast.has(id):
		cast[id].pitch = pitch
		cast[id].lift = lift


func _bend(id: String, angle: float) -> void:
	var entry: Dictionary = view._actors[id]
	var rig: Skeleton3D = entry.rig
	_keep(id, entry, ["Abdomen", "Torso"])
	var axis := (rig.global_basis.inverse() * (entry.node as Node3D).global_basis.x).normalized()
	for bone in ["Abdomen", "Torso"]:
		var index := rig.find_bone(bone)
		if index >= 0:
			Presentation._orient(rig, index, Basis(Quaternion(axis, angle * 0.5)) * rig.get_bone_global_pose(index).basis, 1.0)


func _arms(id: String, left: Vector3, right: Vector3, weight: float, raised: bool) -> void:
	if weight <= 0.0:
		return
	var entry: Dictionary = view._actors[id]
	_keep(id, entry, ARMS)
	var basis: Basis = (entry.node as Node3D).global_basis
	for arm in ["L", "R"]:
		var sign_ := 1.0 if arm == "L" else -1.0
		var pole := basis * (Vector3(sign_ * 0.8, -0.25, -0.3) if raised else Vector3(sign_ * 0.7, -0.8, -0.15))
		Presentation._solve_arm(entry.rig, arm, left if arm == "L" else right, pole, minf(weight, 1.0))


func _hold(id: String, center: Vector3, weight: float) -> void:
	if weight <= 0.0:
		return
	var entry: Dictionary = view._actors[id]
	_keep(id, entry, ARMS)
	Presentation.hold_ball(entry.node, entry.rig, center, minf(weight, 1.0))
