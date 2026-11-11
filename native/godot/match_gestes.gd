extends RefCounted
## Gestes de rugby en présentation : touche avec porteurs, ballon porté, essai aplati.
## Activé seulement par CD_MATCH_GESTES=1 (ou NativeMatchView.set_gestes).
##
## Aucune règle, aucun tirage, aucun résultat ici. Chaque geste habille un fait
## déjà décidé par le moteur et transmis dans la scène :
##   - « lineout » : l'alignement se met en place, le talonneur arme son lancer ;
##   - « setpiece-win » / « setpiece-loss » dont l'origine est une touche (y = 4) :
##     lancer, deux blocs de saut portés, prise par l'équipe que le moteur désigne ;
##   - la combinaison « maul » du même fait (lue dans live.events) : ballon porté
##     jusqu'au point de ballon transmis ;
##   - « try », avec le marqueur désigné par le moteur.
## Les rôles sans équivalent dans le moteur (sauteur, porteurs, lanceur) sont
## distribués par poste, comme la passe en direct choisit son passeur.
## Tout est procédural sur le squelette CC0 existant : aucune ressource ajoutée.

const Presentation = preload("res://match_presentation.gd")

const FORM := 2.0          # mise en place de l'alignement (au plus ; les plus proches arrivent avant)
const FORM_PACE := 4.2     # allure moyenne de mise en place, en m/s
const FORM_MIN := 1.2
const RELEASE := FORM + 0.55   # lancer
const CATCH := FORM + 1.1      # prise à deux mains au sommet
const DOWN := FORM + 1.4       # début de la redescente
const TOUCHE_END := FORM + 1.9
const LIFT := 1.05         # élévation du sauteur porté, en mètres
const MAUL_FORM := 0.7
const MAUL_START := 0.5
const MAUL_PACE := 2.0     # allure moyenne du ballon porté, en m/s
const STRIDE_CYCLE := 0.6  # ballon porté : un cycle de deux petits pas couvre 0,6 m
const STANCE := 0.65       # part du cycle où le pied pousse au sol
const CROUCH := 0.12       # abaissement du bassin des pousseurs, en mètres
const PUSH_PITCH := 0.38   # inclinaison des pousseurs
const LEGS := ["UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R"]
const DIVE_REACH := 1.95   # distance pieds -> ballon d'un plongeon bras tendus
const DIVE_SECONDS := 0.95
const OUTRO := 0.45
# Cadrage pendant un geste (caméras « tv » et « action » seulement).
const FRAME_IN := 1.5      # rapprochement, en secondes
const FRAME_OUT := 1.8     # retour au cadrage normal
const FRAME_SMOOTH := 0.6  # amortissement du centre et de la taille entre deux temps du geste
const FRAME_MIN := {"tv": 11.0, "action": 9.0}  # hauteur visible minimale, en mètres
const FRAME_MARGIN := 1.2
# Pendant le retour, si le suivi d'origine part en panoramique rapide (ballon
# renvoyé au centre après un essai : 100 m/s), le recadrage cède aussitôt la place
# à la caméra d'origine ; mêlé au retour, ce mouvement deviendrait un panoramique
# encore plus rapide à l'écran, en vue rapprochée. Seuil : 40 m/s, au-delà d'une
# course ou d'une passe.
const FRAME_LEAP := 40.0
# Caméra TV seulement : léger pivot autour du point visé pendant le geste, pour
# que les lignes de touche ne s'alignent plus sur l'axe de la caméra (le saut
# se lit alors au-dessus de la ligne). 0,35 rad, soit 20°, en 1,5 s.
const FRAME_YAW := {"tv": 0.35, "action": 0.0}
const ARMS := ["UpperArm.L", "LowerArm.L", "Palm.L", "UpperArm.R", "LowerArm.R", "Palm.R"]
const LINE_Z := [-29.0, -23.2, -21.8, -20.4]
const CONTEST := 0.7        # élévation du bloc adverse, battu

