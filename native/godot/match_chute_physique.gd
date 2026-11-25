extends RefCounted
## Chute physique au plaquage (choix de Léo du 24/11/2026, option B de l'essai « plaquages ») :
## au plaquage, le buste, le cou et la tête du porteur plaqué réagissent physiquement (Jolt
## Physics, project.godot) pendant une seconde, mélangés à l'animation, puis rendus à elle.
##
## Présentation seule. Déclenchée uniquement sur un plaquage déjà transmis : état « plaque » des
## pistes du chorégraphe, ou chute du porteur arrêté par le moteur (match_impacts.gd). Les racines
## restent sur leurs trajectoires : aucun nœud du joueur n'est déplacé. Buste, cou et tête sont
## des corps rigides à l'échelle du monde, liés en cône, accrochés à l'abdomen (corps cinématique
## qui suit l'animation). Seules leurs ROTATIONS reviennent au squelette (ni translation ni échelle
## d'os : le skinning de match_athlete.gd reste intact), posées comme les autres poses procédurales
## de la vue : après l'animation, avant le ballon (le ballon et les mains suivent donc le buste), et
## retirées au début de l'image suivante (`restaurer`). Les bras restent sur l'animation.
##
## Sol et adversaire (exigence de Léo) : un sol de collision (y = 0) arrête les corps ; un butoir
## vérifie, après la pose, la hauteur de chaque os du haut du corps et du haut de la tête, et réduit
## le mélange (jusqu'à l'animation seule) si la physique ferait passer un os sous la pelouse plus
## bas que l'animation ; il fait de même si la physique faisait entrer le buste ou la tête du porteur
## dans ceux du plaqueur plus que l'animation (pas de corps-obstacles : un recouvrement déjà présent
## dans l'animation les ferait exploser).
##
## Corps créés à l'avance (réserve de RESERVE squelettes, au premier joueur créé) : aucun pic de
## création au plaquage. Pourquoi pas PhysicalBone3D : le squelette Quaternius porte une échelle
## ×100 ; les corps physiques étant orthonormés, formes et liaisons des PhysicalBone3D se
## retrouvent 100 fois trop petites et la chaîne explose (banc de l'essai du 24/11).

const ANCRE := "Abdomen"
## Ordre parent d'abord (les rotations sont posées dans cet ordre).
const SIMULES := ["Torso", "Neck", "Head"]
const PARENTS := {"Torso": "Abdomen", "Neck": "Torso", "Head": "Neck"}
## Os qui ferme la capsule de chaque corps (vide : tête, capsule de TETE m le long de l'os).
const BOUTS := {"Abdomen": "Torso", "Torso": "Neck", "Neck": "Head", "Head": ""}
const TETE := 0.22
## Rayon (m) et masse (kg) des corps.
const CORPS := {"Abdomen": [0.16, 12.0], "Torso": [0.17, 16.0], "Neck": [0.06, 2.0], "Head": [0.11, 5.0]}
## Débattement des liaisons (degrés : cône, torsion).
const CONES := {"Torso": [18.0, 10.0], "Neck": [20.0, 15.0], "Head": [20.0, 15.0]}
## Part maximale de la physique dans la pose, vitesse (m/s) donnée au buste dans le sens du
## plaquage, freinage des corps.
const INFLUENCE := 0.75
const IMPULSION := 1.6
const AMORTI := 1.8
## Courbe du mélange (s, temps de la vue) : montée au contact, tenue, retour à l'animation.
const MONTEE := 0.08
const TENUE := 0.45
const DUREE := 1.0
## Butoir : hauteur minimale (m) des os du haut du corps quand l'animation est au-dessus ;
## essais de mélange réduit de moitié avant l'animation seule.
const SOL_MARGE := 0.04
const BUTOIR_ESSAIS := 3
## Recouvrement des bustes et têtes (m) que la physique peut ajouter à celui de l'animation.
const RECOUVREMENT_TOLERE := 0.01
## Squelettes physiques préparés à l'avance (plaquages simultanés au plus).
const RESERVE := 3
## Calques : sol (1), corps du porteur (2). Jamais entre deux joueurs
## hors du plaquage, jamais avec le reste du stade.
const CALQUE_SOL := 1
const CALQUE_OS := 2
## Garde-fou : corps à plus de cette distance (m) de sa place animée -> retour à l'animation.
const ECART_MAX := 1.2
const PARKING := Vector3(0.0, -50.0, 0.0)

var view
## Faux : aucune chute (outils de comparaison avec l'animation seule ; jamais dans le jeu).
var actif := true
var _monde: Node3D
## Réserve : [{"corps": {os: RigidBody3D}, "joints": {os: Joint3D}, "id": String, "autre": String,
##   "t": float, "decal": {os: Transform3D}}]
var _reserve: Array = []
## id -> rotations locales d'origine (os -> Quaternion), remises au début de l'image suivante.
var _origines: Dictionary = {}
## Compteurs (tests, mesures).
var declenchements := 0
var butoirs := 0
var ruptures := 0


