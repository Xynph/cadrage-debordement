extends SceneTree
## « Phrases à retirer », lot Club / Formation / Vestiaire › Entretiens : chaque tuile ou pastille créée à la place d'une phrase
## qui ressemble à un bouton en est un, change d'écran (jamais de petite fenêtre) ; les autres restent de simples affichages.
## Godot réel + worker réel, carrière Monde. Imprime une ligne PHRASES_LOT3 {checks, failures, destinations}.
const Flow = preload("helpers/contextual_flow.gd")
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

func signature() -> String:
	var historique := int(app.navigation_controller.history.size()) if app.navigation_controller != null and "history" in app.navigation_controller else 0
	return "%s|%s|%s|%d" % [app.route, str(app.management_ui.get("immersive08_club_tab", "")), str(app.management_ui.get("immersive08_strategy_tab", "")), historique]

func ouvrir(ecran: String) -> void:
	match ecran:
		"club": app.management_ui["immersive08_club_tab"] = "overview"; app._navigate("Club")
		"infra": app.management_ui["immersive08_club_tab"] = "infrastructure"; app._navigate("Club")
		"histoire": app.management_ui["immersive08_club_tab"] = "history"; app._navigate("Club")
		"formation": app._navigate("Formation")
		"vestiaire": app.management_ui["immersive08_locker_tab"] = "people"; app._navigate("Vestiaire")
	await settle(10)

## Chaque nœud nommé selon `motif` : s'il est un bouton, il mène quelque part ; sinon c'est un affichage neutre (ni bouton, ni curseur main).
func parcourir(ecran: String, motifs: Array) -> void:
	for motif: String in motifs:
		await ouvrir(ecran)
		var noms: Array[String] = []
		for noeud in app.root_content.find_children(motif, "Control", true, false):
			if str(noeud.name) not in noms: noms.append(str(noeud.name))
		for nom in noms:
			await ouvrir(ecran)
			var noeud := app.root_content.find_child(nom, true, false) as Control
			if noeud == null: continue
			if noeud is Button:
				check(not (noeud as Button).disabled, "%s : actif" % nom)
				var avant := signature()
				(noeud as Button).pressed.emit()
				await settle(10)
				var apres := signature()
				check(avant != apres, "%s : mène quelque part (%s -> %s)" % [nom, avant, apres])
				check(windows().is_empty(), "%s : aucune fenêtre" % nom)
				destinations.append("%s [%s] -> %s" % [nom, ecran, apres])
			else:
				check(noeud.mouse_default_cursor_shape == Control.CURSOR_ARROW, "%s : affichage neutre, curseur ordinaire" % nom)

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
	await parcourir("club", ["ClubLastReview", "ClubDecideBadge*", "ClubDecideTile*"])
	await parcourir("infra", ["ClubFacilityNextLevel", "ClubFacilityReason", "ClubStadiumFigure_*"])
	await parcourir("histoire", ["ClubPalmaresVide", "ClubHistoryNo*"])
	await parcourir("formation", ["AcademyContract*", "AcademyCount", "AcademyStarLegend", "AcademyNoSelection", "AcademyNoDecision"])
	await parcourir("vestiaire", ["RelationshipEventContext", "RelationshipTile*", "RelationshipInjury*", "RelationshipNoEvent"])
	# Aucune phrase d'aide ne revient : les « i » et « ? » portent la règle en infobulle.
	await ouvrir("formation")
	check(app.root_content.find_child("AcademyShortcuts", true, false) != null, "Raccourcis derrière un « ? »")
	await ouvrir("vestiaire")
	check(app.root_content.find_child("ChapterInfo", true, false) != null, "Règle des entretiens derrière un « i »")
	print("PHRASES_LOT3 ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)
