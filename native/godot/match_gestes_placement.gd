extends "res://match_gestes_corps.gd"
## Gestes de rugby : mise en place et touche (alignement, courses, coupes de réalisation,
## lecture du journal du moteur).


func _frame() -> Dictionary:
	var k := 1.0
	var angle := axis_to
	if phase == "maul":
		k = _drive_curve(clampf((time - MAUL_START) / drive, 0.0, 1.0))
	else:
		k = _drive_curve(clampf(time / drive, 0.0, 1.0))
		angle = lerp_angle(axis_from, axis_to, smoothstep(0.0, turn_seconds, time))
	var u := Vector3(sin(angle), 0.0, cos(angle))
	var r := Vector3(-u.z, 0.0, u.x)
	if r.z < 0.0:
		r = -r
	return {"center": center_from.lerp(center_to, k), "u": u, "r": r}


## Course ou poussée : mise en mouvement, allure tenue, arrêt ; vitesse de pointe 1,25 fois la moyenne.
static func _drive_curve(t: float) -> float:
	const RAMP := DRIVE_RAMP
	var peak := 1.0 / (1.0 - RAMP)
	if t < RAMP:
		return 0.5 * peak * t * t / RAMP
	if t < 1.0 - RAMP:
		return 0.5 * peak * RAMP + peak * (t - RAMP)
	return 1.0 - 0.5 * peak * (1.0 - t) * (1.0 - t) / RAMP


func _line(scene: Dictionary) -> float:
	# Marque bornée comme dans la scène du moteur (loi 18 : jamais à moins de 5 m d'une ligne de but).
	return clampf(float(scene.origin.x), 5.0, 95.0) - 50.0


## Alignement des deux équipes aux places que donne la scène de touche du moteur
## (loi 18) : lanceur, vis-à-vis, rangées, receveurs, non-participants. Les rôles
## sans équivalent dans le moteur (sauteur, porteurs) prennent trois places voisines
## de la rangée ; les autres avants occupent les places restantes, dans l'ordre des postes.
func _align(scene: Dictionary, thrown_by: int) -> void:
	var by_slot: Array[Dictionary] = [{}, {}]
	var spot := {}
	var slot_of := {}
	var team_of := {}
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		var team := int(player.get("side", -1))
		if team in [0, 1] and view._actors.has(id) and is_instance_valid(view._actors[id].rig):
			by_slot[team][int(player.get("slot", -1))] = id
			spot[id] = view._world(player)
			slot_of[id] = int(player.get("slot", -1))
			team_of[id] = team
	if not by_slot[thrown_by].has(1):
		return
	cast.clear()
	line_x = _line(scene)
	throw_side = thrown_by
	jumpers = ["", ""]
	_ball_ready = false
	for team in 2:
		var own: Dictionary = by_slot[team]
		var facing := 1.0 if team == 0 else -1.0
		if own.has(1):
			if team == thrown_by:
				thrower = own[1]
				_enlist(thrower, "thrower", spot[thrower], 0.0, team, PACE_FORWARD)
			else:
				# Talonneur adverse : à deux mètres de la ligne de remise en jeu et de la ligne des 5 m.
				_enlist(own[1], "line", spot[own[1]], PI, team, PACE_FORWARD)
		var row: Array[int] = []
		var places: Array[Vector3] = []
		for slot in [0, 2, 3, 4, 5, 6, 7]:
			if own.has(slot):
				row.append(slot)
				places.append(spot[own[slot]])
		places.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
		var jumper_slot := 4 if own.has(4) else 3
		var lifters: Array[int] = []
		for slot in [0, 2, 3, 5, 6, 7]:
			if slot != jumper_slot and own.has(slot) and lifters.size() < 2:
				lifters.append(slot)
		var free: Array[Vector3] = places.duplicate()
		if own.has(jumper_slot) and lifters.size() == 2 and places.size() >= 3:
			var c := clampi(places.size() / 2, 1, places.size() - 2)
			jumpers[team] = own[jumper_slot]
			_enlist(own[jumper_slot], "jumper", places[c], PI, team, PACE_FORWARD)
			_enlist(own[lifters[0]], "lift_front", places[c - 1], PI, team, PACE_FORWARD)
			_enlist(own[lifters[1]], "lift_back", places[c + 1], PI, team, PACE_FORWARD)
			cast[own[lifters[0]]].close = maxf(0.0, places[c].z - places[c - 1].z - 0.7)
			cast[own[lifters[1]]].close = maxf(0.0, places[c + 1].z - places[c].z - 0.7)
			free = []
			for index in places.size():
				if absi(index - c) > 1:
					free.append(places[index])
		var next := 0
		for slot in row:
			if not cast.has(own[slot]) and next < free.size():
				_enlist(own[slot], "line", free[next], PI, team, PACE_FORWARD)
				next += 1
		if own.has(8):
			_enlist(own[8], "half", spot[own[8]], facing * PI * 0.5, team, PACE_BACK)
	# Les autres gagnent leur place de non-participant et regardent l'alignement.
	for id: String in spot:
		if not cast.has(id):
			var place: Vector3 = spot[id]
			_enlist(id, "walk", place, atan2(line_x - place.x, -35.0 - place.z), team_of[id], PACE_FORWARD if int(slot_of[id]) < 8 else PACE_BACK)
			cast[id].look = true
	side = thrown_by
	dir = 1.0 if side == 0 else -1.0
	jumper = jumpers[side]
	carrier = thrower
	maul_wanted = false
	awaiting = true
	_lancer_adapte = false
	_saut_lance = false
	var ball: Node3D = view._ball
	ball_from = ball.global_position if ball.visible else spot[thrower]
	ball_from_basis = ball.global_basis
	phase = "touche"
	done = false
	var farthest := 0.0
	for id: String in cast:
		var gap: Vector3 = cast[id].mark - view._actors[id].node.position
		farthest = maxf(farthest, Vector2(gap.x, gap.z).length())
	if farthest > CUT_BEYOND:
		# Temps mort : coupe sur l'alignement déjà formé, lanceur ballon en main.
		_cut()
		_ball_ready = true
		form_seconds = SETTLE
		form_start = FORM - SETTLE
		time = form_start
	else:
		_schedule()


