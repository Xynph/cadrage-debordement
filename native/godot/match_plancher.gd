extends RefCounted
## Plancher des joueurs (Léo, 24/11/2026 : « attention aux joueurs qui traversent le terrain »).
##
## Dernière pose de chaque image, pour chaque joueur : si une partie du corps passe sous la
## pelouse (y = 0, marges ci-dessous), elle est relevée au plus juste, sans toucher la racine :
##   - bras, tête, jambes : rotation de l'os pivot le plus proche dont l'origine est au-dessus du
##     sol (coude ou épaule, cou ou buste, genou ou hanche), dans le plan vertical, juste assez ;
##   - pied (os indépendant du rig) : remonté ;
##   - bassin, buste ou hanches eux-mêmes sous la marge : le modèle (pas la racine) est remonté ;
##   - joueur au sol dont un os resterait sous la pelouse (bras coincé sous le corps) : le modèle
##     est remonté juste assez.
## Dégagement (25/11/2026, défaut du ruck : jambes d'un soutien dans le porteur couché) : après le
## plancher, un joueur debout dont une jambe entre dans le corps d'un joueur couché a son modèle
## (pas sa racine) écarté à l'horizontale juste assez ; l'écart revient doucement à zéro.
## Retiré au début de l'image suivante (`restaurer`), comme les autres poses de présentation.
## Présentation seule : aucune place, aucun cap ni résultat ne change.

## Marges (m) au-dessus de la pelouse : extrémités (doigts, haut de la tête), articulations, tronc.
const MARGE_BOUT := 0.025
const MARGE_ARTICULATION := 0.035
const MARGE_PIED := 0.03
## Haut de la tête : à cette distance (m) de l'origine de l'os Head, le long de son axe.
const TETE := 0.2
## Chaînes : [pivots du plus proche au plus éloigné de l'extrémité], [points contrôlés].
const CHAINES := [
	[["LowerArm.L", "UpperArm.L", "Shoulder.L"], ["Fingers.L", "Thumb2.L", "MiddleHand.L", "Palm.L", "LowerArm.L"]],
	[["LowerArm.R", "UpperArm.R", "Shoulder.R"], ["Fingers.R", "Thumb2.R", "MiddleHand.R", "Palm.R", "LowerArm.R"]],
	[["Neck", "Torso"], ["Head", "Neck"]],
	[["LowerLeg.L", "UpperLeg.L"], ["LowerLeg.L"]],
	[["LowerLeg.R", "UpperLeg.R"], ["LowerLeg.R"]],
]
## Tronc et hanches : os -> marge (m) ; en dessous, le modèle est remonté.
const TRONC := {"Hips": 0.09, "Abdomen": 0.09, "Torso": 0.09, "Neck": 0.09, "UpperLeg.L": 0.035, "UpperLeg.R": 0.035}
const EXCLUS := ["Bone", "PoleTarget.L", "PoleTarget.R"]
## Dernier recours, joueur bas seulement (bassin sous BAS m) : si un os reste sous la pelouse
## (bras coincé sous le corps…), le modèle est remonté juste assez.
const BAS := 0.6
const PLANCHER := 0.002
const PIEDS := ["Foot.L", "Foot.R"]
## Passes au plus par chaîne (un pivot relevé peut laisser un point plus loin sous le sol).
const PASSES := 3
## Dégagement : joueur couché (buste sous COUCHE m), volumes capsules [os, os d'arrivée ou longueur
## le long de l'axe, rayon] du corps couché et des jambes debout, jeu laissé (m), portée (m) entre
## racines, retour de l'écart (m/s), passes au plus par joueur.
const COUCHE := 0.45
const CORPS_COUCHE := [["Hips", "Abdomen", 0.13], ["Abdomen", "Torso", 0.14], ["Torso", "Neck", 0.14], ["Head", 0.22, 0.1],
	["UpperLeg.L", "LowerLeg.L", 0.08], ["UpperLeg.R", "LowerLeg.R", 0.08], ["LowerLeg.L", "Foot.L", 0.06], ["LowerLeg.R", "Foot.R", 0.06],
	["UpperArm.L", "LowerArm.L", 0.06], ["UpperArm.R", "LowerArm.R", 0.06], ["LowerArm.L", "Palm.L", 0.05], ["LowerArm.R", "Palm.R", 0.05]]
const JAMBES_DEBOUT := [["UpperLeg.L", "LowerLeg.L", 0.08], ["UpperLeg.R", "LowerLeg.R", 0.08], ["LowerLeg.L", "Foot.L", 0.06],
	["LowerLeg.R", "Foot.R", 0.06], ["Foot.L", 0.16, 0.045], ["Foot.R", 0.16, 0.045]]
