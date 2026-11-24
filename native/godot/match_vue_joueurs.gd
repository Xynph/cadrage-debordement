extends RefCounted
## Joueurs de la vue 3D du match : création des acteurs, animation image par image, replacements
## lointains, gestes du fait affiché et sortie vers le tunnel (mi-temps, fin de match).
## Fonctions statiques sur la vue (`v`, NativeMatchView de match_view.gd), qui garde tout l'état ;
## découpées de match_view.gd le 24/11/2026 sans changement de comportement.

const Presentation = preload("res://match_presentation.gd")
const Motion = preload("res://match_motion.gd")
const Athlete = preload("res://match_athlete.gd")
const Cut = preload("res://match_cut.gd")
const Impacts = preload("res://match_impacts.gd")
const VueBallon = preload("res://match_vue_ballon.gd")

## Nombre de joueurs à l'image, chacun à plus de Motion.TRAJET_REPLACEMENT de sa place, à partir
## duquel la vue coupe pour les replacer (équipe qui se reforme) au lieu de les faire courir.
const REFORMATION_MIN := 6

## Grands moments (18 novembre 2026) : à la mi-temps et en fin de match, sous le plan large, les
## joueurs rentrent en marchant vers le tunnel, au milieu de la touche proche (sous la tribune
## principale). Allure de marche (m/s) : sous le seuil du trot des clips (2,5 m/s).
const TUNNEL := Vector3(0.0, 0.0, 40.0)
## 18/11/2026 (soir) : sous le plan large, les joueurs minuscules ne faisaient que 8 m loin du tunnel.
## La sortie montrée part d'une coupe : chaque joueur reprend, dans la même direction depuis le
## tunnel, à SORTIE_PROCHE_MIN à SORTIE_PROCHE_MAX m de lui (jamais au-delà de SORTIE_PROCHE_Z, dans
## le terrain), puis rentre en marche rapide, trot léger (sous le seuil de course des clips, 2,5 m/s).
const ALLURE_SORTIE := 2.4
const SORTIE_PROCHE_MIN := 4.5
const SORTIE_PROCHE_MAX := 10.0
const SORTIE_PROCHE_Z := 34.0


## Très grands déplacements (replacement après un essai, équipe qui se reforme, poursuivants
## d'un long coup de pied) : plutôt qu'une course de plus de Motion.TRAJET_REPLACEMENT mètres, le
## joueur est replacé à quelques pas de sa place. Quand au moins REFORMATION_MIN de ces joueurs
## sont à l'image au début d'une nouvelle action, la caméra coupe et tous sont replacés pendant la
## coupe ; sinon seuls ceux qui ne sont pas à l'image le sont (les autres courent au sprint).
static func _replacer_longs(v: NativeMatchView, new_action: bool) -> void:
	if v._paused:
		return
	var longs: Array[String] = []
	var visibles := 0
	for id: String in v._actors:
		var entry: Dictionary = v._actors[id]
		# Seulement un trajet qui vient d'être fixé, et jamais un joueur mis en scène ailleurs.
		if float(entry.elapsed) > 0.0 or v._is_pass_player(id) or v.mise_en_scene().stages(id) or (v._choregraphie != null and v._choregraphie.stages(id)) or v._impacts.occupe(id):
			continue
		var at: Vector3 = (entry.node as Node3D).position
		var target: Vector3 = entry.target
		if Vector2(target.x - at.x, target.z - at.z).length() <= Motion.TRAJET_REPLACEMENT:
			continue
		longs.append(id)
		if _a_l_image(v, at) or _a_l_image(v, target):
			visibles += 1
	if longs.is_empty():
		return
	var coupe := new_action and visibles >= REFORMATION_MIN
	for id: String in longs:
		var entry: Dictionary = v._actors[id]
		if not coupe and (entry.holding or _a_l_image(v, (entry.node as Node3D).position) or _a_l_image(v, entry.target)):
			continue
		_replacer(v, entry)
	if coupe:
		v._camera_cut = true
		# Le ballon est déjà où l'action reprend.
		v._ball_from = v._ball_target
		v._ball_travel = 1.0
		v.replacements_coupes += 1


