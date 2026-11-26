extends SceneTree
## Arrêts de jeu rares dans le VRAI écran du match (godot-match-arrets-ecran.cjs prépare la carrière Monde) :
## vraie interface, vraie régie des temps forts, vraie liaison 3D (match_liaison.gd) et vrai écran intermédiaire
## (terrain 2D, bandeau, carte d'arrêt, horloge). Le moteur est mis en pause, puis la régie reçoit une suite
## scriptée de faits du moteur (même forme que native/engine/match-direct.cjs) :
##   1. en-avant de A (dernier plan 3D), liaison : en-avant de B, puis mêlée pour A ;
##   2. les mêmes faits rejoués par le terrain 2D de l'écran intermédiaire ;
##   3. carton (carte ouverte, terrain 2D en retard de deux minutes), reprise, puis blessure.
## Le texte rendu (bandeau, carte, horloge) est relu à chaque étape ; une capture PNG par étape quand le jeu est rendu.
## Vérificateur de #1319 : « En-avant » sans équipe, carte « CARTON JAUNE · 33′ » sous une horloge à 31:59.
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const Between = preload("res://ui/contextual/match_between.gd")
const Liaison = preload("res://match_liaison.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_MATCH_ARRETS_ARTIFACTS")
var captures := 0

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

func capture(nom: String) -> void:
	if DisplayServer.get_name() == "headless" or captures >= 5: return
	captures += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(proof.path_join("%d-%s.png" % [captures, nom]))

## Quinze joueurs par équipe autour de `centre` : forme du moteur (scène 3D) et forme compacte du terrain 2D.
func joueurs(centre: Vector2) -> Array:
	var liste: Array = []
	for side in 2:
		for slot in 15:
			var p := centre + Vector2((slot % 5) * 1.6 - 3.2 + (side * 2 - 1) * 1.2, (slot / 5) * 3.0 + side * 0.8)
			liste.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot, "x": clampf(p.x, 1.0, 99.0), "y": clampf(p.y, 1.0, 69.0), "featured": false})
	return liste

func compacts(centre: Vector2) -> Array:
	return joueurs(centre).map(func(p: Dictionary) -> Array: return [p.side, p.slot, p.x, p.y, 0, p.id])

## Fait du terrain 2D (élément de direct.deroule).
func fait_2d(i: int, minute: int, kind: String, equipe: int, possession: int, x: float, texte: String) -> Dictionary:
	return {"i": i, "minute": minute, "horloge": "%d′" % minute, "kind": kind, "equipe": equipe, "texte": texte,
		"scene": {"kind": kind, "possession": possession, "periode": 1, "ballon": [x, 30.0], "origine": [x, 30.0], "joueurs": compacts(Vector2(x, 30))}}