const JEU := 0.025
const PORTEE := 3.0
const RETOUR := 1.2
const PASSES_DEGAGEMENT := 6
const PRISE := 0.25
## Séparation des joueurs debout : volumes (tronc, tête, cuisses ; bras exclus), jeu laissé (m),
## portée (m) entre racines, passes au plus.
const TRONC_DEBOUT := [["Hips", "Abdomen", 0.13], ["Abdomen", "Torso", 0.14], ["Torso", "Neck", 0.14], ["Head", 0.22, 0.1],
	["UpperLeg.L", "LowerLeg.L", 0.08], ["UpperLeg.R", "LowerLeg.R", 0.08]]
const JEU_DEBOUT := 0.01
## 25/11/2026 : 2,6 m (comme la sonde des contacts) au lieu de 1,8 m : penché en mêlée, un avant a la
## tête 1,1 m devant ses pieds ; à 1,8 m, le demi qui se tourne contre un flanker n'était pas vu.
const PORTEE_DEBOUT := 2.6
const PASSES_SEPARATION := 4

## id -> {"rotations": {os: Quaternion}, "positions": {os: Vector3}, "y": float}
var _origines: Dictionary = {}
## id -> écart horizontal du modèle (monde) appliqué à l'image précédente (dégagement).
var _ecarts: Dictionary = {}
## id -> écart horizontal du modèle (monde) de la séparation des joueurs debout.
var _separations: Dictionary = {}
## Part de l'écart du porteur suivie par le ballon tenu (0 à la prise, 1 après PRISE s).
var _poids_ballon := 0.0
## Corrections faites (tests, mesures).
var corrections := 0


## Début d'image : poses d'origine remises (à appeler avant les autres retraits de poses).
func restaurer(id: String, entry: Dictionary) -> void:
	if not _origines.has(id):
		return
	var o: Dictionary = _origines[id]
	_origines.erase(id)
	var rig: Skeleton3D = entry.get("rig")
	if rig != null:
		for os_id: int in o.rotations:
			rig.set_bone_pose_rotation(os_id, o.rotations[os_id])
		for os_id: int in o.positions:
			rig.set_bone_pose_position(os_id, o.positions[os_id])
	if o.has("modele") and is_instance_valid(entry.get("model")):
		(entry.model as Node3D).position.x = (o.modele as Vector3).x
		(entry.model as Node3D).position.z = (o.modele as Vector3).z
	if o.has("y") and is_instance_valid(entry.get("model")):
		(entry.model as Node3D).position.y = float(o.y)


## L'état des poses a été remis d'ailleurs (fin du ralenti) : rien à retirer.
func oublier() -> void:
	_origines.clear()
	_ecarts.clear()
	_separations.clear()


## Dernière pose de l'image.
func poser(id: String, entry: Dictionary) -> void:
	var rig: Skeleton3D = entry.get("rig")
	var model: Node3D = entry.get("model")
	if rig == null or model == null or not rig.is_visible_in_tree():
		return
	var o: Dictionary = _origines.get(id, {"rotations": {}, "positions": {}})
	# Tronc sous sa marge : le modèle est remonté (la racine reste à sa place).
	var deficit := 0.0
	for nom: String in TRONC:
		var i := rig.find_bone(nom)
		if i >= 0:
			deficit = maxf(deficit, float(TRONC[nom]) - _monde(rig, i).origin.y)
	if deficit > 0.0:
		o["y"] = model.position.y
		model.position.y += deficit
		corrections += 1
	for chaine: Array in CHAINES:
		for passe in PASSES:
			var bas := _plus_bas(rig, chaine[1])
			if bas.is_empty():
				break
			var marge: float = MARGE_BOUT if bas.bout else MARGE_ARTICULATION
			if float(bas.point.y) >= marge - 0.0005:
				break
			if not _relever(rig, chaine[0], bas.point, marge, o):
				break
			corrections += 1
	for nom: String in PIEDS:
		var i := rig.find_bone(nom)
		if i < 0:
			continue
		var y := _monde(rig, i).origin.y
		if y < MARGE_PIED:
			if not o.positions.has(i):
				o.positions[i] = rig.get_bone_pose_position(i)
			# Hauteur monde -> repère du parent de l'os (racine du rig).
			var parent := rig.get_bone_parent(i)
			var repere := rig.global_transform * (rig.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY)
			var haut := repere.basis.inverse() * Vector3(0.0, MARGE_PIED - y, 0.0)
			rig.set_bone_pose_position(i, rig.get_bone_pose_position(i) + haut)
			corrections += 1
	var bassin := rig.find_bone("Hips")
	if bassin >= 0 and _monde(rig, bassin).origin.y < BAS:
		var reste := PLANCHER - _plus_bas_tout(rig)
		if reste > 0.0:
			if not o.has("y"):
				o["y"] = model.position.y
			model.position.y += reste
			corrections += 1
	if not o.rotations.is_empty() or not o.positions.is_empty() or o.has("y") or o.has("modele"):
		_origines[id] = o


