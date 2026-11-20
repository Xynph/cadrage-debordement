extends SceneTree
## Écran « Finances » (revue DA du 19/11/2026, variante 1) : verdict en mots, colonne de verdict sur chaque onglet,
## tout ce qui a l'air cliquable change d'écran / d'onglet, aucune fenêtre ouverte par un clic, aucun or (réservé à
## Continuer), valeurs lues dans les données du club. Carrière world-champ préparée par le .cjs.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const Finance = preload("res://ui/immersive08/finance_canvas.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const TABS := ["summary", "cash", "wages", "transfers", "budget", "clubs"]
## Zones cliquables dont le clic doit mener ailleurs (écran ou onglet différent) ; les tris et pages restent sur place.
const PREFIXES := ["FinanceMetricLink", "FinanceVerdictLink", "FinanceWatch", "FinanceDueRow", "FinanceAllocationRow", "FinanceLedgerRow_", "FinanceCommitmentLink", "FinanceAdjustBudget", "FinanceRecruitment", "FinanceTransferContracts", "FinanceBudgetDecisions", "FinanceTotalLink"]
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_FINANCES_ARTIFACTS")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
func settle() -> void:
	for i in 12: await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)
func named(id: String) -> Control: return app.body.find_child(id, true, false)
func open_windows() -> Array[String]:
	var found: Array[String] = []
	for node: Node in root.find_children("*", "Window", true, false):
		if (node as Window).visible: found.append(str(node.name))
	return found
func gold_used(node: Node) -> int:
	var count := 0
	for control: Node in node.find_children("*", "Control", true, false):
		if control is Label:
			var color: Color = control.get_theme_color("font_color")
			if color.is_equal_approx(Charte.OR) or color.is_equal_approx(Charte.OR_VIF): count += 1
		for style_name: String in ["panel", "normal", "hover", "pressed", "focus"]:
			var style := (control as Control).get_theme_stylebox(style_name) as StyleBoxFlat
			if style != null and (style.bg_color.is_equal_approx(Charte.OR) or style.bg_color.is_equal_approx(Charte.OR_VIF) or style.border_color.is_equal_approx(Charte.OR)): count += 1
	return count
func ouvrir(tab: String) -> void:
	app._clear_dialogs()
	app.management_ui[Finance.KEY] = tab
	app.management_ui[Finance.WAGES_SCOPE_KEY] = false
	app._navigate("Bureau")
	await settle()
	app._navigate("Finances")
	await settle()
func etat() -> String:
	return "%s|%s|%s" % [app.route, str(app.management_ui.get(Finance.KEY, "")), str(app.management_ui.get(Finance.WAGES_SCOPE_KEY, false))]
func cliquables(tab: String) -> Array[String]:
	var noms: Array[String] = []
	for bouton: Node in app.body.find_children("*", "Button", true, false):
		var nom := str(bouton.name)
		if not (bouton as Button).is_visible_in_tree() or (bouton as Button).disabled: continue
		for prefixe in PREFIXES:
			if nom.begins_with(prefixe) and not (tab == "budget" and nom == "FinanceVerdictLink"):
				noms.append(nom)
				break
	return noms

