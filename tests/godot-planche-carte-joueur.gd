extends SceneTree
## Planche « carte joueur au survol » (choix visuel ouvert, demande de Léo du 21/11/2026) : dans le direct (écran 2D D3),
## la souris passe sur un joueur de Mon XV ; la carte (option A ou B, CD_VARIANTE_VISUELLE=D3-A / D3-B) apparaît après
## un court délai sans mettre le match en pause, entière dans l'écran ; Échap la ferme ; la souris part, elle disparaît.
## Captures 2560 × 1440 (référence de Léo) puis 1920 × 1080. godot-planche-carte-joueur.cjs prépare la carrière Monde.
const Carte = preload("res://ui/carte_joueur_survol.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_PLANCHE_CARTE_JOUEUR")

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
	return is_instance_valid(view) and view.regie != null and view.regie.etat == view.regie.INTER and view.regie.between.is_visible_in_tree() and view.regie.between._journee_montree()

func souris(position: Vector2) -> void:
	var mouvement := InputEventMouseMotion.new()
	mouvement.position = position
	mouvement.global_position = position
	root.push_input(mouvement)

## Tuile de Mon XV du joueur n° `numero` (sinon la première visible).
func tuile(between: Control, numero: int) -> Control:
	var choisie: Control = null
	for n: Node in between.find_children("MatchBetweenPlayer*", "Button", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or not c.has_meta("carte_joueur"): continue
		if choisie == null: choisie = c
		if str(c.name) == "MatchBetweenPlayer%d" % numero: return c
	return choisie

## Textes coupés sans points de suspension et contrôles hors de la carte.
func defauts(carte: Control) -> Array[String]:
	var trouves: Array[String] = []
	var cadre := carte.get_global_rect().grow(1.0)
	for n: Node in carte.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.visible or c.size.x < 1.0: continue
		if not cadre.encloses(c.get_global_rect()): trouves.append("%s hors de la carte" % c.name)
		if c is Label:
			var l := c as Label
			var largeur := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			if largeur > l.size.x + 2.0: trouves.append("%s coupé (« %s »)" % [l.name, l.text])
	return trouves

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
	# Match à fond jusqu'au moment des captures (consigne de Léo : jamais d'attente en temps réel), puis vitesse normale.
	var minute_voulue := int(OS.get_environment("CD_PLANCHE_MINUTE")) if OS.get_environment("CD_PLANCHE_MINUTE").is_valid_int() else 12
	Engine.time_scale = 16.0
	await until(func(): return int(app.model.live.get("minute", 0)) >= minute_voulue, 600000)
	check(await until(func(): return vue_2d(view), 240000), "Écran 2D du direct")
	Engine.time_scale = 1.0
	var between: Control = view.regie.between
	# Survol pendant que le match tourne (l'écran 2D alterne avec les temps forts : on revient sur le joueur tant que la
	# carte n'est pas apparue) ; le survol ne met pas le match en pause.
	var cible: Control = null
	var apparue := false
	var delai_ms := 0
	var limite_survol := Time.get_ticks_msec() + 90000
	while not apparue and Time.get_ticks_msec() < limite_survol:
		await until(func(): return vue_2d(view), 30000)
		cible = tuile(between, 10)
		if cible == null:
			await settle(10)
			continue
		souris(Vector2(4, 4))
		await settle(2)
		var debut := Time.get_ticks_msec()
		souris(cible.get_global_rect().get_center())
		apparue = await until(func(): return Carte.actuelle(app) != null, 3000)
		delai_ms = Time.get_ticks_msec() - debut
	check(apparue, "Match en cours : la carte apparaît au survol")
	check(not apparue or delai_ms >= 300, "Pas de carte avant le délai (%d ms)" % delai_ms)
	check(not bool(app.model.live.get("paused", false)), "Le survol ne met pas le match en pause")
	# Le direct continue (Mon XV redessiné sous la souris) : la carte reste ouverte tant que l'écran 2D est là.
	for i in 60:
		await process_frame
		if not vue_2d(view): break
	check(Carte.actuelle(app) != null or not vue_2d(view), "Match en cours : la carte reste ouverte sous la souris")
	# Match figé sur l'écran 2D (pause du test, pas de la carte) pour des captures stables.
	await until(func(): return vue_2d(view), 60000)
	if not app.model.live.get("finished", false) and not app.model.live.get("paused", false): await command("pause", {"paused": true})
	await settle(20)
	cible = tuile(between, 10)
	check(cible != null, "Tuile du joueur à l'arrêt")
	if cible == null:
		finir()
		return
	souris(Vector2(4, 4))
	await settle(4)
	souris(cible.get_global_rect().get_center())
	await until(func(): return Carte.actuelle(app) != null, 3000)
	check(Carte.actuelle(app) != null, "La carte apparaît au survol")
	# Échap ferme la carte (et ne la rouvre pas tant que la souris reste sur le joueur).
	var echap := InputEventKey.new()
	echap.keycode = KEY_ESCAPE
	echap.pressed = true
	root.push_input(echap)
	await settle(30)
	check(Carte.actuelle(app) == null, "Échap ferme la carte")
	# La souris part : rien.
	souris(Vector2(4, 4))
	await settle(30)
	check(Carte.actuelle(app) == null, "Souris hors du joueur : pas de carte")
	for taille: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = taille
		root.content_scale_size = taille
		souris(Vector2(4, 4))
		await settle(40)
		cible = tuile(between, 10)
		if cible == null: continue
		souris(cible.get_global_rect().get_center())
		await until(func(): return Carte.actuelle(app) != null, 3000)
		await settle(10)
		var carte := Carte.actuelle(app)
		check(carte != null, "%s : la carte apparaît" % str(taille))
		if carte == null: continue
		var ecran := Rect2(Vector2.ZERO, Vector2(taille))
		check(ecran.encloses(carte.get_global_rect()), "%s : carte entière dans l'écran %s" % [str(taille), str(carte.get_global_rect())])
		check(not carte.get_global_rect().intersects(cible.get_global_rect()), "%s : la carte ne cache pas le joueur survolé" % str(taille))
		var d := defauts(carte)
		check(d.is_empty(), "%s : rien de coupé : %s" % [str(taille), str(d.slice(0, 6))])
		check(carte.find_child("CarteJoueurMatch", true, false) != null, "%s : état du match en tête" % str(taille))
		check(carte.find_child("CarteJoueurEtoilesPoste_*", true, false) != null, "%s : étoiles d'adaptabilité" % str(taille))
		print("PLANCHE_CARTE_JOUEUR %s %s : carte %s" % [Carte.variante(), str(taille), str(carte.get_global_rect())])
		await capture("carte-%dx%d" % [taille.x, taille.y])
	finir()

func finir() -> void:
	print("PLANCHE_CARTE_JOUEUR %s %d controles, %d echec" % [OS.get_environment("CD_VARIANTE_VISUELLE"), checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
