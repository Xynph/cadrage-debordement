extends SceneTree
## Bouton « Cris » du direct (idée FM27 n° 34 ; menu déroulant comme dans FM, choix de Léo du 24/11/2026) dans un vrai
## match Monde, à vitesse maximale : un bouton dans la bande des commandes (à côté d'Équipe, Consignes, Réglages, Plus),
## un clic ouvre le menu juste dessous (bouton allumé tant qu'il est ouvert, fond anthracite satiné), Échap ou un clic à
## côté le ferment. Ses lignes (icône + mot) partent tout de suite au moteur (aucun bouton Confirmer) : cri d'équipe en
## cours, ajustement allumé puis éteint, cri à un joueur (sous-liste) dont la réaction ne se voit qu'après coup
## (▲ / ▼, jamais de chiffre), permutation des ailes en attente du prochain arrêt de jeu (« ⧗ ») puis appliquée.
## Vérificateur du 24/11 : taille du terrain 2D (80 %, 4 px) et banc entier avec une bulle de Gabi, en 1920 et 2560 ; menu
## et sous-liste « À un joueur » jamais recréés, cartes Mon XV mises à jour en place pendant 2 minutes de match.
## godot-cris-banc.cjs prépare la carrière ; captures final-*.png dans CD_PLANCHE_DIRECT_2D.
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

func capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dossier.path_join(nom + ".png"))

func vue_2d(view: Control) -> bool:
	return view.regie != null and view.regie.etat == view.regie.INTER and view.regie.between.is_visible_in_tree() and view.regie.between._journee_montree() and not view.regie.between.panneaux_direct.is_empty() and view.regie.between.panneaux_direct[0].is_visible_in_tree()

func live() -> Dictionary:
	return app.model.get("live", {}) if app.model.get("live") is Dictionary else {}

func pilotage() -> Dictionary:
	return live().get("pilotage", {}) if live().get("pilotage") is Dictionary else {}

func ailes() -> Dictionary:
	var a: Variant = pilotage().get("arrets")
	return a.get("ailes", {}) if a is Dictionary and a.get("ailes") is Dictionary else {}

func taille(t: Vector2i) -> void:
	root.size = t
	root.content_scale_size = t
	await settle(30)

## Bouton visible du direct (bande des commandes, menu « Cris », sous-liste) : on le retrouve par son nom.
func bouton(_between: Control, nom: String) -> Button:
	var racine: Node = surface() if surface() != null else _between
	for n: Node in racine.find_children(nom, "Button", true, false):
		if (n as Control).is_visible_in_tree() and not n.is_queued_for_deletion(): return n
	return null

func banc() -> Node:
	return surface().regie.between.get_node_or_null("MatchFmBanc") if surface() != null and surface().regie != null else null

func deroulant() -> Control:
	return surface().regie.between.find_child("FmBancDeroulant", true, false) as Control if surface() != null and surface().regie != null else null

