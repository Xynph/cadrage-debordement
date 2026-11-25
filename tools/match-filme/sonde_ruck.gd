extends Node
## Sonde du ruck (CD_MESURE_RUCK=1, match filmé seulement) : à chaque image, après toutes les poses
## de la vue 3D, cherche les joueurs couchés (buste à moins de COUCHE m du sol) et compte les jambes
## (cuisse, tibia, pied) des autres joueurs qui entrent dans leur corps (tronc, tête, bras, jambes), en
## volumes capsules. Rend le nombre d'images et de couples jambe/corps en intersection, la plus forte
## pénétration et les pires cas (avec l'instant simulé pour retrouver l'image du film).
## CD_RUCK_CAPTURES=<dossier> : les CAPTURES_MAX premiers rucks (un couché entouré d'au moins deux
## joueurs debout) sont aussi photographiés sous deux angles (côté, ras du sol), CAPTURE_APRES s après
## leur formation, par deux vues secondaires du même monde (l'image du film n'est pas touchée).

const COUCHE := 0.45
## Pénétration (m) au-delà de laquelle un contact compte comme une traversée.
const SEUIL := 0.01
## Tronc et tête du couché : [os de départ, os d'arrivée ou longueur le long de l'axe, rayon].
const CORPS := [["Hips", "Abdomen", 0.13], ["Abdomen", "Torso", 0.14], ["Torso", "Neck", 0.14], ["Head", 0.22, 0.1],
	["UpperLeg.L", "LowerLeg.L", 0.08], ["UpperLeg.R", "LowerLeg.R", 0.08], ["LowerLeg.L", "Foot.L", 0.06], ["LowerLeg.R", "Foot.R", 0.06],
	["UpperArm.L", "LowerArm.L", 0.06], ["UpperArm.R", "LowerArm.R", 0.06], ["LowerArm.L", "Palm.L", 0.05], ["LowerArm.R", "Palm.R", 0.05]]
const JAMBES := [["UpperLeg.L", "LowerLeg.L", 0.08], ["UpperLeg.R", "LowerLeg.R", 0.08], ["LowerLeg.L", "Foot.L", 0.06],
	["LowerLeg.R", "Foot.R", 0.06], ["Foot.L", 0.16, 0.045], ["Foot.R", 0.16, 0.045]]

var vue: Node
var images := 0
var images_couche := 0
var images_proches := 0
var images_traversee := 0
var couples := 0
## Couples par rôle du joueur debout : soutien du ruck (match_impacts.gd), porteur du ballon, autre.
var par_role := {"ruck": 0, "porteur": 0, "autre": 0}
var images_hors_porteur := 0
var pire := 0.0
var episodes: Dictionary = {}
var _precedents: Dictionary = {}
var pires: Array = []
var temps := 0.0
const CAPTURES_MAX := 4
const CAPTURE_APRES := 1.0
var dossier_captures := ""
var vues: Array = []
var captures: Array = []
var _ruck_depuis := -1.0
var _capture_due := -1
var _cible := ""


func _init() -> void:
	process_priority = 100001
	dossier_captures = OS.get_environment("CD_RUCK_CAPTURES")


func _ready() -> void:
	if dossier_captures.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dossier_captures)
	for i in 2:
		var v := SubViewport.new()
		v.size = Vector2i(960, 720)
		v.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var c := Camera3D.new()
		c.fov = 38.0
		v.add_child(c)
		add_child(v)
		vues.append(v)


func _photographier(c: String) -> void:
	var rig: Skeleton3D = vue._actors[c].rig
	var torse := rig.global_transform * rig.get_bone_global_pose(rig.find_bone("Torso"))
	var p := torse.origin
	var cap: float = (vue._actors[c].node as Node3D).rotation.y
	var avant := Vector3(sin(cap), 0.0, cos(cap))
	var cote := Vector3(-avant.z, 0.0, avant.x)
	var poses := [[p + cote * 3.6 + Vector3.UP * 1.9, p + Vector3.UP * 0.3], [p - avant * 3.4 + cote * 0.8 + Vector3.UP * 0.35, p + Vector3.UP * 0.35]]
	for i in 2:
		# La vue 3D du match a son propre monde (vue secondaire du jeu) : on le partage.
		(vues[i] as SubViewport).world_3d = (vue as Node).get_viewport().find_world_3d()
		var cam: Camera3D = vues[i].get_child(0)
		cam.global_transform = Transform3D(Basis.IDENTITY, poses[i][0]).looking_at(poses[i][1], Vector3.UP)
		vues[i].render_target_update_mode = SubViewport.UPDATE_ONCE
	_capture_due = images + 2


