extends SceneTree
## Écran « Finances » (revue DA du 19/11/2026 ; Synthèse « façon Effectif » du 22/11/2026, option B : cinq tuiles,
## trois colonnes de listes, solde) : verdict en mots, colonne de verdict sur les autres onglets,
## tout ce qui a l'air cliquable change d'écran / d'onglet, aucune fenêtre ouverte par un clic, aucun or (réservé à
## Continuer), valeurs lues dans les données du club. Carrière world-champ préparée par le .cjs.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const Finance = preload("res://ui/immersive08/finance_canvas.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const TABS := ["summary", "cash", "wages", "transfers", "budget", "clubs"]
## Zones cliquables dont le clic doit mener ailleurs (écran ou onglet différent) ; les tris et pages restent sur place.
const PREFIXES := ["FinanceSeasonBudget", "FinanceMetricLink", "FinanceVerdictLink", "FinanceWatch", "FinanceDueRow", "FinanceAllocationRow", "FinanceLedgerRow_", "FinanceCommitmentLink", "FinanceAdjustBudget", "FinanceRecruitment", "FinanceTransferContracts", "FinanceBudgetDecisions", "FinanceTotalLink", "FinanceProjection", "FinanceMargin", "FinancePlayersPayroll", "FinanceForecastWeeks", "FinanceNothingCommitted", "FinanceWagesScope", "FinanceWagesSeasonEnd", "FinanceWagesCount", "FinanceVerdictMargin", "FinanceVerdictAutonomy", "FinanceMetric0", "FinanceMetric2", "FinanceTransfersLeft", "FinanceTransferRow"]
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
## Aplats dorés : fonds de bouton ou de panneau (tous états). Le texte, le contour et l'anneau de focus dorés sont permis.
func gold_used(node: Node) -> int:
	var count := 0
	for control: Node in node.find_children("*", "Control", true, false):
		for style_name: String in ["panel", "normal", "hover", "pressed", "disabled"]:
			var style := (control as Control).get_theme_stylebox(style_name) as StyleBoxFlat
			if style != null and style.bg_color.a > .05 and (style.bg_color.is_equal_approx(Charte.OR) or style.bg_color.is_equal_approx(Charte.OR_VIF)):
				count += 1
				break
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
		check(named("Info_Palier0") != null and named("Info_Palier2") != null and named("FinanceMetric0") != null and named("FinanceMetric1") != null and named("FinanceMetric2") != null, "Verdict, trésorerie, budget de transferts et marge visibles · " + tab)
		check(gold_used(vue) == 0, "Aucun aplat doré dans l'onglet " + tab+" (Continuer le porte seul)")
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
		if tab == "summary":
			# Bandeau de tuiles (sans sous-tuile), puis lignes des trois colonnes : tout mène ailleurs.
			for tuile in ["FinanceMetric0", "FinanceProjectionEnd", "FinanceMetric2", "FinanceForecastWeeksLien"]: check(tuile in noms, "Synthèse : « %s » est cliquable" % tuile)
			check(not noms.filter(func(n: String): return n.begins_with("FinanceMarginIncome") or n.begins_with("FinanceMarginCosts")).is_empty(), "Synthèse : recettes et charges en lignes cliquables")
			check(not noms.filter(func(n: String): return n.begins_with("FinanceTransferRow")).is_empty(), "Synthèse : lignes du budget de transferts cliquables")
			check(not noms.filter(func(n: String): return n.begins_with("FinanceDueRow")).is_empty(), "Synthèse : échéances en lignes cliquables")
			check(named("FinanceSolde") != null, "Synthèse : courbe « Solde sur 12 mois » gardée")
			for ancien in ["FinanceMarginIncomeLien", "FinanceProjectionEndLien"]: check(named(ancien) == null, "Synthèse : plus de sous-tuile « %s »" % ancien)
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
	# Synthèse : deux pastilles du verdict (marge → Budget, autonomie → Trésorerie).
	for cas: Array in [["FinanceVerdictMarginLien", "budget"], ["FinanceVerdictAutonomyLien", "cash"]]:
		await ouvrir("summary")
		var pastille := named(cas[0]) as Button
		check(pastille != null or Finance.verdict(app, app.model.get("finance", {}), U.strategy(app.model).get("finance", {})).margin == null, "Verdict : pastille « %s » présente" % cas[0])
		if pastille == null: continue
		check(not (named(cas[0].trim_suffix("Lien") + "Texte") as Label).text.is_empty(), "Verdict : pastille « %s » écrite" % cas[0])
		pastille.pressed.emit()
		await settle()
		check(app.route == "Finances" and str(app.management_ui.get(Finance.KEY, "")) == cas[1], "« %s » ouvre l'onglet %s (%s)" % [cas[0], cas[1], etat()])
	# Solde sur 12 mois : une semaine par relevé, chaque semaine ouvre une petite fenêtre ; Échap, ✕ et clic à côté la ferment.
	await ouvrir("summary")
	var solde := named("FinanceSoldePlot")
	check(solde != null and named("FinanceLedgerPlot") == null, "Synthèse : « Solde sur 12 mois » remplace les 12 derniers mouvements")
	var semaines := Finance.solde_semaines(app, app.model.get("finance", {}))
	check(not semaines.is_empty() and semaines.size() <= 52, "Solde : semaines relevées (%d)" % semaines.size())
	# Avant-saison (aucune semaine de championnat close) : seul le solde du jour, rien d'inventé.
	if int(app.model.meta.get("week", 0)) == 0: check(semaines.size() == 1 and semaines[0].variation == null, "Solde : avant la première semaine, le seul point est la trésorerie du jour")
	else: check((app.model.get("finance", {}).get("cashHistory", []) as Array).size() > 0, "Moteur : historique de trésorerie hebdomadaire rempli")
	if solde != null: check((solde.get("semaines") as Array).size() == semaines.size() and solde.call("graduations").size() >= 2, "Solde : courbe et graduations")
	for i in range(1, semaines.size()):
		check(is_equal_approx(float(semaines[i].variation), float(semaines[i].cash) - float(semaines[i - 1].cash)), "Solde : variation de la semaine %d = écart de solde" % i)
	var fermetures := ["echap", "croix", "voile", "tresorerie"]
	for fermeture: String in fermetures:
		await ouvrir("summary")
		var semaine := named("FinanceSoldeSemaine_0") as Button
		check(semaine != null, "Solde : la semaine en cours est cliquable")
		if semaine == null: break
		var avant := etat()
		semaine.pressed.emit()
		await settle()
		var fenetre := named("FinanceSoldeFenetre")
		check(fenetre != null and fenetre.is_visible_in_tree() and etat() == avant, "Solde : un clic ouvre la petite fenêtre de la semaine sur place")
		check(named("FinanceSoldeFenetreSoldeValeur") != null and (named("FinanceSoldeFenetreSoldeValeur") as Label).text == U.amount(semaines.back().cash), "Petite fenêtre : solde de la semaine")
		check(open_windows() == fenetres_avant, "Petite fenêtre dessinée dans l'écran, sans fenêtre système")
		match fermeture:
			"echap":
				var echap := InputEventKey.new()
				echap.keycode = KEY_ESCAPE
				echap.physical_keycode = KEY_ESCAPE
				echap.pressed = true
				app.get_viewport().push_input(echap)
			"croix": (named("FinanceSoldeFenetreFermer") as Button).pressed.emit()
			"voile": (named("FinanceSoldeFenetreVoile") as Button).pressed.emit()
			"tresorerie": (named("FinanceSoldeFenetreTresorerieLien") as Button).pressed.emit()
		await settle()
		check(named("FinanceSoldeFenetre") == null, "Petite fenêtre fermée par " + fermeture)
		if fermeture == "tresorerie": check(str(app.management_ui.get(Finance.KEY, "")) == "cash", "Petite fenêtre : la pastille Trésorerie ouvre l'onglet")
		else: check(etat() == avant and app.route == "Finances", "Fermeture par %s : on reste sur la Synthèse (%s)" % [fermeture, etat()])
	# Courbe des mouvements (onglet Trésorerie) : graduations rondes, le zéro (ligne pointillée) est une graduation.
	await ouvrir("cash")
	var courbe := named("FinanceLedgerPlot")
	if courbe != null and not (courbe.get("operations") as Array).is_empty():
		check(courbe.call("graduations").any(func(v: float): return is_zero_approx(v)), "Courbe : le zéro est une graduation (%s)" % str(courbe.call("graduations")))
	# 1280 × 720 : aucun texte du bloc verdict (mot, palier, trois paliers) n'en chevauche un autre (Synthèse et colonne fixe).
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	for tab in ["summary", "cash"]:
		await ouvrir(tab)
		var bloc := named("FinanceVerdict")
		check(bloc != null, "Verdict présent à 1280 · " + tab)
		if bloc == null: continue
		var zones: Array = []
		for texte: Node in bloc.find_children("*", "Label", true, false):
			if not (texte as Label).is_visible_in_tree() or (texte as Label).text.strip_edges().is_empty(): continue
			zones.append([(texte as Label).text, Rect2((texte as Label).global_position, Vector2((texte as Label).size.x, (texte as Label).get_line_height()))])
		for a in zones.size():
			for b in range(a + 1, zones.size()):
				check(not (zones[a][1] as Rect2).grow(-1).intersects((zones[b][1] as Rect2).grow(-1)), "1280 · %s : « %s » chevauche « %s » %s %s" % [tab, zones[a][0], zones[b][0], str(zones[a][1]), str(zones[b][1])])
	if failures.is_empty(): print("OK finances-ecran : %d vérifications" % checks)
	else: printerr("ÉCHECS : %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