var view
var phase := ""
var time := 0.0
var done := true
var side := 0
var dir := 1.0
var cast: Dictionary = {}
var carrier := ""
var jumper := ""
var jumpers: Array[String] = ["", ""]
var awaiting := false
var line_x := 0.0
var throw_side := 0
var thrower := ""
var maul_wanted := false
var target := Vector3.ZERO
var ball_from := Vector3.ZERO
var ball_from_basis := Basis.IDENTITY
var catch_point := Vector3.ZERO
var release_point := Vector3.ZERO
# Repère du regroupement : centre, axe de poussée, durée.
var center_from := Vector3.ZERO
var center_to := Vector3.ZERO
var axis_from := 0.0
var axis_to := 0.0
var drive := 1.0
var previous_carrier := ""
var peel := 0.0
var dive_from := Vector3.ZERO
var dive_to := Vector3.ZERO
var dive_axis := Vector3.RIGHT
var dive_set := false
var cheer: Array[String] = []
var _saved: Dictionary = {}
var _outro: Dictionary = {}
var _dt := 1.0 / 60.0
# État du recadrage : rampe d'entrée/sortie et cible amortie.
var zoom := 0.0
var _zoom_mode := ""
var _zoom_center := Vector3.ZERO
var _zoom_center_speed := Vector3.ZERO
var _zoom_size := 0.0
var _zoom_size_speed := 0.0
var _zoom_focus := Vector3.ZERO


func _init(owner: Node3D) -> void:
	view = owner


func active() -> bool:
	return not phase.is_empty()


## Le match attend la fin du geste, comme pour la passe longue en direct.
func holding_tick() -> bool:
	return active() and not done


func stages(id: String) -> bool:
	return cast.has(id) and cast[id].get("staged", true)


func observe(live: Dictionary, scene: Dictionary, new_action: bool, enabled: bool) -> void:
	if not enabled:
		cancel()
		return
	if not new_action:
		return
	var kind := str(scene.get("kind", ""))
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
	if kind in ["setpiece-win", "setpiece-loss"] and _is_lineout(scene):
		var thrown_by := team if kind == "setpiece-win" else 1 - team
		var line := _line(scene)
		if not (phase == "touche" and awaiting and throw_side == thrown_by and is_equal_approx(line, line_x)):
			cancel()
			_align(scene, thrown_by)
		if phase == "touche":
			_resolve(scene, team, featured, kind == "setpiece-win" and str(record.get("move", "")) == "maul")
		return
	cancel()
	if kind == "lineout":
		_align(scene, team)
	elif kind == "try" and view._actors.has(featured):
		_start_try(scene, featured, team)


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
	done = true


func _ball_in_hands() -> bool:
	var entry: Dictionary = view._actors[carrier]
	return Presentation.ball_anchor(entry.node, entry.rig).distance_to(view._ball.global_position) < 0.2


