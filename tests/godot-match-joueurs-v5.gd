extends SceneTree
## Joueurs 3D v5 (match_joueur_v5.gd) : 30 acteurs du vrai match, gabarit du poste, taille du gabarit,
## carnations variées, une coupe visible au plus, squelette Quaternius, tenue aux couleurs du club,
## pieds au sol pendant la course.

const JoueurV5 = preload("res://match_joueur_v5.gd")
const Athlete = preload("res://match_athlete.gd")
const ATTENDU := ["prop-trapu", "prop-talon", "prop-grand", "lock-long", "lock-long", "flank-7", "flank-7",
	"flank-8", "back-demi", "back-ouvreur", "back-ailier", "back-centre", "back-centre", "back-ailier"]

var failures: Array[String] = []
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _initialize() -> void:
	call_deferred("run")


func scene(key: String, decalage: float) -> Dictionary:
	var players: Array = []
	for side in 2:
		for slot in 15:
			players.append({"id": "v5_%d_%d" % [side, slot], "side": side, "slot": slot,
				"x": 30.0 + side * 30.0 + slot * 1.5 + decalage, "y": 5.0 + slot * 4.0, "featured": false})
	return {"key": key, "kind": "carry", "possession": 0, "players": players,
		"ball": {"x": 50.0, "y": 35.0}, "origin": {"x": 50.0, "y": 35.0}}


func pied_bas(rig: Skeleton3D) -> float:
	var bas := INF
	for os: String in ["Foot.L", "Foot.R"]:
		bas = minf(bas, rig.to_global(rig.get_bone_global_pose(rig.find_bone(os)).origin).y)
	return bas


func run() -> void:
	check(JoueurV5.disponible(), "Manifeste des joueurs v5 présent")
	# Règles des tenues (match_kit.gd, Athlete.SKINS) : chaque carnation v5 y a une voisine proche.
	for teinte: String in JoueurV5.TEINTES_RVB:
		var c := Color(teinte)
		var proche := INF
		for tone in Athlete.SKINS:
			var s := Color(str(tone))
			proche = minf(proche, Vector3(c.r, c.g, c.b).distance_to(Vector3(s.r, s.g, s.b)))
		check(proche < 0.14, "Carnation %s couverte par les règles des tenues (%.3f)" % [teinte, proche])
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.apply_frame({"teams": [{"color": "#c8102e"}, {"color": "#1d4f91"}], "scene": scene("a", 0.0)})
	await process_frame
	check(view._actors.size() == 30, "30 acteurs : %d" % view._actors.size())
	var teintes := {}
	var avec_coupe := 0
	var stats := {}
	for side in 2:
		for slot in 15:
			var id := "v5_%d_%d" % [side, slot]
			var entry: Dictionary = view._actors[id]
			var model: Node3D = entry.model
			var profil := str(entry.profil)
			if slot < 14:
				check(profil == ATTENDU[slot], "Slot %d -> %s (attendu %s)" % [slot, profil, ATTENDU[slot]])
			else:
				check(profil in ["back-ailier", "back-ouvreur"], "N° 15 ailier ou ouvreur : " + profil)
			check(profil == JoueurV5.profil_pour(id, slot), "Gabarit stable " + id)
			# Taille à l'écran = taille du gabarit (corps sans cheveux), pieds au repos au sol.
			var bornes := JoueurV5.bornes_corps(model)
			var hauteur := bornes.size.y * model.scale.y
			check(absf(hauteur - JoueurV5.taille(profil)) < 0.005, "%s : %.3f m pour %.2f m" % [id, hauteur, JoueurV5.taille(profil)])
			check(absf(model.position.y + bornes.position.y * model.scale.y) < 0.005, id + " : base du corps au sol")
			var rig: Skeleton3D = entry.rig
			check(rig != null and rig.find_bone("Body") >= 0 and rig.find_bone("Head") >= 0 and rig.find_bone("Foot.L") >= 0, id + " : squelette Quaternius")
			check(entry.animation != null and not str(entry.idle).is_empty(), id + " : clip de repos")
			var look := JoueurV5.apparence(id)
			check(look == JoueurV5.apparence(id), "Apparence stable " + id)
			teintes[look.teinte] = true
			var visibles := 0
			for coupe: String in JoueurV5.COUPES:
				var cheveux := model.find_child("Cheveux_" + coupe, true, false) as MeshInstance3D
				if cheveux and cheveux.visible:
					visibles += 1
			check(visibles <= 1, id + " : une coupe au plus (%d)" % visibles)
			check((visibles == 1) == (look.crane == "cheveux"), id + " : coupe seulement sous un crâne à cheveux")
			avec_coupe += visibles
			var corps := model.find_child("Corps", true, false) as MeshInstance3D
			for i in corps.mesh.get_surface_count():
				var nom: String = corps.mesh.surface_get_material(i).resource_name
				var porte := corps.get_surface_override_material(i) as StandardMaterial3D
				if nom == "Shirt2":
					check(porte != null and porte.albedo_color.is_equal_approx(view._kits[side].shirt), id + " : maillot du club")
				if nom == "Skin":
					check(porte != null and porte.albedo_texture != null and porte.albedo_texture.resource_path.ends_with(look.peau), id + " : peau " + str(look.peau))
			stats[profil] = stats.get(profil, 0) + 1
	check(teintes.size() >= 4, "Au moins 4 carnations : %s" % str(teintes.keys()))
	check(avec_coupe >= 3, "Des coupes visibles : %d" % avec_coupe)
	# Course : les pieds restent près du sol (aucun joueur enfoncé ni en l'air).
	view.apply_frame({"teams": [{"color": "#c8102e"}, {"color": "#1d4f91"}], "scene": scene("b", 12.0)})
	var plus_bas := INF
	var plus_haut := -INF
	for f in 40:
		await process_frame
		for entry: Dictionary in view._actors.values():
			var bas := pied_bas(entry.rig)
			plus_bas = minf(plus_bas, bas)
			plus_haut = maxf(plus_haut, bas)
	check(plus_bas > -0.12, "Pieds pas sous la pelouse : %.3f m" % plus_bas)
	check(plus_haut < 0.6, "Toujours un pied près du sol : %.3f m" % plus_haut)
	print("MATCH_JOUEURS_V5_METRICS ", JSON.stringify({"teintes": teintes.keys(), "coupes": avec_coupe, "profils": stats, "pied_min": plus_bas, "pied_max": plus_haut}))
	print("MATCH_JOUEURS_V5_CHECKS %d failures=%d" % [checks, failures.size()])
	view.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
