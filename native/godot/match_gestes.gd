extends "res://match_gestes_essai.gd"
## Gestes de rugby en présentation : touche avec porteurs, ballon porté, essai aplati.
## Activé seulement par CD_MATCH_GESTES=1 (ou NativeMatchView.set_gestes).
##
## Aucune règle, aucun tirage, aucun résultat ici. Chaque geste habille un fait
## déjà décidé par le moteur et transmis dans la scène :
##   - « touch » (sortie en touche) : court plan de fin d'action (ballon sorti),
##     les joueurs repartent à allure de course vers leur place de la scène ;
##   - « lineout » : alignement aux places que la scène donne (loi 18). Mise en
##     place courte : à allure de course ; longue : coupe de réalisation sur
##     l'alignement déjà formé (cut_to_restart), comme pour les autres remises en
##     jeu (mêlée, renvois) : le temps mort n'est pas animé ;
##   - « setpiece-win » / « setpiece-loss » qui suit une mise en place de touche dans
##     le journal : lancer, deux blocs de saut portés, prise par l'équipe que le moteur désigne ;
##   - la combinaison « maul » du même fait (lue dans live.events) : ballon porté
##     jusqu'au point de ballon transmis ;
##   - « try », avec le marqueur désigné par le moteur.
## Les rôles sans équivalent dans le moteur (sauteur, porteurs, lanceur) sont
## distribués par poste, comme la passe en direct choisit son passeur.
## Tout est procédural sur le squelette CC0 existant : aucune ressource ajoutée.
##
## « Touche seule » (`touche_seule`, 18/11/2026) : le direct sans gestes garde la touche
## elle-même (alignement, lancer du talonneur, sauteur porté qui capte) et rien d'autre : ni
## sortie en touche, ni coupe vers les autres remises en jeu, ni ballon porté, ni essai, ni
## recadrage. La vue l'utilise quand les gestes complets ne sont pas posés.
##
## Découpage (refactor du 24/11/2026, chaîne d'héritage, même objet) : constantes et état
## dans match_gestes_etat.gd, poses dans match_gestes_corps.gd, mise en place et touche dans
## match_gestes_placement.gd, ballon porté, essai et après-essai dans match_gestes_essai.gd.
## Ici : l'interface lue par la vue, la régie et les tests, et le recadrage.


func _init(owner: Node3D, seulement_touche: bool = false) -> void:
	view = owner
	touche_seule = seulement_touche


func active() -> bool:
	return not phase.is_empty()


## Le match attend la fin du geste, comme pour la passe longue en direct.
func holding_tick() -> bool:
	return active() and not done


## La vue garde la main sur le ballon pendant la course d'approche et tant que le lanceur ne l'a pas reçu.
func owns_ball() -> bool:
	return active() and phase not in ["approche", "reprise"] and not (phase == "touche" and time < 0.0)


func stages(id: String) -> bool:
	return cast.has(id) and cast[id].get("staged", true)


## Joueur lié au ballon porté à cette image (contact voulu, que la séparation des joueurs debout laisse) :
## membre du regroupement arrivé à sa place ; ni celui qui le rejoint encore, ni le marqueur qui s'en
## détache, ni ceux qui se replient après l'essai (25/11/2026, sonde des contacts du match filmé).
func lie(id: String) -> bool:
	if not cast.has(id) or phase not in ["maul", "essai_maul"]:
		return false
	var member: Dictionary = cast[id]
	if str(member.get("role", "")) not in ["pack", "opp_pack", "tail"]:
		return false
	if phase == "maul":
		return time >= float(member.get("join", MAUL_FORM))
	return id != carrier and time < drive + 0.5


