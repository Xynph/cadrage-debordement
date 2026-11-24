extends RefCounted
## Ballon de la vue 3D du match : port par le porteur, passe du direct, contact, trajectoire et
## ballon des pistes du chorégraphe.
## Fonctions statiques sur la vue (`v`, NativeMatchView de match_view.gd), qui garde tout l'état ;
## découpées de match_view.gd le 24/11/2026 sans changement de comportement.

const Presentation = preload("res://match_presentation.gd")
const Motion = preload("res://match_motion.gd")
const Contact = preload("res://match_contact.gd")
const Pass = preload("res://match_pass.gd")
const ApresEssai = preload("res://match_apres_essai.gd")


## Port du ballon par le porteur : deux mains (prise, passe proche, allure modérée) ou calé sous
## le bras tourné vers la caméra (course lancée). Le ballon suit les poignets.
const PORT_SOUS_LE_BRAS := 4.3     # allure (m/s) à partir de laquelle le ballon est calé sous le bras
const PORT_APRES_PRISE := 0.5      # deux mains au moins pendant ce temps après la prise
const PASSE_ARMEE := 0.42          # armé de la passe avant le lâcher, en secondes
const PASSE_FIN := 0.3             # fin du geste de passe après le lâcher

static func _porter_ballon(v: NativeMatchView, id: String, entry: Dictionary, delta: float) -> void:
	var actor: Node3D = entry.node
	var swing := -1.0
	var toward := 1.0
	if v.choregraphie_active():
		var passe: Dictionary = v._choregraphie.passe_de(id, 0.0, PASSE_ARMEE)
		if not passe.is_empty():
			swing = 1.0 - clampf((float(passe.t) - v._choregraphie.temps) / PASSE_ARMEE, 0.0, 1.0)
			toward = _cote_de(v, actor, str(passe.vers))
	var voulu := 1.0 if swing < 0.0 and float(entry.get("allure", 0.0)) >= PORT_SOUS_LE_BRAS and float(entry.get("tenu", 0.0)) >= PORT_APRES_PRISE else 0.0
	entry.tuck = move_toward(float(entry.get("tuck", 0.0)), voulu, delta * 3.0)
	if float(entry.get("cote_ballon", 0.0)) == 0.0:
		# Calé sous le bras tourné vers la caméra, choisi à la prise : le ballon reste visible.
		var vers_camera := v._camera.global_position - actor.global_position if is_instance_valid(v._camera) else Vector3.BACK
		entry.cote_ballon = 1.0 if actor.global_basis.x.dot(Vector3(vers_camera.x, 0.0, vers_camera.z)) >= 0.0 else -1.0
	var tenue: Array = Presentation.carry_ball(actor, entry.rig, float(entry.grip), float(entry.tuck), float(entry.cote_ballon), swing, toward)
	var possede: bool = v._ball_attached and v._carrier_id == id and not v.mise_en_scene().owns_ball()
	# Raccord en 0,2 s depuis la place donnée par la trajectoire (prise, passe reçue).
	entry.porte = move_toward(float(entry.get("porte", 0.0)), 1.0 if possede else 0.0, delta * 5.0)
	if possede and not v._paused:
		var w := smoothstep(0.0, 1.0, float(entry.porte))
		v._ball.global_position = v._ball.global_position.lerp(tenue[0], w)
		v._ball.global_basis = v._ball.global_basis.orthonormalized().slerp((tenue[1] as Basis).orthonormalized(), w)


## Bras sans ballon : fin du geste de passe, ou mains tendues vers le ballon qui arrive.
static func _bras_hors_ballon(v: NativeMatchView, id: String, entry: Dictionary) -> void:
	if not v.choregraphie_active():
		return
	var actor: Node3D = entry.node
	var passe: Dictionary = v._choregraphie.passe_de(id, PASSE_FIN, 0.0)
	if not passe.is_empty():
		var age: float = v._choregraphie.temps - float(passe.t)
		Presentation.pass_follow(actor, entry.rig, _cote_de(v, actor, str(passe.vers)), 1.0 - clampf(age / PASSE_FIN, 0.0, 1.0))
		return
	var prise: float = v._choregraphie.reception_de(id, 0.45)
	if prise > 0.0 and v._ball.visible:
		Presentation.reach_ball(actor, entry.rig, v._ball.global_position, 1.0 - clampf((prise - v._choregraphie.temps) / 0.45, 0.0, 1.0))


