extends Node
## Sonde des contacts (CD_MESURE_CONTACTS=1, match filmé seulement ; Léo, 25/11/2026 : « pas
## d'interpénétration franche » entre joueurs). À chaque image, après toutes les poses de la vue 3D
## (plancher et dégagement compris), mesure pour chaque couple de joueurs proches la plus forte
## pénétration entre leurs corps entiers (tronc, tête, bras, jambes ; volumes capsules, mêmes rayons
## que la sonde du ruck), et la range par phase : mêlée, maul (ballon porté), plaquage, touche,
## ruck/joueur au sol, joueurs debout entre eux. Images du ralenti de l'essai non comptées (elles
## rejouent des poses déjà vues).
## Rend, par phase : couples-images et épisodes au-delà de FRANC (franc) et de LEGER, images touchées,
## pénétration maximale, os les plus en cause ; et les pires épisodes (instant simulé, couple, os).
## CD_CONTACTS_CAPTURES=<dossier> : les premiers épisodes francs de chaque phase (au plus
## CAPTURES_PAR_PHASE) sont photographiés sous deux angles par deux vues secondaires du même monde.

const FRANC := 0.08
const LEGER := 0.03
const PORTEE := 2.6
const COUCHE := 0.45
const CORPS := [["Hips", "Abdomen", 0.13], ["Abdomen", "Torso", 0.14], ["Torso", "Neck", 0.14], ["Head", 0.22, 0.1],
	["UpperLeg.L", "LowerLeg.L", 0.08], ["UpperLeg.R", "LowerLeg.R", 0.08], ["LowerLeg.L", "Foot.L", 0.06], ["LowerLeg.R", "Foot.R", 0.06],
	["UpperArm.L", "LowerArm.L", 0.06], ["UpperArm.R", "LowerArm.R", 0.06], ["LowerArm.L", "Palm.L", 0.05], ["LowerArm.R", "Palm.R", 0.05]]
const PHASES := ["melee", "maul", "plaquage", "touche", "ruck_sol", "debout"]
## Bustes et têtes (bras et jambes exclus) : en mêlée et au ballon porté, les bras liés et les
## épaules au contact sont voulus ; seuls les bustes et les têtes qui se confondent sont des fautes.
const TRONC_TETE := ["Hips", "Abdomen", "Torso", "Head"]
const CAPTURES_PAR_PHASE := 2
## Vitrines (25/11/2026) : mêlée et ballon porté photographiés formés, VITRINE_DELAI s après leur début,
## au plus VITRINES fois chacun, quels que soient les contacts (pour juger l'allure, pas une faute).
const VITRINE_DELAI := 1.6
const VITRINES := 2
const PIRES_MAX := 80

var vue: Node
var temps := 0.0
var images := 0
var images_rejeu := 0
var par_phase: Dictionary = {}
var _precedents: Dictionary = {}
var pires: Array = []
var dossier_captures := ""
var vues: Array = []
var captures: Array = []
var _captures_phase: Dictionary = {}
var _capture_due := -1
var _capture_info: Dictionary = {}
## Mêlée : épisodes de bustes ou têtes confondus, avec l'état de chaque joueur (diagnostic).
var melee_tt: Array = []
var _vitrine_debut: Dictionary = {}
var _vitrines: Dictionary = {}
var _precedents_tt: Dictionary = {}


func _init() -> void:
	process_priority = 100002
	dossier_captures = OS.get_environment("CD_CONTACTS_CAPTURES")
	for p: String in PHASES:
		par_phase[p] = {"images_couples": 0, "images_franc": 0, "couples_franc": 0, "episodes_franc": 0, "couples_leger": 0,
			"episodes_leger": 0, "penetration_max_m": 0.0, "os": {}, "couples_franc_tronc_tete": 0, "tronc_tete_max_m": 0.0,
			"os_tronc_tete": {}}


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


