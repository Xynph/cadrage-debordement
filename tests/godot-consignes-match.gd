extends SceneTree
## Consignes en petite fenêtre pendant le match (idée FM27 n° 33, choix B de Léo) : lien « Consignes », fenêtre sans
## pause, un clic sur un cran le met dans la file du prochain arrêt de jeu (plan de jeu compris), clic sur le cran en
## place = demande retirée, avis du staff en tendance sans chiffre, application au premier arrêt, Échap ferme.
## Captures final-*.png en 2560 × 1440 et 1920 × 1080. Match à vitesse maximale. godot-consignes-match.cjs prépare la carrière.
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_CAPTURES_CONSIGNES")

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

## Textes coupés, points de suspension compris (la petite fenêtre suit le cadre commun du direct, à l'échelle du gabarit).
func debordements(between: Control) -> Array[String]:
	var trouves: Array[String] = []
	for n: Node in between.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 1.0: continue
		if c.get_parent() is ScrollContainer or c.find_parent("MatchBetweenMultiplexScroll") != null or c.find_parent("MatchBetweenFiguresScroll") != null: continue
		if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF and (c as Label).get_line_count() > (c as Label).get_visible_line_count():
			trouves.append("%s coupé (« %s »)" % [c.name, (c as Label).text])
		if c is Label and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
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
	print("CONSIGNES_MATCH minute %d atteinte en %d s" % [int(app.model.live.get("minute", 0)), (Time.get_ticks_msec() - depart) / 1000])
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
	check(app.model.live.get("paused", false), "Match en pause pour des captures stables")
	var tailles: Array[Vector2i] = [Vector2i(2560, 1440), Vector2i(1920, 1080)]
	# 1) Un clic sur un cran : il part dans la file du prochain arrêt de jeu, rien ne change encore dans le moteur.
	view.consignes_axe = "piedJeu"
	between.lien_consignes.pressed.emit()
	await settle(20)
	check(view.fenetre_ouverte() and fenetre() != null, "Fenêtre des consignes ouverte")
	check(app.model.live.get("paused", false), "La fenêtre ne touche pas à la pause")
	check(fenetre() != null and fenetre().find_children("MatchFenetreConsignesCarteAxe_*", "", true, false).size() == 14, "14 cartes : 11 consignes en direct et le plan de jeu")
	check(fenetre() != null and fenetre().find_children("Tendance_*", "", true, false).size() >= 6, "Pour / Contre en tendances")
	check(chiffres_dans_les_lignes().is_empty(), "Aucun chiffre dans l'avis du staff : %s" % str(chiffres_dans_les_lignes()))
	check(fenetre() != null and fenetre().find_child("MatchFenetreConsignesFiabilite", true, false) != null, "Fiabilité du staff affichée")
	var avant := str(pilotage().get("consignes", {}).get("piedJeu", ""))
	await cliquer("MatchFenetreConsignesChoix_plus")
	check(en_file("piedJeu") == "plus", "Clic = « Occuper » en attente du prochain arrêt")
	check(str(pilotage().get("consignes", {}).get("piedJeu", "")) == avant, "Rien n'est appliqué avant l'arrêt de jeu")
	check(fenetre() != null and fenetre().find_child("MatchFenetreConsignesAttente", true, false) != null, "« ⧗ PROCHAIN ARRÊT » sur le cran demandé")
	check(fenetre() != null and fenetre().find_child("MatchFenetreConsignesCarteAttente_piedJeu", true, false) != null, "⧗ sur la carte de la consigne")
	# 2) Le plan de jeu se règle sans pause, lui aussi au prochain arrêt.
	await cliquer("MatchFenetreConsignesAxeLien_planAttaque")
	check(fenetre() != null and fenetre().find_child("MatchFenetreConsignesLigne_large", true, false) != null, "Plan de jeu : ses crans en lignes")
	await cliquer("MatchFenetreConsignesChoix_large")
	check(en_file("planAttaque") == "large", "Plan de jeu « Jeu au large » en attente du prochain arrêt")
	# 3) Clic sur le cran en place : la demande est retirée.
	await cliquer("MatchFenetreConsignesAxeLien_rythme")
	await cliquer("MatchFenetreConsignesChoix_rapide")
	check(en_file("rythme") == "rapide", "Rythme demandé")
	var en_place := str(pilotage().get("consignes", {}).get("rythme", ""))
	await cliquer("MatchFenetreConsignesChoix_" + en_place)
	check(en_file("rythme") == "", "Clic sur le cran en place = demande retirée")
	# Captures du résultat (plan de jeu montré, deux demandes en attente).
	await cliquer("MatchFenetreConsignesAxeLien_planAttaque")
	for taille: Vector2i in tailles:
		root.size = taille
		root.content_scale_size = taille
		await settle(30)
		view.ouvrir_fenetre_consignes()
		await settle(12)
		check(debordements(fenetre()).is_empty(), "%s : rien de coupé ni hors écran %s" % [str(taille), str(debordements(fenetre()))])
		await capture("final-plan-de-jeu-%dx%d" % [taille.x, taille.y])
	view.consignes_axe = "piedJeu"
	view.ouvrir_fenetre_consignes()
	await settle(12)
	await capture("final-1920x1080")
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	await settle(30)
	view.ouvrir_fenetre_consignes()
	await settle(12)
	await capture("final-2560x1440")
	# 4) Le match reprend (fenêtre ouverte) : au premier arrêt de jeu, le moteur applique ; la fenêtre suit.
	await command("pause", {"paused": false})
	Engine.time_scale = 8.0
	var fin := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < fin and (en_file("piedJeu") != "" or en_file("planAttaque") != "") and not app.model.live.get("finished", false):
		await settle(4)
	Engine.time_scale = 1.0
	check(str(pilotage().get("consignes", {}).get("piedJeu", "")) == "plus", "Au prochain arrêt : « Occuper » appliqué par le moteur")
	var plan := ""
	for a: Variant in pilotage().get("axes", []):
		if a is Dictionary and str(a.get("id", "")) == "planAttaque": plan = str(a.get("valeur", ""))
	check(plan == "large", "Au prochain arrêt : plan de jeu appliqué")
	if not app.model.live.get("paused", false): await command("pause", {"paused": true})
	await settle(20)
	if view.fenetre_ouverte() and fenetre() != null:
		check(await until(func(): return fenetre() != null and fenetre().find_child("MatchFenetreConsignesAttente", true, false) == null and fenetre().find_child("MatchFenetreConsignesEnPlace", true, false) != null, 5000), "La fenêtre montre « En place » après l'arrêt")
		await capture("final-applique-2560x1440")
	else: check(false, "La fenêtre reste ouverte pendant que le match continue")
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

