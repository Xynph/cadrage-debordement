extends SceneTree
## Grands moments du match 3D (18 novembre 2026), sans moteur ni carrière :
##  - essai : marqueur lu dans la légende, bandeau « ESSAI » lisible en 720p et 1080p, ralenti qui
##    part bas et revient à la vitesse réelle avant la fin du moment (image tenue) ;
##  - mi-temps et fin de match : clé de sortie par rencontre, plan large de tout le terrain, puis
##    les joueurs marchent vers le tunnel (jamais au sprint) et restent dans le plan large ;
##  - ralenti de la vue : à 0,35, les joueurs avancent environ trois fois moins vite.
## Joueurs : le temps fort de la 75e minute (tests/fixtures/match-arret-75.json), 30 joueurs.
## Parcours réel (carrière Monde) : godot-match-temps-forts.gd, modes « score_essai » et « grands_moments ».

const View = preload("res://match_view.gd")
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func image(fixture: Dictionary, scene: Dictionary, upto: int, paused: bool) -> Dictionary:
	var events: Array = (fixture.events as Array).slice(0, maxi(0, upto + 1))
	return {"scene": scene, "teams": fixture.teams, "events": events, "paused": paused, "finished": false, "atBreak": false}


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	essai_textes()
	await bandeau()
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/fixtures/match-arret-75.json")))
	check(fixture is Dictionary and fixture.get("depart") is Dictionary and fixture.get("plans") is Array, "Temps fort de la 75e minute lisible")
	if fixture is Dictionary:
		await sortie(fixture)
		await ralenti(fixture)
	print("MATCH_GRANDS_MOMENTS_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Marqueur, ralenti et clés de sortie : fonctions pures de la régie.
func essai_textes() -> void:
	check(Regie.marqueur_essai("TLS · Essai de Jean Dupont sur ballon porté.") == "Jean Dupont", "Marqueur d'un essai sur ballon porté : " + Regie.marqueur_essai("TLS · Essai de Jean Dupont sur ballon porté."))
	check(Regie.marqueur_essai("ABC · Essai de J. Martin, transformé. 7 – 0.") == "J. Martin", "Marqueur lu dans le journal (initiale, transformation, score) : " + Regie.marqueur_essai("ABC · Essai de J. Martin, transformé. 7 – 0."))
	check(Regie.marqueur_essai("Essai de Paul Durand sur mêlée, transformation manquée. 5 – 0.") == "Paul Durand", "Marqueur d'un essai sur mêlée")
	check(Regie.marqueur_essai("XV · Essai décisif de Léo Garnier. 24 – 21.") == "Léo Garnier", "Marqueur d'un essai décisif")
	check(Regie.marqueur_essai("Essai.") == "" and Regie.marqueur_essai("Touche pour TLS.") == "", "Sans marqueur nommé : rien d'inventé")
	# Ralenti : creux au début du moment, vitesse réelle avant la fin (image tenue), jamais plus vite.
	check(is_equal_approx(Regie.ralenti_essai(Regie.ESSAI_MOMENT), Regie.ESSAI_RALENTI), "Le moment d'essai part au ralenti (%.2f)" % Regie.ralenti_essai(Regie.ESSAI_MOMENT))
	check(Regie.ESSAI_RALENTI >= 0.2 and Regie.ESSAI_RALENTI <= 0.6, "Ralenti lisible, ni figé ni imperceptible (%.2f)" % Regie.ESSAI_RALENTI)
	check(is_equal_approx(Regie.ralenti_essai(Regie.ESSAI_MOMENT * 0.15), 1.0) and is_equal_approx(Regie.ralenti_essai(0.0), 1.0), "Vitesse réelle à la fin du moment (image tenue avant la transformation)")
	var precedent := 0.0
	var monotone := true
	for k in 23:
		var f := Regie.ralenti_essai(Regie.ESSAI_MOMENT * (1.0 - k / 22.0))
		monotone = monotone and f >= precedent - 0.0001 and f <= 1.0
		precedent = f
	check(monotone, "Le ralenti ne fait que revenir vers la vitesse réelle")
	check(Regie.ESSAI_MOMENT >= 1.5 and Regie.ESSAI_MOMENT <= 2.5, "Pause d'essai de 1,5 à 2,5 s avant la transformation (%.1f s)" % Regie.ESSAI_MOMENT)
	check(Regie.ESSAI_BANDEAU >= Regie.ESSAI_MOMENT, "Le bandeau reste au moins le temps du moment d'essai")
	var duree_sortie: float = Regie.SORTIE_LARGE + Regie.SORTIE_MARCHE
	check(Regie.SORTIE_LARGE >= 1.0 and Regie.SORTIE_MARCHE >= 3.0 and duree_sortie <= 8.0, "Sortie : plan large puis marche, quelques secondes en tout (%.1f s)" % duree_sortie)
	var direct := {"rencontre": "2026:3:league:4-9"}
	check(Regie.cle_sortie({"direct": direct, "atBreak": true}) == "2026:3:league:4-9|mi-temps", "Clé de la sortie de mi-temps")
	check(Regie.cle_sortie({"direct": direct, "atBreak": true, "finished": true}) == "2026:3:league:4-9|fin", "Clé de la sortie de fin de match (prioritaire)")
	check(Regie.cle_sortie({"direct": direct, "paused": true}).is_empty() and Regie.cle_sortie({"atBreak": true}).is_empty(), "Pas de sortie en cours de jeu, ni sans projection du moteur")


## Bandeau « ESSAI » : marqueur, équipe, tailles lisibles, sous le score, ne capte pas la souris.
func bandeau() -> void:
	var cadre: PanelContainer = Regie.construire_bandeau()
	root.add_child(cadre)
	check(cadre.mouse_filter == Control.MOUSE_FILTER_IGNORE and not cadre.visible, "Bandeau caché au départ, transparent à la souris")
	for hauteur: float in [720.0, 1080.0]:
		Regie.habiller_bandeau(cadre, "ESSAI", "Jean Dupont", "Toulouse Capitole XV", hauteur)
		cadre.show()
		await process_frame
		var titre: Label = cadre.find_child("MatchMomentTitre", true, false)
		var nom: Label = cadre.find_child("MatchMomentNom", true, false)
		var equipe: Label = cadre.find_child("MatchMomentEquipe", true, false)
		check(titre != null and nom != null and equipe != null, "Trois lignes de bandeau")
		if titre == null or nom == null or equipe == null: continue
		var tailles: Dictionary = Regie.tailles_bandeau(hauteur)
		check(titre.text == "ESSAI" and nom.text == "Jean Dupont" and equipe.text == "Toulouse Capitole XV" and nom.visible and equipe.visible, "%d p : ESSAI, marqueur et équipe écrits" % int(hauteur))
		check(titre.get_theme_font_size("font_size") == int(tailles.titre) and int(tailles.titre) >= 40, "%d p : titre lisible (%d points)" % [int(hauteur), titre.get_theme_font_size("font_size")])
		check(nom.get_theme_font_size("font_size") >= 20 and equipe.get_theme_font_size("font_size") >= 16, "%d p : marqueur et équipe lisibles (%d et %d points)" % [int(hauteur), nom.get_theme_font_size("font_size"), equipe.get_theme_font_size("font_size")])
		check(cadre.size.x <= 1280.0 * hauteur / 720.0 and cadre.size.y <= hauteur * 0.3, "%d p : bandeau compact (%s)" % [int(hauteur), str(cadre.size)])
	check(Regie.tailles_bandeau(1080.0).titre > Regie.tailles_bandeau(720.0).titre and Regie.tailles_bandeau(4320.0).titre <= 110, "Taille du titre suit l'écran, sans excès")
	Regie.habiller_bandeau(cadre, "MI-TEMPS", "Toulouse   12 — 7   Bordeaux", "", 720.0)
	await process_frame
	var vide: Label = cadre.find_child("MatchMomentEquipe", true, false)
	check(vide != null and not vide.visible, "Ligne vide masquée (bandeau de mi-temps)")
	cadre.queue_free()
	await process_frame


func distance_sol(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Mi-temps : plan large, puis marche vers le tunnel.
func sortie(fixture: Dictionary) -> void:
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(true)
	view.set_live_cadence(1)
	await process_frame
	view.set_camera("tv")
	var plan: Dictionary = (fixture.plans as Array)[-1]
	view.apply_frame(image(fixture, fixture.depart, int(fixture.debut) - 1, true))
	view.apply_frame(image(fixture, plan.scene, int(plan.index), false))
	for k in 20: view._process(STEP)
	check(view._actors.size() >= 20, "Joueurs sur le terrain (%d)" % view._actors.size())
	# Plan large (le même qu'avant ce lot, posé par la régie à la mi-temps).
	view.set_plan_large(true)
	view._process(STEP)
	var camera: Camera3D = view._camera
	var attendu: Vector3 = View.PLAN_LARGE_VISE + View.PLAN_LARGE_OFFSET.normalized() * View.PLAN_LARGE_RECUL
	check(view.plan_large() and is_equal_approx(camera.fov, View.PLAN_LARGE_CHAMP) and camera.global_position.distance_to(attendu) < 0.5, "Plan large : tout le terrain vu d'au-dessus de la tribune (%s)" % str(camera.global_position))
	var departs: Dictionary = {}
	for id: String in view._actors: departs[id] = (view._actors[id].node as Node3D).position
	view.sortir_du_terrain()
	check(view.sortie and view._carrier_id.is_empty() and not view._ball_attached, "Sortie : plus de porteur, ballon laissé au sol")
	var pointe := 0.0
	var precedent: Dictionary = departs.duplicate()
	var duree: float = Regie.SORTIE_MARCHE
	var t := 0.0
	while t < duree:
		view._process(STEP)
		t += STEP
		for id: String in view._actors:
			var at: Vector3 = (view._actors[id].node as Node3D).position
			pointe = maxf(pointe, distance_sol(at, precedent[id]) / STEP)
			precedent[id] = at
	var rapproches := 0
	var de_face := 0
	var parcouru := 0.0
	var dans_le_plan := 0
	for id: String in view._actors:
		var entry: Dictionary = view._actors[id]
		var at: Vector3 = (entry.node as Node3D).position
		var but: Vector3 = View.place_de_sortie(departs[id], int(entry.side))
		check(distance_sol(entry.target, but) < 0.01, "%s marche vers l'entrée du tunnel de son camp" % id)
		if distance_sol(at, but) < distance_sol(departs[id], but) - 1.0 or distance_sol(at, but) < 0.5: rapproches += 1
		parcouru += distance_sol(at, departs[id])
		var vers := but - at
		if vers.length() < 0.5 or absf(angle_difference((entry.node as Node3D).rotation.y, atan2(vers.x, vers.z))) < 0.6: de_face += 1
		if camera.is_position_in_frustum(at + Vector3.UP): dans_le_plan += 1
	var n: int = maxi(1, view._actors.size())
	check(rapproches == view._actors.size(), "Tous les joueurs se rapprochent du tunnel (%d sur %d)" % [rapproches, view._actors.size()])
	check(parcouru / n >= 4.0, "Les joueurs marchent vraiment (%.1f m en moyenne en %.1f s)" % [parcouru / n, duree])
	check(pointe <= View.ALLURE_SORTIE * 1.5 + 0.3, "Marche, jamais de course (pointe %.2f m/s)" % pointe)
	check(de_face >= int(n * 0.85), "Ils marchent face au tunnel (%d sur %d)" % [de_face, n])
	check(dans_le_plan >= int(n * 0.9), "Ils restent dans le plan large (%d sur %d)" % [dans_le_plan, n])
	# La prochaine image du moteur reprend la main.
	view.apply_frame(image(fixture, plan.scene, int(plan.index), false))
	check(not view.sortie, "Une nouvelle image met fin à la sortie")
	view.set_plan_large(false)
	view.queue_free()
	await process_frame


## Ralenti de présentation : les joueurs avancent moins vite, puis reprennent leur allure.
func ralenti(fixture: Dictionary) -> void:
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_live_cadence(1)
	await process_frame
	var plan: Dictionary = (fixture.plans as Array)[-1]
	view.apply_frame(image(fixture, plan.scene, int(plan.index), true))
	view._process(STEP)
	view.sortir_du_terrain()
	# Joueur le plus loin du tunnel : trajet en ligne droite à allure constante.
	var choisi := ""
	var loin := 0.0
	for id: String in view._actors:
		var d := distance_sol((view._actors[id].node as Node3D).position, view._actors[id].target)
		if d > loin:
			loin = d
			choisi = id
	check(loin > 25.0, "Un joueur loin du tunnel (%.1f m)" % loin)
	if choisi.is_empty():
		view.queue_free()
		return
	for k in 10: view._process(STEP)
	var actor: Node3D = view._actors[choisi].node
	view.set_ralenti(Regie.ESSAI_RALENTI)
	var a := actor.position
	for k in 30: view._process(STEP)
	var lent := distance_sol(actor.position, a)
	view.set_ralenti(1.0)
	a = actor.position
	for k in 30: view._process(STEP)
	var normal := distance_sol(actor.position, a)
	check(normal > 1.0 and lent < normal * (Regie.ESSAI_RALENTI + 0.12) and lent > normal * (Regie.ESSAI_RALENTI - 0.12), "Au ralenti, le joueur avance %.2f fois moins (%.2f m contre %.2f m)" % [normal / maxf(lent, 0.001), lent, normal])
	view.set_ralenti(NAN)
	check(is_equal_approx(view.ralenti, 1.0), "Ralenti invalide : vitesse réelle")
	view.set_ralenti(0.0)
	check(view.ralenti > 0.0, "Jamais d'image figée par le ralenti")
	view.set_ralenti(1.0)
	view.queue_free()
	await process_frame