## Dégagement, après `poser` (écart horizontal seul : le plancher reste acquis) : les jambes des joueurs debout sortent du corps des joueurs couchés.
## `ballon` : ballon tenu par `porteur` (null s'il n'est pas dans ses mains) ; il suit l'écart du
## porteur, avec un poids qui monte en PRISE s après la prise (aucun bond du ballon). À la passe, le
## vol part de la place montrée. Présentation seule.
func degager(actors: Dictionary, delta: float, porteur: String = "", ballon: Node3D = null) -> void:
	_poids_ballon = move_toward(_poids_ballon, 1.0, delta / PRISE) if ballon != null else 0.0
	var couches: Array = []
	for id: String in actors:
		var rig: Skeleton3D = actors[id].get("rig")
		if rig == null or not rig.is_visible_in_tree():
			continue
		var torse := rig.find_bone("Torso")
		if torse >= 0 and _monde(rig, torse).origin.y < COUCHE:
			couches.append(id)
	for id: String in actors.keys():
		var entry: Dictionary = actors[id]
		var model: Node3D = entry.get("model")
		var rig: Skeleton3D = entry.get("rig")
		var ecart: Vector3 = (_ecarts.get(id, Vector3.ZERO) as Vector3).move_toward(Vector3.ZERO, RETOUR * delta)
		if id in couches or model == null or rig == null or not rig.is_visible_in_tree():
			_ecarts.erase(id)
			continue
		var racine: Vector3 = (entry.node as Node3D).global_position
		var voisins: Array = []
		for c: String in couches:
			if (actors[c].node as Node3D).global_position.distance_to(racine) <= PORTEE:
				voisins.append(actors[c].rig)
		if voisins.is_empty() and ecart.is_zero_approx():
			_ecarts.erase(id)
			continue
		var origine := model.position
		model.global_position += ecart
		for passe in PASSES_DEGAGEMENT:
			var pousse := _poussee(rig, voisins)
			if pousse.is_zero_approx():
				break
			model.global_position += pousse
			ecart += pousse
		if ecart.is_zero_approx():
			model.position = origine
			_ecarts.erase(id)
			continue
		_ecarts[id] = ecart
		if id == porteur and ballon != null:
			var reel := model.global_position - (model.get_parent() as Node3D).global_transform * origine
			reel.y = 0.0
			ballon.global_position += reel * _poids_ballon
		var o: Dictionary = _origines.get(id, {"rotations": {}, "positions": {}})
		o["modele"] = origine
		_origines[id] = o
		corrections += 1