## Ouvre le menu « Cris » d'un clic sur son bouton (s'il est fermé).
func ouvrir_menu() -> void:
	if deroulant() != null and deroulant().is_visible_in_tree(): return
	var b := bouton(null, "MatchBetweenShouts")
	if b != null: b.pressed.emit()
	await settle(8)

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
	if live().get("paused", false): await command("pause", {"paused": false})
	# Vitesse maximale jusqu'au milieu de la 1re mi-temps (jamais en temps réel dans les tests), en petite taille.
	Engine.time_scale = 16.0
	await taille(Vector2i(960, 540))
	var depart := Time.get_ticks_msec()
	while Time.get_ticks_msec() - depart < 600000 and int(live().get("minute", 0)) < 22 and not live().get("finished", false):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	print("CRIS_BANC minute %d atteinte en %d s" % [int(live().get("minute", 0)), (Time.get_ticks_msec() - depart) / 1000])
	await taille(Vector2i(1920, 1080))
	check(await until(func(): return surface() != null and vue_2d(surface()), 240000), "Écran 2D du direct")
	Engine.time_scale = 1.0
	# Match en pause sur l'écran 2D pendant les clics et les captures (un temps fort 3D masquerait la barre) ; les cris
	# et la file marchent aussi match lancé (le ballon reste vivant : la permutation attend le prochain arrêt).
	await command("pause", {"paused": true})
	check(await until(func(): return surface() != null and vue_2d(surface()), 60000), "Écran 2D du direct, en pause")
	view = surface()
	var between: Control = view.regie.between
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
	# Plus de barre de ronds : un bouton « Cris » dans la bande des commandes, à côté de ses voisins, menu fermé.
	check(view.find_children("FmBancBarre", "", true, false).is_empty() and view.find_children("FmBancBandeau", "", true, false).is_empty(), "plus de barre du banc (options A et B retirées)")
	var b_banc := bouton(between, "MatchBetweenShouts")
	var consignes := bouton(between, "MatchBetweenConsignes")
	check(b_banc != null and consignes != null and b_banc.get_parent() == consignes.get_parent() and b_banc.get_index() == consignes.get_index() - 1, "bouton « Cris » dans la bande des commandes, juste avant Consignes")
	check(b_banc != null and b_banc.text == "Cris" and consignes != null and b_banc.get_theme_font_size("font_size") == consignes.get_theme_font_size("font_size"), "bouton « Cris » du même style que ses voisins")
	check(b_banc != null and ecran.encloses(b_banc.get_global_rect()), "bouton « Cris » dans l'écran")
	check(deroulant() == null, "menu fermé au départ")
	check(between.get_children().filter(func(n: Node): return n.has_method("basculer_menu")).size() == 1, "un seul banc posé sur l'écran")
	# Taille du terrain 2D et banc entier DANS LE VRAI MATCH (pas une maquette), menu fermé.
	await tailles_vrai_match()
	view = surface()
	between = view.regie.between
	# Menu « Cris » : juste sous le bouton, bouton allumé, anthracite satiné ; captures 1920 et 2560.
	await captures_menu()
	await ouvrir_menu()
	var menu := deroulant()
	check(menu != null and menu.is_visible_in_tree(), "menu « Cris » ouvert d'un clic")
	for id: String in ["encourager", "exiger", "calmer", "defense", "toutDonner"]: check(bouton(between, "FmCri_" + id) != null, "ligne cri d'équipe " + id)
	check(bouton(between, "FmBancJoueur") != null, "ligne « À un joueur »")
	check(menu != null and menu.find_children("FmAjust_*", "Button", true, false).size() == 13, "douze ajustements + Permuter les ailes")
	if menu != null:
		for n: Node in menu.find_children("Fm*", "Button", true, false):
			var mots := n.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
			check(not mots.is_empty() and not str(mots[0]).is_empty(), "ligne %s : icône + mot" % n.name)
			for m: String in mots: check(not (m.contains("%") or m.contains("+")), "ligne %s : aucun effet chiffré (%s)" % [n.name, m])
	# Cri d'équipe : un clic, cri en cours dans le moteur ; la ligne garde son nœud et s'allume.
	var encourager := bouton(between, "FmCri_encourager")
	var id_ligne := encourager.get_instance_id() if encourager != null else 0
	if encourager != null:
		encourager.pressed.emit()
		await wait_command()
		await settle(6)
		var actif: Variant = pilotage().get("cris", {}).get("actif")
		check(actif is Dictionary and str(actif.get("id", "")) == "encourager", "cri d'équipe pris par le moteur")
		var apres := bouton(between, "FmCri_encourager")
		check(apres != null and apres.get_instance_id() == id_ligne and bool(apres.get_meta("allume", false)), "ligne du cri allumée, mise à jour en place")
		check(deroulant() != null and deroulant().get_instance_id() == menu.get_instance_id(), "le menu reste ouvert après un clic")
	# Ajustement : un clic l'allume (commande partie), un second le rééteint.
	var pied := bouton(between, "FmAjust_pied")
	if pied != null:
		pied.pressed.emit()
		await wait_command()
		await settle(6)
		check(bool(bouton(between, "FmAjust_pied").get_meta("allume", false)), "ajustement « Jouer au pied » allumé d'un clic")
		bouton(between, "FmAjust_pied").pressed.emit()
		await wait_command()
		await settle(6)
		check(not bool(bouton(between, "FmAjust_pied").get_meta("allume", true)), "ajustement rééteint d'un second clic")
	# Cri à un joueur : sous-liste à côté du menu, quinze lignes, trois cris par joueur ; la réaction se voit après coup.
	var joueur := bouton(between, "FmBancJoueur")
	if joueur != null: joueur.pressed.emit()
	await settle(10)
	var fenetre := between.find_child("FmBancMenuPanneau", true, false) as Control
	check(fenetre != null, "sous-liste « À un joueur » ouverte")
	check(between.find_children("FmCriJoueur_*_bravo", "Button", true, false).size() == 15, "quinze joueurs, un rond par cri")
	var lineup: Array = live().get("lineup", []) if live().get("lineup") is Array else []
	var id10 := str(lineup[9].get("id", "")) if lineup.size() > 9 and lineup[9] is Dictionary else ""
	var cri := bouton(between, "FmCriJoueur_10_niveau")
	check(cri != null and not id10.is_empty(), "cri « Hausse le niveau » au n° 10")
	if cri != null:
		cri.pressed.emit()
		await wait_command()
		await settle(12)
		var vu: Variant = pilotage().get("cris", {}).get("individuels", {}).get("joueurs", {}).get(id10)
		check(vu is Dictionary and int(vu.get("sens", 0)) != 0, "le cri au joueur est pris par le moteur (bien ou mal)")
		var ligne := between.find_child("FmCriJoueur_10", true, false)
		var fleche := ligne.find_child("FmCriReaction", true, false) as Label if ligne != null else null
		check(fleche != null and fleche.text in ["▲", "▼"], "réaction affichée après coup (▲ / ▼)")
		for l: Node in (ligne.find_children("*", "Label", true, false) if ligne != null else []):
			check(not ((l as Label).text.contains("+") or (l as Label).text.contains("%")), "aucun effet chiffré : " + (l as Label).text)
	check(view.find_children("*Confirmer*", "", true, false).is_empty() and view.find_children("*Valider*", "", true, false).is_empty(), "aucun bouton Confirmer")
	# Un 2e cri au n° 2 pour la capture.
	var bravo := bouton(between, "FmCriJoueur_2_bravo")
	if bravo != null:
		bravo.pressed.emit()
		await wait_command()
	await capture_tailles(between)
	# Menu et sous-liste ouverts, liste descendue, 2 minutes de match à vitesse maximale : jamais recréés, toujours au
	# même endroit ; les cartes de Mon XV gardent leurs nœuds (mises à jour en place).
	await liste_en_place()
	view = surface()
	between = view.regie.between
	# ✕ ferme la sous-liste (le menu reste) ; Échap ferme tout ; un clic à côté aussi.
	var fermer := bouton(between, "FmBancMenuFermer")
	if fermer != null: fermer.pressed.emit()
	await settle(10)
	check(between.find_child("FmBancMenuPanneau", true, false) == null and deroulant() != null, "✕ ferme la sous-liste, le menu reste")
	var ligne_j := bouton(between, "FmBancJoueur")
	check(ligne_j != null and not bool(ligne_j.get_meta("ouvert", true)), "sous-liste fermée : la ligne « À un joueur » s'éteint")
	load("res://ui/petite_fenetre.gd").fermer_derniere(self)
	await settle(8)
	check(deroulant() == null and not bool(bouton(between, "MatchBetweenShouts").get_meta("ouvert", true)), "Échap ferme le menu, le bouton s'éteint")
	await ouvrir_menu()
	check(deroulant() != null, "menu rouvert d'un clic sur « Cris »")
	var calque: Control = deroulant().get_parent() as Control if deroulant() != null else null
	var calque_pose := calque != null
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	if calque != null: calque.gui_input.emit(clic)
	await settle(8)
	check(calque_pose and deroulant() == null and not bool(bouton(between, "MatchBetweenShouts").get_meta("ouvert", true)), "un clic à côté ferme le menu")
	# Toutes les petites fenêtres de l'écran 2D en anthracite satiné (choix B de Léo), captures en 1920.
	await fenetres(view, between)
	# Permuter les ailes (ligne du menu) : attente du prochain arrêt (« ⧗ »), puis nos ailiers échangés.
	var g := str(lineup[10].get("id", "")) if lineup.size() > 13 and lineup[10] is Dictionary else ""
	var d := str(lineup[13].get("id", "")) if lineup.size() > 13 and lineup[13] is Dictionary else ""
	await ouvrir_menu()
	var b_ailes := bouton(between, "FmAjust_ailes")
	if b_ailes != null:
		b_ailes.pressed.emit()
		await wait_command()
		await settle(10)
	check(bool(ailes().get("attente", false)) or bool(ailes().get("permutees", false)), "permutation prise par la file du prochain arrêt")
	if bool(ailes().get("attente", false)):
		await capture("final-ailes-1920")
	load("res://ui/petite_fenetre.gd").fermer_derniere(self)
	await settle(6)
	await command("pause", {"paused": false})
	Engine.time_scale = 8.0
	check(await until(func(): return bool(ailes().get("permutees", false)), 180000), "ailes permutées au prochain arrêt de jeu")
	Engine.time_scale = 1.0
	var apres_l: Array = live().get("lineup", []) if live().get("lineup") is Array else []
	check(apres_l.size() > 13 and str(apres_l[10].get("id", "")) == d and str(apres_l[13].get("id", "")) == g, "nos n° 11 et 14 ont échangé leurs côtés")
	finir()

