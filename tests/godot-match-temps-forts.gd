extends SceneTree
## Direct en temps forts dans la vraie interface, avec le vrai moteur.
## Mode « actif » (CD_MATCH_TEMPS_FORTS=1) : coup d'envoi en 3D, écran intermédiaire,
## nouveau temps fort, arrêt sur carton, lisibilité en 1280×720 et 1920×1080.
## Mode « inactif » : la régie n'existe pas et le direct d'origine est inchangé.
var app: Control
var failures: Array[String] = []
var checks := 0
var proof := OS.get_environment("CD_MATCH_TEMPS_FORTS_ARTIFACTS")
var mode := OS.get_environment("CD_MATCH_TEMPS_FORTS_MODE")

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func settle(frames: int = 8) -> void:
	for i in frames: await process_frame

func wait_command(limit_ms: int = 60000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle(2)

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_command()
	check(not app.waiting and app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)

func surface() -> Control:
	return app.contextual_director.view if app.contextual_director.active() and app.contextual_director.kind == "live" else null

func until(condition: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
		observe_framing()
	return condition.call()

## Cadrage pendant les temps forts : hauteur visible et ballon dans le champ, image par image.
var framing := {"frames": 0, "outside": 0, "hidden": 0, "wide": 0, "smallest": INF, "largest": 0.0, "where": []}
func observe_framing() -> void:
	var view := surface()
	if view == null or view.regie == null or view.regie.etat != view.regie.JEU or view.regie.cadrage == null: return
	var camera: Camera3D = view.stage.get("_camera")
	var ball: Node3D = view.stage.get("_ball")
	if not ball.visible or str(view.stage.get("_camera_mode")) == "tactical": return
	var screen: Vector2 = view.stage.get_viewport().get_visible_rect().size
	var local := camera.to_local(ball.global_position)
	framing.frames += 1
	framing.smallest = minf(framing.smallest, camera.size)
	framing.largest = maxf(framing.largest, camera.size)
	# Sous le voile du fondu d'entrée, l'image 3D n'est pas encore visible.
	var veiled: bool = view.regie.voile.visible and view.regie.voile.modulate.a > 0.85
	if camera.size > 26.5 and not veiled: framing.wide += 1
	# Zone libre : ni sous le bandeau du score, ni sous la légende et les commandes.
	var legend: Control = view.events.get_parent().get_parent().get_parent()
	var top: float = 0.5 - view.clock.get_global_rect().end.y / maxf(1.0, view.size.y)
	var bottom: float = -0.5 + (view.size.y - legend.get_global_rect().position.y) / maxf(1.0, view.size.y)
	if absf(local.x) > camera.size * screen.x / screen.y * 0.5 or local.y > camera.size * top or local.y < camera.size * bottom:
		if veiled: framing.hidden += 1
		else:
			framing.outside += 1
			framing.where.append("plan %d %s à %.2f s, voile %.2f, %s" % [view.regie.index, view.regie.phase, view.regie.temps, view.regie.voile.modulate.a if view.regie.voile.visible else 0.0, str(view.regie.tf.plans[view.regie.index].get("kind", "")) if view.regie.index >= 0 else ""])

func check_framing(label: String, highlights: int) -> void:
	print(label, " — cadrage : ", framing.frames, " images, hauteur visible de ", snappedf(framing.smallest, 0.1), " à ", snappedf(framing.largest, 0.1), " m, ballon hors champ ", framing.outside, " (", framing.hidden, " sous le voile d'entrée), images larges visibles ", framing.wide, " ", framing.where)
	check(framing.frames >= 60, label + " : cadrage observé pendant les temps forts (%d images)" % framing.frames)
	check(framing.outside == 0, label + " : le ballon ne sort jamais du champ visible (%d images : %s)" % [framing.outside, str(framing.where)])
	check(framing.smallest >= 9.0 and framing.smallest <= 18.5, label + " : l'action est cadrée de près (%.1f m au plus serré)" % framing.smallest)
	check(framing.wide == 0 and highlights > 0, label + " : jamais de plan large visible pendant un temps fort (%d images)" % framing.wide)

func inside(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 1.0 and inner.position.y >= outer.position.y - 1.0 and inner.end.x <= outer.end.x + 1.0 and inner.end.y <= outer.end.y + 1.0

func layout(view: Control, size: Vector2i) -> void:
	root.size = size
	root.content_scale_size = size
	await settle(12)
	var between: Control = view.regie.between
	var label := "%d×%d" % [size.x, size.y]
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	check(between.is_visible_in_tree() and inside(screen, between.get_global_rect()), label + " : l'écran intermédiaire tient dans la fenêtre")
	var pitch: Control = between.terrain
	check(pitch.size.x >= 320 and pitch.size.y >= 180 and pitch.champ().size.x >= 300, label + " : terrain lisible (%s)" % str(pitch.size))
	var controls: Control = view.finish.get_parent().get_parent().get_parent()
	check(between.get_global_rect().end.y <= controls.get_global_rect().position.y + 1.0, label + " : rien sous la barre de commandes")
	check(between.get_global_rect().position.y >= view.clock.get_global_rect().end.y - 1.0, label + " : rien sous le bandeau du score")
	var feed: ScrollContainer = between.fil.get_parent()
	for node: Control in between.find_children("*", "Control", true, false):
		# Le fil défile : ses lignes anciennes sont atteignables, pas coupées.
		if not node.is_visible_in_tree() or node == between.arret or between.arret.is_ancestor_of(node) or feed.is_ancestor_of(node): continue
		check(inside(between.get_global_rect(), node.get_global_rect()), label + " : " + str(node.name) + " n'est pas coupé")
	check(between.chiffres.get_child_count() >= 5 and between.fil.get_child_count() >= 1, label + " : fil et chiffres remplis")
	# Mise à l'échelle : texte de 13 points au moins en 720p, doublé en 1440p, et la colonne de droite est remplie.
	var density: float = between.densite_pour(Vector2(size))
	var figure: Label = between.chiffres.get_child(0).get_child(0)
	check(is_equal_approx(between._densite, density) and figure.get_theme_font_size("font_size") == roundi(26 * density), label + " : chiffres à l'échelle (%d points)" % figure.get_theme_font_size("font_size"))
	check(figure.get_theme_font_size("font_size") >= 13 and between.etat.get_theme_font_size("font_size") == roundi(34 * density), label + " : texte lisible")
	var column: Control = between.chiffres.get_parent().get_parent().get_parent().get_parent()
	var used := 0.0
	for panel: Control in column.get_children():
		if panel.visible: used += panel.size.y
	check(used >= column.size.y * 0.9, label + " : la colonne de droite est occupée (%d sur %d px)" % [int(used), int(column.size.y)])
	check(feed.size.y >= between.px(200), label + " : le fil garde de la hauteur (%d px)" % int(feed.size.y))
	for row: Control in between.chiffres.get_children():
		for cell: Label in row.find_children("*", "Label", true, false):
			check(cell.get_minimum_size().x <= cell.size.x + 1.0 or cell.clip_text, label + " : chiffre entier : " + cell.text)

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("live.json"))})
	await settle()
	var view := surface()
	check(view != null and view.has_method("temps_forts_actifs"), "Le match s'ouvre dans la vue du direct")
	if view != null:
		if mode == "actif": await active(view)
		elif mode == "gestes": await gestures(view)
		else: await inactive(view)
	var report := FileAccess.open(proof.path_join("report-" + mode + ".json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "suivi": view.regie.suivi if view != null and view.regie != null else []}, "  "))
	report.close()
	app.closing = true
	app.bridge.stop()
	print("Temps forts (", mode, ") : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)

func inactive(view: Control) -> void:
	check(view.regie == null and not view.temps_forts_actifs(), "Sans la variable, aucune régie")
	check(view.stage.get("_cadrage") == null, "Sans la variable, aucun recadrage de la vue 3D")
	check(view.find_child("MatchBetween", true, false) == null and view.find_child("MatchBetweenVeil", true, false) == null, "Sans la variable, aucun écran intermédiaire")
	check(not app.model.live.has("direct"), "Sans la variable, le moteur ne projette rien")
	check(view.find_children("*", "OptionButton", true, false).any(func(option: OptionButton): return option.item_count == 3 and option.get_item_text(0) == "Cadence ×1"), "La cadence d'origine est conservée")
	var before: int = app.model.live.events.size()
	await command("pause", {"paused": false})
	app.timer.stop()
	await command("tick", {"steps": 1})
	check(app.model.live.events.size() >= before and not app.model.live.has("direct"), "Le pas d'origine fonctionne")
	check(not str(view.stage.get("_action_key")).is_empty(), "La vue 3D reçoit la scène du moteur")

func active(view: Control) -> void:
	var regie: Node = view.regie
	check(regie != null and view.temps_forts_actifs(), "Avec la variable, la régie cadence le match")
	if regie == null: return
	var between: Control = regie.between
	check(app.model.live.direct.tempsFort is Dictionary and app.model.live.direct.tempsFort.type == "coup_d_envoi", "Le moteur projette le coup d'envoi")
	check(regie.etat == regie.JEU and not between.visible, "Le coup d'envoi est joué en 3D, écran intermédiaire masqué")
	check(regie.suivi.size() == 1 and regie.suivi[0].evenement == "temps_fort", "Premier temps fort suivi")
	var first_key := str(view.stage.get("_action_key"))
	check(not first_key.is_empty() and view.stage.get("_actors").size() == 30, "La vue 3D montre les trente joueurs du plan")
	check(view.clock.text.ends_with("′"), "Le bandeau affiche l'horloge du plan rejoué : " + view.clock.text)
	check(not view.events.text.is_empty() and view.events.is_visible_in_tree(), "La légende du plan est affichée : " + view.events.text)
	# Le match importé est en pause : le temps fort va tout de même à son terme, puis l'écran intermédiaire attend.
	check(await until(func(): return regie.etat == regie.INTER, 30000), "Le temps fort se termine")
	check(between.is_visible_in_tree() and regie.voile.visible, "L'écran intermédiaire couvre la 3D")
	check(view.clock.text == str(app.model.live.direct.horloge) and view.clock.text.ends_with("′"), "Même écriture de l'horloge sur l'écran intermédiaire : " + view.clock.text)
	check(str(view.stage.get("_action_key")) != first_key, "Les plans du temps fort se sont succédé")
	var minute: int = app.model.live.minute
	await settle(40)
	check(app.model.live.minute == minute and not app.waiting, "En pause, aucune minute n'est demandée")
	await layout(view, Vector2i(1280, 720))
	await layout(view, Vector2i(1920, 1080))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	# Reprise : la régie demande elle-même les minutes, une par une.
	var events_before: int = app.model.live.events.size()
	await command("pause", {"paused": false})
	check(await until(func(): return app.model.live.minute > minute, 30000), "L'horloge accélérée avance seule")
	check(app.model.live.events.size() > events_before, "Chaque pas simule une minute")
	check(regie.etat != regie.JEU or regie.suivi.size() > 2, "Une minute sans action retenue reste sur l'écran intermédiaire")
	var replayed := func(): return regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "temps_fort").size() >= 2 and regie.etat != regie.JEU
	check(await until(replayed, 240000), "Un second temps fort est joué puis rendu à l'écran intermédiaire (minute %d)" % int(app.model.live.minute))
	var played: Array = regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "temps_fort")
	check(played.all(func(entry: Dictionary): return float(entry.get("duree_reelle", 0.0)) > 0.0), "Chaque temps fort est allé à son terme")
	check(regie.suivi.any(func(entry: Dictionary): return entry.evenement == "intermediaire"), "L'écran intermédiaire a été montré entre deux temps forts")
	check(regie.cadrage != null and view.stage.get("_cadrage") == regie.cadrage, "La régie pose le cadrage des temps forts sur la vue 3D")
	check_framing("Temps forts", played.size())
	check(app.model.live.minute - minute <= app.model.live.events.size(), "Le journal suit l'horloge")
	# Niveau « commentaire seul » : plus aucun temps fort.
	await until(func(): return not app.waiting, 30000)
	between.niveau_choisi.emit("aucun")
	var count := played.size()
	var target: int = int(app.model.live.minute) + 4
	check(await until(func(): return app.model.live.minute >= target or app.model.live.paused, 90000), "Le match continue en commentaire seul")
	check(app.model.live.direct.niveau == "aucun" and regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "temps_fort").size() == count, "Commentaire seul : aucun temps fort de plus")
	# Arrêt-décision : un carton signalé met le match en pause, après le temps fort, jamais pendant.
	await until(func(): return not app.waiting, 30000)
	if app.model.live.paused: await command("pause", {"paused": false})
	await until(func(): return not app.waiting, 30000)
	var live: Dictionary = app.model.live.duplicate(true)
	live.direct.arret = {"cle": "carton-test", "raison": "carton", "rouge": false, "pourNous": false, "texte": "Carton jaune pour un joueur du club.", "horloge": "12′"}
	live.direct.tempsFort = null
	regie.receive(app.model, live)
	check(between.arret.visible and not regie.arret.is_empty(), "Le carton ouvre un arrêt-décision")
	check(await until(func(): return not app.waiting and app.model.live.paused, 30000), "Le match est mis en pause par la régie")
	var stopped: int = app.model.live.minute
	await settle(40)
	check(app.model.live.minute == stopped and between.arret.visible, "Le match attend le manager")
	between.reprise_demandee.emit()
	check(await until(func(): return not app.waiting and not app.model.live.paused, 30000), "« Reprendre le match » relance le direct")
	await settle(4)
	check(not between.arret.visible, "L'arrêt disparaît à la reprise")
	app._command("pause", {"paused": true})
	await wait_command()

