extends SceneTree
## Sonde des contacts du match filmé (tools/match-filme/sonde_contacts.gd), sans rendu :
## 1. pistes du chorégraphe pour un seul des deux joueurs d'un couple proche (l'autre reste sur la
##    vue) : aucune erreur de script, le couple est mesuré (26/11/2026 : 99 SCRIPT ERROR par match,
##    `etat()` demandé pour un joueur sans piste) ;
## 2. membres en cause (bras dans le corps, bras contre bras, jambes, tronc/tête) et pénétration
##    moyenne rendus par phase.
## Coordonnées de test, jamais un vrai match.

const View = preload("res://match_view.gd")
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var metrics := {}


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _initialize() -> void:
	call_deferred("run")


func frame() -> Dictionary:
	var players: Array = [{"id": "c", "side": 0, "featured": true, "x": 50.0, "y": 35.0},
		{"id": "d", "side": 1, "featured": false, "x": 51.2, "y": 35.0},
		{"id": "a", "side": 0, "featured": false, "x": 40.0, "y": 20.0}]
	return {"scene": {"key": "sonde", "kind": "carry", "possession": 0, "players": players,
		"origin": {"x": 50.0, "y": 35.0}, "ball": {"x": 50.0, "y": 35.0}}}


## Pistes du chorégraphe pour le seul porteur « c », immobile, en course.
func pistes() -> Dictionary:
	var n := 11
	var fixe := func(v: float) -> Array:
		var a: Array = []
		a.resize(n)
		a.fill(v)
		return a
	return {"version": 2, "pas": 0.2, "duree": 2.0,
		"joueurs": [{"id": "c", "side": 0, "x": fixe.call(50.0), "y": fixe.call(35.0), "v": fixe.call(0.0), "cap": fixe.call(0.0),
			"etats": [[0.0, "course"]]}],
		"ballon": {"x": fixe.call(50.0), "y": fixe.call(35.0), "h": fixe.call(1.0), "porteurs": [[0.0, "c"]]}}


func run() -> void:
	var Sonde: GDScript = load((get_script() as Script).resource_path.get_base_dir().path_join("../tools/match-filme/sonde_contacts.gd").simplify_path())
	# Catégories des membres en cause.
	check(Sonde.categorie("LowerArm.L", "Torso") == "bras_corps", "forearm in a torso is an arm in a body")
	check(Sonde.categorie("Hips", "UpperArm.R") == "bras_corps", "upper arm in hips is an arm in a body")
	check(Sonde.categorie("UpperArm.R", "UpperArm.L") == "bras_bras", "arm against arm")
	check(Sonde.categorie("LowerLeg.L", "Head") == "jambes", "shin in a head is a leg contact")
	check(Sonde.categorie("Head", "Torso") == "tronc_tete", "head in a torso is torso/head")
	var view = View.new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	view.apply_frame(frame())
	view._process(1.0)
	check(view.jouer_choregraphie(pistes()), "tracks for the carrier only are accepted")
	check(view._choregraphie.stages("c") and not view._choregraphie.stages("d"), "only the carrier has a track")
	var sonde: Node = Sonde.new()
	sonde.vue = view
	root.add_child(sonde)
	sonde.set_process(false)
	await process_frame
	for i in 20:
		view._process(STEP)
		sonde._process(STEP)
	var bilan: Dictionary = sonde.bilan()
	var proches := 0
	for p: String in bilan.resume:
		proches += int(bilan.resume[p].couples_images_proches)
	metrics.images = bilan.images
	metrics.couples_proches = proches
	check(int(bilan.images) == 20, "every frame is measured (%d)" % bilan.images)
	# c (avec piste) et d (sans piste), à 1,2 m : mesurés à chaque image.
	check(proches >= 20, "the carrier with a track and the opponent without one are measured each frame (%d)" % proches)
	for p: String in bilan.resume:
		var r: Dictionary = bilan.resume[p]
		check(r.has("penetration_moyenne_m"), "%s: mean penetration reported" % p)
		check(r.get("membres") is Dictionary and (r.membres as Dictionary).size() == 4, "%s: four limb categories reported" % p)
		for c: String in r.get("membres", {}):
			check(r.membres[c].has("moyenne_m") and r.membres[c].has("images") and r.membres[c].has("episodes"), "%s/%s: counts, frames, mean" % [p, c])
	print("SONDE_CONTACTS_CHECKS ", JSON.stringify({"failures": failures, "metrics": metrics}))
	sonde.queue_free()
	view.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)
