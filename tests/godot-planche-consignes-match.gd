extends SceneTree
## Planche « Consignes en petite fenêtre » (revue FM27 n° 33) : la variante CD_VARIANTE_VISUELLE (A familles en liste,
## B rangée de cartes) capturée en 2e mi-temps aux tailles de CD_PLANCHE_TAILLES (2560 × 1440 puis 1920 × 1080).
## Contrôles : lien « Consignes », fenêtre sans pause, un clic sur un cran l'applique (moteur), Échap ferme.
## Match à vitesse maximale. godot-planche-consignes-match.cjs prépare la carrière Monde.
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_PLANCHE_DIRECT_2D")
var variante := OS.get_environment("CD_VARIANTE_VISUELLE")

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

## Textes coupés ou contrôles hors de leur panneau / de l'écran dans l'écran 2D.
func debordements(between: Control) -> Array[String]:
	var trouves: Array[String] = []
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
	for n: Node in between.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 1.0: continue
		if c.get_parent() is ScrollContainer or c.find_parent("MatchBetweenMultiplexScroll") != null or c.find_parent("MatchBetweenFiguresScroll") != null: continue
		if not ecran.encloses(c.get_global_rect()): trouves.append("%s hors écran %s" % [c.name, str(c.get_global_rect())])
		if c is Label and (c as Label).clip_text == false and (c as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			var l := c as Label
			var largeur := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			if largeur > l.size.x + 2.0: trouves.append("%s coupé (« %s »)" % [l.name, l.text])
	return trouves

func vue_2d(view: Control) -> bool:
	return view.regie != null and view.regie.etat == view.regie.INTER and view.regie.between.is_visible_in_tree() and view.regie.between._journee_montree() and not view.regie.between.panneaux_direct.is_empty() and view.regie.between.panneaux_direct[0].is_visible_in_tree()

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
	# Deux consignes changées tôt : leur bilan existe en 2e mi-temps.
	await command("set_consignes", {"axe": "rucks", "valeur": "agressive"})
	await command("set_consignes", {"axe": "touche", "valeur": "sure"})
	# Vitesse maximale jusqu'à la 2e mi-temps (jamais en temps réel dans les tests), en petite taille.
	Engine.time_scale = 8.0
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	var minute_voulue := int(OS.get_environment("CD_PLANCHE_MINUTE")) if OS.get_environment("CD_PLANCHE_MINUTE").is_valid_int() else 52
	var depart := Time.get_ticks_msec()
	while Time.get_ticks_msec() - depart < 600000 and int(app.model.live.get("minute", 0)) < minute_voulue and not app.model.live.get("finished", false):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	print("PLANCHE_CONSIGNES minute %d atteinte en %d s" % [int(app.model.live.get("minute", 0)), (Time.get_ticks_msec() - depart) / 1000])
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	check(await until(func(): return surface() != null and vue_2d(surface()), 240000), "Écran 2D du direct")
	view = surface()
	if view == null:
		finir()
		return
	Engine.time_scale = 1.0
	# Pause entre deux temps forts, pour des captures stables (la fenêtre, elle, ne met jamais en pause).
	for essai in 20:
		if app.model.live.get("finished", false): break
		if not await until(func(): return surface() != null and vue_2d(surface()), 120000): break
		if not app.model.live.get("paused", false): await command("pause", {"paused": true})
		await settle(20)
		view = surface()
		if view != null and vue_2d(view): break
		await command("pause", {"paused": false})
		await settle(10)
	await settle(30)
	var between: Control = view.regie.between
	check(is_instance_valid(between.lien_consignes) and between.lien_consignes.is_visible_in_tree(), "Lien « Consignes » dans la barre")
	var pause_avant: bool = app.model.live.get("paused", false)
	var tailles: Array[Vector2i] = []
	for t: String in (OS.get_environment("CD_PLANCHE_TAILLES") if not OS.get_environment("CD_PLANCHE_TAILLES").is_empty() else "2560x1440,1920x1080").split(","):
		tailles.append(Vector2i(t.get_slice("x", 0).to_int(), t.get_slice("x", 1).to_int()))
	for taille: Vector2i in tailles:
		root.size = taille
		root.content_scale_size = taille
		await settle(40)
		view.consignes_axe = "rucks"
		between.lien_consignes.pressed.emit()
		await settle(20)
		check(view.fenetre_ouverte() and view.fenetre_hote.find_child("MatchFenetreConsignes*", true, false) != null, "%s : fenêtre des consignes ouverte" % str(taille))
		check(app.model.live.get("paused", false) == pause_avant, "%s : la fenêtre ne touche pas à la pause" % str(taille))
		await capture("consignes-%s-%dx%d" % [variante, taille.x, taille.y])
		view.fermer_fenetre()
		await settle(8)
	# Un clic sur un cran l'applique tout de suite (pas de bouton Confirmer) ; la fenêtre reste ouverte.
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	await settle(30)
	view.consignes_axe = "piedJeu"
	between.lien_consignes.pressed.emit()
	await settle(12)
	var choix: Button = view.fenetre_hote.find_child("MatchFenetreConsignesChoix_plus", true, false) if view.fenetre_ouverte() else null
	check(choix != null, "Cran « Occuper » cliquable")
	if choix != null:
		choix.pressed.emit()
		await wait_command()
		await settle(12)
		var p: Dictionary = app.model.live.get("pilotage", {})
		check(str((p.get("consignes", {}) as Dictionary).get("piedJeu", "")) == "plus", "Clic = consigne appliquée par le moteur")
		check(view.fenetre_ouverte(), "La fenêtre reste ouverte après le choix")
		await capture("consignes-%s-clic-2560" % variante)
	var echap := InputEventKey.new()
	echap.keycode = KEY_ESCAPE
	echap.physical_keycode = KEY_ESCAPE
	echap.pressed = true
	Input.parse_input_event(echap)
	await settle(4)
	var relache := echap.duplicate()
	relache.pressed = false
	Input.parse_input_event(relache)
	await settle(12)
	check(not view.fenetre_ouverte(), "Échap ferme la fenêtre")
	check(surface() == view, "On reste dans le direct")
	finir()

func finir() -> void:
	print("PLANCHE_CONSIGNES %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
