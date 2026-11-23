extends SceneTree
## Effectif › Planificateur (idée FM27 n° 11, choix de Léo du 23/11/2026).
## 1. Calculs purs : note future (âge, potentiel) déterministe, projection des saisons (départs, négociation, vente,
##    espoirs), ordre du poste par note estimée, titulaire à deux postes.
## 2. Vrai jeu (carrière Monde importée) : 11 postes sur le terrain, liste du poste à côté, un clic sur une saison ou un
##    poste s'applique tout de suite (aucun bouton Valider), négociation signalée, nom -> fiche, plus aucune étoile.
## CD_PLAN_CAPTURES=<dossier> (+ CD_PLAN_TAILLE=LxH) : final-actuelle-<L>.png et final-prochaine-<L>.png.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Plan = preload("res://ui/immersive08/planificateur.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_PLAN_CAPTURES")
var taille := Vector2i(1920, 1080)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func settle(frames := 8) -> void:
	for frame in frames: await process_frame
func wait_worker(limit_ms := 240000) -> void:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
func found(id: String) -> Control: return app.find_child(id, true, false) as Control
func click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new(); move.position = point; move.global_position = point
	Input.parse_input_event(move); await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down; event.position = point; event.global_position = point
		Input.parse_input_event(event); await process_frame
	await settle()
func click_id(id: String) -> bool:
	var control := found(id)
	check(control != null and control.is_visible_in_tree(), "Présent et visible · " + id)
	if control == null: return false
	await click(control.get_global_rect().get_center())
	return true

## Choisit un poste par l'en-tête de sa carte (les noms, dessus, ouvrent la fiche).
func choisir_poste(i: int) -> bool:
	var carte := found("PlanCarte_%d" % i)
	check(carte != null and carte.is_visible_in_tree(), "Carte du poste visible · %d" % i)
	if carte == null: return false
	var r := carte.get_global_rect()
	await click(r.position + Vector2(r.size.x * .62, minf(18.0, r.size.y * .1)))
	return true

func appliquer_taille() -> void:
	if captures.is_empty() or Vector2i(root.get_texture().get_size()) == taille: return
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.borderless = true
	root.size = taille
	DisplayServer.window_set_size(taille)
	await create_timer(0.5).timeout

func capture(nom: String) -> void:
	if captures.is_empty(): return
	await appliquer_taille()
	if is_instance_valid(app.coach):
		if app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
		app.coach.close()
	await settle(20)
	await create_timer(1.0).timeout
	var image := root.get_texture().get_image()
	if image != null: image.save_png(captures.path_join("final-%s-%d.png" % [nom, taille.x]))

# ---------------------------------------------------------------- 1. calculs purs

func joueur(id: String, naturels: Array, note: float, age: int, fin: int, globale: float, pot: float) -> Dictionary:
	var niveaux: Array = []
	var notes := {}
	for n in range(1, 16):
		niveaux.append(4 if n in naturels else 0)
		notes[str(n)] = note if n in naturels else note * .6
	return {"id": id, "name": id.to_upper(), "age": age, "contractEnd": fin, "rating": globale,
		"potentialRange": {"min": pot - 2.0, "max": pot + 2.0} if pot >= 0.0 else null,
		"positionFamiliarityLevels": niveaux, "positionRatings": notes, "primaryPositions": [naturels[0]]}