func _init(owner) -> void:
	view = owner


## Prépare la réserve (une fois, avec le squelette du premier joueur : tous partagent le modèle).
func preparer(rig: Skeleton3D) -> void:
	if not _reserve.is_empty() or rig == null or not rig.is_inside_tree() or rig.find_bone(ANCRE) < 0:
		return
	_monde = Node3D.new()
	_monde.name = "ChutePhysique"
	view.add_child(_monde)
	var sol := StaticBody3D.new()
	sol.name = "Sol"
	sol.collision_layer = CALQUE_SOL
	sol.collision_mask = 0
	var forme := CollisionShape3D.new()
	forme.shape = WorldBoundaryShape3D.new()
	sol.add_child(forme)
	_monde.add_child(sol)
	var echelle := rig.global_basis.get_scale().x
	for n in RESERVE:
		var r := {"corps": {}, "joints": {}, "decal": {}, "id": "", "autre": ""}
		var noms: Array = [ANCRE]
		noms.append_array(SIMULES)
		for nom: String in noms:
			var c := _corps(rig, echelle, nom, "Os%d_%s" % [n, nom])
			if c.is_empty():
				continue
			r.corps[nom] = c.corps
			r.decal[nom] = c.decal
		for nom: String in SIMULES:
			if not r.corps.has(nom) or not r.corps.has(PARENTS[nom]):
				continue
			var joint := ConeTwistJoint3D.new()
			joint.name = "Liaison%d_%s" % [n, nom]
			var cone: Array = CONES[nom]
			joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(float(cone[0])))
			joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(float(cone[1])))
			_monde.add_child(joint)
			r.joints[nom] = joint
		_reserve.append(r)


func _corps(rig: Skeleton3D, echelle: float, nom: String, nom_noeud: String) -> Dictionary:
	var os_id := rig.find_bone(nom)
	if os_id < 0:
		return {}
	var bout := str(BOUTS.get(nom, ""))
	var vers := Vector3.UP
	var longueur := TETE
	if not bout.is_empty() and rig.find_bone(bout) >= 0:
		vers = rig.get_bone_rest(rig.find_bone(bout)).origin
		longueur = vers.length() * echelle
	if longueur < 0.02:
		return {}
	var dir := vers.normalized()
	var spec: Array = CORPS[nom]
	var corps := RigidBody3D.new()
	corps.name = nom_noeud.validate_node_name()
	corps.mass = float(spec[1])
	corps.linear_damp = AMORTI
	corps.angular_damp = AMORTI * 2.0
	# Rangé : figé STATIQUE (un corps cinématique déplacé d'un bond prendrait la vitesse du bond).
	corps.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	corps.freeze = true
	corps.collision_layer = 0
	corps.collision_mask = 0
	corps.can_sleep = false
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(spec[0])
	capsule.height = maxf(longueur, capsule.radius * 2.0 + 0.01)
	var forme := CollisionShape3D.new()
	forme.shape = capsule
	# Capsule (axe Y) alignée sur l'os.
	forme.basis = Basis(Quaternion(Vector3.UP, dir)) if not dir.is_equal_approx(Vector3.UP) else Basis.IDENTITY
	corps.add_child(forme)
	corps.position = PARKING
	_monde.add_child(corps)
	# Corps au milieu de l'os, dans le repère (orthonormé) de l'os.
	return {"corps": corps, "decal": Transform3D(Basis.IDENTITY, dir * longueur * 0.5)}


