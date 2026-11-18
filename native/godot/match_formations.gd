extends RefCounted
## Formations des phases arrêtées dans la vue 3D : mêlée liée 3-4-1 et alignement de touche.
##
## Présentation seule : le moteur décide qui introduit, qui gagne et où part le ballon. Ici,
## les avants prennent la place et la posture de la phase que la scène annonce :
##   - « scrum » (loi 19) : les deux paquets liés face à face en 3-4-1 autour du ballon, penchés,
##     le demi de mêlée qui introduit accroupi au tunnel, le demi adverse de son côté du ballon
##     (à l'extérieur des paquets),
##     les arrières à 5 m au moins derrière les pieds du n° 8 ;
##   - « setpiece-win » / « setpiece-loss » juste après une mêlée : les deux paquets restent liés
##     SORTIE secondes (le ballon sort), puis se délient vers leurs places de la scène ;
##   - « lineout » (loi 18) : les places du moteur sont gardées (rangées à 1 m d'écart, lanceur
##     sur la ligne) ; chacun se tourne vers la touche, le lanceur vers le terrain. Le lancer et le
##     saut sont joués par match_gestes.gd (gestes complets, ou touche seule du direct).
## Les joueurs mis en scène ailleurs (gestes, chorégraphie, passe en direct) ne sont pas touchés.
## Valeurs de mise en scène choisies à l'œil sur le match filmé (18/11/2026), non mesurées.
##
## Têtes emboîtées (loi 19 : aucune tête à côté de celle d'un partenaire) : chaque paquet est
## décalé de DECALAGE_TETES vers la gauche de ses joueurs ; les six têtes des premières lignes
## alternent (pilier gauche à l'extérieur du pilier droit adverse), 2 × DECALAGE_TETES entre deux
## têtes adverses voisines, plus que deux rayons de tête (TETE_RAYON) : elles ne se traversent plus.
## Introduction : le demi accroupi tient le ballon bas, à hauteur de genoux, devant lui, à
## l'entrée du tunnel ; la vue lui laisse le ballon (tient_ballon).

const Presentation = preload("res://match_presentation.gd")
const Motion = preload("res://match_motion.gd")

## Mêlée, par poste (slot 0 = n° 1) : [recul des pieds derrière le ballon, décalage vers la
## droite du joueur], en mètres. Première ligne, deuxième ligne et flankers liés, n° 8 derrière.
## Premières lignes à 1,2 m du ballon (2,4 m entre les pieds) : penchés, leurs têtes arrivent à
## quelques centimètres de la ligne du ballon, épaules adverses 0,3 m en arrière.
const MELEE: Array[Vector2] = [
	Vector2(1.2, -0.62), Vector2(1.2, 0.0), Vector2(1.2, 0.62),
	Vector2(2.1, -0.32), Vector2(2.1, 0.32),
	Vector2(2.0, -1.0), Vector2(2.0, 1.0),
	Vector2(3.0, 0.0),
]
## Décalage de chaque paquet vers la gauche de ses joueurs (m) : têtes adverses en alternance.
const DECALAGE_TETES := 0.155
## Rayon de tête du modèle (m), pour l'écart minimal entre têtes adverses.
const TETE_RAYON := 0.11
## Demi de mêlée qui introduit : à côté du tunnel, du côté de son pilier gauche, hors du paquet
## (le pilier gauche décalé vers l'extérieur).
const DEMI_INTRO := Vector2(0.15, -1.8)
## Ballon de l'introduction, dans le repère du demi : DEVANT m devant lui, à hauteur de genoux
## (bornée entre BAS_MIN et BAS_MAX m).
const BALLON_DEVANT := 0.55
const BALLON_BAS_MIN := 0.3
const BALLON_BAS_MAX := 0.6
## Demi adverse : de son côté du ballon (recul négatif), du même côté de la mêlée, nettement à
## l'extérieur des paquets (18/11/2026 soir : à 1,35 m du centre, à demi penché contre le pilier
## droit adverse, il passait à l'image pour un avant resté debout dans le paquet).
const DEMI_ADVERSE := Vector2(-0.6, -2.4)
## Écart latéral minimal (m) entre le demi adverse et l'avant le plus à l'extérieur.
const DEMI_HORS_PAQUET := 0.8
## Hors-jeu de mêlée (loi 19) : arrières à 5 m au moins derrière les pieds du dernier avant.
const HORS_JEU := 5.0
const PIEDS_N8 := 0.6
## Postures : [inclinaison du corps (rad), abaissement (m), flexion du buste (rad)].
const POSTURES := {
	"premiere_ligne": [0.55, -0.08, 0.8],
	"poussee": [0.5, -0.06, 0.7],
	# Demi accroupi (bassin vers 0,45 m), buste penché sur le ballon tenu bas.
	"introduction": [0.35, -0.28, 0.6],
	"aguets": [0.3, -0.1, 0.45],
}
## Sortie de mêlée : les paquets restent liés ce temps après l'annonce du ballon gagné.
const SORTIE := 1.0
## Sortie de mêlée reconnue si le ballon gagné part à moins de cette distance (m) de la mêlée.
const SORTIE_RAYON := 6.0
## Entrée et sortie de posture, en secondes.
const RAMPE := 0.4
## Distance (m) à sa place sous laquelle un joueur se lie.
const ARRIVE := 0.6
## Rotation vers le cap de la phase, à l'arrêt (rad/s).
const VIRAGE := 6.0
const ARMS := ["UpperArm.L", "LowerArm.L", "Palm.L", "UpperArm.R", "LowerArm.R", "Palm.R"]
const LEGS := ["UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R"]

