extends "res://match_gestes_placement.gd"
## Gestes de rugby : ballon porté, essai (course, plongeon) et après-essai (célébration,
## félicitations, replis et replacements).


## Après l'aplati : la scène d'après-essai part (partenaires, défenseurs, autres), puis la joie
## adaptée (clips) ; sans clip de relevé, le marqueur se relève seul après COUCHE s.
func _apres_essai(aplati: float) -> void:
	if time >= aplati + APRES_DEPART: _lancer_apres()
	if time >= aplati + 0.3: _celebrer()
	if _releve.is_empty() and time >= aplati + COUCHE and view._actors.has(carrier):
		_releve = carrier
		_celebre_a = time
		_releve_duree = RELEVE


func _start_maul() -> void:
	var start: Vector3 = view._actors[jumper].node.position
	var gap := target - start
	var u := Vector3(dir * maxf(absf(gap.x), 2.5), 0.0, gap.z).normalized()
	var r := Vector3(-u.z, 0.0, u.x)
	if r.z < 0.0:
		r = -r
	center_from = start
	center_to = target + u * 1.95
	axis_to = atan2(u.x, u.z)
	axis_from = axis_to
	if maul_try_follows:
		# Essai à suivre : le reste jusqu'à la ligne doit tenir en MAUL_TRY_DRIVE s à MAUL_PACE.
		var rest := (dir * 50.0 - center_to.x) * dir
		center_to.x += dir * clampf(rest - MAUL_PACE * MAUL_TRY_DRIVE, 0.0, MAUL_TRY_LEAD)
	drive = clampf(center_from.distance_to(center_to) / MAUL_PACE, 1.6, MAUL_PORTE_DRIVE if maul_try_follows else 6.0)
	if not cast.has(carrier) or cast[carrier].team != side or cast[carrier].role == "half":
		carrier = thrower if cast.has(thrower) and cast[thrower].team == side else jumper
	var rear: Array[Vector2] = [Vector2(-0.75, -0.32), Vector2(-0.75, 0.32), Vector2(-1.5, -0.5), Vector2(-1.5, 0.5), Vector2(-2.25, 0.0)]
	var front := {"jumper": Vector2.ZERO, "lift_front": Vector2(0.0, -0.6), "lift_back": Vector2(0.0, 0.6)}
	# La défense engage aussi ses autres avants de l'alignement : liés sur les flancs du
	# ballon porté, buste engagé, au lieu de rester debout à côté (loi 16 : liés, sur leurs pieds).
	var flanks: Array[Vector2] = [Vector2(0.75, -1.15), Vector2(0.75, 1.15)]
	# Le porteur désigné peut être un arrière hors de l’alignement. Lui réserver
	# une place avant de distribuer les autres : un marcheur n’a pas de slot.
	var carrier_slot: Vector2 = rear[-1]
	if not front.has(cast[carrier].role):
		rear.pop_back()
	var keep: Dictionary = {}
	for id: String in cast:
		var member: Dictionary = cast[id]
		var actor: Node3D = view._actors[id].node
		if id == carrier and not front.has(member.role):
			keep[id] = {"from": actor.position, "heading": actor.rotation.y, "staged": true,
				"team": member.team, "peak": member.peak, "t": 0.0, "role": "pack", "slot": carrier_slot}
			continue
		if member.role == "walk":
			keep[id] = member
			continue
		var next := {"from": actor.position, "heading": actor.rotation.y, "staged": true, "team": member.team, "peak": member.peak, "t": 0.0}
		if member.team != side:
			# Seul le bloc de saut adverse, déjà au contact, s'oppose à la poussée ; les autres
			# rejoignent leur place de la scène à allure de course.
			if not front.has(member.role):
				if member.role == "line" and not flanks.is_empty():
					next.merge({"role": "opp_pack", "slot": flanks.pop_front()})
					keep[id] = next
					continue
				keep[id] = _walker(id, member)
				continue
			next.merge({"role": "opp_pack", "slot": front[member.role] + MAUL_FACE})
		elif front.has(member.role):
			next.merge({"role": "pack", "slot": front[member.role]})
		elif member.role == "half":
			next.merge({"role": "half", "slot": Vector2(-4.0, 0.9)})
		elif rear.is_empty():
			keep[id] = _walker(id, member)
			continue
		else:
			# Lanceur et autres avants se lient derrière, dans l'ordre d'arrivée.
			next.merge({"role": "pack", "slot": rear.pop_front()})
		keep[id] = next
	cast = keep
	# Le porteur désigné par le moteur prend la queue du ballon porté.
	var tail := ""
	var deepest := 1.0
	for id: String in cast:
		if cast[id].role == "pack" and (cast[id].slot as Vector2).x < deepest:
			deepest = cast[id].slot.x
			tail = id
	if tail != carrier:
		var swapped: Vector2 = cast[carrier].slot
		cast[carrier].slot = cast[tail].slot
		cast[tail].slot = swapped
	cast[carrier].role = "tail"
	# Durée de jonction : pointe de smoothstep = 1,5 × distance / durée, au plus MAUL_JOIN_PACE.
	for id: String in cast:
		if cast[id].has("slot"):
			var spot := _maul_spot(id, center_from, u, r, cast[id].slot)
			cast[id].join = clampf(1.5 * (cast[id].from as Vector3).distance_to(spot) / MAUL_JOIN_PACE, MAUL_FORM, 2.5)
	phase = "maul"
	time = 0.0
	done = false


