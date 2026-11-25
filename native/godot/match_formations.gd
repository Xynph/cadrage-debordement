extends RefCounted
## Formations des phases arrêtées dans la vue 3D : mêlée liée 3-4-1 et alignement de touche.
##
## Présentation seule : le moteur décide qui introduit, qui gagne et où part le ballon. Ici,
## les avants prennent la place et la posture de la phase que la scène annonce :
##   - « scrum » (loi 19) : les deux paquets liés face à face en 3-4-1 autour du ballon, penchés,
##     le demi de mêlée qui introduit accroupi au tunnel côté caméra, le demi adverse de son côté du ballon
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
## Demi de mêlée qui introduit : à côté du tunnel, hors du paquet, à 1,8 m de la marque, décalé de
## DEMI_INTRO.x m vers son propre paquet. 19 novembre 2026 : à 0,15 m, droit derrière le ballon, son
## dos et sa tête penchés cachaient le ballon tenu bas à la caméra TV (qui plonge de 24° et plus
## depuis la touche proche) ; décalé de 0,35 m, le ballon (ramené vers la ligne du tunnel, voir
## BALLON_TUNNEL) se voit à côté de son épaule.
const DEMI_INTRO := Vector2(0.35, -1.8)
## Côté de l'introduction (signe en y de la scène) : le demi introduit du côté de la mêlée de son choix
## (loi 19) ; il le fait toujours du côté de la caméra TV (touche proche, y croissants). 19/11/2026 :
## introduit côté tribune opposée, le ballon tenu bas restait caché derrière les deux paquets.
const COTE_INTRO := 1.0
## Ballon de l'introduction, dans le repère du demi : DEVANT m devant lui, à hauteur de genoux
## (bornée entre BAS_MIN et BAS_MAX m).
const BALLON_DEVANT := 0.55
const BALLON_BAS_MIN := 0.3
const BALLON_BAS_MAX := 0.6
## 19 novembre 2026 : le ballon tenu glisse de BALLON_TUNNEL m au plus sur le côté du demi, vers la
## ligne médiane de la mêlée (le tunnel) : hors de l'aplomb de son buste, visible depuis la caméra TV.
const BALLON_TUNNEL := 0.3
## Demi adverse : de son côté du ballon (recul négatif), du même côté de la mêlée, nettement à
## l'extérieur des paquets (18/11/2026 soir : à 1,35 m du centre, à demi penché contre le pilier
## droit adverse, il passait à l'image pour un avant resté debout dans le paquet).
const DEMI_ADVERSE := Vector2(-0.6, -2.4)
## Écart latéral minimal (m) entre le demi adverse et l'avant le plus à l'extérieur.
const DEMI_HORS_PAQUET := 0.8
## Sortie de mêlée (19/11/2026) : le demi du camp qui gagne le ballon le ramasse au pied de son n° 8,
## côté caméra : [recul derrière les pieds du n° 8, écart vers la caméra], en mètres. Il porte le
## ballon pendant la sortie, sauf si le moteur désigne un avant du paquet (n° 8 qui se détache).
## Avant : le ballon partait seul vers le point du fait (5 à 11 m plus loin que la mêlée, « avance »)
## et restait posé sur l'herbe, loin de tout joueur, quand le porteur désigné était un arrière
## éloigné (ou absent).
const DEMI_SORTIE := Vector2(0.9, 0.9)
## N° 8 qui se détache avec le ballon (25/11/2026, accord de Léo) : parti aussitôt vers sa place du
## moteur, droit devant, il traversait les deux paquets encore liés. Comme dans la réalité, il ramasse
## au pied de sa mêlée puis la contourne : d'abord sur le côté de son paquet (CONTOUR_COTE : [recul
## derrière le ballon, écart du centre]), tant que les paquets sont liés ; puis, déliés, il longe le
## paquet adverse jusqu'à CONTOUR_AVANT m devant le ballon, au même écart, avant de rejoindre sa course.
## Écart : flanker à 1,0 m + décalage des têtes, plus deux demi-largeurs d'épaules (≈ 0,9 m).
## Côté caméra (celui des deux demis, DEMI_ADVERSE à 2,4 m du centre), l'écart passe à CONTOUR_CAMERA m.
## Le côté est celui de sa course ; course droit devant : côté opposé à la caméra (loin des demis).
## Le contour cesse s'il n'a plus le ballon, s'il est pris dans un geste (plaquage…) ou après CONTOUR_MAX s.
const CONTOUR_COTE := Vector2(3.4, 2.3)
const CONTOUR_CAMERA := 3.4
const CONTOUR_AVANT := 4.2
const CONTOUR_MAX := 4.0
## Durée (s) depuis la sortie pendant laquelle personne ne traverse le n° 8 (bras compris).
const PROTEGE := 3.0
## Distance (m) sous laquelle un point de passage est atteint.
const CONTOUR_ATTEINT := 0.35
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
## Écart de cap (rad) sous lequel un joueur arrêté à sa place se lie (prend sa posture) : penché,
## sa tête est 1,1 m devant ses pieds ; à 0,05 rad elle dévie de 5 cm au plus, dans la marge de
## l'alternance des têtes (2 × DECALAGE_TETES moins deux rayons de tête : 11 cm à deux).
const FACE := 0.05
## À moins de EN_PLACE m de sa place, un joueur est arrêté (il se tourne vers le cap) ; arrivé, il se
## lie au plus tard après ATTENTE_MAX s.
const EN_PLACE := 0.05
const ATTENTE_MAX := 0.5
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
## Temps passé arrivé à sa place sans être lié (s), par joueur.
var _attente: Dictionary = {}
var _cibles_moteur: Dictionary = {}
var _saved: Dictionary = {}
## Contour du n° 8 détaché : {"id", "points": [Vector2 du terrain], "i", "temps"} (vide sinon). Il survit
## aux images suivantes du moteur : le n° 8 finit de contourner même si le fait d'après arrive.
var contour: Dictionary = {}
## N° 8 détaché que personne ne traverse, bras et jambes compris (match_plancher.gd `separer`,
## `entiers`), PROTEGE s depuis la sortie : {"id", "temps"} (vide sinon).
var protege: Dictionary = {}


