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
const VueMatch = preload("res://match_view.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
const Between = preload("res://ui/contextual/match_between.gd")
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
	# 19 novembre 2026 : la mêlée en TV se cadre jusqu'à 7,5 m (SERRE_MELEE, paquets sur la moitié de l'image).
	check(framing.smallest >= 7.5 and framing.smallest <= 42.5, label + " : l'action est cadrée, ni trop près ni trop loin (%.1f m au plus serré)" % framing.smallest)
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
	check(between.is_visible_in_tree() and inside(screen, between.get_global_rect()), label + " : l'écran intermédiaire tient dans la fenêtre (état %s, visible %s)" % [str(view.regie.etat), str(between.visible)])
	var pitch: Control = between.terrain
	check(pitch.size.x >= 320 and pitch.size.y >= 180 and pitch.champ().size.x >= 260, label + " : terrain lisible (%s)" % str(pitch.size))
	# Pastilles entières dans le cadre : la marge intérieure couvre une pastille sur la touche.
	check(pitch.point(0.0, -2.0).y - pitch.rayon() >= 0.0 and pitch.point(100.0, 72.0).y + pitch.rayon() <= pitch.size.y, label + " : pastilles du bord entières dans le terrain")
	var controls: Control = view.finish.get_parent().get_parent().get_parent()
	check(not controls.is_visible_in_tree() or between.get_global_rect().end.y <= controls.get_global_rect().position.y + 1.0, label + " : rien sous la barre de commandes")
	check(not controls.is_visible_in_tree(), label + " : une seule barre de commandes (celle de l'écran intermédiaire)")
	check(between.get_global_rect().position.y >= view.clock.get_global_rect().end.y - 1.0, label + " : rien sous le bandeau du score")
	# Mon XV (DA du 19/11/2026) : tableau de quinze lignes et le banc, puis le XV adverse par son lien ; rien n'est coupé.
	var vue_avant: String = between.vue_xv
	between.choisir_vue_xv("tableau")
	await settle(4)
	check(between.vue_xv == "tableau" and between.xv.is_visible_in_tree() and between.xv.columns == 1 and between.tuile_principale.is_ancestor_of(between.xv), label + " : Mon XV en tableau, tuile principale")
	var lignes_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button and str(n.name).begins_with("MatchBetweenPlayer"))
	check(lignes_xv.size() == 15, label + " : quinze lignes dans Mon XV (%d)" % lignes_xv.size())
	check(between.banc.is_visible_in_tree() and between.banc.get_child_count() >= 1, label + " : le banc sous Mon XV")
	_pas_coupe(between, label + " (Mon XV)")
	if proof != "" and OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES") != "": await _capture(label, "tableau")
	between.find_child("MatchBetweenTabOpponent", true, false).pressed.emit()
	await settle(4)
	check(between.vue_xv == "adverse" and between.xv.is_visible_in_tree() and not between.banc.is_visible_in_tree(), label + " : XV adverse par le lien de Mon XV")
	_pas_coupe(between, label + " (XV adverse)")
	between.choisir_vue_xv("tableau")
	await settle(2)
	check(between.chiffres.get_child_count() >= 2 and between.fil.get_child_count() >= 1, label + " : fil et chiffres remplis")
	# Mise à l'échelle : textes à l'échelle de la fenêtre, jamais sous 12 px.
	var density: float = between.densite_pour(Vector2(size))
	var figure: Label = between.chiffres.get_child(0).find_children("*", "Label", true, false)[0]
	check(is_equal_approx(between._densite, density) and figure.get_theme_font_size("font_size") == maxi(12, roundi(15 * density)), label + " : chiffres à l'échelle (%d points)" % figure.get_theme_font_size("font_size"))
	check(figure.get_theme_font_size("font_size") >= 12 and between.etat.get_theme_font_size("font_size") == maxi(12, roundi(22 * density)), label + " : texte lisible")
	# Les commandes communes sont dans la bande sous le score (la même qu'en 3D).
	var bande: Control = view.get("bande_temps_forts")
	# Écran 13 (20/11/2026) : la bande est sur la rangée du score, à sa droite (maquettes 13 et 14).
	check(bande != null and bande.is_visible_in_tree() and bande.get_global_rect().position.x >= view.get("_coque_score").get_global_rect().end.x - 1.0 and bande.get_global_rect().end.y <= between.get_global_rect().position.y + 1.0, label + " : bande de commandes à droite du score, au-dessus de l'entracte")
	for nom in ["MatchBetweenTeam", "MatchBetweenSettings", "MatchBetweenMore"]:
		var noeud: Control = view.find_child(nom, true, false)
		check(noeud != null and noeud.is_visible_in_tree() and bande != null and bande.is_ancestor_of(noeud) and inside(screen, noeud.get_global_rect()), label + " : commande " + nom)
	check(not view.find_children("*", "OptionButton", true, false).any(func(o: OptionButton): return o.is_visible_in_tree()), label + " : pas de sélecteur « Horloge … » dans la bande (vitesse dans Réglages)")
	check(between.domination.is_visible_in_tree() and between.domination.size.y >= between.px(120), label + " : frise de domination visible (%d px)" % int(between.domination.size.y))
	check(not between.adjoint_cadre.visible or between.adjoint_cadre.is_visible_in_tree(), label + " : carte de Gabi à l'écran")
	check(between.find_child("MatchBetweenConsignes", true, false) == null and between.find_children("Consigne_*", "BoxContainer", true, false).is_empty(), label + " : pas de consignes sur l'écran 2D")
	# Maquette DA (variante 1) : le terrain 2D au centre, plus large que Mon XV et que les chiffres clés.
	var colonne_xv: Control = between.tuile_principale
	var column: Control = between.find_child("MatchBetweenColumn", true, false)
	var bandeau: Control = between.bandeau
	var tuile_terrain: Control = between.find_child("MatchBetweenPitchTile", true, false)
	check(pitch.size.x >= size.x * 0.38 and pitch.size.y >= size.y * 0.25 and pitch.size.x > colonne_xv.size.x and pitch.size.x > column.size.x, label + " : terrain 2D en grand au centre (%s)" % str(pitch.size))
	check(colonne_xv.get_global_rect().end.x <= pitch.get_global_rect().position.x and column.get_global_rect().position.x >= pitch.get_global_rect().end.x, label + " : Mon XV à gauche, chiffres clés à droite")
	check(bandeau.is_visible_in_tree() and tuile_terrain != null and tuile_terrain.is_ancestor_of(bandeau) and not pitch.is_ancestor_of(bandeau)
		and bandeau.get_global_rect().end.y <= pitch.get_global_rect().position.y + 0.5 and not bandeau.get_global_rect().intersects(pitch.get_global_rect()),
		label + " : dernier fait au-dessus du terrain, sans chevauchement (%s / %s)" % [str(bandeau.get_global_rect()), str(pitch.get_global_rect())])
	await _tient(view, between, label, screen)
	# Chiffres clés : possession et occupation en tête, entrées dans les 22 seulement avec leur donnée.
	var direct_vu: Dictionary = between._dernier[2] if between._dernier.size() == 4 else {}
	check(str(between.chiffres.get_child(0).name) == "MatchBetweenFigure_possession", label + " : la possession en tête des chiffres clés")
	check((between.chiffres.find_child("MatchBetweenFigure_zone22", false, false) != null) == (direct_vu.get("zone22") is Dictionary), label + " : entrées dans les 22 montrées seulement avec leur donnée")
	# Domination en largeur sous les trois colonnes, Gabi en largeur dessous.
	var frise: Control = between.find_child("MatchBetweenMomentumTile", true, false)
	check(frise != null and frise.size.x >= between.size.x * 0.9 and frise.get_global_rect().position.y >= pitch.get_global_rect().end.y, label + " : domination en largeur sous le terrain")
	check(not between.adjoint_cadre.visible or between.adjoint_cadre.size.x >= between.size.x * 0.9 and between.adjoint_cadre.get_global_rect().position.y >= frise.get_global_rect().end.y, label + " : carte de Gabi en largeur, en bas (%s)" % str(between.adjoint_cadre.get_global_rect()))
	for row: Control in between.chiffres.get_children():
		for cell: Label in row.find_children("*", "Label", true, false):
			check(cell.get_minimum_size().x <= cell.size.x + 1.0 or cell.clip_text, label + " : chiffre entier : " + cell.text)
	# Vue rendue telle que le joueur l'avait.
	between.choisir_vue_xv(vue_avant)
	await settle(2)

## Rien de l'écran intermédiaire ne déborde de son cadre ; le contenu des zones qui défilent (Mon XV et le banc,
## cartes du multiplex) peut être hors de vue (on le fait défiler), la zone elle-même doit tenir.
func _pas_coupe(between: Control, label: String) -> void:
	var feed: Control = between.fil.get_parent()
	var defilants: Array = between.find_children("*", "ScrollContainer", true, false)
	for node: Control in between.find_children("*", "Control", true, false):
		if not node.is_visible_in_tree() or node == between.arret or between.arret.is_ancestor_of(node) or feed.is_ancestor_of(node): continue
		if defilants.any(func(d: Node): return d.is_ancestor_of(node)): continue
		check(inside(between.get_global_rect(), node.get_global_rect()), label + " : " + str(node.name) + " n'est pas coupé" + ("" if inside(between.get_global_rect(), node.get_global_rect()) else " (%s hors de %s)" % [str(node.get_global_rect()), str(between.get_global_rect())]))

