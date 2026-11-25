extends Node
## Sonde du sol (CD_MESURE_SOL=1, match filmé seulement) : à chaque image, après toutes les poses
## de la vue 3D, hauteur de chaque os de chaque joueur (racine et cibles d'IK exclues) et du haut
## de la tête. Rend le minimum, le nombre de relevés sous la pelouse (y < 0) et les pires cas, à
## part pendant les chutes physiques du plaquage (match_chute_physique.gd).

const EXCLUS := ["Bone", "PoleTarget.L", "PoleTarget.R"]
## Haut de la tête : à cette distance (m) de l'origine de l'os Head, le long de son axe.
const TETE := 0.2

var vue: Node
var images := 0
var releves := 0
var sous_sol := 0
var minimum := INF
var minimum_chute := INF
var images_chute := 0
var pires: Array = []


func _init() -> void:
	process_priority = 100000


func _process(_delta: float) -> void:
	if vue == null or not is_instance_valid(vue):
		vue = get_tree().root.find_child("NativeMatchView", true, false)
		if vue == null:
			return
	if not vue.is_visible_in_tree():
		return
	var chutes: Dictionary = {}
	var chute = vue.get("_chute_physique")
	if chute != null:
		chutes = chute.actifs()
	if not chutes.is_empty():
		images_chute += 1
	images += 1
	for id: String in vue._actors:
		var rig: Skeleton3D = vue._actors[id].rig
		if rig == null or not rig.is_visible_in_tree():
			continue
		var g := rig.global_transform
		var bas := INF
		var nom_bas := ""
		for i in rig.get_bone_count():
			var nom := rig.get_bone_name(i)
			if nom in EXCLUS:
				continue
			var pose := g * rig.get_bone_global_pose(i)
			var y := pose.origin.y
			if nom == "Head":
				y = minf(y, (pose.origin + pose.basis.y.normalized() * TETE).y)
			if y < bas:
				bas = y
				nom_bas = nom
		releves += 1
		minimum = minf(minimum, bas)
		if chutes.has(id):
			minimum_chute = minf(minimum_chute, bas)
		if bas < 0.0:
			sous_sol += 1
			if pires.size() < 40:
				pires.append({"image": images, "joueur": id, "os": nom_bas, "y": snappedf(bas, 0.001), "chute": chutes.has(id), "ralenti_rejoue": bool(vue._rejeu.actif), "pause": bool(vue._paused)})


func bilan() -> Dictionary:
	return {"images": images, "releves_joueur_image": releves, "minimum_m": snappedf(minimum, 0.001) if minimum < INF else null,
		"sous_la_pelouse": sous_sol, "images_avec_chute": images_chute,
		"minimum_pendant_chute_m": snappedf(minimum_chute, 0.001) if minimum_chute < INF else null, "pires": pires}
