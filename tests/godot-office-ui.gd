extends SceneTree
# Réception de présentation ; les cas « projection » sont des copies, jamais des sauvegardes importées.
const Office = preload("res://ui/office_view.gd")
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		printerr("FAIL: ", text)
func named(node: Node, id: String) -> Node:
	if str(node.name) == id: return node
	for child in node.get_children():
		var found := named(child, id)
		if found != null: return found
	return null
func texts(node: Node) -> String:
	var result: String = node.text + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += texts(child)
	return result
func buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(buttons(child))
	return result
func wait_model() -> void:
	var until := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse native terminée")
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_model()
	check(app.bridge.last_response_ok, "Commande native " + id + " : " + app.last_error)
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("CD_OFFICE_CAPTURES")
	DirAccess.make_dir_recursive_absolute(path)
	check(root.get_texture().get_image().save_png(path.path_join(id + ".png")) == OK, "Capture " + id)
func render() -> void:
	app._navigate("Bureau")
	for i in 4: await process_frame
func press(id: String, route: String) -> void:
	var control: Button = named(app, id)
	check(control != null and not control.disabled, "Bouton réel disponible : " + id)
	if control == null: return
	control.grab_focus()
	await process_frame
	check(control.has_focus(), "Focus clavier : " + id)
	control.pressed.emit()
	await process_frame
	check(app.route == route, "Navigation réelle " + id + " → " + route)
func state_export() -> Dictionary:
	await command("export")
	return JSON.parse_string(app.model.meta.exportText).state
func sections() -> void:
	for id in ["OfficeCarnet", "OfficeDecisions", "OfficeJournal", "OfficeFixture", "OfficeTimeline", "OfficeGroup", "OfficeResults", "OfficeStandings", "OfficeMeans", "OfficePreparation"]:
		check(named(app, id) != null, "Section carnet disponible : " + id)
func navigation() -> void:
	var before: Dictionary = await state_export()
	var filename: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(filename)
	for pair in [["OfficeCalendarAction", "Calendrier"], ["OfficeSquadAction", "Effectif"], ["OfficeStandingsAction", "Classements"], ["OfficeFinanceAction", "Finances"], ["OfficePreparationAction", "Préparation"]]:
		await render()
		await press(pair[0], pair[1])
	await render()
	for i in 5:
		var profile: Button = named(app, "OfficePlayer" + str(i))
		var id: String = str(profile.get_meta("player_id"))
		await press(str(profile.name), "Effectif")
		check(app.selected_player == id, "Fiche du joueur par ID : " + id)
		check(texts(app.body).contains(id) or texts(app.body).contains(str(app.model.squad.filter(func(p):return p.id == id)[0].name)), "La fiche affiche le joueur choisi")
		await render()
	if named(app, "OfficeContractsAction") != null:
		await press("OfficeContractsAction", "Effectif")
		check(not app.selected_player.is_empty(), "Contrat : fiche sélectionnée")
		await render()
	var after_buttons: Dictionary = await state_export()
	check(before == after_buttons, "Boutons et fiches préservent intégralement S/RNG")
	check(bytes == FileAccess.get_file_as_bytes(filename), "Boutons et fiches : aucun octet de sauvegarde modifié")
	await command("set_lineup", {"slot":0,"playerId":null})
	await render()
	check(texts(named(app, "OfficeSelection")).contains("1 poste à couvrir"), "Priorité réelle : poste vacant")
	var after_clear: Dictionary = await state_export()
	var cleared_bytes := FileAccess.get_file_as_bytes(filename)
	await render()
	await press("OfficeSelectionAction", "Composition")
	var after_navigation: Dictionary = await state_export()
	check(after_clear == after_navigation, "Composition : aucun changement S/RNG")
	check(cleared_bytes == FileAccess.get_file_as_bytes(filename), "Composition : aucun octet écrit par navigation")
	await command("auto_lineup")
	# Recheck the full route sequence after the explicit selection command.
	await render()
	var navigation_before: Dictionary = await state_export()
	var navigation_bytes := FileAccess.get_file_as_bytes(filename)
	for route in ["Bureau", "Effectif", "Composition", "Préparation", "Calendrier", "Classements", "Finances"]:
		app._navigate(route)
		await process_frame
	var after: Dictionary = await state_export()
	check(navigation_before == after, "Toutes les navigations préservent intégralement S et le RNG")
	check(navigation_bytes == FileAccess.get_file_as_bytes(filename), "Toutes les navigations préservent les octets de sauvegarde")
	check(not bytes.is_empty() and not before.is_empty(), "Vraie carrière exportée et stockée dans le profil temporaire")