func _release(id: String) -> void:
	var entry: Dictionary = view._actors[id]
	var member: Dictionary = cast[id]
	if member.get("staged", true):
		entry.from = entry.node.position
		entry.elapsed = 0.0
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
	if phase == "touche" and awaiting:
		# Alignement prêt : le match reprend et décidera de la prise.
		time = minf(time, FORM)
		done = time >= FORM
	elif phase == "touche" and time >= TOUCHE_END:
		if maul_wanted:
			_start_maul()
		else:
			cancel()
	elif phase == "maul":
		done = time >= MAUL_START + drive + 0.3
	elif phase == "essai_maul":
		if time >= peel and not dive_set:
			_set_dive(view._actors[carrier].node.position, true)
		done = time >= maxf(drive, peel + DIVE_SECONDS) + 1.6
	elif phase == "essai":
		done = time >= drive + 1.6


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
	match phase:
		"touche":
			var mark: Vector3 = member.mark
			var facing: float = member.facing
			var close := smoothstep(FORM + 0.05, FORM + 0.35, time)
			var arrive: float = member.get("form", FORM)
			if member.role == "lift_front":
				mark.z += 0.5 * close
				facing = lerp_angle(PI, 0.0, close)
			elif member.role == "lift_back":
				mark.z -= 0.5 * close
			# Chacun rejoint sa place à son allure : les plus proches arrivent avant les autres.
			actor.position = from.lerp(mark, _drive_curve(clampf(time / arrive, 0.0, 1.0)))
			var heading := heading_from
			var travel := mark - from
			if travel.length() > 1.5:
				heading = lerp_angle(heading, atan2(travel.x, travel.z), smoothstep(0.0, 0.3, time))
			var turn := smoothstep(arrive * 0.6, arrive, time) if member.role != "lift_front" else smoothstep(arrive * 0.6, FORM + 0.35, time)
			actor.rotation.y = lerp_angle(heading, facing, turn)
		"maul", "essai_maul":
			var frame := _frame()
			var slot: Vector2 = member.slot
			if member.has("slot_from"):
				slot = (member.slot_from as Vector2).lerp(slot, smoothstep(0.0, 0.5, time))
			var spot: Vector3 = frame.center + frame.u * slot.x + frame.r * slot.y
			var facing := atan2(frame.u.x, frame.u.z) + (PI if member.role == "opp_pack" else 0.0)
			if phase == "maul":
				actor.position = from.lerp(spot, smoothstep(0.0, MAUL_FORM, time))
				actor.rotation.y = lerp_angle(heading_from, facing, smoothstep(0.0, 0.5, time))
			elif id == carrier and dive_set:
				# Il se détache de la queue, contourne le regroupement puis plonge droit.
				var k := smoothstep(0.0, 1.0, (time - peel) / DIVE_SECONDS)
				actor.position = dive_from.lerp(dive_to, k)
				var line := dive_to - dive_from
				var around := lerp_angle(facing, atan2(line.x, line.z), smoothstep(0.0, 0.25, k))
				actor.rotation.y = lerp_angle(around, atan2(dive_axis.x, dive_axis.z), smoothstep(0.4, 0.7, k))
			else:
				actor.position = spot
				actor.rotation.y = facing
		"essai":
			var k := clampf(time / drive, 0.0, 1.0)
			actor.position = dive_from.lerp(dive_to, sin(k * PI * 0.5))
			var line := dive_to - dive_from
			var run := lerp_angle(heading_from, atan2(line.x, line.z), smoothstep(0.0, 0.25, time))
			actor.rotation.y = lerp_angle(run, atan2(dive_axis.x, dive_axis.z), smoothstep(0.5, 0.8, k))


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
		"essai_maul": _pose_maul_try()
		"essai": _pose_try()


## Cadrage de la caméra suivie pendant un geste. Reçoit le point visé et la
## hauteur visible normaux ; rend ceux à appliquer. La caméra garde son angle :
## seuls le point visé et la hauteur visible changent, avec une entrée et une
## sortie lissées et une cible amortie. Hors geste et rampe retombée, rend
## exactement les valeurs reçues.
func frame_camera(focus: Vector3, size: float, offset: Vector3, aspect: float, mode: String, delta: float) -> Array:
	if not FRAME_MIN.has(mode):
		reset_framing()
		return [focus, size, offset]
	var wanted := active()
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
			_zoom_size = goal[1]
			_zoom_center_speed = Vector3.ZERO
			_zoom_size_speed = 0.0
		elif delta > 0.0:
			var center_step := _damp3(_zoom_center, goal[0], _zoom_center_speed, delta)
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
			# Le marqueur, sa course, le point d'essai et l'en-but.
			ground.append(dive_from)
			ground.append(target)
			ground.append(Vector3(dir * 52.5, 0.0, target.z))
			for id: String in cheer:
				if view._actors.has(id) and (view._actors[id].target as Vector3).distance_to(target) < 12.0:
					ground.append(view._actors[id].target)
	var points: Array[Vector3] = []
	for point: Vector3 in ground:
		points.append(Vector3(point.x, 0.0, point.z))
		points.append(Vector3(point.x, maxf(point.y, 0.0) + tall, point.z))
	return points


