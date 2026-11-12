extends RefCounted
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

const Presentation = preload("res://match_presentation.gd")

const FORM := 2.0          # instant du geste où l'alignement est en place ; la mise en place commence avant (temps négatif)
const FORM_MIN := 1.2      # durée minimale d'une course de mise en place
# Mise en place courte : chacun court à une allure crédible ; le direct attend le plus long trajet.
const PACE_FORWARD := 6.5  # allure de pointe d'un avant, en m/s
const PACE_BACK := 7.5     # allure de pointe des autres joueurs
const PACE_MAX := 8.0      # jamais plus vite à l'écran
const WALK_MIN := 0.55     # course la plus courte (durée d'une transition ordinaire de la vue)
const DRIVE_RAMP := 0.2    # part de la course passée à accélérer, puis à freiner
const PEAK := 1.0 / (1.0 - DRIVE_RAMP)  # pointe / allure moyenne du profil de course
# Temps mort avant une remise en jeu : coupe de réalisation plutôt qu'une longue course.
const CUT_BEYOND := 11.0   # au-delà de ce trajet (un joueur au moins), coupe sur la remise en jeu en place
const OUT_SHOT := 0.7      # plan de fin d'action quand le ballon sort en touche, en secondes
const SETTLE := 1.0        # après la coupe : temps de lecture, chacun fait ses derniers pas
const SETTLE_STEP := 1.2   # longueur de ces derniers pas, en mètres au plus
const RESTARTS := ["scrum", "kickoff", "drop22", "goalLine"]
const RELEASE := FORM + 0.55   # lancer
const CATCH := FORM + 1.1      # prise à deux mains au sommet
const DOWN := FORM + 1.4       # début de la redescente
const TOUCHE_END := FORM + 1.9
const LIFT := 1.05         # élévation du sauteur porté, en mètres
const MAUL_FORM := 0.7
const MAUL_START := 0.5
const MAUL_PACE := 2.0     # allure moyenne du ballon porté, en m/s
const MAUL_JOIN_PACE := 5.0  # allure de pointe des joueurs qui rejoignent le ballon porté (le groupe avance aussi)
const STRIDE_CYCLE := 0.6  # ballon porté : un cycle de deux petits pas couvre 0,6 m
const STANCE := 0.65       # part du cycle où le pied pousse au sol
const CROUCH := 0.12       # abaissement du bassin des pousseurs, en mètres
const PUSH_PITCH := 0.38   # inclinaison des pousseurs
const LEGS := ["UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R"]
const DIVE_REACH := 1.95   # distance pieds -> ballon d'un plongeon bras tendus
const DIVE_SECONDS := 0.95
# Essai : le ballon est aplati dans l'en-but, à cette distance derrière la ligne (en-but de 5 m).
const IN_GOAL := 2.0
# Course du marqueur : allure de pointe (profil en sinus) ; une longue échappée dure ce qu'elle dure.
const TRY_PACE := 8.0
const TRY_RUN_MAX := 10.0
# Dernière passe avant l'essai quand le marqueur n'est pas le porteur : jamais vers l'avant (loi 11),
# reçue à SUPPORT_SIDE m sur le côté et SUPPORT_BACK m en retrait du porteur.
const SUPPORT_SIDE := 2.2
const SUPPORT_BACK := 1.0
const SUPPORT_START := 0.6  # le soutien arrive déjà lancé, à 60 % de l'allure où il prend la passe
const GIVER_PACE := 4.5     # allure de pointe du porteur qui fixe la défense en avançant
const GIVER_ADVANCE := 6.0  # il avance de six mètres au plus avant de donner
const PASS_FLIGHT := 0.32
const TRY_HOLD_MAX := 11.0  # le geste entier tient sous l'échéance de la régie (12 s par plan)
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
var dive_seconds := DIVE_SECONDS
var turn_seconds := 0.6
var cheer: Array[String] = []
# Essai : porteur qui fait la dernière passe (vide si le marqueur portait déjà le ballon),
# instant de la passe et point de réception.
var giver := ""
var pass_at := 0.0
var receive_at := Vector3.ZERO
var giver_from := Vector3.ZERO
# Porteur de la scène précédente : celui qui a le ballon quand l'essai commence.
var _holder := ""
# Bibliothèque adaptée : lancer du clip en cours ; gestes de fin d'essai déjà lancés.
var _lancer_adapte := false
var _fin_essai := false
# Marqueur qui se relève (clip adapté) : sa pose de plongeon s'efface pendant le relevé.
var _releve := ""
var _celebre_a := 0.0
const JOY_HOLD := 2.6       # avec les clips adaptés : le temps de voir la joie avant la transformation
var _saved: Dictionary = {}
var _outro: Dictionary = {}
var _dt := 1.0 / 60.0
# Mise en place : début (temps du geste, négatif si elle dure plus de FORM), durée, trajets raccourcis hors champ.
var form_start := 0.0
var form_seconds := 0.0
# Coupes de réalisation faites (compteur, pour les contrôles) et ballon déjà remis au lanceur.
var cuts := 0
var _ball_ready := false
var _velocity: Dictionary = {}
var _last_lineout: Dictionary = {}
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


