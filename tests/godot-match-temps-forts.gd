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
## Mode « entracte » : entre deux temps forts, le match défile en 2D (horloge qui défile), aucun
## temps fort n'est retenu, plus de « Passer » (décision de Léo, 12 novembre 2026) ; la tactique
## ouverte met en pause et ses changements passent ; aucun anneau au sol sous les joueurs.
## Mode « terrain2d » : pendant l'entracte, le match continue sur le terrain 2D (pastilles qui
## rejouent les faits du moteur, possession suivie, pause qui fige, rien d'inventé) et le
## tableau de bord (domination, chiffres, Mon XV, adjoint) est alimenté par les vraies données.
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
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
	# Plan large : au-delà du cadrage le plus large d'un temps fort (54 m en TV depuis le soir du 12 novembre 2026).
	if camera.size > 54.5 and not veiled:
		framing.wide += 1
		var gestes: RefCounted = view.stage.get("_gestes")
		if framing.where.size() < 12: framing.where.append("large %.1f m : plan %d %s à %.2f s, %s, suite %s, poids %.2f, geste %s zoom %.2f, voile %.2f" % [camera.size, view.regie.index, view.regie.phase, view.regie.temps, str(view.regie.tf.plans[view.regie.index].get("kind", "")) if view.regie.index >= 0 else "", str(view.regie.tf.get("suite", false)), float(view.regie.cadrage.poids), str(gestes.phase) if gestes != null else "-", float(gestes.zoom) if gestes != null else 0.0, view.regie.voile.modulate.a if view.regie.voile.visible else 0.0])
	# Zone libre : ni sous le bandeau du score, ni sous la légende et les commandes.
	var legend: Control = view.events.get_parent().get_parent().get_parent()
	var top: float = 0.5 - view.clock.get_global_rect().end.y / maxf(1.0, view.size.y)
	var bottom: float = -0.5 + (view.size.y - legend.get_global_rect().position.y) / maxf(1.0, view.size.y)
	# Caméras en perspective depuis le 18 novembre 2026 : position réelle du ballon à l'écran (0,5 au centre).
	var seen := camera.unproject_position(ball.global_position) / screen - Vector2(0.5, 0.5)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		seen = Vector2(local.x / (camera.size * screen.x / screen.y), -local.y / camera.size)
	if camera.is_position_behind(ball.global_position) or absf(seen.x) > 0.5 or -seen.y > top or -seen.y < bottom:
		if veiled: framing.hidden += 1
		else:
			framing.outside += 1
			framing.where.append("plan %d %s à %.2f s, voile %.2f, %s" % [view.regie.index, view.regie.phase, view.regie.temps, view.regie.voile.modulate.a if view.regie.voile.visible else 0.0, str(view.regie.tf.plans[view.regie.index].get("kind", "")) if view.regie.index >= 0 else ""])

func check_framing(label: String, highlights: int) -> void:
	print(label, " — cadrage : ", framing.frames, " images, hauteur visible de ", snappedf(framing.smallest, 0.1), " à ", snappedf(framing.largest, 0.1), " m, ballon hors champ ", framing.outside, " (", framing.hidden, " sous le voile d'entrée), images larges visibles ", framing.wide, " ", framing.where)
	check(framing.frames >= 60, label + " : cadrage observé pendant les temps forts (%d images)" % framing.frames)
	check(framing.outside == 0, label + " : le ballon ne sort jamais du champ visible (%d images : %s)" % [framing.outside, str(framing.where)])
	# Caméra reculée (12 novembre 2026, soir) : 26 à 28 m au plus serré en TV, jamais plus près que 9 m (contact).
	check(framing.smallest >= 9.0 and framing.smallest <= 42.5, label + " : l'action est cadrée, ni trop près ni trop loin (%.1f m au plus serré)" % framing.smallest)
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
	check(pitch.size.x >= 320 and pitch.size.y >= 180 and pitch.champ().size.x >= 260, label + " : terrain lisible (%s)" % str(pitch.size))
	# Pastilles entières dans le cadre : la marge intérieure couvre une pastille sur la touche.
	check(pitch.point(0.0, -2.0).y - pitch.rayon() >= 0.0 and pitch.point(100.0, 72.0).y + pitch.rayon() <= pitch.size.y, label + " : pastilles du bord entières dans le terrain")
	var controls: Control = view.finish.get_parent().get_parent().get_parent()
	check(not controls.is_visible_in_tree() or between.get_global_rect().end.y <= controls.get_global_rect().position.y + 1.0, label + " : rien sous la barre de commandes")
	check(not controls.is_visible_in_tree(), label + " : une seule barre de commandes (celle de l'écran intermédiaire)")
	check(between.get_global_rect().position.y >= view.clock.get_global_rect().end.y - 1.0, label + " : rien sous le bandeau du score")
	# Notre XV, vue Terrain puis vue Tableau : rien n'est coupé dans l'une ni dans l'autre.
	var vue_avant: String = between.vue_xv
	between.find_child("MatchBetweenTabPitch", true, false).pressed.emit()
	await settle(4)
	check(between.vue_xv == "terrain" and between.formation.is_visible_in_tree() and not between.xv.is_visible_in_tree() and between.tuile_principale.is_ancestor_of(between.formation), label + " : Notre XV en vue Terrain, tuile principale")
	var cases: Array = between.formation.cases
	check(cases.size() == 15 and cases.all(func(b: Button): return b.is_visible_in_tree() and inside(between.formation.get_global_rect(), b.get_global_rect())), label + " : quinze joueurs dans le mini-terrain (%d)" % cases.size())
	var anneaux: Array = between.formation.anneaux
	check(anneaux.size() == 15 and anneaux.all(func(a: Control): return a.size.x >= 18.0 and a.size.y >= 18.0), label + " : anneaux d'énergie lisibles (%s)" % (str(anneaux[0].size) if not anneaux.is_empty() else "aucun"))
	var etiquettes: Array = between.formation.find_children("*", "Label", true, false)
	check(not etiquettes.is_empty() and etiquettes.all(func(l: Label): return l.get_theme_font_size("font_size") >= 13), label + " : noms et notes du terrain lisibles")
	_pas_coupe(between, label + " (Terrain)")
	if proof != "" and OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES") != "": await _capture(label, "terrain")
	between.find_child("MatchBetweenTabOwn", true, false).pressed.emit()
	await settle(4)
	check(between.xv.is_visible_in_tree() and between.xv.columns == 1 and between.tuile_principale.is_ancestor_of(between.xv) and not between.formation.is_visible_in_tree(), label + " : Mon XV en tableau, tuile principale (onglet Tableau)")
	_pas_coupe(between, label + " (Tableau)")
	if proof != "" and OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES") != "": await _capture(label, "tableau")
	check(between.chiffres.get_child_count() >= 3 and between.fil.get_child_count() >= 1, label + " : fil et chiffres remplis")
	# Mise à l'échelle : texte de 13 points au moins en 720p, doublé en 1440p.
	var density: float = between.densite_pour(Vector2(size))
	var figure: Label = between.chiffres.get_child(0).get_child(0)
	check(is_equal_approx(between._densite, density) and figure.get_theme_font_size("font_size") == roundi(26 * density), label + " : chiffres à l'échelle (%d points)" % figure.get_theme_font_size("font_size"))
	check(figure.get_theme_font_size("font_size") >= 13 and between.etat.get_theme_font_size("font_size") == roundi(34 * density), label + " : texte lisible")
	# Les commandes communes sont dans la bande sous le score (la même qu'en 3D).
	var bande: Control = view.get("bande_temps_forts")
	check(bande != null and bande.is_visible_in_tree() and bande.get_global_rect().position.y >= view.clock.get_global_rect().end.y - 1.0 and bande.get_global_rect().end.y <= between.get_global_rect().position.y + 1.0, label + " : bande de commandes sous le score, au-dessus de l'entracte")
	for nom in ["MatchBetweenTeam", "MatchBetweenSettings", "MatchBetweenMore"]:
		var noeud: Control = view.find_child(nom, true, false)
		check(noeud != null and noeud.is_visible_in_tree() and bande != null and bande.is_ancestor_of(noeud) and inside(screen, noeud.get_global_rect()), label + " : commande " + nom)
	check(not view.find_children("*", "OptionButton", true, false).any(func(o: OptionButton): return o.is_visible_in_tree()), label + " : pas de sélecteur « Horloge … » dans la bande (vitesse dans Paramètres)")
	check(between.domination.is_visible_in_tree() and between.domination.size.y >= between.px(120), label + " : frise du match visible (%d px)" % int(between.domination.size.y))
	check(not between.adjoint_cadre.visible or between.adjoint_cadre.is_visible_in_tree(), label + " : carte de Gabi à l'écran")
	# Les faits marquants restent à l'écran, même avec le pilotage ; les consignes en direct sont dans la fenêtre Équipe.
	check(between.faits.is_visible_in_tree() and between.faits.get_child_count() >= 1, label + " : faits marquants")
	check(between.find_child("MatchBetweenConsignes", true, false) == null and between.find_children("Consigne_*", "BoxContainer", true, false).is_empty(), label + " : pas de consignes sur l'écran 2D")
	# Maquette du 16 novembre 2026 : le terrain 2D en grand au centre, plus large que Notre XV et que le duel.
	var colonne_xv: Control = between.find_child("MatchBetweenSquadColumn", true, false)
	var column: Control = between.find_child("MatchBetweenColumn", true, false)
	check(pitch.size.x >= size.x * 0.38 and pitch.size.y >= size.y * 0.35 and pitch.size.x > colonne_xv.size.x and pitch.size.x > column.size.x, label + " : terrain 2D en grand au centre (%s)" % str(pitch.size))
	check(colonne_xv.get_global_rect().end.x <= pitch.get_global_rect().position.x and column.get_global_rect().position.x >= pitch.get_global_rect().end.x, label + " : Notre XV à gauche, le duel à droite")
	# Le bandeau du dernier fait est posé sur le terrain, en haut.
	var bandeau: Control = between.bandeau
	check(bandeau.is_visible_in_tree() and between.terrain.get_parent().is_ancestor_of(bandeau) and bandeau.get_global_rect().position.y <= pitch.get_global_rect().position.y + pitch.size.y * 0.2, label + " : dernier fait en bandeau sur le terrain")
	# Anneaux possession et occupation, tuile « Dans les 22 » seulement avec sa donnée.
	for anneau: Control in [between.anneau_possession, between.anneau_occupation]:
		check(anneau.is_visible_in_tree() and anneau.size.x >= between.px(110) and not str(anneau.texte_centre()).is_empty(), label + " : anneau " + str(anneau.name) + " (" + anneau.texte_centre() + ")")
	var direct_vu: Dictionary = between._dernier[2] if between._dernier.size() == 4 else {}
	check(between.zone22.visible == (direct_vu.get("zone22") is Dictionary), label + " : tuile « Dans les 22 » montrée seulement avec sa donnée")
	check(between.carte_changement.is_visible_in_tree() and between.carte_changement.get_global_rect().position.y >= between.tuile_principale.get_global_rect().end.y - 1.0 and between.find_child("MatchBetweenSwapAction", true, false).is_visible_in_tree(), label + " : carte Changement sous Notre XV")
	# Gabi en largeur, en bas.
	# Avec la journée en direct, le multiplex partage la bande du bas avec Gabi.
	var bande_bas: float = between.adjoint_cadre.size.x + (between.multiplex.size.x + between.px(20) if between.multiplex.visible else 0.0)
	check(not between.adjoint_cadre.visible or bande_bas >= between.size.x * 0.9 and between.adjoint_cadre.get_global_rect().position.y >= pitch.get_global_rect().end.y, label + " : carte de Gabi en largeur, en bas")
	var used := 0.0
	for panel: Control in column.get_children():
		if panel.visible: used += panel.size.y
	check(used >= column.size.y * 0.9, label + " : la colonne de droite est occupée (%d sur %d px)" % [int(used), int(column.size.y)])
	for row: Control in between.chiffres.get_children():
		for cell: Label in row.find_children("*", "Label", true, false):
			check(cell.get_minimum_size().x <= cell.size.x + 1.0 or cell.clip_text, label + " : chiffre entier : " + cell.text)
	# Vue rendue telle que le joueur l'avait.
	between.find_child({"terrain": "MatchBetweenTabPitch", "tableau": "MatchBetweenTabOwn", "adverse": "MatchBetweenTabOpponent"}[vue_avant], true, false).pressed.emit()
	await settle(2)

