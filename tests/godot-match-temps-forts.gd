extends SceneTree
## Match en temps forts dans la vraie interface, avec le vrai moteur.
## Mode « defaut » (aucune variable) : le parcours du joueur — causerie, coup d'envoi,
## pause pendant un temps fort, remplacement et consigne sur l'écran intermédiaire,
## mi-temps, fin de match et débrief, son du stade calé sur l'image ; un arrêt sur carton
## (le match attend le manager) est repris comme avec le bouton « Reprendre le match ».
## Mode « reprise » (aucune variable) : match repris en cours de route, niveau conservé,
## fin confiée à l'adjoint.
## Mode « actif » : coup d'envoi en 3D, écran intermédiaire, nouveau temps fort, arrêt
## sur carton, lisibilité en 1280×720 et 1920×1080. Mode « gestes » : vingt minutes
## avec les gestes. Mode « inactif » (CD_MATCH_TEMPS_FORTS=0) : direct d'origine inchangé.
## Mode « entracte » : entre deux temps forts, l'horloge défile, le temps fort suivant attend
## la fin de l'entracte, la tactique ouverte met en pause et ses changements passent, « Passer »
## abrège ; aucun anneau au sol sous les joueurs.
## Mode « terrain2d » : pendant l'entracte, le match continue sur le terrain 2D (pastilles qui
## rejouent les faits du moteur, possession suivie, pause qui fige, rien d'inventé) et le
## tableau de bord (domination, chiffres, Mon XV, adjoint) est alimenté par les vraies données.
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
	# Plan large : au-delà du cadrage le plus large d'un temps fort (32 m en TV depuis le 12 novembre 2026).
	if camera.size > 32.5 and not veiled:
		framing.wide += 1
		var gestes: RefCounted = view.stage.get("_gestes")
		if framing.where.size() < 12: framing.where.append("large %.1f m : plan %d %s à %.2f s, %s, suite %s, poids %.2f, geste %s zoom %.2f, voile %.2f" % [camera.size, view.regie.index, view.regie.phase, view.regie.temps, str(view.regie.tf.plans[view.regie.index].get("kind", "")) if view.regie.index >= 0 else "", str(view.regie.tf.get("suite", false)), float(view.regie.cadrage.poids), str(gestes.phase) if gestes != null else "-", float(gestes.zoom) if gestes != null else 0.0, view.regie.voile.modulate.a if view.regie.voile.visible else 0.0])
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
	# Caméra reculée (12 novembre 2026) : 15 à 16 m au plus serré en TV, jamais plus près que 9 m (contact).
	check(framing.smallest >= 9.0 and framing.smallest <= 24.5, label + " : l'action est cadrée, ni trop près ni trop loin (%.1f m au plus serré)" % framing.smallest)
	check(framing.wide == 0 and highlights > 0, label + " : jamais de plan large visible pendant un temps fort (%d images)" % framing.wide)