func pilotage() -> Dictionary:
	var p: Variant = app.model.live.get("pilotage")
	return p if p is Dictionary else {}

func fenetre() -> Control:
	var v := surface()
	if v == null or not v.fenetre_ouverte(): return null
	return v.fenetre_hote.find_child("MatchFenetreConsignes", true, false) as Control

## Cran en attente du prochain arrêt pour un axe ("" sinon).
func en_file(axe: String) -> String:
	var a: Variant = pilotage().get("arrets")
	for e: Variant in a.get("file", []) if a is Dictionary and a.get("file") is Array else []:
		if e is Dictionary and str(e.get("cle", "")) == "consigne:" + axe: return str(e.get("valeur", ""))
	return ""

func cliquer(nom: String) -> void:
	var b: Button = fenetre().find_child(nom, true, false) as Button if fenetre() != null else null
	check(b != null, "Bouton %s" % nom)
	if b == null: return
	b.pressed.emit()
	await wait_command()
	await settle(12)

## Textes avec un chiffre dans les lignes de crans (l'avis du staff ne chiffre jamais rien).
func chiffres_dans_les_lignes() -> Array[String]:
	var trouves: Array[String] = []
	if fenetre() == null: return trouves
	var re := RegEx.create_from_string("\\d")
	for ligne: Node in fenetre().find_children("MatchFenetreConsignesLigne_*", "", true, false):
		for l: Node in ligne.find_children("*", "Label", true, false):
			if re.search((l as Label).text) != null: trouves.append((l as Label).text)
	return trouves

func finir() -> void:
	print("CONSIGNES_MATCH %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
