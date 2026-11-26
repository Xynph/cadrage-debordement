extends SceneTree
## Fil de l'écran intermédiaire au retour d'un temps fort (godot-match-fil-apres-temps-fort.cjs prépare la carrière
## Monde et joue le vrai match du moteur) : vraie interface, vraie régie, vrai terrain 2D. Chaque séquence réelle
## (direct du temps fort, puis direct de la minute suivante) passe par receive ; au retour de l'écran intermédiaire,
## le fil doit montrer le dernier fait montré en 3D (fin du temps fort), pas un fait d'avant lui, et la ligne
## d'état suivre le même fait. Match filmé du 26/11 : fil resté à la 1′ après un essai à la 4′.
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const Between = preload("res://ui/contextual/match_between.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_MATCH_FIL_ARTIFACTS")

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

## Indice (journal du moteur) de la dernière ligne affichée dans le fil, -1 si aucune.
static func fil_affiche(ecran: Control) -> int:
	var lignes: Array = (ecran.fil as Node).find_children("MatchBetweenFeedLine", "", true, false) if ecran.fil is Node else []
	return int((lignes[-1] as Node).get_meta("i", -1)) if not lignes.is_empty() else -1

## Dernière entrée du fil (direct.fil) jouée par le terrain 2D (indice < prochain fait à jouer), -1 si aucune.
static func fil_attendu(ecran: Control) -> int:
	var prochain: int = ecran.terrain.prochain_i()
	var attendu := -1
	for entree: Variant in ecran._lignes:
		var i := int(entree.get("i", -1)) if entree is Dictionary else -1
		if prochain >= 0 and i >= prochain: continue
		attendu = maxi(attendu, i)
	return attendu

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
	# Le moteur de ce Godot reste en pause : seules les séquences du vrai match alimentent la régie.
	if not app.model.live.get("paused", false): await command("pause", {"paused": true})
	await settle(10)
	var regie: Node = view.regie
	var ecran: Control = regie.between
	limite = Time.get_ticks_msec() + 60000
	while regie.etat == Regie.JEU and Time.get_ticks_msec() < limite: await process_frame
	var donnees: Variant = JSON.parse_string(FileAccess.get_file_as_string(proof.path_join("vrai-match.json")))
	var sequences: Array = donnees.get("sequences", []) if donnees is Dictionary else []
	var lus := 0
	for sequence: Array in sequences:
		var tf_live: Dictionary = (sequence[0] as Dictionary).duplicate()
		var suite: Dictionary = (sequence[1] as Dictionary).duplicate()
		# Match en cours, comme dans le jeu : à la fin du temps fort, la 3D reste à l'écran (ATTENTE) jusqu'au direct de la
		# minute suivante. La régie est arrêtée dès qu'elle l'attend : elle ne demande rien au moteur de ce Godot, et la
		# minute suivante est celle du vrai match (en pause : l'écran intermédiaire n'en redemande pas d'autre).
		tf_live["paused"] = false
		suite["paused"] = true
		var tf: Dictionary = tf_live.direct.tempsFort
		regie.receive(app.model, tf_live)
		if regie.etat != Regie.JEU: continue
		limite = Time.get_ticks_msec() + 120000
		while regie.etat == Regie.JEU and Time.get_ticks_msec() < limite: await process_frame
		regie.set_process(false)
		# Arrêt-décision (carton…) ou sortie : la régie passe seule à l'écran intermédiaire, sans attendre la minute.
		if regie.etat != Regie.ATTENTE:
			regie.set_process(true)
			continue
		# Minute suivante : la régie quitte la 3D pour l'écran intermédiaire (receive → _vers_inter).
		regie.receive(app.model, suite)
		regie.set_process(true)
		ecran.terrain.gel = true
		await settle(2)
		if regie.etat != Regie.INTER: continue
		lus += 1
		var fin := int(tf.get("fin", -1))
		var affiche := fil_affiche(ecran)
		var attendu := fil_attendu(ecran)
		var events: Array = suite.get("events", [])
		var minute_de := func(i: int) -> String: return str(events[i].get("min", "?")) if i >= 0 and i < events.size() and events[i] is Dictionary else "?"
		print("MATCH_FIL_SEQUENCE ", JSON.stringify({"tf": tf.get("horlogeDebut", ""), "fin": fin, "borne_tf": tf_live.direct.get("borne", -1), "borne_suite": suite.direct.get("borne", -1),
			"fil": affiche, "attendu": attendu, "joue_i": ecran.terrain.joue_i, "prochain": ecran.terrain.prochain_i(), "lignes": (ecran._lignes as Array).map(func(e: Variant) -> int: return int(e.get("i", -1)))}))
		check(affiche == attendu, "Temps fort %s (fin %d) : le fil montre le dernier fait joué (fil i=%d à la %s′, attendu i=%d à la %s′, terrain joue_i=%d)" % [
			str(tf.get("horlogeDebut", "")), fin, affiche, minute_de.call(affiche), attendu, minute_de.call(attendu), int(ecran.terrain.joue_i)])
		# Ligne d'état : le fait que montre le terrain (en retard) ou, à jour, la possession du dernier fait montré.
		var etat_lu := str(ecran.etat.text)
		if ecran.terrain.en_retard():
			var vu := Between.etat_du_deroule(ecran.terrain.joue, suite.get("teams", []))
			check(vu.is_empty() or etat_lu == vu, "Temps fort %s : la ligne d'état suit le fait joué (%s, attendu %s)" % [str(tf.get("horlogeDebut", "")), etat_lu, vu])
		ecran.terrain.gel = false
	print("MATCH_FIL_TEMPS_FORT_SEQUENCES ", lus)
	check(lus >= 2, "Au moins deux retours de temps fort relus (%d)" % lus)
	finir()

func finir() -> void:
	print("MATCH_FIL_TEMPS_FORT %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