## Menu « Cris » ouvert en 1920 puis 2560 : juste sous le bouton, dans l'écran, bouton allumé, anthracite satiné.
func captures_menu() -> void:
	var ardoise: Color = load("res://ui/contextual/match_menu_joueur.gd").PAL.fond
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await taille(t)
		await until(func(): return surface() != null and vue_2d(surface()), 30000)
		await settle(10)
		await ouvrir_menu()
		await settle(4)
		var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
		var menu := deroulant()
		var b := bouton(null, "MatchBetweenShouts")
		check(menu != null and menu.is_visible_in_tree() and ecran.encloses(menu.get_global_rect()), "%s : menu « Cris » dans l'écran" % str(t))
		if menu != null and b != null:
			var mr := menu.get_global_rect()
			var br := b.get_global_rect()
			check(mr.position.y >= br.end.y and mr.position.y - br.end.y < 24.0 and (absf(mr.position.x - br.position.x) < 2.0 or absf(mr.end.x - br.end.x) < 2.0), "%s : menu juste sous le bouton (%d px)" % [str(t), int(mr.position.y - br.end.y)])
			var st: StyleBox = menu.get_theme_stylebox("panel")
			check(st != null and st.get("bg_color") is Color and (st.get("bg_color") as Color).is_equal_approx(ardoise), "%s : menu en anthracite satiné" % str(t))
		check(b != null and bool(b.get_meta("ouvert", false)), "%s : bouton « Cris » allumé tant que le menu est ouvert" % str(t))
		await capture("final-menu-%d" % t.x)
	await taille(Vector2i(1920, 1080))
	await until(func(): return surface() != null and vue_2d(surface()), 30000)
	await settle(6)