## Amortissement critique (vitesse continue, aucun dépassement).
static func _damp3(current: Vector3, goal: Vector3, speed: Vector3, delta: float) -> Array:
	var omega := 2.0 / FRAME_SMOOTH
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


func _pose_touche() -> void:
	var ball: Node3D = view._ball
	var lift := LIFT * smoothstep(FORM + 0.35, FORM + 0.95, time) * (1.0 - smoothstep(DOWN, DOWN + 0.45, time))
	_body(jumper, 0.0, lift)
	var jump: Dictionary = view._actors[jumper]
	var pitcher: Dictionary = view._actors[thrower]
	var overhead: Vector3 = jump.node.global_position + jump.node.global_basis * Vector3(0.0, lift + 2.06, 0.14)
	catch_point = jump.node.global_position + jump.node.global_basis * Vector3(0.0, LIFT + 2.06, 0.14)
	# Lanceur : ballon au-dessus de la tête, armé puis lancer droit.
	var wind := clampf(inverse_lerp(FORM, RELEASE, time), 0.0, 1.0)
	var back := lerpf(-0.05, -0.3, minf(wind / 0.6, 1.0))
	if wind > 0.6:
		back = lerpf(-0.3, 0.32, (wind - 0.6) / 0.4)
	var hands: Vector3 = pitcher.node.global_position + pitcher.node.global_basis * Vector3(0.0, 2.03 + 0.07 * maxf(0.0, (wind - 0.6) / 0.4), back)
	var lean := -0.16 * sin(minf(wind / 0.6, 1.0) * PI * 0.5)
	if wind > 0.6:
		lean = lerpf(-0.16, 0.22, (wind - 0.6) / 0.4) * (1.0 - smoothstep(RELEASE + 0.2, RELEASE + 0.7, time))
	_bend(thrower, lean)
	if time < RELEASE:
		ball.global_position = ball_from.lerp(hands, smoothstep(0.0, FORM * 0.8, time))
		ball.global_basis = ball_from_basis.slerp(pitcher.node.global_basis.orthonormalized(), smoothstep(0.0, FORM * 0.8, time))
		_hold(thrower, ball.global_position if time > FORM * 0.8 else hands, smoothstep(0.2, FORM * 0.8, time))
		release_point = hands
	else:
		var follow: Vector3 = pitcher.node.global_position + pitcher.node.global_basis * Vector3(0.0, 1.85, 0.6)
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
			points.append(hip.lerp(knee, 0.75 if member.role == "lift_front" else 0.1))
		if (points[0] - points[1]).dot(actor.global_basis.x) < 0.0:
			points.reverse()
		_arms(id, points[0], points[1], grip, false)


func _pose_maul() -> void:
	var weight := smoothstep(0.15, MAUL_FORM, time)
	for id: String in cast:
		_bind(id, weight)
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
		if id == carrier:
			continue
		_bind(id, push)
		if joy > 0.0 and cast[id].team == side:
			_cheer(id, joy)
	var dive := smoothstep(0.55, 1.0, (time - peel) / DIVE_SECONDS) if dive_set else 0.0
	if dive <= 0.0:
		# Le marqueur quitte sa posture de poussée en douceur avant de se détacher.
		_ease_body(carrier, 0.2, 0.0)
		_push_legs(carrier, 1.0 - smoothstep(peel, peel + 0.35, time) if dive_set else 1.0)
	else:
		var member: Dictionary = cast[carrier]
		_body(carrier, lerpf(float(member.get("lean_now", 0.2)), 1.42, dive), lerpf(float(member.get("crouch_now", 0.0)), 0.14, dive) + sin(dive * PI) * 0.3)
	var scorer: Dictionary = view._actors[carrier]
	var anchor := Presentation.ball_anchor(scorer.node, scorer.rig)
	var held := anchor
	if view._actors.has(previous_carrier) and previous_carrier != carrier:
		var giver: Dictionary = view._actors[previous_carrier]
		held = Presentation.ball_anchor(giver.node, giver.rig).lerp(anchor, smoothstep(0.1, 0.5, time))
	ball.global_position = held.lerp(_grounded(), dive * dive)
	ball.global_basis = scorer.node.global_basis.orthonormalized()
	_hold(carrier, ball.global_position, smoothstep(0.2, 0.5, time))