static func segments(rig: Skeleton3D) -> Array:
	var g := rig.global_transform
	var liste: Array = []
	for v: Array in CORPS:
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


func _couche(rig: Skeleton3D) -> bool:
	var t := rig.find_bone("Torso")
	return t >= 0 and (rig.global_transform * rig.get_bone_global_pose(t)).origin.y < COUCHE


## Phase du couple (a, b) à cette image.
func _phase(a: String, b: String, couches: Dictionary) -> String:
	var ch = vue.get("_choregraphie")
	if ch != null and bool(ch.actif) and (ch.stages(a) or ch.stages(b)):
		var etats := [str(ch.etat(a)), str(ch.etat(b))]
		if "melee" in etats:
			return "melee"
		if "maul" in etats:
			return "maul"
		for e: String in etats:
			if e in ["plaquage", "plaquage_rate", "plaque"]:
				return "plaquage"
		for e: String in etats:
			if e in ["ruck", "au_sol", "aplati"]:
				return "ruck_sol"
		return "ruck_sol" if couches.has(a) or couches.has(b) else "debout"
	var f = vue.get("_formations")
	var type := ""
	if f != null:
		type = str(f.formation.get("type", ""))
		if type in ["melee", "sortie_melee"] and ((f.formation.places as Dictionary).has(a) or (f.formation.places as Dictionary).has(b)):
			return "melee"
	var m = vue.mise_en_scene()
	var ph := str(m.get("phase")) if m != null else ""
	if ph in ["maul", "essai_maul"] and (m.stages(a) or m.stages(b)):
		return "maul"
	if type == "touche" or ph == "touche" or str(vue._kind) == "lineout":
		return "touche"
	var imp = vue.get("_impacts")
	if imp != null:
		if str(imp.phase) != "" and (a in [imp.plaqueur, imp.porteur] or b in [imp.plaqueur, imp.porteur]):
			return "plaquage"
		if (imp.ruck as Dictionary).has(a) or (imp.ruck as Dictionary).has(b):
			return "ruck_sol"
	if couches.has(a) or couches.has(b):
		return "ruck_sol"
	return "debout"


func _etat_melee(id: String) -> Dictionary:
	var e := {"id": id.right(6)}
	var f = vue.get("_formations")
	if f != null:
		e["type"] = str(f.formation.get("type", ""))
		e["role"] = str(f.formation.roles.get(id, ""))
		e["posture"] = f.posture_de(id)
		e["temps"] = snappedf(float(f.temps), 0.01)
		e["libere"] = bool(f.libere)
		if (f.formation.places as Dictionary).has(id):
			var p: Vector2 = f.formation.places[id]
			var n: Vector3 = (vue._actors[id].node as Node3D).position
			e["ecart_place"] = snappedf(Vector2(n.x + 50.0, n.z + 35.0).distance_to(p), 0.01)
			e["place"] = [snappedf(p.x - float(f.formation.centre.x), 0.01), snappedf(p.y - float(f.formation.centre.y), 0.01)]
	e["pitch"] = snappedf((vue._actors[id].model as Node3D).rotation.x, 0.01)
	e["lacet"] = snappedf((vue._actors[id].node as Node3D).rotation.y, 0.01)
	e["mis_en_scene"] = f._mis_en_scene(id) if f != null else false
	e["geste"] = not (vue._actors[id].get("geste", {}) as Dictionary).is_empty()
	return e


func _photographier(info: Dictionary) -> void:
	var p: Vector3 = info.point
	var a: Node3D = vue._actors[info.a].node
	var b: Node3D = vue._actors[info.b].node
	var axe := b.global_position - a.global_position
	axe.y = 0.0
	axe = axe.normalized() if axe.length() > 0.05 else Vector3.RIGHT
	var cote := Vector3(-axe.z, 0.0, axe.x)
	var poses := [[p + cote * 3.4 + Vector3.UP * 1.2, p], [p + cote * -2.6 + axe * 1.6 + Vector3.UP * 0.6, p]]
	for i in 2:
		(vues[i] as SubViewport).world_3d = (vue as Node).get_viewport().find_world_3d()
		var cam: Camera3D = vues[i].get_child(0)
		cam.global_transform = Transform3D(Basis.IDENTITY, poses[i][0]).looking_at(poses[i][1], Vector3.UP)
		vues[i].render_target_update_mode = SubViewport.UPDATE_ONCE
	_capture_info = info
	_capture_due = images + 2