func observe(live: Dictionary, scene: Dictionary, new_action: bool, enabled: bool) -> void:
	var kind := str(scene.get("kind", ""))
	if kind == "lineout":
		# Places d'alignement données par la scène, gardées pour une touche reprise après une pause.
		_last_lineout = scene
	if not enabled:
		cancel()
		return
	if not new_action:
		return
	if touche_seule and kind not in ["lineout", "setpiece-win", "setpiece-loss"]:
		# Direct sans gestes : tout autre fait rend la main à la vue.
		cancel()
		return
	var holder_before := _holder
	_holder = Presentation.carrier_id(scene)
	var possession := int(scene.get("possession", -1))
	var record := _record(live, scene)
	var team := int(record.get("team", possession))
	if team not in [0, 1]:
		cancel()
		return
	var featured := _featured(scene, team)
	if kind == "try" and phase == "maul" and team == side and cast.has(featured) and cast[featured].role in ["pack", "tail"]:
		# Le moteur aplatit ses essais de ballon porté à dix mètres de la touche.
		var point: Vector3 = view._world(scene.get("ball", {}))
		if absf(point.z + 25.0) < 0.01 and point.distance_to(_frame().center) < 27.0:
			_start_maul_try(scene, featured)
			return
	if kind in ["setpiece-win", "setpiece-loss"] and _is_lineout(live, scene):
		var thrown_by := team if kind == "setpiece-win" else 1 - team
		var line := _line(scene)
		if not (phase == "touche" and awaiting and throw_side == thrown_by and is_equal_approx(line, line_x)):
			cancel()
			# Alignement non présenté (reprise après une pause) : places de la dernière scène de touche, si c'est la même.
			if not _last_lineout.is_empty() and is_equal_approx(_line(_last_lineout), line):
				_align(_last_lineout, thrown_by)
		if phase == "touche":
			# Ballon porté : combinaison jouée, ou ballon porté formé après la prise (fait « porte » du moteur).
			# Touche seule : jamais de ballon porté, le sauteur garde le ballon jusqu'au fait suivant.
			var porte: bool = not touche_seule and kind == "setpiece-win" and (str(record.get("move", "")) == "maul" or record.get("porte", false) == true)
			_resolve(scene, team, featured, porte, porte and record.get("porte", false) == true)
		_velocity.clear()
		return
	var approaching := phase == "approche"
	cancel()
	if touche_seule and kind != "lineout":
		_velocity.clear()
		return
	if kind == "lineout":
		_align(scene, team)
	elif kind == "touch" or (kind == "advantage" and approaching):
		_approach(scene)
	elif kind in RESTARTS:
		cut_to_restart(scene)
	elif kind == "try" and view._actors.has(featured):
		_start_try(scene, featured, team, holder_before)
	_velocity.clear()


func cancel() -> void:
	if not active():
		cast.clear()
		return
	for id: String in cast:
		if not view._actors.has(id):
			continue
		_release(id)
	var ball: Node3D = view._ball
	view._ball_from = ball.global_position
	view._ball_from_basis = ball.global_basis
	view._ball_travel = 0.0
	view._ball_attached = false
	if phase in ["maul", "touche"] and view._carrier_id == carrier and view._actors.has(carrier) and _ball_in_hands():
		view._ball_attached = true
		view._ball_travel = 1.0
		view._actors[carrier].grip = 1.0
	phase = ""
	cast.clear()
	cheer.clear()
	giver = ""
	pass_at = 0.0
	_lancer_adapte = false
	_fin_essai = false
	_releve = ""
	_releve_duree = 0.45
	_apres = false
	done = true
	_ball_ready = false


## L'essai mis en scène est aplati à l'écran (ballon au sol dans l'en-but) ; vrai hors geste d'essai.
## Sert à la régie : l'essai est légendé et acclamé à cet instant, ni avant ni après la joie.
func essai_aplati() -> bool:
	match phase:
		"essai_maul":
			return dive_set and time >= maxf(drive, peel + dive_seconds)
		"essai":
			return time >= pass_at + drive
	return true


func _ball_in_hands() -> bool:
	var entry: Dictionary = view._actors[carrier]
	return Presentation.ball_anchor(entry.node, entry.rig).distance_to(view._ball.global_position) < 0.2