func run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("import", {"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	var fenetres_avant := open_windows()
	# Verdict en mots + colonne fixe sur chaque onglet.
	for tab in TABS:
		await ouvrir(tab)
		var vue := app.find_child("ImmersiveFinance", true, false)
		check(vue != null and vue.is_visible_in_tree(), "Finances affichées · onglet " + tab)
		var mot := named("FinanceVerdictWord") as Label
		check(mot != null and mot.text in ["SAINE", "SOUS TENSION", "EN DANGER", "INDISPONIBLE"], "Verdict écrit en mots sur l'onglet %s : « %s »" % [tab, mot.text if mot != null else ""])
		check(named("FinanceVerdictSentence") != null and named("FinanceMetric0") != null and named("FinanceMetric1") != null and named("FinanceMetric2") != null, "Verdict, trésorerie, budget de transferts et marge visibles · " + tab)
		check(gold_used(vue) == 0, "Aucun or dans l'onglet " + tab)
		check(open_windows() == fenetres_avant, "Aucune fenêtre ouverte par l'onglet " + tab)
		var verdict := Finance.verdict(app, app.model.get("finance", {}), U.strategy(app.model).get("finance", {}))
		check(int(verdict.palier) in [-1, 0, 1, 2], "Palier du verdict dans 0..2 (ou inconnu)")
	# Seuils du verdict (design/ux/17-finances.md §13) sur des valeurs posées.
	var seuils := [[{"weeklyIncome": 10, "weeklyCosts": 4, "baseForecast": 5}, 0], [{"weeklyIncome": 4, "weeklyCosts": 10, "baseForecast": 5}, 1], [{"weeklyIncome": 4, "weeklyCosts": 10, "baseForecast": -5}, 2]]
	for cas: Array in seuils:
		check(int(Finance.verdict(app, {"cash": 100}, cas[0]).palier) == int(cas[1]), "Verdict %d pour %s" % [cas[1], str(cas[0])])
	# Tout ce qui a l'air cliquable mène ailleurs, sans fenêtre.
	for tab in TABS:
		await ouvrir(tab)
		var noms := cliquables(tab)
		if tab == "summary": check(noms.size() >= 8, "La Synthèse offre au moins huit zones cliquables (%d)" % noms.size())
		for nom in noms:
			await ouvrir(tab)
			var bouton := named(nom) as Button
			if bouton == null: continue
			var avant := etat()
			bouton.pressed.emit()
			await settle()
			check(etat() != avant, "« %s » (onglet %s) mène ailleurs (%s)" % [nom, tab, etat()])
			check(open_windows() == fenetres_avant, "Aucune fenêtre ouverte par « %s » : %s" % [nom, str(open_windows())])
	# Ctrl+Tab : onglet suivant.
	await ouvrir("summary")
	var touche := InputEventKey.new()
	touche.keycode = KEY_TAB
	touche.ctrl_pressed = true
	touche.pressed = true
	app.get_viewport().push_input(touche)
	await settle()
	check(str(app.management_ui.get(Finance.KEY, "")) == "cash", "Ctrl+Tab ouvre l'onglet suivant")
	# Trésorerie : mouvements du journal paginés, Précédent / Suivant.
	await ouvrir("cash")
	check(named("FinanceLedger") != null and named("FinanceLedgerRow_0") != null or (app.model.get("finance", {}).get("ledger", []) as Array).is_empty(), "Journal des flux : lignes cliquables")
	# Salaires : noms de joueurs, clic = fiche complète.
	await ouvrir("wages")
	var noms_joueurs: Array = app.body.find_children("FinancePlayerName_*", "Button", true, false)
	check(noms_joueurs.size() > 0, "Salaires : noms de joueurs cliquables")
	if noms_joueurs.size() > 0:
		(noms_joueurs[0] as Button).pressed.emit()
		await settle()
		check(app.route == "Effectif" and open_windows() == fenetres_avant, "Un nom de joueur ouvre la fiche complète (%s)" % app.route)
	# Courbe : graduations rondes, le zéro (ligne pointillée) est une graduation.
	await ouvrir("summary")
	var courbe := named("FinanceLedgerPlot")
	if courbe != null and not (courbe.get("operations") as Array).is_empty():
		check(courbe.call("graduations").any(func(v: float): return is_zero_approx(v)), "Courbe : le zéro est une graduation (%s)" % str(courbe.call("graduations")))
	# 1280 × 720 : la phrase du verdict ne chevauche aucun autre texte du bloc (Synthèse et colonne fixe).
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	for tab in ["summary", "cash"]:
		await ouvrir(tab)
		var phrase := named("FinanceVerdictSentence") as Label
		var bloc := named("FinanceVerdict")
		check(phrase != null and bloc != null, "Verdict présent à 1280 · " + tab)
		if phrase == null or bloc == null: continue
		var zone_phrase := Rect2(phrase.global_position, Vector2(phrase.size.x, phrase.get_line_count() * phrase.get_line_height()))
		for texte: Node in bloc.find_children("*", "Label", true, false):
			if texte == phrase or not (texte as Label).is_visible_in_tree() or (texte as Label).text.strip_edges().is_empty(): continue
			var lignes := maxi(1, (texte as Label).get_line_count()) if (texte as Label).autowrap_mode != TextServer.AUTOWRAP_OFF else 1
			var zone_texte := Rect2((texte as Label).global_position, Vector2((texte as Label).size.x, lignes * (texte as Label).get_line_height()))
			check(not zone_phrase.grow(-1).intersects(zone_texte.grow(-1)), "1280 · %s : la phrase du verdict chevauche « %s »" % [tab, (texte as Label).text])
	if failures.is_empty(): print("OK finances-ecran : %d vérifications" % checks)
	else: printerr("ÉCHECS : %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