## Menu et sous-liste « À un joueur » ouverts, en 1920 puis 2560 : captures, cadre dans l'écran, noms entiers.
func capture_tailles(between: Control) -> void:
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await taille(t)
		await until(func(): return surface() != null and vue_2d(surface()), 30000)
		await settle(10)
		var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
		var panneau := between.find_child("FmBancMenuPanneau", true, false) as Control
		var menu := deroulant()
		check(panneau != null and panneau.is_visible_in_tree() and ecran.encloses(panneau.get_global_rect()), "%s : sous-liste « À un joueur » dans l'écran" % str(t))
		check(menu != null and menu.is_visible_in_tree() and ecran.encloses(menu.get_global_rect()), "%s : menu « Cris » dans l'écran" % str(t))
		if panneau != null and menu != null:
			var pr := panneau.get_global_rect()
			var mr := menu.get_global_rect()
			check(not pr.intersects(mr) and absf(pr.position.y - mr.position.y) < 2.0, "%s : sous-liste à côté du menu, alignée sur son haut" % str(t))
			for etiquette: Node in panneau.find_children("FmCriNom", "Label", true, false):
				var l := etiquette as Label
				var large := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
				check(large <= l.custom_minimum_size.x + 1.0 and not l.clip_text, "%s : nom « %s » entier (%d / %d px)" % [str(t), l.text, int(large), int(l.custom_minimum_size.x)])
			var lignes := between.find_child("FmCriJoueur_10", true, false) as Control
			check(lignes != null and lignes.get_global_rect().end.x <= pr.end.x + 1.0, "%s : colonnes de la liste dans sa largeur" % str(t))
		var rond := bouton(between, "FmBancJoueur")
		check(rond != null and bool(rond.get_meta("ouvert", false)), "%s : ligne « À un joueur » allumée tant que la sous-liste est ouverte" % str(t))
		await capture("final-joueurs-%d" % t.x)
	await taille(Vector2i(1920, 1080))