func _start_maul_try(scene: Dictionary, scorer: String) -> void:
	var frame := _frame()
	target = _try_point(scene)
	# Le regroupement s'arrête sur la ligne ; le marqueur aplatit dans l'en-but.
	var line: Vector3 = view._world(scene.get("ball", {}))
	center_from = frame.center
	axis_from = atan2(frame.u.x, frame.u.z)
	# Le regroupement reste côté terrain : le marqueur plonge à découvert le long de la touche.
	var aside := Vector3(0.0, 0.0, 3.0 if target.z <= 0.0 else -3.0)
	var gap: Vector3 = line + aside - center_from
	gap.y = 0.0
	# Le regroupement glisse vers le point d'essai en gardant les épaules vers la ligne.
	var u := Vector3(dir * maxf(absf(gap.x), absf(gap.z)), 0.0, gap.z).normalized()
	center_to = line + aside - u * 0.3
	axis_to = atan2(u.x, u.z)
	# Le groupe pivote sans faire courir sa queue (2,3 m du centre) à plus de 3 m/s.
	turn_seconds = maxf(0.6, 1.5 * absf(angle_difference(axis_from, axis_to)) * 2.3 / 3.0)
	drive = clampf(center_from.distance_to(center_to) / MAUL_PACE, 1.2, MAUL_TRY_DRIVE)
	peel = maxf(drive - DIVE_SECONDS + 0.15, 0.45)
	previous_carrier = carrier
	for id: String in cast:
		if cast[id].has("slot"):
			cast[id].slot_from = cast[id].slot
	if scorer != carrier:
		cast[scorer].slot = cast[carrier].slot_from
		cast[carrier].slot = cast[scorer].slot_from
		cast[carrier].role = "pack"
		cast[scorer].role = "tail"
	# Échange de places à allure de pas (le groupe glisse aussi vers la ligne).
	for id: String in [scorer, carrier]:
		if cast.has(id) and cast[id].has("slot_from"):
			cast[id].swap = maxf(0.5, 1.5 * (cast[id].slot_from as Vector2).distance_to(cast[id].slot) / 3.5)
	carrier = scorer
	dive_set = false
	phase = "essai_maul"
	time = 0.0
	done = false


func _set_dive(from: Vector3, straight: bool) -> void:
	var line := target - from
	line.y = 0.0
	var h := Vector3(dir, 0.0, 0.0)
	if not straight and line.length() > 2.2 and line.x * dir > 0.0:
		h = (line.normalized() + h).normalized()
	dive_axis = h
	dive_from = from
	dive_to = Vector3(target.x, 0.0, target.z) - h * DIVE_REACH
	dive_set = true
	# Plongeon : pointe de smoothstep 1,5 × distance / durée, au plus 7,5 m/s.
	dive_seconds = maxf(DIVE_SECONDS, 1.5 * Vector2(dive_to.x - from.x, dive_to.z - from.z).length() / 7.5)


