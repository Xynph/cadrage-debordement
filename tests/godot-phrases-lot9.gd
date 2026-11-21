extends SceneTree
## « Retouches choisies par Léo », lot 9 : Finances › Budget (quatre tuiles chiffre au lieu de quatre lignes), Compétitions
## (légende des zones en pastilles courtes, note du règlement derrière un « i ») et Bureau (légende courte).
## Godot réel + worker réel, carrière Monde. Chaque tuile ou pastille cliquable mène quelque part, sans petite fenêtre.
## Imprime une ligne PHRASES_LOT9 {checks, failures, destinations}.
const Flow = preload("helpers/contextual_flow.gd")
const Finance = preload("res://ui/immersive08/finance_canvas.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

func signature() -> String:
	return "%s|%s|%s" % [app.route, str(app.management_ui.get(Finance.KEY, "")), str(app.management_ui.get(Finance.WAGES_SCOPE_KEY, false))]

func ouvrir_budget() -> void:
	app._clear_dialogs()
	app.management_ui[Finance.KEY] = "budget"
	app.management_ui[Finance.WAGES_SCOPE_KEY] = false
	app._navigate("Bureau")
	await settle()
	app._navigate("Finances")
	await settle(12)

func textes(racine: Node) -> Array[String]:
	var lus: Array[String] = []
	for etiquette in racine.find_children("*", "Label", true, false): lus.append(str((etiquette as Label).text))
	return lus

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}), "Carrière créée")
	await wait_engine()
	await Flow.settle_club_meetings(app, self, check)
	# Finances › Budget : quatre tuiles, plus de lignes « Propriétaire : … / Saison prévue : … ».
	await ouvrir_budget()
	var budget: Dictionary = Finance.U.strategy(app.model).get("finance", {}).get("budget", {})
	check(not budget.is_empty(), "Budget de saison fourni par le moteur")
	for nom in ["Owner", "Payroll", "Result"]: check(app.root_content.find_child("FinanceSeasonBudget" + nom, true, false) != null, "Tuile Budget : " + nom)
	check(app.root_content.find_child("FinanceSeasonBudgetFine", true, false) != null or app.root_content.find_child("FinanceSeasonBudgetBonus", true, false) != null, "Tuile Budget : prime ou amende")
	for ligne in textes(app.root_content):
		check(not ligne.begins_with("Propriétaire :") and not ligne.begins_with("Saison prévue :") and not ligne.begins_with("Masse salariale :") and not ligne.begins_with("Aucune amende"), "Budget : phrase retirée absente (« %s »)" % ligne)
	var resultat := app.root_content.find_child("FinanceSeasonBudgetResultValeur", true, false) as Label
	if resultat != null and budget.get("resultatPrevu") != null:
		var gain := float(budget.resultatPrevu) >= 0.0
		var couleur := resultat.get_theme_color("font_color")
		check(couleur.is_equal_approx(Pieces.VERT if gain else Pieces.ROUGE), "Résultat prévu : %s selon le signe" % ("vert" if gain else "rouge"))
		if float(budget.resultatPrevu) > 0.0: check(resultat.text.begins_with("+"), "Résultat positif écrit avec +")
		if float(budget.resultatPrevu) < 0.0: check(resultat.text.contains("−"), "Résultat négatif écrit avec −")
	var noms: Array[String] = []
	for bouton in app.root_content.find_children("FinanceSeasonBudget*", "Button", true, false):
		if bouton.is_visible_in_tree() and str(bouton.name) not in noms: noms.append(str(bouton.name))
	check(noms.size() >= 6, "Quatre tuiles et les repères de la ligue sont des boutons (%d)" % noms.size())
	for nom in noms:
		await ouvrir_budget()
		var bouton := app.root_content.find_child(nom, true, false) as Button
		if bouton == null: continue
		check(not bouton.disabled and bouton.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s : actif" % nom)
		var avant := signature()
		bouton.pressed.emit()
		await settle(12)
		var apres := signature()
		check(avant != apres, "%s : mène quelque part (%s -> %s)" % [nom, avant, apres])
		check(windows().is_empty(), "%s : aucune fenêtre" % nom)
		destinations.append("%s -> %s" % [nom, apres])
	# Compétitions : pastilles courtes, note derrière un « i ».
	app._navigate("Classements")
	await settle(12)
	var legende: Node = app.root_content.find_child("StandingsZoneLegend", true, false)
	check(legende != null, "Légende des zones affichée")
	if legende != null:
		var pastilles: Array = legende.find_children("StandingsZonePill_*", "Button", true, false)
		check(pastilles.size() > 0, "Pastilles de zones (%d)" % pastilles.size())
		for pastille: Button in pastilles:
			var mot: String = (pastille.find_children("StandingsZoneLegendItem_*", "Label", true, false)[0] as Label).text
			check(mot.length() <= 16 and not mot.contains("finale directe") and not mot.contains("Barrage phase finale"), "Pastille courte : « %s »" % mot)
			pastille.pressed.emit()
			await settle(4)
			var focus := root.gui_get_focus_owner()
			check(focus is Button and str(focus.name).begins_with("StandingsRow_"), "Pastille « %s » : focus sur une ligne du classement" % mot)
			destinations.append("pastille de zone « %s » -> première ligne de la zone" % mot)
	var note: Control = app.root_content.find_child("StandingsZoneNote", true, false)
	check(note != null and not str(note.tooltip_text).is_empty(), "Note du règlement derrière un « i »")
	for ligne in textes(app.root_content): check(not ligne.contains("Pas de montée dans l"), "Classements : note du règlement non écrite")
	# Bureau : légende courte.
	app._navigate("Bureau")
	await settle(12)
	var bureau: Node = app.root_content.find_child("StandingsZoneLegend", true, false)
	if bureau != null:
		for mot: Label in bureau.find_children("StandingsZoneLegendItem_*", "Label", true, false):
			check(not mot.text.contains("Demi-finale directe") and not mot.text.contains("Barrage phase finale"), "Bureau : légende courte (« %s »)" % mot.text)
	check(windows().is_empty(), "Aucune fenêtre ouverte")
	print("PHRASES_LOT9 ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)