## Terrain 2D dans un vrai match, 1920 et 2560 : il remplit 80 % de sa tuile, pastilles d'au moins 4 px ; écran entier
## (bande des commandes, Mon XV) ; avec une bulle de Gabi de deux lignes, le banc garde ses 8 remplaçants entiers et les
## événements défilent (vérificateur du 24/11).
func tailles_vrai_match() -> void:
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await taille(t)
		await until(func(): return surface() != null and vue_2d(surface()), 30000)
		await settle(10)
		var between: Control = surface().regie.between
		var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
		var cadre := str(t)
		var terrain: Control = between.terrain
		print("CRIS_BANC taille %s : terrain %d / %d px (%.0f %%), pastilles %.2f px" % [cadre, int(terrain.champ().size.x), int(terrain.size.x), 100.0 * terrain.champ().size.x / maxf(1.0, terrain.size.x), terrain.rayon()])
		check(terrain.champ().size.x >= terrain.size.x * 0.80, cadre + " : le terrain remplit sa tuile (%d sur %d px)" % [int(terrain.champ().size.x), int(terrain.size.x)])
		check(terrain.rayon() >= 4.0 and terrain.rayon() <= terrain.echelle() * 3.0, cadre + " : pastilles d'au moins 4 px (rayon %.2f px)" % terrain.rayon())
		var haut := surface().find_child("MatchTopRow", true, false) as Control
		check(haut == null or ecran.encloses(haut.get_global_rect()), cadre + " : rangée du haut dans l'écran")
		var xv := between.find_child("MatchBetweenSquadBar", true, false) as Control
		check(xv != null and ecran.encloses(xv.get_global_rect()), cadre + " : Mon XV entier dans l'écran")
		await capture("final-ferme-%d" % t.x)
		# Bulle de Gabi de deux lignes (deux consignes d'un même constat).
		var bulles: Node = between.get_node_or_null("MatchBullesAdjoint")
		check(bulles != null, cadre + " : bulles de Gabi posées")
		if bulles == null: continue
		bulles._dessiner([{"cle": "consigne:test", "sorte": "consigne", "axes": ["piedJeu", "rythme"], "raison": "Ils reculent : on les use au pied.",
			"lignes": [{"axe": "piedJeu", "label": "Jeu au pied", "actuelLabel": "Normal", "valeurLabel": "Souvent"}, {"axe": "rythme", "label": "Rythme", "actuelLabel": "Normal", "valeurLabel": "Lent"}]}])
		await settle(12)
		var boite := between.find_child("MatchBetweenAdviceBubbles", true, false) as Control
		check(boite != null and boite.is_visible_in_tree(), cadre + " : bulle de Gabi de deux lignes affichée")
		var defile_banc := between.find_child("MatchBetweenBenchScroll", true, false) as Control
		var zone: Control = between.zone_banc
		check(defile_banc != null and zone != null and defile_banc.size.y + 1.0 >= zone.get_combined_minimum_size().y, cadre + " : le banc garde ses 8 lignes (%d / %d px)" % [int(defile_banc.size.y) if defile_banc else -1, int(zone.get_combined_minimum_size().y) if zone else -1])
		var tuile_banc := between.find_child("MatchBetweenBenchTile", true, false) as Control
		var colonne := between.find_child("MatchBetweenEventsColumn", true, false) as Control
		check(tuile_banc != null and colonne != null and tuile_banc.get_global_rect().end.y <= colonne.get_global_rect().end.y + 1.0 and colonne.get_global_rect().end.y <= xv.get_global_rect().position.y, cadre + " : la tuile Banc tient dans la colonne, au-dessus de Mon XV")
		check(xv != null and ecran.encloses(xv.get_global_rect()), cadre + " : Mon XV toujours entier avec la bulle")
		var noms := (zone.find_children("*", "Label", true, false) if zone != null else []).filter(func(l: Label): return l.is_visible_in_tree() and l.text.contains(" "))
		var dernier: Label = noms[-1] if not noms.is_empty() else null
		check(dernier != null and defile_banc.get_global_rect().grow(1.0).encloses(dernier.get_global_rect()), cadre + " : le dernier remplaçant visible dans la tuile Banc")
		await capture("final-gabi-%d" % t.x)
		bulles.apres_adjoint()
		await settle(6)
	await taille(Vector2i(1920, 1080))
	await until(func(): return surface() != null and vue_2d(surface()), 30000)