var view
var formation: Dictionary = _vide()
## Dernière mêlée formée (centre et équipe qui introduit), pour reconnaître sa sortie.
var precedente: Dictionary = {}
var temps := 0.0
var libere := false
var _poids: Dictionary = {}
var _posture: Dictionary = {}
var _cibles_moteur: Dictionary = {}
var _saved: Dictionary = {}


func _init(owner: Node3D) -> void:
	view = owner


static func _vide() -> Dictionary:
	return {"type": "", "places": {}, "caps": {}, "postures": {}, "roles": {}}


## Formation d'une scène du moteur, en coordonnées du terrain (x 0-100, y 0-70) :
## {"type", "places": {id: Vector2}, "caps": {id: lacet}, "postures": {id: nom}, "roles": {id: rôle}}.
## `avant` : {"type": "melee", "centre": Vector2, "introduit": camp} de la mêlée qui précède.
static func calculer(scene: Dictionary, avant: Dictionary = {}) -> Dictionary:
	var ball: Variant = scene.get("ball")
	if not ball is Dictionary or not (ball as Dictionary).has("x") or not (ball as Dictionary).has("y"):
		return _vide()
	var kind := str(scene.get("kind", ""))
	var point := Vector2(float(ball.x), float(ball.y))
	if kind == "scrum":
		return _melee(scene, point, int(scene.get("possession", -1)), false)
	if kind in ["setpiece-win", "setpiece-loss"] and str(avant.get("type", "")) == "melee":
		var origin: Variant = scene.get("origin")
		var depart := Vector2(float(origin.x), float(origin.y)) if origin is Dictionary and origin.has("x") and origin.has("y") else point
		var centre: Vector2 = avant.centre
		if depart.distance_to(centre) <= SORTIE_RAYON:
			return _melee(scene, centre, int(avant.get("introduit", -1)), true)
	if kind == "lineout":
		return _touche(scene, point)
	return _vide()