## Séparation, après `degager` (25/11/2026, sonde des contacts du match filmé : deux joueurs debout
## qui marchent l'un dans l'autre, têtes qui se fondent au ruck, plaqueur dont le buste entre dans
## celui du porteur) : deux joueurs debout dont le tronc, les cuisses ou la tête se pénètrent ont
## leurs modèles (pas leurs racines) écartés à l'horizontale, chacun de la moitié, juste assez ;
## l'écart revient à zéro à RETOUR m/s. Bras exclus (liaisons, plaquages : contact voulu).
## `exclus` : joueurs liés à une phase où le contact est voulu (mêlée, ballon porté), jamais écartés
## entre eux ni déplacés ; 25/11/2026 : ils restent des obstacles pour les autres (demi qui longe le
## paquet à la sortie de mêlée, joueur qui rejoint le ballon porté, repli après l'essai), qui sont
## écartés seuls, de tout l'écart.
## Le ballon tenu suit l'écart de son porteur. Présentation seule.
func separer(actors: Dictionary, delta: float, exclus: Dictionary = {}, porteur: String = "", ballon: Node3D = null) -> void:
	var ids: Array = []
	var volumes: Dictionary = {}
	var racines: Dictionary = {}
	for id: String in actors:
		var entry: Dictionary = actors[id]
		var rig: Skeleton3D = entry.get("rig")
		var model: Node3D = entry.get("model")
		var ecart: Vector3 = (_separations.get(id, Vector3.ZERO) as Vector3).move_toward(Vector3.ZERO, RETOUR * delta)
		_separations[id] = ecart
		if exclus.has(id):
			_separations.erase(id)
		if model == null or rig == null or not rig.is_visible_in_tree():
			_separations.erase(id)
			continue
		var torse := rig.find_bone("Torso")
		if torse < 0 or _monde(rig, torse).origin.y < COUCHE:
			_separations.erase(id)
			continue
		ids.append(id)
		volumes[id] = _volumes(rig, TRONC_DEBOUT)
		racines[id] = (entry.node as Node3D).global_position
	# Écart de cette image : l'écart précédent (qui revient doucement) puis les poussées.
	var poussees: Dictionary = {}
	for id: String in ids:
		poussees[id] = _separations.get(id, Vector3.ZERO)
	for passe in PASSES_SEPARATION:
		var bouge := false
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: String = ids[i]
				var b: String = ids[j]
				var fixe_a := exclus.has(a)
				var fixe_b := exclus.has(b)
				if (fixe_a and fixe_b) or (racines[a] as Vector3).distance_to(racines[b]) > PORTEE_DEBOUT:
					continue
				var p := _poussee_mutuelle(volumes[a], poussees[a], volumes[b], poussees[b], racines[a] - racines[b])
				if p.is_zero_approx():
					continue
				var part_a := 0.0 if fixe_a else (1.0 if fixe_b else 0.5)
				poussees[a] += p * part_a
				poussees[b] -= p * (1.0 - part_a)
				bouge = true
		if not bouge:
			break
	for id: String in ids:
		var ecart: Vector3 = poussees[id]
		if exclus.has(id) or ecart.is_zero_approx():
			_separations.erase(id)
			continue
		_separations[id] = ecart
		var entry: Dictionary = actors[id]
		var model: Node3D = entry.model
		var o: Dictionary = _origines.get(id, {"rotations": {}, "positions": {}})
		if not o.has("modele"):
			o["modele"] = model.position
		_origines[id] = o
		model.global_position += ecart
		if id == porteur and ballon != null:
			ballon.global_position += Vector3(ecart.x, 0.0, ecart.z) * _poids_ballon
		corrections += 1


## Poussée horizontale (monde) qui sépare les volumes `va` (décalés de `da`) de `vb` (décalés de `db`) :
## à ajouter à a et retirer à b (zéro s'ils ne se pénètrent pas). `racines` : racine de a moins celle de b.
static func _poussee_mutuelle(va: Array, da: Vector3, vb: Array, db: Vector3, racines: Vector3) -> Vector3:
	var pire := 0.0
	var vers := Vector3.ZERO
	for s1: Array in va:
		for s2: Array in vb:
			var r := Geometry3D.get_closest_points_between_segments(s1[0] + da, s1[1] + da, s2[0] + db, s2[1] + db)
			var p := float(s1[2]) + float(s2[2]) + JEU_DEBOUT - (r[0] as Vector3).distance_to(r[1])
			if p <= pire:
				continue
			var d: Vector3 = r[0] - r[1]
			var longueur := d.length()
			d.y = 0.0
			if d.length() >= 0.02 and longueur > 0.001:
				p *= minf(longueur / d.length(), 3.0)
			if d.length() < 0.02:
				d = racines + da - db
				d.y = 0.0
			if d.length() < 0.001:
				d = Vector3.RIGHT
			pire = p
			vers = d.normalized() * p
	return vers


## Plus forte poussée horizontale (monde) qui sort une jambe de `rig` des corps couchés `corps`.
static func _poussee(rig: Skeleton3D, corps: Array) -> Vector3:
	var jambes := _volumes(rig, JAMBES_DEBOUT)
	var pire := 0.0
	var vers := Vector3.ZERO
	for autre: Skeleton3D in corps:
		var volumes := _volumes(autre, CORPS_COUCHE)
		for s1: Array in jambes:
			for s2: Array in volumes:
				var r := Geometry3D.get_closest_points_between_segments(s1[0], s1[1], s2[0], s2[1])
				var p := float(s1[2]) + float(s2[2]) + JEU - (r[0] as Vector3).distance_to(r[1])
				if p <= pire:
					continue
				var d: Vector3 = r[0] - r[1]
				var longueur := d.length()
				d.y = 0.0
				# Écart surtout vertical : l'écart horizontal doit être plus grand pour sortir du volume.
				if d.length() >= 0.02 and longueur > 0.001:
					p *= minf(longueur / d.length(), 3.0)
				if d.length() < 0.02:
					# Jambe au-dessus du corps : écartée du côté où se tient le joueur.
					d = rig.global_position - (r[1] as Vector3)
					d.y = 0.0
				if d.length() < 0.02:
					d = rig.global_position - autre.global_position
					d.y = 0.0
				if d.length() < 0.001:
					d = Vector3.RIGHT
				pire = p
				vers = d.normalized() * p
	return vers