## Écran intermédiaire tenu dans la fenêtre : marge basse, carte de Gabi bornée, multiplex sur une rangée qui
## défile (panneau « Autres matchs »), bouton PAUSE dans la police des commandes.
func _tient(view: Control, between: Control, label: String, screen: Rect2) -> void:
	var zone: Rect2 = between.get_global_rect()
	var page: Control = between.find_child("MatchBetweenPage", true, false)
	var pied: Control = between.find_child("MatchBetweenKeys", true, false)
	check(page != null and inside(screen, zone) and inside(zone, page.get_global_rect()) and page.get_combined_minimum_size().y <= page.size.y + 1.0, label + " : la page tient dans l'écran intermédiaire (%s dans %s, minimum %d)" % [str(page.get_global_rect()) if page != null else "?", str(zone), int(page.get_combined_minimum_size().y) if page != null else -1])
	check(pied != null and pied.is_visible_in_tree() and inside(screen, pied.get_global_rect()) and pied.get_global_rect().end.y <= zone.end.y - between.px(8) + 1.0, label + " : marge sous le pied des raccourcis (%s, bas de l'écran intermédiaire %d)" % [str(pied.get_global_rect()) if pied != null else "?", int(zone.end.y)])
	for nom in ["MatchBetweenAdvice", "MatchBetweenBonus", "MatchBetweenColumn", "MatchBetweenMain", "MatchBetweenPitchTile", "MatchBetweenSquadScroll"]:
		var noeud: Control = between.find_child(nom, true, false)
		if noeud != null and noeud.is_visible_in_tree(): check(inside(screen, noeud.get_global_rect()) and inside(zone, noeud.get_global_rect()), label + " : " + nom + " dans l'écran (%s)" % str(noeud.get_global_rect()))
	# Gabi : hauteur bornée (portrait, phrase sur deux lignes au plus).
	check(not between.adjoint_cadre.visible or between.adjoint.get_combined_minimum_size().y <= maxf(between.px(110), 60.0), label + " : carte de Gabi de hauteur bornée (%d px)" % int(between.adjoint.get_combined_minimum_size().y))
	for etiquette: Label in between.adjoint.find_children("*", "Label", true, false):
		if etiquette.autowrap_mode != TextServer.AUTOWRAP_OFF: check(etiquette.max_lines_visible >= 1 and etiquette.max_lines_visible <= 2, label + " : phrase de Gabi sur deux lignes au plus")
	# Multiplex (panneau « Autres matchs ») : une seule rangée de cartes, la première entière, la suite défile.
	if between.journee_vue != null:
		between.montrer_droite("journee")
		await settle(3)
		var cartes := _cartes_multiplex(between)
		if between.multiplex.is_visible_in_tree() and not cartes.is_empty():
			var defile: Control = between.multiplex_defile
			check(defile.is_ancestor_of(between.multiplex_cartes) and between.multiplex_cartes.columns == cartes.size(), label + " : multiplex sur une seule rangée (%d colonnes, %d cartes)" % [between.multiplex_cartes.columns, cartes.size()])
			check(cartes.all(func(c: Control): return absf(c.get_global_rect().position.y - (cartes[0] as Control).get_global_rect().position.y) < 1.0), label + " : cartes du multiplex alignées sur une rangée")
			check(inside(defile.get_global_rect(), (cartes[0] as Control).get_global_rect()) and inside(zone, between.multiplex.get_global_rect()), label + " : première carte du multiplex entière, panneau dans l'écran")
			var fondu: Control = between.multiplex_fondu
			var reste_a_droite: bool = between.multiplex_deborde() and float(between.multiplex_defile.scroll_horizontal) + defile.size.x < between.multiplex_cartes.size.x - 1.0
			check(fondu.visible == reste_a_droite, label + " : « › » du multiplex seulement s'il déborde (%s, rangée %d px dans %d)" % [str(fondu.visible), int(between.multiplex_cartes.size.x), int(defile.size.x)])
		between.montrer_droite("chiffres")
		await settle(2)
	# Bouton PAUSE du bandeau : la police des commandes (Barlow Condensed), comme Équipe et Réglages.
	var pause: Button = view.play
	var police_pause: Font = pause.get_theme_font("font")
	var police_equipe: Font = (view.find_child("MatchBetweenTeam", true, false) as Button).get_theme_font("font")
	# Écran 13 (maquette 13-match-direct-1, 20/11/2026) : « Pause · Espace » en DM Sans 500 sur panneau 85 %, à plat.
	var police_dm: bool = police_pause is FontVariation and (police_pause as FontVariation).base_font != null and (police_pause as FontVariation).base_font.resource_path.get_file().begins_with("DMSans")
	check(police_dm and police_equipe != null, label + " : bouton Pause en DM Sans (commandes du HUD)")
	check(pause.text in ["Pause", "Reprendre"] and pause.get_theme_stylebox("normal") is StyleBoxFlat and (pause.get_theme_stylebox("normal") as StyleBoxFlat).border_width_top == 0 and inside(screen, pause.get_global_rect()), label + " : bouton Pause à plat, dans l'écran")

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
		followed = await reprise_avant_match()
	elif mode == "liaison":
		# Carrière Monde arrêtée à la causerie d'avant-match (godot-match-liaison-monde.cjs).
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("monde.json"))})
		await settle()
		await command("begin_match")
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
		await command("begin_match")
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
	elif mode == "grands_moments":
		# Carrière Monde arrêtée à la causerie d'avant-match (godot-match-grands-moments.cjs).
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("monde.json"))})
		await settle()
		await command("begin_match")
		await settle()
		var limite_g := Time.get_ticks_msec() + 120000
		while Time.get_ticks_msec() < limite_g and (surface() == null or surface().regie == null):
			var scene_g: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
			if scene_g is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene_g.key, "phase": scene_g.phase, "skip": true})
			await settle(2)
		var vue_g := surface()
		check(vue_g != null and vue_g.regie != null, "Carrière Monde : le direct en temps forts s'ouvre")
		if vue_g != null and vue_g.regie != null:
			followed = await grands_moments(vue_g)
	elif mode == "multiplex":
		# Carrière world-champ arrêtée au coup d'envoi de son premier match (godot-match-temps-forts.cjs).
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("multiplex.json"))})
		await settle()
		await command("begin_match")
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
		await command("begin_match")
		await settle()
		followed = await player_path()
	else:
		# Carrière Monde du jour de match : coup d'envoi, causerie d'avant-match passée, puis le direct.
		await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("live.json"))})
		await settle()
		await command("begin_match")
		await settle()
		var limite_l := Time.get_ticks_msec() + 120000
		while Time.get_ticks_msec() < limite_l:
			var scene_l: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
			if scene_l is Dictionary:
				if not app.waiting: await command("match_talk_continue", {"key": scene_l.key, "phase": scene_l.phase, "skip": true})
			elif surface() != null and (not surface().temps_forts_actifs() or surface().regie != null):
				# État de l'ancien match importé en pause (la reprise d'une sauvegarde en plein match n'existe plus,
				# décision du 16/11/2026) : le coup d'envoi part en direct, puis le match est mis en pause comme
				# s'il l'était déjà au départ du temps fort (régie._pause_au_depart) : ce temps fort va à son terme,
				# puis l'écran intermédiaire attend ; les modes reprennent le match eux-mêmes. Sans cela, la pause
				# serait celle du manager pendant un temps fort, qui fige l'image (contrôlée par player_path).
				if app.model.get("live") is Dictionary and not app.model.live.get("paused", false):
					if surface().regie != null: surface().regie.set("_pause_au_depart", true)
					await command("pause", {"paused": true})
				break
			await process_frame
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
const SAUT_MAX_LIAISON := 12.0
func check_liaisons(followed: Array) -> void:
	var liaisons: Array = followed.filter(func(e: Dictionary) -> bool: return e.evenement == "liaison")
	for e: Dictionary in liaisons:
		var nom := "Liaison %s (%s)" % [str(e.type), str(e.cle)]
		if not e.has("duree_reelle"): continue
		check(float(e.duree_reelle) >= float(e.duree_prevue) - 0.2 and float(e.duree_reelle) <= float(e.duree_prevue) + 1.5,
			"%s : jouée à vitesse réelle (%.2f s pour %.2f s prévues)" % [nom, float(e.duree_reelle), float(e.duree_prevue)])
		# Seuil (19/11/2026) : au-dessus d'un sprint (12 m/s) ; un vrai saut de place dépasse 20 m/s
		# (35 cm en une image à 60 i/s). À 10 m/s, une seule image irrégulière d'un exécuteur de CI
		# (pointe isolée à 10,5 m/s dans la mise en place d'une touche) faisait échouer le contrôle.
		check(float(e.get("saut_max", 0.0)) <= SAUT_MAX_LIAISON, "%s : aucun saut de position dans un plan (pointe %.1f m/s d'une image à l'autre)" % [nom, float(e.get("saut_max", 0.0))])
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

