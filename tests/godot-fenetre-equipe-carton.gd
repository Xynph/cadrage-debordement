extends SceneTree
## Fenêtre « Équipe » du direct, pilier n°3 en carton jaune (PR #1338, profil préparé par
## tests/godot-fenetre-equipe-carton.cjs). Le vrai moteur a exclu le pilier par giveMatchCard puis joué une minute
## (live.direct.cartons rempli) ; le vrai Godot reprend ce match (`import`), ouvre la vraie fenêtre Équipe par son
## bouton et lit le rendu : le n° 3 est occupé par le pilier exclu avec la pastille « Carton », il est absent du banc,
## aucun poste vacant. Captures (affichage graphique) : CD_EQUIPE_OUTPUT=<dossier>.
var app: Control
var vue: Control
var fenetre: Control
var sortie := OS.get_environment("CD_EQUIPE_OUTPUT")
var id_carton := OS.get_environment("CD_EQUIPE_CARTON_ID")
var echecs: Array[String] = []
var controles := 0
var rapport := {}

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 8) -> void:
	for i in images: await process_frame

func jusqua(condition: Callable, limite_ms: int = 30000) -> bool:
	var fin := Time.get_ticks_msec() + limite_ms
	while Time.get_ticks_msec() < fin:
		if condition.call(): return true
		await process_frame
	return condition.call()

func attendre(commande: String) -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, commande + " : réponse du vrai moteur " + str(app.last_error))
	await poser(6)

func live() -> Dictionary:
	return app.model.get("live") if app.model.get("live") is Dictionary else {}

func capturer(nom: String) -> void:
	await poser(12)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

## Tous les textes des Label et Button sous un nœud.
func textes(racine: Node) -> Array:
	var t: Array = []
	for n in racine.find_children("*", "Label", true, false): t.append((n as Label).text)
	for n in racine.find_children("*", "Button", true, false): t.append((n as Button).text)
	return t

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await poser(10)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await attendre("ouverture")
	# Reprise du vrai match Monde où le moteur a exclu le pilier n°3 (carton jaune, événement montré).
	var texte := FileAccess.get_file_as_string(OS.get_environment("CD_EQUIPE_SAUVEGARDE"))
	verifier(not texte.is_empty() and not id_carton.is_empty(), "sauvegarde du match et identifiant du pilier fournis")
	app._command("import", {"text": texte})
	await attendre("import")
	await jusqua(func() -> bool: return app.find_child("ContextualLiveMatch", true, false) != null, 30000)
	vue = app.find_child("ContextualLiveMatch", true, false)
	verifier(vue != null and "equipe" in vue, "direct ouvert avec la fenêtre Équipe")
	if vue == null or not "equipe" in vue:
		_fin()
		return
	fenetre = vue.equipe
	await jusqua(func() -> bool: return live().get("direct") is Dictionary, 30000)
	await poser(10)
	# Ce que dit le moteur : pilier exclu dans direct.cartons, n° 3 à son poste dans le XV montré, absent des remplaçants.
	var cartons: Array = live().get("direct", {}).get("cartons", [])
	rapport.cartons = cartons.map(func(c: Variant) -> String: return str(c.get("id", "")) if c is Dictionary else "")
	verifier(cartons.any(func(c: Variant) -> bool: return c is Dictionary and str(c.get("id", "")) == id_carton), "direct.cartons contient le pilier exclu")
	var lineup: Array = live().get("lineup", [])
	verifier(lineup.size() == 15 and lineup.all(func(j: Variant) -> bool: return j is Dictionary), "modèle : XV de 15 joueurs, aucun poste vide")
	verifier(lineup.size() > 2 and lineup[2] is Dictionary and str(lineup[2].get("id", "")) == id_carton, "modèle : pilier exclu au poste n° 3")
	verifier(not (live().get("reserves", []) as Array).any(func(j: Variant) -> bool: return j is Dictionary and str(j.get("id", "")) == id_carton), "modèle : pilier exclu absent des remplaçants")
	# Ouverture de la vraie fenêtre Équipe par son bouton.
	var bouton: Button = vue.find_child("MatchBetweenTeam", true, false)
	if bouton == null: bouton = vue.find_child("MatchTeamButton", true, false)
	verifier(bouton != null, "bouton ÉQUIPE trouvé")
	if bouton != null:
		bouton.disabled = false
		bouton.pressed.emit()
	await poser(6)
	verifier(fenetre.visible, "la fenêtre Équipe s'ouvre")
	await jusqua(func() -> bool: return bool(live().get("paused", false)) and not app.waiting, 30000)
	fenetre.update_frame(app.model)
	await poser(8)
	# Rendu : 15 médaillons, tous occupés ; le n° 3 porte le pilier exclu et la pastille « Carton ».
	verifier(fenetre.medaillons.size() == 15, "15 médaillons (%d)" % fenetre.medaillons.size())
	var vacants: Array = []
	for slot in fenetre.medaillons.keys():
		if "Poste vacant" in textes(fenetre.medaillons[slot]): vacants.append(int(slot) + 1)
	rapport.vacants = vacants
	verifier(vacants.is_empty(), "aucun poste vacant dans le rendu (%s)" % str(vacants))
	var m3: Node = fenetre.medaillons.get(2)
	verifier(m3 != null, "médaillon n° 3 présent")
	if m3 != null:
		var t3 := textes(m3)
		rapport.numero3 = t3
		var nom_exclu := ""
		for j: Variant in lineup:
			if j is Dictionary and str(j.get("id", "")) == id_carton: nom_exclu = str(j.get("name", "")).to_upper()
		rapport.exclu = nom_exclu
		var lien := m3.find_child("TeamPlayerName", true, false)
		var affiche := str(lien.text).to_upper() if lien != null and "text" in lien else ""
		var porte := false
		for mot: String in affiche.replace(".", " ").split(" ", false):
			if mot.length() >= 3 and nom_exclu.contains(mot): porte = true
		verifier(porte, "le n° 3 porte le pilier exclu (affiché « %s », attendu %s)" % [affiche, nom_exclu])
		var puce: Node = m3.find_child("TeamPlayerState", true, false)
		verifier(puce != null and "Carton" in textes(puce), "pastille « Carton » sur le n° 3 (%s)" % str(textes(puce) if puce != null else "aucune pastille"))
		verifier(not ("Poste vacant" in t3), "le n° 3 n'est pas vacant")
	# Autres médaillons : pas de pastille Carton ailleurs (un seul exclu).
	var autres := 0
	for slot in fenetre.medaillons.keys():
		if int(slot) == 2: continue
		var p: Node = fenetre.medaillons[slot].find_child("TeamPlayerState", true, false)
		if p != null and "Carton" in textes(p): autres += 1
	verifier(autres == 0, "pastille Carton seulement sur le pilier exclu (%d ailleurs)" % autres)
	# Banc : le pilier exclu n'y figure pas (aucune tuile à son identifiant) ; le banc est bien affiché.
	rapport.tuiles = fenetre.tuiles.size()
	verifier(fenetre.tuiles.size() > 0, "banc affiché (%d tuiles)" % fenetre.tuiles.size())
	verifier(not fenetre.tuiles.has(id_carton), "pilier exclu absent des remplaçants du rendu")
	await capturer("equipe-carton-xv")
	_fin()

func _fin() -> void:
	print("EQUIPE-CARTON ", JSON.stringify({"controles": controles, "failures": echecs, "rapport": rapport}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
