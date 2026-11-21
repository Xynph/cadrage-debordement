extends SceneTree
## Carte joueur au survol sur les écrans joueurs, valeur au poste en Tactique et danger en Préparation (Léo, 21/11/2026) :
## - Effectif, Composition, Recrutement, Entraînement, Vestiaire : la vraie souris passe sur un nom ou un portrait, la
##   carte (même composant que le direct) apparaît après le délai, entière dans l'écran ; la souris part, elle disparaît ;
## - Tactique : plus d'étoiles ; note au poste chiffrée + familiarité (naturel / 2e poste / dépanne) sur les 15 cartes du
##   terrain et dans la liste des candidats, tri sur la vraie note ; un joueur dépanne et un joueur à son 2e poste sont
##   placés exprès dans le XV. Variante CD_VARIANTE_VISUELLE=POSTE_A | POSTE_B ;
## - Préparation : plus d'étoiles ; chaque joueur à surveiller porte sa note au poste en chiffre dans une pastille colorée.
## Captures 2560 × 1440 et 1920 × 1080 dans CD_ETOILES_FICHE_CAPTURES. godot-poste-carte-survol.cjs prépare la carrière ;
## CD_POSTE_SEUL=1 ne rejoue que la Tactique (seconde variante).
const Carte = preload("res://ui/carte_joueur_survol.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const Poste = preload("res://ui/immersive08/tactics_poste.gd")
const Savoir = preload("res://ui/player_knowledge_text.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_ETOILES_FICHE_CAPTURES")
var taille_txt := ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(taille_txt + message)
		printerr("ECHEC : ", taille_txt, message)

func settle(frames: int = 8) -> void:
	for i in frames: await process_frame

func wait_command(limit_ms: int = 60000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle(3)

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_command()

func until(condition: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	return condition.call()

func capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dossier.path_join(nom + ".png"))

func souris(position: Vector2) -> void:
	var mouvement := InputEventMouseMotion.new()
	mouvement.position = position
	mouvement.global_position = position
	root.push_input(mouvement)

func named(id: String) -> Control:
	return app.find_child(id, true, false) as Control

## Premier contrôle visible et entier à l'écran qui porte la carte joueur (motif de nom facultatif).
func cible(motif: String = "*") -> Control:
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size))
	for n: Node in app.root_content.find_children(motif, "Control", true, false):
		var c := n as Control
		if c.has_meta("carte_joueur") and c.is_visible_in_tree() and c.size.x > 4.0 and ecran.encloses(c.get_global_rect()): return c
	return null

## Survol réel (souris du jeu) : rien avant le délai, la carte ensuite, entière ; la souris part, elle disparaît.
func survoler(ecran_nom: String, controle: Control, nom_capture: String) -> void:
	check(controle != null, ecran_nom + " : un nom ou un portrait porte la carte joueur")
	if controle == null:
		print("ETOILES_FICHE %s : %d contrôles liés, route %s" % [ecran_nom, app.find_children("*", "Control", true, false).filter(func(c: Node): return c.has_meta("carte_joueur")).size(), app.route])
		await capture("echec-" + ecran_nom.validate_node_name())
		return
	if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
	souris(Vector2(2, 2))
	await settle(4)
	var debut := Time.get_ticks_msec()
	souris(controle.get_global_rect().get_center())
	var apparue := await until(func(): return Carte.actuelle(app) != null, 3000)
	var delai := Time.get_ticks_msec() - debut
	check(apparue, ecran_nom + " : la carte apparaît au survol")
	check(not apparue or delai >= 300, ecran_nom + " : pas de carte avant le délai (%d ms)" % delai)
	await settle(6)
	var carte := Carte.actuelle(app)
	if carte != null:
		check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0).encloses(carte.get_global_rect()), ecran_nom + " : carte entière dans l'écran")
		check(str(carte.get_meta("player_id", "")) == str(controle.get_meta("carte_joueur")), ecran_nom + " : carte du joueur survolé")
		check(carte.find_child("CarteJoueurEtoilesPoste_*", true, false) != null or carte.find_child("CarteJoueurPolyvalence", true, false) != null, ecran_nom + " : postes de la carte")
		check(carte.find_child("CarteJoueurEtoilesNiveau", true, false) == null, ecran_nom + " : jamais d'étoiles pour le niveau")
		check(app.get_node_or_null("MiniFicheJoueur") == null, ecran_nom + " : plus de mini-fiche par-dessus")
		if not nom_capture.is_empty(): await capture(nom_capture)
	souris(Vector2(2, 2))
	await settle(10)
	check(Carte.actuelle(app) == null, ecran_nom + " : la souris part, la carte disparaît")