## Après l'essai (bibliothèque adaptée seulement) : le marqueur se relève et lève le
## poing, ses partenaires proches exultent, les adversaires les plus proches baissent la
## tête. Sans les clips, les bras levés procéduraux restent (repli).
func _celebrer() -> void:
	if _fin_essai or not view.has_method("jouer_geste"):
		return
	_fin_essai = true
	# Sans aucun clip lancé, l'appel se répète à chaque image : l'instant du relevé procédural
	# (_apres_essai) ne doit pas être repoussé à chaque fois, sinon le marqueur reste couché.
	var avant := _celebre_a
	_celebre_a = time
	var lances := 0
	if view.jouer_geste(carrier, "se_relever", 0.2, 1.75, true, [["joie_poing", 0.3, 2.4]]):
		lances += 1
		_releve = carrier
	var mates: Array = cheer.duplicate()
	if mates.is_empty():
		# Essai du ballon porté : les partenaires liés les plus proches du marqueur.
		var lies: Array = []
		for id: String in cast:
			if id != carrier and cast[id].team == side and cast[id].role in ["pack", "half"]:
				lies.append([(view._actors[id].node.position as Vector3).distance_to(target), id])
		lies.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for pair: Array in lies.slice(0, 4):
			mates.append(pair[1])
	var n := 0
	for id: String in mates:
		# Partenaire qui accourt vers le marqueur : sa joie part à l'arrivée (_pose_apres).
		if cast.has(id) and cast[id].role == "felicite":
			continue
		if view._actors.has(id) and view.jouer_geste(id, "joie" if n % 2 == 0 else "joie_poing", 0.35 if n % 2 == 0 else 0.4, 3.2 if n % 2 == 0 else 2.4):
			lances += 1
		n += 1
	# Les trois adversaires les plus proches du point d'essai : déception.
	var proches: Array = []
	for id: String in view._actors:
		if int(view._actors[id].side) != side:
			proches.append([(view._actors[id].node.position as Vector3).distance_to(target), id])
	proches.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair: Array in proches.slice(0, 3):
		if view.jouer_geste(pair[1], "deception", 0.3, 3.0, true):
			lances += 1
	_fin_essai = lances > 0
	if not _fin_essai:
		_celebre_a = avant