func ranking_edges() -> void:
	var base: Dictionary = app.model.duplicate(true)
	var rows: Array = []
	for league: Dictionary in base.leagues:
		if league.id == base.meta.leagueId: rows = league.rows
	for i in [0, rows.size()/2, rows.size()-1]:
		var model: Dictionary = base.duplicate(true)
		model.club = rows[int(i)].duplicate(true)
		var window := Office.standings_window(model)
		check(window.size() == mini(8, rows.size()), "Fenêtre de classement : huit lignes")
		check(window.any(func(row):return row.id == model.club.id), "Fenêtre inclut le club au premier/milieu/dernier rang")
		var start := rows.find(window[0])
		check(window == rows.slice(start, start + window.size()), "Ordre de classement natif conservé sans nouveau départage")
func bounds() -> void:
	var page: Control = named(app, "OfficeCarnet")
	check(page.get_global_rect().end.x <= app.size.x + 1 and page.get_global_rect().end.y <= app.size.y + 1, "Bureau dans la fenêtre")
	for id in ["OfficeDecisions", "OfficeStandings"]:
		var node: Control = named(app, id)
		check(node.size.x > 180, "Colonne lisible : " + id)
	for control in buttons(page):
		check(control.focus_mode == Control.FOCUS_ALL, "Bouton accessible au clavier : " + str(control.name))
		check(control.size.x > 0 and control.size.y >= 25, "Cible interactive lisible : " + str(control.name))
func contrast(first: Color, second: Color) -> float:
	var a := first.srgb_to_linear().get_luminance()
	var b := second.srgb_to_linear().get_luminance()
	return (maxf(a,b)+.05)/(minf(a,b)+.05)
func palette() -> void:
	var original: Color = app.accent
	for color in [Color("cad0d3"), Color("ffdf00"), Color("050505")]:
		app.accent = color
		await render()
		var standings: Node = named(app, "OfficeStandings")
		var chapter: Label = standings.get_child(0).get_child(0)
		var objective: Label = standings.get_child(2).get_child(1)
		for label in [chapter, objective]:
			check(contrast(label.get_theme_color("font_color"), Office.PAPER) >= 4.5, "Encre Bureau lisible " + color.to_html() + " " + label.text)
		var grid: GridContainer = standings.get_child(3)
		var rows := Office.standings_window(app.model)
		for index in rows.size():
			if rows[index].id != app.model.club.id: continue
			for column in 6:
				var cell: PanelContainer = grid.get_child(6 + index * 6 + column)
				check(contrast(cell.get_child(0).get_theme_color("font_color"), cell.get_theme_stylebox("panel").bg_color) >= 4.5, "Classement sélectionné lisible " + color.to_html())
		for id in ["OfficeStandingsAction", "OfficePreparationAction", "OfficeFinanceAction"]:
			var button: Button = named(app, id)
			var background := Office.CHARCOAL if id == "OfficeFinanceAction" else Office.PAPER
			for state in [["normal", "font_color"], ["hover", "font_hover_color"], ["pressed", "font_pressed_color"]]:
				var surface: Color = background.blend(button.get_theme_stylebox(state[0]).bg_color)
				check(contrast(button.get_theme_color(state[1]), surface) >= 4.5, "Lien Bureau lisible " + color.to_html() + " " + id + " " + state[0])
			check(contrast(button.get_theme_color("font_focus_color"), background) >= 4.5, "Texte focus Bureau " + id)
			check(contrast(button.get_theme_stylebox("focus").border_color, background) >= 3, "Bordure focus Bureau " + color.to_html() + " " + id)
		await capture("bureau-palette-" + color.to_html())
	app.accent = original
	await render()
func money_lines() -> void:
	var metrics: Node = named(app, "OfficeMeans").get_child(1)
	for metric in metrics.get_children():
		var value: Label = metric.get_child(0)
		check(value.get_line_count() == 1, "Indicateur et unité sur une ligne : " + value.text + " / " + str(root.size.x))
	check(texts(metrics).contains(Office.G.euros(app.model.finance.cash)), "Trésorerie exacte et unité conservées")