## Grands moments sur une vraie carrière Monde (godot-match-grands-moments.cjs), match entier :
## essai joué en 3D (bandeau « ESSAI » qui nomme le marqueur et son équipe, sous le score ; ralenti
## puis image tenue : la transformation attend), mi-temps et fin de match (plan large, joueurs qui
## marchent vers le tunnel, bandeau « MI-TEMPS » / « FIN DU MATCH ») ; la causerie de mi-temps et
## le débrief ne s'ouvrent qu'après la sortie, une seule sortie par moment.
func grands_moments(view: Control) -> Array:
	var director: Node = app.contextual_director
	var regie: Node = view.regie
	var suivi_courant: Array = regie.suivi
	var anciens: Array = []
	var limite := int(OS.get_environment("CD_GRANDS_MOMENTS_LIMITE")) if OS.get_environment("CD_GRANDS_MOMENTS_LIMITE").is_valid_int() else 1200
	var deadline := Time.get_ticks_msec() + limite * 1000
	var essai := {"debut": 0, "cle": "", "plan": -1, "ecart": -1.0, "bandeau": {}, "texte": "", "ralenti": 1.0, "vitesse": 1.0, "calme": false, "cadre": Rect2(), "score_bas": 0.0, "bande_bas": 0.0, "ecran": Rect2(), "legende": Rect2()}
	var sorties := {}
	var ralenti := {"images": 0, "ecarts": 0}
	var relance := 0
	var apres_fin := 0
	var sonde := 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		watch()
		sonde += 1
		var scene := talk()
		if director.kind == "locker" and not scene.is_empty():
			var phase_c := str(scene.get("phase", ""))
			var moment_c := str({"half": "mi-temps", "post": "fin"}.get(phase_c, ""))
			if not moment_c.is_empty() and not sorties.has(moment_c + "_causerie"):
				sorties[moment_c + "_causerie"] = true
				var s_c: Dictionary = sorties.get(moment_c, {})
				# La causerie ne s'ouvre que quand la régie ne retient plus : la sortie est finie.
				check(int(s_c.get("marche", 0)) > 0, "Causerie « %s » ouverte après le plan large et la marche vers le tunnel : %s" % [phase_c, str(s_c.get("images", 0))])
			if phase_c == "post": break
			if not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
			continue
		var vue := surface()
		if vue == null or vue.regie == null:
			if not app.model.get("live") is Dictionary: break
			continue
		if vue.regie != regie:
			# Vue recréée après la causerie : le journal de la régie précédente est gardé.
			anciens.append_array(suivi_courant)
			regie = vue.regie
			view = vue
		suivi_courant = regie.suivi
		var live: Dictionary = app.model.live if app.model.get("live") is Dictionary else {}
		if live.is_empty(): break
		if sonde % 600 == 0: print("sonde grands moments : minute ", live.get("minute"), " état ", regie.etat, " essai ", essai.debut > 0, " sorties ", sorties.keys())
		# Le match attend le manager (coup d'envoi, reprise de seconde période) : il reprend comme avec le bouton.
		if live.get("paused", false) and not live.get("finished", false) and not live.get("atBreak", false) and regie.etat == regie.INTER and regie.arret.is_empty() and not app.waiting and Time.get_ticks_msec() > relance:
			relance = Time.get_ticks_msec() + 2000
			app._command("pause", {"paused": false})
		_observer_essai(view, regie, essai)
		_observer_sortie(view, regie, live, sorties)
		# Ralenti de l'essai : la mention « RALENTI » est à l'écran pendant et seulement pendant lui.
		if regie.has_method("rejeu_en_cours"):
			var en_ralenti: bool = regie.rejeu_en_cours()
			if en_ralenti: ralenti.images += 1
			if en_ralenti != bool(regie.mention_affichee()): ralenti.ecarts += 1
		# Fin de match sans débrief : l'écran de fin suit la sortie.
		if live.get("finished", false) and sorties.has("fin") and regie.etat == regie.INTER:
			apres_fin += 1
			if apres_fin > 60: break
	var tous: Array = anciens + suivi_courant
	# Essai.
	check(int(essai.debut) > 0, "Un essai est joué en 3D pendant le match")
	if int(essai.debut) > 0:
		var b: Dictionary = essai.bandeau
		var attendu: String = load("res://ui/contextual/match_temps_forts.gd").marqueur_essai(str(essai.texte))
		check(bool(b.get("visible", false)) and str(b.get("titre", "")) == "ESSAI", "Bandeau « ESSAI » dès que l'essai est aplati : " + str(b))
		check(str(b.get("nom", "")) == attendu and (not attendu.is_empty() or not str(essai.texte).contains("Essai de")), "Le bandeau nomme le marqueur (« %s », légende « %s »)" % [str(b.get("nom", "")), str(essai.texte)])
		check(not str(b.get("equipe", "")).is_empty(), "Le bandeau nomme l'équipe qui marque : " + str(b))
		var voulu: float = 0.9 * float(load("res://ui/contextual/match_temps_forts.gd").ESSAI_MOMENT) / maxf(float(essai.vitesse), 0.01)
		check(float(essai.ecart) >= voulu, "Pause d'essai : la suite attend %.2f s (%.2f s au moins à ×%.0f)" % [float(essai.ecart), voulu, float(essai.vitesse)])
		check(bool(essai.calme) or float(essai.ralenti) <= 0.6, "Ralenti de la vue à l'essai (%.2f de la vitesse réelle)" % float(essai.ralenti))
		var cadre: Rect2 = essai.cadre
		check(cadre.size.x > 0.0 and cadre.position.y >= maxf(float(essai.score_bas), float(essai.bande_bas)) - 1.0, "Le bandeau ne masque pas le score (%s, score jusqu'à %.0f, bande jusqu'à %.0f)" % [str(cadre), float(essai.score_bas), float(essai.bande_bas)])
		var ecran: Rect2 = essai.ecran
		check(ecran.grow(1.0).encloses(cadre), "Bandeau entier dans l'image : %s dans %s" % [str(cadre), str(ecran)])
		# Façon retransmission : tiers inférieur, au-dessus de la légende sans la recouvrir.
		var sous_titre: Rect2 = essai.get("legende", Rect2())
		check(cadre.get_center().y >= ecran.position.y + ecran.size.y * 2.0 / 3.0, "Bandeau « ESSAI » dans le tiers inférieur (%s dans %s)" % [str(cadre), str(ecran)])
		check(sous_titre.has_area() and not cadre.intersects(sous_titre), "Le bandeau « ESSAI » ne recouvre pas la légende (%s, légende %s)" % [str(cadre), str(sous_titre)])
	# Ralenti de l'essai (19/11/2026) : un par essai au plus, jamais deux pour le même ; environ la moitié
	# de la vitesse réelle, au plus REJEU_MAX s ajoutées (à la vitesse du test), caméra basse, état d'avant
	# remis ; mention « RALENTI » seulement pendant lui ; aucun avec les animations réduites.
	var regie_script = load("res://ui/contextual/match_temps_forts.gd")
	var essais_vus := tous.filter(func(e: Dictionary) -> bool: return str(e.get("evenement", "")) == "essai_moment")
	var ralentis := tous.filter(func(e: Dictionary) -> bool: return str(e.get("evenement", "")) == "rejeu")
	var cles_ralentis := {}
	for e: Dictionary in ralentis: cles_ralentis["%s|%s" % [str(e.get("cle", "")), str(e.get("plan", ""))]] = true
	check(ralentis.size() <= essais_vus.size() and cles_ralentis.size() == ralentis.size(), "Un ralenti par essai au plus (%d ralentis, %d essais)" % [ralentis.size(), essais_vus.size()])
	if bool(essai.calme):
		check(ralentis.is_empty(), "Animations réduites : aucun ralenti")
	elif int(essai.debut) > 0:
		check(not ralentis.is_empty(), "Ralenti de l'essai joué en 3D (%d)" % ralentis.size())
	for e: Dictionary in ralentis:
		var nom := "Ralenti %s" % str(e.get("cle", ""))
		check(absf(float(e.get("vitesse", 0.0)) - 0.5) <= 0.1, "%s : à %.2f de la vitesse réelle" % [nom, float(e.get("vitesse", 0.0))])
		check(float(e.get("duree_prevue", 99.0)) <= float(regie_script.REJEU_MAX) + 0.15, "%s : %.2f s ajoutées au plus" % [nom, float(e.get("duree_prevue", 99.0))])
		var h_cam := float(e.get("hauteur_camera", 99.0))
		check(h_cam >= 2.5 and h_cam < 3.5, "%s : caméra rasante au-dessus des protections (%.2f m)" % [nom, h_cam])
		if not e.has("duree_reelle"): continue
		var a_vitesse_reelle := float(e.duree_reelle) * maxf(float(e.get("vitesse_regie", 1.0)), 0.01)
		check(bool(e.get("passe", false)) or a_vitesse_reelle <= float(regie_script.REJEU_MAX) + 0.6, "%s : %.2f s à vitesse réelle" % [nom, a_vitesse_reelle])
		check(float(e.get("ecart_restitution", 999.0)) < 0.001, "%s : état d'avant remis à l'identique (écart %.5f)" % [nom, float(e.get("ecart_restitution", 999.0))])
	check(int(ralenti.ecarts) == 0, "Mention « RALENTI » pendant et seulement pendant le ralenti (%d images en écart, %d images de ralenti)" % [int(ralenti.ecarts), int(ralenti.images)])
	# Mi-temps et fin de match.
	for moment: String in ["mi-temps", "fin"]:
		var s: Dictionary = sorties.get(moment, {})
		check(not s.is_empty(), "Sortie des joueurs à la " + moment)
		if s.is_empty(): continue
		check(int(s.large) == int(s.images), "%s : plan large pendant toute la sortie (%d sur %d images)" % [moment, int(s.large), int(s.images)])
		check(int(s.visible) > 0, "%s : l'image 3D est à l'écran pendant la sortie (%d images)" % [moment, int(s.visible)])
		check(int(s.bandeau) > 0, "%s : bandeau « %s »" % [moment, "FIN DU MATCH" if moment == "fin" else "MI-TEMPS"])
		var rapproches := 0
		for id: String in s.departs:
			var d0 := Vector2(s.departs[id].x - VueMatch.TUNNEL.x, s.departs[id].z - VueMatch.TUNNEL.z).length()
			var d1 := Vector2(s.derniers[id].x - VueMatch.TUNNEL.x, s.derniers[id].z - VueMatch.TUNNEL.z).length()
			if d1 < d0 - 0.3 or d1 < 5.0: rapproches += 1
		var n: int = maxi(1, (s.departs as Dictionary).size())
		check(int(s.marche) > 0 and rapproches >= int(n * 0.8), "%s : les joueurs marchent vers le tunnel (%d images, %d sur %d se rapprochent)" % [moment, int(s.marche), rapproches, n])
		check(int(s.get("serre", 0)) == int(s.marche), "%s : la marche est montrée en plan serré qui suit les joueurs (%d sur %d images)" % [moment, int(s.get("serre", 0)), int(s.marche)])
		check(int(s.get("bandeau_haut", 0)) == 0, "%s : pendant la marche, le bandeau ne cache pas le tunnel (%d images avec le bandeau en haut)" % [moment, int(s.get("bandeau_haut", 0))])
	if sorties.has("mi-temps"): check(int(sorties["mi-temps"].retenue) > 0, "Mi-temps : la causerie attend la fin de la sortie")
	check(sorties.has("mi-temps_causerie"), "La causerie de mi-temps s'ouvre après la sortie")
	for moment: String in ["mi-temps", "fin"]:
		var n_sorties := tous.filter(func(e: Dictionary) -> bool: return str(e.get("evenement", "")) == "sortie" and str(e.get("moment", "")) == moment).size()
		check(n_sorties == 1, "Une seule sortie de %s, même après la causerie (%d)" % [moment, n_sorties])
	print("Grands moments : essai ", essai.bandeau, " pause ", snappedf(float(essai.ecart), 0.01), " s, ralenti ", snappedf(float(essai.ralenti), 0.01),
		" ; sorties ", sorties.keys().filter(func(k: String) -> bool: return not k.ends_with("_causerie")).map(func(k: String) -> String: return "%s %d images (marche %d)" % [k, int(sorties[k].images), int(sorties[k].marche)]))
	return tous