## Côté (1 gauche, -1 droite, repère du joueur) où se trouve `autre`.
static func _cote_de(v: NativeMatchView, actor: Node3D, autre: String) -> float:
	if not v._actors.has(autre):
		return 1.0
	var local := actor.global_basis.inverse() * ((v._actors[autre].node as Node3D).global_position - actor.global_position)
	return 1.0 if local.x >= 0.0 else -1.0


static func _stage_live_pass(v: NativeMatchView) -> void:
	for id: String in [v._pass_plan.passer, v._pass_plan.receiver]:
		if not v._actors.has(id) or not is_instance_valid(v._actors[id].rig):
			v._pass_plan.clear()
			return
	var release: Vector2 = v._pass_plan.origin
	var catch_point: Vector2 = v._pass_plan.catch_point
	v._pass_plan.ball_from = v._ball.global_position
	v._pass_plan.ball_basis = v._ball.global_basis
	v._pass_plan.duration = Pass.LIVE_SECONDS if v._live_cadence == 1 else Pass.FAST_LIVE_SECONDS
	v._pass_plan.staging = {}
	v._contact_plan.clear()
	for id: String in [v._pass_plan.passer, v._pass_plan.receiver]:
		var sending: bool = id == v._pass_plan.passer
		var point := release if sending else catch_point
		var facing := catch_point - release if sending else release - catch_point
		var entry: Dictionary = v._actors[id]
		v._pass_plan.staging[id] = {"from": entry.node.position, "mark": Vector3(point.x - 50.0, 0.0, point.y - 35.0),
			"heading": entry.node.rotation.y, "facing": atan2(facing.x, facing.y)}
		entry.elapsed = 0.0
		entry.tangent = Vector3.ZERO
		entry.velocity = Vector3.ZERO
		entry.feet.clear()
		entry.grip = 0.0


static func _stop_live_pass(v: NativeMatchView, completed: bool = false) -> void:
	if v._pass_plan.is_empty():
		return
	for id: String in [v._pass_plan.passer, v._pass_plan.receiver]:
		if v._actors.has(id):
			# Nouveau trajet depuis la marque de la passe : sa durée suit la distance qui reste
			# (celle fixée avant la passe, depuis l'ancienne place, ralentirait le porteur).
			var entry: Dictionary = v._actors[id]
			entry.from = entry.node.position
			entry.duree = Motion.duree(entry.from, entry.target)
			entry.elapsed = 0.0
	if not completed:
		v._ball_from = v._ball.global_position
		v._ball_from_basis = v._ball.global_basis
		v._ball_travel = 0.0
	v._pass_plan.clear()
	v._pass_elapsed = 0.0


static func _update_live_pass(v: NativeMatchView) -> bool:
	var passer: Dictionary = v._actors[v._pass_plan.passer]
	var receiver: Dictionary = v._actors[v._pass_plan.receiver]
	var passer_anchor := Presentation.ball_anchor(passer.node, passer.rig)
	if v._pass_elapsed < Pass.PREP_SECONDS:
		var preparation := smoothstep(0.0, Pass.PREP_SECONDS, v._pass_elapsed)
		v._ball.global_position = (v._pass_plan.ball_from as Vector3).lerp(passer_anchor, preparation)
		v._ball.global_basis = (v._pass_plan.ball_basis as Basis).slerp(passer.node.global_basis, preparation)
		Pass.pose(passer.node, passer.rig, v._ball.global_position, preparation, passer.contact_base)
		return true
	var progress := inverse_lerp(Pass.PREP_SECONDS, v._pass_plan.duration, v._pass_elapsed)
	var sample := Pass.sample(progress, passer_anchor,
		Presentation.ball_anchor(receiver.node, receiver.rig))
	if sample.is_empty():
		_stop_live_pass(v)
		return false
	v._ball.global_position = sample.ball
	v._ball.global_basis = receiver.node.global_basis if sample.stage == "received" else passer.node.global_basis
	Pass.pose(passer.node, passer.rig, sample.passer_target, sample.passer_weight, passer.contact_base)
	Pass.pose(receiver.node, receiver.rig, sample.receiver_target, sample.receiver_weight, receiver.contact_base)
	if v._pass_elapsed >= v._pass_plan.duration:
		v._ball_attached = true
		v._ball_travel = 1.0
		receiver.grip = 1.0
	return true