## La vue garde la main sur le ballon pendant la course d'approche et tant que le lanceur ne l'a pas reçu.
func owns_ball() -> bool:
	return active() and phase not in ["approche", "reprise"] and not (phase == "touche" and time < 0.0)


func stages(id: String) -> bool:
	return cast.has(id) and cast[id].get("staged", true)


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
			_resolve(scene, team, featured, kind == "setpiece-win" and (str(record.get("move", "")) == "maul" or record.get("porte", false) == true))
		_velocity.clear()
		return
	var approaching := phase == "approche"
	cancel()
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
	done = true
	_ball_ready = false


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
		if time >= aplati + 0.3: _celebrer()
		done = time >= aplati + (JOY_HOLD if _fin_essai else 1.6)
	elif phase == "essai":
		if time >= pass_at + drive + 0.3: _celebrer()
		done = time >= pass_at + drive + (JOY_HOLD if _fin_essai else 1.6)


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
				actor.rotation.y = lerp_angle(around, atan2(dive_axis.x, dive_axis.z), smoothstep(0.4, 0.7, k))
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
	if time < 0.0:
		# Mise en place encore longue : la vue laisse le ballon à la marque ; il est remis au lanceur ensuite.
		ball_from = ball.global_position
		ball_from_basis = ball.global_basis
		return
	var lift := LIFT * smoothstep(FORM + 0.35, FORM + 0.95, time) * (1.0 - smoothstep(DOWN, DOWN + 0.45, time))
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
			points.append(hip.lerp(knee, 0.75 if member.role == "lift_front" else 0.1))
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
		if joy > 0.0 and cast[id].team == side and not _adapte(id):
			_cheer(id, joy)
	var dive := smoothstep(0.55, 1.0, (time - peel) / dive_seconds) if dive_set else 0.0
	var rise := smoothstep(_celebre_a, _celebre_a + 0.45, time) if _releve == carrier else 0.0
	if dive <= 0.0:
		# Le marqueur quitte sa posture de poussée en douceur avant de se détacher.
		_ease_body(carrier, 0.2, 0.0)
		_push_legs(carrier, 1.0 - smoothstep(peel, peel + 0.35, time) if dive_set else 1.0)
	else:
		var member: Dictionary = cast[carrier]
		_body(carrier, lerpf(float(member.get("lean_now", 0.2)), 1.42, dive) * (1.0 - rise), (lerpf(float(member.get("crouch_now", 0.0)), 0.14, dive) + sin(dive * PI) * 0.3) * (1.0 - rise))
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
	# Relevé du clip adapté : la pose de plongeon s'efface pendant qu'il se redresse.
	var rise := smoothstep(_celebre_a, _celebre_a + 0.45, time) if _releve == carrier else 0.0
	_body(carrier, 1.42 * dive * (1.0 - rise), (0.14 * dive + sin(dive * PI) * 0.3) * (1.0 - rise))
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
			if view._actors.has(id) and not _adapte(id):
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


func _frame() -> Dictionary:
	var k := 1.0
	var angle := axis_to
	if phase == "maul":
		k = _drive_curve(clampf((time - MAUL_START) / drive, 0.0, 1.0))
	else:
		k = smoothstep(0.0, 1.0, clampf(time / drive, 0.0, 1.0))
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
	# La défense engage aussi ses autres avants de l'alignement : liés sur les flancs du
	# ballon porté, buste engagé, au lieu de rester debout à côté (loi 16 : liés, sur leurs pieds).
	var flanks: Array[Vector2] = [Vector2(0.75, -1.15), Vector2(0.75, 1.15)]
	var keep: Dictionary = {}
	for id: String in cast:
		var member: Dictionary = cast[id]
		var actor: Node3D = view._actors[id].node
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
			next.merge({"role": "opp_pack", "slot": front[member.role] + Vector2(1.3, 0.0)})
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
			var spot: Vector3 = center_from + u * (cast[id].slot as Vector2).x + r * (cast[id].slot as Vector2).y
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
	drive = clampf(center_from.distance_to(center_to) / 2.8, 1.2, 4.0)
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


func _adapte(id: String) -> bool:
	return view.has_method("geste_adapte") and view.geste_adapte(id)


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


func _featured(scene: Dictionary, possession: int) -> String:
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == possession:
			return str(player.get("id", ""))
	return ""


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