static func _replacer(v: NativeMatchView, entry: Dictionary) -> void:
	var actor: Node3D = entry.node
	var target: Vector3 = entry.target
	var gap := Vector3(target.x - actor.position.x, 0.0, target.z - actor.position.z)
	var pas := minf(Motion.DERNIERS_PAS, gap.length())
	actor.position = target - gap.normalized() * pas if gap.length() > 0.01 else target
	if gap.length() > 0.01:
		actor.rotation.y = atan2(gap.x, gap.z)
	entry.from = actor.position
	entry.velocity = Vector3.ZERO
	entry.tangent = Vector3.ZERO
	entry.duree = Motion.duree(entry.from, target)
	entry.elapsed = 0.0
	entry.feet.clear()
	v.replacements += 1


static func _a_l_image(v: NativeMatchView, point: Vector3) -> bool:
	return is_instance_valid(v._camera) and v._camera.is_inside_tree() and v._camera.is_position_in_frustum(point + Vector3(0.0, 1.0, 0.0))


## Gestes adaptés déclenchés par le fait affiché (bibliothèque CD_MATCH_ANIMATIONS
## seulement) : le joueur que le moteur met en avant frappe ou reçoit le ballon.
## Le clip est calé pour que le contact du pied ou la prise tombe au départ ou à
## l'arrivée du ballon. Sans le clip, rien ne change.
static func _gestes_du_fait(v: NativeMatchView, scene: Dictionary, previous_kind: String) -> void:
	var kind := str(scene.get("kind", ""))
	var possession := int(scene.get("possession", -1))
	var featured := ""
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == possession:
			featured = str(player.get("id", ""))
	if featured.is_empty() or not v._actors.has(featured) or v.mise_en_scene().stages(featured):
		return
	var ball: Dictionary = scene.get("ball", {})
	var origin: Variant = scene.get("origin")
	match kind:
		"goal", "miss", "kick":
			# Pénalité, transformation, jeu au pied : le pied frappe quand le ballon part.
			var cle := v.instant_geste("coup_de_pied")
			v.jouer_geste(featured, "coup_de_pied", maxf(0.0, cle - 0.1), -1.0, true)
		"kickoff", "drop22", "goalLine":
			# Renvoi en drop : seulement si le moteur place le botteur au ballon.
			var at: Dictionary = origin if origin is Dictionary else ball
			var spot := v._world(at)
			if (v._actors[featured].node as Node3D).position.distance_to(Vector3(spot.x, 0.0, spot.z)) < 3.0:
				v.jouer_geste(featured, "drop", maxf(0.0, v.instant_geste("drop") - 0.1), -1.0, true)
		"reception":
			# Ballon haut après un jeu au pied : prise bras tendus ; sinon prise à hauteur de poitrine.
			# Le clip s'arrête juste après la prise (la suite d'origine est une chute).
			var nom := "reception_haute" if previous_kind in ["kick", "kickoff", "drop22", "goalLine", "touch"] else "reception"
			var cle := v.instant_geste(nom)
			v.jouer_geste(featured, nom, maxf(0.0, cle - 0.5), cle + 0.3)


## Mi-temps, fin de match (régie des temps forts) : chaque joueur quitte sa place et marche vers
## le tunnel, à ALLURE_SORTIE ; le ballon est laissé au sol. Plus rien d'une action en cours (passe,
## contact, geste, posture de mêlée) ne reste posé. La prochaine image du moteur reprend la main.
## `rapprocher` : coupe sur la sortie montrée de près (plan_sortie) ; chaque joueur repart plus près
## du tunnel (place_proche_du_tunnel), et la caméra suit le groupe jusqu'à l'entrée du tunnel.
static func sortir_du_terrain(v: NativeMatchView, rapprocher: bool = false) -> void:
	if not v.is_node_ready():
		return
	v.finir_rejeu()
	v.arreter_choregraphie()
	VueBallon._stop_live_pass(v)
	v._pass_plan = {}
	v._contact_plan = {}
	v._impacts.annuler()
	v.mise_en_scene().cancel()
	v._formations.preparer({}, true)
	for tenue: Dictionary in v._tenues.values():
		tenue.lache = true
	v._paused = false
	v.sortie = true
	v._kind = ""
	v._carrier_id = ""
	v._ball_attached = false
	if v._ball.visible:
		v._ball_from = v._ball.position
		v._ball_from_basis = v._ball.global_basis
		v._ball_target = Vector3(v._ball.position.x, Impacts.BALLON_AU_SOL, v._ball.position.z)
		v._ball_travel = 0.0
	v.plan_sortie = rapprocher
	if rapprocher:
		v._camera_cut = true
	for id: String in v._actors:
		var entry: Dictionary = v._actors[id]
		var actor: Node3D = entry.node
		var at: Vector3 = actor.position
		var but := place_de_sortie(at, int(entry.side))
		if rapprocher:
			# Coupe : le joueur reparaît plus près du tunnel, déjà tourné vers lui.
			at = place_proche_du_tunnel(at)
			actor.position = at
			actor.rotation.y = atan2(but.x - at.x, but.z - at.z)
		entry.holding = false
		entry.geste = {}
		entry.grip = 0.0
		entry.cut_direction = 0
		entry.cut_beat = -1.0
		entry.cut_plant.clear()
		entry.from = at
		entry.target = but
		entry.duree = maxf(Motion.DUREE_MIN, Vector2(but.x - at.x, but.z - at.z).length() / ALLURE_SORTIE)
		entry.elapsed = 0.0
		entry.tangent = Vector3.ZERO
		entry.velocity = Vector3.ZERO
		entry.feet.clear()