func inside(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 1.0 and inner.position.y >= outer.position.y - 1.0 and inner.end.x <= outer.end.x + 1.0 and inner.end.y <= outer.end.y + 1.0

func layout(view: Control, size: Vector2i) -> void:
	root.size = size
	root.content_scale_size = size
	var between: Control = view.regie.between
	await settle(12)
	var label := "%d×%d" % [size.x, size.y]
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	check(between.is_visible_in_tree() and inside(screen, between.get_global_rect()), label + " : l'écran intermédiaire tient dans la fenêtre")
	var pitch: Control = between.terrain
	check(pitch.size.x >= 320 and pitch.size.y >= 180 and pitch.champ().size.x >= 300, label + " : terrain lisible (%s)" % str(pitch.size))
	var controls: Control = view.finish.get_parent().get_parent().get_parent()
	check(not controls.is_visible_in_tree() or between.get_global_rect().end.y <= controls.get_global_rect().position.y + 1.0, label + " : rien sous la barre de commandes")
	check(not controls.is_visible_in_tree(), label + " : une seule barre de commandes (celle de l'écran intermédiaire)")
	check(between.get_global_rect().position.y >= view.clock.get_global_rect().end.y - 1.0, label + " : rien sous le bandeau du score")
	var feed: Control = between.fil.get_parent()
	for node: Control in between.find_children("*", "Control", true, false):
		# Le fil défile : ses lignes anciennes sont atteignables, pas coupées.
		if not node.is_visible_in_tree() or node == between.arret or between.arret.is_ancestor_of(node) or feed.is_ancestor_of(node): continue
		check(inside(between.get_global_rect(), node.get_global_rect()), label + " : " + str(node.name) + " n'est pas coupé")
	check(between.chiffres.get_child_count() >= 3 and between.fil.get_child_count() >= 1, label + " : fil et chiffres remplis")
	# Mise à l'échelle : texte de 13 points au moins en 720p, doublé en 1440p.
	var density: float = between.densite_pour(Vector2(size))
	var figure: Label = between.chiffres.get_child(0).get_child(0)
	check(is_equal_approx(between._densite, density) and figure.get_theme_font_size("font_size") == roundi(26 * density), label + " : chiffres à l'échelle (%d points)" % figure.get_theme_font_size("font_size"))
	check(figure.get_theme_font_size("font_size") >= 13 and between.etat.get_theme_font_size("font_size") == roundi(34 * density), label + " : texte lisible")
	# Les commandes communes sont là dans chaque mise en page.
	for nom in ["MatchBetweenTactics", "MatchBetweenBench", "MatchBetweenSettings", "MatchBetweenMore"]:
		var noeud: Control = between.find_child(nom, true, false)
		check(noeud != null and noeud.is_visible_in_tree(), label + " : commande " + nom)
	check(between.domination.is_visible_in_tree() and between.domination.size.y >= between.px(120), label + " : frise du match visible (%d px)" % int(between.domination.size.y))
	check(not between.adjoint_cadre.visible or between.adjoint_cadre.is_visible_in_tree(), label + " : carte de Gabi à l'écran")
	check(between.xv.is_visible_in_tree() and between.xv.columns == 3, label + " : Mon XV visible, nom et numéro par joueur")
	check(between.details.is_visible_in_tree() and between.details.get_child_count() >= 2, label + " : stats détaillées par thème")
	var column: Control = between.adjoint_cadre.get_parent()
	var used := 0.0
	for panel: Control in column.get_children():
		if panel.visible: used += panel.size.y
	check(used >= column.size.y * 0.9, label + " : la colonne de droite est occupée (%d sur %d px)" % [int(used), int(column.size.y)])
	# Colonne repliable : le terrain prend la place, puis la colonne revient.
	var largeur := pitch.size.x
	var languette: Button = between.find_child("MatchBetweenFold", true, false)
	languette.pressed.emit()
	await settle(4)
	check(not column.is_visible_in_tree() and pitch.size.x > largeur + 50.0, label + " : colonne repliée, terrain agrandi (%d → %d px)" % [int(largeur), int(pitch.size.x)])
	languette.pressed.emit()
	await settle(4)
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
	var followed: Array = []
	if mode == "reprise":
		# Aucune importation : la carrière et son match en cours viennent du dossier de données.
		await settle()
		followed = await resumed()
	elif mode == "defaut":
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("causerie.json"))})
		await settle()
		followed = await player_path()
	else:
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("live.json"))})
		await settle()
		var view := surface()
		check(view != null and view.has_method("temps_forts_actifs"), "Le match s'ouvre dans la vue du direct")
		if view != null:
			if mode == "actif": await active(view)
			elif mode == "gestes": await gestures(view)
			elif mode == "choregraphie": await choreography(view)
			elif mode == "entracte": await interval(view)
			elif mode == "terrain2d": await terrain2d(view)
			else: await inactive(view)
			if view.regie != null: followed = view.regie.suivi
	var report := FileAccess.open(proof.path_join("report-" + mode + ".json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "suivi": followed}, "  "))
	report.close()
	app.closing = true
	app.bridge.stop()
	print("Temps forts (", mode, ") : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)

func inactive(view: Control) -> void:
	check(view.regie == null and not view.temps_forts_actifs(), "Repli (CD_MATCH_TEMPS_FORTS=0) : aucune régie")
	check(view.stage.get("_cadrage") == null and view.stage.get("_gestes") == null, "Repli : ni recadrage ni gestes sur la vue 3D")
	check(view.find_child("MatchBetween", true, false) == null and view.find_child("MatchBetweenVeil", true, false) == null, "Repli : aucun écran intermédiaire")
	check(not app.model.live.has("direct"), "Repli : le moteur ne projette rien")
	check(view.find_children("*", "OptionButton", true, false).any(func(option: OptionButton): return option.is_visible_in_tree() and option.item_count == 3 and option.get_item_text(0) == "Cadence ×1"), "Repli : la cadence d'origine est conservée")
	check(not view.find_child("MatchLevel", true, false).is_visible_in_tree(), "Repli : pas de choix de niveau dans la barre")
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
	# Entracte : l'horloge du moteur, avec les secondes qui roulent (« 1:00 », « 40+2:15 »).
	# (ou la minute du fait que le terrain 2D rejoue encore, en retard sur le moteur).
	check(view.clock.text.begins_with(str(app.model.live.direct.horloge).trim_suffix("′") + ":") or view.clock.text.begins_with(str(app.model.live.direct.get("horlogeMontree", "")).trim_suffix("′") + ":") or not between.horloge_differee().is_empty() and view.clock.text.begins_with(between.horloge_differee().trim_suffix("′") + ":"), "Horloge du moteur, secondes comprises, sur l'écran intermédiaire : " + view.clock.text)
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

## Entracte entre deux temps forts (retours de Léo, 12 novembre 2026).
func interval(view: Control) -> void:
	var regie: Node = view.regie
	check(regie != null and view.temps_forts_actifs(), "La régie cadence le match")
	if regie == null: return
	var between: Control = regie.between
	# Aucun anneau au sol : ni repère d'équipe sous les joueurs, ni repère du ballon en vue TV.
	await settle(4)
	var anneaux := 0
	for id: String in view.stage._actors:
		var acteur: Node3D = view.stage._actors[id].node
		if acteur.get_node_or_null("TeamMarker") != null: anneaux += 1
		for maillage: Node in acteur.find_children("*", "MeshInstance3D", true, false):
			if (maillage as MeshInstance3D).mesh is TorusMesh: anneaux += 1
	check(view.stage._actors.size() == 30 and anneaux == 0, "Aucun anneau au sol sous les %d joueurs (%d trouvés)" % [view.stage._actors.size(), anneaux])
	check(not view.stage._ball_marker.visible, "Pas de repère au sol du ballon en vue TV")
	view.stage.set_camera("tactical")
	await settle(2)
	check(view.stage._ball_marker.visible, "Vue de dessus : le repère du ballon reste, le ballon y est minuscule")
	view.stage.set_camera("tv")
	check(regie.entracte >= 6.0 and regie.entracte <= 10.0, "Entracte par défaut entre 6 et 10 s : %.1f s" % regie.entracte)
	# Fin du coup d'envoi (le match importé est en pause) : l'entracte commence.
	check(await until(func(): return regie.etat == regie.INTER, 60000), "Le coup d'envoi se termine")
	if app.model.live.paused: await command("pause", {"paused": false})
	# Entracte avec un temps fort retenu (pas la suite d'une action) : l'horloge défile, rien ne
	# part avant la fin de l'entracte.
	var horloges := {}
	var retenu := func(): return regie.suivi.any(func(e: Dictionary): return e.evenement == "entracte_retenu")
	var debut := Time.get_ticks_msec()
	while not retenu.call() and Time.get_ticks_msec() - debut < 240000:
		await process_frame
		if regie.etat == regie.INTER and regie.entracte_en_cours(): horloges[view.clock.text] = true
	check(retenu.call(), "Un temps fort arrive pendant un entracte et y est retenu")
	var score_retenu: String = view.score.text
	var t_retenu := Time.get_ticks_msec()
	while regie.etat != regie.JEU and Time.get_ticks_msec() - t_retenu < 60000:
		await process_frame
		if regie.etat != regie.JEU:
			horloges[view.clock.text] = true
			if view.score.text != score_retenu: score_retenu = "changé"
	var fins: Array = regie.suivi.filter(func(e: Dictionary): return e.evenement == "entracte_fin")
	var inters: Array = regie.suivi.filter(func(e: Dictionary): return e.evenement == "intermediaire")
	var tfs: Array = regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort")
	var attendu: float = (float(tfs[-1].debut_ms) - float(inters[-1].debut_ms)) / 1000.0 if not tfs.is_empty() and not inters.is_empty() else 0.0
	check(regie.etat == regie.JEU and not fins.is_empty(), "Le temps fort retenu part")
	check(horloges.size() >= 6 and horloges.keys().all(func(h: String): return ":" in h), "L'horloge défile pendant l'entracte (%d valeurs, ex. %s)" % [horloges.size(), str(horloges.keys().slice(0, 4))])
	check(not fins.is_empty() and float(fins[-1].ecoule) >= regie.entracte - 0.05, "Rien ne part avant la fin de l'entracte : %s" % str(fins.slice(-1)))
	check(attendu >= regie.entracte - 0.5, "Écran intermédiaire montré %.1f s avant le temps fort retenu (entracte %.1f s)" % [attendu, regie.entracte])
	check(score_retenu != "changé", "Le score ne bouge pas pendant la retenue (rien n'annonce l'action)")
	# Deuxième entracte : la tactique ouverte met le match en pause, la consigne passe, rien ne part.
	check(await until(func(): return regie.etat == regie.INTER and regie.entracte_en_cours(), 120000), "Deuxième entracte")
	await until(func(): return not app.waiting, 30000)
	var avant: Dictionary = app.model.get("tactics", {}).duplicate()
	view._toggle_drawer("Tactique")
	check(await until(func(): return app.model.live.paused and not app.waiting, 30000), "Tactique ouverte pendant l'entracte : le match se met en pause")
	var horloge_figee: String = view.clock.text
	await settle(2)
	var options: Array = app.model.get("tactics", {}).get("attacks", [])
	var autre := ""
	for option: Dictionary in options:
		if option.get("id") != avant.get("attack"): autre = str(option.get("id")); break
	check(not autre.is_empty(), "Une autre consigne offensive est proposée")
	var boutons: Array = view.drawer_body.find_children("*", "Button", true, false).filter(func(b: Button): return not b.disabled)
	check(boutons.size() >= 2, "Les consignes sont modifiables pendant la pause de l'entracte (%d boutons actifs)" % boutons.size())
	await command("set_tactics", {"attack": autre, "defense": avant.get("defense", "equilibre")})
	check(str(app.model.get("tactics", {}).get("attack", "")) == autre, "La consigne choisie pendant l'entracte est prise en compte : " + autre)
	var temps_forts: int = regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort").size()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int((regie.entracte + 2.0) * 1000.0): await process_frame
	check(regie.etat != regie.JEU and regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort").size() == temps_forts, "Tiroir ouvert : aucun temps fort ne part")
	check(view.clock.text == horloge_figee, "Pause : l'horloge est figée (%s → %s)" % [horloge_figee, view.clock.text])
	view._toggle_drawer("Tactique")
	check(await until(func(): return not app.model.live.paused and not app.waiting, 30000), "Tactique fermée : le match reprend")
	# La consigne vaut pour la suite du match, comme une consigne donnée en pause aujourd'hui.
	check(await until(func(): return app.model.live.minute > 0 and str(app.model.get("tactics", {}).get("attack", "")) == autre, 30000), "La consigne reste en place après la reprise")
	# « Passer » : le prochain temps fort part sans attendre la fin de l'entracte.
	check(await until(func(): return regie.etat == regie.JEU, 180000), "Temps fort suivant")
	check(await until(func(): return regie.etat == regie.INTER and regie.entracte_en_cours(), 180000), "Troisième entracte")
	check(between.find_child("MatchBetweenSkip", true, false) == null, "Pas de bouton « Passer » : le match défile à la vitesse de l’horloge (choix de Léo)")
	var passe_a := Time.get_ticks_msec()
	between.passer_demande.emit()
	check(await until(func(): return regie.etat == regie.JEU, 120000), "« Passer » mène au prochain temps fort")
	var passe_s: float = (Time.get_ticks_msec() - passe_a) / 1000.0
	check(regie.suivi.any(func(e: Dictionary): return e.evenement == "entracte_passe") and passe_s < regie.entracte, "Le temps fort part sur « Passer », sans attendre la fin de l'entracte (%.1f s)" % passe_s)
	print("ENTRACTE ", JSON.stringify({"premier_s": attendu, "horloges": horloges.size(), "passer_s": (Time.get_ticks_msec() - passe_a) / 1000.0}))
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
	# Depuis l'entracte de #587 (le chrono du match défile entre deux temps forts), vingt-deux minutes de match
	# contiennent trois à cinq temps forts au lieu de quatre à six : « plusieurs » se lit désormais à partir de trois,
	# et les contrôles suivants (terme atteint, retours à l'écran intermédiaire, aucune échéance) restent inchangés.
	check(played.size() >= 3, "Plusieurs temps forts joués avec les gestes : %d" % played.size())
	check(played.filter(func(entry: Dictionary): return entry.has("duree_reelle")).size() >= played.size() - 1, "Les temps forts vont à leur terme")
	check(regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "intermediaire").size() >= 2, "Retours à l'écran intermédiaire")
	check(regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "echeance").is_empty(), "Aucune attente n'a dû être interrompue par une échéance : " + str(regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "echeance")))
	check_framing("Temps forts et gestes", played.size())
	# Le match est laissé en pause au milieu d'un temps fort, niveau « étendus » choisi :
	# le mode « reprise » repart de ce dossier de données.
	var playing: bool = await until(func(): return not app.waiting and regie.etat == regie.JEU and regie.index >= 0, 120000)
	print("Pause demandée pendant un temps fort : ", playing, " (minute ", int(app.model.live.minute), ")")
	await until(func(): return not app.waiting, 30000)
	app._command("pause", {"paused": true})
	await wait_command()
	check(app.model.live.paused and (not playing or regie.gel), "La pause demandée pendant un temps fort fige l'image")
	regie.choisir_niveau("etendus")
	check(app.user_preferences.data.get("match_highlights") == "etendus", "Le niveau choisi est enregistré dans les réglages : " + str(app.user_preferences.last_error))

## Chorégraphe (CD_MATCH_CHOREGRAPHE=1) : le temps fort de l'essai en jeu courant de la
## 14e minute (graine 7) est joué par les pistes du moteur, de bout en bout (depuis sa remise en
## jeu ou sa récupération), chaque fait annoncé à son jalon, l'essai jamais avant l'aplati ; une
## pause pendant les pistes les fige ; le temps fort continue ensuite (transformation).
func choreography(view: Control) -> void:
	var regie: Node = view.regie
	check(regie != null and view.stage.has_method("jouer_choregraphie"), "La régie et la vue savent lire les pistes")
	if regie == null: return
	var deadline := Time.get_ticks_msec() + 400000
	var vu := false
	var annonce_avant := false
	var journal_avance := false
	var fige_teste := false
	var fige_ok := false
	var fige_detail := ""
	var balle_ok := true
	var joueurs_ok := true
	var apres_index := -1
	while int(app.model.live.minute) < 17 and Time.get_ticks_msec() < deadline:
		await process_frame
		if app.model.live.paused and not app.waiting and regie.etat != regie.JEU and regie.arret.is_empty():
			app._command("pause", {"paused": false})
		if regie.phase != "choregraphie":
			if vu and apres_index < 0 and regie.etat == regie.JEU: apres_index = regie.index
			continue
		vu = true
		var pistes: Dictionary = regie.tf.choregraphie
		var plan: Dictionary = regie.tf.plans[regie.index]
		if not regie._jalon_montre:
			if not str(view.events.text).is_empty(): annonce_avant = true
			var montre: Dictionary = regie.montre(app.model.live)
			# Ce que le joueur connaissait déjà avant le temps fort reste au journal (plans d'une minute passée).
			if montre.get("events", []).size() > maxi(int(plan.index), int(regie._vus)): journal_avance = true
		var ball: Node3D = view.stage.get("_ball")
		if not (ball.visible and ball.global_position.is_finite()): balle_ok = false
		# Chaque joueur des pistes est à l'écran, premier temps fort du match compris (coup d'envoi).
		for joueur: Dictionary in pistes.joueurs:
			if not view.stage._actors.has(str(joueur.id)) or not (view.stage._actors[str(joueur.id)].node as Node3D).is_visible_in_tree(): joueurs_ok = false
		# Pause au milieu des pistes : l'image se fige, puis la lecture reprend.
		if not fige_teste and view.stage.choregraphie_temps() > 3.0 and not app.waiting:
			fige_teste = true
			# Match déjà arrêté au départ du temps fort (le temps fort se joue quand même) : le manager
			# relance d'abord, puis demande la pause.
			if app.model.live.paused:
				app._command("pause", {"paused": false})
				await wait_command()
				await settle(2)
			app._command("pause", {"paused": true})
			await wait_command()
			await settle(4)
			var t0: float = view.stage.choregraphie_temps()
			await settle(20)
			fige_ok = regie.gel and absf(view.stage.choregraphie_temps() - t0) < 0.001 and regie.phase == "choregraphie"
			fige_detail = "gel %s, écart %.3f s, phase %s, pause %s, au départ %s, état %d, index %d, suivi %s" % [str(regie.gel), view.stage.choregraphie_temps() - t0, regie.phase, str(app.model.live.paused), str(regie._pause_au_depart), regie.etat, regie.index, str(regie.suivi.slice(-4).map(func(e): return e.evenement))]
			app._command("pause", {"paused": false})
			await wait_command()
	check(vu, "L'essai en jeu courant est joué par les pistes du chorégraphe (minute %d)" % int(app.model.live.minute))
	check(not annonce_avant, "Aucune légende avant son jalon (l'essai jamais avant l'aplati)")
	check(not journal_avance, "Le journal ouvert n'annonce rien avant l'image (l'essai jamais avant l'aplati)")
	check(fige_teste and fige_ok, "Une pause pendant les pistes les fige, puis la lecture reprend (%s)" % fige_detail)
	check(balle_ok, "Ballon visible et fini pendant les pistes")
	check(joueurs_ok, "Chaque joueur des pistes est à l'écran pendant les pistes")
	var lues: Array = regie.suivi.filter(func(entry: Dictionary): return entry.evenement == "choregraphie")
	check(lues.size() >= 1 and lues.all(func(entry: Dictionary): return entry.has("duree_reelle")), "Pistes lues jusqu'au bout : " + str(lues))
	if not lues.is_empty():
		var prevue: float = float(lues[0].duree_prevue) / regie.vitesse
		check(absf(float(lues[0].duree_reelle) - prevue) < prevue * 0.25 + 2.0, "Durée lue ≈ durée des pistes (%s s pour %s s, pause comprise)" % [str(lues[0].duree_reelle), str(prevue)])
		check(float(lues[0].duree_prevue) >= 12.0 and float(lues[0].duree_prevue) <= 50.0, "Temps fort de 12 à 50 s : %s s" % str(lues[0].duree_prevue))
		check(int(lues[0].get("dernier", -1)) >= int(lues[0].get("premier", 0)), "Plans couverts par les pistes : %s" % str(lues[0]))
	check(regie.suivi.filter(func(entry: Dictionary): return entry.evenement in ["echeance", "choregraphie_refusee"]).is_empty(), "Ni échéance ni pistes refusées : " + str(regie.suivi.filter(func(entry: Dictionary): return entry.evenement in ["echeance", "choregraphie_refusee"])))
	check(apres_index > 0 or regie.suivi.any(func(entry: Dictionary): return entry.evenement == "intermediaire"), "Le temps fort continue après les pistes (plan %d)" % apres_index)

func talk() -> Dictionary:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return value if value is Dictionary else {}

func highlights(entries: Array) -> int:
	return entries.filter(func(entry: Dictionary): return entry.evenement == "temps_fort").size()

## Ce que le son du stade a joué, et ce que l'écran montrait à cet instant.
var cues: Array = []
var shown: Dictionary = {}
func hear(id: String) -> void:
	if not id.begins_with("stadium-"): return
	var view := surface()
	var regie: Node = view.regie if view != null else null
	var kind := ""
	if regie != null and regie.etat == regie.JEU and regie.index >= 0 and regie.index < regie.tf.plans.size(): kind = str(regie.tf.plans[regie.index].get("kind", ""))
	cues.append({"id": id, "kind": kind})

## Arrêts-décisions (clés) repris pendant le parcours du joueur.
var stoppages: Array = []
func watch() -> void:
	var view := surface()
	if view == null or view.regie == null: return
	var regie: Node = view.regie
	if regie.etat == regie.JEU and regie.index >= 0 and regie.index < regie.tf.plans.size(): shown[str(regie.tf.plans[regie.index].get("kind", ""))] = true
	# Arrêt sur carton : le match est en pause et attend le manager (aucune échéance, voulu).
	# Le joueur reprend une fois par arrêt, comme avec le bouton de l'écran intermédiaire.
	if not regie.arret.is_empty() and regie.between.arret.visible and app.model.live.get("paused", false) and not app.waiting:
		var cle := str(regie.arret.get("cle", ""))
		if cle not in stoppages:
			stoppages.append(cle)
			print("Arrêt-décision repris : ", regie.arret.get("texte", ""), " (", regie.arret.get("horloge", ""), ")")
			regie.between.reprise_demandee.emit()

## Attend la causerie d'une phase ; note si un temps fort l'a retenue et s'il a bien été joué avant.
func reach_talk(phase: String, limit_ms: int) -> Dictionary:
	var result := {"reached": false, "held": false, "played": true, "minute": 0}
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		watch()
		var scene := talk()
		if scene.is_empty() or scene.get("phase") != phase: continue
		if app.contextual_director.kind == "live":
			if not result.held:
				var view := surface()
				check(view != null and view.regie != null and view.retient_la_causerie(app.model.live), "La causerie n'attend que la fin d'un temps fort (%s)" % phase)
			result.held = true
			continue
		if app.contextual_director.kind == "locker":
			result.reached = true
			result.minute = int(app.model.live.minute)
			var direct: Dictionary = app.model.live.get("direct", {})
			if direct.get("tempsFort") is Dictionary:
				result.played = str(app.management_ui.get("match_temps_forts_cle", "")) == str(direct.get("rencontre", "")) + "|" + str(direct.tempsFort.get("cle", ""))
			return result
	return result

## Le parcours du joueur, sans aucune variable : le match s'ouvre en temps forts.
func player_path() -> Array:
	var director: Node = app.contextual_director
	var followed: Array = []
	check(OS.get_environment("CD_MATCH_TEMPS_FORTS").is_empty() and OS.get_environment("CD_MATCH_GESTES").is_empty(), "Aucune variable de mode n'est posée")
	check(director.active() and director.kind == "locker" and talk().get("phase") == "pre", "La causerie d'avant-match précède le coup d'envoi")
	if director.kind != "locker": return followed
	if is_instance_valid(app.soundscape): app.soundscape.cue_played.connect(hear)
	director.view._continue(true)
	await wait_command()
	await settle()
	var view := surface()
	check(view != null and view.regie != null and view.temps_forts_actifs(), "Sans variable, le match s'ouvre en temps forts")
	if view == null or view.regie == null: return followed
	var regie: Node = view.regie
	followed = regie.suivi
	check(regie.niveau == "dynamique", "Niveau par défaut : dynamique (" + regie.niveau + ")")
	check(view.stage.get("_gestes") != null and view.stage.get("_cadrage") == regie.cadrage and regie.cadrage != null, "Gestes et cadrage font partie du mode de base")
	check(regie.etat == regie.JEU and not regie.between.visible, "Le coup d'envoi est joué en 3D")
	var level: OptionButton = view.find_child("MatchLevel", true, false)
	check(level != null and level.is_visible_in_tree() and level.item_count == 6 and level.get_item_text(level.selected) == "Dynamique", "Le niveau se choisit dans la barre du match")
	var labels: Array = []
	if level != null:
		for index in level.item_count: labels.append(level.get_item_text(index))
	check("Match complet" in labels, "Le choix « Match complet » est proposé : " + str(labels))
	check(view.find_children("*", "OptionButton", true, false).any(func(option: OptionButton): return option.is_visible_in_tree() and option.item_count == 4 and option.get_item_text(1) == "Horloge normale"), "L'horloge de l'écran intermédiaire remplace la cadence")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	var bar: Control = level.get_parent() if level != null else null
	if bar != null:
		for child in bar.get_children():
			if child is Control and child.is_visible_in_tree(): check(screen.grow(1.0).encloses(child.get_global_rect()), "Barre du match dans l'écran en 1280×720 : %s %s" % [child.name, str(child.get_global_rect())])
	# Pause demandée pendant un temps fort : l'image se fige, la reprise la relance. Le coup
	# d'envoi est lu à vitesse réelle le temps de cette étape : à ×4 il peut finir avant que
	# la réponse du moteur à la pause n'arrive.
	var allure: float = regie.vitesse
	regie.vitesse = 1.0
	view._pause()
	await wait_command()
	check(app.model.live.paused and regie.gel and regie.etat == regie.JEU, "La pause demandée pendant un temps fort fige l'image")
	var frozen := [regie.index, regie.temps, regie.phase]
	await settle(40)
	check(frozen == [regie.index, regie.temps, regie.phase] and view.play.text == "REPRENDRE", "Rien n'avance pendant la pause")
	# Le journal ouvert pendant un temps fort ne devance pas l'image.
	view._toggle_drawer("Journal")
	await settle(2)
	var told: int = view.journal.get("_live").get("events", []).size()
	check(told == mini(int(regie.tf.plans[regie.index].index) + 1, app.model.live.events.size()), "Le journal ouvert s'arrête à l'action montrée : %d sur %d" % [told, app.model.live.events.size()])
	view._toggle_drawer("Journal")
	view._pause()
	await wait_command()
	check(not app.model.live.paused and not regie.gel, "La reprise relance le temps fort")
	regie.vitesse = allure
	check(await until(func(): return regie.etat == regie.INTER and not app.waiting, 120000), "Le coup d'envoi se termine et rend la main à l'écran intermédiaire")
	check(float(regie.suivi[0].get("duree_reelle", 0.0)) > 0.0, "Le temps fort interrompu par la pause va à son terme")
	# Remplacement et consigne pendant l'écran intermédiaire.
	await until(func(): return regie.etat == regie.INTER and not app.waiting, 60000)
	await command("pause", {"paused": true})
	var before := highlights(regie.suivi)
	var options: Array = app.model.live.get("substitutions", []).filter(func(option: Dictionary): return not option.get("inIds", []).is_empty())
	check(not options.is_empty(), "Des remplacements sont proposés pendant la pause")
	if not options.is_empty():
		var choice: Dictionary = options[0]
		await command("substitute", {"slot": int(choice.slot), "outId": choice.outId, "inId": choice.inIds[0]})
		check(app.model.live.lineup[int(choice.slot)].get("id") == choice.inIds[0], "Le remplaçant entre pendant l'écran intermédiaire")
	var tactics: Dictionary = app.model.get("tactics", {})
	var other := ""
	for option: Dictionary in tactics.get("attacks", []):
		if option.get("id") != tactics.get("attack"): other = str(option.get("id"))
	check(not other.is_empty(), "Une autre consigne est proposée")
	await command("set_tactics", {"attack": other, "defense": tactics.get("defense", "equilibre")})
	check(app.model.tactics.attack == other, "La consigne donnée pendant l'écran intermédiaire est appliquée")
	check(regie.etat == regie.INTER and regie.between.is_visible_in_tree() and highlights(regie.suivi) == before, "Remplacement et consigne ne rejouent aucun temps fort")
	var minute: int = app.model.live.minute
	await settle(40)
	check(app.model.live.minute == minute and not app.waiting, "En pause, l'horloge attend")
	await command("pause", {"paused": false})
	check(await until(func(): return app.model.live.minute > minute, 60000), "Le match reprend après la pause")
	# Le niveau choisi dans la barre vaut tout de suite et pour les prochains matchs.
	var extended := labels.find("Temps forts étendus")
	if level != null and extended >= 0:
		level.select(extended)
		level.item_selected.emit(extended)
		check(regie.niveau == "etendus" and app.user_preferences.data.get("match_highlights") == "etendus", "Le niveau choisi est appliqué et enregistré : " + str(app.user_preferences.last_error))
		check(FileAccess.get_file_as_string(str(app.model.meta.dataDir).path_join("interface.json")).contains("etendus"), "Le niveau est écrit dans les réglages du profil")
	# Mi-temps : le dernier temps fort de la période passe avant la causerie.
	var sample: Dictionary = {}
	var half := {"reached": false}
	var deadline := Time.get_ticks_msec() + 400000
	while Time.get_ticks_msec() < deadline and talk().get("phase") != "half":
		await process_frame
		watch()
		var direct: Dictionary = app.model.live.get("direct", {})
		if sample.is_empty() and direct.get("tempsFort") is Dictionary and int(app.model.live.minute) > 3: sample = direct.tempsFort.duplicate(true)
	half = await reach_talk("half", 120000)
	check(half.reached, "La causerie de mi-temps s'ouvre")
	check(half.played, "Le dernier temps fort de la première période est joué avant la causerie")
	print("Mi-temps à la minute ", half.minute, " · causerie retenue par un temps fort : ", half.held)
	if not half.reached: return followed
	var half_scene := talk().duplicate(true)
	var seen_key := str(app.management_ui.get("match_temps_forts_cle", ""))
	director.view._continue(true)
	await wait_command()
	view = surface()
	check(view != null and view.regie != null, "La seconde période reprend dans la vue du match")
	if view == null or view.regie == null: return followed
	regie = view.regie
	var journal: Array = regie.suivi
	# Seul un temps fort nouveau (le coup d'envoi de la seconde période) peut s'ouvrir ici.
	check(highlights(journal) == 0 or (highlights(journal) == 1 and str(app.management_ui.get("match_temps_forts_cle", "")) != seen_key), "Après la causerie, aucun temps fort de la première période n'est rejoué : " + str(journal))
	check(await until(func(): return int(app.model.live.minute) > int(half.minute) + 1, 60000), "La seconde période avance")
	# Démonstration à coup sûr : une causerie arrive avec un temps fort encore à montrer.
	await until(func(): return regie.etat == regie.INTER and not app.waiting, 120000)
	await command("pause", {"paused": true})
	check(not sample.is_empty(), "Un temps fort réel sert de modèle")
	if not sample.is_empty():
		var model: Dictionary = app.model.duplicate(true)
		sample["cle"] = "avant-causerie"
		# Depuis l'entracte (#587), un temps fort qui n'est pas la suite d'une action attend la fin de l'entracte, et le
		# match est ici en pause (l'entracte ne défile pas). La démonstration cible donc un temps fort « suite » :
		# il part aussitôt, et la causerie doit l'attendre. La retenue par l'entracte est couverte par interval().
		sample["suite"] = true
		model.live.direct.tempsFort = sample
		model.clubLife.matchTalks.scene = half_scene
		app.model = model
		var already := highlights(journal)
		director.sync()
		check(director.kind == "live" and regie.etat == regie.JEU, "Un temps fort à montrer retient la causerie · " + str(director.kind) + " · état " + str(regie.etat) + " (JEU=" + str(regie.JEU) + ", INTER=" + str(regie.INTER) + ")")
		check(not view.finish.visible, "Pas de validation pendant le temps fort")
		check(await until(func(): return director.kind == "locker", 120000), "La causerie s'ouvre quand le temps fort est fini")
		var last: Dictionary = journal.filter(func(entry: Dictionary): return entry.evenement == "temps_fort")[-1] if highlights(journal) > already else {}
		check(highlights(journal) == already + 1 and float(last.get("duree_reelle", 0.0)) > 0.0, "Le temps fort est allé à son terme avant la causerie")
		followed = followed + journal
		await command("snapshot")
		await settle()
		view = surface()
		check(view != null and view.regie != null and view.regie.etat == view.regie.INTER and highlights(view.regie.suivi) == 0, "Retour au match sans rejouer le temps fort")
		if view == null or view.regie == null: return followed
		regie = view.regie
		journal = regie.suivi
	await command("pause", {"paused": false})
	# Fin de match : le dernier temps fort, puis le débrief, puis le retour au club.
	deadline = Time.get_ticks_msec() + 400000
	while Time.get_ticks_msec() < deadline and talk().get("phase") != "post":
		await process_frame
		watch()
	var post: Dictionary = await reach_talk("post", 120000)
	check(post.reached and app.model.live.finished, "Le débrief s'ouvre à la fin du match")
	check(post.played, "Le dernier temps fort du match est joué avant le débrief")
	print("Fin du match à la minute ", post.minute, " · débrief retenu par un temps fort : ", post.held, " · score ", app.model.live.score, " · arrêts sur carton repris : ", stoppages.size())
	followed = followed + journal
	if post.reached:
		director.view._continue(true)
		await wait_command()
		await settle()
		check(app.model.get("live") == null and not director.active(), "Le débrief validé rend la main au club")
		check(app.root_content.is_visible_in_tree(), "L'écran du club revient après le match")
	# Le son du stade suit l'image : chaque réaction part pendant le plan qu'elle accompagne.
	var expected := {"stadium-try": ["try"], "stadium-goal": ["goal", "transformation"], "stadium-miss": ["miss", "transformation"]}
	var misplaced: Array = cues.filter(func(cue: Dictionary): return cue.kind not in expected.get(cue.id, []))
	check(misplaced.is_empty(), "Aucune réaction du stade hors de l'action montrée : " + str(misplaced))
	var audible: bool = is_instance_valid(app.soundscape) and app.soundscape.get("_profile_ready") and int(app.soundscape.preferences.get_value("stadium_volume")) > 0
	var scoring: bool = shown.has("try") or shown.has("goal") or shown.has("miss") or shown.has("transformation")
	print("Réactions du stade : ", cues.size(), " · son actif : ", audible, " · plans montrés : ", shown.keys())
	if audible and scoring: check(not cues.is_empty(), "Le stade réagit aux essais et aux tirs montrés")
	return followed

## Match repris en cours de route : rien n'est rejoué, puis la fin est confiée à l'adjoint.
func resumed() -> Array:
	var director: Node = app.contextual_director
	var view := surface()
	check(view != null and view.regie != null and view.temps_forts_actifs(), "Le match en cours rouvre en temps forts")
	if view == null or view.regie == null: return []
	var regie: Node = view.regie
	var direct: Dictionary = app.model.live.direct
	print("Reprise à ", direct.get("horloge"), " · temps fort déjà simulé : ", direct.get("tempsFort") is Dictionary)
	check(int(app.model.live.minute) >= 20, "La sauvegarde reprend en cours de match (minute %d)" % int(app.model.live.minute))
	check(regie.etat == regie.INTER and regie.between.is_visible_in_tree() and highlights(regie.suivi) == 0, "Aucun temps fort passé n'est rejoué à la reprise")
	check(regie.suivi.any(func(entry: Dictionary): return entry.evenement == "reprise"), "La reprise est notée par la régie")
	check(is_equal_approx(regie.vitesse, 1.0), "Un temps fort se joue à vitesse réelle")
	check(regie.niveau == "etendus", "Le niveau enregistré au match précédent est repris : " + regie.niveau)
	# Écran intermédiaire : sa barre de commandes porte le niveau (la barre du direct est masquée).
	var level: OptionButton = view.find_child("MatchLevel", true, false)
	var repris: String = level.get_item_text(level.selected) if level != null and level.is_visible_in_tree() else regie.between.niveau_libelle()
	check(repris == "Temps forts étendus", "La barre ou les paramètres montrent le niveau repris : " + repris)
	check(view.stage.get("_gestes") != null, "Les gestes sont actifs par défaut")
	# Écran intermédiaire : la minute du moteur, secondes comprises (entracte, 12 novembre 2026).
	var differee: String = regie.between.horloge_differee().trim_suffix("′")
	check(view.clock.text.begins_with(str(direct.get("horloge", "")).trim_suffix("′") + ":") or view.clock.text.begins_with(str(direct.get("horlogeMontree", "")).trim_suffix("′") + ":") or not differee.is_empty() and view.clock.text.begins_with(differee + ":"), "L'horloge du match repris est affichée : " + view.clock.text)
	await settle(40)
	check(highlights(regie.suivi) == 0 and regie.etat == regie.INTER and not app.waiting, "En pause, le match repris attend")
	var minute: int = app.model.live.minute
	await command("pause", {"paused": false})
	check(await until(func(): return int(app.model.live.minute) >= minute + 2, 120000), "Le match repris continue")
	# « Confier la fin à l'adjoint » : pendant un temps fort si possible.
	var playing: bool = await until(func(): return regie.etat == regie.JEU and not app.waiting, 180000)
	await until(func(): return not app.waiting, 30000)
	var before := highlights(regie.suivi)
	await command("delegate")
	check(app.model.live.finished, "L'adjoint termine le match : " + app.last_error)
	await settle()
	print("Fin confiée à l'adjoint pendant un temps fort : ", playing, " · score final ", app.model.live.score)
	check(regie.etat == regie.INTER and regie.between.is_visible_in_tree(), "La fin confiée ramène à l'écran intermédiaire")
	check(regie.suivi.any(func(entry: Dictionary): return entry.evenement == "delegation"), "La délégation est notée par la régie")
	await settle(60)
	check(highlights(regie.suivi) == before and regie.etat == regie.INTER, "Aucun temps fort n'est joué après la délégation")
	var final: Array = app.model.live.score
	check(view.clock.text == "TERMINÉ" and view.score.text == "%d — %d" % [int(final[0]), int(final[1])], "Le score final est affiché : " + view.score.text)
	check(view.finish.is_visible_in_tree() and not view.finish.disabled, "La journée peut être validée")
	var followed: Array = regie.suivi
	await command("finish_round")
	await settle()
	check(app.model.get("live") == null and (not director.active() or director.kind != "live"), "La journée validée referme le match")
	return followed

## Terrain 2D de l'entracte (demande de Léo, 12 novembre 2026) et tableau de bord autour.
func terrain2d(view: Control) -> void:
	var regie: Node = view.regie
	check(regie != null and view.temps_forts_actifs(), "La régie cadence le match")
	if regie == null: return
	var between: Control = regie.between
	var terrain: Control = between.terrain
	check(terrain != null and terrain.name == "MatchBetweenPitch", "Le terrain 2D est dans l'écran intermédiaire")
	# Chaque fait joué sur le terrain : où sont les joueurs à la fin, et à qui est le ballon.
	var joues: Array[Dictionary] = []
	var ecarts := {"max": 0.0, "faits": 0, "possession": 0, "hors_journal": 0, "avant_retenu": 0}
	terrain.fait_joue.connect(func(item: Dictionary):
		var live: Dictionary = app.model.live
		var i := int(item.get("i", -1))
		var evenement: Variant = live.events[i] if i >= 0 and i < live.events.size() else null
		if not evenement is Dictionary or not evenement.get("scene") is Dictionary: ecarts.hors_journal += 1
		elif int(evenement.scene.get("possession", -1)) != int(terrain.possession): ecarts.possession += 1
		if not regie._retenu.is_empty() and i >= regie._retenu_vus: ecarts.avant_retenu += 1
		for cle: String in terrain.cibles:
			ecarts.max = maxf(ecarts.max, (terrain.places[cle] as Vector2).distance_to(terrain.cibles[cle].place))
		ecarts.faits += 1
		joues.append(item))
	check(await until(func(): return regie.etat == regie.INTER, 60000), "Le coup d'envoi se termine")
	await settle(4)
	check(terrain.places.size() >= 28 and terrain.places.size() <= 30, "Trente pastilles sur le terrain après le coup d'envoi (%d)" % terrain.places.size())
	check(terrain.suivi.any(func(e: Dictionary): return e.evenement == "recale"), "Le terrain repart de la dernière image du temps fort")
	# Pause (match importé en pause) : tout est figé.
	check(app.model.live.paused and terrain.gel, "Match en pause : le terrain 2D est figé")
	var fige: Dictionary = terrain.places.duplicate()
	var images: int = terrain.images
	await settle(30)
	check(terrain.images == images and fige.keys().all(func(c: String): return (terrain.places[c] as Vector2).is_equal_approx(fige[c])), "Pause : aucune pastille ne bouge")
	await command("pause", {"paused": false})
	# Pendant les entractes : les pastilles bougent, les faits du moteur s'enchaînent. Plusieurs
	# entractes : un temps fort décidé tout de suite peut laisser un entracte sans fait montrable.
	var debut := Time.get_ticks_msec()
	var deplacement := 0.0
	var ballons := {}
	var fil_en_avance := 0
	var score_faux := 0
	var devoile := 0
	var entractes := 0
	while entractes < 5 and (ecarts.faits < 4 or entractes < 2) and Time.get_ticks_msec() - debut < 300000:
		check(await until(func(): return regie.etat == regie.INTER and between.visible, 120000), "Entracte %d" % (entractes + 1))
		if app.model.live.paused and regie.arret.is_empty() and not app.model.live.finished: await command("pause", {"paused": false})
		if not regie.arret.is_empty(): between.reprise_demandee.emit()
		entractes += 1
		# Plus haut indice du journal montré pendant l'entracte (terrain, fil) : le temps fort
		# suivant doit commencer après (« on découvre l'action en la regardant »).
		var montre_max := -1
		var avant: Dictionary = terrain.places.duplicate()
		var t0 := Time.get_ticks_msec()
		while regie.etat != regie.JEU and Time.get_ticks_msec() - t0 < 90000:
			await process_frame
			if app.model.live.get("finished", false) or app.model.live.get("atBreak", false): break
			if regie.etat == regie.INTER and between.visible:
				montre_max = maxi(montre_max, terrain.joue_i)
				for ligne: Dictionary in between._lignes: montre_max = maxi(montre_max, int(ligne.get("i", -1)))
			for cle: String in terrain.places:
				if avant.has(cle): deplacement += (terrain.places[cle] as Vector2).distance_to(avant[cle])
			avant = terrain.places.duplicate()
			ballons[str(terrain.ballon.round())] = true
			# Le fil ne dit jamais un fait que le terrain n'a pas encore joué.
			if terrain.prochain_i() >= 0:
				for enfant: Node in between.fil.get_children():
					if not enfant.is_queued_for_deletion() and int(enfant.get_meta("i", -1)) >= terrain.prochain_i():
						fil_en_avance += 1
						if fil_en_avance < 4: print("FIL_AVANCE ", enfant.get_meta("i", -1), " prochain=", terrain.prochain_i(), " joue=", terrain.joue_i)
			var differe: Array = between.score_differe()
			if not differe.is_empty() and view.score.text != "%d — %d" % [int(differe[0]), int(differe[1])]: score_faux += 1
		var suivant: Array = regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort")
		if regie.etat == regie.JEU and not suivant.is_empty() and montre_max >= int(suivant[-1].get("debut", -1)): devoile += 1
		print("ENTRACTE2D ", entractes, " montre_max=", montre_max, " temps_fort_debut=", int(suivant[-1].get("debut", -1)) if not suivant.is_empty() else -1, " faits=", ecarts.faits)
	check(entractes >= 2 and devoile == 0, "Rien du temps fort suivant n'a été montré pendant les %d entractes (%d dévoilé(s))" % [entractes, devoile])
	check(deplacement > 30.0, "Les pastilles bougent pendant l'entracte (%.0f m cumulés)" % deplacement)
	check(ballons.size() >= 4, "Le ballon circule (%d positions)" % ballons.size())
	check(ecarts.faits >= 1, "Des faits du moteur sont rejoués sur le terrain (%d)" % ecarts.faits)
	check(ecarts.max < 0.05, "En fin de fait, chaque pastille est à la place du moteur (écart max %.3f m)" % ecarts.max)
	check(ecarts.possession == 0, "Le terrain suit la possession du moteur (%d écart(s))" % ecarts.possession)
	check(ecarts.hors_journal == 0 and ecarts.avant_retenu == 0, "Rien d'inventé : chaque fait vient du journal, aucun après un temps fort retenu")
	check(fil_en_avance == 0, "Le fil attend que le terrain ait joué le fait (%d ligne(s) en avance)" % fil_en_avance)
	check(score_faux == 0, "Le score suit le terrain quand il rejoue un fait en retard")
	check(terrain.cadence > 0.0 and absf(terrain.cadence - float(regie.HORLOGES[regie.horloge]) / regie.vitesse) < 0.01, "Le terrain suit l'horloge de l'entracte")
	# Tableau de bord : alimenté par la projection du moteur.
	check(await until(func(): return regie.etat == regie.INTER and regie._retenu.is_empty(), 120000), "Retour à l'écran intermédiaire")
	await until(func(): return not app.waiting, 30000)
	if not app.model.live.paused: await command("pause", {"paused": true})
	await settle(6)
	var direct: Dictionary = regie._live_inter.get("direct", app.model.live.direct)
	var minutes: Array = direct.get("domination", {}).get("minutes", [])
	check(minutes.size() >= 1 and between.domination.minutes == minutes, "Domination : la courbe du moteur, minute par minute (%d minutes)" % minutes.size())
	check(minutes.all(func(v: Variant): return absf(float(v)) <= 100.0), "Domination bornée")
	var rangs: Array = direct.get("tableau", [])
	check(rangs.size() >= 10 and between.chiffres.get_child_count() == 3, "Chiffres clés : trois en grand, %d dans l'onglet" % rangs.size())
	for ligne: Node in between.chiffres.get_children():
		var titre := (ligne.get_child(0) as Label).text
		var rang: Array = rangs.filter(func(r: Dictionary): return str(r.label) == titre)
		check(rang.size() == 1 and (ligne.get_child(1) as Label).text.begins_with(str(int(rang[0].valeurs[0]))) and (ligne.get_child(3) as Label).text.begins_with(str(int(rang[0].valeurs[1]))) or rang.size() == 1 and rang[0].get("vide", false), "Chiffre « %s » repris du moteur" % titre)
	var lineup: Array = between._passe(app.model, app.model.live, direct).lineup
	var lignes_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button)
	check(lignes_xv.size() == lineup.size() and lineup.size() == 15, "Mon XV : quinze joueurs (%d)" % lignes_xv.size())
	var conformes := 0
	for poste in mini(lineup.size(), lignes_xv.size()):
		var joueur: Variant = lineup[poste]
		if not joueur is Dictionary: continue
		var textes: Array = lignes_xv[poste].find_children("*", "Label", true, false).map(func(l: Label): return l.text)
		var energie: Array = lignes_xv[poste].find_children("*", "Control", true, false).filter(func(c: Control): return c.get("valeur") != null)
		var note := float(direct.get("notes", {}).get(str(joueur.id), {}).get("note", 6.0))
		if str(joueur.name) in textes and "%.1f" % note in textes and not energie.is_empty() and is_equal_approx(float(energie[0].valeur), float(joueur.condition)): conformes += 1
	check(conformes == lineup.size(), "Mon XV : nom, note et énergie du moteur pour chaque joueur (%d/%d)" % [conformes, lineup.size()])
	var alertes_attendues := lineup.filter(func(j: Variant): return j is Dictionary and (int(j.get("injury", 0)) > 0 or float(j.get("condition", 100)) < between.FATIGUE)).size()
	check(between.alertes_xv.size() >= alertes_attendues, "Alertes de fatigue et de blessure reprises (%d pour %d)" % [between.alertes_xv.size(), alertes_attendues])
	# Alerte de fatigue : un joueur à bout (condition modifiée sur une copie) est signalé par l'adjoint.
	var copie: Dictionary = app.model.duplicate(true)
	copie.live.lineup[6].condition = 31
	var direct_complet: Dictionary = direct.duplicate()
	direct_complet["borne"] = copie.live.events.size()
	between.update_frame(copie, copie.live, direct_complet, func(_c: Dictionary): pass)
	var adjoint_textes: Array = between.adjoint.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
	check(adjoint_textes.any(func(t: String): return t.begins_with("N° 7") and "31" in t), "L'adjoint signale le joueur à bout : " + str(adjoint_textes.slice(0, 3)))
	var phrases := {}
	var redites := 0
	for t: String in adjoint_textes:
		for phrase: String in t.split(". ", false):
			var cle := phrase.strip_edges().trim_suffix(".")
			if cle.length() > 12 and phrases.has(cle): redites += 1
			phrases[cle] = true
	check(redites == 0, "L'adjoint ne répète pas une phrase : " + str(adjoint_textes))
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	# Accès directs : remplacements depuis l'adjoint, et un joueur de Mon XV ouvre le banc sur lui.
	var banc: Button = between.find_child("MatchBetweenBench", true, false)
	check(banc != null and banc.is_visible_in_tree() and between.find_child("MatchBetweenTactics", true, false) != null, "Tactique et remplacements accessibles depuis l'écran")
	check(between.xv.is_visible_in_tree() and between.fil.is_visible_in_tree(), "Mon XV et le dernier fait affichés ensemble")
	var noms_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button).map(func(b: Button): return b.find_children("*", "Label", true, false).filter(func(l: Label): return l.visible).map(func(l: Label): return l.text))
	check(noms_xv.size() == 15 and noms_xv.all(func(t: Array): return t.size() >= 2 and not str(t[0]).is_empty()), "Mon XV : nom de famille et note visibles pour chaque joueur : " + str(noms_xv.slice(0, 3)))
	# Paramètres : vitesse de l'horloge et temps forts montrés dans un petit panneau.
	between.find_child("MatchBetweenSettings", true, false).pressed.emit()
	await settle(4)
	check(between.panneau_parametres.visible and between.grille_niveaux.get_child_count() == 6, "Paramètres : le panneau s'ouvre avec les six niveaux de temps forts")
	between.panneau_parametres.hide()
	var rangs_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button)
	(rangs_xv[9] as Button).pressed.emit()
	await settle(4)
	check(view.drawer.visible and view.drawer_tab == "Banc" and view.selected_slot == 9, "Un joueur de Mon XV ouvre le banc sur lui (poste %d)" % view.selected_slot)
	view._fermer_tiroir()
	var menu: MenuButton = between.find_child("MatchBetweenMore", true, false)
	check(menu != null and menu.get_popup().get_item_text(0) == "Statistiques", "Tous les chiffres du moteur restent dans le tiroir Statistiques (menu Plus)")
	await layout(view, Vector2i(1280, 720))
	await layout(view, Vector2i(1920, 1080))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	print("TERRAIN2D ", JSON.stringify({"faits": ecarts.faits, "deplacement": deplacement, "ballons": ballons.size(), "minutes": minutes.size()}))