## Premier essai joué en 3D : bandeau au début du moment, pause mesurée jusqu'au plan suivant.
func _observer_essai(view: Control, regie: Node, essai: Dictionary) -> void:
	var en_jeu: bool = regie.etat == regie.JEU and regie.index >= 0 and regie.index < (regie.tf.get("plans", []) as Array).size()
	if int(essai.debut) > 0 and float(essai.ecart) < 0.0:
		# Fin du moment : le plan suivant (transformation) ou la fin du temps fort, jamais avant.
		if not en_jeu or str(regie.tf.get("cle", "")) != str(essai.cle) or regie.index != int(essai.plan) or float(regie._moment_essai) <= 0.0:
			essai.ecart = (Time.get_ticks_msec() - int(essai.debut)) / 1000.0
			essai.ralenti = float(regie.ralenti_min)
			if regie.bandeau != null and regie.bandeau.visible:
				essai.cadre = (regie.bandeau as Control).get_global_rect()
				essai.score_bas = view.score.get_global_rect().end.y
				var bande: Control = view.get("bande_temps_forts")
				essai.bande_bas = bande.get_global_rect().end.y if bande != null and bande.is_visible_in_tree() else 0.0
				essai.ecran = view.get_global_rect()
				var legende: Rect2 = regie._legende_rect
				essai.legende = Rect2(legende.position + view.get_global_rect().position, legende.size)
		return
	if int(essai.debut) > 0 or not en_jeu: return
	var plan: Dictionary = regie.tf.plans[regie.index]
	if str(plan.get("kind", "")) != "try" or float(regie._moment_essai) <= 0.0: return
	essai.debut = Time.get_ticks_msec()
	essai.cle = str(regie.tf.get("cle", ""))
	essai.plan = regie.index
	essai.texte = str(plan.get("texte", ""))
	essai.bandeau = regie.bandeau_affiche()
	essai.vitesse = float(regie.vitesse)
	essai.calme = bool(regie._calme())
	print("Essai en 3D : ", essai.texte, " · bandeau ", essai.bandeau)

## Sortie des joueurs en cours : plan large, bandeau, causerie retenue, positions des joueurs.
func _observer_sortie(view: Control, regie: Node, live: Dictionary, sorties: Dictionary) -> void:
	if regie.etat != regie.SORTIE: return
	var moment := "fin" if live.get("finished", false) else "mi-temps"
	if not sorties.has(moment): sorties[moment] = {"images": 0, "large": 0, "visible": 0, "marche": 0, "retenue": 0, "bandeau": 0, "departs": {}, "derniers": {}}
	var s: Dictionary = sorties[moment]
	s.images += 1
	var stage: Node3D = view.stage
	if stage.plan_large(): s.large += 1
	if not regie.voile.visible or regie.voile.modulate.a < 0.5: s.visible += 1
	if app.contextual_director.kind == "live" and view.retient_la_causerie(live): s.retenue += 1
	var b: Dictionary = regie.bandeau_affiche()
	if bool(b.get("visible", false)) and str(b.get("titre", "")) == ("FIN DU MATCH" if moment == "fin" else "MI-TEMPS"): s.bandeau += 1
	if stage.sortie:
		s.marche += 1
		if bool(stage.get("plan_sortie")): s.serre = int(s.get("serre", 0)) + 1
		# Plan serré : le bandeau descend dans la pelouse du bas, le tunnel (haut de l'image) reste visible.
		if regie.bandeau != null and regie.bandeau.visible and (regie.bandeau as Control).get_global_rect().position.y < view.get_global_rect().position.y + view.size.y * 0.5:
			s.bandeau_haut = int(s.get("bandeau_haut", 0)) + 1
		for id: String in stage._actors:
			var at: Vector3 = (stage._actors[id].node as Node3D).position
			if not s.departs.has(id): s.departs[id] = at
			s.derniers[id] = at

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
	# Les traces « legende » (texte / image) ne sont pas des événements de la régie.
	var faits: Array = regie.suivi.filter(func(e: Dictionary) -> bool: return e.evenement != "legende")
	check(faits.size() == 1 and faits[0].evenement == "temps_fort", "Premier temps fort suivi")
	var first_key := str(view.stage.get("_action_key"))
	check(not first_key.is_empty() and view.stage.get("_actors").size() == 30, "La vue 3D montre les trente joueurs du plan")
	check(view.clock.text.ends_with("′"), "Le bandeau affiche l'horloge du plan rejoué : " + view.clock.text)
	# Écran 13 (20/11/2026) : la légende est reprise par le journal du bas (minute + texte).
	await settle(2)
	check(not view.events.text.is_empty() and view.journal_affiche().any(func(l: String) -> bool: return l.contains(view.events.text.strip_edges().left(16))), "La légende du plan est affichée : " + view.events.text + " · journal " + str(view.journal_affiche()))
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
	check(regie.etat != regie.JEU or regie.suivi.filter(func(e: Dictionary) -> bool: return e.evenement != "legende").size() > 2, "Une minute sans action retenue reste sur l'écran intermédiaire")
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
		elif resumed and not app.waiting and regie.etat != regie.JEU and app.model.live.paused:
			# Arrêt de jeu qui attend le manager (carton, blessure… carrière Monde) : le test répond comme lui.
			print("Reprise après un arrêt à la minute ", int(app.model.live.minute), " : ", str(regie.get("arret")))
			if not (regie.get("arret") as Dictionary).is_empty(): regie.between.reprise_demandee.emit()
			else: app._command("pause", {"paused": false})
			await wait_command()
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
	# Bandeau compact pendant l'action 3D (film du 18/11/2026 : la grande barre cachait ~20 % de
	# l'image) ; bouton PAUSE tant que le match joue.
	var coque: Control = view.get("_coque_score")
	check(view.compact and view.play.text == "Pause", "Action 3D : bandeau compact et bouton PAUSE (%s, « %s »)" % [str(view.compact), view.play.text])
	if coque != null:
		var bloc := coque.get_global_rect()
		check(bloc.size.y <= screen.size.y * 0.12 and bloc.size.x <= screen.size.x * 0.6 and bloc.position.x <= screen.size.x * 0.1, "Bloc compact en haut à gauche, petit : " + str(bloc))
		# Écran 13 (variante 1 de Léo, 20/11/2026) : le bandeau d'angle garde les noms pendant l'action ; seules
		# la météo et l'aide « Échap » se retirent.
		check(view.home.is_visible_in_tree() and view.plaques[0].find_child("MatchClubCrest0", true, false).is_visible_in_tree() and not (view.get("_sigles")[0] as Label).is_visible_in_tree() and view.clock.is_visible_in_tree() and view.score.is_visible_in_tree() and not view.get("_meteo_boite").is_visible_in_tree(), "Bandeau d'angle pendant l'action : horloge, plaques et score, sans météo")
		check(float(regie.cadrage.couvert_haut) <= view.clock.get_global_rect().end.y / maxf(1.0, view.size.y) + 0.031, "Cadrage : part cachée en haut ramenée au bloc compact (%.3f)" % float(regie.cadrage.couvert_haut))
	view._pause()
	await wait_command()
	check(app.model.live.paused and regie.gel and regie.etat == regie.JEU, "La pause demandée pendant un temps fort fige l'image")
	var frozen := [regie.index, regie.temps, regie.phase]
	await settle(40)
	check(frozen == [regie.index, regie.temps, regie.phase] and view.play.text == "Reprendre", "Rien n'avance pendant la pause")
	await settle(2)
	check(not view.compact and view.home.is_visible_in_tree() and view.get("_meteo_boite").visible == view.meteo_ligne.visible, "Pause : la ligne météo revient sous le bandeau")
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