## Joueurs que la séparation garde entiers (voir `protege`).
func entiers() -> Dictionary:
	return {} if protege.is_empty() else {str(protege.id): true}


func _init(owner: Node3D) -> void:
	view = owner


static func _vide() -> Dictionary:
	return {"type": "", "places": {}, "caps": {}, "postures": {}, "roles": {}, "porteur": ""}


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
	# Sortie : porteur du ballon pendant la sortie (avant détaché du paquet, sinon demi qui ramasse).
	f.porteur = ""
	for player: Dictionary in scene.get("players", []):
		var slot_porteur := int(player.get("slot", -1))
		if sortie and str(player.get("id", "")) == porteur and slot_porteur >= 0 and slot_porteur < 8:
			f.porteur = porteur
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		var side := int(player.get("side", -1))
		var slot := int(player.get("slot", -1))
		if id.is_empty() or side not in [0, 1] or slot < 0:
			continue
		# Sens de poussée du paquet : le camp 0 pousse vers les x croissants (scène du moteur).
		var s := 1.0 if side == 0 else -1.0
		if slot < 8:
			# Le joueur que le moteur désigne à la sortie (n° 8, talonneur…) se détache avec le ballon :
			# il contourne la mêlée (CONTOUR_COTE), jamais à travers les paquets.
			if sortie and id == porteur:
				var course := Vector2(float(player.get("x", centre.x)), float(player.get("y", centre.y)))
				var cote := signf(course.y - centre.y) if absf(course.y - centre.y) > 0.5 else -COTE_INTRO
				var ecart := CONTOUR_CAMERA if cote == COTE_INTRO else CONTOUR_COTE.y
				var flanc := centre + Vector2(-s * CONTOUR_COTE.x, cote * ecart)
				f.places[id] = flanc
				f.caps[id] = atan2(s, 0.0)
				f.roles[id] = "n8_sortie"
				f.contour = [flanc]
				var devant := centre + Vector2(s * CONTOUR_AVANT, cote * ecart)
				if _traverse(flanc, course, centre, ecart):
					f.contour.append(devant)
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
			# Côté de l'introduction : celui de la caméra (tribune principale, y croissants), quelle que
			# soit l'équipe ; le demi adverse se tient du même côté (voir COTE_INTRO).
			var place := centre + Vector2(-si * d.x, COTE_INTRO * absf(d.y))
			f.places[id] = place
			if side == introduit:
				# Tourné vers le tunnel : le ballon est introduit le long de la ligne médiane de la mêlée.
				f.caps[id] = atan2(0.0, -COTE_INTRO)
				f.postures[id] = "introduction"
				f.roles[id] = "demi_intro"
			else:
				f.caps[id] = atan2(centre.x - place.x, centre.y - place.y)
				f.postures[id] = "aguets"
				f.roles[id] = "demi_adverse"
		elif slot == 8 and sortie and side == possession:
			# Demi qui ramasse au pied du n° 8, côté caméra, tourné vers ses arrières.
			f.places[id] = centre + Vector2(-s * (MELEE[7].x + PIEDS_N8 + DEMI_SORTIE.x), COTE_INTRO * DEMI_SORTIE.y)
			f.caps[id] = atan2(-s, 0.0)
			f.roles[id] = "demi_sortie"
			if str(f.porteur).is_empty():
				f.porteur = id
		elif slot == 8 and sortie and introduit in [0, 1]:
			# Demi adverse : il reste à sa place, hors des paquets, tant qu'ils sont liés (25/11/2026 :
			# parti vers sa place de la scène dès l'annonce, il traversait son propre paquet penché).
			var si := 1.0 if introduit == 0 else -1.0
			var d: Vector2 = DEMI_INTRO if side == introduit else DEMI_ADVERSE
			var place := centre + Vector2(-si * d.x, COTE_INTRO * absf(d.y))
			f.places[id] = place
			f.caps[id] = atan2(centre.x - place.x, centre.y - place.y)
			f.roles[id] = "demi_adverse"
		elif not sortie and player.has("x") and player.has("y"):
			# Arrières : places du moteur, ramenées derrière la ligne de hors-jeu si besoin.
			var limite := MELEE[7].x + PIEDS_N8 + HORS_JEU
			var x := float(player.x)
			if (centre.x - x) * s < limite:
				f.places[id] = Vector2(centre.x - s * limite, float(player.y))
			f.roles[id] = "arriere"
	return f