## Mise en place courte (moins de CUT_BEYOND) : chacun court à son allure, au plus
## PACE_FORWARD ou PACE_BACK ; le direct attend le plus long trajet.
func _schedule() -> void:
	var longest := FORM
	for id: String in cast:
		_plan(id, cast[id])
		longest = maxf(longest, cast[id].form)
	form_seconds = longest
	form_start = FORM - longest
	time = form_start


## Coupe de réalisation vers une remise en jeu (touche, mêlée, renvoi) : plutôt que
## d'animer le temps mort, la vue passe d'un plan à l'autre. Chaque joueur de la
## distribution réapparaît à SETTLE_STEP au plus de sa place, déjà tourné vers elle,
## et fait ses derniers pas pendant SETTLE ; la caméra coupe avec lui (point suivi
## et recadrage posés d'un coup). Réutilisable : la distribution (cast) et ses places
## sont celles du geste en cours.
func _cut() -> void:
	_velocity.clear()
	for id: String in cast:
		var member: Dictionary = cast[id]
		var entry: Dictionary = view._actors[id]
		var actor: Node3D = entry.node
		var gap: Vector3 = member.mark - actor.position
		gap.y = 0.0
		var step := minf(SETTLE_STEP, gap.length())
		member.from = member.mark - (gap.normalized() * step if gap.length() > 0.01 else Vector3.ZERO)
		member.heading = member.facing
		member.t = 0.0
		member.k0 = 0.0
		member.form = SETTLE
		member.dist = step
		actor.position = member.from
		actor.rotation.y = member.facing
		entry.from = member.from
		entry.velocity = Vector3.ZERO
		entry.feet.clear()
	cuts += 1
	view._camera_cut = true
	# Recadrage posé d'emblée : la coupe arrive sur le plan rapproché.
	zoom = 1.0
	_zoom_mode = ""


## Remise en jeu (mêlée, renvoi) dont la mise en place serait une longue course :
## coupe sur la remise en jeu déjà en place, puis SETTLE de lecture. Rend vrai si
## la coupe a eu lieu ; sinon la vue garde sa transition ordinaire.
func cut_to_restart(scene: Dictionary) -> bool:
	var ball_data: Dictionary = scene.get("ball", {})
	var aim: Vector3 = view._world(ball_data) if ball_data.has("x") else Vector3.ZERO
	var farthest := 0.0
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		if view._actors.has(id):
			var gap: Vector3 = view._actors[id].target - view._actors[id].node.position
			farthest = maxf(farthest, Vector2(gap.x, gap.z).length())
	if farthest <= CUT_BEYOND:
		return false
	cast.clear()
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		var team := int(player.get("side", -1))
		if team in [0, 1] and view._actors.has(id) and is_instance_valid(view._actors[id].rig):
			var place: Vector3 = view._actors[id].target
			_enlist(id, "settle", place, atan2(aim.x - place.x, aim.z - place.z), team)
	if cast.is_empty():
		return false
	_cut()
	zoom = 0.0
	# Le ballon est déjà à la remise en jeu.
	view._ball_from = view._ball_target
	view._ball_travel = 1.0
	view._ball.position = view._ball_target
	phase = "reprise"
	time = 0.0
	done = false
	return true