## Point d'arrivée de la marche vers le tunnel : chaque camp sur sa moitié de l'entrée, les joueurs
## étalés sur quelques mètres pour ne pas converger tous sur le même point.
static func place_de_sortie(depuis: Vector3, camp: int) -> Vector3:
	var cote := -1.0 if camp == 0 else 1.0
	return TUNNEL + Vector3(cote * (1.0 + fposmod(depuis.x * 0.37 + depuis.z * 0.21, 3.0)), 0.0, 0.0)


## Départ de la sortie montrée de près : dans la direction du joueur vue du tunnel, à une distance
## ramenée entre SORTIE_PROCHE_MIN et SORTIE_PROCHE_MAX m (l'ordre des distances est gardé : les plus
## loin restent derrière), et jamais hors du terrain côté tunnel.
static func place_proche_du_tunnel(depuis: Vector3) -> Vector3:
	var ecart := Vector2(depuis.x - TUNNEL.x, depuis.z - TUNNEL.z)
	var loin := ecart.length()
	var direction := ecart / loin if loin > 0.01 else Vector2(0.0, -1.0)
	# Toujours vers le terrain (z décroissant depuis le tunnel).
	if direction.y > -0.35:
		direction = Vector2(signf(direction.x) if absf(direction.x) > 0.001 else 1.0, -0.35 / 0.937).normalized()
	var rayon := lerpf(SORTIE_PROCHE_MIN, SORTIE_PROCHE_MAX, clampf((loin - 5.0) / 60.0, 0.0, 1.0))
	var p := Vector2(TUNNEL.x, TUNNEL.z) + direction * rayon
	return Vector3(p.x, 0.0, minf(p.y, SORTIE_PROCHE_Z))


## Point visé du plan de sortie : le groupe des joueurs, tiré vers le tunnel où il se dirige.
static func _vise_sortie(v: NativeMatchView) -> Vector3:
	var somme := Vector3.ZERO
	for entry: Dictionary in v._actors.values():
		somme += (entry.node as Node3D).position
	var groupe := somme / maxf(1.0, float(v._actors.size())) if not v._actors.is_empty() else TUNNEL
	var vise := groupe.lerp(TUNNEL, 0.3)
	return Vector3(vise.x, 1.0, vise.z)


