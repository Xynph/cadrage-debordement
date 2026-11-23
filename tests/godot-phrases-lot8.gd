extends SceneTree
## « Phrases à retirer », lot 8 : Match (avant-match), Délégation, Composition, Comparateur, Centre, Fiche joueur, Mini-fiche,
## Salle du conseil. Les phrases d'aide ne reviennent pas ; les « ? » et « i » portent la règle en infobulle (curseur d'aide,
## jamais une fenêtre) ; les pastilles de la délégation restent de simples affichages. Godot réel + worker réel, carrière Monde.
## Imprime une ligne PHRASES_LOT8 {checks, failures, destinations}.
const Flow = preload("helpers/contextual_flow.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

## Aucun texte visible ne commence par l'une de ces phrases d'aide.
func sans_phrase(racine: Node, debuts: Array, ecran: String) -> void:
	for noeud in racine.find_children("*", "Label", true, false):
		var texte := (noeud as Label).text
		for debut: String in debuts:
			check(not texte.begins_with(debut), "%s : la phrase « %s… » est retirée" % [ecran, debut])

## Un « ? » ou un « i » : affichage d'aide (curseur d'aide), infobulle non vide, aucune fenêtre.
func aide(racine: Node, nom: String, ecran: String) -> void:
	var rond := racine.find_child(nom, true, false) as Control
	check(rond != null, "%s : %s présent" % [ecran, nom])
	if rond == null: return
	check(not rond.tooltip_text.strip_edges().is_empty(), "%s : %s porte la règle en infobulle" % [ecran, nom])
	check(rond.mouse_default_cursor_shape == Control.CURSOR_HELP or rond.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s : %s a un curseur d'aide ou de clic" % [ecran, nom])
	check(not (rond is Button), "%s : %s n'ouvre pas d'écran (simple repère)" % [ecran, nom])
	check(windows().is_empty(), "%s : aucune fenêtre" % ecran)
	destinations.append("%s [%s] -> infobulle" % [nom, ecran])

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}), "Carrière créée")
	await wait_engine()
	await Flow.settle_club_meetings(app, self, check)
	# Centre
	app._navigate("Centre"); await settle(10)
	var centre: Node = app.root_content
	sans_phrase(centre, ["Les chemins de la progression", "La relève se prépare", "Détection, mentorat et compétition junior ouvriront", "Mener la campagne", "Associer un Espoir", "Préparer les rencontres juniors", "Leur progression, leurs promotions", "La capacité tient compte"], "Centre")
	for nom in ["CentreAideDetection", "CentreAideMentoring", "CentreAideJunior", "CentreAidePlaces"]: aide(centre, "Info_" + nom, "Centre")
	# Comparateur
	var effectif: Array = app.model.get("squad", [])
	check(effectif.size() >= 2, "Effectif d'au moins deux joueurs")
	if effectif.size() >= 2:
		app.management_ui.compare = [str(effectif[0].get("id")), str(effectif[1].get("id"))]
		app._navigate("Effectif"); await settle(8)
		load("res://ui/immersive08/comparateur_canvas.gd").ouvrir(app); await settle(10)
		check(app.route == "Comparateur", "Comparateur ouvert")
		sans_phrase(app.root_content, ["Jusqu’à trois joueurs"], "Comparateur")
		aide(app.root_content, "Info_ComparateurAide", "Comparateur")
		# Fiche joueur et mini-fiche
		app._navigate("Effectif"); await settle(10)
		var lien: Array = app.root_content.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.has_meta("entity_id") and str(b.get_meta("entity_id", "")) != "")
		if not lien.is_empty():
			var fiche = MiniFiche.montrer(app, str(lien[0].get_meta("entity_id", "")), "squad", lien[0]); await settle(6)
			check(fiche != null, "Mini-fiche affichée")
			if fiche != null: sans_phrase(fiche, ["Clic :", "I : aperçu", "36 attributs, note"], "Mini-fiche")
			MiniFiche.cacher(app)
	# Composition
	app._navigate("Composition"); await settle(12)
	sans_phrase(app.root_content, ["Projection du staff · se recalcule", "Les n° 16 à 18", "la règle compte", "Chaque poste a au moins", "Loi 3 : une feuille", "Loi 3 : il faut"], "Composition")
	# Match : avant-match puis délégation
	check(await Flow.prepare_match_day(app, self, check), "Jour de match atteint")
	app._navigate("Match"); await settle(12)
	var avant: Control = app.match_screen.find_child("MatchOpening", true, false) if app.match_screen != null else null
	check(avant != null and avant.is_visible_in_tree(), "Avant-match affiché")
	if avant != null:
		sans_phrase(avant, ["Condition des titulaires", "Pas encore de statistiques", "Entrée", "élément suivant", "Leur plan de jeu n'est pas encore connu"], "Match")
		aide(avant, "MatchOpenHelp", "Match")
		avant.ouvrir_page("delegation"); await settle(10)
		var page := app.find_child("MatchDelegationPage", true, false)
		check(page != null, "Page de délégation ouverte")
		if page != null:
			sans_phrase(page, ["L'adjoint joue la rencontre", "Le staff refait la feuille avant"], "Délégation")
			for icone in ["people", "rating", "lock"]:
				var pastille := page.find_child("MatchPastille_" + icone, true, false) as Control
				check(pastille != null and not pastille.tooltip_text.is_empty() and not (pastille is Button), "Délégation : pastille %s en affichage avec infobulle" % icone)
				if pastille != null: check(pastille.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND, "Délégation : pastille %s sans curseur main" % icone)
	print("PHRASES_LOT8 ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)
