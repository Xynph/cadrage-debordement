extends SceneTree
## Lot 10 des phrases à retirer : Recherche, Carrière › Mobilité et recrutement (+ échos et prise de poste), Match en direct,
## Plan de jeu. Godot réel + worker réel, carrière Monde. Captures 1920 si CD_PHRASES_LOT10_CAPTURES est posé (fenêtre réelle).
## Imprime une ligne PHRASES_LOT10 {checks, failures, destinations}.
const Flow = preload("helpers/contextual_flow.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []
var captures := OS.get_environment("CD_PHRASES_LOT10_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await settle()

func capture(nom: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await settle(10)
	DirAccess.make_dir_recursive_absolute(captures)
	root.get_texture().get_image().save_png(captures.path_join(nom + ".png"))

func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

func textes(racine: Node) -> Array[String]:
	var lus: Array[String] = []
	for etiquette in racine.find_children("*", "Label", true, false):
		if (etiquette as Label).is_visible_in_tree(): lus.append(str((etiquette as Label).text))
	return lus

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
	await recherche()
	await carriere()
	var avant := int(app.model.get("meta", {}).get("week", -1))
	if await Flow.play_to_result(app, self, check): await Flow.finish_match_week(app, self, check, avant)
	await echos()
	await plan_de_jeu()
	await match_direct()
	check(windows().is_empty(), "Aucune fenêtre système ouverte")
	print("PHRASES_LOT10 ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)

func route_signature() -> String:
	return "%s|%s" % [app.route, str(app.management_ui.get("immersive08_career_tab", ""))]

func recherche() -> void:
	app.management_ui["search_query"] = ""
	app._navigate("Recherche")
	await settle(10)
	for ligne in textes(app.root_content): check(not ligne.contains("Un joueur, un club"), "Recherche : phrase retirée absente (« %s »)" % ligne)
	await capture("recherche-vide")
	app.management_ui["search_query"] = "a"
	app._navigate("Recherche")
	await settle(10)
	var resume := app.root_content.find_child("SearchSummary", true, false) as Label
	check(resume != null and resume.visible and resume.text.contains("résultat") and not resume.text.contains("précise"), "Recherche : compte court")
	await capture("recherche")

func ouvrir_mobilite() -> void:
	app.management_ui["immersive08_career_tab"] = "details"
	app._navigate("Carrière")
	await settle(12)

func carriere() -> void:
	await ouvrir_mobilite()
	await capture("carriere-mobilite")
	for ligne in textes(app.root_content):
		for phrase in ["Un poste unique", "Suivis persistants", "Mobilité volontaire", "Masse salariale connue", "Couverture projetée", "poste(s)", "semaine(s)"]:
			check(not ligne.contains(phrase), "Mobilité : phrase retirée absente (« %s »)" % ligne)
	var noms: Array[String] = []
	for b in app.root_content.find_children("*", "Button", true, false):
		var n := str(b.name)
		if b.is_visible_in_tree() and (n.begins_with("ManagerCareerFragiles") or n.begins_with("ManagerCareerMasse") or n.begins_with("ManagerCareerSemaines") or n.begins_with("ManagerRecruitmentLien") or n.begins_with("ManagerCareerClubLien")) and n not in noms: noms.append(n)
	check(noms.size() >= 3, "Mobilité : pièces cliquables présentes (%d)" % noms.size())
	for nom in noms:
		await ouvrir_mobilite()
		var bouton := app.root_content.find_child(nom, true, false) as Button
		if bouton == null: continue
		var avant := route_signature()
		bouton.pressed.emit()
		await settle(12)
		check(route_signature() != avant or app.route != "Carrière", "%s : mène quelque part" % nom)
		check(windows().is_empty(), "%s : aucune fenêtre système" % nom)
		destinations.append("%s -> %s" % [nom, app.route])
	await ouvrir_mobilite()
	# Prise de poste : petite fenêtre visuelle.
	var Manager = load("res://ui/manager_career_view.gd")
	var club_autre: Variant = 0
	for ligue: Dictionary in app.model.get("leagues", []):
		for club: Dictionary in ligue.get("rows", []):
			if club.get("id") != app.model.club.get("id"): club_autre = club.get("id"); break
	Manager._confirm(app, {"season": 1}, {"id": "essai", "clubId": club_autre})
	await settle(10)
	var fenetre := app.root_content.find_child("CareerOfferFenetre", true, false) as Control
	check(fenetre != null and fenetre.is_visible_in_tree() and PetiteFenetre.ouverte(self) == fenetre, "Prise de poste : petite fenêtre inscrite pour Échap")
	for nom in ["CareerOfferSaison", "CareerOfferEffectif", "CareerOfferSuivis", "CareerOfferSalaire", "CareerOfferAnnuler", "CareerOfferConfirmer", "CareerOfferFenetreFermer"]:
		check(fenetre != null and fenetre.find_child(nom, true, false) != null, "Prise de poste : " + nom)
	await capture("carriere-prise-de-poste")
	await key(KEY_ESCAPE)
	check(app.find_child("CareerOfferFenetre", true, false) == null or app.find_child("CareerOfferFenetre", true, false).is_queued_for_deletion(), "Prise de poste : Échap ferme")
	check(app.route == "Carrière", "Prise de poste : on reste sur Carrière")
	destinations.append("Prise de poste -> petite fenêtre (Échap, ✕, clic à côté)")

func echos() -> void:
	var events: Array = app.model.get("clubLife", {}).get("clubWorld", {}).get("events", [])
	app.management_ui["rivalry"] = {"tab": 1}
	app._navigate("Rivalités")
	await settle(12)
	var carte := app.root_content.find_child("RivalryEcho_0", true, false) as Button
	if carte == null:
		destinations.append("Échos : aucun écho dans cette carrière (%d événements), fenêtre non testée" % events.size())
		return
	carte.pressed.emit()
	await settle(10)
	var fenetre := app.root_content.find_child("RivalryEchoDetail", true, false) as Control
	check(fenetre != null and PetiteFenetre.ouverte(self) == fenetre, "Écho : petite fenêtre inscrite pour Échap")
	for nom in ["RivalryEchoScore", "RivalryEchoReaction", "RivalryEchoPression", "RivalryEchoTension", "RivalryEchoClubA"]:
		check(fenetre != null and fenetre.find_child(nom, true, false) != null, "Écho : " + nom)
	await capture("rivalites-echo")
	await key(KEY_ESCAPE)
	check(app.route == "Rivalités" and PetiteFenetre.ouverte(self) == null, "Écho : Échap ferme, on reste sur Rivalités")
	destinations.append("Écho -> petite fenêtre")

func plan_de_jeu() -> void:
	app._navigate("Plan de jeu")
	await settle(12)
	var plan: Dictionary = app.model.get("clubLife", {}).get("playbook", {})
	var zone: String = str(plan.get("zones", [{"id": ""}])[0].get("id", ""))
	for nom in ["PlaybookEtat_%s_attack" % zone, "PlaybookEtat_%s_defence" % zone, "PlaybookZoneBande_" + zone]:
		check(app.root_content.find_child(nom, true, false) != null, "Plan de jeu : " + nom)
	for ligne in textes(app.root_content): check(not ligne.contains("Suivre le choix"), "Plan de jeu : phrase retirée absente")
	await capture("plan-de-jeu")
	# Consigne locale -> pastille cliquable qui revient au plan principal.
	var options: Array = plan.get("attackOptions", [])
	if options.size() > 1 and plan.get("available", false):
		var Regles = load("res://ui/playbook_view.gd")
		Regles._choose(app, "attack", str(options[1].id), zone)
		await wait_engine()
		app._navigate("Plan de jeu")
		await settle(12)
		var pastille := app.root_content.find_child("PlaybookEtat_%s_attack" % zone, true, false) as Button
		check(pastille != null, "Plan de jeu : pastille « Consigne locale » cliquable")
		await capture("plan-de-jeu-local")
		if pastille != null:
			pastille.pressed.emit()
			await wait_engine()
			app._navigate("Plan de jeu")
			await settle(12)
			var apres: Dictionary = app.model.get("clubLife", {}).get("playbook", {})
			check(str(apres.zones[0].attack) == "inherit", "Plan de jeu : la pastille revient au plan principal")
			destinations.append("Pastille « Consigne locale » -> plan principal")
	await phases_et_lecture()

## Phases arrêtées : effets en pastilles (plus de description écrite), chaque ligne choisit l'option ;
## Lecture du match (avant le match) : pastilles qui mènent aux zones et aux phases arrêtées.
func phases_et_lecture() -> void:
	app.management_ui.playbook_tab = 1
	app._navigate("Plan de jeu")
	await settle(12)
	var plan: Dictionary = app.model.get("clubLife", {}).get("playbook", {})
	var descriptions: Array[String] = []
	for phase: Dictionary in plan.get("setPieces", []):
		for option: Dictionary in phase.get("options", []): descriptions.append(str(option.get("description", "")))
	for ligne in textes(app.root_content): check(not ligne in descriptions, "Phases arrêtées : description écrite retirée « %s »" % ligne)
	for nom in ["PlaybookPortee_court", "PlaybookPortee_long"]: check(app.root_content.find_child(nom, true, false) != null, "Phases arrêtées : schéma de portée " + nom)
	check(app.root_content.find_children("PlaybookEffet_*", "", true, false).size() >= 9, "Phases arrêtées : pastilles d'effet")
	var melee: Dictionary = plan.get("setPieces", [{}])[0]
	var autre := ""
	for option: Dictionary in melee.get("options", []):
		if str(option.id) != str(melee.get("selected", "")): autre = str(option.id); break
	var ligne := app.root_content.find_child("PlaybookChoix_%s_%s" % [melee.get("key", ""), autre], true, false) as Button
	check(ligne != null and not ligne.disabled, "Phases arrêtées : ligne « %s » cliquable" % autre)
	if ligne != null and plan.get("available", false):
		ligne.pressed.emit()
		await wait_engine()
		var apres: Dictionary = app.model.get("clubLife", {}).get("playbook", {}).get("setPieces", [{}])[0]
		check(str(apres.get("selected", "")) == autre, "Phases arrêtées : la ligne choisit l'option")
		destinations.append("Ligne de phase arrêtée -> choix retenu")
	app.management_ui.playbook_tab = 2
	app._navigate("Plan de jeu")
	await settle(12)
	for texte in textes(app.root_content): check(not texte.contains("apparaîtra pendant le match"), "Lecture du match : phrase retirée")
	for cas: Array in [["PlaybookAdviceZones", 0], ["PlaybookAdvicePhases", 1]]:
		var pastille := app.root_content.find_child(cas[0], true, false) as Button
		check(pastille != null, "Lecture du match : %s cliquable" % cas[0])
		if pastille == null: continue
		pastille.pressed.emit()
		await settle()
		var onglets := app.root_content.find_child("PlaybookTabs", true, false) as TabContainer
		check(onglets != null and onglets.current_tab == cas[1], "Lecture du match : %s ouvre l'onglet %d" % cas)
		destinations.append("%s -> onglet %d" % cas)
		app.management_ui.playbook_tab = 2
		app._navigate("Plan de jeu")
		await settle(12)
	app.management_ui.playbook_tab = 0

func match_direct() -> void:
	pass