## Carrière rouverte après un match quitté en cours (mode « gestes ») : depuis la décision de Léo du 16/11/2026,
## une carrière n'est jamais enregistrée en plein match ; elle reprend avant le coup d'envoi, le match est à
## rejouer. Le niveau de temps forts enregistré (« étendus ») est conservé et le nouveau coup d'envoi part en
## temps forts, sans rien de l'ancien direct.
func reprise_avant_match() -> Array:
	await settle(10)
	var live: Variant = app.model.get("live")
	check(surface() == null and not (live is Dictionary and not (live as Dictionary).is_empty()), "Rouverte après un match quitté en cours : aucun direct, la carrière reprend avant le coup d'envoi")
	check(bool(app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false)) and app.model.get("next") is Dictionary, "Le match est à rejouer : jour de match, coup d'envoi possible")
	check(str(app.user_preferences.data.get("match_highlights", "")) == "etendus", "Le niveau de temps forts enregistré est repris : " + str(app.user_preferences.data.get("match_highlights", "")))
	if not app.model.get("selection", {}).get("valid", false): await command("auto_lineup")
	await command("begin_match")
	var limite := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < limite and (surface() == null or surface().regie == null):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	var view := surface()
	check(view != null and view.regie != null and view.temps_forts_actifs() and view.regie.niveau == "etendus", "Le match rejoué s'ouvre en temps forts, au niveau repris")
	if view == null or view.regie == null: return []
	check(int(app.model.live.minute) <= 1, "Le match repart du coup d'envoi (minute %d)" % int(app.model.live.minute))
	check(await until(func(): return view.regie.suivi.any(func(e: Dictionary): return e.evenement == "temps_fort"), 60000), "Le coup d'envoi est joué en temps forts")
	app._command("pause", {"paused": true})
	await wait_command()
	return view.regie.suivi

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
	check(minutes.size() >= 1 and between.domination.minutes == minutes, "Domination : la frise du moteur, minute par minute (%d minutes)" % minutes.size())
	check(minutes.all(func(v: Variant): return absf(float(v)) <= 100.0), "Domination bornée")
	var rangs: Array = direct.get("tableau", [])
	# Chiffres clés (DA du 19/11/2026) : possession, occupation, pénalités, entrées dans les 22, plaquages réussis,
	# mêlées, touches ; notre valeur à gauche, la leur à droite, reprises du moteur.
	var camp_xv := int(direct.camp)
	var nous := camp_xv if camp_xv in [0, 1] else 0
	var attendus: Array = between.STATS.filter(func(c: String): return rangs.any(func(r: Dictionary): return str(r.cle) == c) or (c == "zone22" and direct.get("zone22") is Dictionary) or (c == "plaquages_reussis" and rangs.any(func(r: Dictionary): return str(r.cle) == "plaquages_manques")))
	check(between.chiffres.get_children().map(func(n: Node): return str(n.name).trim_prefix("MatchBetweenFigure_")) == attendus and attendus.size() >= 5, "Chiffres clés : %s" % str(attendus))
	for ligne: Node in between.chiffres.get_children():
		var cle := str(ligne.name).trim_prefix("MatchBetweenFigure_")
		var rang: Array = rangs.filter(func(r: Dictionary): return str(r.cle) == cle)
		if rang.is_empty(): continue
		var textes: Array = ligne.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
		check(rang[0].get("vide", false) and textes[1] == "—" or str(textes[1]).begins_with(str(int(rang[0].valeurs[nous]))) and str(textes[2]).begins_with(str(int(rang[0].valeurs[1 - nous]))), "Chiffre « %s » repris du moteur, le nôtre à gauche %s" % [cle, str(textes)])
	var lineup: Array = between._passe(app.model, app.model.live, direct).lineup
	# Mon XV : tableau par défaut (numéro, nom, énergie, plaquages, note).
	check(between.vue_xv == "tableau" and between.xv.is_visible_in_tree(), "Mon XV s'ouvre en tableau")
	# Joueur le plus en difficulté : blessé d'abord, sinon l'énergie la plus basse, sous le seuil de fatigue ; les sanctionnés à part.
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
	check(between.changement_poste == attendu_changement, "Joueur le plus en difficulté : poste %d attendu %d" % [between.changement_poste, attendu_changement])
	# Entrées dans les 22 : absentes sans `direct.zone22`, ligne des chiffres clés avec une donnée injectée.
	var avec_22: Dictionary = direct.duplicate()
	avec_22["zone22"] = {"entrees": [3, 1], "points": [10, 0], "secondes": [200, 65]}
	between.update_frame(app.model, app.model.live, avec_22, func(_c: Dictionary): pass)
	var ligne_22: Node = between.chiffres.find_child("MatchBetweenFigure_zone22", false, false)
	var textes_22: Array = ligne_22.find_children("*", "Label", true, false).map(func(l: Label): return l.text) if ligne_22 != null else []
	check(textes_22.size() == 3 and textes_22[1] == str([3, 1][nous]) and textes_22[2] == str([3, 1][1 - nous]), "Entrées dans les 22 : nos entrées à gauche " + str(textes_22))
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	await settle(2)
	check((between.chiffres.find_child("MatchBetweenFigure_zone22", false, false) != null) == (direct.get("zone22") is Dictionary), "Entrées dans les 22 de nouveau absentes sans leur donnée")
	var lignes_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button)
	check(lignes_xv.size() == lineup.size() and lineup.size() == 15, "Mon XV : quinze joueurs (%d)" % lignes_xv.size())
	var conformes := 0
	var feuille: Dictionary = direct.get("feuille", {})
	for poste in mini(lineup.size(), lignes_xv.size()):
		var joueur: Variant = lineup[poste]
		if not joueur is Dictionary: continue
		var nom_bouton: Array = lignes_xv[poste].find_children("MatchBetweenPlayerName_*", "Button", true, false)
		var textes: Array = lignes_xv[poste].find_children("*", "Label", true, false).map(func(l: Label): return l.text)
		var energie: Array = lignes_xv[poste].find_children("*", "Control", true, false).filter(func(c: Control): return c.get("valeur") != null)
		var note := float(direct.get("notes", {}).get(str(joueur.id), {}).get("note", 6.5))
		var plaq := str(int(feuille.get("joueurs", {}).get(str(joueur.id), {}).get("plaquages", 0)))
		if nom_bouton.size() == 1 and str(nom_bouton[0].get_meta("nom_entier", nom_bouton[0].text)) == str(joueur.name) and ("%.1f" % note).replace(".", ",") in textes and plaq in textes and not energie.is_empty() and is_equal_approx(float(energie[0].valeur), float(joueur.condition)): conformes += 1
	check(conformes == lineup.size(), "Mon XV : nom (lien vers la fiche), note, plaquages et énergie du moteur pour chaque joueur (%d/%d)" % [conformes, lineup.size()])
	var alertes_attendues := lineup.filter(func(j: Variant): return j is Dictionary and (int(j.get("injury", 0)) > 0 or float(j.get("condition", 100)) < between.FATIGUE)).size()
	check(between.alertes_xv.size() >= alertes_attendues, "Alertes de fatigue et de blessure reprises (%d pour %d)" % [between.alertes_xv.size(), alertes_attendues])
	# Alerte de fatigue : un joueur à bout (condition modifiée sur une copie) est signalé par l'adjoint.
	var copie: Dictionary = app.model.duplicate(true)
	copie.live.lineup[6].condition = 31
	var direct_complet: Dictionary = direct.duplicate()
	direct_complet["borne"] = copie.live.events.size()
	between.update_frame(copie, copie.live, direct_complet, func(_c: Dictionary): pass)
	var adjoint_textes: Array = between.adjoint.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
	check(adjoint_textes.any(func(t: String): return t.contains("N° 7") and "31" in t), "L'adjoint signale le joueur à bout : " + str(adjoint_textes.slice(0, 3)))
	# Gabi : « Remplacer le 7 » ouvre la fenêtre Équipe sur lui, sauf blessé ou sanctionné prioritaire.
	var blesses: Array = copie.live.lineup.filter(func(j: Variant): return j is Dictionary and int(j.get("injury", 0)) > 0)
	if blesses.is_empty() and not sanctionnes.has(str(copie.live.lineup[6].id)):
		var choisis_copie: Array = []
		var noter_copie := func(poste: int): choisis_copie.append(poste)
		between.joueur_choisi.connect(noter_copie)
		var action_copie: Button = between.find_child("MatchBetweenReplace", true, false)
		if action_copie != null: action_copie.pressed.emit()
		between.joueur_choisi.disconnect(noter_copie)
		check(between.changement_poste == 6 and action_copie != null and action_copie.text.begins_with("Remplacer le 7") and choisis_copie == [6], "Gabi : « Remplacer le 7 » ouvre la fenêtre Équipe sur lui (%s)" % str(choisis_copie))
		if view.equipe.visible: view.equipe.fermer()
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
	# Colonne « Plaq. » : la feuille de statistiques (match-stats.cjs) ; le total d'équipe est la somme des joueurs.
	check(feuille.get("joueurs") is Dictionary and not feuille.joueurs.is_empty(), "Feuille de statistiques jointe au direct")
	var somme := {"plaquages": 0, "metres": 0}
	for fj: Dictionary in feuille.get("joueurs", {}).values():
		if int(fj.camp) == camp_xv:
			for cle: String in somme: somme[cle] += int(fj.get(cle, 0))
	for cle: String in somme:
		var rang_cle := rangs.filter(func(r: Dictionary): return str(r.cle) == cle)
		check(rang_cle.size() == 1 and int(rang_cle[0].valeurs[camp_xv]) == int(somme[cle]), "Tableau : %s de l'équipe = somme des joueurs de la feuille (%d)" % [cle, somme[cle]])
		check(int(feuille.equipes[camp_xv][cle]) == int(somme[cle]), "Feuille : total d'équipe = somme des joueurs (%s)" % cle)
	var colonne := func(zone: Node) -> Array: return zone.find_children("*", "Label", true, false).filter(func(l: Label): return l.visible).map(func(l: Label): return l.text)
	var total_xv: Node = between.pied_xv.find_child("MatchBetweenTeamTotal", true, false)
	check(total_xv != null and colonne.call(total_xv).has(str(somme.plaquages)), "Ligne Équipe de Mon XV : plaquages %d" % somme.plaquages)
	var plaquages_visibles := 0
	for joueur: Variant in lineup:
		if joueur is Dictionary: plaquages_visibles += int(feuille.joueurs.get(str(joueur.id), {}).get("plaquages", 0))
	check(plaquages_visibles >= 5 or int(somme.plaquages) < 10, "Plaquages des quinze titulaires de la feuille : %d" % plaquages_visibles)
	check(between.xv.is_visible_in_tree() and between.fil.is_visible_in_tree(), "Mon XV et le dernier fait affichés ensemble")
	# XV adverse (lien de Mon XV) : le même tableau pour le XV adverse du dernier fait montré, puis retour à Mon XV.
	var adverse: Array = direct.get("adversaire", [])
	between.find_child("MatchBetweenTabOpponent", true, false).pressed.emit()
	await settle(2)
	var lignes_adverses: Array = between.xv.get_children().filter(func(n: Node): return str(n.name).begins_with("MatchBetweenOpponent"))
	var noms_adverses: Array = lignes_adverses.map(func(b: Control): return b.find_children("*", "Label", true, false).map(func(l: Label): return l.text))
	check(adverse.size() == 15 and lignes_adverses.size() == 15 and range(15).all(func(k: int): return adverse[k] == null or str(adverse[k].nom) in noms_adverses[k]), "XV adverse : nom et note de chaque joueur (%d lignes)" % lignes_adverses.size())
	var somme_adverse := {"plaquages": 0, "metres": 0}
	for fj: Dictionary in feuille.get("joueurs", {}).values():
		if int(fj.camp) == 1 - camp_xv:
			for cle: String in somme_adverse: somme_adverse[cle] += int(fj.get(cle, 0))
	var total_adverse: Node = between.pied_xv.find_child("MatchBetweenTeamTotal", true, false)
	check(total_adverse != null and colonne.call(total_adverse).has(str(somme_adverse.plaquages)) and int(feuille.equipes[1 - camp_xv].plaquages) == int(somme_adverse.plaquages), "Ligne Équipe du XV adverse : plaquages %d = somme des joueurs" % somme_adverse.plaquages)
	between.find_child("MatchBetweenTabOpponent", true, false).pressed.emit()
	await settle(2)
	check(between.xv.get_children().filter(func(n: Node): return n is Button and str(n.name).begins_with("MatchBetweenPlayer")).size() == 15, "Retour à Mon XV")
	# Réglages : vitesse de l'horloge et temps forts montrés, à la place des chiffres clés (jamais une fenêtre).
	view.find_child("MatchBetweenSettings", true, false).pressed.emit()
	await settle(4)
	check(between.panneau_parametres.is_visible_in_tree() and between.grille_niveaux.get_child_count() == 6 and not between.find_child("MatchBetweenDuel", true, false).is_visible_in_tree(), "Réglages : le panneau prend la colonne de droite avec les six niveaux de temps forts")
	between.montrer_droite("chiffres")
	var rangs_xv: Array = between.xv.get_children().filter(func(n: Node): return n is Button)
	(rangs_xv[9] as Button).pressed.emit()
	await settle(4)
	check(view.equipe.visible and view.equipe.poste_choisi == 9, "Un joueur de Mon XV ouvre la fenêtre Équipe sur lui (poste %d)" % view.equipe.poste_choisi)
	view.equipe.fermer()
	await settle(2)
	# Le nom d'un joueur ouvre sa fiche sur l'entracte (match en pause), Échap revient à l'entracte sans casser le match.
	var nom_lien := (rangs_xv[2] as Node).find_children("MatchBetweenPlayerName_*", "Button", true, false)
	if not nom_lien.is_empty():
		(nom_lien[0] as Button).pressed.emit()
		await settle(6)
		var fiche: Variant = between.get("fiche_match")
		check(fiche is Control and is_instance_valid(fiche) and (fiche as Control).is_visible_in_tree() and between.find_child("ImmersivePlayerFull", true, false) != null and str(lineup[2].name) in str((between.find_child("ImmersivePlayerFull", true, false) as Control).find_children("*", "Label", true, false).map(func(l: Label): return l.text)), "Nom du 3 : sa fiche complète s'ouvre sur l'entracte")
		check(app.model.live.paused, "Fiche ouverte : le match est en pause")
		var echap := InputEventKey.new()
		echap.keycode = KEY_ESCAPE
		echap.pressed = true
		between._input(echap)
		await settle(4)
		check(between.get("fiche_match") == null and between.is_visible_in_tree() and surface() == view, "Échap referme la fiche et revient à l'entracte, le match continue d'exister")
	var menu: MenuButton = view.find_child("MatchBetweenMore", true, false)
	check(menu != null and menu.get_popup().get_item_text(0) == "Statistiques", "Tous les chiffres du moteur restent dans le tiroir Statistiques (menu Plus)")
	await layout(view, Vector2i(1280, 720))
	await layout(view, Vector2i(1920, 1080))
	await layout(view, Vector2i(2560, 1440))
	# Carrière Monde : la vraie journée en direct arrive avec chaque minute et remplacerait la journée injectée ;
	# le match est mis en pause le temps des contrôles sur données fictives.
	var relancer := await suspendre_direct()
	await journee_injectee(view, direct)
	await consignes_fictives(view, direct)
	if relancer: await command("pause", {"paused": false})
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	print("TERRAIN2D ", JSON.stringify({"faits": ecarts.faits, "deplacement": deplacement, "ballons": ballons.size(), "minutes": minutes.size()}))