func _release(id: String) -> void:
	var entry: Dictionary = view._actors[id]
	var member: Dictionary = cast[id]
	if member.get("staged", true):
		entry.from = entry.node.position
		entry.elapsed = 0.0
		entry.duree = Motion.duree(entry.from, entry.target)
		entry.tangent = Vector3.ZERO
		entry.velocity = Vector3.ZERO
		entry.feet.clear()
	_outro[id] = {"pitch": float(member.get("pitch", 0.0)), "lift": float(member.get("lift", 0.0)), "age": 0.0}


func advance(delta: float) -> void:
	_dt = delta
	for id: String in _outro.keys():
		_outro[id].age += delta
		if _outro[id].age >= OUTRO or not view._actors.has(id):
			_outro.erase(id)
	if not active():
		return
	for id: String in cast:
		if not view._actors.has(id) or not is_instance_valid(view._actors[id].rig):
			cancel()
			return
	time += delta
	for id: String in cast:
		cast[id].t = float(cast[id].get("t", 0.0)) + delta
	if phase == "touche" and awaiting:
		# Alignement prêt : le match reprend et décidera de la prise.
		time = minf(time, FORM)
		done = time >= FORM
	elif phase == "touche" and time >= TOUCHE_END:
		if maul_wanted:
			_start_maul()
		else:
			cancel()
	elif phase == "approche":
		# Plan de fin d'action : le ballon sort, puis le direct passe à la remise en jeu.
		done = time >= OUT_SHOT
	elif phase == "reprise":
		if time >= SETTLE:
			cancel()
	elif phase == "maul":
		done = time >= MAUL_START + drive + 0.3
	elif phase == "essai_maul":
		if time >= peel and not dive_set:
			_set_dive(view._actors[carrier].node.position, true)
		var aplati := maxf(drive, peel + dive_seconds)
		_apres_essai(aplati)
		done = time >= aplati + (JOY_HOLD if _fin_essai else COUCHE)
	elif phase == "essai":
		var aplati := pass_at + drive
		_apres_essai(aplati)
		done = time >= aplati + (JOY_HOLD if _fin_essai else COUCHE)


func restore(id: String, entry: Dictionary) -> void:
	if not _saved.has(id):
		return
	var saved: Dictionary = _saved[id]
	var rig: Skeleton3D = entry.rig
	if is_instance_valid(rig):
		for index: int in saved.bones:
			rig.set_bone_pose_rotation(index, saved.bones[index])
		for index: int in saved.places:
			rig.set_bone_pose_position(index, saved.places[index])
	(entry.model as Node3D).transform = saved.model
	_saved.erase(id)