func _pose_try() -> void:
	var ball: Node3D = view._ball
	var dive := smoothstep(drive - 0.42, drive, time)
	_body(carrier, 1.42 * dive, 0.14 * dive + sin(dive * PI) * 0.3)
	var scorer: Dictionary = view._actors[carrier]
	var anchor := Presentation.ball_anchor(scorer.node, scorer.rig)
	var taken := smoothstep(0.0, 0.3, time)
	ball.global_position = ball_from.lerp(anchor, taken).lerp(_grounded(), dive * dive)
	ball.global_basis = ball_from_basis.slerp(scorer.node.global_basis.orthonormalized(), taken)
	_hold(carrier, ball.global_position, smoothstep(0.1, 0.3, time))
	var joy := smoothstep(drive + 0.3, drive + 0.75, time)
	if joy > 0.0:
		for id: String in cheer:
			if view._actors.has(id):
				_cheer(id, joy)


func _grounded() -> Vector3:
	return Vector3(target.x, 0.14, target.z)


## Posture de poussée liée : buste engagé, bras vers le partenaire de devant.
func _bind(id: String, weight: float) -> void:
	var member: Dictionary = cast[id]
	if member.role == "half":
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


func _frame() -> Dictionary:
	var k := 1.0
	var angle := axis_to
	if phase == "maul":
		k = _drive_curve(clampf((time - MAUL_START) / drive, 0.0, 1.0))
	else:
		k = smoothstep(0.0, 1.0, clampf(time / drive, 0.0, 1.0))
		angle = lerp_angle(axis_from, axis_to, smoothstep(0.0, 0.6, time))
	var u := Vector3(sin(angle), 0.0, cos(angle))
	var r := Vector3(-u.z, 0.0, u.x)
	if r.z < 0.0:
		r = -r
	return {"center": center_from.lerp(center_to, k), "u": u, "r": r}


## Course ou poussée : mise en mouvement, allure tenue, arrêt ; vitesse de pointe 1,25 fois la moyenne.
static func _drive_curve(t: float) -> float:
	const RAMP := 0.2
	var peak := 1.0 / (1.0 - RAMP)
	if t < RAMP:
		return 0.5 * peak * t * t / RAMP
	if t < 1.0 - RAMP:
		return 0.5 * peak * RAMP + peak * (t - RAMP)
	return 1.0 - 0.5 * peak * (1.0 - t) * (1.0 - t) / RAMP


func _line(scene: Dictionary) -> float:
	return clampf(float(scene.origin.x), 6.0, 94.0) - 50.0


