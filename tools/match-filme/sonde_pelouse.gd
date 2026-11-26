extends RefCounted
## Sonde « pelouse vide » (match filmé, toujours active) : à chaque image où la 3D du match se voit
## (voile et écran intermédiaire pas encore opaques), compte les joueurs posés dans le champ de la
## caméra. Aucun joueur à l'image = « pelouse vide » : l'image, l'instant et l'état de la régie sont notés.

## Au-delà de cette opacité du voile (ou de l'écran intermédiaire), la 3D ne se voit plus.
const COUVERTURE_MAX := 0.9
## Point visé sur chaque joueur : à mi-hauteur du corps (m).
const MI_CORPS := 1.0
const PIRES_MAX := 40

var images := 0
var vides := 0
## Épisodes de pelouse vide (images consécutives), décrits à leur première image.
var pires: Array = []
var _en_cours := false


## Opacité de ce qui recouvre la 3D (voile du fondu, écran intermédiaire) : 0 = 3D seule, 1 = cachée.
static func couverture(regie: Node) -> float:
	var c := 0.0
	for nom: String in ["voile", "between"]:
		var n: Variant = regie.get(nom)
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree(): c = maxf(c, (n as CanvasItem).modulate.a)
	return c


## Joueurs (hors arbitre) dont le milieu du corps est dans le champ de la caméra de la vue 3D.
static func joueurs_visibles(vue: Node) -> int:
	var camera: Camera3D = vue.get("_camera")
	if camera == null: return -1
	var n := 0
	for id: String in vue._actors:
		var noeud: Node3D = vue._actors[id].node
		if noeud == null or not noeud.is_visible_in_tree(): continue
		var p := noeud.global_position + Vector3(0.0, MI_CORPS, 0.0)
		if not camera.is_position_behind(p) and camera.is_position_in_frustum(p): n += 1
	return n


## Une image de plus : vrai si la 3D se voit sans aucun joueur à l'image.
func observer(regie: Node, temps: float, minute: int) -> bool:
	if regie == null: return false
	var vue: Variant = regie.get("stage")
	if not vue is Node3D or not (vue as Node3D).is_visible_in_tree() or not (vue as Node).get("_actors") is Dictionary: return false
	var c := couverture(regie)
	if c >= COUVERTURE_MAX:
		_en_cours = false
		return false
	images += 1
	var n := joueurs_visibles(vue)
	if n != 0:
		_en_cours = false
		return false
	vides += 1
	# Images vides consécutives : un seul épisode (son début décrit, sa durée en images).
	if _en_cours and not pires.is_empty():
		var dernier: Dictionary = pires[pires.size() - 1]
		dernier["images"] = int(dernier.get("images", 1)) + 1
		dernier["couverture_min"] = minf(float(dernier.get("couverture_min", 1.0)), snappedf(c, 0.01))
		return true
	_en_cours = true
	if pires.size() < PIRES_MAX:
		var tf: Dictionary = regie.get("tf") if regie.get("tf") is Dictionary else {}
		var plans: Array = tf.get("plans", [])
		var k := int(regie.get("index"))
		var plan: Dictionary = plans[k] if k >= 0 and k < plans.size() and plans[k] is Dictionary else {}
		var camera: Camera3D = vue.get("_camera")
		var centre := Vector3.ZERO
		for id: String in vue._actors: centre += (vue._actors[id].node as Node3D).global_position
		if not vue._actors.is_empty(): centre /= float(vue._actors.size())
		pires.append({"image_rendue": images, "secondes": snappedf(temps, 0.01), "minute": minute, "etat": int(regie.get("etat")),
			"phase": str(regie.get("phase")), "temps_fort": str(tf.get("type", "")), "suite": bool(tf.get("suite", false)), "plan": k,
			"plan_kind": str(plan.get("kind", "")), "couverture": snappedf(c, 0.01), "couverture_min": snappedf(c, 0.01), "images": 1, "acteurs": vue._actors.size(),
			"depart": tf.get("depart") is Dictionary, "coupe": bool(plan.get("coupe", false)),
			"trajet_ballon": snappedf(float(vue.get("_ball_travel")), 0.01) if vue.get("_ball_travel") != null else -1.0,
			"ballon_de": [snappedf((vue.get("_ball_from") as Vector3).x, 0.1), snappedf((vue.get("_ball_from") as Vector3).z, 0.1)] if vue.get("_ball_from") is Vector3 else [],
			"ballon_vers": [snappedf((vue.get("_ball_target") as Vector3).x, 0.1), snappedf((vue.get("_ball_target") as Vector3).z, 0.1)] if vue.get("_ball_target") is Vector3 else [],
			"ballon": [snappedf((vue._ball as Node3D).global_position.x, 0.1), snappedf((vue._ball as Node3D).global_position.z, 0.1)] if vue.get("_ball") is Node3D else [],
			"camera": [snappedf(camera.global_position.x, 0.1), snappedf(camera.global_position.y, 0.1), snappedf(camera.global_position.z, 0.1)] if camera != null else [],
			"joueurs_centre": [snappedf(centre.x, 0.1), snappedf(centre.z, 0.1)]})
	return true


func bilan() -> Dictionary:
	return {"images_3d": images, "pelouse_vide": vides, "episodes": pires.size(), "pires": pires}