## Rien de l'écran intermédiaire ne déborde de son cadre (le fil défile : ses lignes anciennes sont
## atteignables, pas coupées).
func _pas_coupe(between: Control, label: String) -> void:
	var feed: Control = between.fil.get_parent()
	for node: Control in between.find_children("*", "Control", true, false):
		if not node.is_visible_in_tree() or node == between.arret or between.arret.is_ancestor_of(node) or feed.is_ancestor_of(node): continue
		check(inside(between.get_global_rect(), node.get_global_rect()), label + " : " + str(node.name) + " n'est pas coupé" + ("" if inside(between.get_global_rect(), node.get_global_rect()) else " (%s hors de %s)" % [str(node.get_global_rect()), str(between.get_global_rect())]))

## Capture de l'écran (CD_MATCH_TEMPS_FORTS_CAPTURES : dossier ; rendu fenêtré seulement).
func _capture(label: String, vue: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null: return
	var chemin := OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES").path_join("ecran-2d-lot1-%s-%s-%s.png" % [mode, label.replace("×", "x"), vue])
	print("CAPTURE ", chemin, " ", image.get_size(), " ", image.save_png(chemin))

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
	elif mode == "liaison":
		# Carrière Monde arrêtée à la causerie d'avant-match (godot-match-liaison-monde.cjs).
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("monde.json"))})
		await settle()
		var limite := Time.get_ticks_msec() + 120000
		while Time.get_ticks_msec() < limite and (surface() == null or surface().regie == null):
			var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
			if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
			await settle(2)
		var vue := surface()
		check(vue != null and vue.regie != null, "Carrière Monde : le direct en temps forts s'ouvre")
		if vue != null and vue.regie != null:
			await linked(vue)
			followed = vue.regie.suivi
	elif mode == "score_essai":
		# Carrière Monde arrêtée à la causerie d'avant-match (godot-match-score-essai.cjs).
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("monde.json"))})
		await settle()
		var limite_s := Time.get_ticks_msec() + 120000
		while Time.get_ticks_msec() < limite_s and (surface() == null or surface().regie == null):
			var scene_s: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
			if scene_s is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene_s.key, "phase": scene_s.phase, "skip": true})
			await settle(2)
		var vue_s := surface()
		check(vue_s != null and vue_s.regie != null, "Carrière Monde : le direct en temps forts s'ouvre")
		if vue_s != null and vue_s.regie != null:
			await scoring(vue_s)
			followed = vue_s.regie.suivi
	elif mode == "multiplex":
		# Carrière world-champ arrêtée au coup d'envoi de son premier match (godot-match-temps-forts.cjs).
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("multiplex.json"))})
		await settle()
		var limite_m := Time.get_ticks_msec() + 120000
		while Time.get_ticks_msec() < limite_m and (surface() == null or surface().regie == null):
			var scene_m: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
			if scene_m is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene_m.key, "phase": scene_m.phase, "skip": true})
			await settle(2)
		var vue_m := surface()
		check(vue_m != null and vue_m.regie != null, "Carrière Monde : le direct en temps forts s'ouvre")
		if vue_m != null and vue_m.regie != null:
			await journee_directe(vue_m)
			followed = vue_m.regie.suivi
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
			elif mode == "liaison": await linked(view)
			elif mode == "terrain2d": await terrain2d(view)
			else: await inactive(view)
			if view.regie != null: followed = view.regie.suivi
	check_liaisons(followed)
	var report := FileAccess.open(proof.path_join("report-" + mode + ".json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "suivi": followed}, "  "))
	report.close()
	app.closing = true
	app.bridge.stop()
	print("Temps forts (", mode, ") : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)

## Liaisons entre deux temps forts contigus (match_liaison.gd), dans tous les modes : toujours à
## vitesse réelle (jamais d'accéléré, même quand les temps forts sont accélérés pour le test),
## coupe franche en deux plans quand la mise en place est longue, aucun saut de position dans un
## plan, et seulement entre deux temps forts contigus (jamais après l'écran intermédiaire 2D).
func check_liaisons(followed: Array) -> void:
	var liaisons: Array = followed.filter(func(e: Dictionary) -> bool: return e.evenement == "liaison")
	for e: Dictionary in liaisons:
		var nom := "Liaison %s (%s)" % [str(e.type), str(e.cle)]
		if not e.has("duree_reelle"): continue
		check(float(e.duree_reelle) >= float(e.duree_prevue) - 0.2 and float(e.duree_reelle) <= float(e.duree_prevue) + 1.5,
			"%s : jouée à vitesse réelle (%.2f s pour %.2f s prévues)" % [nom, float(e.duree_reelle), float(e.duree_prevue)])
		check(float(e.get("saut_max", 0.0)) <= 10.0, "%s : aucun saut de position dans un plan (pointe %.1f m/s d'une image à l'autre)" % [nom, float(e.get("saut_max", 0.0))])
		var durees: Array = e.get("duree_plans", [])
		if bool(e.coupe):
			check(int(e.plans) == 2 and durees.size() == 2 and float(durees[0]) <= 3.4 and float(durees[1]) >= 1.0 and float(durees[1]) <= 2.1,
				"%s : plan en temps réel puis coupe franche vers la remise en jeu formée (%s)" % [nom, str(durees)])
		else:
			check(int(e.plans) == 1 and float(e.duree_prevue) <= 4.7, "%s : liaison continue de 4,6 s au plus (%s)" % [nom, str(durees)])
	for e: Dictionary in followed:
		if e.evenement == "temps_fort" and not str(e.get("liaison", "")).is_empty():
			check(bool(e.get("contigu", false)) and not bool(e.get("suite", false)), "Liaison seulement entre deux temps forts contigus : " + str(e.get("cle", "")))
	var refusees: Array = followed.filter(func(e: Dictionary) -> bool: return e.evenement == "liaison_refusee" or (e.evenement == "echeance" and str(e.get("cause", "")) == "liaison"))
	check(refusees.is_empty(), "Aucune liaison refusée ni interrompue : " + str(refusees))
	if not liaisons.is_empty(): print("Liaisons jouées : ", liaisons.map(func(e: Dictionary) -> String: return "%s%s %.1f s" % [str(e.type), " (coupe)" if bool(e.coupe) else "", float(e.get("duree_reelle", 0.0))]))

## Bandeau du score pendant un essai (règle de Léo) : rien n'annonce l'essai avant qu'on le voie ;
## une fois aplati et légendé, le score suit (+5), puis la transformation vue (+2) ; le bandeau 2D
## de l'entracte redit le score montré. Mesuré image par image sur les vrais temps forts.
func scoring(view: Control) -> void:
	var regie: Node = view.regie
	var fin := int(OS.get_environment("CD_SCORE_MINUTES")) if OS.get_environment("CD_SCORE_MINUTES").is_valid_int() else 30
	var deadline := Time.get_ticks_msec() + (int(OS.get_environment("CD_SCORE_LIMITE")) if OS.get_environment("CD_SCORE_LIMITE").is_valid_int() else 900) * 1000
	var reprise := false
	var sonde := 0
	var avant := 0
	var apres := 0
	var transfo_avant := 0
	var transfo_apres := 0
	var faux: Array = []
	var inter := 0
	var inter_faux: Array = []
	var captures := {}
	var somme := func(a: Array) -> int: return int(a[0]) + int(a[1])
	while app.model.get("live") is Dictionary and int(app.model.live.minute) < fin and Time.get_ticks_msec() < deadline:
		await process_frame
		sonde += 1
		if sonde % 600 == 0: print("sonde score : minute ", app.model.live.minute, " état ", regie.etat, " phase ", regie.phase, " index ", regie.index, " pause ", app.model.live.paused, " ", avant, "/", apres)
		if not reprise and not app.waiting and regie.etat != regie.JEU:
			reprise = true
			if app.model.live.paused: app._command("pause", {"paused": false})
		if regie.etat == regie.INTER and regie.phase != "liaison" and regie.tf.is_empty() == false and regie._retenu.is_empty():
			var direct: Array = app.model.live.get("direct", {}).get("score", app.model.live.get("score", [0, 0]))
			var differe: Array = regie.between.score_differe()
			var montre: Array = differe if not differe.is_empty() else direct
			inter += 1
			if view.score.text != "%d — %d" % [int(montre[0]), int(montre[1])] and inter_faux.size() < 4: inter_faux.append("%s ≠ %s" % [view.score.text, str(montre)])
			continue
		if regie.etat != regie.JEU or regie.phase != "jeu" or regie.index < 0 or regie.index >= regie.tf.plans.size(): continue
		var plan: Dictionary = regie.tf.plans[regie.index]
		var kind := str(plan.get("kind", ""))
		var affiche: String = view.score.text
		var final: int = somme.call(plan.score)
		var texte := affiche.split(" — ")
		if texte.size() != 2: continue
		var vu: int = int(texte[0]) + int(texte[1])
		if kind == "try":
			var points: int = final - 5
			if not regie._essai_montre:
				# Pas encore aplati : ni légende de l'essai ni nouveau score.
				avant += 1
				if vu != points or str(view.events.text).begins_with("Essai"):
					if faux.size() < 6: faux.append("avant l'aplati : score %s (attendu +0), légende « %s »" % [affiche, str(view.events.text)])
			else:
				apres += 1
				if vu != final and faux.size() < 6: faux.append("essai aplati : score %s (attendu %d points au total)" % [affiche, final])
		elif kind == "transformation" and plan.has("annonce"):
			if not regie._resultat_sonne:
				transfo_avant += 1
				var base: int = somme.call(regie.tf.plans[regie.index - 1].score) if regie.index > 0 else vu
				if vu != base and faux.size() < 6: faux.append("avant le résultat de la transformation : score %s (attendu %d)" % [affiche, base])
			else:
				transfo_apres += 1
				if vu != final and faux.size() < 6: faux.append("transformation vue : score %s (attendu %d)" % [affiche, final])
		# Captures (rendu réel sous xvfb, hors CI) : CD_SCORE_CAPTURES = dossier de sortie.
		var dossier := OS.get_environment("CD_SCORE_CAPTURES")
		if dossier != "" and kind == "try" and not captures.has("png_" + str(regie._essai_montre)) and (regie._essai_montre or regie.temps > 1.0):
			captures["png_" + str(regie._essai_montre)] = true
			await RenderingServer.frame_post_draw
			var image := root.get_viewport().get_texture().get_image()
			if image != null: image.save_png(dossier.path_join("score-essai-" + ("apres" if regie._essai_montre else "avant") + ".png"))
		if apres > 30 and transfo_apres > 5 and avant > 5 and inter > 30: break
	check(avant > 0 and apres > 0, "Des essais sont joués en 3D (%d images avant l'aplati, %d après)" % [avant, apres])
	check(faux.is_empty(), "Bandeau du score : ancien score jusqu'à l'aplati, nouveau score ensuite : " + str(faux))
	check(inter == 0 or inter_faux.is_empty(), "Bandeau 2D de l'entracte cohérent avec le score montré (%d images) : %s" % [inter, str(inter_faux)])
	print("Score pendant l'essai : ", avant, " images avant, ", apres, " après ; transformation ", transfo_avant, "/", transfo_apres, " ; entracte ", inter)

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
	# Décision de Léo (12 novembre 2026) : pas de pause minimale entre deux temps forts, aucune
	# retenue, plus de « Passer ». Le match défile en 2D à l'horloge choisie et le temps fort part
	# dès que le moteur le déclenche, même juste après le précédent.
	check(regie.entracte == 0.0, "Pas de pause minimale entre deux temps forts : %.1f s" % regie.entracte)
	check(await until(func(): return regie.etat == regie.INTER, 60000), "Le coup d'envoi se termine")
	if app.model.live.paused: await command("pause", {"paused": false})
	var horloges := {}
	var passer_vu := false
	var debut := Time.get_ticks_msec()
	var depart_tf: int = regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort").size()
	while regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort").size() < depart_tf + 2 and Time.get_ticks_msec() - debut < 240000:
		await process_frame
		if regie.etat != regie.JEU:
			horloges[view.clock.text] = true
			if between.find_children("*", "Button", true, false).any(func(b: Button): return b.is_visible_in_tree() and ("Passer" in b.text or "Skip" in b.name)): passer_vu = true
	var attendu: float = (Time.get_ticks_msec() - debut) / 1000.0
	check(regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort").size() >= depart_tf + 2, "Le match enchaîne 2D et temps forts")
	check(not regie.suivi.any(func(e: Dictionary): return e.evenement == "entracte_retenu"), "Aucun temps fort n'est retenu : il part dès qu'il est déclenché")
	check(not passer_vu, "Plus de bouton « Passer »")
	# Secondes qui roulent (« 12:41 ») ; l'horloge sans secondes du bandeau 3D peut apparaître à la bascule.
	var roulantes: Array = horloges.keys().filter(func(h: String): return ":" in h)
	check(roulantes.size() >= 3, "L'horloge défile en 2D entre deux temps forts (%d valeurs, ex. %s)" % [roulantes.size(), str(horloges.keys().filter(func(h: String): return not ":" in h).slice(0, 4))])
	# Deuxième entracte : la fenêtre Équipe ouverte met le match en pause, la consigne passe, rien ne part.
	check(await until(func(): return regie.etat == regie.INTER, 120000), "Retour en 2D")
	await until(func(): return not app.waiting, 30000)
	var avant: Dictionary = app.model.get("tactics", {}).duplicate()
	view.ouvrir_equipe("consignes")
	check(await until(func(): return app.model.live.paused and not app.waiting, 30000), "Fenêtre Équipe ouverte pendant l'entracte : le match se met en pause")
	var horloge_figee: String = view.clock.text
	await settle(2)
	var options: Array = app.model.get("tactics", {}).get("attacks", [])
	var autre := ""
	for option: Dictionary in options:
		if option.get("id") != avant.get("attack"): autre = str(option.get("id")); break
	check(not autre.is_empty(), "Une autre consigne offensive est proposée")
	var boutons: Array = view.equipe.find_children("*", "Button", true, false).filter(func(b: Button): return not b.disabled)
	check(boutons.size() >= 2, "Les consignes sont modifiables pendant la pause de l'entracte (%d boutons actifs)" % boutons.size())
	await command("set_tactics", {"attack": autre, "defense": avant.get("defense", "equilibre")})
	check(str(app.model.get("tactics", {}).get("attack", "")) == autre, "La consigne choisie pendant l'entracte est prise en compte : " + autre)
	var temps_forts: int = regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort").size()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	check(regie.etat != regie.JEU and regie.suivi.filter(func(e: Dictionary): return e.evenement == "temps_fort").size() == temps_forts, "Fenêtre Équipe ouverte : aucun temps fort ne part")
	check(view.clock.text == horloge_figee, "Pause : l'horloge est figée (%s → %s)" % [horloge_figee, view.clock.text])
	view.equipe.fermer()
	check(await until(func(): return not app.model.live.paused and not app.waiting, 30000), "Valider et reprendre : le match reprend")
	# La consigne vaut pour la suite du match, comme une consigne donnée en pause aujourd'hui.
	check(await until(func(): return app.model.live.minute > 0 and str(app.model.get("tactics", {}).get("attack", "")) == autre, 30000), "La consigne reste en place après la reprise")
	check(await until(func(): return regie.etat == regie.JEU, 180000), "Temps fort suivant")
	print("ENTRACTE ", JSON.stringify({"premier_s": attendu, "horloges": horloges.size()}))
	app._command("pause", {"paused": true})
	await wait_command()

## Liaisons (carrière Monde, graine choisie par godot-match-liaison-monde.cjs) : les
## temps forts contigus sont reliés en 3D, à vitesse réelle même quand les temps forts sont
## accélérés pour le test ; les autres gardent l'écran intermédiaire. Contrôles détaillés : check_liaisons.
func linked(view: Control) -> void:
	var regie: Node = view.regie
	check(regie != null, "Régie présente")
	if regie == null: return
	check(regie.arbitre != null and regie.arbitre.is_inside_tree(), "Arbitre présent dans la vue 3D")
	var deadline := Time.get_ticks_msec() + 900000
	var reprise := false
	var images_liaison := 0
	var accelere := 0
	var bandeaux_faux: Array = []
	var touches_vues := 0
	var touches_mal_placees: Array = []
	var derniere_liaison := {}
	var fin := int(OS.get_environment("CD_LIAISON_MINUTES")) if OS.get_environment("CD_LIAISON_MINUTES").is_valid_int() else 11
	var attendues := int(OS.get_environment("CD_LIAISON_ATTENDUES")) if OS.get_environment("CD_LIAISON_ATTENDUES").is_valid_int() else 2
	while app.model.get("live") is Dictionary and int(app.model.live.minute) < fin and Time.get_ticks_msec() < deadline:
		await process_frame
		if not reprise and not app.waiting and regie.etat != regie.JEU:
			reprise = true
			if app.model.live.paused: app._command("pause", {"paused": false})
		if regie.phase == "liaison" and regie.etat == regie.JEU:
			images_liaison += 1
			if not (regie.vitesse > 1.0 and view.stage._choregraphie.vitesse == 1.0): accelere += 1
			# Bandeau du haut : l'arrêt de jeu en cours, jamais la situation du moteur.
			var bandeau: String = regie.between.etat.text
			if bandeau != regie.bandeau_liaison() or bandeau.is_empty() or bandeau.contains("a le ballon"):
				if bandeaux_faux.size() < 4: bandeaux_faux.append("%s ≠ %s" % [bandeau, regie.bandeau_liaison()])
			if not is_same(regie.liaison, derniere_liaison):
				derniere_liaison = regie.liaison
				if str(regie.liaison.get("type", "")) == "touche":
					# Alignement formé à la place du moteur : lanceur sur la ligne de touche, avants entre 5 et 15 m.
					touches_vues += 1
					var fin_b: Dictionary = (regie.liaison.plans as Array)[-1]
					var lanceur := str(regie.liaison.get("ramasseur", ""))
					var cote := 0.0
					var alignes := 0
					for j: Dictionary in fin_b.joueurs:
						if str(j.id) == lanceur: cote = float(j.y[-1])
					var ligne := 0.0 if cote < 35.0 else 70.0
					for j: Dictionary in fin_b.joueurs:
						if absf(float(j.y[-1]) - ligne) >= 4.5 and absf(float(j.y[-1]) - ligne) <= 15.5: alignes += 1
					if absf(cote - ligne) > 1.5 or alignes < 12: touches_mal_placees.append("lanceur à %.1f m de la touche, %d joueurs entre 5 et 15 m" % [absf(cote - ligne), alignes])
	check(bandeaux_faux.is_empty(), "Pendant une liaison, le bandeau du haut dit l'arrêt de jeu en cours : " + str(bandeaux_faux))
	check(touches_mal_placees.is_empty(), "Touches formées à leur place (%d vues) : %s" % [touches_vues, str(touches_mal_placees)])
	check(images_liaison > 0 and accelere == 0, "Liaisons à vitesse réelle alors que les temps forts sont accélérés (%d images, %d accélérées)" % [images_liaison, accelere])
	var liaisons: Array = regie.suivi.filter(func(e: Dictionary) -> bool: return e.evenement == "liaison" and e.has("duree_reelle"))
	check(liaisons.size() >= attendues, "Au moins %d liaisons en %d minutes : " % [attendues, fin] + str(liaisons.map(func(e: Dictionary) -> String: return str(e.type))))
	var sans: Array = regie.suivi.filter(func(e: Dictionary) -> bool: return e.evenement == "temps_fort" and not bool(e.get("contigu", false)))
	check(not sans.is_empty() and sans.all(func(e: Dictionary) -> bool: return str(e.get("liaison", "")).is_empty()), "Temps forts après l'écran intermédiaire : aucune liaison")
	check(regie.suivi.any(func(e: Dictionary) -> bool: return e.evenement == "intermediaire"), "L'écran intermédiaire reste entre deux temps forts non contigus")
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
	var arbitre_attendu := false
	var arbitre_vu := false
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
		# Arbitre des pistes (quatrième tranche) : à l'écran tant que les pistes en portent un.
		if pistes.has("arbitre"):
			arbitre_attendu = true
			if view.stage._choregraphie.arbitre_position() != null: arbitre_vu = true
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
	check(arbitre_attendu and arbitre_vu, "L'arbitre des pistes est à l'écran (attendu %s, vu %s)" % [str(arbitre_attendu), str(arbitre_vu)])
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
	# Bande de commandes sous le score, la même en 3D et pendant l'entracte (demande de Léo) ;
	# niveau de temps forts et vitesse de l'horloge dans Paramètres, aucun sélecteur dans la bande.
	await settle(4)
	var grille: Control = regie.between.grille_niveaux
	var labels: Array = grille.get_children().map(func(b: Button): return b.text)
	check(labels.size() == 6 and regie.between.niveau_libelle() == "Dynamique", "Le niveau se choisit dans Paramètres : " + regie.between.niveau_libelle())
	check("Match complet" in labels, "Le choix « Match complet » est proposé : " + str(labels))
	check(not view.find_children("*", "OptionButton", true, false).any(func(option: OptionButton): return option.is_visible_in_tree()), "Pas de sélecteur « Horloge normale » dans la barre, en 3D")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	var bar: Control = view.get("bande_temps_forts")
	check(bar != null and bar.is_visible_in_tree() and not view.barre_commandes.is_visible_in_tree() and view.find_child("MatchBetweenTeam", true, false).is_visible_in_tree(), "En 3D : la bande Équipe / Paramètres / Plus est là, seule")
	var plus_3d: MenuButton = view.find_child("MatchBetweenMore", true, false)
	var entrees: Array = []
	for n in plus_3d.get_popup().item_count: entrees.append(plus_3d.get_popup().get_item_text(n))
	check(["Statistiques", "Journal du match", "Confier la fin à l’adjoint", "Vue TV", "Vue de dessus", "Vue contact"].all(func(t: String): return t in entrees), "Commandes du direct 3D dans Plus : " + str(entrees))
	if bar != null: regie.set_meta("bande_3d", bar.get_global_rect())
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
	# Le niveau se choisit dans Paramètres (bouton du panneau, comme le joueur).
	if extended >= 0:
		(grille.get_child(extended) as Button).pressed.emit()
		await settle(2)
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
	# Le duel : les dix chiffres comparés (possession et occupation sont dans leurs anneaux).
	check(rangs.size() >= 10 and between.chiffres.get_child_count() == between.STATS.filter(func(c: String): return rangs.any(func(r: Dictionary): return str(r.cle) == c)).size() and between.chiffres.get_child_count() >= 8, "Statistiques : %d comparées sur %d" % [between.chiffres.get_child_count(), rangs.size()])
	check(not between.STATS.has("possession") and not between.STATS.has("occupation"), "Possession et occupation hors du duel")
	for ligne: Node in between.chiffres.get_children():
		# Libellé court à l'écran, libellé du moteur en infobulle.
		var titre := (ligne.get_child(0) as Label).tooltip_text
		var rang: Array = rangs.filter(func(r: Dictionary): return str(r.label) == titre)
		check(rang.size() == 1 and not str(rang[0].cle) in ["possession", "occupation"], "Chiffre « %s » du duel (ni possession ni occupation)" % titre)
		check(rang.size() == 1 and (ligne.get_child(1) as Label).text.begins_with(str(int(rang[0].valeurs[0]))) and (ligne.get_child(3) as Label).text.begins_with(str(int(rang[0].valeurs[1]))) or rang.size() == 1 and rang[0].get("vide", false), "Chiffre « %s » repris du moteur" % titre)
	# Anneaux : les parts du moteur, la nôtre au centre (« — » si la part est vide ou l'échantillon court).
	var camp_anneau: int = int(direct.camp) if int(direct.get("camp", -1)) in [0, 1] else 0
	for paire: Array in [[between.anneau_possession, "possession"], [between.anneau_occupation, "occupation"]]:
		var rang_anneau: Array = rangs.filter(func(r: Dictionary): return str(r.cle) == paire[1])
		var anneau: Control = paire[0]
		var vide: bool = rang_anneau.is_empty() or rang_anneau[0].get("vide", false) or between.est_court(direct)
		var attendu := "—" if vide else "%d%%" % roundi(float(rang_anneau[0].valeurs[camp_anneau]))
		check(rang_anneau.size() == 1 and (vide or anneau.valeurs == rang_anneau[0].valeurs) and anneau.vide == vide and anneau.texte_centre() == attendu and anneau.couleurs == between.terrain.couleurs, "Anneau %s : valeurs du moteur (%s, attendu %s)" % [paire[1], anneau.texte_centre(), attendu])
	var lineup: Array = between._passe(app.model, app.model.live, direct).lineup
	# Vue Terrain par défaut : les quinze du moteur à leur poste, anneau d'énergie, nom court et note.
	check(between.vue_xv == "terrain" and between.formation.is_visible_in_tree() and not between.xv.is_visible_in_tree(), "Notre XV s'ouvre sur la vue Terrain")
	var cases: Array = between.formation.cases
	var conformes_terrain := 0
	for poste in mini(lineup.size(), cases.size()):
		var joueur_t: Variant = lineup[poste]
		if not joueur_t is Dictionary: continue
		var textes_t: Array = cases[poste].find_children("*", "Label", true, false).map(func(l: Label): return l.text)
		var anneau_t: Control = between.formation.anneaux[poste]
		var note_t := float(direct.get("notes", {}).get(str(joueur_t.id), {}).get("note", 6.5))
		if between._nom_court(str(joueur_t.name)) in textes_t and "%.1f" % note_t in textes_t and is_equal_approx(float(anneau_t.valeur), float(joueur_t.condition)) and anneau_t.numero == str(poste + 1) and str(joueur_t.name) in cases[poste].tooltip_text: conformes_terrain += 1
	check(cases.size() == 15 and conformes_terrain == lineup.size(), "Vue Terrain : anneau, nom, note et infobulle du moteur pour chaque joueur (%d/%d)" % [conformes_terrain, lineup.size()])
	var choisis: Array = []
	var noter := func(poste: int): choisis.append(poste)
	between.joueur_choisi.connect(noter)
	(cases[3] as Button).pressed.emit()
	between.joueur_choisi.disconnect(noter)
	check(choisis == [3] and view.equipe.visible and view.equipe.poste_choisi == 3, "Vue Terrain : un clic sur le 4 ouvre la fenêtre Équipe sur lui (%s, poste %d)" % [str(choisis), view.equipe.poste_choisi])
	if view.equipe.visible: view.equipe.fermer()
	await settle(2)
	# Carte Changement : blessé d'abord, sinon l'énergie la plus basse, sous le seuil de fatigue ; les sanctionnés à part.
	var sanctionnes := {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: sanctionnes[str(carton.get("id", ""))] = true
	var attendu_changement := -1
	for poste in lineup.size():
		var j: Variant = lineup[poste]
		if not j is Dictionary or sanctionnes.has(str(j.id)): continue
		if attendu_changement < 0: attendu_changement = poste
		else:
			var a: Dictionary = lineup[attendu_changement]
			var blesse := int(j.get("injury", 0)) > 0
			if blesse != (int(a.get("injury", 0)) > 0):
				if blesse: attendu_changement = poste
			elif float(j.condition) < float(a.condition): attendu_changement = poste
	if attendu_changement >= 0 and int(lineup[attendu_changement].get("injury", 0)) <= 0 and float(lineup[attendu_changement].condition) >= between.FATIGUE: attendu_changement = -1
	var action_changement: Button = between.find_child("MatchBetweenSwapAction", true, false)
	check(between.changement_poste == attendu_changement and action_changement != null and action_changement.text == ("Préparer le changement" if attendu_changement >= 0 else "Ouvrir le banc"), "Carte Changement : poste %d attendu %d (%s)" % [between.changement_poste, attendu_changement, action_changement.text if action_changement != null else "sans bouton"])
	# Tuile « Dans les 22 » : masquée sans `direct.zone22`, remplie avec une donnée injectée.
	check(between.zone22.visible == (direct.get("zone22") is Dictionary), "Tuile « Dans les 22 » masquée sans sa donnée")
	var avec_22: Dictionary = direct.duplicate()
	avec_22["zone22"] = {"entrees": [3, 1], "points": [10, 0], "secondes": [200, 65]}
	between.update_frame(app.model, app.model.live, avec_22, func(_c: Dictionary): pass)
	await settle(2)
	var textes_22: Array = between.zone22.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
	var carres := func(cote: int) -> int: return between.zone22.find_child("MatchBetweenZone22Entries%d" % cote, true, false).get_children().filter(func(c: Node): return c.get("teinte") != null).size()
	check(between.zone22.is_visible_in_tree() and carres.call(0) == 3 and carres.call(1) == 1, "Dans les 22 : un carré par entrée (%d, %d)" % [carres.call(0), carres.call(1)])
	check(textes_22.has("10 pts") and textes_22.has("0 pt") and textes_22.any(func(t: String): return t.contains("3,3 pt/entrée") and t.contains("3:20")) and textes_22.any(func(t: String): return t.contains("0,0 pt/entrée") and t.contains("1:05")), "Dans les 22 : points, points par entrée, temps passé " + str(textes_22))
	var carre0: Control = between.zone22.find_child("MatchBetweenZone22Entries0", true, false).get_child(0)
	check(carre0.teinte == between.terrain.couleurs[0], "Dans les 22 : carrés aux couleurs du club")
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	await settle(2)
	check(between.zone22.visible == (direct.get("zone22") is Dictionary), "Tuile « Dans les 22 » de nouveau masquée sans sa donnée")
	# Onglet Tableau : le tableau complet, contrôlé ligne par ligne.
	between.find_child("MatchBetweenTabOwn", true, false).pressed.emit()
	await settle(2)
	check(between.vue_xv == "tableau" and between.xv.is_visible_in_tree() and not between.formation.is_visible_in_tree(), "Onglet Tableau : Mon XV en tableau")
	var lignes_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button)
	check(lignes_xv.size() == lineup.size() and lineup.size() == 15, "Mon XV : quinze joueurs (%d)" % lignes_xv.size())
	var conformes := 0
	for poste in mini(lineup.size(), lignes_xv.size()):
		var joueur: Variant = lineup[poste]
		if not joueur is Dictionary: continue
		var textes: Array = lignes_xv[poste].find_children("*", "Label", true, false).map(func(l: Label): return l.text)
		var energie: Array = lignes_xv[poste].find_children("*", "Control", true, false).filter(func(c: Control): return c.get("valeur") != null)
		var note := float(direct.get("notes", {}).get(str(joueur.id), {}).get("note", 6.5))
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
	# Carte Changement : le 7 à bout (31 %) est proposé, sauf blessé ou sanctionné prioritaire ; le bouton ouvre le banc sur lui.
	var blesses: Array = copie.live.lineup.filter(func(j: Variant): return j is Dictionary and int(j.get("injury", 0)) > 0)
	if blesses.is_empty() and not sanctionnes.has(str(copie.live.lineup[6].id)):
		var choisis_copie: Array = []
		var noter_copie := func(poste: int): choisis_copie.append(poste)
		between.joueur_choisi.connect(noter_copie)
		var action_copie: Button = between.find_child("MatchBetweenSwapAction", true, false)
		action_copie.pressed.emit()
		between.joueur_choisi.disconnect(noter_copie)
		var energie_copie: Label = between.find_child("MatchBetweenSwapEnergyText", true, false)
		check(between.changement_poste == 6 and action_copie.text == "Préparer le changement" and energie_copie != null and energie_copie.text.begins_with("Énergie 31 %") and choisis_copie == [6], "Carte Changement : le 7 à bout, « Préparer le changement » ouvre le banc sur lui (%s)" % str(choisis_copie))
		if view.drawer.visible: view._fermer_tiroir()
		await settle(2)
	var phrases := {}
	var redites := 0
	for t: String in adjoint_textes:
		for phrase: String in t.split(". ", false):
			var cle := phrase.strip_edges().trim_suffix(".")
			if cle.length() > 12 and phrases.has(cle): redites += 1
			phrases[cle] = true
	check(redites == 0, "L'adjoint ne répète pas une phrase : " + str(adjoint_textes))
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	# Accès directs : remplacements depuis l'adjoint, et un joueur de Mon XV ouvre la fenêtre Équipe sur lui.
	var bouton_equipe: Button = view.find_child("MatchBetweenTeam", true, false)
	check(bouton_equipe != null and bouton_equipe.is_visible_in_tree() and view.find_child("MatchBetweenTactics", true, false) == null and view.find_child("MatchBetweenBench", true, false) == null, "Un seul bouton Équipe (ni Tactique ni Banc) depuis l'écran")
	if regie.has_meta("bande_3d"): check(view.bande_temps_forts.get_global_rect().is_equal_approx(regie.get_meta("bande_3d")), "La bande de commandes ne bouge pas entre la 3D et l'entracte")
	# Colonnes « Plaq. » et « Mètres » : la feuille de statistiques (match-stats.cjs) ; le total d'équipe est la
	# somme des joueurs de la feuille et le chiffre du tableau de bord.
	var feuille: Dictionary = direct.get("feuille", {})
	check(feuille.get("joueurs") is Dictionary and not feuille.joueurs.is_empty(), "Feuille de statistiques jointe au direct")
	var camp_xv := int(direct.camp)
	var somme := {"plaquages": 0, "metres": 0}
	for fj: Dictionary in feuille.get("joueurs", {}).values():
		if int(fj.camp) == camp_xv:
			for cle: String in somme: somme[cle] += int(fj.get(cle, 0))
	for cle: String in somme:
		var rang_cle := rangs.filter(func(r: Dictionary): return str(r.cle) == cle)
		check(rang_cle.size() == 1 and int(rang_cle[0].valeurs[camp_xv]) == int(somme[cle]), "Tableau : %s de l'équipe = somme des joueurs de la feuille (%d)" % [cle, somme[cle]])
		check(int(feuille.equipes[camp_xv][cle]) == int(somme[cle]), "Feuille : total d'équipe = somme des joueurs (%s)" % cle)
	var colonne := func(zone: Node) -> Array: return zone.find_children("*", "Label", true, false).filter(func(l: Label): return l.visible).map(func(l: Label): return l.text)
	var total_xv: Node = between.xv.find_child("MatchBetweenTeamTotal", true, false)
	check(total_xv != null and colonne.call(total_xv).has(str(somme.plaquages)) and colonne.call(total_xv).has(str(somme.metres)), "Ligne Équipe de Mon XV : plaquages %d, mètres %d" % [somme.plaquages, somme.metres])
	var plaquages_visibles := 0
	for joueur: Variant in lineup:
		if joueur is Dictionary: plaquages_visibles += int(feuille.joueurs.get(str(joueur.id), {}).get("plaquages", 0))
	check(plaquages_visibles >= 5 or int(somme.plaquages) < 10, "Plaquages des quinze titulaires de la feuille : %d" % plaquages_visibles)
	check(between.xv.is_visible_in_tree() and between.fil.is_visible_in_tree(), "Mon XV et le dernier fait affichés ensemble")
	var noms_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button).map(func(b: Button): return b.find_children("*", "Label", true, false).filter(func(l: Label): return l.visible).map(func(l: Label): return l.text))
	check(noms_xv.size() == 15 and noms_xv.all(func(t: Array): return t.size() >= 2 and not str(t[0]).is_empty()), "Mon XV : nom de famille et note visibles pour chaque joueur : " + str(noms_xv.slice(0, 3)))
	# Onglet adverse : le même tableau pour le XV adverse du dernier fait montré, puis retour à Mon XV.
	var adverse: Array = direct.get("adversaire", [])
	between.find_child("MatchBetweenTabOpponent", true, false).pressed.emit()
	await settle(2)
	var lignes_adverses: Array = between.xv.get_children().filter(func(n: Node): return n is Button)
	var noms_adverses: Array = lignes_adverses.map(func(b: Button): return b.find_children("*", "Label", true, false).map(func(l: Label): return l.text))
	check(adverse.size() == 15 and lignes_adverses.size() == 15 and range(15).all(func(k: int): return adverse[k] == null or str(adverse[k].nom) in noms_adverses[k]), "Onglet adverse : le XV adverse, nom et note de chaque joueur (%d lignes)" % lignes_adverses.size())
	var somme_adverse := {"plaquages": 0, "metres": 0}
	for fj: Dictionary in feuille.get("joueurs", {}).values():
		if int(fj.camp) == 1 - camp_xv:
			for cle: String in somme_adverse: somme_adverse[cle] += int(fj.get(cle, 0))
	var total_adverse: Node = between.xv.find_child("MatchBetweenTeamTotal", true, false)
	check(total_adverse != null and colonne.call(total_adverse).has(str(somme_adverse.plaquages)) and int(feuille.equipes[1 - camp_xv].plaquages) == int(somme_adverse.plaquages), "Ligne Équipe du XV adverse : plaquages %d = somme des joueurs" % somme_adverse.plaquages)
	between.find_child("MatchBetweenTabOwn", true, false).pressed.emit()
	await settle(2)
	check(between.xv.get_children().filter(func(n: Node): return n is Button and str(n.name).begins_with("MatchBetweenPlayer")).size() == 15, "Retour à Mon XV")
	# Paramètres : vitesse de l'horloge et temps forts montrés dans un petit panneau.
	view.find_child("MatchBetweenSettings", true, false).pressed.emit()
	await settle(4)
	check(between.panneau_parametres.visible and between.grille_niveaux.get_child_count() == 6, "Paramètres : le panneau s'ouvre avec les six niveaux de temps forts")
	between.panneau_parametres.hide()
	var rangs_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button)
	(rangs_xv[9] as Button).pressed.emit()
	await settle(4)
	check(view.equipe.visible and view.equipe.poste_choisi == 9, "Un joueur de Mon XV ouvre la fenêtre Équipe sur lui (poste %d)" % view.equipe.poste_choisi)
	view.equipe.fermer()
	var menu: MenuButton = view.find_child("MatchBetweenMore", true, false)
	check(menu != null and menu.get_popup().get_item_text(0) == "Statistiques", "Tous les chiffres du moteur restent dans le tiroir Statistiques (menu Plus)")
	await layout(view, Vector2i(1280, 720))
	await layout(view, Vector2i(1920, 1080))
	await layout(view, Vector2i(2560, 1440))
	await consignes_fictives(view, direct)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	print("TERRAIN2D ", JSON.stringify({"faits": ecarts.faits, "deplacement": deplacement, "ballons": ballons.size(), "minutes": minutes.size()}))

## Pilotage du match (dist/match-pilotage.js, `live.pilotage`) pour une copie du direct : arbitre, cinq axes
## (rucks contestés depuis 52′), un bilan, une ligne du journal du staff, trois états de joueurs après la causerie.
func pilotage_test(lineup: Array) -> Dictionary:
	var axes: Array = []
	for axe: Array in [["piedJeu", "Jeu au pied", "normal", [["moins", "Garder"], ["normal", "Équilibré"], ["plus", "Occuper"]]],
		["rucks", "Rucks", "agressive", [["prudente", "Prudence"], ["normale", "Normale"], ["agressive", "Contester"]]],
		["discipline", "Discipline", "normale", [["stricte", "Zéro faute"], ["normale", "Normale"], ["limite", "À la limite"]]],
		["rythme", "Rythme", "normal", [["lent", "Ralentir"], ["normal", "Normal"], ["rapide", "Accélérer"]]],
		["touche", "Touche", "normale", [["sure", "Sûre"], ["normale", "Normale"], ["risquee", "Risquée"]]]]:
		axes.append({"id": axe[0], "label": axe[1], "valeur": axe[2], "options": (axe[3] as Array).map(func(o: Array) -> Dictionary: return {"id": o[0], "label": o[1]})})
	var consignes := {}
	for axe: Dictionary in axes: consignes[axe.id] = axe.valeur
	var joueurs := {}
	var etats := [["galvanise", "Galvanisé"], ["indifferent", "Indifférent"], ["vexe", "Vexé"]]
	for k in mini(3, lineup.size()):
		if lineup[k] is Dictionary: joueurs[str(lineup[k].id)] = {"etat": etats[k][0], "label": etats[k][1], "phase": "pre", "confiance": 50}
	return {"arbitre": {"id": "castaing", "nom": "Julien Castaing", "pays": "FR", "rucks": 4, "melee": 3, "horsJeu": 3, "cartons": 2, "resume": "Pointilleux sur les rucks, laisse vivre les cartons."},
		"consignes": consignes, "axes": axes,
		"bilans": [{"axe": "rucks", "valeur": "agressive", "depuis": 52, "texte": "Rucks « Contester » depuis 52′ : 3 pénalités, 2 ballons arrachés."}],
		"joueurs": joueurs, "journal": [{"minute": 55, "auteur": "staff", "texte": "Le staff passe « Rythme » sur « Accélérer »."}]}

## Pilotage injecté : les faits marquants restent à l'écran (pas de tuile Consignes), les états des joueurs
## apparaissent dans Mon XV, et l'écran tient en 720p et 1440p ; sans pilotage, rien ne change.
func consignes_fictives(view: Control, direct: Dictionary) -> void:
	var regie: Node = view.regie
	var between: Control = regie.between
	var lineup: Array = between._passe(app.model, app.model.live, direct).lineup
	var copie: Dictionary = app.model.duplicate(true)
	copie.live["pilotage"] = pilotage_test(lineup)
	between.update_frame(copie, copie.live, direct, func(_c: Dictionary): pass)
	await settle(4)
	check(between.faits.is_visible_in_tree() and between.faits.get_child_count() >= 1, "Pilotage : les faits marquants restent à l'écran")
	check(between.find_child("MatchBetweenConsignes", true, false) == null and between.find_children("Consigne_*", "BoxContainer", true, false).is_empty(), "Pilotage : aucune consigne sur l'écran 2D (elles sont dans la fenêtre Équipe)")
	# Mon XV : l'état après la causerie, coloré selon son sens.
	var cases: Array = between.formation.cases
	var attendus := [["Galvanisé", W.VERT], ["Indifférent", Color("aeb9b3")], ["Vexé", W.ALERTE]]
	for k in mini(3, cases.size()):
		if not lineup[k] is Dictionary: continue
		var etat: Label = (cases[k] as Node).find_child("MatchBetweenPlayerState", true, false)
		check(etat != null and etat.text == attendus[k][0] and etat.get_theme_color("font_color").is_equal_approx(attendus[k][1]) and etat.get_theme_font_size("font_size") >= 13, "Mon XV (Terrain) : état « %s » du %d" % [attendus[k][0], k + 1])
	check((cases[4] as Node).find_child("MatchBetweenPlayerState", true, false) == null, "Mon XV : pas d'état sans causerie reçue")
	between.find_child("MatchBetweenTabOwn", true, false).pressed.emit()
	await settle(2)
	var ligne_xv: Node = between.xv.find_child("MatchBetweenPlayer3", true, false)
	var etat_xv: Label = ligne_xv.find_child("MatchBetweenPlayerState", true, false) if ligne_xv != null else null
	check(etat_xv != null and etat_xv.text == "Vexé", "Mon XV (Tableau) : état du 3")
	between.find_child("MatchBetweenTabPitch", true, false).pressed.emit()
	# Mise en page avec le pilotage (rien ne doit être coupé en 720p comme en 1440p).
	await layout(view, Vector2i(1280, 720))
	await layout(view, Vector2i(2560, 1440))
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	await settle(2)
	check(between.faits.is_visible_in_tree(), "Sans pilotage : faits marquants")

## Carrière Monde réelle : un clic sur un cran de la fenêtre Équipe (ouvert, le match se met en pause) envoie
## la consigne au vrai moteur, qui la projette dans `live.pilotage` ; l'écran 2D n'a pas de consignes et garde ses faits marquants.
func consigne_reelle(regie: Node) -> void:
	var between: Control = regie.between
	var p: Variant = app.model.live.get("pilotage")
	check(p is Dictionary, "Carrière Monde : le moteur projette le pilotage du match (live.pilotage)")
	if not p is Dictionary: return
	check(between.faits.is_visible_in_tree() and between.faits.get_child_count() >= 1, "Faits marquants à l'écran 2D pendant le match du manager")
	var vue: Control = regie.view
	vue.ouvrir_equipe("consignes")
	await settle(4)
	var actuel := str(p.get("consignes", {}).get("rythme", ""))
	var voulu := "lent" if actuel == "rapide" else "rapide"
	var bouton: Button = vue.equipe.find_child("Consigne_rythme_" + voulu, true, false)
	check(bouton != null, "Consignes (fenêtre Équipe) : cran « %s » du rythme" % voulu)
	if bouton == null:
		vue.equipe.fermer()
		return
	var pauses: int = regie.suivi.size()
	bouton.pressed.emit()
	var recu: bool = await until(func() -> bool: return app.model.live.get("pilotage") is Dictionary and str(app.model.live.pilotage.get("consignes", {}).get("rythme", "")) == voulu, 30000)
	check(recu, "Consignes : le moteur applique « %s » (%s)" % [voulu, str(app.model.live.get("pilotage", {}).get("consignes", {}) if app.model.live.get("pilotage") is Dictionary else null)])
	check(regie.suivi.slice(pauses).any(func(e: Dictionary) -> bool: return e.evenement == "consigne" and e.get("valeur") == voulu), "Consignes : envoyée par la régie")
	if vue.equipe.visible: vue.equipe.fermer()

## Mode « multiplex » : carrière world-champ réelle. Le moteur projette la journée (`direct.journee`)
## dès le coup d'envoi : au moins une carte de multiplex et notre club dans le classement en direct ;
## puis une journée fictive injectée (rangs, points, badges, scores, surlignage, liseré du score qui
## change), sans journée (tuiles masquées), et rien de coupé en 1280×720, 1920×1080 et 2560×1440.
func journee_directe(view: Control) -> void:
	var regie: Node = view.regie
	var between: Control = regie.between
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 180000 and not (regie.etat == regie.INTER and between.visible and regie._retenu.is_empty()):
		if not regie.arret.is_empty(): between.reprise_demandee.emit()
		elif app.model.live.get("paused", false) and not app.waiting and not app.model.live.get("finished", false): await command("pause", {"paused": false})
		await process_frame
	check(regie.etat == regie.INTER and between.visible, "Multiplex : l'écran intermédiaire s'ouvre")
	await until(func(): return not app.waiting, 30000)
	await consigne_reelle(regie)
	await until(func(): return not app.waiting, 30000)
	if not app.model.live.paused: await command("pause", {"paused": true})
	await settle(6)
	var direct: Dictionary = regie._live_inter.get("direct", app.model.live.direct)
	var journee: Variant = direct.get("journee")
	check(journee is Dictionary, "Carrière world-champ : le moteur fournit la journée en direct")
	if journee is Dictionary:
		var matchs: Array = journee.get("matchs", [])
		var classement: Array = journee.get("classement", [])
		var cartes := _cartes_multiplex(between)
		check(matchs.size() >= 1 and between.multiplex.is_visible_in_tree() and cartes.size() == matchs.size(), "Multiplex réel : une carte par autre match (%d cartes, %d matchs)" % [cartes.size(), matchs.size()])
		var ok_scores := 0
		for n in mini(cartes.size(), matchs.size()):
			var scores: Array = cartes[n].find_children("Score", "Label", true, false).map(func(l: Label): return l.text)
			if scores == [str(int(matchs[n].home.score)), str(int(matchs[n].away.score))]: ok_scores += 1
		check(ok_scores == matchs.size(), "Multiplex réel : scores du moteur (%d/%d)" % [ok_scores, matchs.size()])
		var nous: Array = classement.filter(func(r: Dictionary): return bool(r.get("nous", false)))
		var ligne_nous := _ligne_nous(between)
		check(nous.size() == 1 and between.classement_tuile.is_visible_in_tree() and ligne_nous != null and int(ligne_nous.get_meta("rang")) == int(nous[0].rang), "Classement réel : notre club (%s) surligné à son rang" % (str(nous[0].get("abbr", "")) if nous.size() == 1 else "absent"))
		print("MULTIPLEX_REEL ", JSON.stringify({"minute": journee.get("minute"), "matchs": matchs.size(), "clubs": classement.size(), "nous": nous[0].rang if nous.size() == 1 else null}))
	await _mise_en_page_journee(view, "reel")
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]: await layout(view, taille)
	await journee_fictive(view, direct)

func _cartes_multiplex(between: Control) -> Array:
	return between.multiplex_cartes.get_children().filter(func(n: Node): return not n.is_queued_for_deletion() and str(n.name).begins_with("MatchBetweenMultiplexMatch"))

func _lignes_classement(between: Control) -> Array:
	return between.classement_lignes.get_children().filter(func(n: Node): return not n.is_queued_for_deletion())

func _ligne_nous(between: Control) -> Control:
	for ligne: Node in _lignes_classement(between):
		if ligne.has_meta("nous") and bool(ligne.get_meta("nous")): return ligne
	return null

## Journée fictive : quatorze clubs, nous huitièmes (montée de deux places, bonus défensif), six
## autres matchs dont un terminé.
func _journee_test(minute: int, score_m2: int) -> Dictionary:
	var classement: Array = []
	var nous_id: Variant = app.model.get("club", {}).get("id", 0)
	for rang in range(1, 15):
		classement.append({"rang": rang, "clubId": nous_id if rang == 8 else 900 + rang, "abbr": "NOUS" if rang == 8 else "C%02d" % rang, "nom": "Club %d" % rang, "joues": 3, "points": 40 - rang * 2,
			"diff": 30 - rang * 4, "bonusOff": 1 if rang in [1, 10] else 0, "bonusDef": 1 if rang in [8, 10] else 0, "rangOfficiel": rang + (2 if rang == 8 else -1 if rang == 9 else 0), "delta": 2 if rang == 8 else -1 if rang == 9 else 0, "nous": rang == 8})
	var matchs: Array = []
	for k in 6:
		var dom := 10 + k * 2
		matchs.append({"id": "m%d" % k, "home": {"id": 901 + k * 2, "abbr": "C%02d" % (1 + k * 2), "nom": "Club %d" % (1 + k * 2), "score": score_m2 if k == 2 else dom, "essais": 2 if k == 2 else k % 3},
			"away": {"id": 902 + k * 2, "abbr": "C%02d" % (2 + k * 2), "nom": "Club %d" % (2 + k * 2), "score": 7 + k, "essais": 1}, "minute": 80 if k == 0 else minute, "fini": k == 0})
	return {"minute": minute, "matchs": matchs, "classement": classement}

func journee_fictive(view: Control, direct: Dictionary) -> void:
	var between: Control = view.regie.between
	# Contrôles du contenu en 1920×1080 (leader et voisinage) ; la mise en page suit aux trois tailles.
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	await settle(8)
	var avec: Dictionary = direct.duplicate()
	avec["journee"] = _journee_test(52, 14)
	between.update_frame(app.model, app.model.live, avec, func(_c: Dictionary): pass)
	var suite: Dictionary = direct.duplicate()
	suite["journee"] = _journee_test(53, 19)
	between.update_frame(app.model, app.model.live, suite, func(_c: Dictionary): pass)
	await settle(4)
	# Classement : le leader, « … », puis notre voisinage (5e à 11e) ; rien de plus, sans défilement.
	var lignes := _lignes_classement(between)
	var rangs: Array = lignes.map(func(n: Node): return int(n.get_meta("rang")) if n.has_meta("rang") else -1)
	# Sept lignes en 720p ; neuf sinon.
	var attendus: Array = [5, 6, 7, 8, 9, 10, 11] if between._densite < 0.6 else [1, -1, 5, 6, 7, 8, 9, 10, 11]
	check(between.classement_tuile.is_visible_in_tree() and rangs == attendus, "Classement fictif : notre voisinage (± 3), le leader si la hauteur le permet " + str(rangs))
	# Règle de sélection, indépendante de la fenêtre : 1280×720 (sept lignes) et plus grand (neuf).
	var tableau: Array = _journee_test(52, 14).classement
	check(between.lignes_classement(tableau, 7) == [4, 5, 6, 7, 8, 9, 10] and between.lignes_classement(tableau, 9) == [0, -1, 4, 5, 6, 7, 8, 9, 10] and between.lignes_classement(tableau.slice(0, 9), 9) == range(9), "Classement : lignes choisies (voisinage, leader, tableau court entier)")
	check(between.classement_tuile.find_children("*", "ScrollContainer", true, false).is_empty(), "Classement : pas de défilement interne")
	var par_rang := {}
	for n: Node in lignes:
		if n.has_meta("rang"): par_rang[int(n.get_meta("rang"))] = n
	var texte := func(ligne: Node, nom: String) -> String: return (ligne.find_child(nom, true, false) as Label).text if ligne.find_child(nom, true, false) != null else ""
	check(range(1, 12).filter(func(r: int): return par_rang.has(r)).all(func(r: int): return texte.call(par_rang[r], "Points") == str(40 - r * 2) and texte.call(par_rang[r], "Rang") == str(r)), "Classement fictif : rangs et points du moteur")
	var badges := func(r: int) -> Array: return ["BO", "BD"].filter(func(b: String): return par_rang[r].find_child("Badge" + b, true, false) != null)
	check(badges.call(1) == ["BO"] and badges.call(8) == ["BD"] and badges.call(10) == ["BO", "BD"] and badges.call(5).is_empty(), "Classement fictif : badges BO/BD (%s, %s, %s, %s)" % [badges.call(1), badges.call(8), badges.call(10), badges.call(5)])
	var nous: Control = _ligne_nous(between)
	var style: StyleBoxFlat = nous.get_theme_stylebox("panel") if nous != null else null
	check(nous != null and int(nous.get_meta("rang")) == 8 and style != null and style.border_width_left > 0 and style.bg_color.a > 0.1 and texte.call(nous, "Club") == "NOUS", "Classement fictif : notre club surligné")
	check(nous != null and int(nous.find_child("Evolution", true, false).delta) == 2 and int(par_rang[9].find_child("Evolution", true, false).delta) == -1 and int(par_rang[5].find_child("Evolution", true, false).delta) == 0, "Classement fictif : flèches de l'évolution")
	var teinte_nous: Variant = S_couleur(app.model.get("club", {}))
	check(nous != null and (teinte_nous == null or (nous.find_child("Couleur", true, false).teinte as Color).is_equal_approx(teinte_nous)) and (par_rang[1].find_child("Couleur", true, false).teinte as Color).is_equal_approx(between.FAIBLE), "Classement fictif : pastille aux couleurs du club, neutre sinon")
	# Multiplex : six cartes, scores et essais, « Terminé », liseré vert sur le seul score qui a changé.
	var cartes := _cartes_multiplex(between)
	check(cartes.size() == 6 and between.multiplex.is_visible_in_tree(), "Multiplex fictif : six cartes (%d)" % cartes.size())
	if cartes.size() == 6:
		var scores: Array = cartes.map(func(c: Node): return c.find_children("Score", "Label", true, false).map(func(l: Label): return l.text))
		check(scores[2] == ["19", "9"] and scores[0] == ["10", "7"] and scores[5] == ["20", "12"], "Multiplex fictif : scores " + str(scores))
		var essais: Array = cartes[2].find_children("Essais", "Label", true, false).map(func(l: Label): return l.text)
		check(essais == ["(2)", "(1)"], "Multiplex fictif : essais en petit " + str(essais))
		check((cartes[0].find_child("Minute", true, false) as Label).text == "Terminé" and (cartes[1].find_child("Minute", true, false) as Label).text == "53′", "Multiplex fictif : minute et « Terminé »")
		var changes: Array = cartes.map(func(c: Node): return bool(c.get_meta("change", false)))
		check(changes == [false, false, true, false, false, false] and (cartes[2].get_theme_stylebox("panel") as StyleBoxFlat).border_width_top > 0 and (cartes[1].get_theme_stylebox("panel") as StyleBoxFlat).border_width_top == 0, "Multiplex fictif : liseré vert sur le score qui a changé " + str(changes))
	check(between.faits.is_visible_in_tree() and between.faits.get_child_count() >= 1, "Faits marquants visibles avec le classement")
	await _mise_en_page_journee(view, "fictif")
	# Hors phase de ligue : classement vide, multiplex seul.
	var sans_table: Dictionary = direct.duplicate()
	var j: Dictionary = _journee_test(60, 19)
	j["classement"] = []
	sans_table["journee"] = j
	between.update_frame(app.model, app.model.live, sans_table, func(_c: Dictionary): pass)
	await settle(2)
	check(not between.classement_tuile.visible and between.multiplex.is_visible_in_tree(), "Hors phase de ligue : classement masqué, multiplex montré")
	# Sans journée (match délégué, ancienne carrière) : les deux tuiles masquées, sans message.
	var sans: Dictionary = direct.duplicate()
	sans["journee"] = null
	between.update_frame(app.model, app.model.live, sans, func(_c: Dictionary): pass)
	await settle(2)
	check(not between.classement_tuile.visible and not between.multiplex.visible and between.faits.is_visible_in_tree(), "Sans journée : classement et multiplex masqués")
	await _mise_en_page_journee(view, "sans")
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	await settle(2)

static func S_couleur(club: Dictionary) -> Variant:
	var source: Dictionary = club.get("presentation", club) if club.get("presentation") is Dictionary else club
	var c := str(source.get("color", club.get("color", "")))
	return Color(c) if c.begins_with("#") and (c.length() == 7 or c.length() == 9) else null

## Les deux tuiles de la journée dans l'écran, entières et lisibles, aux trois tailles de fenêtre.
func _mise_en_page_journee(view: Control, variante: String) -> void:
	var between: Control = view.regie.between
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = taille
		root.content_scale_size = taille
		await settle(12)
		var label := "Journée %s %d×%d" % [variante, taille.x, taille.y]
		var ecran := Rect2(Vector2.ZERO, Vector2(taille))
		_pas_coupe(between, label)
		for tuile: Control in [between.classement_tuile, between.multiplex]:
			if tuile.visible: check(tuile.is_visible_in_tree() and inside(ecran, tuile.get_global_rect()) and tuile.size.y >= tuile.get_combined_minimum_size().y - 1.0, label + " : " + str(tuile.name) + " entier")
		if between.classement_tuile.visible:
			var lignes := _lignes_classement(between)
			check(lignes.size() >= mini(7, between.journee_vue.classement.size()) and lignes.all(func(l: Control): return inside(between.classement_tuile.get_global_rect(), l.get_global_rect())), label + " : lignes du classement dans la tuile (%d)" % lignes.size())
		# Aucun texte tronqué : sigles, rangs, points, scores et minutes entiers.
		for tuile: Control in [between.classement_tuile, between.multiplex]:
			if not tuile.visible: continue
			for etiquette: Label in tuile.find_children("*", "Label", true, false):
				if not etiquette.is_visible_in_tree() or etiquette.text.is_empty(): continue
				var police: Font = etiquette.get_theme_font("font")
				var largeur := police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, etiquette.get_theme_font_size("font_size")).x
				check(largeur <= etiquette.size.x + 1.0, label + " : « %s » entier (%d sur %d px)" % [etiquette.text, int(largeur), int(etiquette.size.x)])
				check(etiquette.get_theme_font_size("font_size") >= 10, label + " : « %s » lisible" % etiquette.text)
		if between.classement_tuile.visible: check(between.faits.is_visible_in_tree() and between.faits.get_child_count() >= 1 and inside(ecran, between.faits.get_global_rect()), label + " : faits marquants visibles")
		if DisplayServer.get_name() != "headless" and OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES") != "":
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image != null:
				var chemin := OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES").path_join("ecran-2d-multiplex-%s-%dx%d.png" % [variante, taille.x, taille.y])
				print("CAPTURE ", chemin, " ", image.get_size(), " ", image.save_png(chemin))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await settle(4)
