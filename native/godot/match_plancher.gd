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

## id -> {"rotations": {os: Quaternion}, "positions": {os: Vector3}, "y": float}
var _origines: Dictionary = {}
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
	if o.has("y") and is_instance_valid(entry.get("model")):
		(entry.model as Node3D).position.y = float(o.y)


## L'état des poses a été remis d'ailleurs (fin du ralenti) : rien à retirer.
func oublier() -> void:
	_origines.clear()


## Dernière pose de l'image.
func poser(id: String, entry: Dictionary) -> void:
	var rig: Skeleton3D = entry.get("rig")
	var model: Node3D = entry.get("model")
	if rig == null or model == null or not rig.is_visible_in_tree():
		return
	var o := {"rotations": {}, "positions": {}}
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
	if not o.rotations.is_empty() or not o.positions.is_empty() or o.has("y"):
		_origines[id] = o


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