## Vrai si le trajet `a` -> `b` passe dans l'emprise des deux paquets (CONTOUR_AVANT m de part et
## d'autre du ballon, moins de `ecart` − 0,4 m de l'axe de la mêlée).
static func _traverse(a: Vector2, b: Vector2, centre: Vector2, ecart: float) -> bool:
	for k in 21:
		var p := a.lerp(b, k / 20.0)
		if absf(p.x - centre.x) < CONTOUR_AVANT and absf(p.y - centre.y) < ecart - 0.4:
			return true
	return false


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
	if formation.has("contour"):
		contour = {"id": str(formation.porteur), "points": formation.contour, "i": 0, "temps": 0.0}
		protege = {"id": str(formation.porteur), "temps": 0.0}
	elif formation.type in ["melee", "touche"]:
		contour = {}
		protege = {}
	if formation.type == "melee":
		precedente = {"type": "melee", "centre": formation.centre, "introduit": formation.introduit}
	elif formation.type != "sortie_melee":
		precedente = {}


## Place du joueur dans la vue : celle de la formation, sinon celle du moteur.
func place(id: String, moteur: Vector3) -> Vector3:
	if not contour.is_empty() and id == str(contour.id):
		_cibles_moteur[id] = moteur
		return _terrain(contour.points[int(contour.i)])
	if libere or not formation.places.has(id):
		return moteur
	_cibles_moteur[id] = moteur
	var p: Vector2 = formation.places[id]
	return _terrain(p)


static func _terrain(p: Vector2) -> Vector3:
	return Vector3(p.x - 50.0, 0.0, p.y - 35.0)


func active() -> bool:
	return not str(formation.type).is_empty() and not libere


