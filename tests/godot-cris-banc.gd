extends SceneTree
## Barre du banc (idée FM27 n° 34, choix B de Léo du 23/11/2026) dans un vrai match Monde, à vitesse maximale : la barre
## est toujours visible au-dessus du tableau de bord (cinq cris d'équipe, « À un joueur », douze ajustements, « Permuter
## les ailes ») ; un clic part tout de suite au moteur (aucun bouton Confirmer) : cri d'équipe en cours, cri à un
## joueur dont la réaction ne se voit qu'après coup (▲ / ▼, jamais de chiffre), permutation des ailes en attente du
## prochain arrêt de jeu (« ⧗ ») puis appliquée (nos n° 11 et 14 échangés).
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

## Bouton visible de la barre (reconstruite à chaque image du modèle) : on le retrouve par son nom.
func bouton(between: Control, nom: String) -> Button:
	for n: Node in between.find_children(nom, "Button", true, false):
		if (n as Control).is_visible_in_tree() and not n.is_queued_for_deletion(): return n
	return null

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
	var barre := between.find_child("FmBancBarre", true, false) as Control
	check(barre != null and barre.is_visible_in_tree(), "barre du banc toujours visible")
	for id: String in ["encourager", "exiger", "calmer", "defense", "toutDonner"]: check(bouton(between, "FmCri_" + id) != null, "cri d'équipe " + id)
	check(bouton(between, "FmBancJoueur") != null, "rond « À un joueur »")
	check(between.find_children("FmAjust_*", "Button", true, false).size() == 13, "douze ajustements + Permuter les ailes")
	check(bouton(between, "FmAjust_ailes") != null, "rond « Permuter les ailes »")
	check(between.find_children("FmBancCris", "", true, false).is_empty() and between.find_children("FmBancAjustements", "", true, false).is_empty(), "variante A retirée")
	if barre != null: check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0).encloses(barre.get_global_rect()), "barre dans l'écran en 1920")
	# Cri d'équipe : un clic, cri en cours dans le moteur.
	var encourager := bouton(between, "FmCri_encourager")
	if encourager != null:
		encourager.pressed.emit()
		await wait_command()
		var actif: Variant = pilotage().get("cris", {}).get("actif")
		check(actif is Dictionary and str(actif.get("id", "")) == "encourager", "cri d'équipe pris par le moteur")
	# Cri à un joueur : petite fenêtre, quinze lignes, trois cris par joueur ; la réaction se voit après coup.
	var joueur := bouton(between, "FmBancJoueur")
	if joueur != null: joueur.pressed.emit()
	await settle(10)
	var fenetre := between.find_child("FmBancMenuPanneau", true, false) as Control
	check(fenetre != null, "fenêtre « À un joueur » ouverte")
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
	check(between.find_children("*Confirmer*", "", true, false).is_empty() and between.find_children("*Valider*", "", true, false).is_empty(), "aucun bouton Confirmer")
	# Un 2e cri au n° 2 pour la capture.
	var bravo := bouton(between, "FmCriJoueur_2_bravo")
	if bravo != null:
		bravo.pressed.emit()
		await wait_command()
	await capture_tailles(between)
	# Toutes les petites fenêtres de l'écran 2D en anthracite satiné (choix B de Léo), captures en 1920.
	await fenetres(view, between)
	# Fenêtre refermée (✕) ; permuter les ailes : attente du prochain arrêt (« ⧗ »), puis nos ailiers échangés.
	var fermer := bouton(between, "FmBancMenuFermer")
	if fermer != null: fermer.pressed.emit()
	await settle(10)
	check(between.find_child("FmBancMenuPanneau", true, false) == null, "✕ ferme la fenêtre")
	var rond_ferme := bouton(between, "FmBancJoueur")
	check(rond_ferme != null and not bool(rond_ferme.get_meta("ouvert", true)), "liste fermée : le rond s'éteint")
	var g := str(lineup[10].get("id", "")) if lineup.size() > 13 and lineup[10] is Dictionary else ""
	var d := str(lineup[13].get("id", "")) if lineup.size() > 13 and lineup[13] is Dictionary else ""
	var b_ailes := bouton(between, "FmAjust_ailes")
	if b_ailes != null:
		b_ailes.pressed.emit()
		await wait_command()
		await settle(10)
	check(bool(ailes().get("attente", false)) or bool(ailes().get("permutees", false)), "permutation prise par la file du prochain arrêt")
	if bool(ailes().get("attente", false)):
		await capture("final-ailes-1920")
	await command("pause", {"paused": false})
	Engine.time_scale = 8.0
	check(await until(func(): return bool(ailes().get("permutees", false)), 180000), "ailes permutées au prochain arrêt de jeu")
	Engine.time_scale = 1.0
	var apres: Array = live().get("lineup", []) if live().get("lineup") is Array else []
	check(apres.size() > 13 and str(apres[10].get("id", "")) == d and str(apres[13].get("id", "")) == g, "nos n° 11 et 14 ont échangé leurs côtés")
	finir()