func calculs() -> void:
	# Note future : progression vers le potentiel selon l'âge, déclin dès 30 ans, valeurs exactes et répétables.
	check(Plan.note_future(70, 19, 65, 80, 1) == 76.0, "Espoir de 19 ans : +6 la saison prochaine (40 % de l'écart)")
	check(Plan.note_future(70, 19, 65, 80, 2) == 80.0, "Espoir de 19 ans : +10 dans deux saisons")
	check(Plan.note_future(70, 25, 70, 80, 1) == 72.0, "25 ans : 15 % de l'écart")
	check(Plan.note_future(80, 31, 78, 80, 2) == 77.0, "31 puis 32 ans : −1 puis −2")
	check(Plan.note_future(75, 34, 75, 90, 1) == 72.0, "34 ans : −3 même avec du potentiel")
	check(Plan.note_future(60, 22, 60, -1, 2) == 60.0, "Potentiel inconnu, jeune : inchangé")
	check(Plan.note_future(-1, 22, 60, 80, 2) == -1.0, "Note au poste inconnue : inconnue")
	check(Plan.note_future(66, 22, 60, 80, 0) == 66.0, "Saison actuelle : note du jour")
	check(Plan.note_future(98, 18, 90, 99, 2) <= 99.0, "Plafond 99")
	check(Plan.note_future(70, 19, 65, 80, 2) == Plan.note_future(70, 19, 65, 80, 2), "Déterministe")
	# Projection : a (fin cette saison, en négociation), b (titulaire centre ET ailier), c (fin cette saison, part),
	# d (jeune centre à fort potentiel), e (vendu).
	var a := joueur("a", [12, 13], 75, 24, 1, 74, 76)
	a.renewal = {"available": true, "negotiation": {"status": "counter", "salary": 1000, "years": 2}}
	var b := joueur("b", [12, 13, 11, 14], 72, 27, 3, 72, 74)
	var c := joueur("c", [11, 14], 60, 28, 1, 60, 62)
	var d := joueur("d", [12, 13], 50, 19, 4, 52, 85)
	var e := joueur("e", [11, 14], 58, 26, 3, 58, 60)
	e.sale = {"pending": {"club": "x"}}
	var model := {"meta": {"season": 1}, "squad": [a, b, c, d, e], "decisions": {"development": {"academy": []}}}
	var p0 := Plan.projection(model, 0)
	check(p0.partis.is_empty() and p0.presents.size() == 5, "Saison actuelle : tout le monde est là")
	var o0 := Plan.ordres(p0)
	var centre: Dictionary = o0[8]
	var ailier: Dictionary = o0[9]
	check(str(centre.liste[0].e.p.id) == "a" and str(centre.liste[1].e.p.id) == "b", "Centre : a puis b titulaires, classés par note")
	var doubles := Plan.titulaires_multiples(o0)
	check(doubles.has("b") and (doubles.b as Array) == [8, 9], "b titulaire au centre et à l'aile : gardé aux deux, signalé")
	check(not doubles.has("a"), "a titulaire à un seul poste")
	check(ailier.liste.size() == 3 and Plan.signes(ailier.liste[0], 9, doubles).any(func(s: Dictionary): return s.rond), "Pastille du titulaire à deux postes sur le terrain")
	var p1 := Plan.projection(model, 1)
	var ids1: Array = p1.presents.map(func(x: Dictionary): return str(x.p.id))
	check("a" in ids1 and p1.presents.filter(func(x: Dictionary): return str(x.p.id) == "a" and x.nego).size() == 1, "Saison prochaine : a reste, prolongation en négociation")
	check(p1.partis.map(func(x: Dictionary): return str(x.p.id)) == ["c", "e"], "Saison prochaine : c (fin de contrat) et e (vendu) partent")
	var o1 := Plan.ordres(p1)
	check((o1[9].partis as Array).size() == 2, "Ailier : deux départs barrés")
	var p2 := Plan.projection(model, 2)
	var o2 := Plan.ordres(p2)
	var d2: Array = o2[8].liste.filter(func(x: Dictionary): return str(x.e.p.id) == "d")
	check(d2.size() == 1 and float(d2[0].note) > float(d2[0].actuelle) and Plan.ecart(d2[0])[0].begins_with("+"), "Jeune à fort potentiel : note estimée en hausse dans deux saisons")
	var b2: Array = o2[8].liste.filter(func(x: Dictionary): return str(x.e.p.id) == "b")
	check(b2.size() == 1 and float(b2[0].note) == Plan.note_future(72, 27, 72, 74, 2), "Note estimée = note_future du joueur")

# ---------------------------------------------------------------- 2. vrai jeu

func etoiles(noeud: Node) -> int:
	var n := 0
	if noeud is Label and ("★" in (noeud as Label).text or "☆" in (noeud as Label).text): n += 1
	for enfant in noeud.get_children(): n += etoiles(enfant)
	return n

func boutons_valider(noeud: Node) -> int:
	var n := 0
	if noeud is Button:
		var t := ((noeud as Button).text + " " + (noeud as Button).tooltip_text).to_lower()
		if "valider" in t or "confirmer" in t: n += 1
	for enfant in noeud.get_children(): n += boutons_valider(enfant)
	return n