## Durée de course d'un joueur (allure de pointe member.peak), départ à sa vitesse actuelle.
func _plan(id: String, member: Dictionary, forced: float = -1.0) -> void:
	var along: Vector3 = member.mark - member.from
	along.y = 0.0
	var dist := along.length()
	member.dist = dist
	member.t = 0.0
	member.form = forced if forced > 0.0 else maxf(WALK_MIN if member.role == "walk" else FORM_MIN, PEAK * dist / float(member.peak))
	# Sans arrêt à la reprise : la course part de la vitesse déjà prise dans la bonne direction.
	var velocity: Vector3 = _velocity.get(id, view._actors[id].get("velocity", Vector3.ZERO))
	var ahead := velocity.dot(along / dist) if dist > 0.01 else 0.0
	member.k0 = clampf(maxf(ahead, 0.0) * DRIVE_RAMP * float(member.form) / (PEAK * maxf(dist, 0.01)), 0.0, DRIVE_RAMP)


## Position sur la course : profil à allure tenue, repris à la progression k0.
func _run(member: Dictionary, mark: Vector3) -> Vector3:
	var k0: float = member.get("k0", 0.0)
	var k := lerpf(k0, 1.0, clampf(float(member.t) / float(member.form), 0.0, 1.0))
	var d0 := _drive_curve(k0)
	return (member.from as Vector3).lerp(mark, (_drive_curve(k) - d0) / maxf(1.0 - d0, 0.001))


## Joueur qui suit la place que lui donne la scène, à allure de course ; nouvelle place, nouvelle course.
func _walk(id: String, member: Dictionary, actor: Node3D) -> void:
	var goal: Vector3 = view._actors[id].target
	if not goal.is_equal_approx(member.mark):
		member.mark = goal
		member.from = actor.position
		member.heading = actor.rotation.y
		member.look = false
		_plan(id, member)
	actor.position = _run(member, member.mark)
	var travel: Vector3 = member.mark - member.from
	var heading: float = member.heading
	if travel.length() > 1.5:
		heading = lerp_angle(heading, atan2(travel.x, travel.z), smoothstep(0.0, 0.3, float(member.t)))
	if member.get("look", false):
		heading = lerp_angle(heading, float(member.facing), smoothstep(float(member.form) * 0.6, float(member.form), float(member.t)))
	actor.rotation.y = heading


## Sortie en touche : chacun gagne sa place de la scène à allure de course, sans retenir le direct.
func _approach(scene: Dictionary) -> void:
	cast.clear()
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		var team := int(player.get("side", -1))
		if team in [0, 1] and view._actors.has(id) and is_instance_valid(view._actors[id].rig):
			_enlist(id, "walk", view._actors[id].target, 0.0, team, PACE_FORWARD if int(player.get("slot", -1)) < 8 else PACE_BACK)
			_plan(id, cast[id])
	if cast.is_empty():
		return
	phase = "approche"
	time = 0.0
	done = false


func _enlist(id: String, role: String, mark: Vector3, facing: float, team: int, peak: float = PACE_FORWARD) -> void:
	var entry: Dictionary = view._actors[id]
	cast[id] = {"role": role, "team": team, "from": entry.node.position, "heading": entry.node.rotation.y, "mark": mark, "facing": facing, "staged": true, "peak": peak, "t": 0.0, "form": FORM_MIN, "k0": 0.0}
	entry.grip = 0.0
	entry.feet.clear()


## Un joueur mis en scène redevient suiveur de sa place dans la scène, à allure de course.
func _walker(id: String, member: Dictionary) -> Dictionary:
	var actor: Node3D = view._actors[id].node
	var next := {"role": "walk", "team": member.team, "from": actor.position, "heading": actor.rotation.y, "mark": view._actors[id].target,
		"facing": 0.0, "staged": true, "peak": member.get("peak", PACE_BACK), "t": 0.0}
	_plan(id, next)
	return next


## Touche : la scène de mise en place elle-même, ou la touche gagnée ou perdue que le
## moteur enregistre juste après elle dans le journal. À défaut de journal, l'alignement
## en cours de présentation.
func _is_lineout(live: Dictionary, scene: Dictionary) -> bool:
	var kind := str(scene.get("kind", ""))
	if kind == "lineout":
		return true
	if kind not in ["setpiece-win", "setpiece-loss"]:
		return false
	var index := _record_index(live, scene)
	if index > 0:
		var previous: Variant = live.events[index - 1]
		return previous is Dictionary and previous.get("scene") is Dictionary and str(previous.scene.get("kind", "")) == "lineout"
	return index < 0 and phase == "touche" and awaiting


## Fait affiché, retrouvé dans le journal : la clé de scène porte minute et texte.
func _record(live: Dictionary, scene: Dictionary) -> Dictionary:
	var index := _record_index(live, scene)
	return live.events[index].scene if index >= 0 else {}


func _record_index(live: Dictionary, scene: Dictionary) -> int:
	var parser := JSON.new()
	if parser.parse(str(scene.get("key", ""))) != OK:
		return -1
	var key: Variant = parser.data
	var events: Variant = live.get("events")
	if not key is Array or key.size() < 2 or not events is Array:
		return -1
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and event.get("scene") is Dictionary and event.get("text") == key[1] and float(event.get("min", -1)) == float(key[0]):
			return index
	return -1