## Journée en direct injectée dans l'entracte (classement et multiplex de dix matchs) : en 1280×720 et
## 1920×1080, tout tient dans l'écran avec la marge basse, le multiplex reste sur une rangée et défile.
func journee_injectee(view: Control, direct: Dictionary) -> void:
	var between: Control = view.regie.between
	var journee := _journee_test(52, 14)
	for k in range(6, 10):
		journee.matchs.append({"id": "m%d" % k, "home": {"id": 901 + k * 2, "abbr": "C%02d" % (1 + k * 2), "nom": "Club %d" % (1 + k * 2), "score": 3 * k, "essais": 1},
			"away": {"id": 902 + k * 2, "abbr": "C%02d" % (2 + k * 2), "nom": "Club %d" % (2 + k * 2), "score": 6, "essais": 0}, "minute": 52, "fini": false})
	var avec: Dictionary = direct.duplicate()
	avec["journee"] = journee
	# Championnat à bonus : la tuile Bonus partage la bande du bas avec Gabi et le multiplex (elle
	# élargissait la page au-delà de l'écran en 1280×720, colonne de droite coupée, constaté au match filmé).
	avec["bonus"] = {"regle": "3 essais d'écart · défaite de 7 pts ou moins", "offensif": {"texte": "Bonus offensif à 3 essais", "manque": 2}, "defensif": {"texte": "Défensif : défaite de 7 pts ou moins", "statut": "tenu"}}
	between.update_frame(app.model, app.model.live, avec, func(_c: Dictionary): pass)
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = taille
		root.content_scale_size = taille
		await settle(12)
		# Le direct réel (sans journée) peut avoir été rafraîchi pendant l'attente : on réinjecte la journée.
		between.update_frame(app.model, app.model.live, avec, func(_c: Dictionary): pass)
		# Autres matchs et classement en direct : panneau de la colonne de droite (menu Plus), jamais une fenêtre.
		between.montrer_droite("journee")
		await settle(3)
		var label := "Entracte avec la journée %d×%d" % [taille.x, taille.y]
		var ecran := Rect2(Vector2.ZERO, Vector2(taille))
		check(between.classement_tuile.is_visible_in_tree() and between.multiplex.is_visible_in_tree() and _cartes_multiplex(between).size() == 10, label + " : classement et multiplex de dix matchs (%d cartes ; classement %s, multiplex %s)" % [_cartes_multiplex(between).size(), between.classement_tuile.is_visible_in_tree(), between.multiplex.is_visible_in_tree()])
		_pas_coupe(between, label)
		await _tient(view, between, label, ecran)
		between.montrer_droite("journee")
		await settle(3)
		check(between.multiplex_cartes.size.x > between.multiplex_defile.size.x + 1.0, label + " : dix matchs, la rangée dépasse et défile (%d px dans %d)" % [int(between.multiplex_cartes.size.x), int(between.multiplex_defile.size.x)])
		# La dernière carte visible n'est plus coupée net : fondu et « › » au bord droit, retirés au bout de la rangée.
		var plus: Label = between.find_child("MatchBetweenMultiplexMore", true, false)
		check(between.multiplex_fondu.is_visible_in_tree() and plus != null and plus.is_visible_in_tree() and plus.text == "›", label + " : dix matchs, fondu et « › » au bord droit du multiplex")
		between.multiplex_defile.scroll_horizontal = int(between.multiplex_cartes.size.x)
		await settle(3)
		check(not between.multiplex_fondu.visible, label + " : au bout de la rangée, plus de fondu (défilement %d)" % between.multiplex_defile.scroll_horizontal)
		between.multiplex_defile.scroll_horizontal = 0
		await settle(3)
		check(between.multiplex_fondu.visible, label + " : revenu au début, le fondu revient")
		check(between.adjoint_cadre.is_visible_in_tree() and between.adjoint_cadre.size.x >= between.size.x * 0.9, label + " : Gabi garde sa largeur (%d px)" % int(between.adjoint_cadre.size.x))
		if proof != "" and OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES") != "": await _capture(label.replace(" ", "-"), "journee")
		between.montrer_droite("chiffres")
	# Deux matchs seulement : la rangée tient, pas de fondu ni de « › ».
	var courte := _journee_test(52, 14)
	courte["matchs"] = (courte["matchs"] as Array).slice(0, 2)
	var avec_courte: Dictionary = direct.duplicate()
	avec_courte["journee"] = courte
	between.update_frame(app.model, app.model.live, avec_courte, func(_c: Dictionary): pass)
	await settle(6)
	between.update_frame(app.model, app.model.live, avec_courte, func(_c: Dictionary): pass)
	between.montrer_droite("journee")
	await settle(3)
	check(_cartes_multiplex(between).size() == 2 and not between.multiplex_deborde() and not between.multiplex_fondu.visible, "Entracte avec deux matchs : la rangée tient, pas de fondu (%d cartes, rangée %d px dans %d)" % [_cartes_multiplex(between).size(), int(between.multiplex_cartes.size.x), int(between.multiplex_defile.size.x)])
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await settle(4)

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
	check(between.fil.is_visible_in_tree() and between.fil.get_child_count() >= 1, "Pilotage : les faits marquants restent à l'écran")
	check(between.find_child("MatchBetweenConsignes", true, false) == null and between.find_children("Consigne_*", "BoxContainer", true, false).is_empty(), "Pilotage : aucune consigne sur l'écran 2D (elles sont dans la fenêtre Équipe)")
	# Mon XV : l'état après la causerie, coloré selon son sens.
	between.choisir_vue_xv("tableau")
	await settle(2)
	var cases: Array = between.xv.get_children().filter(func(n: Node): return n is Button and str(n.name).begins_with("MatchBetweenPlayer"))
	var attendus := [["Galvanisé", W.VERT], ["Indifférent", Between.DOUX], ["Vexé", W.ALERTE]]
	for k in mini(3, cases.size()):
		if not lineup[k] is Dictionary: continue
		var etat: Label = (cases[k] as Node).find_child("MatchBetweenPlayerState", true, false)
		check(etat != null and etat.text == attendus[k][0] and etat.get_theme_color("font_color").is_equal_approx(attendus[k][1]) and etat.get_theme_font_size("font_size") >= 12, "Mon XV : état « %s » du %d" % [attendus[k][0], k + 1])
	check((cases[4] as Node).find_child("MatchBetweenPlayerState", true, false) == null, "Mon XV : pas d'état sans causerie reçue")
	var ligne_xv: Node = between.xv.find_child("MatchBetweenPlayer3", true, false)
	var etat_xv: Label = ligne_xv.find_child("MatchBetweenPlayerState", true, false) if ligne_xv != null else null
	check(etat_xv != null and etat_xv.text == "Vexé", "Mon XV (Tableau) : état du 3")
	# Mise en page avec le pilotage (rien ne doit être coupé en 720p comme en 1440p).
	await layout(view, Vector2i(1280, 720))
	await layout(view, Vector2i(2560, 1440))
	between.update_frame(app.model, app.model.live, direct, func(_c: Dictionary): pass)
	await settle(2)
	check(between.fil.is_visible_in_tree(), "Sans pilotage : le dernier fait reste à l'écran")