func projections() -> void:
	var base: Dictionary = app.model.duplicate(true)
	var projected: Dictionary = base.duplicate(true)
	projected.messages = ["Message long de réception. ".repeat(35)]
	projected.club.presentation.name = "Club de réception au nom particulièrement long pour éprouver la mise en page"
	projected.next.home.presentation.name = "Une équipe au nom particulièrement long pour la réception"
	projected.next.neutral = true
	projected.next.phase = "final"
	projected.packs = {"missing":["Pack de carrière absent : réception"]}
	app.model = projected
	await render()
	check(texts(named(app,"OfficeFixture")).contains("Terrain neutre · enceinte générique"), "Neutre : aucune fausse enceinte du club hôte")
	check(texts(app.root_content).contains("Pack de carrière absent"), "Avertissement pack manquant conservé")
	bounds()
	await capture("bureau-projection-long-neutre-pack-absent")
	projected = base.duplicate(true)
	projected.next = null
	projected.calendar = []
	projected.messages = []
	projected.meta.canAdvanceSeason = true
	app.model = projected
	await render()
	check(texts(named(app,"OfficeFixture")).contains("La saison se termine"), "Intersaison sans rencontre")
	check(texts(named(app,"OfficeTimeline")).contains("Aucune rencontre programmée"), "Chronologie vide honnête")
	check(texts(named(app,"OfficeJournal")).contains("Le carnet s'ouvre"), "Journal vide honnête")
	check(named(app,"OfficeTraining") == null, "Aucune priorité entraînement en intersaison")
	await capture("bureau-projection-intersaison")
	projected.meta.canAdvanceSeason = false
	app.model = projected
	await render()
	check(texts(named(app,"OfficeFixture")).contains("Le travail continue"), "Semaine sans rencontre")
	app.model = base
	await render()
func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_model()
	app.timer.stop()
	await command("new_career", {"club":0,"mode":"common"})
	await render()
	sections()
	if failures.size() > 0:
		print("BUREAU RED : ", checks, " contrôles ; ", failures.size(), " sections manquantes")
		app.bridge.stop(); quit(1); return
	check(texts(named(app, "OfficeResults")).contains("Aucun match joué"), "Première semaine : aucun faux résultat")
	check(texts(named(app, "OfficeDecisions")).contains("Échéances d’ici la saison 2"), "Échéances de contrats honnêtes")
	var real_contracts: int = app.model.squad.filter(func(p):return p.contractEnd != null and int(p.contractEnd) <= int(app.model.meta.season) + 1).size()
	check(texts(named(app, "OfficeContracts")).contains(str(real_contracts) + " contrat"), "Nombre de contrats issu du modèle réel")
	ranking_edges()
	await navigation()
	for resolution in [Vector2i(1280,800), Vector2i(1440,900), Vector2i(1920,1080)]:
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		for i in 5: await process_frame
		await render()
		bounds()
		money_lines()
		await capture("bureau-" + str(resolution.x))
		var center: ScrollContainer = named(app, "OfficeFixture").get_parent().get_parent()
		center.scroll_vertical = 10000
		await capture("bureau-" + str(resolution.x) + "-bas")
		if resolution.x == 1440:
			named(app, "OfficeDecisions").get_parent().scroll_vertical = 10000
			named(app, "OfficeStandings").get_parent().scroll_vertical = 10000
			await capture("bureau-1440-journal-preparation")
	await projections()
	for setup in [[29, "common"], [0, "france"], [0, "fiction"]]:
		await command("new_career", {"club":setup[0],"mode":setup[1]})
		await render()
		check(int(app.model.club.id) == setup[0], "Vraie carrière : " + setup[1])
		money_lines()
		if setup[0] == 29:
			check(app.accent == Color("cad0d3"), "Couleur identitaire réelle de Valence Romans conservée")
			for resolution in [Vector2i(1280,800), Vector2i(1440,900), Vector2i(1920,1080)]:
				root.size = resolution
				if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
				for i in 5: await process_frame
				await render()
				bounds()
				money_lines()
				named(app, "OfficeStandings").get_parent().scroll_vertical = 10000
				await capture("bureau-club29-moyens-" + str(resolution.x))
			await palette()
		sections()
		ranking_edges()
		await capture("bureau-" + str(setup[1]) + "-" + str(setup[0]))
		check(app.model.leagues.size() == (1 if setup[1] == "fiction" else 2), "Divisions natives : " + setup[1])
	await command("new_career", {"club":29,"mode":"france"})
	await command("begin_match")
	await command("pause", {"paused":true})
	await render()
	check(texts(named(app, "OfficeFixture")).contains("RETOUR AU DIRECT"), "Action de match en cours conservée")
	check(app.minibar.text.contains("min"), "Horloge du direct conservée")
	var live_before: Dictionary = await state_export()
	await render()
	await press("OfficePrimaryAction", "Match")
	var live_after: Dictionary = await state_export()
	check(live_before == live_after, "Retour au direct sans modifier S/RNG")
	await command("delegate")
	await render()
	check(texts(named(app,"OfficeFixture")).contains("VALIDER LE RÉSULTAT"), "Match terminé : validation existante conservée")
	await command("finish_round")
	await render()
	check(not texts(named(app,"OfficeResults")).contains("Aucun match joué"), "Résultat issu du vrai match")
	await capture("bureau-resultat-reel")
	print("BUREAU GREEN : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