func pastille(ecran: Control) -> bool:
	var tag: Node = ecran.phrase_fm.find_child("MatchBetweenPlayLineTag", true, false) if is_instance_valid(ecran.phrase_fm) else null
	return tag != null and not tag.is_queued_for_deletion()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
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
	# Le moteur reste en pause : seule la suite scriptée alimente la régie (sa lecture propre est coupée).
	if not app.model.live.get("paused", false): await command("pause", {"paused": true})
	await settle(10)
	var regie: Node = view.regie
	regie.set_process(false)
	var ecran: Control = regie.between
	var vrai_live: Dictionary = app.model.live
	var equipes: Array = vrai_live.get("teams", [])
	var nom_a: String = Between.etat_du_fait("try", 0, NAN, equipes).trim_prefix("Essai — ")
	var nom_b: String = Between.etat_du_fait("try", 1, NAN, equipes).trim_prefix("Essai — ")
	check(not nom_a.is_empty() and not nom_b.is_empty() and nom_a != nom_b, "Fixture : deux clubs nommés (%s, %s)" % [nom_a, nom_b])

	# --- 1. Temps fort 3D fini sur l'en-avant de A ; liaison : en-avant de B, puis mêlée pour A ------------------
	var events_tf: Array = [
		{"scene": {"kind": "carry", "team": 0, "possession": 0}, "text": "Course."},
		{"scene": {"kind": "hand-fault", "team": 0, "possession": 0, "cause": "knock-on", "ball": {"x": 45.0, "y": 30.0}}, "text": "A commet un en-avant : introduction adverse."},
		{"scene": {"kind": "scrum", "possession": 1}, "text": "Mêlée."},
		{"scene": {"kind": "carry", "team": 1, "possession": 1}, "text": "Course."},
		{"scene": {"kind": "hand-fault", "team": 1, "possession": 1, "cause": "knock-on", "ball": {"x": 55.0, "y": 30.0}}, "text": "B commet un en-avant : introduction adverse."},
		{"scene": {"kind": "scrum", "possession": 0}, "text": "Mêlée pour A."},
	]
	var melee_scene := {"kind": "scrum", "possession": 0, "origin": {"x": 55, "y": 30}, "ball": {"x": 55, "y": 30}, "players": joueurs(Vector2(55, 30))}
	var tf1 := {"cle": "arrets-a", "plans": [{"index": 1, "kind": "hand-fault", "horloge": "31′", "texte": "A commet un en-avant.", "scene": events_tf[1].scene}], "debut": 0, "fin": 1}
	var tf2 := {"cle": "arrets-b", "plans": [{"index": 5, "kind": "scrum", "horloge": "31′", "texte": "Mêlée pour A.", "scene": melee_scene}], "debut": 2, "fin": 5}
	var info := Liaison.analyser(tf1, tf2, events_tf)
	check(str(info.get("type", "")) == "melee" and bool(info.get("coupe_forcee", false)), "Liaison : en-avant de A, jeu, en-avant de B, mêlée (coupe)")
	var ecran_3d: Dictionary = {}
	for p: Dictionary in joueurs(Vector2(47, 30)): ecran_3d[p.id] = {"p": Vector2(p.x, p.y), "v": Vector2.ZERO}
	var lien := Liaison.construire(info, ecran_3d, {"p": Vector3(45.0, 0.1, -30.0), "porteur": ""}, Vector2(45, 25), 41)
	regie._teams = equipes
	regie._score = [0, 0]
	regie.tf = tf1
	regie.etat = Regie.JEU
	regie.index = 0
	regie.phase = "jeu"
	regie.temps = 5.0
	regie._essai_montre = true
	regie._jalon_montre = true
	regie._montrer_jeu(true)
	regie._habiller()
	await settle(6)
	var lu_3d: Array = [str(ecran.etat.text)]
	await capture("3d-en-avant-A")
	regie.liaison = lien
	regie.phase = "liaison"
	for k in (lien.bandeaux as Array).size():
		regie._liaison_plan = k
		regie._habiller()
		await settle(4)
		lu_3d.append(str(ecran.etat.text))
		if k == 1: await capture("liaison-en-avant-B")
	regie.tf = tf2
	regie.phase = "jeu"
	regie.index = 0
	regie._habiller()
	await settle(4)
	lu_3d.append(str(ecran.etat.text))
	var voulu_3d := ["En-avant — " + nom_a, "En-avant — " + nom_a, "En-avant — " + nom_b, "Mêlée pour " + nom_a]
	check(lu_3d == voulu_3d, "3D et liaison : chaque en-avant nomme l'équipe fautive, puis la mêlée (%s)" % str(lu_3d))

	# --- 2. Écran intermédiaire : les mêmes faits joués par le terrain 2D ----------------------------------------
	regie.tf = {}
	regie.liaison = {}
	regie._vers_inter()
	await settle(30)
	check(ecran.is_visible_in_tree(), "L'écran intermédiaire est à l'écran")
	var base := maxi(1000, (vrai_live.get("events", []) as Array).size() + 50)
	var deroule: Array = [
		fait_2d(base, 31, "hand-fault", 0, 0, 45.0, "A commet un en-avant : introduction adverse."),
		fait_2d(base + 1, 31, "scrum", 1, 1, 45.0, "Mêlée pour B."),
		fait_2d(base + 2, 31, "hand-fault", 1, 1, 55.0, "B commet un en-avant : introduction adverse."),
		fait_2d(base + 3, 31, "scrum", 0, 0, 55.0, "Mêlée pour A."),
		fait_2d(base + 4, 31, "carry", 0, 0, 60.0, "A avance."),
		fait_2d(base + 5, 33, "card", 1, 0, 60.0, "Carton jaune pour Paul DURAND : exclusion de 10 minutes de jeu."),
		fait_2d(base + 6, 34, "carry", 0, 0, 64.0, "A avance."),
	]
	var events_live: Array = (vrai_live.get("events", []) as Array).duplicate()
	while events_live.size() < base + 8: events_live.append({"min": 31, "text": "Jeu.", "type": "play"})
	var direct_base: Dictionary = (vrai_live.get("direct", {}) as Dictionary).duplicate(true)
	direct_base.erase("tempsFort")
	direct_base.erase("arret")
	var envoyer := func(minute: int, horloge: String, montree: String, faits: int, reperes: Array, arret: Dictionary, pause: bool) -> void:
		var live: Dictionary = vrai_live.duplicate()
		var direct: Dictionary = direct_base.duplicate(true)
		direct["deroule"] = deroule.slice(0, faits)
		direct["borne"] = base + faits
		direct["horloge"] = horloge
		direct["horlogeMontree"] = montree
		direct["possession"] = 0
		direct["zone"] = {"x": 60.0, "kind": "carry"}
		direct["reperes"] = reperes
		if not arret.is_empty(): direct["arret"] = arret
		live["direct"] = direct
		live["events"] = events_live.slice(0, base + faits)
		live["minute"] = minute
		live["paused"] = pause
		live["atBreak"] = false
		live["finished"] = false
		regie.receive(app.model, live)
	ecran.terrain.gel = true
	envoyer.call(31, "31′", "31′", 5, [], {}, true)
	var lu_2d: Array = []
	for k in 4:
		ecran.terrain.gel = true
		ecran.terrain.avancer(10.0)
		await settle(3)
		lu_2d.append(str(ecran.etat.text))
		if k == 2: await capture("ecran-en-avant-B")
	check(lu_2d == ["En-avant — " + nom_a, "Mêlée pour " + nom_b, "En-avant — " + nom_b, "Mêlée pour " + nom_a],
		"Écran intermédiaire : en-avant de A, mêlée, en-avant de B, mêlée, chaque en-avant avec l'équipe fautive (%s)" % str(lu_2d))

	# --- 3. Carton (terrain 2D encore à la 31′), reprise, puis blessure -----------------------------------------
	ecran.terrain.avancer(10.0)
	var carton := {"cle": "carton-%d" % (base + 5), "raison": "carton", "rouge": false, "pourNous": true, "texte": "Carton jaune pour Paul DURAND : exclusion de 10 minutes de jeu.", "horloge": "33′"}
	var reperes := [{"kind": "card", "nom": "Paul DURAND", "minute": 33, "rouge": false}]
	envoyer.call(33, "33′", "31′", 6, reperes, carton, true)
	await settle(6)
	var titre := str(ecran.arret_titre.text) if is_instance_valid(ecran.arret_titre) else ""
	var horloge := str(view.clock.text)
	check(ecran.terrain.en_retard() and ecran.terrain.horloge_montree() == "31′", "Fixture : le terrain 2D montre encore la 31′ quand la carte s'ouvre")
	check(titre == "CARTON JAUNE · 33′", "Carte d'arrêt du carton (%s)" % titre)
	check(horloge.split(":")[0] == "33", "Carte et horloge : même minute, « CARTON JAUNE · 33′ » et %s" % horloge)
	check(str(ecran.etat.text) == "Carton jaune pour Paul DURAND" and pastille(ecran), "Carton ouvert : le bandeau dit le carton, avec sa pastille (%s)" % str(ecran.etat.text))
	await capture("carton")
	# Reprise du jeu : la carte se ferme, le terrain joue le carton puis la course suivante.
	envoyer.call(33, "33′", "33′", 6, reperes, {}, false)
	await settle(4)
	ecran.terrain.gel = true
	for k in 2:
		ecran.terrain.avancer(10.0)
		await settle(2)
	var reprise_horloge := str(view.clock.text)
	check(reprise_horloge.split(":")[0] == "33", "Après la carte : l'horloge ne recule pas (%s)" % reprise_horloge)
	var blessure := {"cle": "incident-arrets-%d" % (base + 6), "raison": "blessure", "rouge": false, "pourNous": false, "texte": "Blessure : Jean MARTIN doit quitter le terrain.", "horloge": "34′"}
	envoyer.call(34, "34′", "34′", 7, reperes, blessure, true)
	ecran.terrain.gel = true
	ecran.terrain.avancer(10.0)
	await settle(6)
	var titre_b := str(ecran.arret_titre.text) if is_instance_valid(ecran.arret_titre) else ""
	var horloge_b := str(view.clock.text)
	check(titre_b == "BLESSURE · 34′", "Carte d'arrêt de la blessure (%s)" % titre_b)
	check(horloge_b.split(":")[0] == "34", "Blessure : carte et horloge à la même minute (%s)" % horloge_b)
	check(not str(ecran.etat.text).contains("Carton") and not pastille(ecran), "Blessure après le carton : ni carton ni pastille au bandeau (%s)" % str(ecran.etat.text))
	await capture("blessure-apres-carton")
	finir()

func finir() -> void:
	print("MATCH_ARRETS_ECRAN %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