## Scène d'après-essai (voir APRES_DEPART) : partenaires vers le marqueur, défense vers son en-but,
## les autres vers leur place de la transformation. Tous restent mis en scène jusqu'au fait suivant.
func _lancer_apres() -> void:
	if _apres or not view._actors.has(carrier):
		return
	_apres = true
	var scorer: Vector3 = view._actors[carrier].node.position
	var centre := Vector3(scorer.x, 0.0, scorer.z)
	# Places de la transformation (repère du moteur), marque dans l'axe du point d'essai.
	var joueurs: Array = []
	for id: String in view._actors:
		var at: Vector3 = view._actors[id].node.position
		joueurs.append({"id": id, "side": int(view._actors[id].side), "x": at.x + 50.0, "y": at.z + 35.0})
	var places := ApresEssai.places(joueurs, side, ApresEssai.marque(side, target.z + 35.0), carrier)
	# Partenaires les plus proches du marqueur : FELICITE_MAX dans FELICITE_RAYON m, au moins FELICITE_MIN.
	var proches: Array = []
	for id: String in view._actors:
		if id != carrier and int(view._actors[id].side) == side and is_instance_valid(view._actors[id].rig):
			proches.append([(view._actors[id].node.position as Vector3).distance_to(centre), id])
	proches.sort()
	var mates: Array = []
	for paire: Array in proches:
		if mates.size() < FELICITE_MAX and (float(paire[0]) <= FELICITE_RAYON or mates.size() < FELICITE_MIN):
			mates.append(str(paire[1]))
	var slots: Array[Vector3] = ApresEssai.autour(centre, dir, mates.size())
	var libres: Array = range(slots.size())
	var rang := 0
	for id: String in mates:
		# Place libre la plus proche : personne ne traverse le groupe.
		var at: Vector3 = view._actors[id].node.position
		var choix := 0
		for k in libres.size():
			if (slots[libres[k]] as Vector3).distance_to(at) < (slots[libres[choix]] as Vector3).distance_to(at):
				choix = k
		var slot: Vector3 = slots[libres[choix]]
		libres.remove_at(choix)
		var joie := _joie_actuelle(id)
		_reprendre(id, "felicite", slot, atan2(centre.x - slot.x, centre.z - slot.z), PACE_BACK)
		cast[id].joie0 = joie
		cast[id].rang = rang
		rang += 1
		# Il court rejoindre le marqueur : il quitte ses applaudissements ou sa joie sur place.
		if view.has_method("arreter_geste"):
			view.arreter_geste(id)
		_plan(id, cast[id])
	for id: String in view._actors:
		if id == carrier or cast.has(id) and cast[id].role in APRES_ROLES or not is_instance_valid(view._actors[id].rig):
			continue
		if not places.has(id):
			continue
		var ou: Vector2 = places[id]
		var mark := Vector3(ou.x - 50.0, 0.0, ou.y - 35.0)
		var camp := int(view._actors[id].side)
		var graine := absi(id.hash())
		var joie := _joie_actuelle(id) if camp == side else 0.0
		var marque_tir := ApresEssai.marque(side, target.z + 35.0)
		var vise := Vector3(marque_tir.x - 50.0, 0.0, marque_tir.y - 35.0)
		_reprendre(id, "repli" if camp != side else "replace", mark, atan2(vise.x - mark.x, vise.z - mark.z), MARCHE)
		var member: Dictionary = cast[id]
		member.joie0 = joie
		if camp != side:
			# Défenseur qui rentre : il contourne le groupe du marqueur (_contourner).
			member.evite = centre
			member.evite_cote = 0.0
		var bornes: Array = JOIE_SUR_PLACE if joie > 0.05 else MARCHE_DEPART
		member.wait = lerpf(float(bornes[0]), float(bornes[1]), float(graine % 100) / 99.0)
		member.allure = MARCHE + MARCHE_ECART * (float(int(graine / 100.0) % 21) / 10.0 - 1.0)
		var elan: Vector3 = _velocity.get(id, view._actors[id].get("velocity", Vector3.ZERO))
		elan.y = 0.0
		member.glisse = elan.limit_length(GLISSE_MAX)


## Poids des bras levés d'un partenaire à l'instant (essai : les trois plus proches ; ballon
## porté : les liés de l'équipe), pour que sa joie continue sans saut.
func _joie_actuelle(id: String) -> float:
	if phase == "essai":
		return smoothstep(drive + 0.3, drive + 0.75, time - pass_at) if id in cheer else 0.0
	if phase == "essai_maul" and cast.has(id) and cast[id].team == side and cast[id].role not in ["walk", "tail"] and id != carrier:
		return smoothstep(drive + 0.25, drive + 0.7, time)
	return 0.0


## Nouveau rôle d'après-essai, depuis la place et la posture du moment (aucun saut de pose).
func _reprendre(id: String, role: String, mark: Vector3, facing: float, peak: float) -> void:
	var avant: Dictionary = cast.get(id, {})
	_enlist(id, role, mark, facing, int(view._actors[id].side), peak)
	for cle in ["pitch", "lift", "lean_now", "crouch_now"]:
		if avant.has(cle):
			cast[id][cle] = avant[cle]