## Position et cap d'un joueur mis en scène ; appelé à la place de la trajectoire.
func place(id: String, actor: Node3D) -> void:
	var member: Dictionary = cast[id]
	var from: Vector3 = member.from
	var heading_from: float = member.heading
	var before := actor.position
	if member.role == "walk":
		_walk(id, member, actor)
		_velocity[id] = (actor.position - before) / maxf(_dt, 0.001)
		return
	if member.role in APRES_ROLES:
		_place_apres(id, member, actor)
		_velocity[id] = (actor.position - before) / maxf(_dt, 0.001)
		return
	match phase:
		"reprise":
			actor.position = _run(member, member.mark)
			actor.rotation.y = member.facing
		"touche":
			var mark: Vector3 = member.mark
			var facing: float = member.facing
			var close := smoothstep(FORM + 0.05, FORM + 0.35, time)
			var arrive: float = member.form
			var t: float = member.t
			# Les porteurs se resserrent contre le sauteur (0,7 m) au moment de le soulever.
			if member.role == "lift_front":
				mark.z += float(member.get("close", 0.0)) * close
				facing = lerp_angle(PI, 0.0, close)
			elif member.role == "lift_back":
				mark.z -= float(member.get("close", 0.0)) * close
			# Chacun rejoint sa place à son allure : les plus proches arrivent avant les autres.
			actor.position = _run(member, mark)
			var heading := heading_from
			var travel := mark - from
			if travel.length() > 1.5:
				heading = lerp_angle(heading, atan2(travel.x, travel.z), smoothstep(0.0, 0.3, t))
			var turn := smoothstep(arrive * 0.6, arrive, t) if member.role != "lift_front" else smoothstep(arrive * 0.6, FORM + 0.35 - form_start, t)
			actor.rotation.y = lerp_angle(heading, facing, turn)
			_velocity[id] = (actor.position - before) / maxf(_dt, 0.001)
		"maul", "essai_maul":
			var frame := _frame()
			var slot: Vector2 = member.slot
			if member.has("slot_from"):
				slot = (member.slot_from as Vector2).lerp(slot, smoothstep(0.0, float(member.get("swap", 0.5)), time))
			var spot: Vector3 = frame.center + frame.u * slot.x + frame.r * slot.y
			var facing := atan2(frame.u.x, frame.u.z) + (PI if member.role == "opp_pack" else 0.0)
			if phase == "maul":
				# Chacun rejoint le regroupement à allure de course : les plus éloignés se lient après.
				actor.position = from.lerp(spot, smoothstep(0.0, float(member.get("join", MAUL_FORM)), time))
				actor.rotation.y = lerp_angle(heading_from, facing, smoothstep(0.0, 0.5, time))
			elif id == carrier and dive_set:
				# Il se détache de la queue, contourne le regroupement puis plonge droit.
				var k := smoothstep(0.0, 1.0, (time - peel) / dive_seconds)
				actor.position = dive_from.lerp(dive_to, k)
				var line := dive_to - dive_from
				var around := lerp_angle(facing, atan2(line.x, line.z), smoothstep(0.0, 0.25, k))
				actor.rotation.y = _turn_scorer(lerp_angle(around, atan2(dive_axis.x, dive_axis.z), smoothstep(0.4, 0.7, k)))
			else:
				actor.position = spot
				actor.rotation.y = facing
		"essai":
			if member.role == "giver":
				# Le porteur avance, fait la passe, puis ralentit et s'arrête.
				var go := float(member.get("advance", 0.0))
				var moved := go * smoothstep(0.0, 1.0, minf(time, pass_at) / maxf(pass_at, 0.01)) + minf(1.2, go * 0.25) * smoothstep(pass_at, pass_at + 0.9, time)
				actor.position = from + Vector3(dir * moved, 0.0, 0.0)
				actor.rotation.y = lerp_angle(heading_from, atan2(dir, 0.0), smoothstep(0.0, 0.3, time))
				return
			if time < pass_at:
				# Le soutien, déjà en course, accélère vers la passe et la prend lancé (vitesse continue).
				var u := time / pass_at
				var a0 := 2.0 * SUPPORT_START / (1.0 + SUPPORT_START)
				actor.position = from.lerp(receive_at, a0 * u + (1.0 - a0) * u * u)
				var way := receive_at - from
				actor.rotation.y = lerp_angle(heading_from, atan2(way.x, way.z) if way.length() > 0.5 else atan2(dir, 0.0), smoothstep(0.0, 0.25, time))
				return
			var run_time := time - pass_at
			var k := clampf(run_time / drive, 0.0, 1.0)
			actor.position = dive_from.lerp(dive_to, sin(k * PI * 0.5))
			var line := dive_to - dive_from
			var start_heading := heading_from if giver.is_empty() else atan2(dir, 0.0)
			var run := lerp_angle(start_heading, atan2(line.x, line.z), smoothstep(0.0, 0.25, run_time))
			actor.rotation.y = _turn_scorer(lerp_angle(run, atan2(dive_axis.x, dive_axis.z), smoothstep(0.5, 0.8, k)))


## Corps, bras et ballon ; appelé après l'animation source et avant les prises.
func pose() -> void:
	for id: String in _outro:
		if view._actors.has(id) and not cast.has(id):
			var fade: float = 1.0 - smoothstep(0.0, OUTRO, _outro[id].age)
			_body(id, _outro[id].pitch * fade, _outro[id].lift * fade)
			if _outro[id].lift < 0.0:
				_ground_feet(id)
	if not active():
		return
	match phase:
		"touche": _pose_touche()
		"maul": _pose_maul()
		"essai_maul":
			_pose_maul_try()
			_pose_apres()
		"essai":
			_pose_try()
			_pose_apres()