func _enregistrer() -> void:
	var n := captures.size() / 2 + 1
	for i in 2:
		var nom := "ruck-%d-%s.png" % [n, ["cote", "ras"][i]]
		(vues[i] as SubViewport).get_texture().get_image().save_png(dossier_captures.path_join(nom))
		captures.append({"fichier": nom, "t": snappedf(temps, 0.01), "couche": _cible})
	_capture_due = -1


static func segments(rig: Skeleton3D, volumes: Array) -> Array:
	var g := rig.global_transform
	var liste: Array = []
	for v: Array in volumes:
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
		liste.append([a.origin, b, float(v[2]), str(v[0])])
	return liste


func _process(delta: float) -> void:
	temps += delta
	if vue == null or not is_instance_valid(vue):
		vue = get_tree().root.find_child("NativeMatchView", true, false)
		if vue == null:
			return
	if not vue.is_visible_in_tree():
		return
	images += 1
	if _capture_due >= 0 and images >= _capture_due:
		_enregistrer()
	var couches: Array = []
	for id: String in vue._actors:
		var rig: Skeleton3D = vue._actors[id].rig
		if rig == null or not rig.is_visible_in_tree():
			continue
		var t := rig.find_bone("Torso")
		if t >= 0 and (rig.global_transform * rig.get_bone_global_pose(t)).origin.y < COUCHE:
			couches.append(id)
	if couches.is_empty():
		_precedents.clear()
		_ruck_depuis = -1.0
		return
	images_couche += 1
	var vus: Dictionary = {}
	var proche := false
	var traverse := false
	var traverse_hors_porteur := false
	for c: String in couches:
		var rc: Skeleton3D = vue._actors[c].rig
		var pc: Vector3 = (vue._actors[c].node as Node3D).position
		var corps := segments(rc, CORPS)
		for id: String in vue._actors:
			if id == c or id in couches:
				continue
			var rig: Skeleton3D = vue._actors[id].rig
			if rig == null or not rig.is_visible_in_tree():
				continue
			if (vue._actors[id].node as Node3D).position.distance_to(pc) > 3.5:
				continue
			proche = true
			var max_p := -INF
			var detail := ""
			for s1: Array in segments(rig, JAMBES):
				for s2: Array in corps:
					var r := Geometry3D.get_closest_points_between_segments(s1[0], s1[1], s2[0], s2[1])
					var p := float(s1[2]) + float(s2[2]) - (r[0] as Vector3).distance_to(r[1])
					if p > max_p:
						max_p = p
						detail = "%s/%s" % [s1[3], s2[3]]
			if max_p > SEUIL:
				traverse = true
				couples += 1
				pire = maxf(pire, max_p)
				var cle := c + ">" + id
				vus[cle] = true
				if not _precedents.has(cle):
					episodes[cle + "@" + str(snappedf(temps, 0.1))] = snappedf(max_p, 0.001)
				var ruck_id := false
				var impacts = vue.get("_impacts")
				if impacts != null:
					ruck_id = (impacts.ruck as Dictionary).has(id)
				var porteur: bool = id == str(vue._carrier_id) and bool(vue._ball_attached)
				var role := "ruck" if ruck_id else ("porteur" if porteur else "autre")
				par_role[role] += 1
				if not porteur:
					traverse_hors_porteur = true
				if pires.size() < 60:
					pires.append({"role": role, "t": snappedf(temps, 0.01), "image": images, "couche": c, "debout": id, "os": detail,
						"penetration": snappedf(max_p, 0.001), "ruck_vue": ruck_id, "rejeu": bool(vue._rejeu.actif)})
	_precedents = vus
	if not vues.is_empty() and captures.size() < CAPTURES_MAX * 2 and _capture_due < 0 and not bool(vue._rejeu.actif):
		var entoure := ""
		for c: String in couches:
			var n := 0
			var pc: Vector3 = (vue._actors[c].node as Node3D).position
			for id: String in vue._actors:
				if id != c and not id in couches and (vue._actors[id].node as Node3D).position.distance_to(pc) < 2.2:
					n += 1
			if n >= 2:
				entoure = c
		if entoure.is_empty():
			_ruck_depuis = -1.0
		elif _ruck_depuis < 0.0:
			_ruck_depuis = temps
		elif temps - _ruck_depuis >= CAPTURE_APRES and _ruck_depuis > -0.5:
			_cible = entoure
			_photographier(entoure)
			_ruck_depuis = -1000.0
	if proche:
		images_proches += 1
	if traverse:
		images_traversee += 1
	if traverse_hors_porteur:
		images_hors_porteur += 1


func bilan() -> Dictionary:
	return {"images": images, "images_avec_couche": images_couche, "images_couche_entoure": images_proches,
		"images_traversee": images_traversee, "couples_jambe_corps": couples, "couples_par_role": par_role, "images_traversee_hors_porteur": images_hors_porteur, "episodes": episodes.size(),
		"penetration_max_m": snappedf(pire, 0.001), "captures": captures, "liste_episodes": episodes, "pires": pires}