## Place d'un joueur de la scène d'après-essai.
func _place_apres(id: String, member: Dictionary, actor: Node3D) -> void:
	var t := float(member.t)
	var voulu := actor.rotation.y
	if member.role == "felicite":
		actor.position = _run(member, member.mark)
		var reste: Vector3 = member.mark - actor.position
		voulu = atan2(reste.x, reste.z) if Vector2(reste.x, reste.z).length() > 0.4 else float(member.facing)
	else:
		var precedente := actor.position
		var attente := float(member.wait)
		if view.geste_adapte(id) and t <= attente + 0.05:
			# Geste en cours (déception, applaudissements) : il reste sur place, puis rentre.
			member.wait = t
			actor.position = _contourner(member, actor.position, t)
			member.from = actor.position
			member.glisse = Vector3.ZERO
			return
		var marche := maxf(0.0, t - attente)
		var trajet: Vector3 = member.mark - member.from
		trajet.y = 0.0
		var longueur := trajet.length()
		var fait := minf(longueur, float(member.allure) * (marche - ELAN_MARCHE * (1.0 - exp(-marche / ELAN_MARCHE))))
		var glisse: Vector3 = (member.glisse as Vector3) * GLISSE * (1.0 - exp(-t / GLISSE))
		var droit: Vector3 = member.from + (trajet / longueur * fait if longueur > 0.01 else Vector3.ZERO) + glisse
		actor.position = _contourner(member, droit, t)
		if marche > 0.05 and fait < longueur - 0.05:
			# En contournant le groupe : il regarde où il va (tangente), pas à travers le groupe.
			var pas: Vector3 = actor.position - precedente
			pas.y = 0.0
			voulu = atan2(pas.x, pas.z) if pas.length() > 0.2 * _dt and not actor.position.is_equal_approx(droit) else atan2(trajet.x, trajet.z)
		elif marche > 0.05:
			voulu = float(member.facing)
	# Rotation bornée (3,5 rad/s) : jamais de volte-face instantanée.
	actor.rotation.y += clampf(angle_difference(actor.rotation.y, voulu), -3.5 * _dt, 3.5 * _dt)


## Rayon du cercle que les défenseurs qui rentrent laissent libre autour du marqueur (m).
static func rayon_groupe() -> float:
	return ApresEssai.AUTOUR + GROUPE_DEGAGEMENT


## Point `p` d'un défenseur qui rentre, écarté du groupe du marqueur (member.evite) : il est décalé de
## côté (perpendiculairement à son trajet), du côté où il passait déjà, d'un écart en cloche
## (cos², sur GROUPE_APPROCHE fois le rayon avant et après le groupe) qui enveloppe le cercle du
## groupe. Son chemin s'incurve donc tôt et en douceur (pente au plus π / (2 × GROUPE_APPROCHE)),
## sans saut ni accélération. `t` : temps de la scène (écart progressif s'il démarre déjà dedans).
func _contourner(member: Dictionary, p: Vector3, t: float) -> Vector3:
	if not member.has("evite"):
		return p
	var centre: Vector3 = member.evite
	var trajet: Vector3 = member.mark - member.from
	trajet.y = 0.0
	var d := trajet.normalized() if trajet.length() > 0.05 else Vector3(1.0, 0.0, 0.0)
	var n := Vector3(-d.z, 0.0, d.x)
	var q := p - centre
	q.y = 0.0
	var a := q.dot(d)
	var b := q.dot(n)
	var r := rayon_groupe() + 0.1
	var portee := r * GROUPE_APPROCHE
	if absf(a) >= portee:
		return p
	var enveloppe := r * pow(cos(PI * 0.5 * a / portee), 2.0)
	if absf(b) >= enveloppe:
		return p
	if is_zero_approx(float(member.get("evite_cote", 0.0))):
		# Côté choisi à l'approche : celui où il passait déjà (sinon le côté du milieu du terrain).
		member.evite_cote = signf(b) if absf(b) > 0.01 else (1.0 if n.dot(Vector3(-signf(centre.x), 0.0, 0.0)) >= 0.0 else -1.0)
	var cote := float(member.evite_cote)
	var voulu := cote * maxf(cote * b, enveloppe)
	return p + n * (voulu - b) * smoothstep(0.0, GROUPE_ECART, t)