func planificateur() -> void:
	app._clear_dialogs()
	app._navigate("Effectif")
	await settle(12)
	await click_id("RosterTab4")
	await settle(6)

func jeu() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await appliquer_taille()
	var export := OS.get_environment("CD_PLAN_EXPORT")
	check(not export.is_empty() and app._command("import", {"text": FileAccess.get_file_as_string(export)}), "Carrière de test importée")
	await wait_worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	app.coach.close()
	var nego := OS.get_environment("CD_PLAN_NEGO")
	var joueur_nego: Array = app.model.squad.filter(func(p: Dictionary): return str(p.id) == nego)
	check(joueur_nego.size() == 1 and Plan.en_negociation(joueur_nego[0]), "Moteur : prolongation en négociation")
	if not captures.is_empty():
		await planificateur()
		await create_timer(2.5).timeout
		if app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
		app.coach.close()
	await planificateur()
	check(int(app.management_ui.roster.get("immersive_tab", 0)) == 4, "Onglet Planificateur ouvert")
	for i in Plan.POSTES.size(): check(found("PlanCarte_%d" % i) != null, "Poste sur le terrain · %s" % Plan.POSTES[i].nom)
	var terrain := found("PlanTerrainPanneau")
	var liste := found("PlanListe")
	check(terrain != null and liste != null and terrain.get_global_rect().end.x < liste.get_global_rect().position.x, "Terrain à gauche, liste du poste à droite")
	check(found("PlanLigne_0") != null, "Liste du poste remplie")
	check(etoiles(app) == 0, "Plus aucune étoile à l'écran")
	check(boutons_valider(app) == 0, "Aucun bouton Valider / Confirmer")
	await capture("actuelle")
	# Clic sur un poste : la liste complète du poste s'affiche tout de suite.
	if await choisir_poste(0):
		check(int(app.management_ui.roster.get("plan_poste", -1)) == 0, "Clic sur le pilier gauche appliqué")
		var titre := found("PlanListeTitre") as Label
		check(titre != null and titre.text == "PILIER GAUCHE", "Liste du pilier gauche à côté du terrain")
	# Saison prochaine : note estimée, négociation comptée, appliquée au clic.
	if await click_id("PlanSaisonOuvrir1"):
		check(int(app.management_ui.roster.get("plan_saison", 0)) == 1, "Saison prochaine appliquée au clic")
		var negos := found("PlanTotalNegos")
		var valeur := negos.find_child("TuileValeur", true, false) as Label if negos != null else null
		check(valeur != null and int(valeur.text) >= 1, "Tuile « en négociation » de la saison prochaine")
		var proj := Plan.projection(app.model, 1)
		var o := Plan.ordres(proj)
		var poste_nego := -1
		for i in o.size():
			if o[i].liste.any(func(x: Dictionary): return str(x.e.p.id) == nego): poste_nego = i; break
		check(poste_nego >= 0, "Le joueur en négociation reste dans l'effectif de la saison prochaine")
		if poste_nego >= 0 and await choisir_poste(poste_nego):
			check(found("PlanNego") != null or found("PlanNegoFond") != null, "Pastille « En négociation » dans la liste du poste")
		await capture("prochaine")
		# Nom -> fiche du joueur.
		var nom: Control = null
		for enfant in found("PlanListe").find_children("PlanNom_*", "Button", true, false): nom = enfant; break
		if nom != null:
			await click(nom.get_global_rect().get_center())
			check(not app.selected_player.is_empty() and found("CarnetSquad") == null, "Nom -> fiche du joueur")
		else: check(false, "Nom cliquable dans la liste")

func run() -> void:
	var t := OS.get_environment("CD_PLAN_TAILLE").split("x")
	if t.size() == 2: taille = Vector2i(int(t[0]), int(t[1]))
	if not captures.is_empty():
		root.mode = Window.MODE_WINDOWED
		root.borderless = true
		DisplayServer.window_set_size(taille)
	root.size = taille
	calculs()
	if not OS.get_environment("CD_PLAN_EXPORT").is_empty(): await jeu()
	print("PLANIFICATEUR %d controles, %d echec" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