## Porteur du ballon montré pour cette image : à la sortie de mêlée, l'avant détaché ou le demi qui
## ramasse (DEMI_SORTIE), jamais un porteur éloigné vers qui le ballon partirait seul ; sinon
## `moteur`, le porteur de la scène. Fixé pour toute l'image : le demi garde le ballon en se replaçant.
func porteur(moteur: String) -> String:
	if str(formation.type) == "sortie_melee" and not str(formation.get("porteur", "")).is_empty():
		return str(formation.porteur)
	return moteur


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
			if not contour.is_empty() and id == str(contour.id):
				continue
			_viser(id, _cibles_moteur[id])
	_contourner(delta)


## N° 8 détaché : point de passage suivant dès que le précédent est atteint, puis sa course du moteur.
## 25/11/2026 (vérificateur) : il n'attend plus sur le flanc que les paquets se délient (1 s planté,
## ballon en main) ; il longe aussitôt le paquet adverse, encore lié donc immobile, à l'écart.
func _contourner(delta: float) -> void:
	if not protege.is_empty():
		protege.temps = float(protege.temps) + delta
		if float(protege.temps) >= PROTEGE or not view._actors.has(str(protege.id)):
			protege = {}
	if contour.is_empty():
		return
	var id := str(contour.id)
	contour.temps = float(contour.temps) + delta
	if not view._actors.has(id) or _mis_en_scene(id):
		contour = {}
		return
	var fini: bool = view._carrier_id != id or float(contour.temps) >= CONTOUR_MAX
	var entry: Dictionary = view._actors[id]
	var at: Vector3 = (entry.node as Node3D).position
	var vise := _terrain(contour.points[int(contour.i)])
	if not fini and Vector2(vise.x - at.x, vise.z - at.z).length() > CONTOUR_ATTEINT:
		return
	contour.i = int(contour.i) + 1
	if not fini and int(contour.i) < (contour.points as Array).size():
		_viser(id, _terrain(contour.points[int(contour.i)]))
		return
	contour = {}
	if _cibles_moteur.has(id):
		_viser(id, _cibles_moteur[id])


func _viser(id: String, cible: Vector3) -> void:
	var entry: Dictionary = view._actors[id]
	var at: Vector3 = (entry.node as Node3D).position
	entry.from = at
	entry.target = cible
	entry.duree = Motion.duree(at, cible)
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
		var arrete: bool = float(entry.elapsed) >= float(entry.duree) or Vector2(gap.x, gap.z).length() < EN_PLACE
		if actif and formation.caps.has(id) and arrete:
			var change := angle_difference(actor.rotation.y, float(formation.caps[id]))
			actor.rotation.y += clampf(change, -VIRAGE * delta, VIRAGE * delta)
		# 25/11/2026 (sonde des contacts du match filmé) : il ne se penche qu'une fois arrêté à sa place
		# et tourné vers l'adversaire ; penché de travers en arrivant, sa tête entrait dans celle d'en face.
		# Arrivé, il se lie au plus tard après ATTENTE_MAX s, même mal tourné (jamais de mêlée debout).
		var face: bool = not formation.caps.has(id) or absf(angle_difference(actor.rotation.y, float(formation.caps[id]))) < FACE
		var attente: float = float(_attente.get(id, 0.0)) + delta if arrive and not nom.is_empty() else 0.0
		_attente[id] = attente
		var lie: bool = not nom.is_empty() and arrive and ((arrete and face) or attente >= ATTENTE_MAX or float(_poids.get(id, 0.0)) > 0.0)
		var poids := move_toward(float(_poids.get(id, 0.0)), 1.0 if lie else 0.0, (delta / RAMPE) if not view._paused else 0.0)
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
	# Vers la ligne du tunnel (x du centre de la mêlée), sur le côté du demi : voir BALLON_TUNNEL.
	var centre: Variant = formation.get("centre")
	var droite := Vector3(actor.global_basis.x.x, 0.0, actor.global_basis.x.z)
	if centre is Vector2 and absf(droite.x) > 0.1:
		droite = droite.normalized()
		bas += droite * clampf((float(centre.x) - 50.0 - bas.x) / droite.x, -BALLON_TUNNEL, BALLON_TUNNEL)
	bas.y =clampf(genoux / n if n > 0 else BALLON_BAS_MIN, BALLON_BAS_MIN, BALLON_BAS_MAX)
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
