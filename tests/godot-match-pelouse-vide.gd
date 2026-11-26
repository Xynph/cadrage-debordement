extends SceneTree
## Pelouse vide en transition dans le VRAI écran du match (godot-match-pelouse-vide.cjs prépare la carrière Monde et
## un vrai match du moteur : un temps fort qui finit sur un tir au but, l'écran intermédiaire, puis le temps fort
## suivant). Ses vrais plans et événements passent par la vraie régie (receive), la vraie vue 3D et le vrai écran
## intermédiaire. À chaque image où la 3D se voit (voile et écran intermédiaire pas encore opaques), au moins un
## joueur doit être dans le champ de la caméra (sonde de tools/match-filme/sonde_pelouse.gd, celle des films).
## Film 1305c/film-2 image 0588, films du 26/11 : pelouse sans joueur pendant les fondus d'entrée et de sortie.
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_MATCH_PELOUSE_ARTIFACTS")
var Sonde: GDScript
## Déplacement de la caméra d'une image à l'autre au-delà duquel c'est une coupe (m) : un suivi amorti en fait moins d'un.
const SAUT_CAMERA := 4.0
var camera_avant := Vector3.INF
var coupes_dans_fondu: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func settle(frames: int = 8) -> void:
	for i in frames: await process_frame

func wait_command(limit_ms: int = 60000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle(3)

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_command()

func surface() -> Control:
	return app.contextual_director.view if app.contextual_director.active() and app.contextual_director.kind == "live" else null

## Images rendues jusqu'à ce que la régie soit sortie du temps fort et que le fondu soit fini (au moins `minimum` s).
## Chaque image où la 3D se voit est relue par la sonde ; rend le nombre d'images vides et le détail de la première.
func regarder(regie: Node, sonde: RefCounted, etape: String, minimum: float, bilan: Dictionary) -> void:
	var debut := Time.get_ticks_msec()
	var limite := debut + 90000
	var vides_avant: int = sonde.vides
	var episodes_avant: int = sonde.pires.size()
	while Time.get_ticks_msec() < limite:
		await process_frame
		sonde.observer(regie, (Time.get_ticks_msec() - debut) / 1000.0, 0)
		# Fondu vers l'écran intermédiaire : la 3D se voit encore, la caméra ne doit pas couper ailleurs.
		var camera: Camera3D = (regie.stage as Node).get("_camera")
		var couv: float = Sonde.couverture(regie)
		if camera != null:
			if regie.etat == Regie.INTER and couv < Sonde.COUVERTURE_MAX and camera_avant.is_finite() and camera.global_position.distance_to(camera_avant) > SAUT_CAMERA:
				coupes_dans_fondu.append({"etape": etape, "saut_m": snappedf(camera.global_position.distance_to(camera_avant), 0.1), "couverture": snappedf(couv, 0.01), "joueurs": Sonde.joueurs_visibles(regie.stage)})
			camera_avant = camera.global_position
		var fondu: Variant = regie.get("_fondu")
		var en_fondu: bool = fondu is Tween and (fondu as Tween).is_valid() and (fondu as Tween).is_running()
		if regie.etat != Regie.JEU and not en_fondu and Time.get_ticks_msec() - debut >= int(minimum * 1000.0): break
	var vides: int = sonde.vides - vides_avant
	bilan[etape] = vides
	if vides > 0 and sonde.pires.size() > episodes_avant:
		print("PELOUSE_VIDE ", etape, " ", JSON.stringify(sonde.pires[episodes_avant]))

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	Sonde = load((get_script() as Script).resource_path.get_base_dir().path_join("../tools/match-filme/sonde_pelouse.gd"))
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("monde.json"))})
	await command("begin_match")
	var limite := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < limite and (surface() == null or surface().regie == null):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	var view := surface()
	check(view != null and view.regie != null, "Le direct en temps forts s'ouvre")
	if view == null or view.regie == null:
		finir()
		return
	# Le moteur reste en pause : seul le vrai match enregistré alimente la régie.
	if not app.model.live.get("paused", false): await command("pause", {"paused": true})
	var regie: Node = view.regie
	# Le temps fort du coup d'envoi de ce Godot finit d'abord.
	limite = Time.get_ticks_msec() + 60000
	while regie.etat == Regie.JEU and Time.get_ticks_msec() < limite: await process_frame
	await settle(10)
	var donnees: Variant = JSON.parse_string(FileAccess.get_file_as_string(proof.path_join("vrai-match.json")))
	var vies: Array = donnees.get("vies", []) if donnees is Dictionary else []
	var events: Array = donnees.get("events", []) if donnees is Dictionary else []
	check(vies.size() >= 20, "Vrai match : la première mi-temps minute par minute (%d minutes)" % vies.size())
	if vies.size() < 20:
		finir()
		return
	var sonde: RefCounted = Sonde.new()
	var bilan: Dictionary = {}
	# Couverture : entrées d'un temps fort depuis l'écran intermédiaire, dont après un temps fort fini aux poteaux ;
	# sorties vers l'écran intermédiaire après un tel temps fort.
	var entrees := 0
	var entrees_apres_tir := 0
	var sorties_apres_tir := 0
	var aux_poteaux := false
	var sortie_attendue := false
	for n in vies.size():
		var live: Dictionary = (vies[n] as Dictionary).duplicate()
		live["events"] = events.slice(0, int(live.get("nombreEvents", events.size())))
		live.erase("nombreEvents")
		# Pause : la régie ne redemande aucune minute au moteur de ce Godot (le temps fort se joue quand même).
		live["paused"] = true
		var etat_avant: int = regie.etat
		var cle_avant := str(regie.tf.get("cle", ""))
		regie.receive(app.model, live)
		var tf_vu: bool = regie.etat == Regie.JEU and str(regie.tf.get("cle", "")) != cle_avant
		if tf_vu and etat_avant == Regie.INTER:
			entrees += 1
			if aux_poteaux: entrees_apres_tir += 1
		if not tf_vu and regie.etat == Regie.INTER and sortie_attendue: sorties_apres_tir += 1
		sortie_attendue = false
		if tf_vu:
			var plans: Array = regie.tf.get("plans", [])
			aux_poteaux = not plans.is_empty() and str(plans[plans.size() - 1].get("kind", "")) in ["goal", "miss", "transformation"]
			sortie_attendue = aux_poteaux
		var etape := "%s:%s" % [str(live.get("minute", n)), "temps_fort" if tf_vu else ("intermediaire" if regie.etat == Regie.INTER else str(regie.etat))]
		# Un fondu dure Regie.FONDU : on regarde au moins deux fois plus longtemps.
		await regarder(regie, sonde, etape, Regie.FONDU * 2.0 + 0.3, bilan)
	var vides_par_etape: Dictionary = {}
	for k: String in bilan:
		if int(bilan[k]) > 0: vides_par_etape[k] = bilan[k]
	print("MATCH_PELOUSE_VIDE_BILAN ", JSON.stringify({"images_3d": sonde.images, "pelouse_vide": sonde.vides, "episodes": sonde.pires.size(), "entrees": entrees,
		"entrees_apres_tir": entrees_apres_tir, "sorties_apres_tir": sorties_apres_tir, "vides_par_etape": vides_par_etape, "coupes_dans_fondu": coupes_dans_fondu}))
	check(coupes_dans_fondu.is_empty(), "Fondu vers l'écran intermédiaire : la caméra ne coupe pas tant que la 3D se voit (%s)" % JSON.stringify(coupes_dans_fondu))
	check(sonde.images > 300, "La 3D est regardée image par image (%d images)" % sonde.images)
	check(entrees_apres_tir >= 1, "Un temps fort part de l'écran intermédiaire après un tir au but ou une transformation (%d)" % entrees_apres_tir)
	check(sorties_apres_tir >= 1, "Un tir au but ou une transformation est suivi de l'écran intermédiaire (%d)" % sorties_apres_tir)
	check(sonde.vides == 0, "Aucune image de pelouse vide pendant les fondus et les temps forts (%d images vides, %d épisodes : %s)" % [sonde.vides, sonde.pires.size(), JSON.stringify(vides_par_etape)])
	finir()

func finir() -> void:
	print("MATCH_PELOUSE_VIDE %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