## Cadrage de la caméra suivie pendant un geste. Reçoit le point visé et la
## hauteur visible normaux ; rend ceux à appliquer. La caméra garde son angle :
## seuls le point visé et la hauteur visible changent, avec une entrée et une
## sortie lissées et une cible amortie. Hors geste et rampe retombée, rend
## exactement les valeurs reçues.
func frame_camera(focus: Vector3, size: float, offset: Vector3, aspect: float, mode: String, delta: float) -> Array:
	if not FRAME_MIN.has(mode) or touche_seule:
		reset_framing()
		return [focus, size, offset]
	var wanted := active() and phase not in ["approche", "reprise"]
	var leap := delta > 0.0 and Vector2(focus.x - _zoom_focus.x, focus.z - _zoom_focus.z).length() > FRAME_LEAP * delta
	_zoom_focus = focus
	if not wanted and zoom <= 0.0:
		_zoom_mode = ""
		return [focus, size, offset]
	var turned := offset.rotated(Vector3.UP, FRAME_YAW[mode])
	if wanted:
		var goal := _frame_goal(turned, aspect, size, FRAME_MIN[mode])
		if _zoom_mode != mode:
			# Début du geste, ou changement de caméra demandé par le joueur (déjà une coupe).
			_zoom_mode = mode
			_zoom_center = goal[0]
			_zoom_goal = goal[0]
			_zoom_size = goal[1]
			_zoom_center_speed = Vector3.ZERO
			_zoom_goal_speed = Vector3.ZERO
			_zoom_size_speed = 0.0
		elif delta > 0.0:
			var goal_step := _damp3(_zoom_goal, goal[0], _zoom_goal_speed, delta)
			_zoom_goal = goal_step[0]
			_zoom_goal_speed = goal_step[1]
			var center_step := _damp3(_zoom_center, _zoom_goal, _zoom_center_speed, delta, FRAME_SMOOTH * 0.5)
			_zoom_center = center_step[0]
			_zoom_center_speed = center_step[1]
			var size_step := _damp1(_zoom_size, goal[1], _zoom_size_speed, delta)
			_zoom_size = size_step[0]
			_zoom_size_speed = size_step[1]
		zoom = minf(1.0, zoom + delta / FRAME_IN)
	else:
		zoom = 0.0 if leap else maxf(0.0, zoom - delta / FRAME_OUT)
		if zoom <= 0.0:
			_zoom_mode = ""
			return [focus, size, offset]
	var w := smoothstep(0.0, 1.0, zoom)
	# Rapprochement à vitesse perçue constante : interpolation de la hauteur visible en échelle logarithmique.
	return [focus.lerp(_zoom_center, w), size * pow(_zoom_size / size, w), offset.rotated(Vector3.UP, FRAME_YAW[mode] * w)]


func reset_framing() -> void:
	zoom = 0.0
	_zoom_mode = ""


## Point visé au sol et hauteur visible qui contiennent le geste, vus sous l'angle de la caméra.
func _frame_goal(offset: Vector3, aspect: float, base: float, smallest: float) -> Array:
	var basis := Basis.looking_at(-offset, Vector3.UP)
	var inverse := basis.inverse()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector3 in _frame_points():
		var local := inverse * point
		low = Vector2(minf(low.x, local.x), minf(low.y, local.y))
		high = Vector2(maxf(high.x, local.x), maxf(high.y, local.y))
	if not low.is_finite():
		return [view._camera_focus, base]
	var middle := (low + high) * 0.5
	var extent := high - low
	var size := clampf(maxf(extent.y, extent.x / maxf(aspect, 0.1)) * FRAME_MARGIN, smallest, base)
	var center := basis * Vector3(middle.x, middle.y, 0.0)
	var ahead := -basis.z
	center += ahead * (-center.y / ahead.y)
	return [Vector3(center.x, 0.0, center.z), size]