static func _update_contact(v: NativeMatchView, delta: float) -> void:
	var carrier: String = v._contact_plan.get("carrier", "")
	var opponent: String = v._contact_plan.get("opponent", "")
	var active := v._ball_attached and v._actors.has(carrier) and v._actors.has(opponent)
	var strength := 0.0
	if active:
		strength = Contact.strength(v._actors[carrier].node.position, v._actors[opponent].node.position)
	for id: String in v._actors:
		var entry: Dictionary = v._actors[id]
		# Clear immediately on an excluded action/pause/removal; fade only within
		# the same eligible geometry. A stale pair must never keep an actor posed.
		if not active or id not in [carrier, opponent]:
			entry.contact_weight = 0.0
			continue
		entry.contact_weight = minf(strength, move_toward(float(entry.contact_weight), strength, delta * 5.0))
	if not active: return
	# Apply the carrier first so the opponent reads the same current chest pose,
	# irrespective of insertion order in the transmitted presence list.
	for id: String in [carrier, opponent]:
		var entry: Dictionary = v._actors[id]
		var other: Dictionary = v._actors[opponent if id == carrier else carrier]
		if entry.rig and other.rig:
			Presentation.brace_contact(entry.node, entry.rig, other.node, other.rig, entry.contact_weight, id == carrier, entry.contact_base)


static func _update_ball(v: NativeMatchView, delta: float) -> void:
	if v.choregraphie_active():
		_ball_des_pistes(v)
		return
	if not v._ball.visible:
		return
	if v.mise_en_scene().owns_ball():
		return
	if not v._pass_plan.is_empty() and _update_live_pass(v):
		return
	v._ball_travel = minf(1.0, v._ball_travel + delta / v.duree_vol())
	if v._tir_au_but():
		# Tir au but : au-dessus de la barre, puis le ballon retombe dans l'en-but (match_apres_essai.gd).
		v._ball_attached = false
		v._ball.position = ApresEssai.vol(v._ball_from, v._ball_target, v._ball_travel)
		return
	if not v._carrier_id.is_empty() and v._actors.has(v._carrier_id) and v._actors[v._carrier_id].rig:
		var entry: Dictionary = v._actors[v._carrier_id]
		var anchor := Presentation.ball_anchor(entry.node, entry.rig)
		if v._ball_travel >= 1.0:
			v._ball_attached = true
		v._ball.global_position = anchor if v._ball_attached else v._ball_from.lerp(anchor, v._ball_travel)
		v._ball.global_basis = entry.node.global_basis if v._ball_attached else v._ball_from_basis.slerp(entry.node.global_basis, v._ball_travel)
	else:
		v._ball_attached = false
		v._ball.position = v._ball_from.lerp(v._ball_target, v._ball_travel)
		# Seuls les coups de pied existants utilisent cet arc générique.
		if v._kind in ["kick", "goal", "miss", "kickoff", "drop22", "goalLine"]:
			v._ball.position.y += sin(v._ball_travel * PI) * minf(6.0, v._ball_from.distance_to(v._ball_target) * 0.18)


## Ballon des pistes : dans les mains de son porteur, sinon sur sa trajectoire (passe,
## ballon au sol, aplati).
static func _ball_des_pistes(v: NativeMatchView) -> void:
	v._ball.visible = true
	var porteur: String = v._choregraphie.porteur()
	v._carrier_id = porteur
	for id: String in v._actors:
		v._actors[id].holding = id == porteur
	var tenu: bool = not porteur.is_empty() and v._actors.has(porteur) and v._actors[porteur].rig and v._choregraphie.etat(porteur) != "aplati"
	var vise: Vector3 = v._choregraphie.ballon_piste()
	if tenu:
		var entry: Dictionary = v._actors[porteur]
		vise = Presentation.ball_anchor(entry.node, entry.rig)
		v._ball.global_basis = (entry.node as Node3D).global_basis
	# Changement de source (prise, lâcher, ramassage, aplati) : le ballon rejoint la nouvelle
	# source en 0,2 s depuis sa place à l'écran, jamais d'un bond.
	var source := porteur + ("|tenu" if tenu else "|piste")
	if v._choregraphie.coupe_ballon:
		# Coupe sur une remise en jeu formée : le ballon est déjà à sa place.
		v._choregraphie.coupe_ballon = false
		v._choregraphie.source_ballon = source
		v._choregraphie.source_depuis = v._choregraphie.temps - 1.0
		v._choregraphie.source_de = vise
	if source != v._choregraphie.source_ballon:
		v._choregraphie.source_ballon = source
		v._choregraphie.source_depuis = v._choregraphie.temps
		v._choregraphie.source_de = v._ball.global_position
	var k := smoothstep(0.0, 0.2, v._choregraphie.temps - v._choregraphie.source_depuis)
	v._ball.global_position = (v._choregraphie.source_de as Vector3).lerp(vise, k)
	v._ball_attached = tenu and k >= 1.0
