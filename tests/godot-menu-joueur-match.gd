extends SceneTree
## Fenêtre d'un joueur en match (idée FM27 n° 32, choix final de Léo du 23/11/2026) dans un vrai match Monde, à vitesse
## maximale jusqu'à la 2e mi-temps : clic sur une carte de Mon XV = petite fenêtre ardoise claire (mini-fiche, poste en
## familiarité, terrain des 15 postes, rôle, consignes), SANS pause et SANS colonne de remplaçants ; un clic sur un rôle
## ou une consigne part tout de suite au moteur (aucun bouton Confirmer) et attend le prochain arrêt de jeu ; un
## remplacement fait par le circuit de la fenêtre Équipe attend lui aussi l'arrêt, puis la carte sortant / entrant
## s'affiche sur la phrase de jeu (pas sur le terrain 2D) et l'entrant garde son vrai numéro (16 à 23).
## godot-menu-joueur-match.cjs prépare la carrière ; captures final-*.png dans CD_PLANCHE_DIRECT_2D.
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

func file() -> Array:
	var p: Variant = live().get("pilotage")
	var a: Variant = p.get("arrets") if p is Dictionary else null
	return a.get("file", []) if a is Dictionary and a.get("file") is Array else []

func taille(t: Vector2i) -> void:
	root.size = t
	root.content_scale_size = t
	await settle(30)

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
	if live().get("paused", false): await command("pause", {"paused": false})
	# Vitesse maximale jusqu'à la 2e mi-temps (jamais en temps réel dans les tests), en petite taille.
	Engine.time_scale = 16.0
	await taille(Vector2i(960, 540))
	var depart := Time.get_ticks_msec()
	while Time.get_ticks_msec() - depart < 600000 and int(live().get("minute", 0)) < 50 and not live().get("finished", false):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	print("MENU_JOUEUR minute %d atteinte en %d s" % [int(live().get("minute", 0)), (Time.get_ticks_msec() - depart) / 1000])
	await taille(Vector2i(1920, 1080))
	check(await until(func(): return surface() != null and vue_2d(surface()), 240000), "Écran 2D du direct")
	view = surface()
	var between: Control = view.regie.between
	# Le joueur à ouvrir : un ouvreur ou un demi (rôles et consignes riches), sur sa carte de Mon XV.
	var carte := la_carte(between, "MatchBetweenPlayer10")
	check(carte != null, "carte n° 10 de Mon XV")
	if carte == null:
		finir()
		return
	var id := str(carte.get_meta("player_id", ""))
	Engine.time_scale = 1.0
	carte.pressed.emit()
	await settle(16)
	var fenetre: Node = view.fenetre_hote.find_child("MatchMenuJoueur", true, false) if view.fenetre_ouverte() else null
	check(fenetre != null and view.fenetre_hote.find_child("MatchMenuJoueurPortrait", true, false) != null, "clic sur la carte : la fenêtre du joueur s'ouvre")
	check(not live().get("paused", false), "le match continue derrière la fenêtre")
	check(view.fenetre_hote.find_child("MatchMenuJoueurRemplacants", true, false) == null and view.fenetre_hote.find_children("MatchMenuJoueurRemplacant*", "", true, false).is_empty(), "aucun remplacement dans la fenêtre")
	for nom: String in ["MatchMenuJoueurNom", "MatchMenuJoueurOrigine", "MatchMenuJoueurGabarit", "MatchMenuJoueurNoteMatch", "MatchMenuJoueurEnergie", "MatchMenuJoueurMoral", "MatchMenuJoueurFamiliarite", "MatchMenuJoueurNotePoste", "MatchMenuJoueurTerrain"]:
		check(view.fenetre_hote.find_child(nom, true, false) != null, "mini-fiche : " + nom)
	check(view.fenetre_hote.find_children("MatchMenuJoueurRole_*Lien", "Button", true, false).size() == 3, "trois rôles du poste")
	check(view.fenetre_hote.find_children("Consigne_*Lien", "Button", true, false).size() == 4, "quatre consignes individuelles")
	check(view.fenetre_hote.find_children("*Confirmer*", "", true, false).is_empty() and view.fenetre_hote.find_children("*Valider*", "", true, false).is_empty(), "aucun bouton Confirmer")
	# Un clic sur un autre rôle : la commande part tout de suite et le moteur la garde jusqu'à l'arrêt (ou l'applique).
	var autre: Button = null
	for b: Node in view.fenetre_hote.find_children("MatchMenuJoueurRole_*Lien", "Button", true, false):
		if (b.get_parent() as Panel).get_theme_stylebox("panel").bg_color.a < 0.5 and autre == null: autre = b
	check(autre != null, "un autre rôle à choisir")
	if autre != null:
		var role_voulu := str(autre.name).trim_prefix("MatchMenuJoueurRole_").trim_suffix("Lien")
		autre.pressed.emit()
		await wait_command()
		var arrets: Dictionary = live().get("pilotage", {}).get("arrets", {})
		var en_file := file().any(func(e: Variant) -> bool: return e is Dictionary and str(e.get("cle", "")) == "role:" + id)
		var applique := str(arrets.get("roles", {}).get(id, {}).get("role", "")) == role_voulu
		check(en_file or applique, "clic sur un rôle : pris tout de suite par le moteur (en attente du prochain arrêt ou appliqué), sans confirmation")
	await settle(10)
	var consigne := view.fenetre_hote.find_child("Consigne_piedLien", true, false) as Button if view.fenetre_ouverte() else null
	check(consigne != null, "consigne « Jouer au pied »")
	if consigne != null:
		consigne.pressed.emit()
		await wait_command()
		var a1: Dictionary = live().get("pilotage", {}).get("arrets", {})
		check(file().any(func(e: Variant) -> bool: return e is Dictionary and str(e.get("cle", "")) == "consignes:" + id) or (a1.get("consignes", {}).get(id, []) as Array).has("pied"), "clic sur une consigne : prise par le moteur, sans confirmation")
	await settle(12)
	# Une consigne de plus juste avant les captures : la fenêtre montre « ⧗ » tant que le ballon vit.
	var ligne := view.fenetre_hote.find_child("Consigne_attaquerLigneLien", true, false) as Button if view.fenetre_ouverte() else null
	if ligne != null:
		ligne.pressed.emit()
		await wait_command()
	await capture_tailles(view, id)
	# La file part au prochain arrêt de jeu : le match tourne, on attend qu'elle soit vide.
	Engine.time_scale = 8.0
	check(await until(func(): return file().is_empty(), 180000), "la file se vide au prochain arrêt de jeu")
	Engine.time_scale = 1.0
	var a2: Dictionary = live().get("pilotage", {}).get("arrets", {})
	check((a2.get("consignes", {}).get(id, []) as Array).has("pied"), "consigne appliquée par le moteur")
	if view.fenetre_ouverte(): view.fermer_fenetre()
	await settle(10)
	# Remplacement par le circuit de la fenêtre Équipe (commande substitute) : en attente, badge sur Mon XV, puis carte.
	var choix: Dictionary = {}
	for option: Variant in live().get("substitutions", []):
		if choix.is_empty() and option is Dictionary and int(option.get("slot", -1)) >= 5 and not (option.get("inIds", []) as Array).is_empty(): choix = option
	check(not choix.is_empty(), "un remplacement possible")
	if not choix.is_empty():
		var entrant := str(choix.inIds[0])
		var numero := int(live().get("numeros", {}).get(entrant, 0))
		check(numero >= 16 and numero <= 23, "numéro de feuille du remplaçant (%d)" % numero)
		await command("substitute", {"slot": int(choix.slot), "outId": choix.outId, "inId": entrant})
		var en_attente := not file().is_empty()
		if en_attente:
			await settle(20)
			check(not between.find_children("MatchMenuJoueurAttenteBadge", "", true, false).is_empty(), "badge ⧗ sur la carte du sortant")
		Engine.time_scale = 8.0
		check(await until(func(): return file().is_empty(), 180000), "le remplacement part au prochain arrêt")
		Engine.time_scale = 4.0
		check(await until(func(): return between.find_child("MatchChangementCarte", true, false) != null, 120000), "carte sortant / entrant affichée quand le direct montre le changement")
		Engine.time_scale = 1.0
		var carte_ch := between.find_child("MatchChangementCarte", true, false) as Control
		check(carte_ch != null and between.terrain.find_child("MatchChangementCarte", true, false) == null, "carte hors du terrain 2D")
		var entrant_label := false
		if carte_ch != null:
			for l: Node in carte_ch.find_children("*", "Label", true, false):
				if (l as Label).text == str(numero): entrant_label = true
		check(entrant_label, "l'entrant garde son vrai numéro (%d) sur la carte" % numero)
		check(int(live().get("numeros", {}).get(entrant, 0)) == numero, "numéro gardé par le moteur")
		var nom_tuile := "MatchBetweenPlayer%d" % (int(choix.slot) + 1)
		check(await until(func(): return la_carte(between, nom_tuile) != null and str(la_carte(between, nom_tuile).get_meta("player_id", "")) == entrant, 60000), "Mon XV : l'entrant prend la carte du poste")
		# Capture sur l'écran 2D posé (pas pendant le fondu vers un temps fort 3D).
		await until(func(): return vue_2d(view) and not app.waiting, 60000)
		await settle(20)
		carte_ch = between.find_child("MatchChangementCarte", true, false) as Control
		check(carte_ch != null and not carte_ch.get_global_rect().intersects(between.terrain.get_global_rect()), "carte qui ne recouvre pas le terrain 2D")
		check(carte_ch != null and between.phrase_fm.get_global_rect().grow(4.0).encloses(carte_ch.get_global_rect()), "carte posée sur la bande de la phrase de jeu")
		await capture("final-remplacement-1920")
		# Le numéro sur la médaille arrive avec le dernier rafraîchissement de la carte (runner lent) : on attend qu'il s'affiche.
		var chiffre := ""
		var lire_numero := func() -> String:
			var t: Button = la_carte(between, nom_tuile)
			var texte := ""
			var medaille: Node = t.find_child("MatchBetweenFaceNumber", true, false) if t != null else null
			for l: Node in (medaille.find_children("*", "Label", true, false) if medaille != null else []): texte = (l as Label).text
			return texte
		# Runner lent : la carte du poste peut rester cachée le temps d'un temps fort 3D, on laisse le match avancer pour le passer.
		Engine.time_scale = 4.0
		await until(func(): return lire_numero.call() == str(numero), 90000)
		Engine.time_scale = 1.0
		chiffre = lire_numero.call()
		check(chiffre == str(numero), "Mon XV : l'entrant porte le n° %d (vu : %s)" % [numero, chiffre])
	finir()

## Fenêtre ouverte (rouverte sur le même joueur), en 1920 puis 2560 : captures et cadre dans l'écran.
func capture_tailles(view: Control, id: String) -> void:
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await taille(t)
		load("res://ui/contextual/match_menu_joueur.gd").ouvrir(view, id, null)
		await settle(16)
		var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0)
		var panneau := view.fenetre_hote.find_child("MatchMenuJoueurPanneau", true, false) as Control if view.fenetre_ouverte() else null
		check(panneau != null and ecran.encloses(panneau.get_global_rect()), "%s : fenêtre dans l'écran" % str(t))
		if panneau != null: check(panneau.get_global_rect().size.x < root.size.x * 0.72, "%s : petite fenêtre (≈ 2/3 de la planche)" % str(t))
		await capture("final-%d" % t.x)
	await taille(Vector2i(1920, 1080))

## La carte de Mon XV est reconstruite au changement de taille : on la retrouve par son nom.
func la_carte(between: Control, nom: String) -> Button:
	for n: Node in between.find_children(nom, "Button", true, false):
		if (n as Control).is_visible_in_tree() and not n.is_queued_for_deletion(): return n
	return null

func finir() -> void:
	print("MENU_JOUEUR %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