func run() -> void:
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text": FileAccess.get_file_as_string(dossier.path_join("monde.json"))})
	await hors_poste()
	var seul := OS.get_environment("CD_POSTE_SEUL") == "1"
	for taille: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = taille
		root.content_scale_size = taille
		taille_txt = "%dx%d · " % [taille.x, taille.y]
		var suffixe := "-%d" % taille.x
		await settle(10)
		await tactique(suffixe)
		if seul: continue
		await preparation(suffixe)
		# Effectif.
		app._navigate("Effectif")
		await settle(20)
		await survoler("Effectif", cible("SquadOpenPlayer_*"), "effectif" + suffixe)
		# Recrutement.
		app._navigate("Recrutement")
		await settle(30)
		await survoler("Recrutement", cible("MarketEntity_*"), "recrutement" + suffixe)
		# Entraînement (onglet de la Composition).
		app._navigate("Composition")
		await settle(10)
		var onglet := named("TacticsTab4") as Button
		if onglet != null:
			onglet.pressed.emit()
			await settle(20)
		await survoler("Entraînement", cible(), "entrainement" + suffixe)
		# Vestiaire.
		app._navigate("Vestiaire")
		await settle(20)
		await survoler("Vestiaire", cible(), "vestiaire" + suffixe)
	finir()

## Place exprès un joueur qui dépanne au n° 13 et un joueur à son 2e poste (premier poste possible parmi n° 15, 14, 11,
## 10, 9, 8, 7, 6), pris hors du XV.
func hors_poste() -> void:
	var places_2e := [14, 13, 10, 9, 8, 7, 6, 5]
	for cible: Array in [[12, 1], [-1, 2]]:
		var place: int = cible[0]
		var choix := ""
		if place < 0:
			for essai: int in places_2e:
				for pid: Variant in Selection.slot(app.model, essai).get("eligibleIds", []):
					var source2 := Selection.source(app.model, str(pid))
					if Selection.familiarite(app.model, Selection.player(app.model, str(pid)), essai) == 2 and (source2 < 0 or source2 >= 15) and Selection.rating(app.model, Selection.player(app.model, str(pid)), essai) != null:
						place = essai
						break
				if place >= 0: break
			if place < 0:
				print("ETOILES_FICHE : aucun joueur à son 2e poste disponible")
				continue
		for pid: Variant in Selection.slot(app.model, place).get("eligibleIds", []):
			var p := Selection.player(app.model, str(pid))
			if Selection.familiarite(app.model, p, place) != int(cible[1]): continue
			var source := Selection.source(app.model, str(pid))
			if source >= 0 and source < 15: continue
			choix = str(pid)
			break
		if choix.is_empty():
			print("ETOILES_FICHE : aucun joueur de familiarité %d disponible au n° %d" % [cible[1], place + 1])
			continue
		await command("set_lineup", {"playerId": choix, "slot": place})
		check(Selection.familiarite(app.model, Selection.occupant(app.model, place), place) == int(cible[1]), "Hors poste : familiarité %d placée au n° %d" % [cible[1], place + 1])