func _enregistrer() -> void:
	var n := captures.size() + 1
	var fichiers: Array = []
	for i in 2:
		var nom := "contact-%02d-%s-%s.png" % [n, _capture_info.phase, ["cote", "face"][i]]
		(vues[i] as SubViewport).get_texture().get_image().save_png(dossier_captures.path_join(nom))
		fichiers.append(nom)
	var c := _capture_info.duplicate()
	c.erase("point")
	c["fichiers"] = fichiers
	captures.append(c)
	_capture_due = -1


func _process(delta: float) -> void:
	temps += delta
	if vue == null or not is_instance_valid(vue):
		vue = get_tree().root.find_child("NativeMatchView", true, false)
		if vue == null:
			return
	if not vue.is_visible_in_tree():
		return
	if _capture_due >= 0 and images >= _capture_due:
		_enregistrer()
	if bool(vue._rejeu.actif):
		images_rejeu += 1
		return
	images += 1
	var ids: Array = []
	var corps: Dictionary = {}
	var racines: Dictionary = {}
	var couches: Dictionary = {}
	for id: String in vue._actors:
		var rig: Skeleton3D = vue._actors[id].rig
		if rig == null or not rig.is_visible_in_tree():
			continue
		ids.append(id)
		corps[id] = segments(rig)
		racines[id] = (vue._actors[id].node as Node3D).global_position
		if _couche(rig):
			couches[id] = true
	var vus: Dictionary = {}
	var vus_tt: Dictionary = {}
	var touchees: Dictionary = {}
	var vus_phase: Dictionary = {}
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			if (racines[a] as Vector3).distance_to(racines[b]) > PORTEE:
				continue
			var phase := _phase(a, b, couches)
			par_phase[phase].images_couples += 1
			if phase in ["melee", "maul"]:
				var v: Array = vus_phase.get(phase, [Vector3.ZERO, 0, a, b])
				v[0] = (v[0] as Vector3) + (racines[a] as Vector3) + (racines[b] as Vector3)
				v[1] = int(v[1]) + 2
				vus_phase[phase] = v
			var max_p := -INF
			var detail := ""
			var point := Vector3.ZERO
			var max_t := -INF
			var detail_t := ""
			for s1: Array in corps[a]:
				for s2: Array in corps[b]:
					var r := Geometry3D.get_closest_points_between_segments(s1[0], s1[1], s2[0], s2[1])
					var p := float(s1[2]) + float(s2[2]) - (r[0] as Vector3).distance_to(r[1])
					if p > max_p:
						max_p = p
						detail = "%s/%s" % [s1[3], s2[3]]
						point = ((r[0] as Vector3) + (r[1] as Vector3)) * 0.5
					if p > max_t and str(s1[3]) in TRONC_TETE and str(s2[3]) in TRONC_TETE:
						max_t = p
						detail_t = "%s/%s" % [s1[3], s2[3]]
			if max_t > FRANC and phase == "melee" and _precedents_tt.get(a + ">" + b, false) == false and melee_tt.size() < 40:
				melee_tt.append({"t": snappedf(temps, 0.01), "image": images, "os": detail_t, "p": snappedf(max_t, 0.001),
					"a": _etat_melee(a), "b": _etat_melee(b)})
			vus_tt[a + ">" + b] = max_t > FRANC
			if max_t > FRANC:
				var st: Dictionary = par_phase[phase]
				st.couples_franc_tronc_tete += 1
				st.tronc_tete_max_m = maxf(float(st.tronc_tete_max_m), snappedf(max_t, 0.001))
				st.os_tronc_tete[detail_t] = int(st.os_tronc_tete.get(detail_t, 0)) + 1
			if max_p <= LEGER:
				continue
			var s: Dictionary = par_phase[phase]
			var cle := a + ">" + b
			var nouveau := not _precedents.has(cle)
			if max_p > FRANC:
				s.couples_franc += 1
				touchees[phase] = true
				s.penetration_max_m = maxf(float(s.penetration_max_m), snappedf(max_p, 0.001))
				var cle_os := detail
				s.os[cle_os] = int(s.os.get(cle_os, 0)) + 1
				vus[cle] = "franc"
				if nouveau or _precedents[cle] != "franc":
					s.episodes_franc += 1
					var e := {"phase": phase, "t": snappedf(temps, 0.01), "image": images, "a": a, "b": b, "os": detail,
						"penetration": snappedf(max_p, 0.001), "a_couche": couches.has(a), "b_couche": couches.has(b),
						"porteur": str(vue._carrier_id), "kind": str(vue._kind)}
					if pires.size() < PIRES_MAX:
						pires.append(e)
					if not vues.is_empty() and _capture_due < 0 and int(_captures_phase.get(phase, 0)) < CAPTURES_PAR_PHASE and max_p >= 0.12:
						_captures_phase[phase] = int(_captures_phase.get(phase, 0)) + 1
						var info := e.duplicate()
						info["point"] = point
						_photographier(info)
			else:
				s.couples_leger += 1
				vus[cle] = "leger"
				if nouveau:
					s.episodes_leger += 1
	for phase: String in touchees:
		par_phase[phase].images_franc += 1
	_precedents = vus
	_precedents_tt = vus_tt
	for phase: String in ["melee", "maul"]:
		if not vus_phase.has(phase):
			_vitrine_debut.erase(phase)
			continue
		if not _vitrine_debut.has(phase):
			_vitrine_debut[phase] = temps
		elif temps - float(_vitrine_debut[phase]) >= VITRINE_DELAI and int(_vitrines.get(phase, 0)) < VITRINES and _capture_due < 0 and not vues.is_empty():
			var v: Array = vus_phase[phase]
			_vitrines[phase] = int(_vitrines.get(phase, 0)) + 1
			_vitrine_debut[phase] = INF
			_photographier({"phase": "vitrine-" + phase, "t": snappedf(temps, 0.01), "image": images, "a": v[2], "b": v[3],
				"point": (v[0] as Vector3) / float(v[1]) + Vector3.UP * 0.9})