## Carrière Monde réelle : un clic sur un cran de la fenêtre Équipe (ouvert, le match se met en pause) envoie
## la consigne au vrai moteur, qui la projette dans `live.pilotage` ; l'écran 2D n'a pas de consignes et garde ses faits marquants.
func consigne_reelle(regie: Node) -> void:
	var between: Control = regie.between
	var p: Variant = app.model.live.get("pilotage")
	check(p is Dictionary, "Carrière Monde : le moteur projette le pilotage du match (live.pilotage)")
	if not p is Dictionary: return
	check(between.fil.is_visible_in_tree() and between.fil.get_child_count() >= 1, "Faits marquants à l'écran 2D pendant le match du manager")
	var vue: Control = regie.view
	vue.ouvrir_equipe("consignes")
	await settle(4)
	var actuel := str(p.get("consignes", {}).get("rythme", ""))
	var voulu := "lent" if actuel == "rapide" else "rapide"
	var bouton: Button = vue.equipe.find_child("Consigne_rythme_" + voulu, true, false)
	check(bouton != null, "Consignes (fenêtre Équipe) : cran « %s » du rythme" % voulu)
	# Fermeture sans « Valider et reprendre » : fermer() relance le match quelques images plus tard (la
	# fenêtre envoie la reprise dans son _process), et la régie enchaînait alors un temps fort qui masquait
	# l'écran intermédiaire pendant les mesures du mode multiplex. Le test garde le match en pause.
	if bouton == null:
		vue.equipe.fermer(false)
		return
	var pauses: int = regie.suivi.size()
	bouton.pressed.emit()
	var recu: bool = await until(func() -> bool: return app.model.live.get("pilotage") is Dictionary and str(app.model.live.pilotage.get("consignes", {}).get("rythme", "")) == voulu, 30000)
	check(recu, "Consignes : le moteur applique « %s » (%s)" % [voulu, str(app.model.live.get("pilotage", {}).get("consignes", {}) if app.model.live.get("pilotage") is Dictionary else null)])
	check(regie.suivi.slice(pauses).any(func(e: Dictionary) -> bool: return e.evenement == "consigne" and e.get("valeur") == voulu), "Consignes : envoyée par la régie")
	if vue.equipe.visible: vue.equipe.fermer(false)

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
	# Un temps fort lancé avant la pause va à son terme (rien ne démarre pendant la pause : la régie ne
	# demande pas de minute au moteur match en pause) : attendre le retour à l'écran intermédiaire.
	var revenu: bool = await until(func() -> bool: return regie.etat == regie.INTER and between.visible and regie._retenu.is_empty(), 90000)
	check(revenu, "Multiplex : retour à l'écran intermédiaire après la consigne (état %s, visible %s)" % [str(regie.etat), str(between.visible)])
	await settle(4)
	# Les mesures qui suivent supposent le match arrêté : rien ne doit l'avoir relancé (fenêtre Équipe fermée sans reprise).
	check(bool(app.model.live.get("paused", false)) and not bool(view.equipe._veut_reprise),"Multiplex : match toujours en pause pour les mesures (pause %s)" % str(app.model.live.get("paused", false)))
	var direct: Dictionary = regie._live_inter.get("direct", app.model.live.direct)
	var journee: Variant = direct.get("journee")
	check(journee is Dictionary, "Carrière world-champ : le moteur fournit la journée en direct")
	if journee is Dictionary:
		var matchs: Array = journee.get("matchs", [])
		var classement: Array = journee.get("classement", [])
		between.montrer_droite("journee")
		await settle(3)
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
		between.montrer_droite("chiffres")
		print("MULTIPLEX_REEL ", JSON.stringify({"minute": journee.get("minute"), "matchs": matchs.size(), "clubs": classement.size(), "nous": nous[0].rang if nous.size() == 1 else null}))
	await _mise_en_page_journee(view, "reel")
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]: await layout(view, taille)
	var relancer := await suspendre_direct()
	await journee_fictive(view, direct)
	if relancer: await command("pause", {"paused": false})

