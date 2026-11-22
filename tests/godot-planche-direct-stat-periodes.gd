extends SceneTree
## Évolution d'un chiffre du direct (choix de Léo, 22/11/2026) : en 2e mi-temps, entre deux temps forts,
## un chiffre de l'écran 2D ouvre sa petite fenêtre (match en pause), avec l'évolution par tranche de 10 minutes : parts
## possession en courbe du match, occupation en frise, taux en barres, comptes en courbes, aux tailles de CD_PLANCHE_TAILLES (2560 × 1440 puis 1920 × 1080).
## Contrôles : tranches présentes, rien hors de la fenêtre, Échap ferme, on reste dans le direct.
## godot-planche-direct-stat-periodes.cjs prépare la carrière Monde.
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_PLANCHE_STAT_PERIODES")

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

func until(condition: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	return condition.call()

func capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dossier.path_join(nom + ".png"))

func vue_2d(view: Control) -> bool:
	return is_instance_valid(view) and view.regie != null and view.regie.etat == view.regie.INTER and view.regie.between.is_visible_in_tree()

func premier(racine: Node, motif: String) -> Button:
	for n: Node in racine.find_children(motif, "Button", true, false):
		if (n as Control).is_visible_in_tree(): return n
	return null

func echap() -> void:
	var touche := InputEventKey.new()
	touche.keycode = KEY_ESCAPE
	touche.physical_keycode = KEY_ESCAPE
	touche.pressed = true
	Input.parse_input_event(touche)
	await settle(4)
	var relache := touche.duplicate()
	relache.pressed = false
	Input.parse_input_event(relache)
	await settle(12)

func run() -> void:
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text": FileAccess.get_file_as_string(dossier.path_join("monde.json"))})
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
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	# Vitesse maximale jusqu'à la 2e mi-temps (consigne : jamais en temps réel dans les tests).
	Engine.time_scale = 8.0
	var minute_voulue := int(OS.get_environment("CD_PLANCHE_MINUTE")) if OS.get_environment("CD_PLANCHE_MINUTE").is_valid_int() else 55
	var depart := Time.get_ticks_msec()
	while Time.get_ticks_msec() - depart < 900000 and int(app.model.live.get("minute", 0)) < minute_voulue and not app.model.live.get("finished", false):
		# Mi-temps, causerie : on passe.
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	print("PLANCHE_STAT minute %d atteinte en %d s" % [int(app.model.live.get("minute", 0)), (Time.get_ticks_msec() - depart) / 1000])
	# La vue du direct est reconstruite à la mi-temps : on reprend la vue courante.
	check(await until(func(): return surface() != null and vue_2d(surface()), 240000), "Écran 2D du direct")
	view = surface()
	if view == null:
		finir()
		return
	Engine.time_scale = 1.0
	if app.model.live.get("finished", false) == false and not app.model.live.get("paused", false): await command("pause", {"paused": true})
	await settle(30)
	var between: Control = view.regie.between
	var tranches: Array = (app.model.live.get("direct", {}) as Dictionary).get("periodes", {}).get("tranches", [])
	check(tranches.size() >= 5, "au moins 5 tranches de 10 minutes en 2e mi-temps (%d)" % tranches.size())
	# Les tranches retombent sur les chiffres du match (mêlées, touches : gagnées / tentées par club).
	var tableau: Array = (app.model.live.get("direct", {}) as Dictionary).get("tableau", [])
	for cle: String in ["melees", "touches"]:
		var total := [[0, 0], [0, 0]]
		for t: Dictionary in tranches:
			for s in 2:
				total[s][0] += int(t.parts[cle][s][0])
				total[s][1] += int(t.parts[cle][s][1])
		for rang: Dictionary in tableau:
			if str(rang.get("cle", "")) == cle:
				var attendu := [[int(rang.valeurs[0]), int(rang.sur[0])], [int(rang.valeurs[1]), int(rang.sur[1])]]
				print("PLANCHE_STAT %s : tranches %s, match %s" % [cle, str(total), str(attendu)])
				check(total == attendu, "%s : somme des tranches %s = chiffres du match %s" % [cle, str(total), str(attendu)])
	var tailles: Array[Vector2i] = []
	for t: String in (OS.get_environment("CD_PLANCHE_TAILLES") if not OS.get_environment("CD_PLANCHE_TAILLES").is_empty() else "2560x1440,1920x1080").split(","):
		tailles.append(Vector2i(t.get_slice("x", 0).to_int(), t.get_slice("x", 1).to_int()))
	for taille: Vector2i in tailles:
		root.size = taille
		root.content_scale_size = taille
		await settle(40)
		# Possession en courbe (G), occupation en frise (F), taux en barres, comptes en courbes (choix de Léo, 22/11/2026).
		for passe: Array in [["G", ["possession"]], ["F", ["occupation"]], ["", ["plaquages_reussis", "penalites"]]]:
			var variante: String = passe[0]
			for cle: String in passe[1]:
				var bouton := premier(between, "MatchBetweenMirror_%s_*" % cle)
				if bouton == null: bouton = premier(between, "MatchBetweenFigure_%s" % cle)
				check(bouton != null, "%s : chiffre « %s » à l'écran" % [str(taille), cle])
				if bouton == null: continue
				bouton.pressed.emit()
				await wait_command()
				await settle(16)
				var fenetre: Control = view.fenetre_hote.find_child("MatchFenetreStatPanneau", true, false) if view.fenetre_ouverte() else null
				check(fenetre != null, "%s %s : petite fenêtre du chiffre" % [str(taille), cle])
				if fenetre == null: continue
				check(bool(app.model.live.get("paused", false)), "%s %s : match en pause à l'ouverture" % [str(taille), cle])
				var periodes := fenetre.find_child("MatchFenetreStatPeriodes", true, false) as Control
				check(periodes != null, "%s %s : évolution par période" % [str(taille), cle])
				var cadre := fenetre.get_global_rect().grow(1.0)
				for n: Node in fenetre.find_children("*", "Control", true, false):
					var c := n as Control
					if c.is_visible_in_tree() and c.size.x >= 1.0 and not cadre.encloses(c.get_global_rect()):
						check(false, "%s %s : %s hors de la fenêtre" % [cle, str(taille), c.name])
						break
				if variante == "G":
					var courbe := fenetre.find_child("MatchFenetreStatCourbe", true, false) as Control
					var bulle_g: String = courbe._get_tooltip(Vector2(courbe.size.x * 34.0 / 80.0, courbe.size.y / 2.0)) if courbe != null else ""
					check(bulle_g.begins_with("34′ · ") and bulle_g.ends_with("%"), "courbe : survol d'une minute (« %s »)" % bulle_g)
				await capture("stat-%s-%dx%d" % [cle, taille.x, taille.y])
				await echap()
				check(not view.fenetre_ouverte(), "%s %s : Échap ferme la fenêtre" % [str(taille), cle])
				check(surface() == view and view.regie != null, "%s %s : on reste dans le direct" % [str(taille), cle])
	finir()

func finir() -> void:
	Engine.time_scale = 1.0
	print("PLANCHE_STAT %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