static func _melee(scene: Dictionary, centre: Vector2, introduit: int, sortie: bool) -> Dictionary:
	var f := _vide()
	f.type = "sortie_melee" if sortie else "melee"
	f.centre = centre
	f.introduit = introduit
	var possession := int(scene.get("possession", -1))
	var porteur := ""
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == possession:
			porteur = str(player.get("id", ""))
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		var side := int(player.get("side", -1))
		var slot := int(player.get("slot", -1))
		if id.is_empty() or side not in [0, 1] or slot < 0:
			continue
		# Sens de poussée du paquet : le camp 0 pousse vers les x croissants (scène du moteur).
		var s := 1.0 if side == 0 else -1.0
		if slot < 8:
			# Le joueur que le moteur désigne à la sortie (n° 8, talonneur…) se détache avec le ballon.
			if sortie and id == porteur:
				continue
			var m: Vector2 = MELEE[slot]
			# Paquet décalé vers la gauche de ses joueurs : têtes adverses emboîtées en alternance.
			f.places[id] = centre + Vector2(-s * m.x, s * (m.y - DECALAGE_TETES))
			f.caps[id] = atan2(s, 0.0)
			f.postures[id] = "premiere_ligne" if slot < 3 else "poussee"
			f.roles[id] = "pack"
		elif slot == 8 and not sortie and introduit in [0, 1]:
			var si := 1.0 if introduit == 0 else -1.0
			var d: Vector2 = DEMI_INTRO if side == introduit else DEMI_ADVERSE
			var place := centre + Vector2(-si * d.x, si * d.y)
			f.places[id] = place
			if side == introduit:
				# Tourné vers le tunnel : le ballon est introduit le long de la ligne médiane de la mêlée.
				f.caps[id] = atan2(0.0, si)
				f.postures[id] = "introduction"
				f.roles[id] = "demi_intro"
			else:
				f.caps[id] = atan2(centre.x - place.x, centre.y - place.y)
				f.postures[id] = "aguets"
				f.roles[id] = "demi_adverse"
		elif not sortie and player.has("x") and player.has("y"):
			# Arrières : places du moteur, ramenées derrière la ligne de hors-jeu si besoin.
			var limite := MELEE[7].x + PIEDS_N8 + HORS_JEU
			var x := float(player.x)
			if (centre.x - x) * s < limite:
				f.places[id] = Vector2(centre.x - s * limite, float(player.y))
			f.roles[id] = "arriere"
	return f


static func _touche(scene: Dictionary, marque: Vector2) -> Dictionary:
	var f := _vide()
	f.type = "touche"
	# Côté de la touche où le ballon est remis en jeu : la ligne y = 0 ou y = 70.
	var cote := -1.0 if marque.y < 35.0 else 1.0
	var ligne := 0.0 if cote < 0.0 else 70.0
	var lanceur := ""
	var proche := INF
	for player: Dictionary in scene.get("players", []):
		if int(player.get("slot", -1)) == 1 and player.has("y"):
			var d := absf(float(player.y) - ligne)
			if d < proche:
				proche = d
				lanceur = str(player.get("id", ""))
	var camp_lanceur := -1
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		var slot := int(player.get("slot", -1))
		if id.is_empty() or not player.has("x") or not player.has("y"):
			continue
		var x := float(player.x)
		var y := float(player.y)
		if id == lanceur:
			camp_lanceur = int(player.get("side", -1))
			f.caps[id] = atan2(0.0, -cote)
			f.roles[id] = "lanceur"
		elif slot < 8 and absf(x - marque.x) < 3.0 and absf(y - ligne) <= 16.0:
			f.caps[id] = atan2(0.0, cote)
			f.roles[id] = "alignement"
		else:
			# Demi et non-participants regardent l'alignement.
			var centre := Vector2(marque.x, ligne - cote * 10.0)
			f.caps[id] = atan2(centre.x - x, centre.y - y)
			f.roles[id] = "demi" if slot == 8 else "hors_alignement"
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		if int(player.get("side", -1)) == camp_lanceur and f.roles.get(id, "") == "alignement" and int(player.get("slot", -1)) == 4:
			f.roles[id] = "sauteur"
	return f


## Nouvelle image du moteur : formation de cette scène (au premier passage d'un fait seulement).
func preparer(scene: Dictionary, nouvelle: bool) -> void:
	if not nouvelle:
		return
	formation = calculer(scene, precedente)
	temps = 0.0
	libere = false
	_cibles_moteur.clear()
	if formation.type == "melee":
		precedente = {"type": "melee", "centre": formation.centre, "introduit": formation.introduit}
	elif formation.type != "sortie_melee":
		precedente = {}


