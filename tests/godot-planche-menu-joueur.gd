extends SceneTree
## Planche « menu sur un joueur en match » (idée FM27 n° 32, CD_VARIANTE_VISUELLE=A|B) : en 2e mi-temps, match arrêté, clic
## sur une carte de la bande Mon XV = menu du joueur (poste, rôle, responsabilités, remplaçants) aux tailles de
## CD_PLANCHE_TAILLES ; puis un clic sur un remplaçant fait le changement et la carte sortie / entrée s'affiche sur le
## terrain. godot-planche-menu-joueur.cjs prépare la carrière Monde.
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_PLANCHE_DIRECT_2D")

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

func trace(m: String) -> void:
	var f := FileAccess.open(dossier.path_join("trace.txt"), FileAccess.READ_WRITE if FileAccess.file_exists(dossier.path_join("trace.txt")) else FileAccess.WRITE)
	f.seek_end()
	f.store_line("%d %s" % [Time.get_ticks_msec() / 1000, m])
	f.close()

func capture(nom: String) -> void:
	trace("capture " + nom)
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
	var variante := OS.get_environment("CD_VARIANTE_VISUELLE")
	# Le joueur le plus fatigué de la bande (celui qu'on remplacerait).
	var carte: Button = null
	var plus_bas := 999.0
	for n: Node in between.find_children("MatchBetweenPlayer*", "Button", true, false):
		var b := n as Button
		if not b.is_visible_in_tree() or not b.has_meta("player_id"): continue
		var e := 999.0
		var lineup: Array = app.model.live.get("lineup", [])
		for k in lineup.size():
			# Hors première ligne (3e ligne, charnière, trois-quarts) : plus de remplaçants possibles.
			if k >= 5 and lineup[k] is Dictionary and str(lineup[k].get("id", "")) == str(b.get_meta("player_id")): e = float(lineup[k].get("condition", 100))
		if e < plus_bas:
			plus_bas = e
			carte = b
	check(carte != null, "une carte de Mon XV à cliquer")
	if carte == null:
		finir()
		return
	var nom_carte := str(carte.name)
	for taille: Vector2i in tailles:
		root.size = taille
		root.content_scale_size = taille
		await settle(40)
		carte = la_carte(between, nom_carte)
		trace("clic carte %s" % str(taille))
		carte.pressed.emit()
		await wait_command()
		trace("menu ouvert")
		await settle(16)
		var menu: Variant = view.fenetre_hote.find_child("MatchMenuJoueur*", true, false) if view.fenetre_ouverte() else null
		check(menu != null, "%s : le menu du joueur s'ouvre" % str(taille))
		var lignes: Array = view.fenetre_hote.find_children("MatchMenuJoueurRemplacant*", "Panel", true, false) if view.fenetre_ouverte() else []
		check(lignes.size() >= 5, "%s : la liste des remplaçants (%d)" % [str(taille), lignes.size()])
		var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
		for p: Node in view.fenetre_hote.find_children("MatchMenuJoueur*", "Panel", true, false) if view.fenetre_ouverte() else []:
			if (p as Control).is_visible_in_tree() and not ecran.encloses((p as Control).get_global_rect()): failures.append("%s : %s hors écran" % [str(taille), p.name])
		await capture("menu-joueur-%s-%dx%d" % [variante, taille.x, taille.y])
		if taille == tailles[0] and variante == "A":
			# Le volet des rôles du poste.
			var role := view.fenetre_hote.find_child("MatchMenuJoueurRoleLien", true, false) as Button
			if role != null:
				role.pressed.emit()
				await settle(16)
				await capture("menu-joueur-A-roles-%dx%d" % [taille.x, taille.y])
				var remp := view.fenetre_hote.find_child("MatchMenuJoueurRemplacerLien", true, false) as Button
				if remp != null:
					remp.pressed.emit()
					await settle(16)
		trace("fermer")
		view.fermer_fenetre()
		await settle(10)
		trace("ferme")
	# Le changement d'un clic, puis la carte sortie / entrée sur le terrain.
	root.size = tailles[0]
	root.content_scale_size = tailles[0]
	await settle(30)
	var avant: Array = app.model.live.get("lineup", []).map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else "")
	carte = la_carte(between, nom_carte)
	trace("changement")
	carte.pressed.emit()
	await wait_command()
	await settle(16)
	var premier: Button = null
	for n: Node in view.fenetre_hote.find_children("MatchMenuJoueurRemplacant*Lien", "Button", true, false):
		if (n.get_parent() as Control).modulate.a > .9:
			premier = n
			break
	check(premier != null, "un remplaçant autorisé à ce poste")
	if premier != null:
		trace("clic remplacant")
		premier.pressed.emit()
		await wait_command()
		await settle(30)
		var apres: Array = app.model.live.get("lineup", []).map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else "")
		check(apres != avant, "le changement est fait d'un clic, sans confirmation")
		check(not view.fenetre_ouverte(), "le menu se ferme après le changement")
		for taille: Vector2i in tailles:
			root.size = taille
			root.content_scale_size = taille
			await settle(40)
			check(between.terrain.find_child("MatchChangementCarte", false, false) != null, "%s : carte sortie / entrée sur le terrain" % str(taille))
			await capture("changement-%s-%dx%d" % [variante, taille.x, taille.y])
	finir()

## La carte de Mon XV est reconstruite au changement de taille : on la retrouve par son nom.
func la_carte(between: Control, nom: String) -> Button:
	for n: Node in between.find_children(nom, "Button", true, false):
		if (n as Control).is_visible_in_tree() and not n.is_queued_for_deletion(): return n
	return null

func finir() -> void:
	print("PLANCHE_MENU_JOUEUR %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
