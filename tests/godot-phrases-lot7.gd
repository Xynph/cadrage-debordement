extends SceneTree
## « Phrases à retirer », lot 7 (Sélections, Calendrier, Accueil, Création, Packs, Options + titres de héros du bandeau) :
## plus de slogan sous le nom de l'écran, plus de phrase d'aide ; les pastilles et tuiles créées mènent quelque part,
## les « i » et « ? » portent la règle en infobulle. Godot réel + worker réel, carrière Monde.
## Imprime une ligne PHRASES_LOT7 {checks, failures, destinations}.
const Entry = preload("res://ui/entry_screens.gd")
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []
const SLOGANS := ["Ta semaine commence ici", "Les hommes du projet", "La semaine se gagne ici", "Un groupe, une ambition", "Un club. Un territoire", "Garder une longueur", "Chaque point compte", "Le fil de ta saison", "Le futur porte nos couleurs", "Ils grandissent sous nos couleurs", "Ton confort de jeu", "La voix du club", "Ta place dans le rugby", "Construire dans la durée", "Des décisions qui engagent"]

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

func texts() -> Array[String]:
	var found: Array[String] = []
	for node in app.find_children("*", "Label", true, false): found.append((node as Label).text)
	return found

func contains_text(fragment: String) -> bool:
	for text in texts():
		if text.contains(fragment): return true
	return false

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
	# --- Titres de héros : le nom de l'écran, jamais un slogan ---
	for route: String in ["Bureau", "Effectif", "Préparation", "Plan de jeu", "Vestiaire", "Recrutement", "Club", "Finances", "Classements", "Calendrier", "Formation", "Presse", "Rivalités", "Sélections"]:
		app._navigate(route)
		await settle(8)
		if app.route != route: continue
		if app.heading == null: continue
		var attendu := "LE BUREAU" if route == "Bureau" else route.to_upper()
		if route in ["Bureau", "Préparation", "Sélections"]: check(app.heading.text == attendu, "%s : titre = nom de l'écran (%s)" % [route, app.heading.text])
		for slogan: String in SLOGANS: check(not contains_text(slogan), "%s : plus de slogan « %s »" % [route, slogan])
	# --- Calendrier : tuile, pastille et bouton mènent aux disponibilités ---
	for nom: String in ["InternationalAvailabilityTile", "InternationalAvailabilityDetail", "InternationalAvailabilityOpen"]:
		app.management_ui.international_section = "callups"
		app._navigate("Calendrier")
		await settle(10)
		var noeud := app.find_child(nom, true, false) as Control
		if noeud == null:
			check(nom == "InternationalAvailabilityDetail", "Calendrier : %s présent" % nom)
			continue
		check(noeud is Button, "Calendrier : %s est un bouton" % nom)
		if noeud is Button:
			(noeud as Button).pressed.emit()
			await settle(10)
			check(app.route == "Sélections" and app.management_ui.international_section == "availability", "Calendrier : %s ouvre les disponibilités" % nom)
			check(windows().is_empty(), "Calendrier : %s n'ouvre aucune fenêtre" % nom)
			destinations.append("%s [Calendrier] -> Sélections · disponibilités" % nom)
	app._navigate("Calendrier")
	await settle(8)
	check(not contains_text("Aucun absent confirmé") and not contains_text("Anticiper les fenêtres"), "Calendrier : plus de phrase du bandeau international")
	# --- Sélections : « Groupe au complet » en pastille, sans phrase ---
	app.management_ui.international_section = "callups"
	app._navigate("Sélections")
	await settle(10)
	check(not contains_text("le groupe reste au complet") and not contains_text("Suis les convocations"), "Sélections : plus de phrase d'aide")
	var complet := app.find_child("InternationalCallupsNone", true, false) as Control
	if complet != null:
		check(complet is Button, "Sélections : « Groupe au complet » est une pastille cliquable")
		if complet is Button:
			(complet as Button).pressed.emit()
			await settle(10)
			check(app.management_ui.international_section == "availability", "Sélections : « Groupe au complet » ouvre les disponibilités")
			destinations.append("InternationalCallupsNone [Sélections] -> disponibilités")
	# --- Réglages : « i » au lieu des phrases ---
	app._navigate("Réglages")
	await settle(10)
	check(app.route == "Réglages" and app.find_child("PreferencesSoundInfo", true, false) != null, "Réglages : règle du mixage derrière un « i »")
	check(not contains_text("Les préférences locales") and not contains_text("Le mode calme garde") and not contains_text("ont chacun leur volume"), "Réglages : plus de phrase d'aide")
	var avis := app.find_child("PreferencesPressNotice", true, false)
	check(avis == null or avis is Button, "Réglages : explication des conférences en infobulle")
	# --- Packs ---
	app._navigate("Packs")
	await wait_engine()
	await settle(12)
	check(app.route == "Packs" and app.find_child("PackBaseInfo", true, false) != null, "Packs : règle des packs derrière un « i »")
	check(not contains_text("Retrouve les clubs") and not contains_text("Les packs changent") and not contains_text("Sélectionne la réalité"), "Packs : plus de phrase d'aide")
	# --- Accueil et Création ---
	app._navigate("Accueil")
	await settle(10)
	check(app.find_child("EntryShortcutsHelp", true, false) != null, "Accueil : raccourcis derrière un « ? »")
	check(not contains_text("Prends les rênes. Prépare"), "Accueil : plus de phrase sous l'accroche")
	Entry.begin_creation(app)
	await settle(12)
	check(app.find_child("CreationShortcutsHelp", true, false) != null, "Création : raccourcis derrière un « ? »")
	check(not contains_text("pour découvrir son stade"), "Création : plus de phrase dans le panneau du championnat")
	print("PHRASES_LOT7 ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)