## Place du joueur dans la vue : celle de la formation, sinon celle du moteur.
func place(id: String, moteur: Vector3) -> Vector3:
	if libere or not formation.places.has(id):
		return moteur
	_cibles_moteur[id] = moteur
	var p: Vector2 = formation.places[id]
	return Vector3(p.x - 50.0, 0.0, p.y - 35.0)


func active() -> bool:
	return not str(formation.type).is_empty() and not libere


func _mis_en_scene(id: String) -> bool:
	return (view.mise_en_scene().stages(id) or (view._choregraphie != null and view._choregraphie.stages(id))
		or view._is_pass_player(id) or not (view._actors[id].get("geste", {}) as Dictionary).is_empty()
		or (view.get("_impacts") != null and view._impacts.occupe(id)))


## Temps de la formation ; à la fin de la sortie de mêlée, les avants rejoignent leurs places de la scène.
func avancer(delta: float) -> void:
	if view._paused:
		return
	temps += delta
	if formation.type == "sortie_melee" and not libere and temps >= SORTIE:
		libere = true
		for id: String in _cibles_moteur:
			if not view._actors.has(id) or _mis_en_scene(id):
				continue
			var entry: Dictionary = view._actors[id]
			var at: Vector3 = (entry.node as Node3D).position
			entry.from = at
			entry.target = _cibles_moteur[id]
			entry.duree = Motion.duree(at, entry.target)
			entry.elapsed = 0.0
			entry.tangent = Vector3.ZERO
			entry.velocity = Vector3.ZERO


## Rend le squelette et le modèle d'avant la posture (avant la nouvelle animation de l'image).
func restaurer(id: String, entry: Dictionary) -> void:
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


## Postures et caps de la formation ; appelé après l'animation source, avant les prises du ballon.
func poser(delta: float) -> void:
	for id: String in _poids.keys():
		if not view._actors.has(id):
			_poids.erase(id)
			_posture.erase(id)
	var actif := active()
	for id: String in view._actors:
		var entry: Dictionary = view._actors[id]
		if not is_instance_valid(entry.rig) or _mis_en_scene(id):
			_poids.erase(id)
			continue
		var actor: Node3D = entry.node
		var nom := str(formation.postures.get(id, "")) if actif else ""
		var gap: Vector3 = entry.target - actor.position
		var arrive := Vector2(gap.x, gap.z).length() < ARRIVE
		var poids := move_toward(float(_poids.get(id, 0.0)), 1.0 if not nom.is_empty() and arrive else 0.0, (delta / RAMPE) if not view._paused else 0.0)
		if actif and formation.caps.has(id) and float(entry.elapsed) >= float(entry.duree):
			var change := angle_difference(actor.rotation.y, float(formation.caps[id]))
			actor.rotation.y += clampf(change, -VIRAGE * delta, VIRAGE * delta)
		if not nom.is_empty():
			_posture[id] = nom
		if poids <= 0.0:
			_poids.erase(id)
			_posture.erase(id)
			continue
		_poids[id] = poids
		_appliquer(id, entry, str(_posture[id]), smoothstep(0.0, 1.0, poids))
		if tient_ballon(id):
			_tenir_ballon(entry, smoothstep(0.0, 1.0, poids))


## Le demi qui introduit tient le ballon bas lui-même (la vue ne le lui remet pas sur la poitrine).
func tient_ballon(id: String) -> bool:
	return (active() and formation.type == "melee" and str(formation.roles.get(id, "")) == "demi_intro"
		and view._carrier_id == id and view._ball.visible and float(_poids.get(id, 0.0)) > 0.0
		and str(_posture.get(id, "")) == "introduction" and not _mis_en_scene(id)
		and not view.choregraphie_active())