## Ce que chaque geste doit montrer.
func _frame_points() -> Array[Vector3]:
	var ground: Array[Vector3] = []
	var tall := 2.0
	match phase:
		"touche":
			# Les deux lignes, le lanceur, les demis ; le sauteur porté au sommet.
			for id: String in cast:
				if cast[id].role != "walk":
					ground.append(cast[id].mark)
			if not jumper.is_empty() and cast.has(jumper):
				ground.append(cast[jumper].mark + Vector3.UP * (LIFT + 2.3 - tall))
		"maul", "essai_maul":
			# Le groupe là où il est, avec de l'espace devant lui dans le sens de la poussée.
			var frame := _frame()
			for corner: Vector2 in [Vector2(-3.0, -2.0), Vector2(5.0, -2.0), Vector2(-3.0, 2.0), Vector2(5.0, 2.0)]:
				ground.append(frame.center + frame.u * corner.x + frame.r * corner.y)
			if phase == "essai_maul":
				ground.append(target)
				ground.append(Vector3(dir * 52.5, 0.0, target.z))
		"essai":
			# Le marqueur, sa course, le point d'essai et l'en-but ; le porteur de la dernière passe.
			if not giver.is_empty() and time < pass_at + 0.6:
				ground.append(giver_from)
				ground.append(view._actors[carrier].node.position if view._actors.has(carrier) else dive_from)
			# Après l'essai, le départ de la course quitte peu à peu le cadre : il se resserre sur le groupe.
			ground.append(dive_from.lerp(dive_to, smoothstep(pass_at + drive, pass_at + drive + 3.0, time)))
			ground.append(target)
			ground.append(Vector3(dir * 52.5, 0.0, target.z))
			for id: String in cheer:
				if view._actors.has(id) and (view._actors[id].target as Vector3).distance_to(target) < 12.0 and not cast.has(id):
					ground.append(view._actors[id].target)
	if phase in ["essai", "essai_maul"] and _apres:
		# Les partenaires qui accourent vers le marqueur, ajoutés en douceur (aucun saut du cadrage).
		var centre: Vector3 = view._actors[carrier].node.position if view._actors.has(carrier) else target
		for id: String in cast:
			if cast[id].role == "felicite" and view._actors.has(id):
				ground.append(centre.lerp(view._actors[id].node.position, smoothstep(0.0, 1.0, float(cast[id].t))))
	var points: Array[Vector3] = []
	for point: Vector3 in ground:
		points.append(Vector3(point.x, 0.0, point.z))
		points.append(Vector3(point.x, maxf(point.y, 0.0) + tall, point.z))
	return points


## Amortissement critique (vitesse continue, aucun dépassement).
static func _damp3(current: Vector3, goal: Vector3, speed: Vector3, delta: float, smooth: float = FRAME_SMOOTH) -> Array:
	var omega := 2.0 / smooth
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - goal
	var push := (speed + omega * change) * delta
	return [goal + (change + push) * decay, (speed - omega * push) * decay]


static func _damp1(current: float, goal: float, speed: float, delta: float) -> Array:
	var omega := 2.0 / FRAME_SMOOTH
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - goal
	var push := (speed + omega * change) * delta
	return [goal + (change + push) * decay, (speed - omega * push) * decay]


## Le moteur a tranché : l'équipe « team » prend le ballon en l'air.
## `try_follows` : le moteur a écrit « porte » sur la conquête, l'essai sur ballon porté suit.
func _resolve(scene: Dictionary, team: int, featured: String, maul: bool, try_follows: bool = false) -> void:
	if str(jumpers[team]).is_empty():
		cancel()
		return
	side = team
	dir = 1.0 if side == 0 else -1.0
	jumper = jumpers[side]
	carrier = featured if view._actors.has(featured) else jumper
	maul_wanted = maul
	maul_try_follows = maul and try_follows
	target = view._world(scene.get("ball", {}))
	awaiting = false
	done = false