## Fenêtre « À un joueur » ouverte, en 1920 puis 2560 : captures et cadre dans l'écran.
func capture_tailles(between: Control) -> void:
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await taille(t)
		await until(func(): return surface() != null and vue_2d(surface()), 30000)
		await settle(10)
		var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
		var panneau := between.find_child("FmBancMenuPanneau", true, false) as Control
		check(panneau != null and ecran.encloses(panneau.get_global_rect()), "%s : fenêtre « À un joueur » dans l'écran" % str(t))
		var barre := between.find_child("FmBancBarre", true, false) as Control
		check(barre != null and ecran.encloses(barre.get_global_rect()), "%s : barre du banc dans l'écran" % str(t))
		# Liste accrochée au rond « À un joueur » : juste dessous, alignée sur lui ; le rond reste allumé.
		var rond := bouton(between, "FmBancJoueur")
		if rond != null and panneau != null:
			var rr := rond.get_global_rect()
			var pr := panneau.get_global_rect()
			check(pr.position.y >= rr.end.y and pr.position.y - rr.end.y < 24.0, "%s : liste juste sous le rond (%d px)" % [str(t), int(pr.position.y - rr.end.y)])
			var colonne := between.find_child("MatchBetweenEventsColumn", true, false) as Control
			var rc := colonne.get_global_rect() if colonne != null else Rect2()
			check(colonne != null and absf(pr.position.x - rc.position.x) < 2.0 and pr.end.x <= rc.end.x + 2.0, "%s : liste sur la colonne de gauche (%d → %d, colonne %d → %d)" % [str(t), int(pr.position.x), int(pr.end.x), int(rc.position.x), int(rc.end.x)])
			var terrain_2d: Control = between.get("terrain")
			check(terrain_2d == null or not terrain_2d.is_visible_in_tree() or not pr.intersects(terrain_2d.get_global_rect()), "%s : la liste ne chevauche pas le terrain 2D" % str(t))
			var centre := between.find_child("MatchBetweenCentre", true, false) as Control
			check(centre == null or not pr.intersects(centre.get_global_rect()), "%s : la liste reste à gauche du centre" % str(t))
			var lignes := between.find_child("FmCriJoueur_10", true, false) as Control
			check(lignes != null and lignes.get_global_rect().end.x <= pr.end.x + 1.0, "%s : colonnes de la liste dans sa largeur" % str(t))
		check(rond != null and bool(rond.get_meta("ouvert", false)), "%s : rond « À un joueur » allumé tant que la liste est ouverte" % str(t))
		await capture("final-%d" % t.x)
	await taille(Vector2i(1920, 1080))

## Chaque petite fenêtre de l'écran 2D (et la fenêtre Équipe, le menu Plus) : ouverte, fond anthracite satiné, capture.
func fenetres(view: Control, between: Control) -> void:
	var ardoise: Color = load("res://ui/contextual/match_menu_joueur.gd").PAL.fond
	if bouton(between, "FmBancMenuFermer") != null: bouton(between, "FmBancMenuFermer").pressed.emit()
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
