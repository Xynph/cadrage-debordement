extends SceneTree
## Planche « Direct en tableau de bord » (revue FM27 de Léo, 22/11/2026) : la variante CD_VARIANTE_VISUELLE (A compositions
## en terrain, B compositions en lignes) capturée en jeu, en 2e mi-temps,
## entre deux temps forts, aux tailles de CD_PLANCHE_TAILLES (2560 × 1440, référence de Léo, puis 1920 × 1080) ; contrôle que rien ne déborde et
## qu'un club du classement ouvre sa petite fenêtre. godot-planche-direct-2d.cjs prépare la carrière Monde.
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
	# Causerie d'avant-match prononcée (premier choix, à tout le groupe) : les réactions des joueurs (moral) existent.
	var dites := {}
	while Time.get_ticks_msec() < limite and (surface() == null or surface().regie == null):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting:
			var cle_scene := "%s/%s" % [str(scene.key), str(scene.phase)]
			var options: Array = scene.get("options", []) if scene.get("options") is Array else []
			if not dites.has(cle_scene) and options.size() > 0 and options[0] is Dictionary:
				dites[cle_scene] = true
				await command("match_talk_decide", {"key": scene.key, "phase": scene.phase, "choiceId": str(options[0].get("id", "")), "audience": "group", "playerIds": []})
				await command("match_talk_continue", {"key": scene.key, "phase": scene.phase})
			else: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	var view := surface()
	check(view != null and view.regie != null, "Le direct en temps forts s'ouvre")
	if view == null or view.regie == null:
		finir()
		return
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	# Vitesse maximale jusqu'à la 2e mi-temps (consigne : jamais en temps réel dans les tests), en petite taille.
	Engine.time_scale = 8.0
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	var minute_voulue := int(OS.get_environment("CD_PLANCHE_MINUTE")) if OS.get_environment("CD_PLANCHE_MINUTE").is_valid_int() else 52
	var depart := Time.get_ticks_msec()
	while Time.get_ticks_msec() - depart < 600000 and int(app.model.live.get("minute", 0)) < minute_voulue and not app.model.live.get("finished", false):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	print("PLANCHE_DIRECT_TABLEAU minute %d atteinte en %d s" % [int(app.model.live.get("minute", 0)), (Time.get_ticks_msec() - depart) / 1000])
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	check(await until(func(): return surface() != null and vue_2d(surface()), 240000), "Écran 2D du direct avec classement et multiplex")
	view = surface()
	if view == null:
		finir()
		return
	Engine.time_scale = 1.0
	# Pause entre deux temps forts : si la pause tombe pendant un temps fort 3D, on relance et on réessaie.
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
	var tailles: Array[Vector2i] = []
	for t: String in (OS.get_environment("CD_PLANCHE_TAILLES") if not OS.get_environment("CD_PLANCHE_TAILLES").is_empty() else "2560x1440,1920x1080").split(","):
		tailles.append(Vector2i(t.get_slice("x", 0).to_int(), t.get_slice("x", 1).to_int()))
	for taille: Vector2i in tailles:
		root.size = taille
		root.content_scale_size = taille
		await settle(40)
		check(vue_2d(view), "%s : classement et multiplex à l'écran" % str(taille))
		check(debordements(between).is_empty(), "%s : rien ne déborde : %s" % [str(taille), str(debordements(between).slice(0, 6))])
		var lignes: int = between.classement_lignes.get_children().filter(func(n: Node): return str(n.name).begins_with("MatchBetweenLiveRow")).size()
		var attendu: int = (between.journee_vue.get("classement", []) as Array).size() if between.journee_vue is Dictionary else -1
		check(lignes == attendu and lignes >= 8, "%s : classement complet (%d lignes sur %d)" % [str(taille), lignes, attendu])
		var bas_tableau: float = between.classement_lignes.get_global_rect().end.y
		var bas_panneau: float = between.panneaux_direct[0].get_global_rect().end.y
		check(bas_tableau <= bas_panneau + 1.0, "%s : classement entier dans son panneau" % str(taille))
		check(not between.defile_xv.get_v_scroll_bar().visible, "%s : Mon XV sans ascenseur" % str(taille))
		check(not between.multiplex_deborde(), "%s : multiplex entier" % str(taille))
		var defile_chiffres := between.find_child("MatchBetweenFiguresScroll", true, false) as ScrollContainer
		check(defile_chiffres != null and not defile_chiffres.get_v_scroll_bar().visible, "%s : chiffres clés sans ascenseur" % str(taille))
		print("PLANCHE_DIRECT_TABLEAU %s : classement %d lignes, multiplex %d matchs" % [str(taille), lignes, between.multiplex_cartes.get_child_count()])
		check(between.compos_fm.size() == 2, "%s : les deux compositions" % str(taille))
		await capture("direct-tableau-%s-%dx%d" % [variante, taille.x, taille.y])
	# Plein écran obligatoire : chaque type d'élément ouvre sa petite fenêtre par-dessus le match ; Échap la ferme et
	# l'on reste dans le direct (2560 × 1440, référence de Léo).
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	await settle(40)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	var premier := func(racine: Node, motif: String, classe: String = "Control") -> Control:
		for n: Node in racine.find_children(motif, classe, true, false):
			if (n as Control).is_visible_in_tree(): return n
		return null
	var nous_camp := int(between._dernier[2].get("camp", 0)) if between._dernier.size() > 2 else 0
	if variante == "A":
		var compo: Control = premier.call(between, "MatchBetweenLineupPitch0")
		await essayer("joueur de notre composition", "MatchFenetreJoueur", "direct-tableau-%s-fenetre-joueur-2560" % variante, func(): compo.choisi.emit("%d:9" % nous_camp), compo != null, view)
	else:
		var rangee: Button = premier.call(between, "MatchBetweenLineupRow0_10", "Button")
		await essayer("ligne de notre composition", "MatchFenetreJoueur", "direct-tableau-%s-fenetre-joueur-2560" % variante, func(): rangee.pressed.emit(), rangee != null, view)
	var barre: Button = premier.call(between, "MatchBetweenMirrorBar_zone22", "Button")
	await essayer("barre miroir", "MatchFenetreStat", "direct-tableau-%s-fenetre-stat-2560" % variante, func(): barre.pressed.emit(), barre != null, view)
	# Le bandeau du score est commun au temps fort 3D : une capture en plein temps fort (match relancé).
	if OS.get_environment("CD_PLANCHE_TEMPS_FORT") == "1":
		if app.model.live.get("paused", false): await command("pause", {"paused": false})
		if await until(func(): return view.regie.etat == view.regie.JEU, 120000):
			await settle(20)
			await capture("direct-3d-temps-fort-2560")
	finir()

## Clic sur un élément : sa petite fenêtre `nom` s'ouvre par-dessus le match (capture), Échap la ferme, le direct reste.
func essayer(element: String, nom: String, fichier: String, action: Callable, present: bool, view: Control) -> void:
	check(present, "%s : présent à l'écran" % element)
	if not present: return
	action.call()
	await wait_command()
	await settle(12)
	var fenetre: Node = view.fenetre_hote.find_child(nom + "*", true, false) if view.fenetre_ouverte() else null
	check(view.fenetre_ouverte() and fenetre != null, "%s : sa petite fenêtre %s" % [element, nom])
	if not fichier.is_empty(): await capture(fichier)
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
	check(not view.fenetre_ouverte(), "%s : Échap ferme la fenêtre" % element)
	check(surface() == view and view.regie != null, "%s : on reste dans le direct" % element)

func finir() -> void:
	print("PLANCHE_DIRECT_TABLEAU %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