## Liste « À un joueur » ouverte, descendue en bas, 2 minutes de match à vitesse maximale : même panneau, toujours
## visible avec l'écran 2D, défilement inchangé ; la carte du n° 10 de Mon XV garde son nœud.
func liste_en_place() -> void:
	var between: Control = surface().regie.between
	var panneau := between.find_child("FmBancMenuPanneau", true, false) as Control
	check(panneau != null, "liste « À un joueur » ouverte avant le match lancé")
	if panneau == null: return
	var defile := panneau.find_child("FmBancMenuDefile", true, false) as ScrollContainer
	defile.scroll_vertical = 100000
	await settle(6)
	var bas := defile.scroll_vertical
	check(bas > 0, "liste descendue (%d px)" % bas)
	var id_panneau := panneau.get_instance_id()
	var id_menu := deroulant().get_instance_id() if deroulant() != null else 0
	var ligne_cri: Node = deroulant().find_child("FmCri_exiger", true, false) if deroulant() != null else null
	var id_ligne := ligne_cri.get_instance_id() if ligne_cri != null else 0
	var menus := 0
	var carte := between.find_child("MatchBetweenPlayer10", true, false)
	var id_carte := carte.get_instance_id() if carte != null else 0
	var joueur_carte := str(carte.get_meta("player_id", "")) if carte != null else ""
	var m0 := int(live().get("minute", 0))
	await command("pause", {"paused": false})
	Engine.time_scale = 16.0
	var images := 0
	var recree := 0
	var cachee := 0
	var bouge := 0
	var cartes := 0
	var depart := Time.get_ticks_msec()
	while int(live().get("minute", 0)) < m0 + 2 and not live().get("finished", false) and Time.get_ticks_msec() - depart < 240000:
		await process_frame
		var v := surface()
		if v == null or not vue_2d(v): continue
		images += 1
		var p := v.regie.between.find_child("FmBancMenuPanneau", true, false) as Control
		if p == null or p.get_instance_id() != id_panneau: recree += 1
		elif not p.is_visible_in_tree(): cachee += 1
		elif defile.scroll_vertical != bas: bouge += 1
		var m := v.regie.between.find_child("FmBancDeroulant", true, false) as Control
		var lc: Node = m.find_child("FmCri_exiger", true, false) if m != null else null
		if m == null or m.get_instance_id() != id_menu or not m.is_visible_in_tree() or lc == null or lc.get_instance_id() != id_ligne: menus += 1
		var c: Node = v.regie.between.find_child("MatchBetweenPlayer10", true, false)
		if c != null and str(c.get_meta("player_id", "")) == joueur_carte and c.get_instance_id() != id_carte: cartes += 1
	# Un temps fort 3D en cours : on le laisse finir (match lancé) avant la pause, sur l'écran 2D.
	await until(func(): return surface() != null and vue_2d(surface()), 120000)
	Engine.time_scale = 1.0
	await command("pause", {"paused": true})
	await until(func(): return surface() != null and vue_2d(surface()), 60000)
	print("CRIS_BANC liste : minutes %d -> %d, %d images 2D" % [m0, int(live().get("minute", 0)), images])
	check(int(live().get("minute", 0)) >= m0 + 2 and images >= 10, "2 minutes de match jouées avec la liste ouverte (%d images)" % images)
	check(recree == 0 and cachee == 0, "liste jamais recréée ni cachée (%d recréée, %d cachée)" % [recree, cachee])
	check(bouge == 0, "liste toujours au même endroit (%d images déplacées)" % bouge)
	check(menus == 0, "menu « Cris » jamais recréé ni caché, ses lignes gardent leurs nœuds (%d images)" % menus)
	check(cartes == 0, "carte Mon XV du n° 10 mise à jour en place (%d recréations)" % cartes)