## Une image d'un joueur (déplacement, cap, clip, appuis, crochet) : boucle de NativeMatchView._process.
static func animer_acteur(v: NativeMatchView, id: String, entry: Dictionary, delta: float, preparation: float) -> void:
	var actor: Node3D = entry.node
	var suivi: bool = v._choregraphie != null and v._choregraphie.stages(id)
	var staged: bool = suivi or v.mise_en_scene().stages(id)
	# Postures rendues dans l'ordre inverse de leur pose : formation (posée en dernier), puis gestes.
	if v._formations:
		v._formations.restaurer(id, entry)
	v.mise_en_scene().restore(id, entry)
	if entry.rig:
		Presentation.restore_contact(entry.rig, entry.contact_base)
		Cut.restore(entry.rig, entry.cut_pose)
	var previous := actor.position
	var previous_heading := actor.rotation.y
	var in_pass := v._is_pass_player(id)
	if in_pass:
		var staging: Dictionary = v._pass_plan.staging[id]
		actor.position = (staging.from as Vector3).lerp(staging.mark, preparation)
		actor.rotation.y = lerp_angle(staging.heading, staging.facing, preparation)
	elif suivi:
		v._choregraphie.place(id, actor)
	elif staged:
		v.mise_en_scene().place(id, actor)
	else:
		# Temps passé à l'arrêt, une fois la place atteinte (même au milieu de cette image).
		var repos := float(entry.elapsed) + delta - float(entry.duree)
		if repos > 0.0:
			entry.cut_idle = minf(NativeMatchView.BLEND_SECONDS, entry.cut_idle + minf(delta, repos))
		entry.elapsed = minf(float(entry.duree), float(entry.elapsed) + delta)
	var progress: float = entry.elapsed / float(entry.duree)
	var live_cut: bool = entry.cut_beat >= 0.0 and entry.cut_normal_speed
	var oneshot: Dictionary = entry.get("geste", {})
	if not in_pass and not staged and not oneshot.is_empty() and oneshot.ancre:
		# Geste au sol ou sur place : le joueur reste où il est ; il rejoindra sa place ensuite.
		entry.from = actor.position
		entry.elapsed = 0.0
		entry.duree = Motion.duree(actor.position, entry.target)
		entry.velocity = Vector3.ZERO
		entry.tangent = Vector3.ZERO
	elif not in_pass and not staged:
		var travel := Cut.live_travel(progress, float(entry.duree)) if live_cut else progress
		actor.position = Motion.position_at(entry.from, entry.target, entry.tangent, travel)
		entry.velocity = ((actor.position - previous) / maxf(delta, 0.001) if live_cut
			else Motion.velocity_at(entry.from, entry.target, entry.tangent, progress, entry.duree))
	var movement := actor.position - previous
	var speed := movement.length() / maxf(delta, 0.001)
	# Allure lissée : elle décide du port du ballon (deux mains ou sous le bras).
	if delta > 0.0 and not v._paused:
		entry.allure = lerpf(float(entry.get("allure", 0.0)), minf(speed, 12.0), 1.0 - exp(-6.0 * delta))
	var moving := speed > 0.035 and not v._paused
	if moving and not in_pass and not staged:
		var change := angle_difference(actor.rotation.y, atan2(movement.x, movement.z))
		actor.rotation.y += clampf(change, -7.2 * delta, 7.2 * delta)
	var animation: AnimationPlayer = entry.animation
	if animation and not oneshot.is_empty() and not v._paused:
		# Geste adapté : le clip avance au temps, pas à la distance parcourue.
		if not oneshot.lance or animation.current_animation != oneshot.clip:
			oneshot.lance = true
			animation.play(oneshot.clip, 0.2)
			animation.seek(float(oneshot.t), false)
		animation.speed_scale = 1.0
		# « vitesse » (match_impacts.gd) : clip lu à une autre allure, ou à l'envers (relevé).
		var vitesse := float(oneshot.get("vitesse", 1.0))
		if vitesse == 1.0:
			animation.advance(delta)
		oneshot.t = float(oneshot.t) + delta * vitesse
		if vitesse != 1.0:
			animation.seek(maxf(0.0, float(oneshot.t)), true)
		if float(oneshot.t) >= float(oneshot.fin) if vitesse >= 0.0 else float(oneshot.t) <= float(oneshot.fin):
			var suite: Array = oneshot.suite
			entry.geste = {}
			if not suite.is_empty():
				var prochain: Array = suite[0] if suite[0] is Array else [suite[0]]
				v.jouer_geste(id, str(prochain[0]), float(prochain[1]) if prochain.size() > 1 else 0.0, float(prochain[2]) if prochain.size() > 2 else -1.0, bool(oneshot.ancre), suite.slice(1))
			else:
				entry.pace = -1
	elif animation:
		var pose_moving := moving or live_cut
		var clip: StringName
		var stride := 4.0
		if entry.adapted:
			# Quatre paliers (marche, trot, course, sprint) au lieu de deux.
			if moving or not live_cut:
				entry.pace = v._animations_adaptees.palier(speed, entry.pace) if moving else -1
			var tier := maxi(int(entry.pace), 0)
			entry.running = tier >= 2 and moving
			clip = v._animations_adaptees.clip(tier) if pose_moving else entry.idle
			stride = v._animations_adaptees.allure(tier)
		else:
			# Hysteresis avoids changing support on every small speed fluctuation.
			if moving or not live_cut:
				entry.running = speed > (2.5 if entry.running else 3.3) if moving else false
			clip = (entry.run if entry.running else entry.walk) if pose_moving else entry.idle
			stride = 1.6 if clip == entry.walk else 4.0
		if not clip.is_empty() and animation.current_animation != clip:
			animation.play(clip, 0.18)
		# Frame-owned animation prevents an AnimationPlayer update from overwriting
		# the hand contact after the pose solver has run.
		animation.speed_scale = 1.0
		# Advance by travelled distance; no minimum cadence while the root creeps.
		var pose_delta := movement.length() / stride if pose_moving else delta
		animation.advance(0.0 if v._paused else pose_delta)
	if entry.rig and not v._paused:
		if staged or not entry.get("geste", {}).is_empty():
			entry.feet.clear()
		elif not live_cut:
			Presentation.support_feet(actor, entry.rig, entry.feet, speed, angle_difference(previous_heading, actor.rotation.y))
		else:
			entry.feet.clear()
		var cut_progress := progress
		if entry.cut_beat >= 0.0:
			entry.cut_beat = minf(NativeMatchView.CUT_SECONDS, float(entry.cut_beat) + delta)
			cut_progress = entry.cut_beat / NativeMatchView.CUT_SECONDS
			if cut_progress >= 1.0:
				entry.cut_beat = -1.0
				entry.cut_direction = 0
				entry.cut_plant.clear()
		if entry.cut_direction != 0 and cut_progress < 1.0:
			if live_cut:
				Cut.apply_live(actor, entry.rig, entry.cut_direction, cut_progress, entry.cut_pose, entry.cut_plant)
			else:
				Cut.apply(actor, entry.rig, entry.cut_direction, cut_progress, entry.cut_pose, entry.cut_plant)