static func _volumes(rig: Skeleton3D, liste: Array) -> Array:
	var g := rig.global_transform
	var sortie: Array = []
	for v: Array in liste:
		var i := rig.find_bone(v[0])
		if i < 0:
			continue
		var a := g * rig.get_bone_global_pose(i)
		var b: Vector3
		if v[1] is String:
			var j := rig.find_bone(v[1])
			if j < 0:
				continue
			b = (g * rig.get_bone_global_pose(j)).origin
		else:
			b = a.origin + a.basis.y.normalized() * float(v[1])
		sortie.append([a.origin, b, float(v[2])])
	return sortie


## Hauteur (m) du point le plus bas de tout le corps (haut de la tête compris).
func _plus_bas_tout(rig: Skeleton3D) -> float:
	var g := rig.global_transform
	var bas := INF
	for i in rig.get_bone_count():
		var nom := rig.get_bone_name(i)
		if nom in EXCLUS:
			continue
		var pose := g * rig.get_bone_global_pose(i)
		bas = minf(bas, pose.origin.y)
		if nom == "Head":
			bas = minf(bas, (pose.origin + pose.basis.y.normalized() * TETE).y)
	return bas


## Point le plus bas d'une chaîne : {"point": Vector3, "bout": bool} (vide si aucun os trouvé).
func _plus_bas(rig: Skeleton3D, noms: Array) -> Dictionary:
	var bas := {}
	for nom: String in noms:
		var i := rig.find_bone(nom)
		if i < 0:
			continue
		var t := _monde(rig, i)
		var points: Array = [t.origin]
		var bout := nom.begins_with("Fingers") or nom.begins_with("Thumb")
		if nom == "Head":
			points = [t.origin + t.basis.y.normalized() * TETE]
			bout = true
		for p: Vector3 in points:
			var marge := MARGE_BOUT if bout else MARGE_ARTICULATION
			if bas.is_empty() or p.y - marge < float(bas.point.y) - (MARGE_BOUT if bas.bout else MARGE_ARTICULATION):
				bas = {"point": p, "bout": bout}
	return bas


## Tourne le premier pivot au-dessus du sol pour amener `point` à la hauteur `marge`.
func _relever(rig: Skeleton3D, pivots: Array, point: Vector3, marge: float, o: Dictionary) -> bool:
	for nom: String in pivots:
		var i := rig.find_bone(nom)
		if i < 0:
			continue
		var pivot := _monde(rig, i).origin
		var v := point - pivot
		var longueur := v.length()
		if longueur < 0.01 or pivot.y < marge + 0.01 or marge - pivot.y > longueur * 0.98:
			continue
		var axe := v.cross(Vector3.UP)
		if axe.length() < 0.0001:
			continue
		var angle := asin(clampf((marge - pivot.y) / longueur, -1.0, 1.0)) - asin(clampf(v.y / longueur, -1.0, 1.0))
		if angle <= 0.0:
			return false
		var monde := Quaternion(axe.normalized(), angle)
		var r := rig.global_basis.orthonormalized().get_rotation_quaternion()
		var actuel := rig.get_bone_global_pose(i).basis.get_rotation_quaternion()
		var voulu := r.inverse() * monde * r * actuel
		var parent := rig.get_bone_parent(i)
		var parent_rot := rig.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		if not o.rotations.has(i):
			o.rotations[i] = rig.get_bone_pose_rotation(i)
		rig.set_bone_pose_rotation(i, (parent_rot.inverse() * voulu).normalized())
		return true
	return false


## Milieu des deux paumes (monde) : le ballon tenu suit ses mains quand le plancher les relève.
static func mains(rig: Skeleton3D) -> Vector3:
	var g := rig.global_transform
	return (g * rig.get_bone_global_pose(rig.find_bone("Palm.L")).origin + g * rig.get_bone_global_pose(rig.find_bone("Palm.R")).origin) * 0.5


static func _monde(rig: Skeleton3D, i: int) -> Transform3D:
	return rig.global_transform * rig.get_bone_global_pose(i)