## Chaque petite fenêtre de l'écran 2D (et la fenêtre Équipe, le menu Plus) : ouverte, fond anthracite satiné, capture.
func fenetres(view: Control, between: Control) -> void:
	var ardoise: Color = load("res://ui/contextual/match_menu_joueur.gd").PAL.fond
	if deroulant() != null: load("res://ui/petite_fenetre.gd").fermer_derniere(self)
	await settle(10)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	var premier := func(racine: Node, motif: String, classe: String = "Control") -> Control:
		for n: Node in racine.find_children(motif, classe, true, false):
			if (n as Control).is_visible_in_tree(): return n
		return null
	var cas := [
		["joueur", "MatchFenetreJoueur", func(): (premier.call(between, "MatchBetweenPlayerName_*", "Button") as Button).pressed.emit()],
		["joueur-carte", "MatchMenuJoueur", func(): (premier.call(between, "MatchBetweenPlayer1", "Button") as Button).pressed.emit()],
		["club", "MatchFenetreClub", func(): (premier.call(between.classement_lignes, "MatchBetweenLiveRow*", "PanelContainer") as Control).gui_input.emit(clic)],
		["match", "MatchFenetreMatch", func(): (premier.call(between.multiplex_cartes, "MatchBetweenMultiplexMatch*", "PanelContainer") as Control).gui_input.emit(clic)],
		["stat", "MatchFenetreStat", func(): (premier.call(between, "MatchBetweenMirrorBar_possession", "Button") as Button).pressed.emit()],
		["fait", "MatchFenetreFait", func():
			var f: Control = premier.call(between, "MatchBetweenEvent*", "PanelContainer")
			if f == null: f = premier.call(between, "MatchBetweenHighlight*", "PanelContainer")
			f.gui_input.emit(clic)],
	]
	for c: Array in cas:
		c[2].call()
		await wait_command()
		await settle(14)
		var en_ardoise := false
		if view.fenetre_ouverte() and view.fenetre_hote.find_child(str(c[1]) + "*", true, false) != null:
			for n: Node in view.fenetre_hote.find_children("*", "Panel", true, false):
				var st: StyleBox = (n as Panel).get_theme_stylebox("panel")
				if st != null and st.get("bg_color") is Color and (st.get("bg_color") as Color).is_equal_approx(ardoise): en_ardoise = true
		check(en_ardoise, "fenêtre %s ouverte, en anthracite satiné" % str(c[0]))
		await capture("final-fenetres-%s-1920" % str(c[0]))
		load("res://ui/petite_fenetre.gd").fermer_derniere(self)
		await settle(12)
		check(not view.fenetre_ouverte(), "fenêtre %s refermée" % str(c[0]))
	# Menu Plus (déroulant) et fenêtre Équipe.
	var plus: MenuButton = between.plus
	plus.show_popup()
	await settle(12)
	var st_plus: StyleBox = plus.get_popup().get_theme_stylebox("panel")
	check(st_plus != null and st_plus.get("bg_color") is Color and (st_plus.get("bg_color") as Color).is_equal_approx(ardoise), "menu Plus en anthracite satiné")
	await capture("final-fenetres-plus-1920")
	plus.get_popup().hide()
	await settle(8)
	view.ouvrir_equipe("composition")
	await settle(30)
	var fond_equipe := view.equipe.find_child("TeamBackdrop", true, false) as ColorRect if is_instance_valid(view.equipe) else null
	check(fond_equipe != null and fond_equipe.color.is_equal_approx(ardoise), "fenêtre Équipe en anthracite satiné")
	await capture("final-fenetres-equipe-1920")
	if is_instance_valid(view.equipe) and view.equipe.visible: view.equipe.fermer(false)
	await settle(20)
	if not live().get("paused", false): await command("pause", {"paused": true})
	await until(func(): return surface() != null and vue_2d(surface()), 30000)

func finir() -> void:
	print("CRIS_BANC %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)