static func _make_actor(v: NativeMatchView, id: String, side: int, target: Vector3) -> Dictionary:
	var actor := Node3D.new()
	actor.name = "Athlete_" + id.validate_node_name()
	v._players.add_child(actor)
	actor.position = target
	actor.rotation.y = PI * 0.5 if side == 0 else -PI * 0.5
	# Aucun repère au sol (anneau aux couleurs de l'équipe) : retiré à la demande de Léo
	# (12 novembre 2026), « ça fait pas réaliste ». Les maillots suffisent à distinguer les équipes.
	var model := v._athlete_scene.instantiate() as Node3D
	actor.add_child(model)
	model.set_meta("athlete_id", id)
	# Imported source contains a 100x mesh transform; calibrate its real rest bounds.
	var bounds := _model_bounds(model, model)
	if bounds.size.y > 0.001:
		var calibration := 1.9 / bounds.size.y
		model.scale = Vector3.ONE * calibration
		model.position.y = -bounds.position.y * calibration
	Athlete.prepare(model)
	v._recolor(model, side)
	if v._rendu:
		v._rendu.equiper_joueur(actor)
	var squelette := Presentation.rig_for(model)
	if squelette:
		squelette.set_meta("repos_relatif", actor.global_basis.inverse() * squelette.global_basis)
	var animation := _find_animation(model)
	var idle := StringName()
	var run := StringName()
	var walk := StringName()
	var adapted := false
	if animation:
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: StringName in animation.get_animation_list():
			if str(clip).ends_with("Man_Idle"):
				idle = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if str(clip).ends_with("Man_Run"):
				run = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if str(clip).ends_with("Man_Walk"):
				walk = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if v._animations_adaptees and v._animations_adaptees.equiper(animation):
			adapted = true
			idle = v._animations_adaptees.repos()
		if not idle.is_empty():
			animation.play(idle)
	return {"node": actor, "model": model, "side": side, "from": target, "target": target,
		"elapsed": NativeMatchView.BLEND_SECONDS, "duree": NativeMatchView.BLEND_SECONDS, "velocity": Vector3.ZERO, "tangent": Vector3.ZERO, "running": false,
		"feet": {}, "cut_direction": 0, "cut_idle": NativeMatchView.BLEND_SECONDS, "cut_beat": -1.0, "cut_normal_speed": false, "cut_pose": {}, "cut_plant": {},
		"contact_base": {}, "contact_weight": 0.0,
		"animation": animation, "idle": idle, "run": run, "walk": walk, "adapted": adapted, "pace": -1, "geste": {}, "rig": Presentation.rig_for(model), "holding": false, "grip": 0.0,
		"allure": 0.0, "tenu": 0.0, "tuck": 0.0, "cote_ballon": 0.0, "porte": 0.0}


static func _model_bounds(node: Node3D, origin: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var relative := origin.global_transform.affine_inverse() * mesh.global_transform
		var part: AABB = relative * mesh.get_aabb()
		result = result.merge(part) if found else part
		found = true
	return result


static func _find_animation(node: Node) -> AnimationPlayer:
	for child: Node in node.get_children():
		if child is AnimationPlayer:
			return child
		var nested := _find_animation(child)
		if nested:
			return nested
	return null