## Alignement des deux équipes : sauteur, deux porteurs, autres avants, demi de mêlée.
func _align(scene: Dictionary, thrown_by: int) -> void:
	var by_slot: Array[Dictionary] = [{}, {}]
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		var team := int(player.get("side", -1))
		if team in [0, 1] and view._actors.has(id) and is_instance_valid(view._actors[id].rig):
			by_slot[team][int(player.get("slot", -1))] = id
	if not by_slot[thrown_by].has(1) or not _is_lineout(scene):
		return
	cast.clear()
	line_x = _line(scene)
	throw_side = thrown_by
	jumpers = ["", ""]
	for team in 2:
		var own: Dictionary = by_slot[team]
		var facing := 1.0 if team == 0 else -1.0
		var x := line_x - facing * 0.6
		if own.has(1):
			if team == thrown_by:
				thrower = own[1]
				_enlist(thrower, "thrower", Vector3(line_x, 0.0, -35.7), 0.0, team)
			else:
				# Talonneur adverse : à deux mètres de la ligne de remise en jeu, dans le couloir des cinq mètres.
				_enlist(own[1], "line", Vector3(line_x - facing * 2.0, 0.0, -32.4), PI, team)
		var jumper_slot := 4 if own.has(4) else 3
		var lifters: Array[int] = []
		for slot in [0, 2, 3, 5, 6, 7]:
			if slot != jumper_slot and own.has(slot) and lifters.size() < 2:
				lifters.append(slot)
		if own.has(jumper_slot) and lifters.size() == 2:
			jumpers[team] = own[jumper_slot]
			_enlist(own[jumper_slot], "jumper", Vector3(x, 0.0, -26.0), PI, team)
			_enlist(own[lifters[0]], "lift_front", Vector3(x, 0.0, -27.2), PI, team)
			_enlist(own[lifters[1]], "lift_back", Vector3(x, 0.0, -24.8), PI, team)
		var place_index := 0
		for slot in [0, 2, 3, 4, 5, 6, 7]:
			if own.has(slot) and not cast.has(own[slot]) and place_index < LINE_Z.size():
				_enlist(own[slot], "line", Vector3(x, 0.0, LINE_Z[place_index]), PI, team)
				place_index += 1
		if own.has(8):
			_enlist(own[8], "half", Vector3(x - facing * 2.8, 0.0, -24.5), facing * PI * 0.5, team)
	side = thrown_by
	dir = 1.0 if side == 0 else -1.0
	jumper = jumpers[side]
	carrier = thrower
	maul_wanted = false
	awaiting = true
	var ball: Node3D = view._ball
	ball_from = ball.global_position if ball.visible else Vector3(line_x, 1.2, -35.7)
	ball_from_basis = ball.global_basis
	phase = "touche"
	time = 0.0
	done = false


## Le moteur a tranché : l'équipe « team » prend le ballon en l'air.
func _resolve(scene: Dictionary, team: int, featured: String, maul: bool) -> void:
	if str(jumpers[team]).is_empty():
		cancel()
		return
	side = team
	dir = 1.0 if side == 0 else -1.0
	jumper = jumpers[side]
	carrier = featured if view._actors.has(featured) else jumper
	maul_wanted = maul
	target = view._world(scene.get("ball", {}))
	awaiting = false
	done = false


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
	drive = clampf(center_from.distance_to(center_to) / MAUL_PACE, 1.6, 6.0)
	if not cast.has(carrier) or cast[carrier].team != side or cast[carrier].role == "half":
		carrier = thrower if cast.has(thrower) and cast[thrower].team == side else jumper
	var rear: Array[Vector2] = [Vector2(-0.75, -0.32), Vector2(-0.75, 0.32), Vector2(-1.5, -0.5), Vector2(-1.5, 0.5), Vector2(-2.25, 0.0)]
	var front := {"jumper": Vector2.ZERO, "lift_front": Vector2(0.0, -0.6), "lift_back": Vector2(0.0, 0.6)}
	var keep: Dictionary = {}
	for id: String in cast:
		var member: Dictionary = cast[id]
		var actor: Node3D = view._actors[id].node
		var next := {"from": actor.position, "heading": actor.rotation.y, "staged": true, "team": member.team}
		if member.team != side:
			# Seul le bloc de saut adverse, déjà au contact, s'oppose à la poussée.
			if not front.has(member.role):
				_release(id)
				continue
			next.merge({"role": "opp_pack", "slot": front[member.role] + Vector2(1.3, 0.0)})
		elif front.has(member.role):
			next.merge({"role": "pack", "slot": front[member.role]})
		elif member.role == "half":
			next.merge({"role": "half", "slot": Vector2(-4.0, 0.9)})
		elif rear.is_empty():
			_release(id)
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
		if cast[id].role == "pack" and cast[id].slot.x < deepest:
			deepest = cast[id].slot.x
			tail = id
	if tail != carrier:
		var swapped: Vector2 = cast[carrier].slot
		cast[carrier].slot = cast[tail].slot
		cast[tail].slot = swapped
	cast[carrier].role = "tail"
	phase = "maul"
	time = 0.0
	done = false