## Ballon de l'introduction : à deux mains, devant le demi accroupi, à hauteur de ses genoux.
func _tenir_ballon(entry: Dictionary, w: float) -> void:
	var actor: Node3D = entry.node
	var rig: Skeleton3D = entry.rig
	var genoux := 0.0
	var n := 0
	for leg in ["L", "R"]:
		var knee := rig.find_bone("LowerLeg." + leg)
		if knee >= 0:
			genoux += rig.to_global(rig.get_bone_global_pose(knee).origin).y
			n += 1
	var bas := actor.global_position + actor.global_basis.z.normalized() * BALLON_DEVANT
	bas.y = clampf(genoux / n if n > 0 else BALLON_BAS_MIN, BALLON_BAS_MIN, BALLON_BAS_MAX)
	var ball: Node3D = view._ball
	ball.global_position = ball.global_position.lerp(bas, w)
	# Grand axe dans l'axe du tunnel, comme le ballon est introduit.
	ball.global_basis = ball.global_basis.orthonormalized().slerp(actor.global_basis.orthonormalized(), w)
	Presentation.hold_ball(actor, rig, ball.global_position, w)


func _appliquer(id: String, entry: Dictionary, nom: String, w: float) -> void:
	var p: Array = POSTURES.get(nom, [0.0, 0.0, 0.0])
	var actor: Node3D = entry.node
	var rig: Skeleton3D = entry.rig
	_garder(id, entry, ARMS + LEGS + ["Abdomen", "Torso"])
	var model: Node3D = entry.model
	model.transform = _saved[id].model
	model.rotation.x = float(p[0]) * w
	model.position.y += float(p[1]) * w
	# Buste fléchi vers l'avant (dos plat de la poussée).
	var axe := (rig.global_basis.inverse() * actor.global_basis.x).normalized()
	for bone in ["Abdomen", "Torso"]:
		var index := rig.find_bone(bone)
		if index >= 0:
			Presentation._orient(rig, index, Basis(Quaternion(axe, float(p[2]) * w * 0.5)) * rig.get_bone_global_pose(index).basis, 1.0)
	# Appuis plantés derrière le bassin, genoux fléchis : les pieds restent sur la pelouse.
	var avant := actor.global_basis.z.normalized()
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
		var longueur := hip.distance_to(knee) + knee.distance_to(source)
		var hauteur := maxf(hip.y - 0.025, 0.1)
		var recul := sqrt(maxf(0.0, pow(longueur * 0.9, 2.0) - hauteur * hauteur)) * (0.8 if nom in ["premiere_ligne", "poussee"] else 0.4)
		var hanche := actor.to_local(hip)
		var plante := actor.to_global(Vector3(sign_ * 0.17, 0.0, hanche.z - recul))
		plante.y = 0.025
		Presentation._solve_leg(rig, leg, source.lerp(plante, w), avant)
	# Bras liés : vers l'avant et vers le bas (maillot du partenaire ou de l'adversaire).
	if nom in ["premiere_ligne", "poussee"]:
		var poitrine := Presentation.ball_anchor(actor, rig)
		var cote := actor.global_basis.x.normalized()
		var vise := poitrine + avant * 0.36 + Vector3.DOWN * 0.1
		for arm in ["L", "R"]:
			var sign_ := 1.0 if arm == "L" else -1.0
			Presentation._solve_arm(rig, arm, vise + cote * sign_ * 0.32, actor.global_basis * Vector3(sign_ * 0.7, -0.8, -0.15), w)


func _garder(id: String, entry: Dictionary, names: Array) -> void:
	if not _saved.has(id):
		_saved[id] = {"model": (entry.model as Node3D).transform, "bones": {}, "places": {}}
	var rig: Skeleton3D = entry.rig
	for bone: String in names:
		var index := rig.find_bone(bone)
		if index >= 0 and not _saved[id].bones.has(index):
			_saved[id].bones[index] = rig.get_bone_pose_rotation(index)
			_saved[id].places[index] = rig.get_bone_pose_position(index)


## Posture en cours d'un joueur (pour les contrôles) : [nom, poids].
func posture_de(id: String) -> Array:
	return [str(_posture.get(id, "")), float(_poids.get(id, 0.0))]