## Met le direct en pause (s'il tourne) pour des contrôles sur une journée injectée ; vrai s'il faudra le relancer.
func suspendre_direct() -> bool:
	await until(func(): return not app.waiting, 30000)
	if not (app.model.get("live") is Dictionary) or app.model.live.get("paused", false) or app.model.live.get("finished", false): return false
	await command("pause", {"paused": true})
	await settle(4)
	return true

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
	# Autres matchs et classement : panneau de la colonne de droite (menu Plus).
	between.montrer_droite("journee")
	await settle(4)
	# Classement : notre voisinage (5e à 11e, nous 8e au milieu) ; rien de plus, sans défilement.
	var lignes := _lignes_classement(between)
	var rangs: Array = lignes.map(func(n: Node): return int(n.get_meta("rang")) if n.has_meta("rang") else -1)
	# Sept lignes en 720p (± 3) ; neuf sinon (le leader, « … », notre voisinage) : le panneau a toute la colonne de droite.
	var attendus: Array = [5, 6, 7, 8, 9, 10, 11] if between._densite < 0.6 else [1, -1, 5, 6, 7, 8, 9, 10, 11]
	check(between.classement_tuile.is_visible_in_tree() and rangs == attendus, "Classement fictif : notre voisinage, nous au milieu " + str(rangs))
	# Règle de sélection, indépendante de la fenêtre : 1280×720 (sept lignes) et plus grand (neuf).
	var tableau: Array = _journee_test(52, 14).classement
	check(between.lignes_classement(tableau, 7) == [4, 5, 6, 7, 8, 9, 10] and between.lignes_classement(tableau, 5) == [5, 6, 7, 8, 9] and between.lignes_classement(tableau, 9) == [0, -1, 4, 5, 6, 7, 8, 9, 10] and between.lignes_classement(tableau.slice(0, 9), 9) == range(9), "Classement : lignes choisies (voisinage, leader, tableau court entier)")
	check(between.classement_tuile.find_children("*", "ScrollContainer", true, false).is_empty(), "Classement : pas de défilement interne")
	var par_rang := {}
	for n: Node in lignes:
		if n.has_meta("rang"): par_rang[int(n.get_meta("rang"))] = n
	var texte := func(ligne: Node, nom: String) -> String: return (ligne.find_child(nom, true, false) as Label).text if ligne.find_child(nom, true, false) != null else ""
	check(range(1, 12).filter(func(r: int): return par_rang.has(r)).all(func(r: int): return texte.call(par_rang[r], "Points") == str(40 - r * 2) and texte.call(par_rang[r], "Rang") == str(r)), "Classement fictif : rangs et points du moteur")
	var badges := func(r: int) -> Array: return ["BO", "BD"].filter(func(b: String): return par_rang.has(r) and par_rang[r].find_child("Badge" + b, true, false) != null)
	# Le leader (BO) n'est montré que dans le classement à neuf lignes (voisinage seul en sept lignes, 19/11/2026).
	var leader_ok: bool = badges.call(1) == ["BO"] if par_rang.has(1) else true
	check(leader_ok and badges.call(8) == ["BD"] and badges.call(10) == ["BO", "BD"] and badges.call(5).is_empty(), "Classement fictif : badges BO/BD (%s, %s, %s, %s)" % [badges.call(1), badges.call(8), badges.call(10), badges.call(5)])
	var nous: Control = _ligne_nous(between)
	var style: StyleBoxFlat = nous.get_theme_stylebox("panel") if nous != null else null
	# Charte finale (20/11/2026) : notre ligne est la ligne choisie, fond SELECTION en case de 6 px (plus de liseré).
	check(nous != null and int(nous.get_meta("rang")) == 8 and style != null and style.bg_color.is_equal_approx(preload("res://ui/charte.gd").SELECTION) and style.corner_radius_top_left == preload("res://ui/charte.gd").RAYON_PETIT and texte.call(nous, "Club") == "NOUS", "Classement fictif : notre club surligné")
	check(nous != null and int(nous.find_child("Evolution", true, false).delta) == 2 and int(par_rang[9].find_child("Evolution", true, false).delta) == -1 and int(par_rang[5].find_child("Evolution", true, false).delta) == 0, "Classement fictif : flèches de l'évolution")
	var teinte_nous: Variant = S_couleur(app.model.get("club", {}))
	check(nous != null and (teinte_nous == null or (nous.find_child("Couleur", true, false).teinte as Color).is_equal_approx(teinte_nous)) and (par_rang[5].find_child("Couleur", true, false).teinte as Color).is_equal_approx(between.FAIBLE), "Classement fictif : pastille aux couleurs du club, neutre sinon")
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
		check(changes == [false, false, true, false, false, false] and (cartes[2].get_theme_stylebox("panel") as StyleBoxFlat).border_width_left > 0 and (cartes[2].get_theme_stylebox("panel") as StyleBoxFlat).border_width_top == 0 and (cartes[1].get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 0, "Multiplex fictif : filet gauche vert (jamais un cadre complet) sur le score qui a changé " + str(changes))
	check(between.fil.is_visible_in_tree() and between.fil.get_child_count() >= 1, "Faits marquants visibles avec le classement")
	await _mise_en_page_journee(view, "fictif")
	# Hors phase de ligue : classement vide, multiplex seul.
	var sans_table: Dictionary = direct.duplicate()
	var j: Dictionary = _journee_test(60, 19)
	j["classement"] = []
	sans_table["journee"] = j
	between.update_frame(app.model, app.model.live, sans_table, func(_c: Dictionary): pass)
	between.montrer_droite("journee")
	await settle(2)
	check(not between.classement_tuile.visible and between.multiplex.is_visible_in_tree(), "Hors phase de ligue : classement masqué, multiplex montré")
	# Sans journée (match délégué, ancienne carrière) : les deux tuiles masquées, sans message.
	var sans: Dictionary = direct.duplicate()
	sans["journee"] = null
	between.update_frame(app.model, app.model.live, sans, func(_c: Dictionary): pass)
	await settle(2)
	check(not between.classement_tuile.visible and not between.multiplex.visible and between.fil.is_visible_in_tree(), "Sans journée : classement et multiplex masqués")
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
		await _tient(view, between, label, ecran)
		between.montrer_droite("journee")
		await settle(3)
		for tuile: Control in [between.classement_tuile, between.multiplex]:
			if tuile.visible: check(tuile.is_visible_in_tree() and inside(ecran, tuile.get_global_rect()) and tuile.size.y >= tuile.get_combined_minimum_size().y - 1.0, label + " : " + str(tuile.name) + " entier")
		if between.classement_tuile.visible:
			var lignes := _lignes_classement(between)
			check(lignes.size() >= mini(5, between.journee_vue.classement.size()) and lignes.all(func(l: Control): return inside(between.classement_tuile.get_global_rect(), l.get_global_rect())), label + " : lignes du classement dans la tuile (%d)" % lignes.size())
		# Aucun texte tronqué : sigles, rangs, points, scores et minutes entiers.
		for tuile: Control in [between.classement_tuile, between.multiplex]:
			if not tuile.visible: continue
			for etiquette: Label in tuile.find_children("*", "Label", true, false):
				if not etiquette.is_visible_in_tree() or etiquette.text.is_empty(): continue
				var police: Font = etiquette.get_theme_font("font")
				var largeur := police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, etiquette.get_theme_font_size("font_size")).x
				check(largeur <= etiquette.size.x + 1.0, label + " : « %s » entier (%d sur %d px)" % [etiquette.text, int(largeur), int(etiquette.size.x)])
				check(etiquette.get_theme_font_size("font_size") >= 12, label + " : « %s » lisible" % etiquette.text)
		if between.classement_tuile.visible: check(between.fil.is_visible_in_tree() and between.fil.get_child_count() >= 1 and inside(ecran, between.fil.get_global_rect()), label + " : dernier fait visible")
		if DisplayServer.get_name() != "headless" and OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES") != "":
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image != null:
				var chemin := OS.get_environment("CD_MATCH_TEMPS_FORTS_CAPTURES").path_join("ecran-2d-multiplex-%s-%dx%d.png" % [variante, taille.x, taille.y])
				print("CAPTURE ", chemin, " ", image.get_size(), " ", image.save_png(chemin))
		between.montrer_droite("chiffres")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await settle(4)