## Point d'essai : celui du moteur (sur la ligne), reporté dans l'en-but.
func _try_point(scene: Dictionary) -> Vector3:
	var point: Vector3 = view._world(scene.get("ball", {}))
	return Vector3(dir * (50.0 + IN_GOAL), point.y, point.z) if absf(absf(point.x) - 50.0) < 1.0 else point


func _start_try(scene: Dictionary, scorer: String, possession: int, holder: String = "") -> void:
	side = possession
	dir = 1.0 if side == 0 else -1.0
	target = _try_point(scene)
	cast.clear()
	carrier = scorer
	giver = ""
	pass_at = 0.0
	var start: Vector3 = view._actors[scorer].node.position
	# Le ballon est dans les mains d'un partenaire : il le donne au marqueur par une passe
	# en retrait, le marqueur venant en soutien ; le ballon ne saute jamais d'un joueur à l'autre.
	if holder != scorer and view._actors.has(holder) and int(view._actors[holder].side) == side and is_instance_valid(view._actors[holder].rig):
		giver = holder
		giver_from = view._actors[holder].node.position
		var lateral := signf(start.z - giver_from.z)
		if is_zero_approx(lateral):
			lateral = 1.0 if giver_from.z < 0.0 else -1.0
		# Le porteur avance vers la ligne pendant que le soutien arrive ; il s'arrête avant l'en-but.
		var room := maxf(0.0, (dir * 50.0 - giver_from.x) * dir - 4.0)
		var advance := 0.0
		pass_at = 0.6
		for attempt in 3:
			receive_at = giver_from + Vector3(dir * (advance - SUPPORT_BACK), 0.0, lateral * SUPPORT_SIDE)
			receive_at.z = clampf(receive_at.z, -34.0, 34.0)
			# Le soutien accélère jusqu'à prendre la passe à l'allure où il part vers la ligne.
			_set_dive(receive_at, false)
			drive = clampf(PI * 0.5 * dive_from.distance_to(dive_to) / TRY_PACE, 0.6, TRY_RUN_MAX)
			var launch := maxf(PI * 0.5 * dive_from.distance_to(dive_to) / drive, 3.0)
			# Il court déjà (SUPPORT_START de son allure de départ) et accélère jusqu'à elle.
			pass_at = clampf(2.0 * start.distance_to(receive_at) / (launch * (1.0 + SUPPORT_START)), 0.6, maxf(0.6, TRY_HOLD_MAX - 1.6 - drive))
			advance = minf(minf(GIVER_PACE * pass_at / 1.5, GIVER_ADVANCE), room)
		_enlist(giver, "giver", Vector3.ZERO, 0.0, side)
		cast[giver]["advance"] = advance
		start = receive_at
	_enlist(scorer, "scorer", Vector3.ZERO, 0.0, side)
	_set_dive(start, false)
	# Course puis plongeon (profil en sinus : pointe π/2 × distance / durée, au plus TRY_PACE) ;
	# une longue échappée n'est pas accélérée pour tenir dans le plan.
	drive = clampf(PI * 0.5 * dive_from.distance_to(dive_to) / TRY_PACE, 0.6, TRY_RUN_MAX)
	# Les trois partenaires les plus proches lèvent les bras ; ils ne sont pas déplacés.
	var mates: Array = []
	for id: String in view._actors:
		if id != scorer and int(view._actors[id].side) == side and is_instance_valid(view._actors[id].rig):
			mates.append([(view._actors[id].target as Vector3).distance_to(target), id])
	mates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	cheer.clear()
	for mate in mates.slice(0, 3):
		cheer.append(mate[1])
	var ball: Node3D = view._ball
	ball_from = ball.global_position if ball.visible else Presentation.ball_anchor(view._actors[scorer].node, view._actors[scorer].rig)
	ball_from_basis = ball.global_basis
	phase = "essai"
	time = 0.0
	done = false


func _featured(scene: Dictionary, possession: int) -> String:
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == possession:
			return str(player.get("id", ""))
	return ""