## Tactique : note au poste chiffrée + familiarité sur les cartes du terrain et les candidats (jamais d'étoiles).
func tactique(suffixe: String) -> void:
	app._navigate("Composition")
	await settle(10)
	app.selected_slot = 12
	app._render()
	await settle(20)
	var v := Poste.variante()
	var poses := 0
	var hors := 0
	for i in 15:
		var person: Dictionary = Selection.occupant(app.model, i)
		if person.is_empty(): continue
		check(named("TacticsPositionStars%02d" % (i + 1)) == null, "Terrain : plus d'étoiles (n° %d)" % (i + 1))
		var e := named("TacticsPositionRating%02d" % (i + 1))
		var note: Variant = Selection.rating(app.model, person, i)
		var fam := Selection.familiarite(app.model, person, i)
		if e != null and note != null and int(e.get_meta("note", -1)) == roundi(float(note)) and int(e.get_meta("familiarite", 0)) == fam and str(e.get_meta("variante", "")) == v: poses += 1
		if e != null and note != null:
			var chiffre := e.find_child("Chiffre", true, false) as Label
			check(chiffre != null and chiffre.text == str(roundi(float(note))), "Terrain : chiffre de la note au poste (n° %d)" % (i + 1))
			var carte := named("LineupSlot%02d" % (i + 1))
			if carte != null: check(carte.get_global_rect().grow(1.0).encloses(e.get_global_rect()), "Terrain : valeur au poste dans la carte n° %d" % (i + 1))
			if fam in [1, 2]:
				hors += 1
				if v == "A":
					var mot := e.find_child("MarqueMot", true, false) as Label
					check(mot != null and mot.text in ["2e poste", "Dépanne", "2e", "Dép."] and (mot.text.begins_with("D") == (fam == 1)), "Terrain A : pastille « 2e poste / Dépanne » (n° %d)" % (i + 1))
				else:
					check(e.find_children("Point*", "", true, false).size() == 3, "Terrain B : trois points de familiarité (n° %d)" % (i + 1))
			elif fam == 3 and v == "A":
				check(e.find_child("Marque", true, false) == null, "Terrain A : rien de plus au poste naturel (n° %d)" % (i + 1))
	check(poses >= 14, "Terrain : note au poste et familiarité sur les cartes (%d/15)" % poses)
	check(hors >= 1, "Terrain : au moins un joueur hors de son poste naturel visible (%d)" % hors)
	var notes: Array = []
	for ligne: Node in app.root_content.find_children("TacticsCandidate_*", "Control", true, false):
		var r := ligne.find_child("TacticsCandidateRating", false, false)
		if r != null and r.has_meta("note") and r.modulate.a > 0.9: notes.append(int(r.get_meta("note")))
	check(notes.size() >= 3, "Candidats : note au poste chiffrée (%d lignes)" % notes.size())
	var trie := notes.duplicate()
	trie.sort()
	trie.reverse()
	check(notes == trie, "Candidats : triés sur la vraie note au poste " + str(notes))
	check(app.root_content.find_children("TacticsCandidateStars", "Control", true, false).is_empty(), "Candidats : plus d'étoiles")
	check(app.root_content.find_children("CarteJoueurEtoiles*", "Control", true, false).is_empty(), "Tactique : aucune étoile hors carte joueur")
	if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
	souris(Vector2(2, 2))
	await settle(10)
	await capture("tactique-poste-%s%s" % [v, suffixe])
	await survoler("Composition", named("TacticsName10"), "tactique-survol-%s%s" % [v, suffixe])

## Préparation : chaque joueur à surveiller porte sa note au poste en chiffre dans une pastille colorée (jamais d'étoiles).
func preparation(suffixe: String) -> void:
	app._navigate("Préparation")
	await settle(30)
	var menaces: Array = app.model.get("decisions", {}).get("preparation", {}).get("threats", []) if app.model.get("decisions", {}).get("preparation") is Dictionary else []
	if menaces.is_empty():
		print("ETOILES_FICHE : pas de joueurs adverses à surveiller dans cette carrière")
		return
	check(app.root_content.find_children("PreparationThreatStars*", "Control", true, false).is_empty(), "Préparation : plus d'étoiles")
	for i in mini(3, menaces.size()):
		var m: Dictionary = menaces[i]
		# Danger publié seulement : note au poste si connue, sinon fourchette de niveau, sinon « ? » (jamais une valeur cachée).
		var attendu := "?"
		if m.get("note") is int or m.get("note") is float: attendu = str(roundi(float(m.note)))
		elif not Savoir.bounds(m, "rating").is_empty(): attendu = "%d–%d" % [roundi(float(Savoir.bounds(m, "rating").min)), roundi(float(Savoir.bounds(m, "rating").max))]
		var pastille := named("PreparationThreatLevel%d" % i)
		check(pastille != null and str(pastille.get_meta("valeur", "")) == attendu, "Préparation : pastille du joueur %d = %s" % [i, attendu])
		if pastille != null:
			var chiffre := pastille.find_child("Chiffre", true, false) as Label
			check(chiffre != null and chiffre.text == attendu, "Préparation : valeur écrite dans la pastille %d" % i)
			var legende := named("PreparationThreatLevelLabel%d" % i) as Label
			check(legende != null and not legende.text.is_empty(), "Préparation : mot sous la pastille %d" % i)
			var carte := named("PreparationThreat%d" % i)
			if carte != null: check(carte.get_global_rect().grow(1.0).encloses(pastille.get_global_rect()), "Préparation : pastille dans la carte %d" % i)
	await capture("preparation" + suffixe)

func finir() -> void:
	print("ETOILES_FICHE %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