## Plaquage transmis : le haut du corps de `id` part dans `direction` (monde, horizontale) ;
## `autre` (le plaqueur, s'il est connu) : la physique ne doit pas faire entrer le porteur en lui.
func declencher(id: String, direction: Vector3, autre: String = "") -> void:
	if not actif or not view._actors.has(id):
		return
	var entry: Dictionary = view._actors[id]
	var rig: Skeleton3D = entry.rig
	if rig == null or not rig.is_inside_tree() or rig.find_bone(ANCRE) < 0:
		return
	preparer(rig)
	if _reserve.is_empty():
		return
	# Même joueur déjà en chute : on repart de lui ; sinon un squelette libre, ou le plus avancé.
	var r: Dictionary = {}
	for x: Dictionary in _reserve:
		if x.id == id:
			r = x
	if r.is_empty():
		for x: Dictionary in _reserve:
			if x.id.is_empty():
				r = x
				break
	if r.is_empty():
		r = _reserve[0]
		for x: Dictionary in _reserve:
			if float(x.get("t", 0.0)) > float(r.get("t", 0.0)):
				r = x
	_liberer(r)
	r.id = id
	r.autre = autre if view._actors.has(autre) and view._actors[autre].rig != null else ""
	r.t = 0.0
	var actor: Node3D = entry.node
	var d := Vector3(direction.x, 0.0, direction.z)
	d = d.normalized() if d.length() > 0.001 else Vector3.ZERO
	var elan: Vector3 = actor.global_basis.z.normalized() * float(entry.get("allure", 0.0))
	# Corps posés (encore statiques : téléportés, sans vitesse) sur la pose animée courante, puis
	# l'ancre devient cinématique (elle suit l'animation) et les autres dynamiques.
	for nom: String in r.corps:
		var corps: RigidBody3D = r.corps[nom]
		_placer(corps, _monde_os(rig, nom) * (r.decal[nom] as Transform3D))
		corps.collision_layer = CALQUE_OS
		corps.collision_mask = CALQUE_SOL
		if nom == ANCRE:
			corps.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		else:
			corps.freeze = false
			corps.linear_velocity = elan + d * IMPULSION
			corps.angular_velocity = Vector3.ZERO
	# Liaisons recalculées sur la pose courante : cône centré sur l'animation, à l'origine de l'os.
	for nom: String in r.joints:
		var joint: Joint3D = r.joints[nom]
		var a: RigidBody3D = r.corps[PARENTS[nom]]
		var b: RigidBody3D = r.corps[nom]
		var origine := _monde_os(rig, nom)
		var x := (b.global_position - origine.origin).normalized()
		if x.length() < 0.5:
			x = Vector3.UP
		var y := x.cross(Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.global_transform = Transform3D(Basis(x, y, x.cross(y).normalized()), origine.origin)
		joint.node_a = joint.get_path_to(a)
		joint.node_b = joint.get_path_to(b)
	declenchements += 1


## Chute en cours : id -> temps écoulé (sondes et tests).
func actifs() -> Dictionary:
	var vus := {}
	for r: Dictionary in _reserve:
		if not r.id.is_empty():
			vus[r.id] = float(r.t)
	return vus


## Début d'image (boucle des joueurs de la vue, avec les autres retraits de poses) : rotations
## d'origine remises.
func restaurer(id: String, entry: Dictionary) -> void:
	if not _origines.has(id):
		return
	var rig: Skeleton3D = entry.rig
	if rig != null:
		var origines: Dictionary = _origines[id]
		for os_id: int in origines:
			rig.set_bone_pose_rotation(os_id, origines[os_id])
	_origines.erase(id)


## Après l'animation et les poses procédurales de l'image, avant le ballon : avance la chute et
## pose les rotations simulées (temps de la vue, ralenti compris).
func poser(delta: float) -> void:
	for r: Dictionary in _reserve:
		if r.id.is_empty():
			continue
		if not view._actors.has(r.id) or view._actors[r.id].rig == null:
			_liberer(r)
			continue
		var rig: Skeleton3D = view._actors[r.id].rig
		var gel: bool = view._paused
		for nom: String in r.corps:
			if nom != ANCRE:
				(r.corps[nom] as RigidBody3D).freeze = gel
		# Ancre : la pose animée de cette image (corps cinématique).
		_placer(r.corps[ANCRE], _monde_os(rig, ANCRE) * (r.decal[ANCRE] as Transform3D))
		# Garde-fou : un corps parti loin de sa place animée (liaison rompue) rend l'animation.
		var rompu := false
		for nom: String in SIMULES:
			var corps: RigidBody3D = r.corps.get(nom)
			if corps != null and corps.global_position.distance_to((_monde_os(rig, nom) * (r.decal[nom] as Transform3D)).origin) > ECART_MAX:
				rompu = true
		if rompu:
			ruptures += 1
			_liberer(r)
			continue
		if not gel:
			r.t = float(r.t) + delta
		var t: float = r.t
		if t >= DUREE:
			_liberer(r)
			continue
		var poids := smoothstep(0.0, MONTEE, t) * (1.0 - smoothstep(TENUE, DUREE, t)) * INFLUENCE
		_appliquer(r, rig, poids)


func annuler() -> void:
	for r: Dictionary in _reserve:
		if not r.id.is_empty():
			_liberer(r)
	for id: String in _origines.keys():
		if view._actors.has(id):
			restaurer(id, view._actors[id])
	_origines.clear()


func _appliquer(r: Dictionary, rig: Skeleton3D, poids: float) -> void:
	var origines: Dictionary = {}
	var voulus: Dictionary = {}
	var repere := rig.global_basis.orthonormalized().inverse()
	for nom: String in SIMULES:
		var os_id := rig.find_bone(nom)
		var corps: RigidBody3D = r.corps.get(nom)
		if os_id < 0 or corps == null:
			continue
		origines[os_id] = rig.get_bone_pose_rotation(os_id)
		voulus[os_id] = (repere * (corps.global_basis * (r.decal[nom] as Transform3D).basis.inverse())).get_rotation_quaternion()
	if origines.is_empty():
		return
	_origines[r.id] = origines
	var controle := _points_controle(rig)
	var plancher := minf(_plus_bas(rig, controle), SOL_MARGE)
	var autre: Skeleton3D = view._actors[r.autre].rig if not r.autre.is_empty() and view._actors.has(r.autre) else null
	var recouvrement := maxf(_penetration(rig, autre), 0.0) + RECOUVREMENT_TOLERE if autre != null else INF
	var w := poids
	for essai in BUTOIR_ESSAIS + 1:
		if essai == BUTOIR_ESSAIS:
			w = 0.0
		for os_id: int in voulus:
			var parent := rig.get_bone_parent(os_id)
			var parent_rot := rig.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
			var physique := (parent_rot.inverse() * (voulus[os_id] as Quaternion)).normalized()
			rig.set_bone_pose_rotation(os_id, (origines[os_id] as Quaternion).slerp(physique, w).normalized())
		if w <= 0.0 or (_plus_bas(rig, controle) >= plancher - 0.001 and (autre == null or _penetration(rig, autre) <= recouvrement)):
			break
		butoirs += 1
		w *= 0.5


## Recouvrement (m) des bustes et têtes des deux joueurs : volumes [os de départ, os d'arrivée ou
## longueur, rayon]. La physique ne doit jamais l'augmenter de plus de RECOUVREMENT_TOLERE.
static func _penetration(r1: Skeleton3D, r2: Skeleton3D) -> float:
	var pire := -INF
	var s1 := _volumes(r1)
	var s2 := _volumes(r2)
	for a: Array in s1:
		for b: Array in s2:
			var p := Geometry3D.get_closest_points_between_segments(a[0], a[1], b[0], b[1])
			pire = maxf(pire, float(a[2]) + float(b[2]) - (p[0] as Vector3).distance_to(p[1]))
	return pire


static func _volumes(rig: Skeleton3D) -> Array:
	var g := rig.global_transform
	var tete := g * rig.get_bone_global_pose(rig.find_bone("Head"))
	return [[(g * rig.get_bone_global_pose(rig.find_bone("Abdomen"))).origin, (g * rig.get_bone_global_pose(rig.find_bone("Neck"))).origin, 0.16],
		[tete.origin, tete.origin + tete.basis.y.normalized() * TETE, 0.1]]


## Os contrôlés par le butoir : tous les descendants de l'abdomen (buste, cou, tête, épaules, bras,
## mains, doigts).
func _points_controle(rig: Skeleton3D) -> PackedInt32Array:
	var liste := PackedInt32Array()
	var ancre := rig.find_bone(ANCRE)
	for i in rig.get_bone_count():
		var p := rig.get_bone_parent(i)
		while p >= 0 and p != ancre:
			p = rig.get_bone_parent(p)
		if p == ancre:
			liste.append(i)
	return liste


## Hauteur (m) du point le plus bas : os contrôlés et haut de la tête.
func _plus_bas(rig: Skeleton3D, controle: PackedInt32Array) -> float:
	var g := rig.global_transform
	var bas := INF
	var tete := rig.find_bone("Head")
	for i in controle:
		var pose := g * rig.get_bone_global_pose(i)
		bas = minf(bas, pose.origin.y)
		if i == tete:
			bas = minf(bas, (pose.origin + pose.basis.y.normalized() * TETE).y)
	return bas


func _liberer(r: Dictionary) -> void:
	r.id = ""
	r.autre = ""
	r.t = 0.0
	for groupe: String in ["corps"]:
		for nom: String in r[groupe]:
			var corps: RigidBody3D = r[groupe][nom]
			if not is_instance_valid(corps):
				continue
			corps.freeze = true
			corps.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			corps.collision_layer = 0
			corps.collision_mask = 0
			corps.linear_velocity = Vector3.ZERO
			corps.angular_velocity = Vector3.ZERO
			_placer(corps, Transform3D(Basis.IDENTITY, PARKING))


## Repère monde orthonormé d'un os (pose courante).
static func _monde_os(rig: Skeleton3D, nom: String) -> Transform3D:
	return (rig.global_transform * rig.get_bone_global_pose(rig.find_bone(nom))).orthonormalized()


## Place un corps tout de suite, côté nœud et côté serveur physique (les notifications de
## transformation des nœuds sont différées à la fin de l'image).
static func _placer(corps: RigidBody3D, repere: Transform3D) -> void:
	corps.global_transform = repere
	PhysicsServer3D.body_set_state(corps.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, repere)