func bilan() -> Dictionary:
	var resume := {}
	for p: String in PHASES:
		var s: Dictionary = par_phase[p]
		var os_tries: Array = []
		for k: String in s.os:
			os_tries.append([k, s.os[k]])
		os_tries.sort_custom(func(x, y): return x[1] > y[1])
		var os_tt: Array = []
		for k: String in s.os_tronc_tete:
			os_tt.append([k, s.os_tronc_tete[k]])
		os_tt.sort_custom(func(x, y): return x[1] > y[1])
		resume[p] = {"images_franc": s.images_franc, "couples_franc": s.couples_franc, "episodes_franc": s.episodes_franc,
			"couples_leger": s.couples_leger, "episodes_leger": s.episodes_leger, "penetration_max_m": s.penetration_max_m,
			"couples_images_proches": s.images_couples, "os": os_tries.slice(0, 6),
			"couples_franc_tronc_tete": s.couples_franc_tronc_tete, "tronc_tete_max_m": s.tronc_tete_max_m, "os_tronc_tete": os_tt.slice(0, 6)}
	return {"images": images, "images_rejeu_ignorees": images_rejeu, "seuil_franc_m": FRANC, "seuil_leger_m": LEGER,
		"resume": resume, "pires": pires, "captures": captures, "melee_bustes_tetes": melee_tt}