func _start_maul_try(scene: Dictionary, scorer: String) -> void:
	var frame := _frame()
	target = view._world(scene.get("ball", {}))
	center_from = frame.center
	axis_from = atan2(frame.u.x, frame.u.z)
	# Le regroupement reste côté terrain : le marqueur plonge à découvert le long de la touche.
	var aside := Vector3(0.0, 0.0, 3.0 if target.z <= 0.0 else -3.0)
	var gap: Vector3 = target + aside - center_from
	gap.y = 0.0
	# Le regroupement glisse vers le point d'essai en gardant les épaules vers la ligne.
	var u := Vector3(dir * maxf(absf(gap.x), absf(gap.z)), 0.0, gap.z).normalized()
	center_to = target + aside - u * 0.3
	axis_to = atan2(u.x, u.z)
	drive = clampf(center_from.distance_to(center_to) / 2.8, 1.2, 4.0)
	peel = maxf(drive - DIVE_SECONDS + 0.15, 0.45)
	previous_carrier = carrier
	for id: String in cast:
		cast[id].slot_from = cast[id].slot
	if scorer != carrier:
		cast[scorer].slot = cast[carrier].slot_from
		cast[carrier].slot = cast[scorer].slot_from
		cast[carrier].role = "pack"
		cast[scorer].role = "tail"
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


func _start_try(scene: Dictionary, scorer: String, possession: int) -> void:
	side = possession
	dir = 1.0 if side == 0 else -1.0
	target = view._world(scene.get("ball", {}))
	cast.clear()
	carrier = scorer
	_enlist(scorer, "scorer", Vector3.ZERO, 0.0, side)
	_set_dive(view._actors[scorer].node.position, false)
	drive = clampf(dive_from.distance_to(dive_to) / 7.5, 0.6, 1.5)
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


func _enlist(id: String, role: String, mark: Vector3, facing: float, team: int) -> void:
	var entry: Dictionary = view._actors[id]
	var form := clampf(Vector2(mark.x - entry.node.position.x, mark.z - entry.node.position.z).length() / FORM_PACE, FORM_MIN, FORM)
	cast[id] = {"role": role, "team": team, "from": entry.node.position, "heading": entry.node.rotation.y, "mark": mark, "facing": facing, "staged": true, "form": form}
	entry.grip = 0.0
	entry.feet.clear()


func _featured(scene: Dictionary, possession: int) -> String:
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == possession:
			return str(player.get("id", ""))
	return ""


func _is_lineout(scene: Dictionary) -> bool:
	var origin: Variant = scene.get("origin")
	return origin is Dictionary and origin.has("x") and origin.has("y") and absf(float(origin.y) - 4.0) < 0.01


## Fait affiché, retrouvé dans le journal : la clé de scène porte minute et texte.
func _record(live: Dictionary, scene: Dictionary) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(str(scene.get("key", ""))) != OK:
		return {}
	var key: Variant = parser.data
	var events: Variant = live.get("events")
	if not key is Array or key.size() < 2 or not events is Array:
		return {}
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and event.get("scene") is Dictionary and event.get("text") == key[1] and float(event.get("min", -1)) == float(key[0]):
			return event.scene
	return {}


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