## Temps forts et gestes ensemble : vingt minutes de match sans que rien ne se fige.
func gestures(view: Control) -> void:
	var regie: Node = view.regie
	check(regie != null and view.stage.get("_gestes") != null, "La régie et les gestes de la vue 3D sont actifs ensemble")
	if regie == null: return
	var goal := 22
	var state := ""
	var progress := Time.get_ticks_msec()
	var deadline := progress + 400000
	var resumed := false
	var smallest := INF
	while int(app.model.live.minute) < goal and Time.get_ticks_msec() < deadline:
		await process_frame
		if not resumed and not app.waiting and regie.etat != regie.JEU:
			resumed = true
			if app.model.live.paused: app._command("pause", {"paused": false})
		observe_framing()
		var gestes: RefCounted = view.stage.get("_gestes")
		var camera: Camera3D = view.stage.get("_camera")
		if not (is_finite(camera.size) and camera.size >= 4.0 and camera.size <= 200.0 and camera.position.is_finite() and camera.basis.is_finite()):
			check(false, "Caméra dégénérée : taille %s, position %s, minute %d, geste %s" % [str(camera.size), str(camera.position), int(app.model.live.minute), str(gestes.phase)])
			break
		smallest = minf(smallest, camera.size)
		var now_state := "%d|%d|%d|%s|%s" % [int(app.model.live.minute), regie.etat, regie.index, regie.phase, str(gestes.phase)]
		if now_state != state:
			state = now_state
			progress = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - progress > 45000:
			check(false, "Direct figé (minute|état|plan|phase|geste) : %s · geste en attente %s · moteur en attente %s · demande %s · pause %s · erreur « %s »" % [state, str(view.stage.is_presenting_extended_pass()), str(app.waiting), str(regie.get("_demande")), str(app.model.live.paused), str(app.last_error)])
			break
	print("Hauteur visible minimale pendant les gestes : ", snappedf(smallest, 0.1), " m")
	check(int(app.model.live.minute) >= goal, "Vingt minutes de match jouées avec les deux variables (minute %d)" % int(app.model.live.minute))
	var played: Array = regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "temps_fort")
	check(played.size() >= 4, "Plusieurs temps forts joués avec les gestes : %d" % played.size())
	check(played.filter(func(entry: Dictionary): return entry.has("duree_reelle")).size() >= played.size() - 1, "Les temps forts vont à leur terme")
	check(regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "intermediaire").size() >= 2, "Retours à l'écran intermédiaire")
	check(regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "echeance").is_empty(), "Aucune attente n'a dû être interrompue par une échéance : " + str(regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "echeance")))
	check_framing("Temps forts et gestes", played.size())
	await until(func(): return not app.waiting and regie.etat != regie.JEU, 60000)
	app._command("pause", {"paused": true})
	await wait_command()
