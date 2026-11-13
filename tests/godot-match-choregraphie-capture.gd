extends SceneTree
## Capture de contrôle du chorégraphe (outil manuel, lancé par godot-match-choregraphie-capture.cjs).
## Vue 3D du match seule, cadrage rapproché des temps forts : chaque séquence de
## CD_CHOREGRAPHIE_PISTES est jouée à vitesse réelle (lancer Godot avec --fixed-fps 30 : une
## image par 1/30 s de jeu, quelle que soit la lenteur du rendu) et chaque image est écrite
## dans CD_CHOREGRAPHIE_CAPTURE (img-00001.jpg…), avec report.json (séquences et images).

const View = preload("res://match_view.gd")
const Cadrage = preload("res://match_cadrage.gd")

var report := {"sequences": [], "images": 0}


## Gros plan (CD_CHOREGRAPHIE_GROS_PLAN=1) : plan serré sur le ballon et son porteur, pour juger
## la tenue du ballon et les plaquages (planche d'images). Même interface que match_cadrage.gd.
class GrosPlan extends RefCounted:
	var view
	var centre := Vector3.ZERO
	var pose := false
	func _init(owner) -> void: view = owner
	func regler(_on: bool, _kind: String = "", _longue: bool = false) -> void: pass
	func couper() -> void: pose = true
	func frame_camera(focus: Vector3, size: float, offset: Vector3, _aspect: float, _mode: String, delta: float, _cut: bool = false) -> Array:
		var ballon: Vector3 = view._ball.global_position if view._ball.visible else focus
		var but := Vector3(ballon.x, 0.0, ballon.z)
		centre = but if pose else centre.lerp(but, 1.0 - exp(-4.0 * delta))
		pose = false
		return [centre, 6.5, offset]
	func garder_ballon(look: Vector3, _size: float, _offset: Vector3, _aspect: float) -> Vector3: return look


func _initialize() -> void:
	call_deferred("run")


func start_frame(entree: Dictionary) -> Dictionary:
	var players: Array = []
	for p: Dictionary in entree.joueurs:
		players.append({"id": str(p.id), "side": int(p.side), "slot": int(p.slot), "x": float(p.x), "y": float(p.y),
			"featured": str(p.id) == str(entree.get("porteur", ""))})
	var scene := {"kind": "reception", "key": "[0,\"capture\",\"reception\"]", "possession": int(entree.possession), "team": int(entree.possession),
		"players": players, "ball": entree.ballon, "origin": entree.ballon}
	return {"scene": scene, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}], "events": [], "paused": false}


func run() -> void:
	var dossier := OS.get_environment("CD_CHOREGRAPHIE_CAPTURE")
	var donnees: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_CHOREGRAPHIE_PISTES")))
	if dossier.is_empty() or not donnees is Dictionary:
		push_error("CD_CHOREGRAPHIE_CAPTURE et CD_CHOREGRAPHIE_PISTES requis")
		quit(2)
		return
	var view = View.new()
	root.add_child(view)
	view.set_gestes(true)
	view.set_live_cadence(1)
	var gros_plan := OS.get_environment("CD_CHOREGRAPHIE_GROS_PLAN") == "1"
	var cadrage = GrosPlan.new(view) if gros_plan else Cadrage.new(view)
	view.set_cadrage(cadrage)
	# Gros plan : sans le recadrage des gestes, qui choisirait son propre plan.
	if gros_plan: view.set_gestes(false)
	await process_frame
	for cas: Dictionary in donnees.cas:
		var pistes: Dictionary = cas.pistes
		view.apply_frame(start_frame(cas.entree))
		var genre := str(pistes.get("type", ""))
		cadrage.regler(true, "kick" if genre == "jeu_au_pied" or genre.begins_with("penalite") else "carry", genre == "franchissement")
		cadrage.couper()
		# Une seconde d'image posée avant la séquence (sans pistes : la vue s'installe).
		for i in 2:
			await process_frame
		if not view.jouer_choregraphie(pistes):
			push_error("pistes refusées : " + str(cas.get("titre", "")))
			quit(1)
			return
		cadrage.couper()
		var premiere: int = report.images + 1
		while view.choregraphie_active() and not view.choregraphie_finie():
			await process_frame
			ecrire(dossier)
		# Une seconde de plus sur la dernière image des pistes.
		for i in 30:
			await process_frame
			ecrire(dossier)
		view.arreter_choregraphie()
		report.sequences.append({"titre": str(cas.get("titre", "")), "premiere": premiere, "derniere": report.images, "duree": float(pistes.duree)})
	var f := FileAccess.open(dossier.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()
	print("CAPTURE_CHOREGRAPHIE ", JSON.stringify(report))
	quit(0)


func ecrire(dossier: String) -> void:
	var image := root.get_texture().get_image()
	report.images += 1
	if image == null or image.save_jpg(dossier.path_join("img-%05d.jpg" % report.images), 0.85) != OK:
		push_error("écriture impossible")
